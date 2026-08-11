# Round 3 — Angle 1: Zero-criteria review guard

SPEC.md re-read at round start. Sections 4.2/4.3/6 were stable since Round 1; Round 2's LOW amendments do not intersect this angle. Stale-text sweep of the spec: clean.

**Round-3 input from the orchestrator (cross-validating reviewer's trace, supplied mid-round):** one candidate finding in this angle's territory. Independently verified against source before acting — NOT taken on trust. Every link in the chain re-checked from this review's own reads:

- `CreateAiSummaryGeneration` builds a `:pending` summary and enqueues `GenerateAiJobApplicationSummaryJob` (create_ai_summary_generation.rb:60-74) ✓
- Race window is real: enqueue→perform latency plus `set(wait: 30.seconds)` scheduling (job.rb:707) and 2-minute `retry_on` waves (extract_job_criteria_job.rb:5) — a zero-criteria failure can land after validation passed but before the funnel runs ✓
- The new funnel guard (§6.2.4) returns bare between textract_result.rb:68 and :70 — Orchestrate never runs; the summary stays `:pending` (manual) / `:textract_processing` (textract path) ✓
- No broadcast: `broadcast_completion` terminal-status guard skips non-terminal rows (generate_ai_job_application_summary_job.rb:62) ✓
- Not revivable by `resume_waiting_summaries` — queries only `awaiting_job_criteria` (ai_job_criteria.rb:24) ✓
- Manual re-click dead-ends: active-summary branch (`where.not(status: :failed).where(stale: false)`, create_ai_summary_generation.rb:30-44) matches the stuck row and returns WITHOUT enqueueing ✓
- Revival paths that DO work: bulk re-run (`:done` rows don't block re-claim, queue_bulk_ai_summary_jobs.rb:45-49; funnel call unconditional at bulk_generate_ai_summaries_job.rb:80) and new resume upload (staleness branch :36-39) ✓
- Bulk race variant: claim row marked `:done` (bulk_generate_ai_summaries_job.rb:86) though nothing ran ✓
- Pre-feature comparison: the same race produced a revivable `awaiting_job_criteria` (Orchestrate `check_criteria_and_score` sets it before the criteria-status branch) ✓ — the guard genuinely makes this window worse than status quo, undocumented.

Resolution per pipeline rule 20 (gap fix = minimum change; no new state transitions on shared infrastructure without owner approval): DOCUMENT-AND-ACCEPT in §6.2.4, following the §4.1 "documented consequence" precedent. The alternative (funnel guard transitions the latest summary to `awaiting_job_criteria` instead of bare return) is recorded as an open question for Jessica in SPEC-REVIEW-COMPLETE.md — it is her infrastructure call, not the spec review's.

## Findings

- F1 [MED] SPEC §6.2.4 did not document the funnel-guard race consequence: a summary enqueued pre-zero-criteria arrives at the guarded funnel and is stranded in a non-terminal status with no broadcast, unrevivable on the manual path (chain verified above; supplied by cross-validation, independently confirmed). Fix: documented-consequence paragraph added to §6.2.4 with the full chain, revival paths, bulk variant, pre-feature comparison, and rule-20 acceptance rationale.

## Amendments Applied

1. §6.2.4: "Documented consequence of the funnel guard" paragraph added (F1). Patched section re-read and verified.
