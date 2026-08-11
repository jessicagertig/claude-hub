# Completeness review — PostHog group analytics proposal

## (A) Gaps found and now filled

### A1. The single strongest argument for groups is already solved in this codebase — nobody checked

`groups-vs-alternatives` concludes "Feature flags are the strongest case, and it is not substitutable… there is no person-property trick that yields '50% of organizations, all-or-nothing per org.'" That was written without checking what inflow-ats already uses. It uses **Flipper, with the Organization as the actor**.

- `Gemfile:109-111` — `flipper-cloud`, `flipper-active_record`, `flipper-api`, all `~> 0.21.0`; resolved 0.21.0 (`Gemfile.lock:183-191`)
- `app/models/organization.rb:443-445` — `def flipper_id; "Organization-#{id}"; end`
- 13 org-actor call sites, e.g. `app/models/job.rb:697` `return unless Flipper.enabled?(:AI_APPLICANT_SUMMARY, organization)`; also `job_application.rb:185,247`, `channel_message.rb:89`, `docx_to_pdf_job.rb:11`, `validate_ai_summary_generation.rb:66`, `queue_bulk_ai_summary_jobs.rb:18`, `reset_daily_ai_credits.rb:15`, `validate_auto_ai_summary_generation.rb:27`, `api_public/v1/hire/base_controller.rb:73`, `job_application_notifications_controller.rb:21`, `api_keys_controller.rb:58`, `job_applications_controller.rb:116`
- Group-based targeting also already exists: `config/initializers/flipper.rb:4` registers `Flipper.register(:flipper_group_beta_testers)`, backed by the `organizations.flipper_group` enum column
- The frontend gets flags from `GET /api/v1/flipper/features` (`app/javascript/shared/queryHooks/useFeatureFlippers.ts:5`), not from PostHog
- Zero PostHog flag calls anywhere: no `get_feature_flag`, `is_feature_enabled`, `get_all_flags`, `useFeatureFlagEnabled`, `useActiveFeatureFlags` in `app/`, `lib/`, `config/`, or `app/javascript`

Org-consistent, all-or-nothing rollout is a solved problem here. What Flipper 0.21.0 does **not** give that PostHog groups would: percentage-of-organizations rollout, and targeting by org property (`plan`, `seats`, `created_at`) without hand-maintaining a Flipper group. That is the real, much narrower delta, and it never appears in any report.

### A2. PostHog region is US Cloud — confirmed, not assumed

`POSTHOG_API_KEY` is the only PostHog key present in `.env`; `POSTHOG_HOST` is not set. So `Variables::POSTHOG_HOST` takes its literal fallback `'https://us.i.posthog.com'` (`config/initializers/01_variables.rb:36`). Capture/batch backfill host is `https://us.i.posthog.com`; the private REST and `/query` host for read-back is `https://us.posthog.com`.

### A3. `person_profiles` default is `identified_only`, and `group()` latches person processing on permanently

Verified in the installed build, not from memory: `node_modules/posthog-js/lib/src/posthog-core.js:126` includes `person_profiles: 'identified_only'` in the default config object, and `PostHogContext.tsx:32-40` does not override it. `group()` calls `_requirePersonProcessing('posthog.group')` (`posthog-core.js:1895`), which registers `$epp` in persistence — every subsequent event on that browser becomes identified, including logged-out browsing, until a full `reset()`.

Scope limit that bounds the billing exposure: only `app/views/layouts/application.html.erb:78-79` sets the PostHog globals, and `PostHogProvider` is mounted only in `App.tsx:37` (the `ats_application` pack). The public careers page runs `job_board_application.js` under `job_board_application.html.erb`, which has no PostHog at all — public job-board traffic is not in the project and is not affected either way.

### A4. The logout reset is skippable, and it fails exactly in the case that matters

Confirmed chain, all four links read:

1. `app/javascript/shared/queryHooks/useMe.ts:88` — on a `me` error, `window.location.href = ${window.APP_ATS_ROOT_URL}/logout...`
2. `app/javascript/ats/src/views/sessions/Logout.tsx:14-28` — `resetUser()` lives **only** inside `logout(null, { onSuccess: ... })`
3. `app/javascript/shared/queryHooks/api.ts:53-61` — `apiMutate` `.catch(...)` returns `Promise.reject(normalizedError)` for any non-2xx, so the mutation errors and `onSuccess` never runs
4. `app/controllers/api/v1/sessions_controller.rb:25-31` — `destroy` renders `{ error: 'Logout failed' }, status: :unprocessable_entity` when `sign_out` is falsey, and Devise 4.8.1 `sign_out_all_scopes` ends in `users.any?` (`devise-4.8.1/lib/devise/controllers/sign_in_out.rb:95-104`) — false when nobody was signed in

So an already-expired session takes the redirect to `/logout`, gets a 422, and never calls `posthog.reset()`. Today that strands a `distinct_id`. With groups added it strands `$groups` in localStorage, which then rides every event the next person on that browser generates. Any proposal that says "we clear on logout" is relying on a path that does not always run.

### A5. Deriving the group key from the user is wrong for the two org-level event producers

`Posthog::Track#default_properties` resolves `@user.organization&.id` (`app/services/posthog/track.rb:27`), and `User#organization` is `current_organization_user&.organization` (`app/models/user.rb:206-208`). But:

- `app/models/subscription_event.rb:61` — `PosthogTrackJob.perform_later(organization.owner.id, event_type, event_properties)`
- `app/models/organization_ai_credit_purchase.rb:83` and `:91` — same shape

A user can hold several memberships (`app/models/user.rb:34` `has_many :organization_users`; `MeController#choose_organization_user` selects among `current_user.organization_users`, `me_controller.rb:18`). An owner of Org A who has switched to Org B produces `organization_id: B` on Org A's subscription event **today** — and would produce group key B under any scheme that derives `$groups` from the same expression. These two callers must pass the organization explicitly.

### A6. Nil organization must omit `groups:`, not send a null key

`@user.organization&.id` is nil for any user with no `current_organization_user` — including the whole signup window where `user_signed_up` and `organization_owner_signed_up` fire (`registrations_controller.rb:55-57`). posthog-ruby 2.11.0 validates nothing beyond `check_is_hash!(groups, 'groups')`, and `{}` still ships as `"$groups":{}` (`field_parser.rb:25-28`). So the guard is "omit the key entirely when the org is absent", never `{ organization: nil }` and never `{}`.

### A7. Backfilling 300 orgs attaches **zero** historical events — and the reports' `created_at` contradiction is moot

No report states this plainly. inflow-ats has never sent `$groups` on any event: zero `groups:`, `group_identify`, `$groups`, or `posthog.group(` call sites in `app/`, `config/`, `lib/`, or `app/javascript` (confirmed across both trace reports). Therefore no historical event carries a `$group_0` value at all, and the HogQL `created_at` masking rule (`if(timestamp < mapping.created_at, '', $group_N)`) has nothing to mask.

Consequence: a backfill of ~300 orgs produces group **rows** — profiles, properties, day-one flag/experiment targeting inputs — and nothing else. Every group-aggregated trend, funnel, and retention chart starts at the deploy date. The two reports' disagreement about whether `GroupTypeMapping.created_at` comes from the event timestamp (`groups-core-concepts`, citing `group-type-manager.ts`) or wall clock (`groups-api-and-backfill`, citing the Django model's `save`) does not need resolving for this migration.

### A8. The frontend `group()` call must pass properties, and 1.297.4 has no dedupe

Verified in the installed compiled build, not inferred from version numbers — `node_modules/posthog-js/lib/src/posthog-core.js:1904`:

```js
if (groupPropertiesToSet) {
    this.capture('$groupidentify', { $group_type: groupType, $group_key: groupKey, $group_set: groupPropertiesToSet });
    this.setGroupPropertiesForFlags(...);
}
```

No properties → no `$groupidentify` → no group exists server-side. With properties → an event **and** a `/flags` POST on **every** call. The existing identify effect (`AppAuthRouter.tsx:166-177`) already fires at least twice per cold load because `organizationName` and `currentPlan` arrive from a second query, so a naive `posthog.group()` in the same effect doubles up. Caller-side guard required: `posthog.getGroups()["organization"] !== String(organizationId)`.

### A9. "~300 orgs" has no scope, and the table holds non-customers

`organizations` also holds unclaimed scraped shells created by `app/site_scrapers/boards_scraper.rb:75` (`is_scrapable: true`, `kind: 'kind_scrapable'`, owner `system@inflowhq.com`). Existing scopes to choose from: `Organization.claimed` (`organization.rb:139`), `Organization.customers` (claimed + `PAID_PLANS`, `:142-144`), `Organization.subscribers` (`:141`).

---

## (B) Gaps still open

1. Given Flipper already provides org-consistent, all-or-nothing feature flags with `Organization` as the actor, what specifically do you want from PostHog groups that you do not have — percentage-of-orgs rollout, property-based org targeting, the group profile UI, or group-aggregated retention?
2. What exact string is the group key: `"5"`, `"org_5"`, or the existing `flipper_id` value `"Organization-5"` — given there is no rename or merge API and the choice is permanent?
3. Which organizations get backfilled: `Organization.claimed`, `Organization.customers`, or every row including the scraped shells?
4. What is the PostHog project's current monthly **identified** event volume, and is it under the add-on's 1,000,000/month free tier — since subscribing bills all identified events project-wide, not just grouped ones?
5. Are any group types already defined in the PostHog project, given the hard cap of 5 and that an index, once assigned, is never reassignable?
6. Which group properties do you want on the org, and what refreshes them — noting that `Organization`'s `after_commit` fires only on `stripe_subscription_status`, `plan`, `name`, `linkedin_company_id`, and `stripe_cancel_at_period_end` (`organization.rb:1023-1029`), that `users_count` / `jobs_count` / `published_jobs_count` change with no Organization callback at all, and that `set_default_plan`, `subscription_canceled_at`, `owner_id`, and `completed_setup` all use `update_column(s)` and skip callbacks entirely?
7. What `distinct_id` should server-side `group_identify` use, given that omitting it makes posthog-ruby synthesize `"$organization_5"` and create one fake person per organization?
8. Do you accept posthog-ruby 2.11.0 writing `$lib` and `$lib_version` into `$group_set` as permanent group properties on every call (`field_parser.rb:84`), or should the `~> 2.0` constraint in `Gemfile:122` be raised to reach the 3.10.0 fix?
9. On organization switch — which today calls no reset at all (`OrganizationSwitcher.tsx:60-73` does `queryClient.clear()` + `history.push` only) — is overwriting `$groups["organization"]` enough, or should the stored group-property flag cache be cleared too?
10. Do PostHog group property filters work on session replay: `groups-gotchas-and-limits` says yes, citing `events_subquery.py` source, while `groups-vs-alternatives` says undocumented and advises against relying on it — which is right?
11. Is the group-analytics add-on's tier table real: `groups-core-concepts` states the tiers "were not retrievable as static text," while `groups-vs-alternatives` prints a full six-row tier table attributed to the same page — which report actually read it?
12. Does the 6th group type get silently dropped: `groups-core-concepts` asserts it from `group-type-manager.ts`, while `groups-gotchas-and-limits` explicitly labels the same claim unverified — is the enforcement path the one that was read?