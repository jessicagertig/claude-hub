# Plain English Summary

When a recruiter posts a job on Polymer and candidates apply, the system already generates an AI summary of each candidate's resume. This feature extends that pipeline: after the summary is generated, the system also extracts the job's requirements from the job description, scores each candidate's resume against those requirements, and produces an integrated analysis combining the summary insights with the scoring evidence. The result is a single AI evaluation that tells the recruiter not just what the candidate has done, but how well they match this specific job.

The scoring pipeline is not a separate feature -- it extends the existing AI summary lifecycle. One credit still covers the full evaluation. The job description criteria are extracted once per job (not per candidate), and multiple candidates waiting for the same criteria are automatically resumed when extraction completes.

# Blast Radius

## New tables
- `ai_job_criteria` -- one per job, stores extracted requirements. New model, new migration, new job (`ExtractJobCriteriaJob`).
- `ai_job_application_summary_statuses` -- one per job application, lightweight read model. New model, new migration, new serializer.

## Modified tables
- `ai_job_application_summaries` -- 3 new columns (`score_percentage`, `criteria_results`, `integrated_role_analysis`). Status enum redesigned from 6 values to 10 values. `succeeded` moves from integer 2 to integer 8.

## Existing behavior changes
- **`AiJobApplicationSummary.status_succeeded?`** -- now means "full pipeline done" (summary + scoring + integration), not just "summary done." Every caller of `status_succeeded?` must be verified: `textract_result.rb:79` (credit consumption gate), `generate_ai_job_application_summary_job.rb:51` (broadcast status), `ai_job_application_summary.rb:39` (cleanup callback), `bulk_generate_ai_summaries_job.rb:89` (success count).
- **`TextractResult#generate_ai_summary`** -- replaced by orchestrator call. The entire pipeline gets longer.
- **`GenerateAiJobApplicationSummaryJob`** -- broadcast timing shifts (fires later). Status value in broadcast payload changes.
- **`BulkGenerateAiSummariesJob`** -- `status: :succeeded` queries now match integer 8 instead of 2. `generate_ai_summary_with_credit_flow` now runs the extended pipeline.
- **`CreateAiSummaryGeneration`** -- `where.not(status: :failed)` still works (symbols resolve via enum), but the active summary check needs attention with new intermediate statuses.
- **`Summary::Generate`** -- status transitions change from `in_progress -> extracted -> succeeded` to `in_progress -> extracted -> summarizing`. It no longer sets `succeeded` -- the orchestrator does after scoring + integration.
- **`Job` model** -- new methods added to `handle_before_update` callback chain. New `extract_job_criteria` method saves a record and enqueues a job inside a `before_update` callback (transaction implications).
- **`AiJobApplicationSummarySerializer`** -- new attributes added.
- **`ShallowJobApplicationSerializer`** -- needs to include `AiJobApplicationSummaryStatus` data.
- **`JobApplication` model** -- new `has_one :ai_job_application_summary_status` association.
- **`AiApiRequest`** -- new polymorphic type `AiJobCriteria` for `requestable`.

## What breaks if this is wrong
- Credits consumed at wrong point (too early or never) if `status_succeeded?` semantics aren't updated everywhere
- Broadcast fires at wrong time if status values shift without updating broadcast logic
- Bulk summary success counts wrong if `status: :succeeded` integer value changes without updating queries
- `AiJobCriteria` record saved inside `before_update` on Job can be orphaned if the parent save fails
- Multiple candidates stall at `awaiting_job_criteria` if the `after_commit` callback doesn't find and resume all of them
- Description change detection inside `before_update` creates side effects in a transaction context
