# HANDOFF — PostHog organization groups

**Written:** 2026-08-10, end of session, ahead of a machine switch.
**Repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`
**Branch:** `ai-credit-posthog-events` — **merged** into `develop` via [PR #3088](https://github.com/wrk-corp/inflow-ats/pull/3088) at 2026-08-11T00:26Z. CI green.

---

## TL;DR — what is left to do

1. **Run the migration.** `20260810153000_add_posthog_distinct_id_to_users_and_organizations.rb` adds `posthog_distinct_id` to `users` and `organizations`. Not run anywhere. Dev, test, and production all need it.
2. **Run the Stripe customer metadata backfill** — console snippet at `../stripe-customer-metadata-backfill/CONSOLE-BACKFILL.md`. Status unknown; a partial run happened during the session.
3. **Verify `$groupidentify` and `$groups` are landing** in the PostHog live event feed. Both are ordinary events and visible without the add-on.
4. **Then** run `rake backfill_posthog_organization_groups`.
5. **Then, last,** enable the group analytics add-on on the PostHog billing page.

Order matters for #4 and #5 — see "Billing" below.

---

## What shipped

Four commits on the branch, all merged:

| Commit | What |
|---|---|
| `2d1b45563` | Fix `OrgOwnerUpdateJob` calling a method that no longer exists |
| `2790c0f46` | PostHog organization groups, browser reverse proxy, SDK upgrades |
| `a7fb42b3c` | update yarn lock |
| `11e35f8d3` | Collection of the PostHog distinct id |

### 1. Organization as a PostHog group

- Group type `organization`. Group key `organization.id.to_s`.
- **The key is permanent.** PostHog has no rename, no merge, and no per-group delete. Only whole group types can be deleted, and deleting one is data-losing for history.
- New `app/services/posthog/identify_organization.rb` (mirrors `Posthog::Identify`) and `app/jobs/posthog_identify_organization_job.rb` (mirrors `PosthogIdentifyJob`).

**Eleven group properties:** `organization_id`, `name`, `plan`, `stripe_subscription_status`, `stripe_customer_id`, `created_at`, `job_board_url`, `linkedin_page_url`, `owner_id`, `owner_email`, `owner_name`.

**No counts, deliberately.** `users_count`, `published_jobs_count`, active-users and visible-jobs counts all change in child tables that fire no `Organization` callback, so they would be stale most of the time. Decision: a wrong count is worse than no count.

**Three enqueue points, all model callbacks.** A job never enqueues another job — that is a house rule.

| When | Where | Gate |
|---|---|---|
| Create | `Organization#complete_setup_workers` | none |
| Refresh | new branch on `Organization#handle_after_commit_on_update` | `saved_changes` on `name`, `plan`, `stripe_subscription_status`, `stripe_customer_id`, `linkedin_company_id`, `owner_id` |
| Refresh | `CareersPage#handle_after_update` | `saved_change_to_slug?` / `saved_change_to_custom_domain?` / `saved_change_to_custom_domain_valid?` |

**Events carry the group.** `Posthog::Track` attaches `groups: { organization: <id> }`, **omitted entirely** when there is no organization. Not `{}` — the gem ships `"$groups":{}` for an empty hash, and the user has no organization throughout the signup window.

`PosthogTrackJob` gained a **trailing optional** `organization_id`, so the 20 existing call sites and any in-flight enqueued jobs are unaffected. Three call sites pass it explicitly — `subscription_event.rb:61`, `organization_ai_credit_purchase.rb:83` and `:91` — because they use `organization.owner.id` as the distinct_id, and `Posthog::Track` would otherwise resolve the owner's *current* organization, which for a multi-org owner is a different one.

**Browser.** `identifyOrganization` in `app/javascript/shared/lib/posthog.ts` is a structural copy of `identifyUser` — same object parameter, same guard, same logger lines, **no dedupe guard** (because `identifyUser` has none). Called in the existing identify effect in `AppAuthRouter.tsx` right after `identifyUser`, guarded on `currentOrganization != undefined`. It calls `posthog.group` and registers `organization_id` as a super property.

**Backfill task:** `backfill_posthog_organization_groups` in `lib/tasks/one_off_tasks.rake`. `Organization.claimed.find_each` + `next unless organization.active_paid_plan?`, shaped on `recurring_tasks.rake:150-156`.

### 2. Browser reverse proxy

`Variables::POSTHOG_BROWSER_HOST` = `https://b.polymer.co`, emitted as `window.POSTHOG_BROWSER_HOST`, read by `posthog.init`.

`POSTHOG_HOST` is **unchanged** and is still what the Ruby client uses. The gem goes direct to `us.i.posthog.com` — a reverse proxy only helps browser requests, since ad-blockers do not block server-side calls.

No `defaults` key was added to `posthog.init`. It is an opt-in snapshot that flips several unrelated runtime defaults at once.

### 3. SDK upgrades

- `posthog-ruby` 2.11.0 → **3.23.0**, exact pin, with `require: 'posthog'` in the Gemfile. 3.0.0 deleted the `lib/posthog-ruby.rb` shim, which is why `config/initializers/posthog.rb` changed.
- `posthog-js` 1.297.4 → **1.414.0**, `@posthog/react` 1.0.0 → **1.10.3**.

**The Ruby-version question, settled:** posthog-ruby's changelog for gem 3.0.0 says the minimum Ruby is 3.2; every 3.x gemspec actually enforces `>= 3.0`. This app runs Ruby 3.1.6. Decision was to go with the enforced constraint. It installs and runs.

### 4. PostHog distinct id capture

posthog-js mints an anonymous UUID as the `distinct_id` on first page load and stores it in the `ph_<project_api_key>_posthog` cookie — one of only five properties it keeps in a cookie rather than localStorage, which is what lets it cross subdomains from the marketing site.

New `posthog_distinct_id` column on `users` and `organizations`. Read in `adPlatformCookies()` (`app/javascript/shared/lib/utils.js`) with a JSON parse helper alongside `gaClientIdFromCookie`. Carried through both signup paths:

- **Email:** request body, like every other identifier.
- **Google SSO:** hidden input → `allowed_keys` in `config/initializers/omniauth.rb` → session → `omniauth_callbacks_controller.rb` → `User.from_omniauth`.

Copied to the Organization at create straight off `current_user`, **no fallback**.

`AuthForm.tsx` additionally re-reads the cookie as a fallback beside the `googleClickId` / `liFatId` ternaries, because a visitor arriving directly has no cookie at first render — posthog creates it a moment after mount.

**Deliberately NOT added to** `User#attribution_properties` (undecided; it would change three PostHog event payloads at once) or `SubscriptionEvent#posthog_properties` (every row there routes through `attribution_value(owner, organization)`, which is exactly the owner-to-organization fallback this field must not have).

### 5. Separate bug fix

`OrgOwnerUpdateJob:17` called `organization.update_stripe_customer_on_owner_change`. That method was renamed to `update_stripe_customer` in `65a47fee8` (Jul 2024), which updated the two call sites in `organization.rb` and missed this one. The job raised `NoMethodError` on its first record for ~25 months, swallowed by its own rescue — **owner profile changes never reached Stripe in that time.**

---

## Known gaps, accepted

- **Owner name and email go stale.** They live on `users`, which fires no `Organization` callback. They refresh whenever some other gated column changes. Accepted; a `User` callback could be added later.
- **`custom_domain_valid` written by `update_columns`.** `careers_page.rb#custom_domain_info` uses `update_columns`, so it fires no callback — `job_board_url` will not refresh at the moment a custom domain actually goes live. This was deliberately reverted to `update_columns` after review; switching it to `update` would run the four attachment validators on a path that never ran them before.
- **`job_board/base_controller.rb:21`** also writes `custom_domain_valid` with `update_columns`. Explicitly excluded from scope.
- **`owner_id` gate clause is dead** unless `transfer_ownership_to_organization_user` keeps its `update` (it does — that one was changed and kept, with the `if update(...)` wrapper so role flips only happen on success).
- **No historical group attribution, ever.** `$group_N` is written onto the event at ingest. [PostHog#11224](https://github.com/PostHog/posthog/issues/11224) is closed as not planned. Group-aggregated charts start at deploy date.

---

## Billing — read before enabling the add-on

- Billing starts when the add-on is **toggled on the billing page**, not when code deploys. It then bills **all identified events project-wide**, not just group-tagged ones.
- First 1,000,000 identified events/month are free. Get the actual project number from the billing page before deciding.
- PostHog's own stat: 20% of accounts paying for group analytics send no group events at all. Verify data is landing first.
- `$groupidentify` and `$groups` are ordinary events and **are visible in the live feed without the add-on**. What the add-on gates is the Groups tab, group profiles, `Unique groups` aggregation, group funnels/retention, and B2B mode.

---

## Verification steps

Manual, against the running app and the live PostHog feed:

1. Log in — exercises `Posthog::Identify` and `Posthog::Track`. Confirm the event carries `$groups`.
2. Change an organization's name — confirm a `$groupidentify` arrives with all eleven properties.
3. Confirm browser requests go to `b.polymer.co` and server events still reach `us.i.posthog.com`.
4. Run the backfill; confirm the group count.

HogQL for verification:
```sql
SELECT index, count() AS groups, max(created_at) AS newest FROM groups GROUP BY index
```
```sql
SELECT event, $group_0 FROM events WHERE $group_0 != '' ORDER BY timestamp DESC LIMIT 20
```

**`rails runner` scripts must call `POSTHOG_CLIENT.flush` before exiting** — the gem batches on a background thread and the process exits before anything sends.

### Cross-subdomain cookie test

Paste in the console on the marketing site, note the id, then type the app URL directly in the same browser and run again. Same id means it carried.

```js
(() => {
  const entry = document.cookie.split("; ").find(c => /^ph_.+_posthog=/.test(c));
  if (!entry) return "NO POSTHOG COOKIE on " + location.hostname;
  const value = entry.substring(entry.indexOf("=") + 1);
  try {
    return { host: location.hostname, distinct_id: JSON.parse(decodeURIComponent(value)).distinct_id };
  } catch (e) {
    return { host: location.hostname, raw: value.slice(0, 120), parseError: String(e) };
  }
})();
```

`document.cookie` cannot show the `Domain` attribute — check DevTools → Application → Cookies. `.polymer.co` crosses subdomains; `polymer.co` without the dot is host-only. Only works within one registrable domain.

---

## Open questions never resolved

1. **Does `posthog_distinct_id` belong in `User#attribution_properties`?** That hash feeds `user_signed_up` and `organization_owner_signed_up` plus their `$set_once` person properties, across three call sites. No storage impact either way.
2. **How does PostHog link groups to Stripe?** The HogQL `groups` table has a `revenue_analytics` lazy join to a `GroupsRevenueAnalyticsTable`, so group↔Stripe is supported — but what field it keys on was never verified. The Stripe customer metadata backfill (`organization_id`, `organization_name`, `careers_page_url`, `organization_created_via`) may or may not be what it matches.
3. **Should browser events also carry more organization properties?** Currently `name` and `plan` only; the backend sends all eleven.

---

## Artifacts in this directory

- `SPEC.md` — the full spec, four blocks. Note it is **ahead of** what shipped in one place: it describes `careers_page.rb#custom_domain_info` using `update` with return-value handling, which was reverted to `update_columns` after review.
- `PROPOSAL.md` — the original proposal, including the full SDK upgrade blast-radius analysis for both packages.
- `research/` — 11 reports: PostHog group docs, both SDK surfaces read from installed source, gotchas and limits, groups vs alternatives, the HTTP/backfill APIs, plus full end-to-end traces of the existing backend and frontend integration, the Organization model, and house conventions.
- `../stripe-customer-metadata-backfill/CONSOLE-BACKFILL.md` — the Stripe console snippet and its reasoning.

---

## Process notes for the next session

- **The pre-commit hook runs the full Cypress suite and can hang indefinitely.** It hung for 12 hours in this session on `job-setup/hiring-stage-automations.cy.js` and produced no output after the first six minutes. If you background a commit, **arm a stall monitor on the output file's mtime** — a live process with a stale output file is the signature.
- The hang's likely cause: `package.json` had the new posthog-js version while `yarn.lock` and `node_modules` still had the old one. `bundle install` was run; `yarn install` was not. **Run both when bumping both.**
- `cursor_rules/` has 47 files. One reviewer per file finds real defects; a single broad "conventions" angle finds almost nothing.
- The model-level pattern for handling a non-bang `update` return value is **not** in `core_critical_rules.md` (its rule 12 examples are controller-shaped). It is `backend/code_style_and_structure.md`, which scopes itself to all Ruby files in `app/`, plus `backend/services.md` on logging with both `ap` and `Rails.logger.error`. The only non-AI model precedent is `JobResumeExport#mark_failed`.
