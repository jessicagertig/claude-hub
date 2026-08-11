# Angle 1 — Zero-criteria review guard: entry-point completeness and predicate semantics — Round 2

Round-2 focus: does the guard still fire on ALL entry points AFTER the develop merge (68e5e6a4e) rethreaded `rescore_requested` through the bulk pipeline and unified `latest_ai_job_application_summary` selection?

## Entry-point re-trace at HEAD (merged code)

Re-ran the trace greps over `app/ lib/` at HEAD. `QueueBulkAiSummaryJobs` has exactly one production caller (the bulk controller, both actions). All entry points and their guards, verified in the merged files:

1. **Manual single** — `ValidateAiSummaryGeneration` (validate_ai_summary_generation.rb:30): `fail!` on `@job_application.job&.zero_criteria_extraction_failure?` present, ordered after the description fail. Develop did not touch this file (byte-identical to feature parent — verified by empty `git diff e7b8cef0a HEAD -- app/interactors/validate_ai_summary_generation.rb`).
2. **Bulk fail-fast** — `QueueBulkAiSummaryJobs:19`: third `context.fail!` on `context.job&.zero_criteria_extraction_failure?`, after Flipper and credits fails. Merged controller passes `job: @job` in BOTH `create` (:17) and `all_stages` (:43) alongside develop's `params: bulk_ai_job_application_summary_params`. The guard fires BEFORE `context.params` is first read (:41), so the guard is independent of the rescore threading.
3. **Bulk per-record backstop** — `BulkGenerateAiSummariesJob#each_iteration:62-66`: `ValidateAiSummaryGeneration` still called per record; develop's 2-line addition (`job_application.ai_summary_rescore_requested = payload['rescore_requested']`, :36) sits ABOVE the validation and does not bypass it. The rescore path only relaxes `CreateBulkAiSummaryGeneration`'s active-summary early-return (create_bulk_ai_summary_generation.rb:45), which runs AFTER validation succeeded — no new validation bypass.
4. **Auto (new applicant / resume upload)** — `ValidateAutoAiSummaryGeneration:20`: `fail!` present, byte-identical to feature parent.
5. **Textract completion** — `TextractResult#queue_ai_summary_job`: develop's unification changed the waiting-summary LOOKUP (now `latest_ai_job_application_summary` + `status_textract_processing?` + `!stale?`, textract_result.rb:126-130) but BOTH branches still route through `ValidateAiSummaryGeneration` (:133, :147) before any enqueue; the manual-waiting failure path still destroys the waiting summary and broadcasts `AI_SUMMARY_FAILED` with the guard message (:138-140).
6. **`AiJobCriteria#resume_waiting_summaries`** — untouched (fires only on `succeeded`; guard definitionally false).
7. **Shared funnel** — `TextractResult#generate_ai_summary_with_credit_flow`: `return if job_application.job.zero_criteria_extraction_failure?` present at :70, ordered AFTER the succeeded-summary early return (:67-68) and BEFORE `extract_job_criteria_if_needed` (:72). Interdiff (05c9513ef..e7b8cef0a vs 639458b9d..HEAD for this file) shows the feature hunk carried through the merge byte-identically.

## Predicate + message semantics (unchanged, re-verified at HEAD)

- `AiJobCriteria#zero_criteria_failure?` = `status_failed? && ZERO_CRITERIA_ERROR_MESSAGES.include?(error_message)` (ai_job_criteria.rb:17-19); constants exactly match all three writer sites, which now use the constants (`extract_criteria.rb:62`, `:122`; `score_job_application.rb:43` — grep-verified).
- `Job#zero_criteria_extraction_failure?` reads the LATEST row (job.rb:696-698) — not latest-terminal, per spec. Not "fixed."
- Identical guard message at ValidateAiSummaryGeneration and QueueBulkAiSummaryJobs; ValidateAutoAiSummaryGeneration declines silently by convention.
- No extra guards added in `Orchestrate` / `ScoreJobApplication` / `CreateAiSummaryGeneration` / `CreateBulkAiSummaryGeneration` (grep for `zero_criteria` over `app/` returns only the specced sites + serializer + models).
- `resume_waiting_summaries` untouched by the whole diff.

## Semantic merge risk hunted, not found

Develop's `latest_ai_job_application_summary` unification does not interact with the funnel guard: the funnel's own early-return already used the has_one at base (feature-parent context line), the guard reads only `job.latest_ai_job_criteria`, and ordering is preserved.

## Findings

No issues found.
