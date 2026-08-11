# Plan review pass 1 — always-on checks

Covers: source accuracy, test coverage, backward compatibility, full-stack analog completeness, analog structural matching.

## Source accuracy

Every file path, class, method, column, and line number in plan.md was verified against `attribution-work-qa` @ `b4cb4463a` (branch confirmed, working tree clean). All anchors exact — the full verification lists live in the six angle files. Cited commits verified: `ec9f87232` (18-file analog set matches manifest), `fa51c91a5` (surrogate-safe truncation), `b4cb4463a` (touched utils.js only at INTERNAL_UTM_PARAMS :145 — disjoint from T4's region, no conflict). All seven "Read before implementing" cursor_rules files exist; cited rule numbers verified against headings (core rules 1, 5, 7, 8, 9, 10, 11, 13; frontend/_base rule 1 = no `??`).

## Test coverage (calibrated per harness-profile.md)

- T17-T21 map SPEC §10 items 1-4 completely, including the pinning values (`ga_session_id` with `=`/`.`/`;`, >255-char fbclid-style value, `login_intent: 'hire'` on every magic_create POST), the T20b inversion, and the T20c header rewrite. All spec-file line refs verified exact (see angle files).
- Ghost-test check present (plan §8): the T20b inversion fails if T13 reverts; T19's exhaustive keyword expectations fail at dispatch if T16 lands alone. No ghost-test risk identified in the planned assertions.
- Cypress: `cypress/e2e/auth/registration.cy.js` read and confirmed to assert navigation/text only (both signup paths + org creation; no payload shapes). Pre-commit hook verified: `package.json` husky config runs `bash bin/run-cypress-precommit && lint-staged`; the script runs `yarn cy:run`.
- lint-staged also runs `spec/requests/api_public/` specs when api_public files are staged — this feature touches none, so the customer API spec priority is unaffected.

## Backward compatibility

Consumer sets re-grepped; all match the plan's claims exactly:
- `sanitizeTrackingParams` → AuthForm.tsx, SignupForm.tsx only
- `GoogleSSOButton` → AuthForm.tsx only
- `AuthForm` → Auth.tsx + AuthRegister.tsx (no change needed); `SignupForm` → Signup.tsx
- `from_omniauth` → 1 app call site + 2 spec files (T16a/T19/T18 cover all)
- `useCookieValue` → OrganizationForm.tsx (import removed) + useReferrerCookie.ts (untouched)
- `organization_params` → `#create` + `#update` (narrowing consequence stated and accepted)

## Full-stack analog completeness + structural matching

Plan §5 manifest checked row-by-row against live code: all 15 analog layers present for each of the eight identifiers (§5.2 table); every DIFFERENT row is justified only by a §4 source difference or a §13-RESOLVED decision; no EXTRA files/methods/write moments beyond the two migrations and the sanctioned in-helper cookie functions; the not-touched set matches the analog's. The four deviation-ledger items equal the four sanctioned deviations in REVIEW-ANGLES.md — nothing else deviates.

## Findings

### F1 — LOW (note only) — "no Jest" wording

Plan §8 says "this codebase has no Jest." Factually: `jest.config.js`, jest `^24.5.0`, and one test file (`app/javascript/ats/src/components/shared/Button/Button.test.tsx`) exist. The house ruling (2026-07-16) is that the codebase does not USE Jest and the helper changes get no JS unit tests — SPEC §10's wording is accurate; the plan's shorthand is slightly off but changes no task and cites the ruling. Note only.

### F2 — LOW (note only) — pre-commit runs the full Cypress suite

Plan §13/T21 say the pre-commit hook runs `registration.cy.js`. The hook actually runs `yarn cy:run` (all Cypress e2e specs), which includes `registration.cy.js`. The plan's statement remains true; the hook is broader than stated. No task affected. Note only.

## Verdict for this angle

0 BLOCKER, 0 HIGH, 0 MED, 2 LOW (notes).
