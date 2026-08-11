# test-coverage — Round 2 (always-on check + always-on impl angle)

Executed this round (all fresh runs):

- `RAILS_ENV=test bundle exec rspec` over the five new spec files: **17 examples, 0 failures** (test DB migrated through `20260715233506`).
- `yarn jest app/javascript/shared/lib/utils.test.js`: **8/8 pass**.
- Full `yarn jest`: 4 suites — only the known pre-existing `FormCheckbox/test.tsx` failures (3); `Button.test.tsx`, `utils.test.js`, `devUtils.js` pass. Zero new failures — confirms the `utils.js` (new `query-string` import) and `posthog.ts` edits broke no other suite.
- Baseline non-intersection: the ~148 pre-existing RSpec failures live in AI-credit/AI-summary specs; none of the five files touched here are among them, and all five run clean.

Coverage adequacy against spec §9: every enumerated RSpec case exists (magic_create new-user raw + nil, existing-confirmed, existing-unconfirmed, create with/without; from_omniauth keyword/nil/existing-user/required-kwargs; callback keyword+session-string-key pin including the no-tracking nil case; org copy + tamper + nil; confirmations success/failure redirects) and every enumerated Jest case exists. Ghost-test audit in test-coverage-and-ghost-tests.md — none found. Conventions match the ai-credit analog (stubbing pattern, per-file Devise opt-in, manual record creation, `type: :controller`).

Existing tests: none covered the touched backend code before this feature (re-verified); Cypress `registration.cy.js` unmodified and its assertions don't intersect the changes.

## Findings

No new issues. (The connect-branch coverage note is filed as LOW F1 in test-coverage-and-ghost-tests.md — not double-counted here.)
