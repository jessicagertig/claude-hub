# Spec: FindOrCreateAiJobApplicationSummaryStatus

**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`
**Branch:** `feature-ai-summaries-integrating-scoring-v4`

---

## New file

### `app/interactors/find_or_create_ai_job_application_summary_status.rb`

Create interactor `FindOrCreateAiJobApplicationSummaryStatus`. Receives `job_application` on context. Sets `context.ai_job_application_summary_status` with the found or created record. Follows the `build` + explicit `save` pattern (matching `FindOrCreateOrgInterviewerInvite`), not `find_or_create_by`.

Throughout the interactor, check the `ai_job_application_summary` association directly (via `belongs_to`) instead of checking the `ai_job_application_summary_id` column. If the association is present, the summary record is available directly — no separate lookup by ID.

**Record exists, `ai_job_application_summary` is nil:** Make no changes to the record.

**Record exists, `ai_job_application_summary` is present:** Check that summary's `status`. If `succeeded`, set the status record's `status` to `:regenerating`. If anything other than `succeeded`, set `ai_job_application_summary` to nil and set `status` to `:none`.

**Record does not exist:** Create an `AiJobApplicationSummaryStatus` built from `job_application`. Before saving, check whether the job_application already has a succeeded, non-stale `AiJobApplicationSummary`. If yes → create with `status: :current`, set `ai_job_application_summary_id` and denormalized columns (`score_percentage`, `headline`, `integrated_role_analysis`) from that summary. If no → create with `status: :none`.

---

## Modified files

### `app/models/job_application.rb`

Add instance method `find_or_create_ai_job_application_summary_status`. One line: call `FindOrCreateAiJobApplicationSummaryStatus.call(job_application: self)`. Failure handling deferred.

Add a call to `find_or_create_ai_job_application_summary_status` as the last line of `enqueue_new_job_application`.

### `app/models/textract_result.rb`

In `generate_ai_summary_with_credit_flow`, add a call to `job_application.find_or_create_ai_job_application_summary_status` after the early return guard (line 67), before calling `generate_ai_summary`. This is the single call site for all generation triggers (manual, auto, bulk).

### `app/models/ai_job_application_summary.rb`

Delete `after_commit :create_status_record, on: :create` callback declaration. Delete the `create_status_record` method.

### `app/interactors/create_ai_summary_generation.rb`

Delete both `AiJobApplicationSummaryStatus.find_or_create_by(job_application: job_application)` calls (lines 54 and 74).

### Codebase-wide

Grep for any other references to `create_status_record` or `find_or_create_by` involving `AiJobApplicationSummaryStatus`. Delete any found.
