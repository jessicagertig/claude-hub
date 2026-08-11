# Job gating change, ExtractJobCriteriaJob signature, WebSocket broadcast lifecycle — Pass 2

## Pass 1 corrections in this angle's scope
None were required.

## Fresh scrutiny
- Re-read E.2 and E.3 in the amended plan: unchanged by the Pass 1 amendment; no new inconsistencies.
- Flag 4 re-verified MATCHED after amendment: E.2.1 optional positional; E.2.3 reads `job.arguments.first`/`.second`; E.2 preamble and §G both carry "do not re-litigate". Consistent with ORCHESTRATION-LOG flag 4 and SPEC-REVIEW-COMPLETE's ruling.
- Fresh check: E.2.3's snippet preserves the existing exhaustion-block behavior for a nil row (before: safe-nav no-op; after: `if ai_job_criteria` block no-op) — behaviorally identical, and the broadcast can never receive nil (the NoMethodError hazard the SPEC calls out).
- Fresh check: E.2.2's perform-end broadcast uses the `ai_job_criteria` variable already nil-guarded at the top of `perform` (:13-14) — matches the analog's :30/:34 shape; no nil path.
- Fresh check: E.3.1 "Keep the existing comments above `extract_job_criteria_if_needed` / `handle_criteria_extraction_after_commit` intact" — both comments verified present in the worktree (:735-736, :745+); instruction is executable as written.
- Fresh check: backward-compat invariants in §G re-verified against the four enqueue sites (:707, :709, :723, :732 — all single-arg today) and the existing spec's positional `perform_now(id)` calls (:15/:30/:49/:63): the invariants are testable exactly as stated.
- R-1 (reload) unchanged; still correctly framed as gate-bound (see claude-md-compliance.md).

## Completeness re-sweep (SPEC §4.1/§7/§12)
All present: gating replacement + kwarg + no-pending-guard consequence; 3 broadcast sites + helper verbatim; auto-path-never-broadcasts; failure broadcasts (flag 3) not narrowed; behavioral spec coverage incl. the no-broadcast-on-retry and no-requesting-user cases; lifecycle spec describes. Nothing dropped.

## Findings
No new issues found.

## Amendments Applied
None.
