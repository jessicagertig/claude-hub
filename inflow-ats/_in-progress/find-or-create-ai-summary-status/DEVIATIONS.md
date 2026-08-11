# Deviations from LIFECYCLE.md

## Phase 0: Spec Writing — SKIP
Spec already written and approved via brainstorming-plus decision capture in this session. File: `spec.md` in this directory. Copy to `SPEC.md`.

## Phase 1: Generate Review Angles — DO NOT PRESENT TO JESSICA
Generate angles but skip the human gate. Ensure angles cover tracing all generation flows (manual, auto, bulk) through `generate_ai_summary_with_credit_flow`. Proceed directly to Phase 2.

## Phase 2: Spec Review — SKIP
Spec was designed collaboratively with Jessica via 9 approved decisions. No adversarial spec review needed.

## Phase 3: Planning — RUN NORMALLY

## Phase 4: Plan Review — USE SPEC REVIEW RIGOR
Instead of the normal 2-pass fact-check, run iterative adversarial review: up to 5 rounds against the review angles, goal of two consecutive clean passes. Same protocol as Phase 2 would normally use for the spec. The plan is where the risk is — all generation flows must be traced correctly.

## Phase 5: Implementation — RUN NORMALLY

## Phase 6: Implementation Review — RUN NORMALLY

## Phase 7: Hardening — RUN NORMALLY

## Phase 8: QA — RUN WITHOUT PLAYWRIGHT
Run QA layer 8 but skip the Playwright layer. Do not install Playwright. Do not run Cypress tests. Backend-only verification.
