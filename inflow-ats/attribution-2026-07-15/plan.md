# Implementation Plan — UTM capture + identify/funnel events (attribution)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats` (from `REPO-PATH`), branch `attribution-work` (off `develop`), at `62dd55867` at planning time.
**Binding spec:** `/Users/jessica/claude-hub/inflow-ats/attribution-2026-07-15/SPEC.md` (amended, survived 5-round review — READY FOR PLANNING).
**Binding decisions:** `/Users/jessica/claude-hub/inflow-ats/attribution-2026-07-15/approved-decisions.md` (D1–D10, D12–D17; no D11). This plan introduces NO new design decisions; where the spec left something plan-level (helper internals, state shape, timestamps), the choice is called out inline as "plan choice".
**Pre-existing working-tree state that is part of this feature:** `app/javascript/shared/lib/posthog.ts` has an uncommitted diff (`window.logger` added to `identifyUser`'s fire path and not-loaded skip path). **Commit it as-is with this PR. Make no further edit to that file.**

---

## Summary

Two changes in one PR. (1) **UTM capture:** four new nullable columns on `users` and `organizations` — `utm_source` (string), `utm_campaign` (string), `utm_data` (jsonb), `internal_ref` (string) — captured from `location.search` on the auth pages by a new `sanitizeTrackingParams` helper in `app/javascript/shared/lib/utils.js`, threaded through the `magicLink`/`register` JSON payloads and the Google SSO hidden-form path (omniauth `setup` lambda → `session[:oauth_tracking]` → `User.from_omniauth`, converted to all-keyword arguments), written raw onto the `User` at row creation only, and copied from `current_user` onto the new `Organization` in `Api::V1::OrganizationsController#create`. No defaults, no backfill, absent params stay nil at every layer. (2) **Funnel events + identify (browser-first):** five new browser PostHog events via the existing `trackEvent`/`identifyUser` helpers — `user_signed_up_client_side` (AuthForm/SignupForm mutation onSuccess), `email_verified` + `identifyUser({ id, email })` at the `/auth?email_confirmed=true` landing (the confirmation redirect gains `id` and URL-encoded `email` params), `organization_created` (OrganizationForm onSuccess), and `organization_owner_user_name_submitted` / `invited_user_name_submitted` (ProfileForm onSuccess, keyed on `isNewOwner`). All existing server-side `PosthogTrackJob`/`PosthogIdentifyJob` calls stay byte-identical as backup.

## Pattern precedents (verified in live code at planning time)

| Pattern | Analog location | Used for |
|---|---|---|
| Query-param capture into component state | `app/javascript/ats/src/views/sessions/components/AuthForm.tsx:37-38` (`referral`, `partner`), `SignupForm.tsx:23` (`referral`) | F3/F4 capture |
| Tracking threading through signup payloads | `referral`/`partner`: `AuthForm.tsx` `handleAuth` (lines 70–98) → `useSession.ts` `magicLink` (lines 41–82) / `register` (lines 27–39) → `sign_up_params` (registrations_controller.rb:302) → `user_params` both branches (lines 88–107) | F2/F3/F4, B3 |
| Hidden tracking inputs on the SSO form | `GoogleSSOButton.tsx:46-51` (`referral`/`partner`, guard `typeof referral === "string" && referral.length > 0`) | F5 |
| Omniauth tracking whitelist + session ride | `config/initializers/omniauth.rb:12-27` `setup` lambda, `allowed_keys` line 14 | B5 |
| Tracking recovery in the callback | `app/controllers/api/v1/users/omniauth_callbacks_controller.rb:9-22` (`session.delete(:oauth_tracking)`, `merged_tracking`, string keys) | B6 |
| Creation-time-only attribute assignment | `app/models/user.rb:379-406` `from_omniauth` `first_or_create` block (`created_via`, `partner_source&.downcase`) | B6 |
| Parent→child attribute copy at org creation | `app/controllers/api/v1/organizations_controller.rb:31` (`@organization.created_via = current_user.created_via`) | B4 |
| Arbitrary-key jsonb permit | `app/controllers/api/v1/questions_controller.rb:50` (`permit(..., options: {})` — trailing hash-permit into `questions.options` jsonb) | B3 |
| Query-param helper placement | `app/javascript/shared/lib/utils.js` — `standardizeQueryParamsObject` at top of file (lines 9–19) | F1 |
| Browser event in a mutation onSuccess | `app/javascript/ats/src/components/modals/NewJobCenterModal.tsx:47` (`trackEvent("job_created", ...)` inside `createJob` onSuccess), `CommentTemplateModal.tsx:100` (plain no-property `trackEvent("review_template_created")`) | F3/F4/F7/F8 |
| Browser identify | `app/javascript/ats/src/views/layouts/AppAuthRouter.tsx:165-177` (`identifyUser` effect; keys on `currentUser.id`) | F6 |
| Add-columns migration shape | `db/migrate/20260622182504_add_ai_summary_and_criteria_columns_to_jobs.rb` (`ActiveRecord::Migration[6.1]`, plain `add_column`; NOTE its `default: 0, null: false` is exactly what the new migrations must NOT have — D6) | B1/B2 |
| Controller-spec conventions | `spec/controllers/api/v1/organization_ai_credit_purchases_purchase_top_up_spec.rb` (type: :controller; `allow(controller).to receive(:authenticate_api_v1_user!)` / `:current_user` / `:authorize`; manual `create!` record helpers, no FactoryBot); `spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb:6-14` (`include Devise::Test::ControllerHelpers` per-file at line 7; `around` block switching `ActiveJob::Base.queue_adapter` to `:test`) | T2–T6 |
| Jest precedent | `app/javascript/ats/src/components/shared/Button/Button.test.tsx` (relative import `./index.js`); config `jest.config.js` | T1 |

**Approved deviations from the analogs (spec-mandated — do NOT "fix" these to match the analog):**
1. The analog downcases and maps (`partner_source&.downcase`, `get_created_via`); the four new values are stored **raw as sent** (D3).
2. The analog's `from_omniauth` is positional; this PR converts it (and every call site) to all-keyword form (D9).
3. The analog fires server-side PostHog jobs; the new events are browser-side (funnel-audit ruling). No `PosthogTrackJob`/`PosthogIdentifyJob` added, removed, or modified.
4. `utm_data` inner keys stay raw URL param names, not camelCased (D2; accepted exception to the frontend JSONB-camelCase rule, like the Ruby-enum exception).
5. The migrations omit the `default: {}, null: false` that the sibling `settings` jsonb columns carry (D6 — nil-for-absent).

## Check-before-create verification (performed at planning time; implementer re-verifies)

- [ ] C.1 `users`/`organizations` have NO `utm_source`/`utm_campaign`/`utm_data`/`internal_ref` columns today (`db/schema.rb` lines 1244–1286 and 1033–1090; the only `utm_*` columns in the schema are on `ahoy_visits` — unrelated, untouched). Re-verify: `grep -n "utm_source" db/schema.rb`.
- [ ] C.2 `sanitizeTrackingParams` does not exist anywhere (`git grep sanitizeTrackingParams` → no matches).
- [ ] C.3 None of the five event-name strings exists anywhere (`git grep -E "user_signed_up_client_side|\"email_verified\"|\"organization_created\"|organization_owner_user_name_submitted|invited_user_name_submitted" app/` → no matches; only incidental substrings `organization_created_via` and a comment `email_verified:` in `app/services/smtp_email_validator.rb:113` exist — leave untouched).
- [ ] C.4 None of the six test files exists: `spec/controllers/api/v1/` contains only the three AI-credit specs; `spec/controllers/hire/` and `spec/controllers/api/v1/users/` do not exist (create the directories); `spec/models/user_from_omniauth_spec.rb` and `app/javascript/shared/lib/utils.test.js` do not exist.
- [ ] C.5 `git grep -ln "from_omniauth"` returns exactly two files today: `app/models/user.rb` (definition, line 379) and `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` (sole call site, line 22). **Re-run at implementation time — do not rely on this list (D9).**
- [ ] C.6 `app/javascript/shared/lib/posthog.ts` is the ONLY uncommitted change on the branch (`git status --porcelain` → ` M app/javascript/shared/lib/posthog.ts`). If anything else is dirty at implementation start, stop and surface it.

## Files to create or modify

**New files (4 source-adjacent, 6 test):**
1. `db/migrate/<ts1>_add_attribution_columns_to_users.rb` — four `add_column :users` lines.
2. `db/migrate/<ts2>_add_attribution_columns_to_organizations.rb` — four `add_column :organizations` lines (`<ts2>` > `<ts1>`).
3. `spec/controllers/api/v1/registrations_controller_spec.rb`
4. `spec/models/user_from_omniauth_spec.rb`
5. `spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb`
6. `spec/controllers/api/v1/organizations_controller_spec.rb`
7. `spec/controllers/hire/confirmations_controller_spec.rb`
8. `app/javascript/shared/lib/utils.test.js`

**Modified files (6 backend + 9 frontend incl. posthog.ts + schema):**
9. `app/controllers/api/v1/registrations_controller.rb` — `sign_up_params` permit + `magic_create` `user_params` merge (both branches).
10. `app/controllers/api/v1/organizations_controller.rb` — `create` copies four values from `current_user`.
11. `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` — line 22 call converted to keyword form with four new values.
12. `app/models/user.rb` — `from_omniauth` keyword signature + four assignments inside the `first_or_create` block. NO other change to this file.
13. `config/initializers/omniauth.rb` — line 14 `allowed_keys` grows by four entries.
14. `app/controllers/hire/confirmations_controller.rb` — line 18 success redirect gains `id` + URL-encoded `email`.
15. `app/javascript/shared/lib/utils.js` — new `sanitizeTrackingParams` helper + `query-string` import.
16. `app/javascript/shared/queryHooks/useSession.ts` — `magicLink` and `register` request functions gain the four fields.
17. `app/javascript/ats/src/views/sessions/components/AuthForm.tsx` — capture, payload, SSO props, `user_signed_up_client_side`.
18. `app/javascript/ats/src/views/sessions/components/SignupForm.tsx` — capture, payload, `user_signed_up_client_side`.
19. `app/javascript/ats/src/views/sessions/components/GoogleSSOButton.tsx` — four new Props + hidden inputs.
20. `app/javascript/ats/src/views/sessions/Auth.tsx` — second `useEffect` keyed on `emailConfirmed`: guarded `identifyUser` + `email_verified`.
21. `app/javascript/ats/src/views/sessions/components/OrganizationForm.tsx` — `organization_created` in onSuccess.
22. `app/javascript/ats/src/views/sessions/components/ProfileForm.tsx` — `organization_owner_user_name_submitted` / `invited_user_name_submitted` in onSuccess.
23. `db/schema.rb` — regenerated by `db:migrate` (commit it).
24. `app/javascript/shared/lib/posthog.ts` — ALREADY MODIFIED on disk; commit as-is, zero further edits.

## Do-NOT-touch list (reviewer verifies zero diff)

- Serializers — `app/serializers/**` (incl. `Api::V1::SessionSerializer`, `Api::V1::OrganizationSerializer`). The four columns are NOT serialized.
- Policies — `app/policies/**`. `organizations#create` keeps its existing `authorize @organization` unchanged.
- Models other than `app/models/user.rb` — especially `app/models/organization.rb` (needs no edit; repo restricts edits there).
- Sidekiq/ActiveJob files and every `PosthogTrackJob`/`PosthogIdentifyJob` callsite (`registrations_controller.rb:51-52,181-182`, `omniauth_callbacks_controller.rb:26-28`, sessions/magic_links/invites controllers). Zero adds, removes, or edits.
- `app/javascript/shared/queryHooks/api.ts` (never-edit list) and `app/javascript/ats/src/lib/utils/structure.js` (`allKeysToSnake` behavior is consumed as-is).
- Context files (`ModalContext.tsx`, `ToastContext.tsx`, `CurrentSessionContext.tsx`).
- Existing Cypress tests — all of `cypress/` is read-only; `cypress/e2e/auth/registration.cy.js` must keep passing (pre-commit hook runs it). No new Cypress tests for this PR (spec §9).
- `useSession.ts` hook wrappers `useMagicLink`/`useRegister` (only the request functions change); the `window.logger` object inside the `magicLink` request function (do not add the new fields to it — unspecced).
- `Auth.tsx` `showEmailConfirmationBannerIfApplicable` and the existing mount effect (unchanged); `AuthRegister.tsx`, `Login.tsx`, `Signup.tsx`, `OnboardingProfile.tsx` (render sites — no change).
- `sanitized_account_update_params`, `get_created_via`, `magic_link_status`, `add_connect_user`, `accept_invite`, `update` in the registrations controller.
- The `magic_create` JSON response shapes (byte-identical to today); the failure redirect `redirect_to '/auth?email_confirmed=false'` at `hire/confirmations_controller.rb:21`.
- The pre-existing `magic_create` connect-branch crash (`organization.id` on nil, `registrations_controller.rb:88-97`): **out of scope, do NOT fix** — tests route around it with `login_intent: 'hire'`.
- `.env`, git hooks, `AGENTS.md`, `.gitignore`.

---

## Backend changes

### Task B1 — Migration: attribution columns on users
_Read first: `cursor_rules/backend/migrations.md`, `cursor_rules/backend/_base.md`_

- [ ] B1.1 Generate a timestamp: `date +%Y%m%d%H%M%S` (call it `<ts1>`). Create `db/migrate/<ts1>_add_attribution_columns_to_users.rb` with exactly:

```ruby
# frozen_string_literal: true

class AddAttributionColumnsToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :utm_source, :string
    add_column :users, :utm_campaign, :string
    add_column :users, :utm_data, :jsonb
    add_column :users, :internal_ref, :string
  end
end
```

- [ ] B1.2 Confirm NO `default:`, NO `null: false`, NO index on any of the four (D6 — deliberately unlike `t.jsonb "settings", default: {}, null: false` on both tables). Absent data must stay `nil`, never `{}`.

### Task B2 — Migration: attribution columns on organizations
_Read first: `cursor_rules/backend/migrations.md`_

- [ ] B2.1 Create `db/migrate/<ts2>_add_attribution_columns_to_organizations.rb` where `<ts2>` is strictly greater than `<ts1>` (re-run `date +%Y%m%d%H%M%S` a second later), with exactly:

```ruby
# frozen_string_literal: true

class AddAttributionColumnsToOrganizations < ActiveRecord::Migration[6.1]
  def change
    add_column :organizations, :utm_source, :string
    add_column :organizations, :utm_campaign, :string
    add_column :organizations, :utm_data, :jsonb
    add_column :organizations, :internal_ref, :string
  end
end
```

- [ ] B2.2 Run `bundle exec rails db:migrate` (dev DB — allowed command) and `RAILS_ENV=test bundle exec rails db:migrate` (test DB). Do NOT use `db:test:prepare`, `db:schema:load`, `db:setup`, or `db:reset` (prohibited).
- [ ] B2.3 Verify `db/schema.rb` regenerated: version bumped to `<ts2>`; the four columns appear on both tables with plain `t.string`/`t.jsonb` (no default/null options). Commit `db/schema.rb` with the migrations. No `db/data/` migration (D6 — no backfill).
- [ ] B2.4 No model edits for the columns: no validations, no enums, no `attr_accessor` in `user.rb`/`organization.rb` (D6/D3). `organization.rb` gets zero diff.

### Task B3 — `Api::V1::RegistrationsController`: permit + magic_create merge (D3)
_Read first: `cursor_rules/core_critical_rules.md` (rules 5, 7), `cursor_rules/backend/controllers/controller_patterns_and_crud.md`, `cursor_rules/backend/_base.md`_

- [ ] B3.1 `sign_up_params` (currently lines 300–303; the permit at line 302) — add the three scalars and the trailing hash-permit (the `options: {}` form from `questions_controller.rb:50`; the hash-permit MUST be the trailing argument of `permit`):

```ruby
def sign_up_params
  # params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation, :beta_token, :registration_stripe_plan)
  params.permit(:name, :first_name, :last_name, :email, :password, :beta_token, :registration_stripe_plan, :referral, :partner, :organization_slug, :login_intent, :utm_source, :utm_campaign, :internal_ref, utm_data: {})
end
```

  Keep the existing commented-out line; this remains the controller's ONE params method (rule 5).
- [ ] B3.2 `magic_create` — the `user_params` two-branch conditional (lines 88–107). Add the four keys to the `.merge(...)` hash of **BOTH** branches, after the existing keys:

```ruby
user_params = if login_intent == 'connect' && organization.nil?
                {
                  email: sign_up_params[:email],
                  partner_source: params[:partner]&.downcase
                }.merge(
                  created_via: created_via,
                  password: password,
                  password_confirmation: password,
                  connect_login_intent_organization_id: organization.id, # Used to determine where to redirect a customer
                  utm_source: sign_up_params[:utm_source],
                  utm_campaign: sign_up_params[:utm_campaign],
                  utm_data: sign_up_params[:utm_data],
                  internal_ref: sign_up_params[:internal_ref]
                )
              else
                {
                  email: sign_up_params[:email],
                  partner_source: params[:partner]&.downcase
                }.merge(
                  created_via: created_via,
                  password: password,
                  password_confirmation: password,
                  utm_source: sign_up_params[:utm_source],
                  utm_campaign: sign_up_params[:utm_campaign],
                  utm_data: sign_up_params[:utm_data],
                  internal_ref: sign_up_params[:internal_ref]
                )
              end
```

  Facts the implementer relies on (verified): values are stored **raw** — no `&.downcase`, no `get_created_via`-style mapping (D3). `sign_up_params[:utm_source]` is `nil` when the param wasn't sent → column stays nil. `sign_up_params[:utm_data]` is a permitted `ActionController::Parameters` when present (assigning it to the jsonb attribute serializes as a plain hash — `Parameters` delegates `as_json` to `@parameters`, actionpack 6.1.7.7 `strong_parameters.rb:247`) and `nil` when absent → jsonb column nil, not `{}`. Only the new-user branch (`build_resource(user_params)` at line 158) creates a row; the existing-user branches read only `user_params[:email]` (line 109) so the added keys are inert there. **No identify/track/redirect/response-shape change anywhere in `magic_create`.**
- [ ] B3.3 `create` (password path, D10): NO change beyond B3.1 — `expanded_params = sign_up_params.merge(created_via: ..., partner_source: ...)` (lines 13–16) already forwards the newly permitted params to `build_resource`. Verify by reading, not by editing.

### Task B4 — `Api::V1::OrganizationsController#create`: copy from current_user (D5)
_Read first: `cursor_rules/backend/controllers/controller_patterns_and_crud.md`, `cursor_rules/backend/controllers/pundit_policies.md`_

- [ ] B4.1 Insert the four copy lines in `create`, immediately after line 31 (`@organization.created_via = current_user.created_via`) and before `@organization.is_claimed = true`:

```ruby
    @organization.created_via = current_user.created_via   # existing line, unchanged
    @organization.utm_source = current_user.utm_source
    @organization.utm_campaign = current_user.utm_campaign
    @organization.utm_data = current_user.utm_data
    @organization.internal_ref = current_user.internal_ref
```

- [ ] B4.2 `organization_params` is NOT modified — the values never come from the request (an attacker-controlled `utm_source` in the org-create body is ignored because it is unpermitted AND unread). The existing `authorize @organization` (line 33) is untouched. A user with nil columns produces an organization with nil columns — no fallback of any kind.

### Task B5 — omniauth setup lambda whitelist (D8)
_Read first: `cursor_rules/backend/_base.md`_

- [ ] B5.1 `config/initializers/omniauth.rb` line 14 — the ONLY change in this file:

```ruby
      allowed_keys = %w[partner referral utm_source utm_campaign utm_data internal_ref]
```

  Verified: the existing loop (`value = rack_request.params[key]; tracking_params[key] = value if value && !value.empty?`) already handles the new keys — `utm_source`/`utm_campaign`/`internal_ref` arrive as strings; `utm_data` arrives as a `Hash` from the Rails-nested `utm_data[<key>]` form inputs (Hash responds to `empty?`). The session cookie uses the `:json` serializer (`config/initializers/cookies_serializer.rb`), so the `utm_data` hash round-trips with string keys.

### Task B6 — `User.from_omniauth` keyword conversion + call-site census (D9)
_Read first: `cursor_rules/backend/_base.md`, `cursor_rules/backend/code_style_and_structure.md`, `cursor_rules/core_critical_rules.md` (rule 8)_

- [ ] B6.1 `app/models/user.rb` line 379 — convert the signature to keywords in this exact order:

```ruby
  def self.from_omniauth(auth:, created_via:, partner_source: nil, utm_source: nil, utm_campaign: nil, utm_data: nil, internal_ref: nil)
```

  `auth:` and `created_via:` are required keywords; the rest default to nil.
- [ ] B6.2 Add the four assignments **inside the `first_or_create` block only**, after the existing `omniauth_user.partner_source = partner_source&.downcase` line (raw — no `&.downcase` on the new four):

```ruby
    user = where(email: auth.info.email).first_or_create do |omniauth_user|
      omniauth_user.password = Devise.friendly_token[0, 20]
      omniauth_user.created_via = created_via
      omniauth_user.partner_source = partner_source&.downcase
      omniauth_user.utm_source = utm_source
      omniauth_user.utm_campaign = utm_campaign
      omniauth_user.utm_data = utm_data
      omniauth_user.internal_ref = internal_ref
      omniauth_user.sign_on_provider = 'google'
      # (existing skip_confirmation! comment + call unchanged)
      omniauth_user.skip_confirmation!
    end
```

  The `ap` debug lines above the block and ALL post-block behavior (`assign_attributes(remember_me: true)`, `update(first_name:, last_name:)`, `enqueue_complete_user_setup`, return of `user`) stay byte-identical. An existing user logging in via SSO is untouched — the block does not run and no assignment happens outside it.
- [ ] B6.3 **Mandatory call-site census (D9):** run `git grep -n "from_omniauth"` across the repo at implementation time. Convert EVERY call site found to keyword form. As of planning the only call site is `app/controllers/api/v1/users/omniauth_callbacks_controller.rb:22` — do not rely on this list; a missed positional caller raises `ArgumentError` on every SSO login. Re-run the grep AFTER converting and confirm the only remaining matches are the definition and keyword-form call sites.
- [ ] B6.4 `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` line 22 — keyword form, four new values from the merged tracking hash (string keys — `merged_tracking = request_phase_params.merge(tracking_from_session)`, line 15):

```ruby
    user = User.from_omniauth(
      auth: oauth_data,
      created_via: created_via_value,
      partner_source: partner_param,
      utm_source: merged_tracking['utm_source'],
      utm_campaign: merged_tracking['utm_campaign'],
      utm_data: merged_tracking['utm_data'],
      internal_ref: merged_tracking['internal_ref']
    )
```

  Nothing else in the action changes — `session.delete(:oauth_tracking)`, `get_created_via`, `sign_in`, the `PosthogIdentifyJob`/`PosthogTrackJob` calls, and the redirect stay as they are.

### Task B7 — `Hire::ConfirmationsController#show` success redirect (D12)
_Read first: `cursor_rules/backend/_base.md` (string-quoting rule: double quotes only for interpolation — applies here)_

- [ ] B7.1 Line 18 — replace `redirect_to '/auth?email_confirmed=true'` with:

```ruby
      redirect_to "/auth?email_confirmed=true&id=#{user.id}&email=#{CGI.escape(user.email)}"
```

  Param names `id` and `email` (spec-proposed, fixed by the amended spec). `CGI.escape` URL-encodes the email (`+`/`@` become `%2B`/`%40`). In the success branch `user` is a confirmed persisted User (`user.errors.blank?`), so both values are always present.
- [ ] B7.2 The failure redirect at line 21 (`redirect_to '/auth?email_confirmed=false'`) is byte-identical — no id/email there. `OrgOwnerUpdateJob.perform_later` and everything else unchanged.

---

## Frontend changes

Case convention (core rule 7): payload fields are camelCase — `utmSource`, `utmCampaign`, `utmData`, `internalRef`. `apiPost` → `allKeysToSnake` (`structure.js:94-105`, lodash `snakeCase` per key, recursing into nested objects) produces wire params `utm_source`/`utm_campaign`/`utm_data`/`internal_ref`. The keys **inside** `utmData` are the raw URL param names (`utm_medium`, …) per D2 — approved deviation. The SSO path posts a plain HTML form (bypasses `allKeysToSnake`), so its input names are written snake_case directly. Absent fields are `undefined` → axios' JSON body drops them (`JSON.stringify` omits undefined values) → wire param never arrives → `sign_up_params[<key>]` nil → column nil.

### Task F1 — `sanitizeTrackingParams` in `app/javascript/shared/lib/utils.js` (D4)
_Read first: `cursor_rules/core_critical_rules.md` (rules 9, 10, 13), `cursor_rules/frontend/_base.md`_

- [ ] F1.1 Add `import queryString from "query-string";` to the imports at the top of `utils.js` (currently lodash `keys`/`isString`/`isArray`/`isPlainObject`).
- [ ] F1.2 Add the helper directly after `standardizeQueryParamsObject` (helper placement analog). **Input contract (spec §5.1, review-amended):** the raw `location.search` STRING — never the object from `queryString.parse`, because the installed query-string v6.1.0 `parse` returns keys alphabetically sorted with no opt-out (`node_modules/query-string/index.js` — `parse()` ends in `Object.keys(ret).sort().reduce(...)`), destroying the occurrence order D4's 10-key cap requires. Values come from `queryString.parse(search)`; key occurrence order comes from the raw string. Array values for a repeated param ARE built in occurrence order and pass through the final sort untouched (`!Array.isArray(value)` guard in the library), so "first occurrence = element [0]" holds from the parse output. Plan-level implementation (double quotes — frontend style):

```js
/* sanitizeTrackingParams
--===================================================-- */
// Captures utm_source, utm_campaign, internal_ref, and up to 10 additional utm_* params
// from the raw location.search string. Key occurrence order is derived from the raw string
// because queryString.parse (v6.1.0) returns its keys alphabetically sorted.
const TRACKING_VALUE_MAX_LENGTH = 255;
const UTM_DATA_MAX_KEYS = 10;

function sanitizeTrackingValue(value) {
  const firstValue = isArray(value) ? value[0] : value; // repeated param: keep first occurrence
  return isString(firstValue) ? firstValue.slice(0, TRACKING_VALUE_MAX_LENGTH) : firstValue; // truncate to 255
}

export function sanitizeTrackingParams(search) {
  const parsedParams = queryString.parse(search);

  const keysInOccurrenceOrder = [];
  queryString
    .extract(search)
    .split("&")
    .forEach((param) => {
      if (param.length === 0) return;
      const rawKey = param.replace(/\+/g, " ").split("=")[0];
      let decodedKey;
      try {
        decodedKey = decodeURIComponent(rawKey);
      } catch (e) {
        decodedKey = rawKey;
      }
      if (keysInOccurrenceOrder.indexOf(decodedKey) === -1) {
        keysInOccurrenceOrder.push(decodedKey);
      }
    });

  const trackingParams = {};
  if (parsedParams.utm_source !== undefined) {
    trackingParams.utmSource = sanitizeTrackingValue(parsedParams.utm_source);
  }
  if (parsedParams.utm_campaign !== undefined) {
    trackingParams.utmCampaign = sanitizeTrackingValue(parsedParams.utm_campaign);
  }
  if (parsedParams.internal_ref !== undefined) {
    trackingParams.internalRef = sanitizeTrackingValue(parsedParams.internal_ref);
  }

  const utmDataKeys = keysInOccurrenceOrder
    .filter(
      (key) =>
        key.indexOf("utm_") === 0 &&
        key !== "utm_source" &&
        key !== "utm_campaign" &&
        parsedParams[key] !== undefined,
    )
    .slice(0, UTM_DATA_MAX_KEYS); // first 10 by occurrence order in the raw string

  if (utmDataKeys.length > 0) {
    const utmData = {};
    utmDataKeys.forEach((key) => {
      utmData[key] = sanitizeTrackingValue(parsedParams[key]);
    });
    trackingParams.utmData = utmData;
  }

  return trackingParams;
}
```

  Notes pinning the contract:
  - **`!== undefined` (strict) is deliberate**, not a rule-13 violation: `?utm_source` (present, no value) parses to `null` and must pass through as-is (spec §5.1); the loose house guard `!= undefined` would misclassify that `null` as absent. Absent param → key absent from the parse output → field absent from the result. Conventions reviewers: do not "fix" this to `!=`.
  - No `|| ""`, no `|| {}`, no fabricated empty object (core rule 10; D3/D6). `utmData` appears ONLY when at least one extra `utm_*` param was captured.
  - Key decoding for order-matching: `+`→space then `decodeURIComponent`, mirroring the library's own decode; `try/catch` falls back to the raw key on malformed percent-encoding (recorded spec-review LOW — plan-level mechanism).
  - Prefix matching is case-sensitive (`utm_`), matching `queryString.parse` key case — recorded LOW fact, accepted.
  - `queryString.extract` handles both `"?a=b"` and `""` forms of `location.search` (returns `""` when no `?`).

### Task F2 — `useSession.ts` request functions (D2, D10)
_Read first: `cursor_rules/frontend/react_query/react_query_mutations_and_cache.md`_

- [ ] F2.1 `magicLink` (lines 41–82): add `utmSource`, `utmCampaign`, `utmData`, `internalRef` to (a) the destructured parameter list, (b) the inline TS type — as `utmSource?: string | null; utmCampaign?: string | null; utmData?: Record<string, any> | null; internalRef?: string | null;` (pragmatic-TS rule; `Record<string, any>` for the raw-keyed object) — and (c) the `variables` object passed to `apiPost` (path `/magic_login`). Do NOT add them to the `window.logger` call inside the function (unspecced).
- [ ] F2.2 `register` (lines 27–39): add the same four to the destructured parameters and the `variables` object (path `/sign_up`). `register` has no inline type today — do not add one.
- [ ] F2.3 The hook wrappers `useMagicLink`/`useRegister` (lines 141–166) are UNCHANGED — component-level `onSuccess` callbacks carry the new events.

### Task F3 — `AuthForm.tsx` (D1, D2, D7, D14)
_Read first: `cursor_rules/frontend/react_hooks.md`, `cursor_rules/frontend/forms/form_submission_and_mutations.md`, `cursor_rules/core_critical_rules.md` (rule 13)_

- [ ] F3.1 Imports: add `import { sanitizeTrackingParams } from "@shared/lib/utils";` and `import { trackEvent } from "@shared/lib/posthog";`.
- [ ] F3.2 Capture (D1/D4): alongside the existing `referral`/`partner` states (lines 37–38), hold the sanitized values in component state — sanitization happens BEFORE the values enter state, and no setter is needed (plan choice: one object state rather than four scalar states; the spec explicitly leaves the shape plan-level):

```tsx
  const [trackingParams] = React.useState(sanitizeTrackingParams(location.search));
```

- [ ] F3.3 Magic-link payload (D2): inside `handleAuth`, add to the `magicLink({...})` variables object, alongside `referral` and `partner`:

```tsx
          referral,
          partner,
          utmSource: trackingParams.utmSource,
          utmCampaign: trackingParams.utmCampaign,
          utmData: trackingParams.utmData,
          internalRef: trackingParams.internalRef,
```

  Absent fields are `undefined` property reads passed through as-is (frontend rule 2 "pass values directly"); they drop out of the JSON body.
- [ ] F3.4 Step-2 event (D14): in the existing `magicLink` `onSuccess` callback (lines 82–85), fire the event BEFORE `onComplete` — plain call, no properties:

```tsx
          onSuccess: (data) => {
            window.logger("[AuthForm] data", { ...data });
            trackEvent("user_signed_up_client_side");
            onComplete({ email: cleanedEmail, ...data });
          },
```

  Accepted semantics (spec Risk 1): this fires on EVERY successful `magic_login` response, including an existing confirmed user requesting a login link — shared-form behavior, not a defect.
- [ ] F3.5 SSO props (D7): extend line 120:

```tsx
        <GoogleSSOButton
          referral={referral}
          partner={partner}
          utmSource={trackingParams.utmSource}
          utmCampaign={trackingParams.utmCampaign}
          utmData={trackingParams.utmData}
          internalRef={trackingParams.internalRef}
          darkModeAllowed={darkModeAllowed}
        />
```

- [ ] F3.6 No change to `Auth.tsx`/`AuthRegister.tsx` render sites — both already pass `location={props.location}` (`Auth.tsx:72`, `AuthRegister.tsx:136`), so capture covers `/auth` and `/auth-register` automatically.

### Task F4 — `SignupForm.tsx` (D10, D14)
_Read first: `cursor_rules/frontend/forms/form_submission_and_mutations.md`_

- [ ] F4.1 Imports: add `import { sanitizeTrackingParams } from "@shared/lib/utils";` and `import { trackEvent } from "@shared/lib/posthog";`.
- [ ] F4.2 Capture, same mechanism as its `referral` state (line 23):

```tsx
  const [trackingParams] = React.useState(sanitizeTrackingParams(props.location.search));
```

- [ ] F4.3 `register` payload (inside `handleSignup`): add the four fields alongside `inviteToken`/`referral`:

```tsx
          inviteToken,
          referral,
          utmSource: trackingParams.utmSource,
          utmCampaign: trackingParams.utmCampaign,
          utmData: trackingParams.utmData,
          internalRef: trackingParams.internalRef,
```

- [ ] F4.4 In the existing `register` `onSuccess` (lines 66–69), fire BEFORE `props.onComplete()`:

```tsx
          onSuccess: (data) => {
            window.logger("[SignupForm] register onScucess", { data });
            trackEvent("user_signed_up_client_side");
            props.onComplete();
          },
```

  (Keep the existing `onScucess` typo in the logger string — do not fix unrelated lines.)

### Task F5 — `GoogleSSOButton.tsx` hidden inputs (D7)
_Read first: `cursor_rules/frontend/components/component_architecture.md`, `cursor_rules/core_critical_rules.md` (rule 13)_

- [ ] F5.1 Extend `Props`:

```tsx
interface Props {
  isDisabled?: boolean;
  referral?: string;
  partner?: string;
  utmSource?: string;
  utmCampaign?: string;
  utmData?: Record<string, any>;
  internalRef?: string;
  darkModeAllowed?: boolean;
}
```

  and add the four to the destructured function signature (line 16).
- [ ] F5.2 Render hidden inputs after the existing `referral`/`partner` inputs (lines 46–51), following the analog's render-only-when-present guard exactly; `utm_data` is one input per key with Rails-nested naming, each key behind the SAME analog guard applied per-value:

```tsx
      {typeof utmSource === "string" && utmSource.length > 0 ? (
        <input type="hidden" name="utm_source" value={utmSource} />
      ) : null}
      {typeof utmCampaign === "string" && utmCampaign.length > 0 ? (
        <input type="hidden" name="utm_campaign" value={utmCampaign} />
      ) : null}
      {typeof internalRef === "string" && internalRef.length > 0 ? (
        <input type="hidden" name="internal_ref" value={internalRef} />
      ) : null}
      {utmData != undefined
        ? Object.keys(utmData).map((key) =>
            typeof utmData[key] === "string" && utmData[key].length > 0 ? (
              <input type="hidden" name={"utm_data[" + key + "]"} value={utmData[key]} key={key} />
            ) : null,
          )
        : null}
```

  Input names are snake_case on purpose — the plain form POST bypasses `allKeysToSnake` (spec §5 case note). Stated consequence (accepted, spec §5.3): a valueless `?utm_medium` (null) or empty `utm_medium=` ("") rides the JSON paths but is omitted from the SSO path — the analog's own guard behavior. The `utmData != undefined` outer guard is the correct loose house form here (absent check).

### Task F6 — `Auth.tsx`: state-keyed identify effect (D12)
_Read first: `cursor_rules/frontend/react_hooks.md`, `cursor_rules/core_critical_rules.md` (rules 2a, 13)_

- [ ] F6.1 Imports: add `import { identifyUser, trackEvent } from "@shared/lib/posthog";`.
- [ ] F6.2 `showEmailConfirmationBannerIfApplicable` (lines 22–29) and the existing mount effect (lines 18–20) stay EXACTLY as they are. **The identify and event must NOT fire inside the mount effect** (spec §5.6 timing: the mechanism must not depend on the incidental `useOrganization` loading gate that currently delays `Auth.tsx`'s mount past `posthog.init`). Add a SECOND `React.useEffect` directly after the existing one, keyed on the existing `emailConfirmed` state:

```tsx
  React.useEffect(() => {
    if (!emailConfirmed) return;

    const { id, email } = queryString.parse(props.location.search);
    if (id != undefined && email != undefined) {
      identifyUser({ id: Number(id), email: email as string });
      trackEvent("email_verified");
    }
  }, [emailConfirmed]);
```

  Contract points (all spec-bound):
  - The re-render scheduled by `setEmailConfirmed` always commits after the initial effect flush containing `posthog.init` — robust in both current and `enabled:`-gated worlds.
  - The guard requires BOTH `id` and `email` (loose `!= undefined` — house absent-check; these params are either present strings or absent). If either is missing (stale bookmarked `/auth?email_confirmed=true`), NEITHER call fires — no `ph.identify("undefined")`, no anonymous `email_verified`.
  - `identifyUser({ id: Number(id), email })` — `Number()` satisfies the helper's `id: number` signature; `identifyUser` keys on `String(user.id)` internally, so the distinct_id matches `AppAuthRouter.tsx`'s.
  - `trackEvent("email_verified")` — no properties — fires AFTER the identify, inside the same guard.
  - Fires exactly once per landing (`emailConfirmed` transitions `false → true` once per mount, never back); the `email_confirmed=false` branch gets nothing.
  - `AuthRegister.tsx` and `Login.tsx` also read `email_confirmed` but are NOT modified — the confirmation redirect targets `/auth` only.
  - Accepted boundary (spec Risk 7 — do NOT redesign): `email_verified` fires only for confirmations clicked while signed OUT (cross-device/logged-out/browser-restarted); the signed-in majority is bounced by `Hire::PagesController#redirect_if_authed` before `Auth.tsx` renders. Decision-bound; any fix is a new decision outside this PR.

### Task F7 — `OrganizationForm.tsx` (D13)
_Read first: `cursor_rules/frontend/react_query/react_query_mutations_and_cache.md`_

- [ ] F7.1 Import: `import { trackEvent } from "@shared/lib/posthog";`.
- [ ] F7.2 In the `createOrganization` `onSuccess` (lines 68–71), fire BEFORE `onComplete(data)`:

```tsx
          onSuccess: (data) => {
            window.logger("[OrganizationForm] createOrganization onSuccess", { data });
            trackEvent("organization_created");
            onComplete(data);
          },
```

  Plain call, no properties; fires on every successful creation. **NO identify call here** — the existing `AppAuthRouter.tsx:165-177` identify effect re-fires with the new organization's properties because `useCreateOrganization` (`useOrganization.ts:87-102`) invalidates `currentOrganization` and `me`, changing the effect deps (`currentUser`, `organizationId`, `currentPlan`, `organizationName`). Jessica verifies the re-fire in dev via the `identifyUser` `window.logger` already on the branch.

### Task F8 — `ProfileForm.tsx` (D16)
_Read first: `cursor_rules/frontend/forms/form_submission_and_mutations.md`, `cursor_rules/frontend/boolean_variables_and_naming.md`_

- [ ] F8.1 Import: `import { trackEvent } from "@shared/lib/posthog";`.
- [ ] F8.2 In the `updateMe` `onSuccess` (lines 64–67), fire exactly ONE of two events — plain calls, no properties — BEFORE `props.onComplete()`, keyed on the existing `isNewOwner` prop:

```tsx
          onSuccess: (data) => {
            window.logger("[ProfileForm] onSuccess", { data });
            if (props.isNewOwner) {
              trackEvent("organization_owner_user_name_submitted");
            } else {
              trackEvent("invited_user_name_submitted");
            }
            props.onComplete();
          },
```

  The else branch covers the `wasInvited` case AND the rare neither-true edge (spec-bound). `isNewOwner`/`wasInvited` are computed and passed by `OnboardingProfile.tsx` (lines 16–17, props at 47–48) — that file is NOT modified.

### Task F9 — `posthog.ts` (already applied)

- [ ] F9.1 Verify `git diff app/javascript/shared/lib/posthog.ts` shows ONLY the `window.logger` additions to `identifyUser` (fire + skip paths). Make no edit. Include the file in the feature commit.

---

## Validation and constraints

- **All input sanitization is capture-side only (D4), in `sanitizeTrackingParams`:** 255-char truncation per value; first occurrence of a repeated param; at most 10 `utm_*` keys in `utmData` by raw-string occurrence order. There is intentionally NO server-side sanitization — the server stores values raw as sent (D3). Postgres `character varying` without limit means direct API callers can store longer values — accepted (spec Risk 4).
- **Nil-for-absent at every layer (D3/D6, core rule 10):** absent URL param → absent helper field → dropped from JSON body → `sign_up_params[<key>]` nil → nil column. No `|| ""`, no `|| {}`, no jsonb default, no backfill.
- **No model validations, enums, or mappings** for the four columns — plain attributes, mass-assigned (`build_resource`) or directly set.
- **Authorization: none new.** `/magic_login`, `/sign_up`, omniauth request/callback are unauthenticated by design (Devise scope `api_v1_user`); `organizations#create` keeps its existing Pundit `authorize`; `confirmations#show` stays token-authenticated via `User.confirm_by_token`.
- **Server params tolerance:** unknown params are already ignored by `permit`; the new params are additive and optional in both directions (old clients keep working).

## Test plan

Verified current state (re-verify at implementation): NO existing RSpec file covers `Api::V1::RegistrationsController`, `Api::V1::Users::OmniauthCallbacksController`, `Api::V1::OrganizationsController#create`, `Hire::ConfirmationsController`, or `User.from_omniauth` — all six test files are NEW. Suite conventions: `type: :controller`, per-file Devise opt-in, `allow(controller).to receive(...)` stubs, manual `create!` record creation (bang methods OK in specs — core rule 11 exception; no FactoryBot), `reload` OK in specs. `config.active_job.queue_adapter = :inline` in test env (`config/environments/test.rb:64`), so every controller/model spec below MUST wrap examples in the `around` adapter-switch pattern from `bulk_ai_job_application_summaries_controller_spec.rb:9-14` (`ActiveJob::Base.queue_adapter = :test`) — otherwise `PosthogIdentifyJob`/`PosthogTrackJob`/`UserSetupJob`/`NotifyUserJob`/`OrgOwnerUpdateJob` run inline (NotifyUserJob pings a real Slack webhook when the user has an organization). `Recaptcha::Verifier#verify` returns success automatically in test env (`app/services/recaptcha/verifier.rb:16`) — no stubbing needed for `magic_create`.

**Anti-ghost rule (pipeline rule 26 — BLOCKER-level):** every assertion below must fail if the corresponding permit/merge/assignment/keyword is deleted. Raw-storage assertions use a mixed-case value (`'SomeRawValue'`) that any downcase/`get_created_via`-style mapping would alter; jsonb nil assertions use `be_nil` (fails on `{}`); the Jest occurrence-order test uses non-alphabetical param order so a parse-key-order implementation fails.

### Task T1 — Jest: `app/javascript/shared/lib/utils.test.js`
_Read first: `jest.config.js`; precedent `Button.test.tsx` (relative import)_

- [ ] T1.1 Create the file co-located with `utils.js`; `import { sanitizeTrackingParams } from "./utils";`. Run with `nvm use && yarn jest app/javascript/shared/lib/utils.test.js`.
- [ ] T1.2 Truncation: `"?utm_source=" + "a".repeat(300)` → `utmSource.length === 255`.
- [ ] T1.3 Repeated param → first occurrence: `"?utm_source=first&utm_source=second"` → `"first"`.
- [ ] T1.4 10-key cap by occurrence order — **query string MUST list `utm_*` params in an order that differs from alphabetical** (spec §9.6 anti-ghost). E.g. `"?utm_z=1&utm_y=2&utm_x=3&utm_w=4&utm_v=5&utm_u=6&utm_t=7&utm_s=8&utm_r=9&utm_q=10&utm_a=11"` → `Object.keys(result.utmData)` equals `["utm_z","utm_y","utm_x","utm_w","utm_v","utm_u","utm_t","utm_s","utm_r","utm_q"]` (10 keys, occurrence order, `utm_a` dropped). An implementation taking order from `queryString.parse`'s sorted output keeps `utm_a` and fails.
- [ ] T1.5 Exclusions: `"?utm_source=s&utm_campaign=c&utm_medium=m"` → `utmData` is exactly `{ utm_medium: "m" }` (no utm_source/utm_campaign inside).
- [ ] T1.6 Absence semantics: `sanitizeTrackingParams("")` → `toEqual({})` (no fabricated `""`/`{}` — assert `Object.prototype.hasOwnProperty.call(result, "utmSource")` is false); `"?utm_source=x"` alone → result has `utmSource` but NO `utmData` property.
- [ ] T1.7 Valueless param passes through: `"?utm_source"` → `utmSource === null` (property present, null).
- [ ] T1.8 `internal_ref` capture: `"?internal_ref=ref-1"` → `internalRef === "ref-1"`; non-`utm_` params (`"?foo=bar"`) never appear anywhere in the result.

### Task T2 — `spec/controllers/api/v1/registrations_controller_spec.rb`
_Read first: `cursor_rules/core_critical_rules.md` (rule 11 exception); analogs named above_

- [ ] T2.1 Skeleton: `RSpec.describe Api::V1::RegistrationsController, type: :controller` with `include Devise::Test::ControllerHelpers` (per-file precedent `bulk_ai_job_application_summaries_controller_spec.rb:7` — the actions call `sign_up`/`sign_in`, which need warden in the request env; rails_helper does NOT wire the helpers globally) AND `before { @request.env['devise.mapping'] = Devise.mappings[:api_v1_user] }`. Add the `around` ActiveJob `:test`-adapter block.
- [ ] T2.2 **Every `magic_create` POST includes `login_intent: 'hire'`** (the value `AuthForm.tsx` always sends). Without it `login_intent` defaults to `'connect'` and — with no `organization_slug` — the connect branch evaluates `organization.id` on nil (`registrations_controller.rb:88-97`) and raises `NoMethodError`. Pre-existing, out of scope — route around it, do NOT fix it. Params are top-level (no `user:` wrapper — `sign_up_params` uses bare `params.permit`).
- [ ] T2.3 `magic_create` new-user branch: `post :magic_create, params: { email: 'new-magic@example.com', login_intent: 'hire', utm_source: 'SomeRawValue', utm_campaign: 'Camp01', internal_ref: 'ref-99', utm_data: { utm_medium: 'email', utm_term: 'hiring' } }` → response ok; `user = User.find_by(email: 'new-magic@example.com')` has `utm_source == 'SomeRawValue'` (verbatim — raw), `utm_campaign == 'Camp01'`, `internal_ref == 'ref-99'`, `utm_data == { 'utm_medium' => 'email', 'utm_term' => 'hiring' }` (hash round-trip, string keys).
- [ ] T2.4 `magic_create` with none of the four params → created user has nil in all four columns; `expect(user.utm_data).to be_nil` (nil, NOT `{}`).
- [ ] T2.5 Existing-CONFIRMED-user branch: `User.create!(email:, password:, password_confirmation:, first_name:, last_name:).tap(&:confirm)`; POST with the four params (+`login_intent: 'hire'`) → response ok; `user.reload` → all four columns still nil (not modified).
- [ ] T2.6 Existing-UNCONFIRMED-user branch (resend-confirmation path — calls `sign_in`, hence warden): same as T2.5 but without `.tap(&:confirm)` → response ok; columns not modified.
- [ ] T2.7 `create` (password path): `post :create, params: { first_name: 'Pat', last_name: 'Tester', email: 'pw@example.com', password: 'password', utm_source: 'SomeRawValue', utm_campaign: 'Camp01', internal_ref: 'ref-99', utm_data: { utm_medium: 'cpc' } }` → user persisted with all four raw (assigned via `sign_up_params` through `expanded_params`); a second POST without them → nil columns.

### Task T3 — `spec/models/user_from_omniauth_spec.rb`

- [ ] T3.1 Skeleton: `RSpec.describe User, type: :model` (file name pins the subject; `describe '.from_omniauth'`). `around` ActiveJob `:test` adapter (from_omniauth calls `enqueue_complete_user_setup` → `UserSetupJob`/`NotifyUserJob`). Auth stub: `OmniAuth::AuthHash.new(info: { email: 'sso-new@example.com', first_name: 'Sso', last_name: 'User' })`.
- [ ] T3.2 Keyword creation: `User.from_omniauth(auth: auth_hash, created_via: 'created_via_signup', partner_source: 'WWR', utm_source: 'SomeRawValue', utm_campaign: 'Camp01', utm_data: { 'utm_medium' => 'cpc' }, internal_ref: 'ref-99')` → user persisted; four values raw (`utm_source == 'SomeRawValue'`); `partner_source == 'wwr'` (STILL downcased — existing behavior); `utm_data` round-trips as hash.
- [ ] T3.3 Omitted keywords → all four columns nil (`utm_data` `be_nil`).
- [ ] T3.4 Existing user (create + confirm a user with the matching email first): calling `from_omniauth` with `utm_source: 'ShouldNotStick'` etc. does not change `User.count` and leaves all four columns nil — assignment happens only inside `first_or_create`.
- [ ] T3.5 Required keywords: `expect { User.from_omniauth(created_via: 'created_via_signup') }.to raise_error(ArgumentError)` and `expect { User.from_omniauth(auth: auth_hash) }.to raise_error(ArgumentError)` — pins the keyword interface (spec Risk 5 mitigation).

### Task T4 — `spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb`

- [ ] T4.1 Create the `spec/controllers/api/v1/users/` directory. Skeleton: `RSpec.describe Api::V1::Users::OmniauthCallbacksController, type: :controller` with `include Devise::Test::ControllerHelpers` (`google_oauth2` calls `sign_in(user)` — warden required) AND `before { @request.env['devise.mapping'] = Devise.mappings[:api_v1_user] }` — same requirement as T2.1: devise 4.8.1's `DeviseController` (parent of this controller via `Devise::OmniauthCallbacksController`) runs `prepend_before_action :assert_is_devise_resource!` (devise_controller.rb:17), which raises `AbstractController::ActionNotFound` when `request.env['devise.mapping']` is unset in a controller spec, and `Devise::Test::ControllerHelpers` does not set it; the action's own line-5 mapping assignment runs after the prepend_before_action, too late to help. Add the `around` `:test`-adapter block.
- [ ] T4.2 Setup: create a confirmed user; `allow(User).to receive(:from_omniauth).and_return(that_user)`; `request.env['omniauth.auth'] = OmniAuth::AuthHash.new(info: { email:, first_name:, last_name: })`; seed `session[:oauth_tracking] = { 'partner' => 'wwr', 'referral' => 'someref', 'utm_source' => 'SomeRawValue', 'utm_campaign' => 'Camp01', 'utm_data' => { 'utm_medium' => 'cpc' }, 'internal_ref' => 'ref-99' }` (string keys — mirrors the `:json` cookie-serializer round-trip).
- [ ] T4.3 `get :google_oauth2` → `expect(User).to have_received(:from_omniauth).with(auth: anything, created_via: 'created_via_weworkremotely_referral', partner_source: 'wwr', utm_source: 'SomeRawValue', utm_campaign: 'Camp01', utm_data: { 'utm_medium' => 'cpc' }, internal_ref: 'ref-99')` — pins BOTH the keyword call-site conversion AND the string-key session read. Assert the redirect to `"#{Variables::AtsRootUrl}/"`.
- [ ] T4.4 Second example with `session[:oauth_tracking]` unset → `from_omniauth` receives `utm_source: nil, utm_campaign: nil, utm_data: nil, internal_ref: nil` (nil-for-absent on the SSO path).

### Task T5 — `spec/controllers/api/v1/organizations_controller_spec.rb`

- [ ] T5.1 Skeleton: `RSpec.describe Api::V1::OrganizationsController, type: :controller`; stub per the ai-credit pattern: `allow(controller).to receive(:authenticate_api_v1_user!).and_return(true)`, `allow(controller).to receive(:current_user).and_return(user)`, `allow(controller).to receive(:authorize).and_return(true)`, `allow(controller).to receive(:set_sentry_context)` (base controller `before_action`). `around` `:test`-adapter block.
- [ ] T5.2 `user` with values: `User.create!(email:, password:, password_confirmation:, first_name:, last_name:, utm_source: 'SomeRawValue', utm_campaign: 'Camp01', utm_data: { 'utm_medium' => 'email' }, internal_ref: 'ref-99').tap(&:confirm)`. `post :create, params: { organization: { name: 'Attributed Org' } }` (note the `organization:` wrapper — `organization_params` uses `params.require(:organization)`) → response ok; the created Organization has all four columns equal to the user's (copy semantics, D5).
- [ ] T5.3 `user` with nil columns → created Organization has nil in all four (`utm_data` `be_nil`, not `{}`).
- [ ] T5.4 Anti-tamper: include `utm_source: 'attacker'` inside `params[:organization]` in one example and assert the created Organization's `utm_source` still equals the `current_user` value (values never come from the request — `organization_params` unmodified).

### Task T6 — `spec/controllers/hire/confirmations_controller_spec.rb`

- [ ] T6.1 Create the `spec/controllers/hire/` directory. Skeleton: `RSpec.describe Hire::ConfirmationsController, type: :controller`; `around` `:test`-adapter block (`OrgOwnerUpdateJob.perform_later` on success). No Devise helpers needed (no `sign_in` in the action). Contingency: if URL generation trips on the `SubdomainAppConstraints` wrapper, set `@request.host = 'app.lvh.me'` — constraint classes gate recognition, not generation, so this is not expected.
- [ ] T6.2 Success: `user = User.create!(email: 'confirm+test@example.com', password: 'password', password_confirmation: 'password', first_name: 'C', last_name: 'T')` (unconfirmed; Devise confirmable stores the raw token in `confirmation_token`). `get :show, params: { confirmation_token: user.confirmation_token }` → `expect(response).to redirect_to("/auth?email_confirmed=true&id=#{user.id}&email=#{CGI.escape(user.email)}")` — the `+`/`@` in the address pin the URL-encoding (`confirm%2Btest%40example.com`).
- [ ] T6.3 Failure: `get :show, params: { confirmation_token: 'not-a-real-token' }` → `expect(response).to redirect_to('/auth?email_confirmed=false')` — byte-identical failure redirect, no id/email.

### Cypress (read-only — verification only)

- [ ] T7.1 `git status`/`git diff` confirm zero changes under `cypress/`. `cypress/e2e/auth/registration.cy.js` exercises both signup paths end-to-end and runs in the pre-commit hook (`bin/run-cypress-precommit`) — the payload additions and confirmation-redirect params must not break it. No new Cypress tests for this PR (spec §9: browser events are PostHog side effects verified manually by Jessica via the `window.logger` output; UTM persistence is covered by RSpec).

## Implementation order

1. **B1 → B2** (migrations + `db:migrate` dev and test + schema.rb) — everything downstream needs the columns.
2. **B3 → B4 → B5 → B6 (incl. B6.3 census) → B7** (backend, in dependency order: permit before merge; whitelist before callback).
3. **F1** (helper) → **F2** (request functions) → **F3/F4** (capture + payload + events) → **F5** (SSO inputs) → **F6/F7/F8** (events/identify) → **F9** (verify posthog.ts untouched).
4. **T1** (Jest) → **T2–T6** (RSpec).
5. Verification commands below; then commit per repo commit rules (`nvm use && git commit …` outside sandbox; pre-commit runs Cypress + lint-staged; NEVER `--no-verify`). Implementation reviews must review COMMITTED code (pipeline rule 15) — commit before requesting review.

## Verification commands

Run from `/Users/jessica/wrk/wrk-corp/inflow-ats`:

- [ ] V1 Migrations: `bundle exec rails db:migrate` then `RAILS_ENV=test bundle exec rails db:migrate`; `bundle exec rails db:migrate:status | tail -5` shows both `up`.
- [ ] V2 New RSpec: `bundle exec rspec spec/controllers/api/v1/registrations_controller_spec.rb spec/models/user_from_omniauth_spec.rb spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb spec/controllers/api/v1/organizations_controller_spec.rb spec/controllers/hire/confirmations_controller_spec.rb`
- [ ] V3 Full RSpec suite stays green: `bundle exec rspec`
- [ ] V4 Jest: `nvm use && yarn jest app/javascript/shared/lib/utils.test.js`, then full `nvm use && yarn jest`
- [ ] V5 Lint (new/modified lines only — do not fix pre-existing violations, do not auto-fix whole files): `nvm use && npx eslint app/javascript/shared/lib/utils.js app/javascript/shared/lib/utils.test.js app/javascript/shared/queryHooks/useSession.ts app/javascript/ats/src/views/sessions/Auth.tsx app/javascript/ats/src/views/sessions/components/AuthForm.tsx app/javascript/ats/src/views/sessions/components/SignupForm.tsx app/javascript/ats/src/views/sessions/components/GoogleSSOButton.tsx app/javascript/ats/src/views/sessions/components/OrganizationForm.tsx app/javascript/ats/src/views/sessions/components/ProfileForm.tsx` and `bundle exec rubocop <changed .rb files>`
- [ ] V6 Event-name census: `git grep -n user_signed_up_client_side app/` → exactly the two frontend callsites (`AuthForm.tsx`, `SignupForm.tsx`); `git grep -n "'user_signed_up'" app/` → unchanged server callsites only.
- [ ] V7 `from_omniauth` census: `git grep -n "from_omniauth"` → definition (keyword signature) + keyword call sites only; zero positional calls.
- [ ] V8 Zero-diff check on the do-NOT-touch list: `git status --porcelain` contains no serializer/policy/job/api.ts/context/cypress paths; `git diff develop...HEAD --stat` matches the Files list above plus `db/schema.rb` and `posthog.ts`.

## Documentation impact

None. No docs pages exist for signup attribution or PostHog events in the repo; the spec requires none. (The working-directory artifacts — SPEC.md, funnel-audit.md — are the documentation of record for this feature.)

## Open-PR conflict check (performed at planning time)

No open PR updated within the last 3 weeks (newest: #3035 `messaging-improvements`, 2026-06-05). Overlap scan of the two newest branches against the feature files: `messaging-improvements` — none. `recruiter-links` (#3005) reformats `Api::V1::OrganizationsController#organization_params` (adds `:enable_recruiter_submission_links`) — a different method from the `create` lines this PR touches; textual conflict unlikely, semantic conflict none. No coordination needed.

## Risks and open questions

1. **Missed positional `from_omniauth` caller** would raise `ArgumentError` on every SSO login — mitigated by B6.3's mandatory census re-run and T3.5/T4.3 pinning the keyword interface. Highest-blast-radius item in the PR.
2. **`emailConfirmed` effect timing** is deliberately state-keyed (not mount-keyed) to be immune to the `useOrganization` `enabled:`-gate cleanup scenario (spec §5.6, corrected in review round 2). Do not "simplify" it into the mount effect.
3. **Accepted spec-bound behaviors — do not re-litigate during implementation or review:** `user_signed_up_client_side` fires for existing users requesting a login link (Risk 1); email address in the confirmation redirect URL (Risk 6/D12); `email_verified` fires only for signed-out confirmations (Risk 7 — open question recorded for Jessica; the diff is identical either way); cookie-session overflow on a direct unsanitized POST to the omniauth request path (Risk 2); `allKeysToSnake` normalizing non-canonical `utm_data` inner keys in transit on JSON paths while the SSO form posts keys verbatim (Risk 3); 255-char cap existing only client-side (Risk 4).
4. **`ActionController::Parameters` → jsonb assignment** (B3.2) relies on the verified `as_json` delegation (actionpack 6.1.7.7). T2.3's hash round-trip assertion is the falsifier — if it ever renders `{"parameters" => ...}`-shaped garbage, convert with `.to_h` at the merge site (would be a plan deviation to surface, not silently apply).
5. **Test-DB migration state:** T2–T6 fail with `UndefinedColumn` if `RAILS_ENV=test bundle exec rails db:migrate` was skipped (V1). Remember: `db:test:prepare` is prohibited — use `db:migrate` under `RAILS_ENV=test` only.
6. **Controller-spec routing for `Hire::ConfirmationsController`** sits under `constraints SubdomainAppConstraints` — expected fine (constraints gate recognition, not generation); contingency documented in T6.1.
7. **Pre-commit Cypress** (`registration.cy.js`) must keep passing; if it fails for reasons unrelated to this diff, do not commit and document the failure (repo Cypress rules) — never bypass the hook.

## Estimated scope

- 2 new migrations (+ regenerated `db/schema.rb`)
- 6 backend files edited (~45 lines added/changed total)
- 8 frontend files edited + 1 helper added to `utils.js` (~130 lines added/changed total, incl. the already-applied `posthog.ts` diff)
- 6 new test files (~380 lines)
- Total: 16 modified files (incl. `db/schema.rb` and `posthog.ts`), 8 new files, roughly +550/-15 lines.
