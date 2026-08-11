# PostHog group analytics — Organization as the group type

**Status:** proposal, nothing implemented
**Repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats` · branch `ai-credit-posthog-events`
**Research:** `research/` (11 reports, every claim cited to docs, package source, or repo `file:line`)

---

## 1. What exists today

Organization data already flows to PostHog — as flat person and event properties, never as a group.

| Layer | File | What it sends |
|---|---|---|
| Server identify | `app/services/posthog/identify.rb:11-21` | person props `email`, `created_at`, `organization_id`, `organization_name`, `plan`, `organization_user_role` |
| Server capture | `app/services/posthog/track.rb:13-17` | `default_properties` (`email`, `organization_id`, `organization_name`, `plan`) merged into **every** event |
| Browser identify | `app/javascript/shared/lib/posthog.ts:32-38` | the same five person props |
| Browser capture | `app/javascript/shared/lib/posthog.ts:41-50` | `trackEvent` → `ph.capture(event, properties)`; 69 call sites across 39 files |

`distinct_id` is `user.id.to_s` everywhere (`track.rb:14`, `identify.rb:12`, `track_new_sso_owner_signup_job.rb:25`, `lib/posthog.ts:32`).

`POSTHOG_CLIENT.group_identify` has **zero call sites**. `groups:` is passed nowhere. `posthog.group(` appears nowhere. Confirmed by repo-wide grep across `app/`, `lib/`, `config/`, `spec/`.

**Both SDKs already support groups.** `posthog-ruby 2.11.0` has `PostHog::Client#group_identify` (`lib/posthog/client.rb:136`) and `capture(groups:)` → `properties['$groups']` (`lib/posthog/field_parser.rb:25-28`). `posthog-js 1.297.4` has `group()`, `getGroups()`, `resetGroups()`. No upgrade is required to ship this.

---

## 2. The honest case for adopting groups

**Weaker than the textbook version, because Flipper already covers the strongest argument.**

`Organization#flipper_id` is `"Organization-#{id}"` (`app/models/organization.rb:443-445`), with 13 org-actor call sites (`app/models/job.rb:697`, `job_application.rb:185,247`, `channel_message.rb:89`, …) and a `flipper_group` enum column registered at `config/initializers/flipper.rb:4`. The frontend reads flags from `GET /api/v1/flipper/features` (`useFeatureFlippers.ts:5`). There are **zero PostHog feature-flag calls** anywhere. Org-consistent, all-or-nothing rollout is a solved problem here.

What genuinely remains:

1. **Percentage-of-organizations rollout and org-property targeting** — Flipper 0.21.0 gives you allowlists and hand-maintained groups; PostHog hashes the group key, so "50% of orgs" and "orgs on `plan_ats_tier_scale_v2`" come free.
2. **The account-object UI** — group profile pages, the Groups tab, Customer Analytics **B2B mode** (gated on the add-on outright). This is the CS / account-health surface.
3. **Point-and-click group aggregation** — `Unique groups` in Trends, funnel `Aggregating by` with a per-org drop-off list, group-cohort retention (logo churn). All reachable today via `uniq(properties.organization_id)` in a SQL insight; what you buy is access for non-SQL teammates.
4. **The clock.** `$group_N` is written onto the event row at ingest. There is no backfill — [PostHog#11224](https://github.com/PostHog/posthog/issues/11224) is closed as not planned, and Amplitude and Mixpanel are identical ("Changes to account groups and group properties apply to new data and don't affect historical data"). Group history starts the day you deploy.

**Do not adopt groups for:** cohorts (explicitly unsupported — [cohorts docs](https://posthog.com/docs/data/cohorts)), lifecycle insights, user paths, or session replay (works per PostHog source, undocumented, and event-property filtering works today).

The tiebreaker is #4. The code below is cheap, and it is inert and unbilled until you subscribe to the add-on — which converts an irreversible timing decision into a reversible billing one.

---

## 3. Design decisions

| # | Decision | Value | Why |
|---|---|---|---|
| D1 | Group type name | `"organization"` | Singular, per docs. Becomes `group_type_index 0` — permanently, no rename or merge API exists. |
| D2 | Group key | `organization.id.to_s` | `organizations` has no UUID, slug, or `hash_id` (`db/schema.rb:1033-1101`; the one `uuid` column is `zapier_api_key`, a credential). The integer PK is already what `organization_id` carries in every existing event. Immutability is the only criterion that matters — there is no rename, merge, or per-group delete. |
| D3 | Keep `organization_id` as an event property | permanently | It is the only handle on pre-adoption history, it works in cohorts (groups do not), and it survives the group-type delete/recreate timestamp trap. Costs nothing. |
| D4 | Group properties | `name`, `plan`, `stripe_subscription_status`, `users_count`, `published_jobs_count`, `created_at` | `name` is required — PostHog displays the group key when absent, and a group with **zero** properties is invisible in the UI entirely. |
| D5 | `distinct_id` on `group_identify` | static `'groups_setup_id'` | Omitting it makes the gem synthesize `"$organization_5"` (`field_parser.rb:73`) — one fake person **per organization**. The static string is what PostHog documents and costs one junk person total. |
| D6 | Browser `group()` passes **no** properties | — | It only needs to register the `$groups` super property so browser events carry it. The backend owns property writes. This emits zero extra browser events and sidesteps both known 1.297.4 group bugs. |
| D7 | Backfill mechanism | the same ActiveJob, over `Organization.claimed` | ~300 rows. The `/batch/` + `historical_migration` apparatus is for millions of events; reusing the job is one rake task. |

**On D7's scope:** `organizations` also holds unclaimed scraped shells created by `app/site_scrapers/boards_scraper.rb:75` (`is_scrapable: true`, `kind: 'kind_scrapable'`, owner `system@inflowhq.com`). `Organization.claimed` (`organization.rb:139`) excludes them. `Organization.customers` (`:142-144`, claimed + `PAID_PLANS`) is the narrower alternative.

---

## 4. The change

**7 files: 2 new, 5 modified. No new specs** — `.claude/CLAUDE.md §0a` prohibits writing RSpec, and there is zero existing PostHog test coverage to extend.

### 4.1 `app/services/posthog/identify_organization.rb` — NEW

Mirrors `Posthog::Identify` exactly: same directory, same `return unless POSTHOG_CLIENT` guard, same method-level rescue-and-log, keyword-arg initializer, descriptive method name (not `call`).

```ruby
# frozen_string_literal: true

class Posthog::IdentifyOrganization
  def initialize(organization:)
    @organization = organization
  end

  def identify
    return unless POSTHOG_CLIENT

    POSTHOG_CLIENT.group_identify({
                                    group_type: 'organization',
                                    group_key: @organization.id.to_s,
                                    distinct_id: 'groups_setup_id',
                                    properties: group_properties
                                  })
  rescue StandardError => e
    Rails.logger.error("[PostHog] IdentifyOrganization failed: #{e.message}")
  end

  private

  def group_properties
    {
      name: @organization.name,
      plan: @organization.plan,
      stripe_subscription_status: @organization.stripe_subscription_status,
      users_count: @organization.users_count,
      published_jobs_count: @organization.published_jobs_count,
      created_at: @organization.created_at&.iso8601
    }
  end
end
```

### 4.2 `app/jobs/posthog_identify_organization_job.rb` — NEW

Byte-for-byte the shape of `PosthogIdentifyJob`.

```ruby
# frozen_string_literal: true

class PosthogIdentifyOrganizationJob < ApplicationJob
  queue_as :default

  def perform(organization_id)
    organization = Organization.find_by(id: organization_id)
    return unless organization

    Posthog::IdentifyOrganization.new(organization: organization).identify
  end
end
```

### 4.3 `app/services/posthog/track.rb` — MODIFIED

Adds `groups:` to the capture, and an explicit `organization:` so the two organization-owned event producers resolve the right org.

```ruby
class Posthog::Track
  def initialize(user:, event:, properties: {}, organization: nil)
    @user = user
    @event = event
    @properties = properties
    @organization = organization || user.organization
  end

  def track
    return unless POSTHOG_CLIENT

    POSTHOG_CLIENT.capture(capture_attributes)
  rescue StandardError => e
    Rails.logger.error("[PostHog] Track failed: #{e.message}")
  end

  private

  def capture_attributes
    attributes = {
      distinct_id: @user.id.to_s,
      event: @event,
      properties: default_properties.merge(@properties)
    }
    attributes[:groups] = { organization: @organization.id.to_s } if @organization
    attributes
  end

  def default_properties
    {
      email: @user.email,
      organization_id: @organization&.id,
      organization_name: @organization&.name,
      plan: @organization&.plan
    }
  end
end
```

`groups:` is **omitted entirely** when there is no organization — never `{}`. The gem sends `"$groups":{}` for an empty hash (`field_parser.rb:25-28`, verified by execution), and `@user.organization` is nil for the whole signup window where `user_signed_up` and `organization_owner_signed_up` fire (`registrations_controller.rb:55-57`).

### 4.4 `app/jobs/posthog_track_job.rb` — MODIFIED

Trailing optional positional param, so all 20 existing `perform_later` call sites are untouched and in-flight jobs still deserialize.

```ruby
  def perform(user_id, event, properties = {}, organization_id = nil)
    user = User.find_by(id: user_id)
    return unless user

    organization = Organization.find_by(id: organization_id) if organization_id.present?

    Posthog::Track.new(user: user, event: event, properties: properties.deep_symbolize_keys, organization: organization).track
  end
```

### 4.5 `app/models/subscription_event.rb:61` and `app/models/organization_ai_credit_purchase.rb:83,91` — MODIFIED

These three call sites pass `organization.owner.id` as the distinct_id but currently let `Posthog::Track` resolve the organization from `@user.organization`, which is `current_organization_user&.organization` (`app/models/user.rb:206-208`). An owner who holds memberships in several organizations and has switched to Org B produces `organization_id: B` on **Org A's** subscription event today. Pass the organization explicitly:

```ruby
    PosthogTrackJob.perform_later(organization.owner.id, event_type, event_properties, organization.id)
```

> **This is a behavior change beyond the group work.** It corrects `organization_id` / `organization_name` / `plan` on these events for multi-org owners. Scoped to exactly these three call sites; every other caller passes nil and is byte-identical to today. Flagging it because a group key and an `organization_id` property that disagree would be worse than either alone — your call whether to take it.

### 4.6 `app/models/organization.rb` — MODIFIED

Two enqueue points. `.claude/CLAUDE.md` permits feature changes (methods, enums, callbacks) to this file.

In `complete_setup_workers` (`:180-190`, the existing `after_commit … on: [:create]` chain), and a new branch method added to `handle_after_commit_on_update` (`:1023-1029`) alongside the five that already exist:

```ruby
  POSTHOG_GROUP_PROPERTY_COLUMNS = %w[name plan stripe_subscription_status].freeze

  def handle_posthog_group_properties_change_after_commit
    return unless (saved_changes.keys & POSTHOG_GROUP_PROPERTY_COLUMNS).any?

    PosthogIdentifyOrganizationJob.perform_later(id)
  end
```

Gating on `saved_changes` matches how the five existing branch methods work (`:1074`, `:1105`, `:1066`, `:1207`, `:1215`) and avoids a billable `$groupidentify` on every unrelated settings write.

**Two known staleness gaps, disclosed rather than chased:**
- `users_count` and `published_jobs_count` are `counter_culture` columns on child models (`organization_user.rb:9`, `job.rb:29`). They change with **no Organization callback**, so they refresh only on the next name/plan/status change. Cut them from D4 if that is not acceptable.
- `set_default_plan` (`:226`), `subscription_canceled_at` (`stripe_webhook_handler_job.rb:208`), `owner_id`, `completed_setup`, and the clearbit fields all use `update_column(s)` and bypass callbacks entirely. The steady-state plan writer, `sync_with_stripe` (`:566-601`), uses `update(changes_to_make)` and **does** fire.

### 4.7 `app/javascript/shared/lib/posthog.ts` — MODIFIED

```ts
function identifyOrganization(organizationId: number): void {
  const ph = getPosthog();
  if (!ph) {
    window.logger("%c[PostHog] identifyOrganization skipped - not loaded", "background-color: #FF76D2", { organizationId });
    return;
  }

  const groupKey = String(organizationId);
  if (ph.getGroups()["organization"] === groupKey) return;

  window.logger("%c[PostHog] identifyOrganization", "background-color: #FF76D2", { organizationId });
  ph.group("organization", groupKey);
}
```

The key-equality guard is load-bearing on 1.297.4: `group()` with a changed key and no properties calls `reloadFeatureFlags()` — a `/flags` POST — on every invocation (`posthog-core.ts:2274-2277`), and the surrounding effect already re-fires several times per cold load.

Export it alongside `identifyUser`, `trackEvent`, `resetUser` (`:59`).

### 4.8 `app/javascript/ats/src/views/layouts/AppAuthRouter.tsx:163-177` — MODIFIED

Inside the existing identify effect, **after** `identifyUser`:

```tsx
      if (organizationId != undefined) {
        identifyOrganization(organizationId);
      }
```

Order matters on 1.297.4: `group()` before `identify()` trips a one-shot latch that permanently loses `$initial_utm_source`, `$initial_referrer`, and the rest of the initial-attribution set ([PR #2725](https://github.com/PostHog/posthog-js/pull/2725), fixed in 1.306.0 — not in this build). The bug only fires when `group()` passes properties, which D6 avoids, but the ordering is free.

**Org switch needs no extra code.** `OrganizationSwitcher.tsx:60-73` does `queryClient.clear()` + `history.push`; the effect re-fires with the new `organizationId` and `group()` overwrites `$groups["organization"]`, and clears the stale flag-property cache itself when the key changes (`posthog-core.ts:2258-2260`). Verified in the installed source.

### 4.9 `lib/tasks/one_off_tasks.rake` — MODIFIED (backfill)

```ruby
  desc 'Create PostHog organization groups for existing organizations'
  task backfill_posthog_organization_groups: :environment do
    Organization.claimed.find_each do |organization|
      PosthogIdentifyOrganizationJob.perform_later(organization.id)
    end
  end
```

~300 jobs. Well under every documented limit (the per-`distinct_id` ingestion protection kicks in around 5,000 events/minute).

**A backfill creates group rows and nothing else.** No historical event carries `$group_0` — inflow-ats has never sent `$groups`. Every group-aggregated trend, funnel, and retention chart starts at the deploy date. That is not a defect in this plan; it is the constraint from §2 #4.

---

## 5. Convention note requiring your sign-off before implementation

`cursor_rules/backend/services.md` ends with: *"**IMPORTANT**: If you plan to use these patterns [service calling another service, service queueing a background job], explicitly state this to the user before implementing."*

This proposal has a **model `after_commit` callback queueing a background job** (§4.6). That is the same pattern `SubscriptionEvent#handle_after_commit_on_create` already uses to reach PostHog (`subscription_event.rb:26,61`), and `complete_setup_workers` already uses for four other jobs. Stating it as the rule requires.

---

## 6. Rollout order

1. Ship §4. Events start carrying `$groups`; `$groupidentify` starts creating group rows.
2. Verify in PostHog with HogQL:
   `SELECT index, count() AS groups, max(created_at) FROM groups GROUP BY index`
   and `SELECT event, $group_0 FROM events WHERE $group_0 != '' ORDER BY timestamp DESC LIMIT 20`
3. Run the backfill rake task.
4. **Subscribe to the add-on last.** Billing starts when you toggle it on the billing page, not when the code deploys — and it then bills **all identified events project-wide**, not just group-tagged ones. First 1,000,000 events/month are free, then $0.000071/event ([posthog.com/addons](https://posthog.com/addons)).

---

## 7. Known defects this surfaces but does not fix

| What | Where | Why it matters more with groups |
|---|---|---|
| Logout reset is skippable | `Logout.tsx:12-28` — `resetUser()` lives only inside `logout(null, { onSuccess })`; an already-expired session gets a 422 from `sessions_controller.rb:25-31` and never resets | Today this strands a `distinct_id`. With groups it strands `$groups` in localStorage, which then rides every event the next person on that browser generates. Minimal fix is moving `resetUser()` out of `onSuccess` — a change to `Logout.tsx`, out of scope here. |
| `TrackNewSsoOwnerSignupJob` bypasses `Posthog::Track` | `track_new_sso_owner_signup_job.rb:24` calls `POSTHOG_CLIENT.capture` directly | Its four events already carry no `organization_id`/`organization_name`/`plan`, and will carry no `$groups` either. The org does not exist yet at that point in signup, so this is arguably correct — noting it so it is a decision, not an oversight. |
| `$lib` / `$lib_version` land inside `$group_set` | `posthog-ruby 2.11.0` `field_parser.rb:84` | Every `group_identify` writes two junk properties onto the group. Cosmetic. Fixed in posthog-ruby 3.10.0 — see the SDK upgrade section. |
| Five `SubscriptionEvent` enum values never reach PostHog | `subscription_event.rb:251-253`, the `else → return` | Pre-existing, unrelated to groups, and it contradicts the enum comments at `:9` and `:15` which claim those values are "sent to PostHog". |

---

## 8. SDK upgrades — blast radius

**These are two entirely separate packages with separate version lines, separate call sites, and separate upgrades. They share only the API key.** Nothing below crosses between them.

| | Backend | Browser |
|---|---|---|
| Package | `posthog-ruby` (RubyGems) | `posthog-js` + `@posthog/react` (npm) |
| Declared in | `Gemfile:122` | `package.json:70` and `:31` |
| Pinned at | 2.11.0 | 1.297.4 / 1.0.0 |
| Latest | 3.23.0 | 1.414.0 / 1.10.3 |
| Client built at | `config/initializers/posthog.rb:5` (`POSTHOG_CLIENT`) | `PostHogContext.tsx:33` (`posthog.init`) |
| Gem/package API call sites | 3 | 2 files |
| Upgrade touches | `Gemfile` + 1 initializer line | 2 `package.json` lines |

Three different version numbers appear below and must not be conflated: **the posthog-ruby gem version** (2.11.0 → 3.23.0), **the Ruby language version** (this app runs 3.1.6), and **the posthog-js package version** (1.297.4 → 1.414.0).

Neither upgrade is required for groups. Both SDKs at their pinned versions already support everything §4 needs. Both upgrades are mechanical.

### 8.1 BACKEND — `posthog-ruby` gem, 2.11.0 → 3.23.0 — **2 files, 1 real break**

**2.11.0 is the last 2.x release** (2025-05-20); 3.0.0 shipped the same day, and there have been 55 releases in the 3.x line since, latest 3.23.0 (2026-08-05). No 4.x.

**The one hard break:** 3.0.0 deleted the require shim `lib/posthog-ruby.rb`. Verified directly — the file is present in the installed 2.11.0 gem (85 bytes, contents `require 'posthog'`), and `raw.githubusercontent.com/PostHog/posthog-ruby/3.0.0/lib/posthog-ruby.rb` returns **404** while the 2.11.0 path returns 200. So `config/initializers/posthog.rb:3`'s `require 'posthog-ruby'` raises `LoadError` on 3.x.

The entire code change:

```ruby
# Gemfile:122
gem 'posthog-ruby', '~> 3.23', require: 'posthog'

# config/initializers/posthog.rb:3
require 'posthog'
```

Everything else compiles unchanged. `capture`, `identify`, and `group_identify` still take a single positional Hash with no renamed keys. `on_error`, `host`, `api_key` are unchanged. The only other namespace change — `class PostHog` (2.11.0 `client.rb:11`) → `module PostHog` — cannot bite: the repo never reopens `PostHog`, and the app's own `Posthog::` (lowercase `h`) is a distinct constant because `config/initializers/inflections.rb` defines no acronyms.

- **Gem API call sites: 3** (`track.rb:13`, `identify.rb:11`, `track_new_sso_owner_signup_job.rb:24`) — none require changes.
- **Indirect enqueue sites: 27** — none require changes.
- **Spec files: 0.** `grep -rn -i posthog spec/` returns nothing across all 19 files. No VCR cassettes, no WebMock stubs.
- **Dependencies:** byte-identical (`concurrent-ruby ~> 1`, confirmed via the RubyGems API). Nothing else in `Gemfile.lock` depends on `posthog-ruby`.

**Two non-code decisions:**

1. **The gem's stated Ruby-language floor conflicts with the one it enforces.** posthog-ruby's changelog entry for **gem version 3.0.0** says *"The minimum supported version is now Ruby 3.2."* The constraint actually **enforced** by every 3.x gemspec is `required_ruby_version = '>= 3.0'`. This app runs **Ruby 3.1.6** (`.ruby-version`, `Gemfile:6`) — above the enforced floor, below the documented one. Bundler enforces the gemspec, so the gem installs and runs; verified by parsing every file in gem 3.23.0 under Ruby 3.1.6 and executing this repo's exact call shapes. But it is a configuration the vendor's own prose disclaims. Your call. (Nothing here concerns posthog-js — the browser package declares no `engines` constraint at all.)
2. **Two silent data changes in PostHog.** 3.10.0 adds `"$is_server": true` to every server-side event; 3.12.2 drops the top-level `library`, `library_version`, and `messageId` fields and always sends a `uuid`. If any existing insight, cohort, or funnel filters on those, check it before deploying.

**Relevance to groups:** 3.10.0 fixes the `$lib` / `$lib_version` pollution of `$group_set` (§7). That is the only group-related gain, and it is cosmetic.

**On "PostHog wants us to upgrade":** there is no deprecation or EOL statement anywhere — not in the docs, the README, the handbook, and no 2.x version is yanked. What does exist is [PostHog's SDK health check](https://posthog.com/docs/sdk-doctor), which monitors `posthog-ruby` and *"Always flagged if you're not on the current major version."* So the project is flagged as out of date, one major behind and ~15 months old — but 2.x is not deprecated.

### 8.2 BROWSER — `posthog-js` 1.297.4 → 1.414.0 and `@posthog/react` 1.0.0 → 1.10.3 — **2 version strings, 0 source files**

Nothing in this section involves the Ruby gem, the Ruby language version, or any file under `app/services/` or `app/jobs/`.

**There is no 2.x** — filtering the packument for major ≥ 2 returns empty. 347 releases and 117 minor boundaries separate 1.297.4 from 1.414.0, with **zero `### Major Changes` sections** across the whole range.

**1.297.4 is not deprecated** (`deprecated: null`). npm deprecation notices on this package stop at 1.126.0; everything from 1.127.0 up is clean, and npm's `previous` dist-tag points at 1.297.4 itself.

The mechanism that makes 347 releases non-breaking is an opt-in `defaults: ConfigDefaults` key, default `'unset'` = legacy behavior everywhere. This repo passes no `defaults`, so every default is frozen.

Both patterns you'd worry about survive:
- **`posthog.__loaded`** is still a declared public property, `__loaded: boolean` at `posthog-js@1.414.0/dist/module.d.ts:2835`, unmentioned in 347 releases of changelog. The guards at `shared/lib/posthog.ts:14` and `PostHogContext.tsx:14` need no change.
- **`<PHProvider client={posthog}>`** — `PostHogProviderProps` is the same discriminated union in 1.0.0 and 1.10.3, `client` still the first branch. The provider does not self-initialize when given a `client`, so `posthog.init()` at `PostHogContext.tsx:33` keeps ownership.

Neither package ships an `exports` map or `"type": "module"` — verified against the real published `package.json`. That is the failure mode that normally kills webpack-4 upgrades, and it does not apply. Both dist bundles contain zero `?.`, `??`, logical assignment, private class fields, or `async`/`await`, so webpack 4's parser handles them. `@posthog/react@1.10.3` requires `react >=16.8.0`; this repo is on 16.14.0.

- **Files requiring edits: 2** — `package.json:70` and `package.json:31`, plus a `yarn.lock` regeneration. **Zero application source files.**
- **Call sites: 71** (69 `trackEvent`, 1 `identifyUser`, 1 `resetUser`) across 42 files — none require changes, because all route through `@shared/lib/posthog`.
- **Test files: 0.** The repo has two Jest tests total and neither touches PostHog. `jest.config.js` has no `transform` and no `transformIgnorePatterns`, and it does not matter: nothing imports posthog in a test.

**One cosmetic cost:** `@posthog/react@1.10.3`'s `.d.ts` does `import { JSX } from 'react'`, which `@types/react@16.14.5` does not export (it is a global namespace there). That adds **one** TypeScript error to the **186** `node_modules`-only errors the repo already carries under `tsc --noEmit` — zero of which are in app code. `fork-ts-checker-webpack-plugin` runs only in `config/webpack/development.js` and is absent from production, so production builds do not type-check at all. `"skipLibCheck": true` in `tsconfig.json` clears all 187 in one line.

**Relevance to groups:** 1.364.7 makes `group()` emit `$groupidentify` even with no properties, and 1.306.0 fixes losing initial person props when `group()` runs before `identify()`. §4's design (D6 — browser passes no properties; §4.8 — identify first) sidesteps both, so neither is a reason to upgrade.

### 8.3 What each upgrade does to the warning PostHog shows

The alert comes from [SDK doctor](https://posthog.com/docs/sdk-doctor), which monitors both packages and applies these thresholds verbatim:

> "Major versions: Always flagged if you're not on the current major version… Minor versions: Flagged if 3+ minor versions behind, or more than 6 months old. Patch versions: Never flagged."

| Package | Why it is flagged now | After upgrading |
|---|---|---|
| `posthog-ruby` | **Major** — on 2.11.0 while 3.x exists. Also ~15 months old. | Clears, and stays clear until a gem 4.x ships. |
| `posthog-js` | **Minor** — 117 minor versions and ~8.5 months behind. Never flagged on major; there is no 2.x. | Clears, then **re-flags in roughly 4–6 months.** posthog-js ships a minor every ~2 days, so 3-behind is reached within days and the 6-month clock starts at the deploy. |

So the backend upgrade is a durable fix and the browser upgrade is recurring maintenance. If the goal is a quiet dashboard for non-technical teammates, the browser package needs a standing bump cadence, not a one-off.

---

## 9. Questions only you can answer

1. What is the PostHog project's current monthly **identified** event volume? The add-on's free tier is 1,000,000/month, and subscribing bills *all* identified events project-wide — not just grouped ones. This decides cost, not code.
2. Are any group types already defined in the project? The cap is 5 and an index, once assigned, is never reassignable.
3. Backfill scope — `Organization.claimed`, or the narrower `Organization.customers`?
