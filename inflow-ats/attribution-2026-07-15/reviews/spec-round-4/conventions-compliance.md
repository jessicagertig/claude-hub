# conventions-compliance — Round 4

This round's conventions file: `cursor_rules/frontend/_base.md` (read in full; rules 1–6 checked against every frontend section of the spec).

- Rule 1 (no `??`): no occurrence in any spec'd mechanism.
- Rule 2 (never deliberately set undefined): §5.1/§5.2/§5.5 pass values through; absent-key object construction is not the banned pattern.
- Rule 3 (trust the transformation layer; JSONB camelCase): the spec adds no snake_case fallbacks anywhere; the `utm_data` inner-key rawness is the declared, approved deviation (§5 note; REVIEW-ANGLES Priority rule 4) — not reported.
- Rule 4 (pragmatic TS): Props extensions use optional fields on the existing interface; typing detail left to plan — compliant.
- Rule 5 (boolean variables): no new booleans mandated.
- Rule 6 (no useMemo for minor computation): the spec proposes no useMemo.

Cumulative conventions coverage across rounds: core_critical_rules.md, backend/migrations.md, frontend/react_hooks.md, backend/controllers/controller_patterns_and_crud.md, frontend/_base.md — the five files most implicated by this diff's shape, one per round per the spec-stage override. The full per-file fan-out (pipeline rule 27) remains an impl-review obligation, already encoded in REVIEW-ANGLES angle 7.

## Findings

- None.

## Amendments Applied

- None.
