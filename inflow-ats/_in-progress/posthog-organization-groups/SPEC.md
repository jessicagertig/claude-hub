# SPEC — PostHog organization groups + browser reverse proxy

**Repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`
**Branch:** cut from the merge branch (`develop`)
**Scope:** three independent blocks — SDK pins, reverse proxy, organization groups.

No RSpec. Verification is manual, per `.claude/CLAUDE.md §0a`.

---

## Block 1 — SDK pins

| File | From | To |
|---|---|---|
| `package.json:70` | `"posthog-js": "1.297.4"` | `"posthog-js": "1.414.0"` |
| `package.json:31` | `"@posthog/react": "1.0.0"` | `"@posthog/react": "1.10.3"` |
| `Gemfile:122` | `gem 'posthog-ruby', '~> 2.0'` | `gem 'posthog-ruby', '3.23.0', require: 'posthog'` |
| `config/initializers/posthog.rb:3` | `require 'posthog-ruby'` | `require 'posthog'` |

Regenerate `yarn.lock` and `Gemfile.lock`.

- **No `tsconfig.json` change.** The one new `node_modules` type error is accepted.
- The gem's own changelog states a Ruby 3.2 minimum; every 3.x gemspec enforces `>= 3.0`. This app runs Ruby 3.1.6. Decision: proceed on the enforced constraint.
- Gem 3.x adds `"$is_server": true` to every server-side event and drops top-level `library` / `library_version` / `messageId`. Expected, not a regression.

---

## Block 2 — Browser reverse proxy

Browser traffic routes through `https://b.polymer.co`. The Ruby gem continues to go direct to `https://us.i.posthog.com`.

| File | Change |
|---|---|
| `config/initializers/01_variables.rb` | Add `POSTHOG_BROWSER_HOST = ENV['POSTHOG_BROWSER_HOST'] \|\| 'https://b.polymer.co'`, matching the shape of the `POSTHOG_HOST` line above it. `POSTHOG_HOST` is unchanged. |
| `app/views/layouts/application.html.erb:79` | Replace `window.POSTHOG_HOST` with `window.POSTHOG_BROWSER_HOST`, emitting `Variables::POSTHOG_BROWSER_HOST` |
| `app/javascript/shared/PostHogContext.tsx:28, 34` | Read `window.POSTHOG_BROWSER_HOST` for `api_host` |
| `app/javascript/shared/lib/posthog.ts:3-8` | Rename `POSTHOG_HOST` to `POSTHOG_BROWSER_HOST` in the `Window` interface |

`Variables::POSTHOG_HOST` remains, read only by `config/initializers/posthog.rb:8`.

**Open decision:** whether `posthog.init` also takes `defaults: '2026-05-30'`. No `defaults` key is passed today, so all defaults are currently legacy. Not resolved.

---

## Block 3 — Organization as a PostHog group

### 3.1 Identity

- Group type: `organization` (singular). Becomes `group_type_index 0`, permanently — no rename or merge API exists.
- Group key: `organization.id.to_s`.
- The existing `organization_id` event property stays. It is the only handle on pre-adoption history.

### 3.2 Group properties — ten

| Property | Expression |
|---|---|
| `organization_id` | `organization.id` |
| `name` | `organization.name` |
| `plan` | `organization.plan` |
| `stripe_subscription_status` | `organization.stripe_subscription_status` |
| `stripe_customer_id` | `organization.stripe_customer_id` |
| `created_at` | `organization.created_at&.iso8601` |
| `job_board_url` | `organization.careers_page_url` (`organization.rb:1379`) |
| `linkedin_page_url` | `"https://www.linkedin.com/company/#{organization.linkedin_company_id}"`, only when `linkedin_company_id.present?` |
| `owner_id` | `organization.owner&.id` |
| `owner_email` | `organization.owner&.email` |
| `owner_name` | `organization.owner&.full_name` |

Deliberately excluded: **all counts.** `users_count`, `published_jobs_count`, active-users count and visible-jobs count are all written outside the two models that trigger a refresh, so they would be wrong most of the time. A wrong count is worse than no count.

`name` is required by PostHog or the group displays as a bare ID.

**Note:** `User#full_name` (`user.rb:242-244`) returns `" "` — a single space — when `first_name` and `last_name` are both at their `""` default. Do not send a space; treat it as absent (rule 13, never fabricate a value for missing data).

### 3.3 New files

**`app/services/posthog/identify_organization.rb`** — `Posthog::IdentifyOrganization`
Mirrors `Posthog::Identify`: keyword-arg initializer taking `organization:`, a descriptive public method (not `call`), `return unless POSTHOG_CLIENT` guard, method-level `rescue StandardError => e` logging `[PostHog] …`.
Calls `POSTHOG_CLIENT.group_identify` with `group_type: 'organization'`, `group_key: organization.id.to_s`, `distinct_id: 'groups_setup_id'`, and the ten properties.

`distinct_id` is the static `'groups_setup_id'` PostHog documents. Omitting it makes the gem synthesize `"$organization_<id>"`, creating one fake person per organization.

**`app/jobs/posthog_identify_organization_job.rb`** — `PosthogIdentifyOrganizationJob`
Mirrors `PosthogIdentifyJob` exactly: `queue_as :default`, takes `organization_id`, `Organization.find_by(id:)` with a bare `return unless`, delegates to the service.

### 3.4 Refresh triggers

Three enqueue points, all `PosthogIdentifyOrganizationJob.perform_later(organization_id)` from a model callback — never from inside another job. Every fire recomputes all ten properties.

| When | Where | Gate |
|---|---|---|
| **Create** | `Organization#complete_setup_workers` (`organization.rb:180-190`), the existing `after_commit on: [:create]` | none |
| **Refresh** | new branch method on `Organization#handle_after_commit_on_update` (`organization.rb:1023-1029`) | `saved_changes` on `name`, `plan`, `stripe_subscription_status`, `stripe_customer_id`, `linkedin_company_id`, `owner_id` |
| **Refresh** | `CareersPage` | `saved_changes` on `slug`, `custom_domain` |

### Two `update_columns` writers become `update`

Both were confirmed safe by reading every validation and callback they would newly fire.

**`careers_page.rb:138`, in `custom_domain_info`** — `update_columns(custom_domain_valid: custom_domain_valid)` becomes `update`. Without this the refresh fires at the wrong moment: `hire_display_url` (line 94) only returns the custom domain once `custom_domain_valid` is true, so a `custom_domain` change refreshes the group to the *old* URL, and the moment the URL actually changes writes through `update_columns` and fires nothing.

What `update` newly runs there: the four attachment validations, `handle_before_update` → `ensure_proper_navigation_url` (normalizes `custom_navigation_url`, no-op when already normalized), and `handle_after_update`, whose logo branch requires `logo.key != logo_blob_key` and whose slug branch requires `saved_change_to_slug?`. Nothing consequential.

**`organization.rb:275`, in `transfer_ownership_to_organization_user`** — `update_columns(owner_id: ...)` becomes `update`. Without this the `owner_id` clause in the gate is unreachable, so `owner_id`, `owner_email` and `owner_name` never refresh on an ownership transfer.

This adds no new callback firing at all: the same method already calls `update_settings` two lines later, which does a plain `save`. The validations (`name` presence, `linkedin_company_id` uniqueness with `allow_nil`, `validate_wwr_percent_off`) and all five `after_commit` branch methods already run in this method today.

### `CareersPage` gets one callback, not two

The `custom_domain` refresh goes in the existing `handle_after_update` (`careers_page.rb:164-184`), alongside the branch that already calls `organization.update_stripe_customer` on a slug change — not as a second `after_update_commit` registration.

**Accepted staleness:** `owner_email` and `owner_name` live on `users` and are not covered. They refresh whenever either callback next fires. An `OrganizationUser` or `User` callback can be added later if this matters.

**Known gap:** `CareersPage#custom_domain_valid` is written with `update_columns` (`careers_page.rb:137`), which fires no callback.

### 3.5 Attaching groups to events

**`app/services/posthog/track.rb`** — add an optional `organization:` keyword defaulting to `user.organization`; pass `groups: { organization: organization.id.to_s }` on `capture`.
`groups:` must be **omitted entirely** when there is no organization. The gem sends `"$groups":{}` for an empty hash, and `user.organization` is nil throughout the signup window.

**`app/jobs/posthog_track_job.rb`** — add a trailing optional `organization_id = nil`, so the 20 existing call sites and any in-flight jobs are unaffected.

**Three call sites pass the organization explicitly**, because they use `organization.owner.id` as the distinct_id while `Posthog::Track` would otherwise resolve the owner's *current* organization, which may be a different one:
- `app/models/subscription_event.rb:61`
- `app/models/organization_ai_credit_purchase.rb:83`
- `app/models/organization_ai_credit_purchase.rb:91`

This also corrects `organization_id` / `organization_name` / `plan` on those events for multi-org owners.

### 3.6 Browser

Copies `identifyUser` (`shared/lib/posthog.ts:17-39`) exactly — same object parameter, same `getPosthog()` guard, same two `window.logger` lines. No dedupe guard, matching `identifyUser`.

**`app/javascript/shared/lib/posthog.ts`** — add below `identifyUser`, and add to the `export` at line 59:

```ts
function identifyOrganization(organization: {
  id: number;
  name?: string;
  plan?: string;
}): void {
  const ph = getPosthog();
  if (!ph) {
    window.logger("%c[PostHog] identifyOrganization skipped - not loaded", "background-color: #FF76D2", { organization });
    return;
  }

  window.logger("%c[PostHog] identifyOrganization", "background-color: #FF76D2", { organization });
  ph.group("organization", String(organization.id), {
    name: organization.name,
    plan: organization.plan,
  });
  ph.register({ organization_id: organization.id });
}
```

The `register` call is the browser equivalent of the backend's `default_properties`. Verified in the installed source: `posthog-core.js:1120` writes into persistence, and `posthog-core.js:1026` merges persistence properties into every captured event —

```js
properties = extend({}, infoProperties, this.persistence.properties(), this.sessionPersistence.properties(), properties);
```

so `organization_id` lands on `trackEvent` calls, `$pageview`, `$pageleave` and autocapture, with call-site properties still winning since they are spread last. Without it, browser events would carry `$groups` but not the plain `organization_id` property that every server-side event already has, and queries filtering on `properties.organization_id` would miss them.

`$snapshot` events are the one exception — they return at `posthog-core.js:966` before the merge. Session replay is not enabled, and `$groups` is excluded there too, so the two stay consistent.

**`app/javascript/shared/PostHogContext.tsx`** — add to the import at line 5 and the export at line 54, since `AppAuthRouter` imports from there.

**`app/javascript/ats/src/views/layouts/AppAuthRouter.tsx:163-177`** — add to the import at line 44, and call inside the existing identify effect directly under `identifyUser({...})`:

```tsx
      identifyOrganization({
        id: organizationId,
        name: organizationName,
        plan: currentPlan,
      });
```

The effect's dependency array is already `[currentUser, organizationId, currentPlan, organizationName]`, so it fires on mount and when any of those change. No new effect, no new dependency.

`name` and `plan` from the browser upsert only those two keys; they cannot clobber the eight the backend sends.

Logout and org switch need no new code. `resetUser()` → `ph.reset()` already clears `$groups`; on org switch the effect re-fires and `group()` overwrites the key.

### 3.7 Backfill

A rake task in `lib/tasks/one_off_tasks.rake`, scoped to **organizations on an active paid plan**.

Copies the shape of `lib/tasks/recurring_tasks.rake:150-156`, the non-AI analog:

```ruby
Organization.claimed.find_each do |organization|
  next unless organization.active_paid_plan?

  PosthogIdentifyOrganizationJob.perform_later(organization.id)
  count += 1
end
```

with a `puts` before and after reporting the count, matching that task. The same `next unless organization.active_paid_plan?` guard is used at `db/data/20260727185945_create_subscription_events_for_existing_paid_organizations.rb:8`.

`active_paid_plan?` (`organization.rb:691`) is `paid_plan? && stripe_subscription_in_good_standing` — both local column reads, no Stripe API call in the loop.

No staggering. `recurring_tasks.rake` staggers for Google Sheets rate limits; PostHog's per-`distinct_id` ingestion protection does not engage until roughly 5,000 events a minute.

Everything outside that scope — unclaimed rows, internal organizations, free accounts — never becomes a group. **Individual groups cannot be deleted in PostHog**, only whole group types, so a junk group would be permanent.

A backfill creates group rows only. No historical event carries `$group_0`, and there is no way to add one — group-aggregated charts start at the deploy date.

---

---

## Block 4 — Capture the PostHog anonymous distinct id at signup

**Independent of Blocks 1-3.** Ships separately.

### Why

posthog-js mints an anonymous UUID as the `distinct_id` on a visitor's first page load and marks the person `anonymous` (`posthog-core.js:438-448`). It lives in the `ph_<project_api_key>_posthog` cookie — one of only five properties posthog-js keeps in a cookie rather than localStorage (`storage.js:244-250`), which is what lets it cross subdomains.

When the browser later calls `identify(String(user.id), ...)`, PostHog merges the anonymous person's history into the identified one. That merge is internal to PostHog. Capturing the UUID ourselves gives us the same link **outside** PostHog — the join from a signup back to its pre-signup marketing session, in our own data.

This is the same thing already done for `ga_client_id`, `ga_session_id`, `fbp`, `fbc`, `li_fat_id`, `google_click_id`, `adroll_click_id` and `adroll_first_party_cookie`.

### What

A new attribution identifier following the existing cookie-sourced pattern exactly, deviating only to use PostHog's own accessor.

- **Read it with `posthog.get_distinct_id()`**, not by parsing the cookie. The cookie value is JSON, unlike `_ga` or `_fbp`.
- **Stored on `users`** — written at signup on both paths.
- **Copied to `organizations`** at organization create, straight off `current_user`, **with no fallback** — several existing fields have one; this must not.
- Proposed column name `posthog_distinct_id` on both tables, nullable string, matching the other identifiers.

### Both signup paths must be covered

1. **Plain email registration** — the AuthRegister path. XHR, so the value rides in the request body like the other identifiers.
2. **Google SSO** — a full-page redirect, not an XHR. The existing identifiers already solve this somehow; Block 4 must use whatever that mechanism is rather than inventing one.

### Where the value comes from — the cookie, like every other one

The visitor arrives from the marketing site already carrying `ph_<project_api_key>_posthog`, set on the root domain. It is in `document.cookie` at first render, so this is an ordinary cookie read.

**It goes in `adPlatformCookies()` in `app/javascript/shared/lib/utils.js`**, alongside `gaClientId`, `fbp`, `fbc` and the rest. No posthog import, no `posthog.get_distinct_id()`, no timing consideration — captured at first render by the existing `React.useState(adPlatformIdentifiers(location.search))` in both forms, exactly like the other cookie-sourced fields.

The cookie value is JSON, so it needs a small parse helper to pull `distinct_id` out of it. That is the same shape as the two helpers already in that file: `gaClientIdFromCookie` (splits `_ga` on `.` and rejoins the last two segments) and `gaSessionIdFromCookies` (collects every `_ga_*` cookie into one string). Absent or unparseable → `undefined`, never `""`.

Reading it via the cookie rather than the SDK also means the value is captured on `/auth` even though `posthog.init` has not run yet there.

### File manifest — 15 items

1. `db/migrate/<ts>_add_posthog_distinct_id_to_users.rb` — `class AddPosthogDistinctIdToUsers < ActiveRecord::Migration[6.1]`, `add_column :users, :posthog_distinct_id, :string`. Frozen-string header, no options, no index — matching all six existing attribution migrations.
2. `db/migrate/<ts+1>_add_posthog_distinct_id_to_organizations.rb` — same shape, `:organizations`. One migration per table, users first, organizations at the next sequential timestamp.
3. `db/schema.rb` — version bump plus one `t.string "posthog_distinct_id"` line in each block, hand-written. Do not stage the regenerated dump. Current version is `2026_07_27_185856`, so the new timestamps must exceed it.
4. `app/javascript/shared/lib/utils.js` — add `posthogDistinctId` to `adPlatformCookies()`, with a parse helper alongside `gaClientIdFromCookie` / `gaSessionIdFromCookies`. Goes through `attributionValue` like the others.
5. `app/javascript/ats/src/views/sessions/components/AuthForm.tsx` — add `posthogDistinctId` to the `magicLink(...)` payload and to the `<GoogleSSOButton>` props.
6. `app/javascript/ats/src/views/sessions/components/SignupForm.tsx` — same for the `register(...)` payload. No SSO button on this form.
7. `app/javascript/shared/queryHooks/useSession.ts` — **five edits**: `register`'s destructure and `variables`; `magicLink`'s destructure, its inline TS type block (lines 96-118), and `variables`.
8. `app/javascript/ats/src/views/sessions/components/GoogleSSOButton.tsx` — `Props` interface, destructure, and one hidden input `name="posthog_distinct_id"` using the house guard `typeof x === "string" && x.length > 0`.
9. `config/initializers/omniauth.rb` — append `posthog_distinct_id` to `allowed_keys`. **Easy to forget: without this the SSO value is silently dropped between the POST body and the session, and nothing errors.**
10. `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` — one more keyword arg `posthog_distinct_id: merged_tracking['posthog_distinct_id']`.
11. `app/models/user.rb#self.from_omniauth` — keyword parameter on the signature, and `omniauth_user.posthog_distinct_id = posthog_distinct_id` inside the `first_or_create` block. Note attribution is written **only on user creation**; an existing user re-authenticating never has it updated. That matches the 13 existing fields.
12. `app/controllers/api/v1/registrations_controller.rb` — add `:posthog_distinct_id` to `sign_up_params`, and add it to **both** branches of the `magic_create` if/else. **Easy to forget: the second branch.** The `create` action needs nothing beyond the permit — it mass-assigns.
13. `app/controllers/api/v1/organizations_controller.rb#create` — one line after line 44: `@organization.posthog_distinct_id = current_user.posthog_distinct_id`. Straight copy, no fallback. All 13 existing lines are already straight copies with zero fallbacks, so this matches exactly.
14. `app/models/user.rb#attribution_properties` — **decision required, see below.**
15. `app/models/subscription_event.rb#posthog_properties` — **leave alone.** Every row there wraps `attribution_value(owner.x, organization.x)`, which *is* the owner→organization fallback. Adding a row would give the new field the org fallback by construction, contradicting the requirement.

### Where the existing fallbacks actually live

Not at the organization copy — that is 13 straight assignments. The two fallbacks are:

1. **Frontend, URL-over-cookie** — `googleClickId` falls back to the `_gcl_aw` cookie and `liFatId` to the `li_fat_id` cookie (`AuthForm.tsx:44-49`, `SignupForm.tsx:29-34`). Those two fields only.
2. **`SubscriptionEvent#attribution_value`** (`subscription_event.rb:126-134`) — owner value, else organization value, else nil. All 13 fields route through it in `posthog_properties`.

The new field gets neither.

### Open decision

Does `posthog_distinct_id` belong in `User#attribution_properties` (`user.rb:495-511`)? That hash feeds the `user_signed_up` and `organization_owner_signed_up` PostHog events and their `$set_once` person properties, via `registrations#create`, `registrations#magic_create`, and `TrackNewSsoOwnerSignupJob`. Adding it changes three payloads at once. It has no effect on storage.

### No ripple sites

No spec file references any attribution field. No serializer exposes them. No data migration touches them. Nothing to backfill — the column is null for existing users by design.

---

## Conventions sign-off

`cursor_rules/backend/services.md` requires stating before implementation when a background job is queued from a callback. Block 3.4 does this, matching `SubscriptionEvent#handle_after_commit_on_create` (`subscription_event.rb:26,61`) and `complete_setup_workers`, which already do the same.

---

## Verification

Manual, against the running app and the live PostHog event feed.

1. Log in once — exercises `Posthog::Identify` and `Posthog::Track` through the real job path. Confirm the event carries `$groups`.
2. Change an organization's name — confirm a `$groupidentify` arrives with all ten properties.
3. Confirm browser requests go to `b.polymer.co` and server events still reach `us.i.posthog.com`.
4. Run the backfill; confirm the group count in PostHog.

`rails runner` scripts must call `POSTHOG_CLIENT.flush` before exiting or nothing sends — the gem batches on a background thread.

---

## Open decisions

1. `defaults: '2026-05-30'` in `posthog.init` — yes or no.
2. Backfill scope — `Organization.claimed` or `Organization.customers`.
