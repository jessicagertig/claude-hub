# test-coverage-and-ghost-tests — Round 2

Re-derived fresh; all suites executed this round.

## Verified

- **All six required test files exist** and sit where §9 puts them: `spec/controllers/api/v1/registrations_controller_spec.rb`, `spec/models/user_from_omniauth_spec.rb`, `spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb`, `spec/controllers/api/v1/organizations_controller_spec.rb`, `spec/controllers/hire/confirmations_controller_spec.rb`, `app/javascript/shared/lib/utils.test.js`.
- **Conventions:** `type: :controller`; Devise helpers opted in per-file (`include Devise::Test::ControllerHelpers` + `@request.env['devise.mapping']` where sign_in/sign_up run); the organizations spec stubs `authenticate_api_v1_user!`/`current_user`/`authorize`/`set_sentry_context` per the ai-credit analog; manual `User.create!` record creation (bang methods allowed in specs); no FactoryBot.
- **Falsifiability (rule 26) checked per assertion class:** delete the permit additions → `'SomeRawValue'` assertions fail (unpermitted params dropped); delete either `magic_create` branch merge → the exercised default branch's assertions fail; delete the `first_or_create`-block assignments → model-spec raw assertions fail; revert the keyword signature → ArgumentError assertions and the controller spec's kwargs `have_received` match fail; revert the redirect → `redirect_to` equality fails; delete the org copy → `eq 'SomeRawValue'` fails. Raw-storage assertions use the unmapped `'SomeRawValue'`; nil assertions distinguish `nil` from `{}` on jsonb (`be_nil` on `utm_data`); existing-user branches assert non-modification after reload. The Jest 10-key-cap test orders `utm_z…utm_q, utm_a` — non-alphabetical, falsifying a parse-sorted implementation as §9.6 demands. No ghost tests found.
- **`magic_create` POSTs all include `login_intent: 'hire'`** with the spec-mandated comment documenting the pre-existing connect-branch NoMethodError being routed around, not fixed.
- **Executed:** 5 RSpec files → 17 examples, 0 failures (`RAILS_ENV=test`, test DB migrated through `20260715233506`). `utils.test.js` → 8/8. Full `yarn jest` → only the known pre-existing `FormCheckbox/test.tsx` failures (3), zero new.
- **Spec's "no existing specs to update" claim re-verified:** `git grep from_omniauth` matches only the definition, the sole call site, and the two new specs; `spec/controllers/api/v1/` contained only the three AI-credit specs before this feature.
- **Cypress:** zero diffs under `cypress/`; `registration.cy.js` asserts only `/needs-email-confirmation` and `/jobs` URL fragments — no assertion intersects the confirmation-redirect param additions or the request payload additions.
- **Baseline non-intersection:** the ~148 pre-existing failures live in AI-credit/AI-summary specs — none of the five files run here; both runs completed clean.

## Findings

- F1 [LOW] `spec/controllers/api/v1/registrations_controller_spec.rb` / connect-intent branch merge keys untested / all `magic_create` examples use `login_intent: 'hire'` (per spec §9's own instruction), so only the default branch's four-key merge is exercised by a test; the connect-intent branch's identical merge is verified by code reading only. That branch is currently unreachable without raising (pre-existing `organization.id`-on-nil when the `organization.nil?` condition is true — documented out of scope in spec §9), so a test cannot exercise it without first fixing the pre-existing bug. Spec §9 does not require this coverage; noted for completeness only.

No BLOCKER/HIGH/MED findings.
