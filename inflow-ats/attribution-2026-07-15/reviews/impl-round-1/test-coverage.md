# test-coverage (always-on) — Round 1

Full detail lives in `test-coverage-and-ghost-tests.md` (the feature-specific angle); this always-on check confirms adequacy and conventions at the suite level.

## Verification performed

- **Existence:** all six spec-§9-required test files exist (5 RSpec + 1 Jest) — the exact set, no extras, no gaps.
- **Executed results:** 17 RSpec examples / 0 failures (`RAILS_ENV=test`, both migrations `up` on the test DB); Jest 8/8 on `utils.test.js`; full `yarn jest` shows ONLY the known pre-existing `FormCheckbox/test.tsx` failures (3) — no new Jest breakage from the shared `utils.js` edit.
- **Right things tested:** persistence-level assertions (columns on the found User/Organization), not reflective/tautological checks; every rule of the sanitizer has a dedicated falsifiable case; the two interface risks the spec called highest-blast-radius (positional `from_omniauth` caller; parse-order 10-key cap) each have a test that fails under the wrong implementation.
- **Conventions:** `type: :controller`, per-file Devise opt-in with the `:api_v1_user` mapping, ai-credit-analog stubbing, ActiveJob `:test` around-blocks in all five files (necessary — `queue_adapter = :inline` in test env would run `NotifyUserJob`/`PosthogTrackJob`/`OrgOwnerUpdateJob` inline), bang methods and `reload` confined to specs.
- **Pre-existing failures:** non-intersection with the ~148 AI-credit/AI-summary failures confirmed by grep (no AI spec references any modified controller/method) and by structure (nullable no-default columns; signature change on a method no existing spec calls).
- **Cypress:** zero diff; no new Cypress tests required per spec §9 (browser PostHog events are verified manually by Jessica via `window.logger`).

## Findings

No issues found.
