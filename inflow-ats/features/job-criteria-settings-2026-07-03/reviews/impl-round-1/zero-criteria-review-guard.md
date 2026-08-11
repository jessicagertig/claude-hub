# Angle 1 — Zero-criteria review guard: entry-point completeness and predicate semantics — Round 1

Reviewed committed diff `05c9513ef..HEAD` (worktree clean; pipeline rule 15 satisfied).

## Entry-point re-trace (independent, not trusted from SPEC 6.1)

Re-ran the trace grep (`GenerateAiJobApplicationSummaryJob.perform_later|generate_ai_summary_with_credit_flow|CreateAiSummaryGeneration.call|CreateBulkAiSummaryGeneration.call|auto_generate_ai_summary_if_enabled|QueueBulkAiSummaryJobs.call|Orchestrate.new` over `app/ lib/`). Every hit maps to the SPEC 6.1 table; no unlisted creation path exists:

1. Manual single — `ai_job_application_summaries_controller.rb:8` calls `ValidateAiSummaryGeneration` (guard added at validate_ai_summary_generation.rb:30) before `CreateAiSummaryGeneration.call` (:17). Covered.
2. Bulk — `bulk_ai_job_application_summaries_controller.rb:13/:38` → `QueueBulkAiSummaryJobs` (guard at queue_bulk_ai_summary_jobs.rb:19) → `BulkGenerateAiSummariesJob#each_iteration` per-record `ValidateAiSummaryGeneration` (bulk_generate_ai_summaries_job.rb:59). Covered twice.
3/4. Auto (new applicant `job_application.rb:175→183-187`; resume upload `job_applications_controller.rb:118`) — `ValidateAutoAiSummaryGeneration` (guard at validate_auto_ai_summary_generation.rb:19). Covered.
5. Textract completion — `textract_result.rb` `queue_ai_summary_job`: BOTH branches call `ValidateAiSummaryGeneration` (manual-waiting branch :129-138 destroys + `broadcast_ai_summary_failed` with the error; auto branch :141-146 enqueues only on success). Covered.
6. `AiJobCriteria#resume_waiting_summaries` (ai_job_criteria.rb:39) — deliberately unguarded per SPEC (fires only on `succeeded`); UNTOUCHED in the diff. Verified.
7. Shared funnel — `TextractResult#generate_ai_summary_with_credit_flow`: `return if job_application.job.zero_criteria_extraction_failure?` at textract_result.rb:70, AFTER the succeeded-summary early return (:67-68) and BEFORE `extract_job_criteria_if_needed` (:72). Ordering rationale (blocked review must not re-trigger extraction) is enforced. Bare return (core rule 8). Covered.
- `CreateAiSummaryGeneration.call` sites: controller :17 (behind validator), job_application.rb:187 (behind validate-auto). Behind a validator on every calling path — claim verified.
- `Orchestrate.new` only at textract_result.rb:115 (`generate_ai_summary`), downstream of the funnel guard. Cypress controllers create no summaries (grep re-run — no hits under app/controllers/cypress for these identifiers).

## Predicate semantics

- `AiJobCriteria#zero_criteria_failure?` (ai_job_criteria.rb:16-18): `status_failed? && ZERO_CRITERIA_ERROR_MESSAGES.include?(error_message)` — exact.
- The three constants byte-match the writer strings, and all three writers switched to the constants: extract_criteria.rb:62 (`ZERO_CRITERIA_NO_SECTIONS_ERROR_MESSAGE`), :122 (`ZERO_CRITERIA_NONE_EXTRACTED_ERROR_MESSAGE`), score_job_application.rb:43 (`ZERO_CRITERIA_EMPTY_ARRAY_ERROR_MESSAGE`). One-line substitutions only; nothing else changed in either service (diff verified).
- `Job#zero_criteria_extraction_failure?` (job.rb:696-698) reads `latest_ai_job_criteria&.zero_criteria_failure?` — LATEST row, any status, exactly as specced (NOT latest-terminal). In-flight-over-zero behavior confirmed by tests (validate_ai_summary_generation_spec.rb "does not fail when an in-flight row sits on top of a zero-criteria failure").
- Guard error message identical at ValidateAiSummaryGeneration and QueueBulkAiSummaryJobs sites (byte-compared). ValidateAutoAiSummaryGeneration declines with the same `fail!` message consumed silently by the auto path — matches its existing credit/description declines.
- NO guards added in `Orchestrate`, `ScoreJobApplication`, `CreateAiSummaryGeneration`, `CreateBulkAiSummaryGeneration` (none of these files in the diff except score_job_application.rb's constant substitution). No scope creep.
- `resume_waiting_summaries` untouched; SPEC 6.4 race documented-and-accepted — no state transition was added at the funnel (rule 20 honored).

## Findings

No issues found.
