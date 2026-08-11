# Angle 1 — Zero-criteria review guard: entry-point completeness and predicate semantics — Round 3

Fresh independent re-trace at HEAD `68e5e6a4e` (clean tree verified). Did NOT trust rounds 1-2's tables; re-ran the trace greps (`GenerateAiJobApplicationSummaryJob.perform_later|generate_ai_summary_with_credit_flow|CreateAiSummaryGeneration.call|CreateBulkAiSummaryGeneration.call|auto_generate_ai_summary_if_enabled|QueueBulkAiSummaryJobs|ValidateAiSummaryGeneration.call|ValidateAutoAiSummaryGeneration.call|Orchestrate.new` over `app/ lib/`).

## Entry points at the MERGED HEAD (includes develop's rescore pipeline)

| Entry | Guard on path | Verified |
|---|---|---|
| Manual single (`ai_job_application_summaries_controller.rb:8`) | `ValidateAiSummaryGeneration` new fail (validate_ai_summary_generation.rb:30) | yes |
| Bulk `#create`/`#all_stages` → `QueueBulkAiSummaryJobs` | fail-fast `context.job&.zero_criteria_extraction_failure?` after the credits fail (queue_bulk_ai_summary_jobs.rb:19); bulk controller passes `job: @job` in BOTH actions | yes |
| Bulk per-record (`bulk_generate_ai_summaries_job.rb:61`) | `ValidateAiSummaryGeneration` per record | yes |
| Bulk RESCORE variant (develop's `rescore_requested`, same interactor/job path) | same three layers as bulk — the rescore flag only skips the already-summarized filter, never the guard | yes (new-at-merge path re-checked) |
| Auto on new applicant / resume upload (`job_application.rb:187`, `job_applications_controller.rb:118`) | `ValidateAutoAiSummaryGeneration` new fail (validate_auto_ai_summary_generation.rb:19) | yes |
| Textract completion both branches (`textract_result.rb:132`, `:146`) | `ValidateAiSummaryGeneration` | yes |
| `AiJobCriteria#resume_waiting_summaries` (ai_job_criteria.rb:39 enqueue) | none needed (fires only on criteria success; predicate definitionally false); file diff adds ONLY constants + predicate — callback untouched | yes |
| Shared funnel `TextractResult#generate_ai_summary_with_credit_flow` | `return if job_application.job.zero_criteria_extraction_failure?` after the succeeded-stale early return and BEFORE `extract_job_criteria_if_needed` (textract_result.rb:70-72) — ordering rationale enforced | yes |
| `CreateAiSummaryGeneration:71` direct enqueue | behind a validator on every calling path (controller :8; job_application.rb:187-188) — re-verified claim | yes |

## Predicate and messages

- `AiJobCriteria#zero_criteria_failure?` = `status_failed? && ZERO_CRITERIA_ERROR_MESSAGES.include?(error_message)`; three constants byte-match the three writer strings; all three writers switched to the constants (extract_criteria.rb:62, :122; score_job_application.rb:43 — one-line swaps only, nothing else in those services changed).
- `Job#zero_criteria_extraction_failure?` reads the LATEST row via safe-nav (job.rb:696-698) — deliberately not latest-terminal; not "fixed."
- Guard message byte-identical at the two user-facing sites; auto validator declines silently by existing convention (same fail! chain shape).
- No extra guards added in `Orchestrate`/`ScoreJobApplication`/`CreateAiSummaryGeneration`/`CreateBulkAiSummaryGeneration` (diff touches none of them beyond the score_job_application constant swap).
- Funnel-guard race stranding: documented-and-accepted per SPEC §6.2.4 — standing adjudication, not re-opened.

## Findings

No issues found.
