# test-coverage-and-ghost-tests — Round 1

Verified against live source: `spec/` layout (controllers/models/support all exist; `spec/controllers/api/v1/` holds only AI-credit-era specs — no registrations/omniauth/organizations-create/confirmations specs, spec §9 claim re-verified), `spec/rails_helper.rb` (no Devise helpers wired globally — verified by grep), `spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb:7` (`include Devise::Test::ControllerHelpers` — the per-file precedent), `spec/controllers/api/v1/organization_ai_credit_purchases_purchase_top_up_spec.rb` (stubbing pattern for BaseController-derived controllers: `allow(controller).to receive(:authenticate_api_v1_user!/:current_user/:authorize)`), `spec/support/api_factories.rb` (manual factories, `create_api_test_setup` etc., no FactoryBot), `app/services/recaptcha/verifier.rb:16` (`return VerificationResult.new(true) if Rails.env.test?` — spec's no-stubbing claim verified), `jest.config.js` (no `roots`/`testMatch` restriction → `app/javascript/shared/lib/utils.test.js` is collected; `Button.test.tsx` precedent exists), `cypress/e2e/auth/registration.cy.js` (both signup paths; password path traverses the confirmation redirect via `currentUser.confirmationUrl` → `Hire::ConfirmationsController#show`; URL assertions are `include`-based and PostHog is disabled under `IS_TEST_ENV` while `window.logger` is a defined no-op — the redirect param additions and new events cannot break it), `registrations_controller.rb` lines 88–97 (the `login_intent` crash branch), routes 577/684 (`get '/email_confirmation' → confirmations#show'` — `Hire::ConfirmationsController < Hire::BaseController < ApplicationController`, NOT a Devise controller, so its spec needs no mapping/warden).

## Findings

- F1 [MED] Spec §9 items 1 and 3 prescribed Devise-controller specs with only `@request.env['devise.mapping']` set. Both `magic_create`/`create` (`sign_up`/`sign_in`) and `google_oauth2` (`sign_in(user)`) invoke warden, which is absent in controller specs unless `Devise::Test::ControllerHelpers` is included — the POSTs would error before reaching any assertion. The suite's own precedent is per-file inclusion (`bulk_ai_job_application_summaries_controller_spec.rb:7`). / Fix applied: §9 items 1 and 3 now require `include Devise::Test::ControllerHelpers`, citing the precedent.
- F2 [MED] Spec §9 item 1's `magic_create` POSTs, as previously written (no `login_intent`), default `login_intent` to `'connect'`; with no `organization_slug` the connect branch of the `user_params` conditional dereferences `organization.id` on nil (`registrations_controller.rb:88–97`) → `NoMethodError` → 500 in every new-user test. Pre-existing latent defect outside feature scope (production always sends `loginIntent: "hire"` from `AuthForm.tsx:78`); the fix must be in the tests' inputs, not the controller. / Fix applied: §9 item 1 now mandates `login_intent: 'hire'` on every `magic_create` POST with the mechanism explained and an explicit do-not-fix note.

## Ghost-test audit of the required assertions (rule 26)

Each required assertion fails if the corresponding spec'd change is deleted — no tautologies found:
- Raw-storage assertion pins an unmapped value (`'SomeRawValue'`) — fails if a downcase/mapping sneaks in, fails if the permit/merge is dropped (column nil).
- Nil-columns assertion distinguishes `nil` from `{}` on jsonb — fails if a default or `|| {}` fabrication appears.
- Existing-user not-modified assertions fail if assignment leaks outside the new-user branch / `first_or_create` block.
- Omniauth controller spec pins the keyword call + string-key session read — fails on a missed positional call site or symbol-key read.
- Jest occurrence-order case (as amended under frontend-capture F1) now discriminates sorted-parse implementations — previously it was satisfiable by an alphabetical cap, i.e. a ghost with respect to the order rule.
- Confirmation-redirect spec pins both branches (success URL gains id+encoded email; failure URL byte-identical).

## Verified-clean

- "No existing specs to update" — re-verified this round.
- Cypress read-only constraint respected; no new Cypress required (browser events unverifiable under `IS_TEST_ENV` — correctly delegated to Jessica's dev logger check).
- Event-name grep check (§9 tail) is falsifiable and cheap.

## Amendments Applied

- SPEC.md §9 item 1: `Devise::Test::ControllerHelpers` + mandatory `login_intent: 'hire'` with rationale.
- SPEC.md §9 item 3: `Devise::Test::ControllerHelpers` with rationale.
