# Approved Decisions

## 1. Interactor definition

Create an interactor named `FindOrCreateAiJobApplicationSummaryStatus`. It receives `job_application` on context. It sets `context.ai_job_application_summary_status` with the found or created record. It follows the `build` + explicit `save` pattern (matching `FindOrCreateOrgInterviewerInvite`), not `find_or_create_by`.

## 2. Record exists — ai_job_application_summary is nil

When the interactor finds an existing `AiJobApplicationSummaryStatus` and `ai_job_application_summary` is nil, the interactor makes no changes to the record.

## 3. Record exists — ai_job_application_summary is present

When the interactor finds an existing `AiJobApplicationSummaryStatus` and `ai_job_application_summary` is present, it checks that summary's `status`. If `succeeded`, set the status record's `status` to `:regenerating`. If anything other than `succeeded`, set `ai_job_application_summary` to nil and set `status` to `:none` on the status record.

## 4. Record does not exist

The interactor creates an `AiJobApplicationSummaryStatus` built from `job_application`. Before saving, it checks whether the job_application already has a succeeded, non-stale `AiJobApplicationSummary`. If yes → create with `status: :current`, set `ai_job_application_summary_id` and denormalized columns (`score_percentage`, `headline`, `integrated_role_analysis`) from that summary. If no → create with `status: :none`.

## 5. Use the association, not the column

Throughout the interactor, check the `ai_job_application_summary` association directly (via `belongs_to`) instead of checking the `ai_job_application_summary_id` column. If the association is present, the summary record is available directly — no separate lookup by ID needed.

## 6. Helper method on JobApplication

`JobApplication#find_or_create_ai_job_application_summary_status` calls `FindOrCreateAiJobApplicationSummaryStatus.call(job_application: self)`. One line. Failure handling deferred — future consideration.

## 7. Trigger A — job application created

`JobApplication#enqueue_new_job_application` calls `find_or_create_ai_job_application_summary_status` as the last line of the method.

## 8. Trigger B — all generation paths

`TextractResult#generate_ai_summary_with_credit_flow` calls `job_application.find_or_create_ai_job_application_summary_status` after the early return guard (line 67), before calling `generate_ai_summary`. This is the single call site for all generation triggers (manual, auto, bulk) — every path funnels through `generate_ai_summary_with_credit_flow`. Replaces the `find_or_create_by` calls in `CreateAiSummaryGeneration` (lines 54 and 74) and eliminates the need for separate calls in `queue_ai_summary_job` and `BulkGenerateAiSummariesJob`.

## 9. Removal

Delete `after_commit :create_status_record, on: :create` callback declaration and the `create_status_record` method from `AiJobApplicationSummary`. Delete both `AiJobApplicationSummaryStatus.find_or_create_by(job_application: job_application)` calls from `CreateAiSummaryGeneration` (lines 54 and 74). Grep the codebase for any other references to `create_status_record` or `find_or_create_by` involving `AiJobApplicationSummaryStatus` and delete those too.
