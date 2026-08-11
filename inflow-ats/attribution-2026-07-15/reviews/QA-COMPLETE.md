# QA COMPLETE - attribution (UTM capture + funnel events)

**Final verdict: APPROVED** (under deadline-compressed convergence rules - all relaxations disclosed below)
**Date:** 2026-07-16, completed ~10:18 CT
**Branch:** attribution-work-qa | **Final commit:** fa51c91a5 (clean tree)
**Reviewed diff:** 62dd55867..fa51c91a5 (feature 8dcc2f06f + 2 QA fix commits)
**Layer 5 (Playwright MCP) omitted per Jessica's instruction.**

## Runs and layers

### qa-run-1 (at 8dcc2f06f) - full-rigor round
- **Layer 1 (diff-to-spec):** 15 agents, 8 areas, every requirement double-covered. Round 1: 2 HIGH findings -> FAIL -> fix loop.
  - l1-r1-F1: sanitizeTrackingParams dropped utm_* params with malformed percent-encoded keys (scan decoder != queryString.parse decoder). Found independently + empirically by 2 agents.
  - l1-r1-F2: Jest gap - utmData inner-value sanitization rules unpinned.
  - **Fix commit 299cf9465** (decode-uri-component swap + 3 tests; pre-commit Cypress hook passed). Minimum-change verified.
- Run superseded by qa-run-2 restart per the fix-loop rule. (A second full 15-agent restart at 01:17 was killed by the account session limit; its partial outputs were voided - reviews/qa-run-2/layer-1-diff-to-spec/voided-partial-run-0127/ is empty because no agent had written output.)

### qa-run-2 (at 299cf9465 -> fa51c91a5) - deadline-compressed (session restarted 09:29 CT; clean-stop 10:45 / ceiling 11:00)
- **Layer 1 (diff-to-spec):** 1 round, 5 file-group agents (compressed from 15). 0 findings. Fix commit 299cf9465 traced to FAILURE-REPORT F1/F2 and empirically re-verified. GATE PASS.
- **Layer 2 (code correctness):** 1 round, 3 fresh cold readers. 1 HIGH, 4 MED, 9 LOW.
  - l2-B1 (HIGH, orchestrator-reproduced): .slice(0,255) could split a surrogate pair; ES2019 JSON.stringify emits a lone \udXXX escape; Rails json 2.6.1 rejects the body -> entire signup POST 400s.
  - **Fix commit fa51c91a5** (surrogate-safe truncation + 2 tests; pre-commit Cypress hook passed). Targeted re-verification: committed delta byte-identical to the independently re-reviewed working-tree snapshot (fresh delta-review agent: PASS on scope, correctness, dead reproduction, 13/13 Jest).
- **Layer 3 (script runner):** 1 agent, 4 scenarios against the live test server (RAILS_ENV=test, port 5007): magic_create new-user raw persistence + nil-for-absent (HTTP); both existing-user branches no-touch (HTTP); from_omniauth keyword interface incl. first_or_create-only assignment (rails runner); organizations#create copy incl. nils and the 4.3 password path (HTTP, real session-cookie auth). 4/4 PASS, 0 findings. GATE PASS.
- **Layer 4 (regression):** five new RSpec files: 17 examples, 0 failures. Jest utils.test.js: 13/13. spec/models/user_spec.rb does not exist (from_omniauth spec is user.rb's coverage). Baseline non-intersection held (~148 pre-existing AI-credit/AI-summary full-suite failures untouched by scope; FormCheckbox Jest pre-existing; Cypress 56/56 in the pre-commit hook at ALL THREE commits 8dcc2f06f, 299cf9465, fa51c91a5). GATE PASS.
- **Post-fix targeted re-verification (in lieu of full Layer-1 restart):** committed fix delta == reviewed snapshot (byte-identical diff check); Jest 13/13 and RSpec 17/17 re-run on the committed tree at fa51c91a5.

## Deadline relaxations (coordinator-directed, none silent)
1. Layer 5 (Playwright MCP) omitted per Jessica's explicit instruction.
2. qa-run-2 convergence: ONE clean round per layer instead of two consecutive clean rounds.
3. Team sizes: L1 5 agents (vs 15), L2 3 (vs 5-15), L3 1 agent/4 scenarios (vs 15/round), L4 scoped suites (vs full suites; baseline verified by non-intersection instead).
4. L1/L2 agents dispatched in parallel (read-only static analysis; no shared state) instead of sequentially.
5. The fa51c91a5 fix got a targeted delta re-review + suite re-run instead of a full Layer-1 restart in a qa-run-3.
6. Sequencing: Layer 3 ran while the l2-B1 fix commit was gated (fix is frontend-only, disjoint from Layer 3's backend scope); all test-DB users (L3 scripts -> L4 RSpec -> pre-commit Cypress hook) were serialized via a commit gate file.

## Findings for Jessica
- **reviews/QA-MED-FINDINGS.md** - 4 MED + 9 LOW, consolidated and deduplicated across all layers/runs.
- Both QA fix commits were minimum-change, traced line-by-line, and adversarially re-reviewed (fresh agents).

## Totals
- Agents dispatched: 15 (run-1 L1) + 5 (run-2 L1) + 3 (L2) + 1 (L3) + 1 (L4) + 1 seed planner + 2 fix agents + 1 delta reviewer = 29 completed (14 additional run-2 restart agents killed by the session limit, outputs voided).
- Fix loops: 2 (commits 299cf9465, fa51c91a5), both hook-verified, never bypassed.
