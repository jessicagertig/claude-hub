# WebSocket frontend handler, copy rules, DECIDED-OUT absence — Pass 2

## Pass 1 corrections in this angle's scope
None were required (F2, the bare-`guard` grep note, is MED — recorded for the implementer, no amendment per the phase rules).

## Fresh scrutiny
- Re-read F.1.2/F.1.3/F.4 in the amended plan: unchanged; no new inconsistencies. The Pass 1 amendment (E.4.6) did not touch any user-facing string, so the Pass 1 copy sweep remains valid; the amendment's own prose contains no product copy.
- Fresh check: the full-stack analog chain closes with no missing layer (REVIEW-ANGLES §4 "analog completeness"): confirm modal owning mutation (F.3.2) → hook (F.1.1) → route (E.5.1) → controller (E.5.2) → model guards/validators (E.3/E.4) → async job (E.2) → broadcast helper (E.2.5) → GlobalChannel → handler case (F.1.3) → payload type (F.1.2) → query invalidation (key-shape match verified). No HIGH missing-layer finding.
- Fresh check: F.1.3's snippet uses `queryCache` — the handler's actual local identifier (:11), not `queryClient`; a copy-paste implementer gets working code.
- Fresh check: three-way toast branch order (succeeded → zeroCriteriaFailure → else) means a zero-criteria SUCCESS is impossible to mis-toast (succeeded rows always have ≥1 criterion — SPEC 4.2's verified premise).
- Re-swept the amended plan for decided-OUT terms: `TierHint` appears only in prohibitions; `internal_job_criteria` only in the NOT-touched list and F.4.1 grep; guard-modal artifacts only in F.4.1 grep and §G prohibition; `tier1`/`tier2`/`tier3` bundle keys only as rejected forms. Clean.

## Completeness re-sweep (SPEC §8.6/§8.7/§10)
All present. Copy rules checklist (F.4.2) covers every string category SPEC 10 binds; decided-OUT absence greps (F.4.1) cover all four exclusions plus bundle leaks; backward-compat and flags-settled checklists intact (§G). Nothing dropped.

## Findings
No new issues found. (F2 [MED] from Pass 1 stands as noted — scope the bare-`guard` grep to frontend files when executing F.4.1.)

## Amendments Applied
None.
