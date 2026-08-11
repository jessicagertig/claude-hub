# Plan review — attribution-identifiers

**Verdict: APPROVED.**

One pass per harness-profile.md (`reviews/plan-review/pass-1/`), reviewed against SPEC.md and the live source tree on `attribution-work-qa` @ `b4cb4463a` (branch and clean working tree confirmed at review start — no drift from plan time). **The amended plan.md in this directory is canonical and is what the implementation agent consumes.** code-task-list.md required no changes and remains consistent with the amended plan.

## Scope of verification

Every file path, class/method/component name, line number, schema claim, consumer set, and behavior claim in plan.md was checked against live code — the six angle files list the specifics. Highlights:

- All anchors exact across the 14 modified/created files and 4 spec files (utils.js :28/:31-40/:42-91/:59-70/:72; AuthForm :41/:85/:129-138; SignupForm :26/:71; GoogleSSOButton :17/:29/:61-85; OrganizationForm :14/:24-36/:72; useSession :38/:53/:71/:85/:111; registrations_controller :13/:20/:88-117/:97-101/:111-115/:312; organizations_controller :31-36/:120; omniauth.rb :14/:17-24; user.rb :379/:385-398/:393; omniauth_callbacks_controller :22/:26-30; all four spec files' cited ranges).
- Schema: none of the six new organization columns nor the eight user columns pre-exist; `organizations.google_click_id` :1078 and `organizations.adroll_first_party_cookie` :1094 confirmed — the 8/6 migration split is right.
- Empirical re-verification: all eight lodash `snakeCase` transforms (installed lodash), query-string v6.1.0 `?fbclid`→null / `?fbclid=`→"" / repeated→array (installed package).
- Consumer sets re-grepped and exact: `sanitizeTrackingParams` (2), `GoogleSSOButton` (1), `from_omniauth` (4 files), `useCookieValue` (3 files), `organization_params` (#create + #update).
- Completeness: every SPEC requirement §3-§10 maps to a T-task; §12 corrections respected; all five §13 rulings honored (no plan step contradicts any); §14 risks 1-5 all carried into plan §10/T8c. The SPEC §9 structural manifest is present (plan §5) and its 24 rows verified row-by-row.
- Feasibility: browser-runtime dependencies (`document.cookie`, `Date.now()`) confined to code that runs on the auth pages; no test infrastructure assumed beyond the four existing RSpec files and the read-only Cypress suite; no Jest tests planned (house ruling 2026-07-16).

## Per-angle findings

| Angle | BLOCKER | HIGH | MED | LOW |
|---|---|---|---|---|
| per-identifier-capture-contract | 0 | 0 | 1 (amended) | 0 |
| collection-point-move | 0 | 0 | 0 | 0 |
| sso-session-ride | 0 | 0 | 0 | 0 |
| wire-format-integrity | 0 | 0 | 0 | 0 |
| nil-absence-semantics | 0 | 0 | 0 | 0 |
| creation-time-only-and-existing-behavior-unchanged | 0 | 0 | 0 | 0 |
| migrations-and-schema-hygiene | 0 | 0 | 0 | 0 |
| always-on checks | 0 | 0 | 0 | 2 (notes) |
| claude-md-compliance | 0 | 0 | 0 | 0 |
| **Total** | **0** | **0** | **1** | **2** |

## Amendments applied to plan.md

1. **MED (capture-contract F1):** §3 precedents row and §12 deviation-ledger item 2 corrected — `useCookieValue.ts:8` matches `` startsWith(`${cookieKey}=`) ``, so it has no shadowing defect; only the `cookie.split("=")[1]` value truncation (:10) is real. The exact-equality directive in T4a is unchanged (it comes from SPEC §5.1 and stands on its own). Post-edit sweep confirmed no stale references to the removed claim.

## Deliberately-left MEDs

None.

## LOW notes (no action required)

1. Plan §8 "this codebase has no Jest" — jest.config.js, jest ^24.5.0, and one Button.test.tsx exist; the house ruling is that Jest is not USED. Behavior identical: no JS unit tests.
2. The pre-commit hook runs `yarn cy:run` (the full Cypress e2e suite), which includes `registration.cy.js` — the plan's narrower statement remains true.

## Verdict basis

0 BLOCKER, 0 HIGH after amendments; the single MED was amended and verified. PASS criteria met — APPROVED.
