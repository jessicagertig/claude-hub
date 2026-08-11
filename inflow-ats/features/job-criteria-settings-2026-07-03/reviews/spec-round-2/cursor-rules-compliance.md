# Round 2 — Angle 8: cursor_rules compliance + always-on checks

SPEC.md re-read in full. Round 1 compliance verifications stand (no spec'd code changed in Rounds 1-2 except the §8.1 type union and §5.2 citation — both re-checked: `string | null` is a plain union, no `??`, no fallback fabrication; the useBulkMessage citation is factual).

Always-on delta checks:
- **Source accuracy:** all Round 1/2 amendments re-verified against source this round (analog guards :17-21/:45; EmptyState :7-13; extraction schema :246/:249; useBulkMessage :23). No citation in the amended spec is known-stale.
- **Stale-reference sweep (hub CLAUDE.md failure pattern):** for each Round 1 amendment, searched the whole spec for contradicting text — flag-4 (Angle 3 file documents the sweep: clean), payload table vs §12 state list vs §8.2 rows (consistent), action-row placement vs §8.3 (consistent), frozen-prop note vs §8.4 props (consistent).
- **Test coverage:** unchanged; plan still names the load-bearing cases; no test-plan text contradicted by amendments.
- **Backward compatibility:** strengthened by the flag-4 resolution (in-flight payloads now the documented rationale).
- **Analog structural matching:** the one remaining unadjudicated deviation class from Round 1 (broadcast-site guard shapes) is now spec'd to mirror the analog; no deviations remain outside the 7 sanctioned flags + the flag-4 ruling.

## Findings

No issues found.

## Amendments Applied

None (this angle).
