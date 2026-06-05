# Note #13 Investigation — Add Email Notification on Bulk AI Summary Completion

## File chain traced

```
QueueBulkAiSummaryJobs (interactor, initiates payload)
  → BulkGenerateAiSummariesJob (job, iterates)
    → ValidateAiSummaryGeneration (per-iteration validation)
    → TextractResult#generate_ai_summary_with_credit_flow (per-iteration pipeline)
    → BulkAiSummaryJobApplication (status tracking model)
    → AiJobApplicationSummary (result model, queried in on_complete)
    → GlobalChannel (WebSocket broadcast)
    → AiSummaryBulkCompletePayload (frontend type)
    → WebsocketGlobalChannelHandler.tsx (frontend toast handler)

Pattern examples:
  → JobResumeExportMailer (success + failure methods)
  → OrganizationDataExportMailer (success method)
  → ExportOrganizationCandidatesToCsvJob (GlobalChannel + mailer in job)
  → ExportOrganizationJobsToCsvJob (same pattern)
  → ExportOrganizationJobApplicationsToCsvJob (same pattern)
  → JobResumeExport model (status-change callbacks trigger both broadcast + mailer)

Framework:
  → job-iteration 1.12.0 Iteration module (on_complete callback behavior)
  → ActiveJob 6.1.7.7 Exceptions module (retry_on/discard_on ordering)
  → ActiveSupport 6.1.7.7 Rescuable (rescue_from reverse-order matching)
```

## Payload constructed by QueueBulkAiSummaryJobs

```
{
  'bulk_job_id'        => UUID,
  'user_id'            => integer (triggering user),
  'hiring_stage_id'    => integer,
  'job_id'             => integer,
  'job_application_ids'=> array of integers (the working set),
  'skipped_count'      => integer (input_ids.size - claimed_ids.size)
}
```

## Terminal states of BulkGenerateAiSummariesJob

### Terminal state 1: Normal completion (on_complete fires)

**When:** The enumerator exhausts all `job_application_ids`. Every item in the array has been passed to `each_iteration`. The gem's `iterate_with_enumerator` returns `true`, and `run_callbacks(:complete)` fires.

**Data available in on_complete:**
- `payload = arguments.first` — the full hash above
- `user = User.find_by(id: payload['user_id'])` — the triggering user
- `BulkAiSummaryJobApplication.where(bulk_job_id: payload['bulk_job_id'])` — per-row statuses (`:done` or `:failed`, possibly `:processing` if the StandardError rescue in each_iteration swallowed an error without updating status)
- `AiJobApplicationSummary.where(job_application_id: [...], status: :succeeded).where('created_at >= ?', floor_at).count` ��� succeeded count
- `failed = job_application_ids.size - succeeded` — everything else
- `payload['skipped_count']` — pre-queue skips
- `payload['job_id']` → `Job.find(...)` gives `job.title`, `job.organization`
- `payload['hiring_stage_id']` → `HiringStage.find(...)` gives stage name
- Link constructable: `/jobs/#{job_id}/stages/#{hiring_stage_id}/applicants`

**Current behavior:** Sends `GlobalChannel.broadcast_to(user, action: 'AI_SUMMARY_BULK_COMPLETE', payload: {...})`. Frontend renders toast with counts.

**Note:** The `failed` count is imprecise. It's `total - succeeded`, which includes: actual AI pipeline failures (AiJobApplicationSummary with status :failed), iterations where ValidateAiSummaryGeneration failed (no summary created at all), iterations where the StandardError rescue swallowed an error (bulk status stays :processing, no summary created). All of these get lumped into "failed."

### Terminal state 2: discard_on StandardError (job abandoned)

**When:** An exception propagates out of `perform` that matches `StandardError`. Due to ActiveJob rescue_from reverse-order matching, this includes:
- `CustomErrorAiSummary` (subclass of StandardError) — raised inside each_iteration, re-raised by the `rescue CustomErrorAiSummary; raise` block
- Any error in `build_enumerator` (e.g., payload is nil or malformed)
- Any error in the gem's own machinery (cursor deserialization, enumerator assertion)

**IMPORTANT FINDING:** The `retry_on CustomErrorAiSummary` declaration (line 12) is effectively unreachable. ActiveJob's `rescue_from` searches handlers in reverse declaration order. `discard_on StandardError` (declared at line 19, added to rescue_handlers last) is checked first. Since `StandardError === CustomErrorAiSummary.new` is true, the discard handler always wins. The retry_on block with `update_remaining_statuses_to_failed` never fires via this path.

**Data available in the discard_on block:**
- `current_job.arguments.first` — the full payload hash
- `error` — the exception instance

**Current behavior:** `update_remaining_statuses_to_failed(payload)` marks all still-`:processing` BulkAiSummaryJobApplication rows as `:failed`. No notification of any kind is sent to the user. The job silently disappears.

**What's queryable at this point (same as on_complete):**
- User from payload
- BulkAiSummaryJobApplication rows (some may be :done if earlier iterations succeeded before the error)
- AiJobApplicationSummary rows created before the error
- Job title, hiring stage, link — all constructable from payload

### Terminal state 3: retry_on exhaustion (EFFECTIVELY DEAD CODE)

**When:** Would fire after 3 `CustomErrorAiSummary` retries. But per the handler ordering analysis above, this path is unreachable — `discard_on StandardError` intercepts first.

**Data available:** Same as discard_on — `current_job.arguments.first` and `error`.

**Current behavior (if it could fire):** Same as discard_on: `update_remaining_statuses_to_failed(payload)`. No notification.

### Non-terminal interruption: job_iteration_max_job_runtime (10 minutes)

**When:** Iteration takes longer than 10 minutes. `job_should_exit?` returns true, `@needs_reenqueue = true`, job is re-enqueued with the cursor position. `on_complete` does NOT fire on this run. The job continues from where it left off on the next run.

**This is not a terminal state.** The job eventually reaches terminal state 1 (all items processed) or terminal state 2 (an error escapes).

## Established notification pattern (3 examples)

### Shared structural traits:

1. **Dual notification:** GlobalChannel WebSocket broadcast + mailer email, both triggered from the same completion point
2. **Email via Emails::SendTemplateEmail:** All mailers use this service, not ActionMailer's built-in rendering. Params: `from`, `to`, `list_unsubscribe`, `subject`, `template` (Mailgun template name), `template_version`, `tags`, `variables`
3. **from address:** `Variables::EMAIL_NOTIFICATIONS_ADDRESS` for user-facing task completions (exports); `Variables::DEFAULT_EMAIL_FROM_ADDRESS` for system alerts (credit notifications)
4. **Tags:** `['hire', 'user-facing']` for export emails; `['polymer', 'user-facing', 'ai-credits']` for AI credit emails
5. **deliver_later vs deliver_now:** Resume export uses `.deliver_later` (called from model callback). CSV exports use `.deliver_now` (called inline in the job's perform). Both work.
6. **Mailer args:** `JobResumeExportMailer` takes IDs (avoids stale GlobalID). `OrganizationDataExportMailer` takes records directly. ID-based is newer/preferred pattern per the comment in JobResumeExportMailer.
7. **Separate methods for success vs failure:** `JobResumeExportMailer` has `export_ready` and `export_failed`. `OrganizationDataExportMailer` only has `export_ready` (failure path just calls `mark_failed` with no email). The resume export is the more complete pattern.
8. **Failure broadcast includes a user-facing message string** in the payload (e.g., "Your resume export for #{job.title} couldn't be built. Please try again in a few minutes.")

### Example 1: ExportOrganizationCandidatesToCsvJob
- Completion: `GlobalChannel.broadcast_to(user, {...})` then `OrganizationDataExportMailer.export_ready(user, data_export).deliver_now`
- Failure: `rescue StandardError => e` → `data_export.mark_failed(e.message)` — no broadcast, no email on failure

### Example 2: ExportOrganizationJobApplicationsToCsvJob
- Same pattern as Example 1

### Example 3: JobResumeExport (model-based, most complete)
- Success: `GlobalChannel.broadcast_to(user, action: 'downloadJobResumesExport', ...)` then `JobResumeExportMailer.export_ready(user.id, id, url).deliver_later`
- Failure: `GlobalChannel.broadcast_to(user, action: 'jobResumesExportFailed', payload: { message: "..." })` then `JobResumeExportMailer.export_failed(user.id, id).deliver_later`
- Both wrapped in their own `rescue StandardError` with logging + Sentry

## Frontend WebSocket handling

Current `AI_SUMMARY_BULK_COMPLETE` handler in WebsocketGlobalChannelHandler.tsx:
- Renders toast with counts ("X AI summaries generated, Y failed, Z skipped")
- Toast kind: `success` (all good), `warning` (any failed), `info` (none processed)
- Toast includes `linkTo: payload.hiringStageLink`
- Invalidates `jobApplicationsForStage`, `jobApplication`, `organizationAiCreditBalance` queries

No existing handler for a bulk AI summary FAILURE action (the action doesn't exist yet).

Resume export failure handler (`jobResumesExportFailed`):
- Renders toast with `data.payload.message`, kind: `error`, delay: 10000

## cursor_rules consulted

- `cursor_rules/backend/background_jobs.md` — Rule 3 "Jobs orchestrate, don't contain business logic" (notification logic should stay thin in the callback). Rule 6 "`deliver_later` is not a background job" (don't wrap mailer call in a separate job class).
- `cursor_rules/backend/_base.md` — Rule 1 no begin blocks, Rule 4 never leave rescue blocks empty, Rule 9 variable names must match model names.
- `cursor_rules/core_critical_rules.md` — Standard rules (no begin blocks, guard clauses, etc.)

No conflicts with cursor_rules for this feature.
