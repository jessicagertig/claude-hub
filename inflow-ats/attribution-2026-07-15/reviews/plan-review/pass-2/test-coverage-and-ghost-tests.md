# Test Coverage and Ghost Tests — Pass 2

## Pass 1 correction verification
- F1: amended T4.1 (plan.md line 609) verified — it now requires `before { @request.env['devise.mapping'] = Devise.mappings[:api_v1_user] }` alongside `include Devise::Test::ControllerHelpers` and the around block, with the devise 4.8.1 `assert_is_devise_resource!` rationale. Mapping key re-verified correct: the app's Devise mapping for User is `:api_v1_user` (routes.rb `devise_for :users` under `namespace :api/:v1` + `devise_scope :api_v1_user`); `Devise.mappings[:user]` does not exist in this app, so copying the controller's own line-5 expression would have been wrong — the amendment correctly mirrors T2.1 instead. ✓
- Consistency check: T2.1 (registrations — Devise controller, mapping + helpers ✓), T4.1 (Devise controller, now mapping + helpers ✓), T6.1 (`Hire::ConfirmationsController` < `Hire::BaseController` < `ApplicationController` — NOT a Devise controller, correctly needs neither), T5.1 (`Api::V1::OrganizationsController` — not a Devise controller, auth stubbed per the AI-credit pattern ✓). The amendment introduces no inconsistency across the five RSpec skeletons. ✓

## Fresh scrutiny
- T4 flow re-traced post-amendment: mapping set → `assert_is_devise_resource!` passes → action runs → `session[:oauth_tracking]` seeded string keys read by `session.delete` → stubbed `from_omniauth` receives keyword args (T4.3 matcher) → `user.persisted?` true → `sign_in(user)` (warden from ControllerHelpers) → jobs on `:test` adapter → redirect asserted with the same `"#{Variables::AtsRootUrl}/"` expression the controller uses (value-independent). GET route for the callback exists (routes.rb `get 'users/auth/google_oauth2/callback'`). ✓
- Anti-ghost re-audit of all planned assertions (rule 26): each still fails if its feature line is deleted — keyword pins (T3.5, T4.3), raw-value pin (`'SomeRawValue'`), `be_nil` jsonb pins, not-modified pins (T2.5/T2.6/T3.4), occurrence-order pin (T1.4, non-alphabetical), anti-tamper pin (T5.4), CGI-escape pin (T6.2). No tautological assertion in the plan. ✓
- T2 warden dependency re-checked: `magic_create` existing-unconfirmed branch calls `sign_in(resource_name, user)` and `resource_name` needs the mapping — T2.1 provides both. ✓
- Around-block necessity re-confirmed: `queue_adapter = :inline` in test env (test.rb:64) + `NotifyUserJob`'s real Slack ping — every T2/T3/T5/T6 skeleton carries the around block per `bulk_ai_job_application_summaries_controller_spec.rb:9-14`. ✓
- Jest run re-checked: default testMatch catches `app/javascript/shared/lib/utils.test.js`; not in `testPathIgnorePatterns`; `Button.test.tsx` precedent exists; eslint `exhaustive-deps` is warn-only so V5 cannot fail on the new effect. ✓
- Cypress: T7.1 verification-only; no `cypress/` edits anywhere in the plan. ✓

## Completeness sweep (spec §9)
Every §9 bullet maps to a T-task (9.1→T2.2–T2.7, 9.2→T3.2–T3.5, 9.3→T4.2–T4.4, 9.4→T5.2–T5.4, 9.5→T6.2–T6.3, 9.6→T1.2–T1.8, Cypress→T7.1, event-grep→V6). "No existing specs to update" re-verified (no registrations/omniauth/organizations-create/user specs exist; `from_omniauth` grep returns 2 files).

## Findings
No issues found.

## Amendments Applied
None.
