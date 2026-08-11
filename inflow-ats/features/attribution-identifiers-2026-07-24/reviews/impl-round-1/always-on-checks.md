# Impl round 1 — always-on-checks (source accuracy, test coverage, backward compat, analog completeness, analog structural matching)

## Source accuracy

Every file path, class, method, column, and component in the diff verified against the live committed tree at `a0d59115d`. All 18 diff files match the plan's file list exactly (2 migrations created + 12 modified + 4 spec extensions). No phantom references.

## Test coverage (calibrated per harness-profile.md)

- **Cypress (top priority):** `cypress/e2e/auth/registration.cy.js` untouched (read-only ✓). Read the file: 72 lines, zero references to tracking params, cookies, payload shapes, or intercepts — the payload additions cannot break it.
- **RSpec:** all four SPEC §10 files extended per spec, no new files. Ran all four: **20 examples, 0 failures.** Pinning values present: `ga_session_id` containing `=`/`.`/`;` (`'_ga_ABC123XYZ=GS1.1...0.0.0; _ga_DEF456=GS1.1.2.3'`), >255-char fbclid (`'fb' + ('x' * 300)`), `login_intent: 'hire'` on every `magic_create` POST. Stale "five attribution values" counts updated everywhere (repo grep finds no remaining "five attribution" reference; the one `all five` hit is unrelated `ai_job_criteria_spec.rb`).
- **Stubs vs production types:** the `have_received(:from_omniauth).with(...)` expectations pass string values for the eight keywords — production passes `merged_tracking['<key>']` strings from the session hash. Types match; no stub masks a mismatch. Expectations remain exhaustive keyword matches (not `hash_including`) — they fail at dispatch if the call site and spec drift, by design.
- **Ghost tests:** none found. Every new assertion fails against the pre-feature code (columns wouldn't exist / values wouldn't land / keywords wouldn't be passed). One nuance filed as LOW under collection-point-move: the inverted org-spec example pins the feature as a whole but cannot isolate the permit removal from the copy lines.

## Backward compatibility

Consumer sets re-grepped at review time, all addressed:
- `sanitizeTrackingParams`: `AuthForm.tsx` + `SignupForm.tsx` only — both extended.
- `sanitizeTrackingValue`: internal to `utils.js`; existing callers unchanged via the defaulted param.
- `GoogleSSOButton`: `AuthForm.tsx` only — extended.
- `from_omniauth`: 1 app call site + 2 spec files — all extended; new keywords nil-defaulted so any hypothetical un-extended caller would still work.
- `useCookieValue`: `useCookieValue.ts` + `useReferrerCookie.ts` only after the `OrganizationForm.tsx` import removal — both untouched.
- `organization_params`: `#create` + `#update` — permit narrowing affects both; accepted stated consequence.

## Full-stack analog completeness (15 layers × 8 identifiers)

For EACH of the eight: capture rule (`utils.js`) → component state (automatic via `trackingParams`) → magicLink payload → register payload → SSO props → hidden input → `magicLink` hook (destructure/type/variables) → `register` hook (destructure/variables) → permit → magic_create merge BOTH branches → password path (permit-only) → `allowed_keys` → callback keyword → `from_omniauth` keyword + assignment → org copy → migration column → spec extensions. No missing layer for any identifier.

## Analog structural matching (vs the `ec9f87232` chain)

Diffed the new code against the analog's parameter interfaces and patterns at every hop (guard forms, keyword form, string-key session reads, plain-symbol permits before the trailing `utm_data: {}`, copy-line form, migration shape). Every row SAME except exactly the four sanctioned deviations: (1) 1024 cap via the defaulted param; (2) in-helper `document.cookie` reading with first-`=` split; (3) the `organization_params` request-body path removal; (4) per-keyword `from_omniauth` growth to 16. No EXTRA file, method (beyond the two sanctioned in-`utils.js` cookie helpers), write moment, or column beyond the manifest. No MISSING layer.

## Findings

None beyond the LOW filed under collection-point-move. 0 BLOCKER / 0 HIGH / 0 MED / 0 LOW (here).
