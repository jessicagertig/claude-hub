# Review Angles — UTM/attribution capture + PostHog funnel events

Generated from: SPEC.md (binding decisions: approved-decisions.md D1–D17, no D11; context: funnel-audit.md)
Date: 2026-07-15
Repo: /Users/jessica/wrk/wrk-corp/inflow-ats (branch `attribution-work`; `app/javascript/shared/lib/posthog.ts` already modified uncommitted on the branch as part of this feature)

## Subsystems touched

**Backend (all edits to existing files except the two new migrations):**
- `db/migrate/<timestamp>_add_attribution_columns_to_users.rb` — NEW: `utm_source` string, `utm_campaign` string, `utm_data` jsonb, `internal_ref` string; no defaults, nullable, no index
- `db/migrate/<timestamp>_add_attribution_columns_to_organizations.rb` — NEW: identical column set
- `app/controllers/api/v1/registrations_controller.rb` — `sign_up_params` (line 300–303) permits the four params (`utm_data: {}` trailing hash-permit); `magic_create` merges the four into `user_params` in both branches of the two-branch conditional (lines 88–107); `create` needs no change beyond the permit (assigned via `expanded_params = sign_up_params.merge(...)` at lines 13–16)
- `app/controllers/api/v1/organizations_controller.rb` — `create` copies the four values from `current_user` onto the new Organization, alongside the existing `@organization.created_via = current_user.created_via` (line 31)
- `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` — line 22 call site converted to keyword form; four new values supplied from `merged_tracking` (string keys)
- `app/models/user.rb` — `from_omniauth` (line 379) converted to all-keyword signature; four new assignments inside the `first_or_create` block only
- `config/initializers/omniauth.rb` — line 14 `allowed_keys = %w[partner referral]` grows to include `utm_source utm_campaign utm_data internal_ref`
- `app/controllers/hire/confirmations_controller.rb` — line 18 success redirect gains `id` and URL-encoded `email` query params

**Frontend (all edits to existing files):**
- `app/javascript/shared/lib/utils.js` — NEW helper `sanitizeTrackingParams` (spec-proposed name), placed alongside `standardizeQueryParamsObject` at the top of the file
- `app/javascript/ats/src/views/sessions/components/AuthForm.tsx` — capture into state (analog: `referral` at line 37, `partner` at line 38), four fields into the `magicLink` payload in `handleAuth`, four props onto `GoogleSSOButton` (line 120), `trackEvent("user_signed_up_client_side")` in `magicLink` onSuccess (lines 82–84)
- `app/javascript/ats/src/views/sessions/components/SignupForm.tsx` — capture (analog: `referral` at line 23), four fields into `register` payload, `trackEvent("user_signed_up_client_side")` in `register` onSuccess (lines 66–69)
- `app/javascript/ats/src/views/sessions/components/GoogleSSOButton.tsx` — `Props` gains `utmSource?`/`utmCampaign?`/`utmData?`/`internalRef?`; hidden inputs alongside `referral`/`partner` (lines 46–51), `utm_data` as one input per key with Rails-nested `utm_data[key]` naming
- `app/javascript/shared/queryHooks/useSession.ts` — `magicLink` (lines 41–82: destructure, inline TS type, `variables`) and `register` (lines 27–39: destructure, `variables`) gain the four fields; hook wrappers `useMagicLink`/`useRegister` unchanged
- `app/javascript/ats/src/views/sessions/Auth.tsx` — in `showEmailConfirmationBannerIfApplicable` (lines 22–29), on `email_confirmed=true`: guarded `identifyUser({ id: Number(id), email })` then `trackEvent("email_verified")`
- `app/javascript/ats/src/views/sessions/components/OrganizationForm.tsx` — `trackEvent("organization_created")` in `createOrganization` onSuccess (lines 68–71) before `onComplete(data)`
- `app/javascript/ats/src/views/sessions/components/ProfileForm.tsx` — one of `organization_owner_user_name_submitted` / `invited_user_name_submitted` in `updateMe` onSuccess (lines 64–67), keyed on the existing `isNewOwner` prop
- `app/javascript/shared/lib/posthog.ts` — ALREADY ON BRANCH (uncommitted): `window.logger` in `identifyUser` fire + skip paths; commit as-is, no further edit

**Tests (all new; verified none exist today):**
- `spec/controllers/api/v1/registrations_controller_spec.rb`
- `spec/models/user_from_omniauth_spec.rb` (or equivalent)
- `spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb`
- `spec/controllers/api/v1/organizations_controller_spec.rb`
- `Hire::ConfirmationsController` spec
- `app/javascript/shared/lib/utils.test.js` (Jest; precedent `app/javascript/ats/src/components/shared/Button/Button.test.tsx`, config `jest.config.js`)

**Explicitly NOT touched (reviewer verifies zero diff):** serializers (`Api::V1::SessionSerializer`, `Api::V1::OrganizationSerializer`), policies, models other than `user.rb` (including `app/models/organization.rb` — repo rule restricts edits; the spec requires none), Sidekiq jobs (`PosthogTrackJob`/`PosthogIdentifyJob` callsites), `api.ts`, context files, existing Cypress tests (`cypress/e2e/auth/registration.cy.js` must keep passing).

## Full-stack analog

**The referral/partner arrival-param capture flow** — the exact same shape of work: a tracking param arrives on the auth page URL, is held in component state, threads through all three signup transports, and lands on the User (and Organization) at creation time. Verified end-to-end in live code:

- **Frontend capture:** `AuthForm.tsx:37` (`React.useState(queryString.parse(location.search).referral)`) and `:38` (`partner`); `SignupForm.tsx:23` (`referral`). `AuthForm` receives `location={props.location}` from both `Auth.tsx:72` (`/auth`) and `AuthRegister.tsx:134` (`/auth-register`).
- **Magic-link payload:** `AuthForm.tsx` `handleAuth` (lines 70–98) passes `referral`/`partner` → `useSession.ts` `magicLink` (lines 41–82) → `apiPost` (`app/javascript/shared/queryHooks/api.ts:52` runs `allKeysToSnake` from `app/javascript/ats/src/lib/utils/structure.js:94-105`, lodash `snakeCase` per key, recursing into nested objects) → `POST /magic_login` (`config/routes.rb:82`).
- **Password payload:** `SignupForm.tsx` `handleSignup` (lines 56–77) passes `referral` → `useSession.ts` `register` (lines 27–39) → `POST /sign_up` (`config/routes.rb:81`).
- **Controller:** `app/controllers/api/v1/registrations_controller.rb` — `sign_up_params` permit (line 302); `magic_create` builds `user_params` with `partner_source: params[:partner]&.downcase` in both branches (lines 88–107), row created only in the new-user branch (`build_resource(user_params)` line 158); `create` builds `expanded_params = sign_up_params.merge(created_via:, partner_source:)` (lines 13–16); `get_created_via` mapping (lines 316–342).
- **SSO threading:** `GoogleSSOButton.tsx:31` plain HTML form POST to `/api/v1/users/auth/google_oauth2` with hidden inputs rendered only-when-present (lines 46–51, `typeof referral === "string" && referral.length > 0`) → `config/initializers/omniauth.rb:12-27` `setup` lambda whitelists via `allowed_keys` (line 14) into `env['rack.session'][:oauth_tracking]` → `app/controllers/api/v1/users/omniauth_callbacks_controller.rb:9` (`session.delete(:oauth_tracking) || {}`), `:14-15` (`merged_tracking = request_phase_params.merge(tracking_from_session)`, string keys), `:22` (`User.from_omniauth(oauth_data, created_via_value, partner_param)` — the sole call site, positional today).
- **Model, creation-time-only:** `app/models/user.rb:379` `from_omniauth`; `first_or_create` block assigns `created_via` and `partner_source&.downcase` only when the row is created (lines ~385–393); post-block `assign_attributes(remember_me: true)` / `update(first_name:, last_name:)` / `enqueue_complete_user_setup` run for everyone.
- **Org inheritance:** `app/controllers/api/v1/organizations_controller.rb:31` `@organization.created_via = current_user.created_via` inside `create`; Pundit `authorize @organization` follows.
- **PostHog event analog (browser):** `NewJobCenterModal.tsx:47` (`trackEvent("job_created", ...)` in a create-mutation onSuccess) and `CommentTemplateModal.tsx:100` (plain no-property call); identify analog `AppAuthRouter.tsx:165-177` (`identifyUser` effect, deps `[currentUser, organizationId, currentPlan, organizationName]`); helpers in `app/javascript/shared/lib/posthog.ts` (`identifyUser` keys on `String(user.id)`; `trackEvent` → `ph.capture`).
- **jsonb permit analog:** `app/controllers/api/v1/questions_controller.rb:50` — `permit(..., options: {})` trailing hash-permit into the `questions.options` jsonb column.
- **Migration analog:** `db/migrate/20260622182504_add_ai_summary_and_criteria_columns_to_jobs.rb` (`ActiveRecord::Migration[6.1]`, plain `add_column` calls) — note its counter columns have `default: 0, null: false`, the new columns deliberately have NO defaults (D6).
- **Auth (analog):** none — `/magic_login`, `/sign_up`, omniauth paths are unauthenticated Devise scope `api_v1_user`; `organizations#create` keeps its existing `authorize @organization`.
- **Serialization (analog):** `created_via`/`partner_source` handling shows the pattern; the four new columns are deliberately NOT serialized (spec §7.6).
- **Tests (analog):** none exist — verified: `spec/controllers/api/v1/` contains only the three AI-credit specs; `git grep from_omniauth` matches only `user.rb` and the callbacks controller. The spec conventions analog is `spec/controllers/api/v1/organization_ai_credit_purchases_purchase_top_up_spec.rb` (type: :controller, stubs `authenticate_api_v1_user!`/`current_user`/`authorize`; no Devise helpers in rails_helper; manual factories in `spec/support/api_factories.rb`, no FactoryBot). Cypress: `cypress/e2e/auth/registration.cy.js` exercises both signup paths (read-only; must keep passing).

**Priority rule:** Where the full-stack analog deviates from convention, the analog wins. Note these APPROVED deviations from the analog itself so the reviewer doesn't flag them:
1. The analog downcases and maps (`partner_source&.downcase`, `get_created_via` mapping to enum values); the new columns store **raw as sent** — D3 mandates this contrast. Flagging "should downcase like partner_source" is wrong.
2. The analog's `from_omniauth` is positional; the feature converts it (and its sole call site) to all-keyword form — D9 mandates the interface change plus a repo-wide call-site search at implementation time.
3. The analog fires server-side PostHog jobs; the new events are browser-side by design (funnel-audit ruling). No `PosthogTrackJob`/`PosthogIdentifyJob` may be added, removed, or modified.
4. `utm_data` inner keys stay as raw URL param names (not camelCased) — accepted deviation from the frontend camelCase rule, like the Ruby-enum exception (spec §5 case-convention note).
5. The migrations omit `default`/`null: false` that sibling jsonb `settings` columns have — D6 mandates nil-for-absent.

## Angles

### 1. frontend-capture-and-sanitization
**What this covers:** The new `sanitizeTrackingParams` helper and its use at both capture sites — correctness of the sanitization rules (255-char truncation, first-of-array for repeated params, 10-key cap on extra `utm_*` keys by occurrence order, `utm_source`/`utm_campaign` excluded from `utmData`), and the absence semantics: absent param → absent field, no `|| ""`, no `|| {}`, no fabricated empty object, `utmData` present only when at least one extra `utm_*` param was captured; `?utm_source` (present, no value) parses to `null` and passes through.
**Files across all layers:**
- `app/javascript/shared/lib/utils.js` (new helper, placed with `standardizeQueryParamsObject` at top of file)
- `app/javascript/ats/src/views/sessions/components/AuthForm.tsx` (capture into state at render, sanitize BEFORE setState; no setter/re-capture)
- `app/javascript/ats/src/views/sessions/components/SignupForm.tsx` (same via `props.location.search`)
- `app/javascript/shared/lib/utils.test.js` (new Jest coverage of every rule)
**Analog files for comparison:** `AuthForm.tsx:37-38` and `SignupForm.tsx:23` (`referral`/`partner` state — the capture mechanism to match exactly); `utils.js` `standardizeQueryParamsObject` (helper placement/shape)
**Convention context:** `cursor_rules/core_critical_rules.md` rules 9 (never deliberately set undefined), 10 (never fabricate fallback values), 13 (`x != undefined` house guard); `cursor_rules/frontend/_base.md`; `cursor_rules/frontend/react_hooks.md`

### 2. params-threading-contract (three signup paths × four values)
**What this covers:** The wire contract for `utmSource`/`utmCampaign`/`utmData`/`internalRef` from component state to persisted User columns on the two JSON paths — camelCase payload → `allKeysToSnake` → `sign_up_params` permit (three scalars + trailing `utm_data: {}` hash-permit) → `magic_create` merge into `user_params` in BOTH branches of the two-branch conditional → row creation only in the new-user branch (existing-user branches inert) → `create` path assigned automatically via `expanded_params`. Verify nil-for-absent survives every hop (absent field serializes out of the JSON body; `sign_up_params[<key>]` nil; column nil, jsonb nil not `{}`), raw storage (no downcase, no mapping), and that `magic_create`'s JSON responses are byte-identical to today.
**Files across all layers:**
- `app/javascript/ats/src/views/sessions/components/AuthForm.tsx` (`handleAuth` payload)
- `app/javascript/ats/src/views/sessions/components/SignupForm.tsx` (`register` payload)
- `app/javascript/shared/queryHooks/useSession.ts` (`magicLink` destructure + inline type + `variables`; `register` destructure + `variables`; hook wrappers unchanged)
- `app/javascript/ats/src/lib/utils/structure.js` (`allKeysToSnake` recursion into `utmData` — behavior noted as fact: non-canonical inner keys like `utm_content2` → `utm_content_2` in transit; canonical `utm_*` names pass through)
- `app/controllers/api/v1/registrations_controller.rb` (`sign_up_params` lines 300–303; `magic_create` lines 88–107 + new-user branch; `create` lines 10–22)
- `db/migrate/*_add_attribution_columns_to_users.rb`
- `spec/controllers/api/v1/registrations_controller_spec.rb` (new)
**Analog files for comparison:** the `referral`/`partner` threading through the same exact files (`AuthForm.tsx` `handleAuth` → `useSession.ts` `magicLink`/`register` → `sign_up_params`/`user_params`); `questions_controller.rb:50` for the `options: {}` hash-permit form (must be the trailing argument of `permit`)
**Convention context:** `cursor_rules/core_critical_rules.md` rules 5 (one params method), 7 (snake_case/camelCase + enum exception), 12 (check save return values); `cursor_rules/backend/controllers/controller_patterns_and_crud.md`; `cursor_rules/backend/_base.md`

### 3. sso-oauth-session-contract
**What this covers:** The SSO branch end-to-end — hidden-input rendering in `GoogleSSOButton.tsx` (render-only-when-present pattern; `utm_data` as one input per key with Rails-nested `name="utm_data[<key>]"` naming; snake_case names written directly since the plain form POST bypasses `allKeysToSnake`), the omniauth `setup` lambda whitelist growth (only line 14 changes; verify the existing loop's `value && !value.empty?` handles the `utm_data` Hash correctly and the `:json` cookie serializer round-trips it with string keys), the session ride and recovery (`session.delete(:oauth_tracking)`, `merged_tracking` string-key reads), the `from_omniauth` keyword conversion (exact signature order per D9: `auth:`, `created_via:` required; `partner_source:`, `utm_source:`, `utm_campaign:`, `utm_data:`, `internal_ref:` defaulting nil), assignment strictly inside the `first_or_create` block (existing SSO users untouched; post-block behavior unchanged), and the mandatory repo-wide call-site search re-run at implementation time (a missed positional call site raises `ArgumentError` on every SSO login — BLOCKER).
**Files across all layers:**
- `app/javascript/ats/src/views/sessions/components/GoogleSSOButton.tsx` (Props + hidden inputs)
- `app/javascript/ats/src/views/sessions/components/AuthForm.tsx` (line 120 props to `GoogleSSOButton`)
- `config/initializers/omniauth.rb` (setup lambda, line 14)
- `config/initializers/cookies_serializer.rb` (`:json` — context for the hash round-trip claim)
- `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` (line 22 keyword call; nothing else changes — Posthog jobs and redirect untouched)
- `app/models/user.rb` (`from_omniauth`, line 379)
- `spec/models/user_from_omniauth_spec.rb`, `spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb` (new)
**Analog files for comparison:** the `referral`/`partner` ride through the identical files (`GoogleSSOButton.tsx:46-51`, `omniauth.rb:12-27`, `omniauth_callbacks_controller.rb:9-22`, `user.rb` `first_or_create` block `created_via`/`partner_source` assignments)
**Convention context:** `cursor_rules/core_critical_rules.md` rules 8 (guard clauses), 12; `cursor_rules/backend/_base.md`; `cursor_rules/backend/code_style_and_structure.md`. Accepted-risk context the reviewer must NOT re-litigate: cookie-session overflow on a direct un-sanitized POST to the omniauth request path (spec Risk 2 — accepted property of the approved no-server-sanitization design).

### 4. org-inheritance-and-persistence
**What this covers:** The two migrations (identical column sets, string/string/jsonb/string, NO defaults, nullable, no index — deliberately unlike the `settings` jsonb `default: {}, null: false`; no backfill; no data migration) and the copy-at-creation semantics: `organizations#create` copies the four values from `current_user` exactly like the adjacent `created_via` copy, `organization_params` NOT modified (values never come from the request — an attacker-controlled `utm_source` in the org-create body must be ignored), nil user columns → nil org columns, no model edits anywhere (`app/models/organization.rb` untouched per repo rule; `user.rb` touched only for `from_omniauth`), no validations/enums/`attr_accessor`, and no serializer exposure (`Api::V1::SessionSerializer`, `Api::V1::OrganizationSerializer` zero-diff).
**Files across all layers:**
- `db/migrate/*_add_attribution_columns_to_users.rb`, `db/migrate/*_add_attribution_columns_to_organizations.rb` (new)
- `db/schema.rb` (regenerated — column shapes match the table above)
- `app/controllers/api/v1/organizations_controller.rb` (`create`, around line 31)
- `app/models/user.rb` / `app/models/organization.rb` (verify NO attribute-level changes beyond the `from_omniauth` edit in user.rb)
- `spec/controllers/api/v1/organizations_controller_spec.rb` (new)
**Analog files for comparison:** `organizations_controller.rb:31` (`created_via` copy); `db/migrate/20260622182504_add_ai_summary_and_criteria_columns_to_jobs.rb` (migration shape — noting its `default: 0, null: false` is exactly what the new migrations must NOT have)
**Convention context:** `cursor_rules/backend/migrations.md`; `cursor_rules/backend/controllers/controller_patterns_and_crud.md`; `cursor_rules/backend/controllers/pundit_policies.md` (existing `authorize @organization` must be unchanged); `cursor_rules/core_critical_rules.md` rule 12

### 5. posthog-events-and-identity
**What this covers:** The five browser events and the confirmation-landing identify — exact event names (`user_signed_up_client_side`, `email_verified`, `organization_created`, `organization_owner_user_name_submitted`, `invited_user_name_submitted`; all plain `trackEvent` calls, NO properties), exact placement (inside the existing component-level `onSuccess` callbacks, before `onComplete`; hook wrappers in `useSession.ts` untouched), the `Hire::ConfirmationsController#show` redirect gaining `id` + URL-encoded `email` on the success branch only (failure branch byte-identical), the `Auth.tsx` identify (`identifyUser({ id: Number(id), email })` guarded on BOTH params present — a stale bookmarked `/auth?email_confirmed=true` must not call `ph.identify("undefined")`; distinct_id must equal the `AppAuthRouter.tsx:168` one via `String(user.id)`), `trackEvent("email_verified")` after the identify, the `isNewOwner` keying in `ProfileForm.tsx` (else-branch covers `wasInvited` and the neither-true edge), and the untouched-server-events invariant: zero `PosthogTrackJob`/`PosthogIdentifyJob` diffs; `git grep user_signed_up_client_side app/` matches only the two frontend callsites; the server's `user_signed_up` string unmodified. Also: the already-on-branch `posthog.ts` `window.logger` diff is committed as-is with no further edits.
**Files across all layers:**
- `app/controllers/hire/confirmations_controller.rb` (line 18 success redirect; line 21 failure unchanged)
- `app/javascript/ats/src/views/sessions/Auth.tsx` (`showEmailConfirmationBannerIfApplicable`, lines 22–29; `AuthRegister.tsx` and `Login.tsx` also read `email_confirmed` but are NOT modified — redirect targets `/auth`)
- `app/javascript/ats/src/views/sessions/components/AuthForm.tsx`, `SignupForm.tsx` (`user_signed_up_client_side` in onSuccess)
- `app/javascript/ats/src/views/sessions/components/OrganizationForm.tsx` (`organization_created`; NO identify added — the `AppAuthRouter.tsx:165-177` effect re-fires because `useCreateOrganization` in `useOrganization.ts:87-102` invalidates `currentOrganization` + `me`; Jessica verifies in dev via the `window.logger`)
- `app/javascript/ats/src/views/sessions/components/ProfileForm.tsx` + `OnboardingProfile.tsx` (lines 16–17, 47–48 — `isNewOwner`/`wasInvited` computed and passed; OnboardingProfile NOT modified)
- `app/javascript/shared/lib/posthog.ts` (already-applied diff; `identifyUser`/`trackEvent` helpers)
- `Hire::ConfirmationsController` spec (new)
**Analog files for comparison:** `NewJobCenterModal.tsx:47` and `CommentTemplateModal.tsx:100` (trackEvent-in-onSuccess placement); `AppAuthRouter.tsx:165-177` (identify shape and distinct_id)
**Convention context:** `cursor_rules/core_critical_rules.md` rule 2a (window.logger encouraged — do not flag), rule 13; `cursor_rules/frontend/react_query/react_query_mutations_and_cache.md`; `cursor_rules/frontend/forms/form_submission_and_mutations.md`. Accepted semantics the reviewer must NOT flag: `user_signed_up_client_side` fires for existing users requesting a login link (shared-form semantics, spec Risk 1); email address in the confirmation redirect URL (spec Risk 6, D12); SSO signups get neither `user_signed_up_client_side` nor `email_verified` (spec §10).

### 6. test-coverage-and-ghost-tests
**What this covers:** Whether the six new test files exist, follow the suite's conventions, and actually falsify the feature — every RSpec assertion must fail if the corresponding assignment/permit/keyword is deleted (raw-storage assertions must use an unmapped value like `utm_source: 'SomeRawValue'` that `get_created_via`-style mapping would alter; nil assertions must distinguish `nil` from `{}` on jsonb; the existing-user branches must assert columns NOT modified; the omniauth controller spec must pin the keyword call + string-key session read; the Jest test must cover truncation, first-of-array, 10-key cap by occurrence order, exclusions, and absent-field semantics). Verify the spec's "no existing specs to update" claim at review time (re-run `git grep from_omniauth`; re-list `spec/controllers/api/v1/`). Verify `cypress/e2e/auth/registration.cy.js` is unmodified and still passes (pre-commit hook).
**Files across all layers:** the six new test files listed under Subsystems touched; `spec/support/api_factories.rb` (manual factories, no FactoryBot); `spec/rails_helper.rb` (no Devise controller helpers — specs must set `@request.env['devise.mapping']` / stub auth per the analog); `jest.config.js`
**Analog files for comparison:** `spec/controllers/api/v1/organization_ai_credit_purchases_purchase_top_up_spec.rb` (type: :controller, stubbing pattern: `allow(controller).to receive(:authenticate_api_v1_user!)` / `:current_user` / `:authorize`); `app/javascript/ats/src/components/shared/Button/Button.test.tsx` (Jest precedent)
**Convention context:** `~/claude-hub/inflow-ats/CLAUDE.md` rule 26 (test assertions must be falsifiable by removing the feature — ghost tests are BLOCKERs); `cursor_rules/core_critical_rules.md` rule 11 exception (bang methods OK in specs); `cursor_rules/cypress/core_critical_rules.md` (context only — no Cypress edits allowed)

### 7. conventions-compliance (fan-out: one reviewer per rules file — pipeline rule 27)
**What this covers:** Per-rules-file compliance of the full diff. This angle is NOT one broad reviewer — at review time it fans out one reviewer per cursor_rules file below, each holding only that file's rules as its checklist against the diff.
**Files across all layers:** the entire feature diff (all files under Subsystems touched).
**cursor_rules files to fan out over (one reviewer each):**
- `cursor_rules/core_critical_rules.md` (rules 1, 5, 7, 8, 9, 10, 11, 12, 13 all have bite here)
- `cursor_rules/backend/_base.md`
- `cursor_rules/backend/controllers/controller_patterns_and_crud.md`
- `cursor_rules/backend/controllers/controller_error_handling.md`
- `cursor_rules/backend/controllers/pundit_policies.md`
- `cursor_rules/backend/migrations.md`
- `cursor_rules/backend/code_style_and_structure.md`
- `cursor_rules/backend/architecture.md`
- `cursor_rules/frontend/_base.md`
- `cursor_rules/frontend/core_critical_rules.md`
- `cursor_rules/frontend/react_hooks.md`
- `cursor_rules/frontend/components/component_architecture.md`
- `cursor_rules/frontend/forms/form_state_and_change_handlers.md`
- `cursor_rules/frontend/forms/form_submission_and_mutations.md`
- `cursor_rules/frontend/forms/form_validation_and_errors.md`
- `cursor_rules/frontend/react_query/react_query_mutations_and_cache.md`
- `cursor_rules/frontend/boolean_variables_and_naming.md`
- `cursor_rules/frontend/reference_patterns.md`
- `cursor_rules/cypress/core_critical_rules.md` (verify-untouched only — no Cypress files may change)
Not relevant to this diff (skip): `public_api_controller_rules.md`, `backend/interactors/*`, `backend/serializers.md` (unless the diff unexpectedly touches a serializer — then it becomes a finding under angle 4), `backend/background_jobs.md` (no job changes allowed — any job diff is a finding under angle 5), `frontend/modals/*`, `frontend/lists/*`, `frontend/contexts/*` (context files are on the never-edit list; any diff there is automatically HIGH), `frontend/ui_styling.md` (no styling changes in scope), remaining `cypress/*` files.
**Convention context:** `~/claude-hub/inflow-ats/CLAUDE.md` Known Failure Pattern 27 (single broad compliance angle finds nothing; per-file fan-out finds real defects).

## Always-on checks

These apply to every feature regardless of angles:

### Source accuracy
The review agent verifies every file path, class, method, column, route, and component the spec references against the current source.

### Test coverage
The review agent checks what existing tests cover the affected code and what new tests the spec should require.

### Backward compatibility
The review agent identifies all consumers of modified code and verifies they are addressed.

### Full-stack analog completeness
The review agent verifies the new feature has a corresponding piece for every layer of the analog pipeline. A missing layer is a BLOCKER. (For this feature: capture state, mutation payload, request-function threading, permit, controller assignment, SSO hidden inputs, setup-lambda whitelist, session recovery, `from_omniauth` assignment, org copy — the analog's layers are enumerated in the Full-stack analog section above. The `referral`/`partner` analog threads through THREE transports; the four new values must thread through all three.)

### Analog structural matching
The review agent greps for analog files, reads their parameter interfaces, retry/exhaustion patterns, callback patterns, and error handling shapes, and diffs them against the new code. Layer completeness ("it has a controller") without structural matching ("the controller accepts the same parameter shape") is insufficient. A structural mismatch is BLOCKER.

What to compare:
- **Controller parameter interfaces:** if existing bulk operations accept `job_id` + `hiring_stage_id` + `included/excluded_ids` with server-side resolution, the new bulk operation must too. Do not accept raw ID arrays resolved client-side when the analog resolves server-side.
- **Job retry/exhaustion patterns:** if other jobs in the same domain use exhaustion blocks on `retry_on`, the new job must too. Do not skip the exhaustion block when analogs have one.
- **Callback patterns:** if analogous models use `after_commit` callbacks to trigger downstream work, the new model should follow the same pattern.
- **Error handling shapes:** if analogs rescue specific error classes and set status before re-raising, the new code must follow the same rescue/status/raise sequence.

Real failures this would have caught: (1) `BulkAiJobApplicationSummariesController` accepted raw `job_application_ids` from the frontend instead of following the `job_id` + `hiring_stage_id` + `included/excluded` pattern used by bulk move and bulk message controllers. Passed a full QA round unflagged. (2) `GenerateAiJobApplicationSummaryJob` lacked an exhaustion block on `retry_on` despite `GetResumeTextFromTextractJob` and `BulkGenerateAiSummariesJob` both having one. Users saw multiple failure toasts before retries exhausted.

(For this feature the approved deviations listed under the Priority rule — raw storage vs. the analog's downcase/mapping, keyword conversion of `from_omniauth`, browser-side events, raw `utm_data` inner keys, no-default migrations — are spec-mandated and must not be reported as structural mismatches. Everything else must match the analog structurally: hidden-input render guards, session-ride mechanics, `first_or_create`-block-only assignment, copy-at-org-create shape, onSuccess event placement.)
