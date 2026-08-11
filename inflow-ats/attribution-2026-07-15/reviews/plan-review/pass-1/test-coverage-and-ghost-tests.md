# Test Coverage and Ghost Tests — Pass 1

## Fact Check

| Claim (plan) | Verified against | Result |
|---|---|---|
| C.4: none of the six test files exists; `spec/controllers/` contains only `api/`; `spec/controllers/api/v1/` contains only the three AI-credit specs; no `spec/models/user_*` spec; no `app/javascript/shared/lib/*.test.js` | live listings | ✓ re-verified — `spec/controllers/hire/` and `spec/controllers/api/v1/users/` must be created, as the plan says |
| Around-block precedent `bulk_ai_job_application_summaries_controller_spec.rb:9-14`; `include Devise::Test::ControllerHelpers` at line 7 | live file lines 1–14 | ✓ exact (`ActiveJob::Base.queue_adapter = :test` swap/restore) |
| `config/environments/test.rb:64` — `config.active_job.queue_adapter = :inline` (why the around block is mandatory) | live file line 64 | ✓ exact |
| `NotifyUserJob` pings a real Slack webhook when the user has an organization | `app/jobs/notify_user_job.rb` (`return unless organization`; `Slack::Notifier.new(...).ping`) | ✓ — inline adapter would fire it; around block is load-bearing |
| `Recaptcha::Verifier#verify` returns success in test env | `app/services/recaptcha/verifier.rb:16` — `return VerificationResult.new(true) if Rails.env.test?` | ✓ exact |
| rails_helper has no Devise helpers wired globally | `grep -i devise spec/rails_helper.rb spec/spec_helper.rb` → none | ✓ |
| Manual factories, no FactoryBot; `spec/support/api_factories.rb` exists | live listing + AI-credit spec stub pattern (`allow(controller).to receive(:authenticate_api_v1_user!)` / `:current_user` / `:authorize`) | ✓ |
| T2.1 `@request.env['devise.mapping'] = Devise.mappings[:api_v1_user]` | routes.rb — `devise_for :users` inside `namespace :api/:v1` with `devise_scope :api_v1_user` → mapping name `:api_v1_user` | ✓ correct and REQUIRED (see F1) |
| T2.2 `login_intent: 'hire'` requirement (connect branch evaluates `organization.id` on nil) | registrations_controller.rb:88–97 — branch condition `login_intent == 'connect' && organization.nil?` then `connect_login_intent_organization_id: organization.id` | ✓ crash confirmed; routing around it (not fixing) matches spec §9.1 and the Do-NOT-touch list |
| T4.3 mapping `partner 'wwr'` → `created_via_weworkremotely_referral`; redirect `"#{Variables::AtsRootUrl}/"` | callbacks controller's own `get_created_via` mapping + line 29; `created_via` enum values in `app/models/concerns/created_via_able.rb` | ✓ |
| T3.2 `created_via: 'created_via_signup'` valid enum value | created_via_able.rb:8 | ✓ |
| T5.1 stub list matches base-controller before_actions | `Api::V1::BaseController` — `authenticate_api_v1_user!`, `set_sentry_context` | ✓ |
| T5.2 `organization:` wrapper (`params.require(:organization)`) | organization_params | ✓ |
| T5.4 anti-tamper example is executable (unpermitted param logs, doesn't raise) | `action_on_unpermitted_parameters` unset in `config/` → Rails 6.1 default `:log` in test | ✓ |
| T6.1 no Devise helpers needed; SubdomainAppConstraints contingency | `Hire::BaseController` (only `skip_before_action :track_ahoy_visit`; no auth); routes.rb:541/577 | ✓ — constraints gate recognition, not generation; contingency documented |
| T6.2 Devise confirmable stores raw token in `confirmation_token` | devise 4.8.1 (confirmable does not digest confirmation tokens) | ✓ |
| T1 runnable: jest configured (default testMatch catches `app/javascript/shared/lib/utils.test.js`), `Button.test.tsx` precedent exists | jest.config.js + live file | ✓ |
| V1–V8 verification commands | commands + DB-safety rules | ✓ (db:migrate only; census greps match spec §9's reviewer checks) |

## Anti-ghost audit (pipeline rule 26)

Every planned assertion fails if the corresponding feature line is deleted:
- T1.4 uses non-alphabetical `utm_*` occurrence order → a parse-key-order implementation keeps `utm_a` and fails ✓ (verified against the v6.1.0 sort behavior).
- T2.3 mixed-case `'SomeRawValue'` → any downcase/mapping alters it ✓; `utm_data` hash round-trip with string keys ✓ (actionpack `as_json` delegation verified).
- T2.4/T3.3/T5.3 `be_nil` on jsonb distinguishes `nil` from `{}` ✓ (no column default to fabricate `{}`).
- T2.5/T2.6/T3.4 existing-user not-modified assertions fail if assignment leaks outside creation ✓.
- T3.5 `ArgumentError` on missing required keywords pins the keyword interface ✓.
- T4.3 `have_received(:from_omniauth).with(auth: anything, created_via:..., utm_source:...)` fails if the call site stays positional or drops a value ✓.
- T5.4 fails if `utm_source` is ever permitted through `organization_params` ✓.
- T6.2 `confirm%2Btest%40example.com` pins CGI-escaping ✓.

## Completeness (spec §9)

All six files planned (T1–T6) cover every §9 bullet; Cypress read-only verification (T7.1) covers the §9 Cypress requirement; V6 covers the event-name grep check. No existing specs to update — re-verified true.

## Findings

- F1 [HIGH] plan.md Task T4.1 — the omniauth-callbacks controller spec skeleton omits `@request.env['devise.mapping'] = Devise.mappings[:api_v1_user]`. Evidence: `Api::V1::Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController < DeviseController`; devise 4.8.1 `devise_controller.rb:17` runs `prepend_before_action :assert_is_devise_resource!`, which raises `AbstractController::ActionNotFound` ("Could not find devise mapping for path … You are testing a Devise controller bypassing the router") whenever `request.env["devise.mapping"]` is unset — and `Devise::Test::ControllerHelpers` does not set it (no mapping handling anywhere in `lib/devise/test/controller_helpers.rb`). The controller's own line-5 assignment (`request.env["devise.mapping"] = Devise.mappings[:user]`) runs inside the action, AFTER the prepend_before_action, so it cannot save the spec. Every T4 example would fail at dispatch; an implementation agent would be left improvising. T2.1 already carries the exact line needed. (Latent gap inherited from spec §9.3, which mandates only the ControllerHelpers include; adding the mapping line is test-mechanics, not a decision deviation — §9.1 sets the in-spec precedent.) Fix: add `before { @request.env['devise.mapping'] = Devise.mappings[:api_v1_user] }` to T4.1.

## Amendments Applied

- plan.md T4.1: added the `before { @request.env['devise.mapping'] = Devise.mappings[:api_v1_user] }` requirement with the devise 4.8.1 `assert_is_devise_resource!` rationale.
