# Spec Review — Round 2 Verdict
**Date:** 2026-07-16 00:40

## Counts
- BLOCKER: 0
- HIGH: 1 (posthog-events-and-identity F1 — round-1 amendment rationale was factually wrong: `useOrganization`'s ungated query means Auth.tsx currently mounts AFTER `posthog.init`, so the original mount-effect design would have worked incidentally; round-1 BLOCKER was overclaimed. §5.6 rationale corrected; the two-effect mechanism is retained because it is robust to the incidental gate being removed. Recorded per the prompt's amendment-correctness escalation rule — content preserved for Jessica in SPEC-REVIEW-COMPLETE.md.)
- MED: 2 (test-coverage F1 — existing-unconfirmed-branch not-modified test added; test-coverage F2 — §9 preamble vs per-file Devise-helpers include coherence)
- LOW: 3 (utmData key-length uncapped — D4-bound; percent-encoded key order derivation is plan-level; Number(id) tamper → "NaN" distinct_id, same class as accepted Risk 6)

## Amendments Applied
1. §5.6 timing-facts paragraph rewritten with corrected mechanism facts (mount-effect would currently work only via the incidental `useOrganization` loading gate; state-keyed effect is ordering-immune in both worlds). Mechanism/guard/event unchanged.
2. §9.1: new bullet — existing-UNCONFIRMED-user branch not-modified assertion.
3. §9 preamble: Devise-controller specs opt into `Devise::Test::ControllerHelpers` per-file (coherence with items 1 and 3).

## Verdict: FAIL (findings found and amendments applied — loop continues)
