# CLAUDE.md Hardening Report

**Source:** reviews/impl-round-{1,2,3}/FAILURE-REPORT.md
**Date:** 2026-06-11

## Rules Added to ~/claude-hub/inflow-ats/CLAUDE.md

- **KFP #11: Analog replication: copy behavioral props, not just layout** — motivated by R1-M1 + R2-M1 (generate buttons missing loading/disabled, then stale banner also missing it). Pattern recurred across two fix rounds.
- **KFP #12: Styled components: use separate components for visual variants, not conditional props** — motivated by R3-M1 (isKey prop forwarded to DOM). User-directed pattern preference.

## Existing Rules That Were Violated

- KFP "Spec-implementation mismatch is never MED" (hub-level CLAUDE.md): R1-H1 state evaluation order differed from spec. The review correctly classified it as HIGH per this rule. No change needed — rule worked as intended.

## Findings Skipped (one-offs, not patterns)

- R1-L1/L2 (unused variables): Resolved by M1 fix, not a recurring pattern
- R2-L1 (unused css import): One-off copy artifact
