# test-coverage-and-ghost-tests — Round 1

## Verification performed

All six required test files exist and were EXECUTED during this review:

- **RSpec** (`RAILS_ENV=test bundle exec rspec` on the five new files): **17 examples, 0 failures.**
- **Jest** (`yarn jest app/javascript/shared/lib/utils.test.js`): **8 passed.** Full `yarn jest`: only the KNOWN pre-existing `FormCheckbox/test.tsx` suite fails (3 tests) — unchanged baseline; utils.test.js passes within the full run.

Anti-ghost audit (pipeline rule 26 — every assertion checked for falsifiability):

- **registrations spec:** raw-storage assertions use mixed-case `'SomeRawValue'` (any downcase/`get_created_via`-style mapping would fail them); deleting the permit OR either branch's merge nils the columns and fails the new-user/create examples; `utm_data` nil assertions use `be_nil` (fails on `{}`); `utm_data` round-trip asserted as a string-keyed hash (fails on a `Parameters`-shaped artifact). Every `magic_create` POST carries `login_intent: 'hire'` (routing around the pre-existing connect-branch nil crash — correctly NOT fixed). Devise wiring per plan T2.1: `include Devise::Test::ControllerHelpers` + `@request.env['devise.mapping'] = Devise.mappings[:api_v1_user]` + the ActiveJob `:test` around-block (prevents `NotifyUserJob`'s real Slack ping under the `:inline` test adapter).
  - The existing-confirmed/existing-unconfirmed examples pass with or without the feature (columns nil before and after) — they are deliberate spec-§9 pinning tests for "existing User's columns are not modified", not ghost coverage; they would catch a regression that assigns in those branches.
- **from_omniauth spec:** the keyword interface is pinned by the creation example (under the old positional signature, `User.from_omniauth(auth: ..., created_via: ..., ...)` collapses to ONE hash argument → ArgumentError → example fails). Existing-user example asserts `not_to change(User, :count)` AND nil columns. `partner_source: 'WWR'` → `'wwr'` pins the unchanged downcasing next to the raw new values. Required-keyword examples per T3.5.
- **omniauth callbacks spec:** `have_received(:from_omniauth).with(auth: anything, created_via: ..., partner_source: ..., utm_source: ..., ...)` fails against a positional call site — pins the D9 conversion. String-key session seed with all six tracking keys pins the `:json`-serializer read; the no-session example pins nil-for-absent on the SSO path. Redirect asserted.
- **organizations spec:** deleting any copy line fails the copy example; anti-tamper example (unpermitted `utm_source: 'attacker'` in the body) pins that values never come from the request; nil case uses `be_nil`.
- **confirmations spec:** success redirect asserted as the full interpolated URL with `CGI.escape` on a `+`/`@` email (pins the encoding); failure redirect asserted byte-identical.
- **Jest:** the 10-key-cap query lists `utm_*` keys in non-alphabetical order (`utm_z` first, `utm_a` eleventh) — an implementation taking order from `parse`'s sorted output would keep `utm_a` and fail (spec §9.6 anti-ghost requirement satisfied). Truncation, first-of-array, exclusions, absent-field semantics (`hasOwnProperty` false — no fabricated `""`/`{}`), null passthrough, `internal_ref`, and non-utm exclusion all covered.

Other checks:

- **"No existing specs to update" claim re-verified:** before this branch, `spec/controllers/api/v1/` contained only the three AI-credit specs; `git grep from_omniauth` at base matched only `user.rb` + the callbacks controller. Confirmed — all six files are new; `spec/controllers/hire/` and `spec/controllers/api/v1/users/` directories were created.
- **Pre-existing suite failures — non-intersection confirmed (not flagged):** the known ~148 pre-existing failures live in AI-credit/AI-summary specs. Grep of all `spec/models/ai_*`, `organization_ai_*`, `job_*`, `textract_*` and the AI-credit controller specs for `magic_create|from_omniauth|OrganizationsController|ConfirmationsController|OmniauthCallbacks|sign_up_params` → zero matches. Those specs create Users/Organizations via `create!`/`api_factories` (never via the modified controllers), and this diff adds only nullable no-default columns and a signature change on a method they never call. Non-intersecting.
- **Cypress:** zero diff under `cypress/` (the 24-file commit list contains none). `registration.cy.js` runs in the pre-commit hook; this review did not re-run Cypress (browser-run out of review scope; noted under operational-concerns).
- **Test conventions:** `type: :controller`, per-file Devise opt-in, `allow(controller).to receive(...)` stubs per the ai-credit analog, inline `User.create!` record setup (bang methods permitted in specs — rule 11 exception; the plan's T-tasks specified inline creation, and `create_api_test_setup` would over-provision org/api_key state these specs must not have), `reload` used only in specs (permitted).

## Findings

No issues found.
