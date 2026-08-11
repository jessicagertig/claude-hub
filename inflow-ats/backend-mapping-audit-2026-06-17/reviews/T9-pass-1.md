# T9 — Manual generate when no TextractResult exists

**Slice:** ValidateAiSummaryGeneration kicks off Textract; trace the validate path that initiates Textract and the state the summary is left in.

## Files traced (chain)

`app/controllers/api/v1/ai_job_application_summaries_controller.rb:8` (create → ValidateAiSummaryGeneration.call)
→ `app/interactors/validate_ai_summary_generation.rb:31` (latest_textract_result) , `:38-42` (no-textract branch)
→ `app/models/job_application.rb:685-687` (def latest_textract_result)
→ `app/jobs/submit_resume_to_textract_job.rb` (SubmitResumeToTextractJob#perform)
→ `app/services/submit_resume_to_textract.rb:22-27` (build TextractResult, link waiting summary, schedule poll)
→ back to controller `:17` → `app/interactors/create_ai_summary_generation.rb:46-57` (textract_processing summary built)
→ `app/models/organization.rb:961` (ai_credits_available? — definition exists, not descended)

## Entry point (manual single generate, "Generate" click)

`POST /api/v1/job_applications/:id/ai_job_application_summaries` →
`Api::V1::AiJobApplicationSummariesController#create`:

- `:6` `authorize :ai_job_application_summary, :create?`
- `:8-11` `ValidateAiSummaryGeneration.call(job_application:, organization: current_organization)`
- `:12-15` if validation fails → `render_general_errors([validation_result.error])` and return
- `:17-21` `CreateAiSummaryGeneration.call(job_application:, validation_result:, user: current_user)`
- `:22-23` on success → `render_one(result.ai_summary, ...Serializer)`

## The validate path that initiates Textract

`validate_ai_summary_generation.rb`:

Guards (fail-fast), `:24-29`:
- `:24` `context.fail!(error: 'Job application not found') if @job_application.nil?`
- `:25` `context.fail!(error: 'Organization not found') if @organization.nil?`
- `:26` `... unless flipper_enabled?` → `:66` `Flipper.enabled?(:AI_APPLICANT_SUMMARY, @organization)`
- `:27` `... unless has_resume?` → `:70` `@job_application.has_resume`
- `:28` `... unless credits_available?` → `:78` `@organization.ai_credits_available?`
- `:29` `context.fail!(error: 'This job needs a description before Plato can review candidates. Add one in Job Setup.') unless has_job_description?` → `:82` `@job_application.job&.description.present?`

Textract resolution:
- `:31` `@latest_textract_result = @job_application.latest_textract_result`
  - `job_application.rb:685-687`: `textract_results.order(created_at: :desc).first`
- `:32` `context.textract_result = @latest_textract_result`

No-TextractResult branch (THIS slice), `:38-42`:
```
unless @latest_textract_result
  SubmitResumeToTextractJob.perform_later(@job_application.id)
  context.textract_pending = true
  return
end
```
- `:39` enqueues `SubmitResumeToTextractJob.perform_later(@job_application.id)`
- `:40` `context.textract_pending = true`
- `:41` `return` — interactor SUCCEEDS (no `context.fail!`). Outputs on context: `textract_result = nil`, `textract_pending = true`.

## What SubmitResumeToTextractJob does (the initiated Textract)

`submit_resume_to_textract_job.rb`: `perform(job_application_id)` → `SubmitResumeToTextract.new(job_application_id).submit_resume`; rescues StandardError and only `ap`-logs it (swallowed).

`submit_resume_to_textract.rb#submit_resume`:
- `:9-10` guards: returns string if no job_application / no resume
- `:15-16` selects `resume_docx_to_pdf` if `has_resume_docx_to_pdf` else `resume`; `parser.send_to_textract(hash_id, resume_for_textract)`
- `:18-20` conditional stale: `unless ...where(status: :textract_processing, stale: false).exists?` → `ai_job_application_summaries.update_all(stale: true)`
- `:22` `@textract_result = @job_application.textract_results.build(textract_job_id: textract.job_id, textract_job_status: 'in_progress')`
- `:24-27` on save: `waiting_summary = ...find_by(status: :textract_processing, stale: false, textract_result_id: nil)`; `waiting_summary&.update_columns(textract_result_id: @textract_result.id)`; `GetResumeTextFromTextractJob.set(wait: 2.minutes).perform_later(@job_application.id)`
- `:31-40` AWS errors → `@textract_result&.update_columns(textract_job_status: 'failed')`

## The state the summary is left in

After validate returns (`textract_pending = true`, `textract_result = nil`), `CreateAiSummaryGeneration` runs:
- `:30-34` `active_ai_summary` = newest non-failed, non-stale summary
- `:36-39` if its `textract_result_id != job_application.latest_textract_result&.id` → mark stale, set nil
- `:41-44` if an active summary survives → return it (no new record)
- `:46-57` textract_pending path (this slice):
  - `:47-51` builds `AiJobApplicationSummary` with `textract_result: validation_result.textract_result` (**nil** here), `status: :textract_processing`, `requested_by_organization_user_id: context.user&.current_organization_user&.id`
  - `:53` `ai_summary.save` — no job enqueued
  - The `:60-77` pending/ready path (status `:pending` + immediate `GenerateAiJobApplicationSummaryJob`) is NOT taken on this slice.

**Terminal-ish state:** the new summary rests at `status: textract_processing` with `textract_result_id: nil`. It is NOT a true terminal status — it waits for an external actor. `SubmitResumeToTextract` (`:25-26`) later links the new TextractResult's id onto this waiting summary via `update_columns`, and `GetResumeTextFromTextractJob` (scheduled `:27`) advances it once Textract text arrives (the TextractResult `queue_ai_summary_job` after_commit then drives generation). If `SubmitResumeToTextract` raises before saving a TextractResult, no waiting-summary link happens and no poll job is scheduled — the summary stays `textract_processing` / `textract_result_id: nil` with no further actor (dead-end window; the job's StandardError rescue swallows the error).

## Verdicts vs old map (Trigger 9 / 9, Part 7 row 9, Part 3 #3)

1. **Map line 149: "File: validate_ai_summary_generation.rb:37-41"** — CHANGED. Actual no-textract branch is `:38-42`; the kickoff is `:39`, flag `:40`, return `:41`. Line numbers shifted by +1 because a new guard was inserted above.

2. **NEW guard `has_job_description?` at `:29`** — ABSENT from map. The map's validation list (lines 216-227) lists checks 1-6 and never mentions a job-description requirement. Current code fails validation with `'This job needs a description before Plato can review candidates. Add one in Job Setup.'` (`:29`, def `:81-83`) before any Textract resolution. This is a new fail-fast guard on the T9 path.

3. **Map lines 150-155 (no-TextractResult behavior)** — CONFIRMED. `latest_textract_result` nil → `SubmitResumeToTextractJob.perform_later` (`:39`), `textract_pending = true` (`:40`), return success (`:41`). `CreateAiSummaryGeneration` then builds a `textract_processing` summary with nil `textract_result_id` (`create_ai_summary_generation.rb:47-51`). `SubmitResumeToTextract` links `textract_result_id` after creating the TextractResult (`submit_resume_to_textract.rb:25-26`). CONFIRMED.

4. **Map line 152 / 223: `context.textract_result` set to nil on no-textract path** — MAP-WRONG (minor). The map (line 223) implies the no-textract branch sets only `textract_pending`. Code at `:31-32` sets `context.textract_result = @latest_textract_result` (nil here) BEFORE the branch, so `textract_result` is explicitly assigned nil for all paths, not left unset. Behavior matches (nil either way); exact write text differs.

5. **Map Part 7 row 9 "Flipper Gate: AI_APPLICANT_SUMMARY"** — CONFIRMED (`:26,66`). The map omits the additional `ai_credits_available?` and the new `has_job_description?` preconditions on this trigger; both gate the T9 path before Textract is initiated.

## Map text to write

> **Trigger 9 — Manual AI Summary Generation with No TextractResult**
> File: `app/interactors/validate_ai_summary_generation.rb`
> Preconditions (all fail-fast, in order): job_application present (`:24`); organization present (`:25`); Flipper `AI_APPLICANT_SUMMARY` (`:26`); `has_resume` (`:27`); `organization.ai_credits_available?` (`:28`); **job description present — `job_application.job&.description.present?` (`:29`, NEW)**.
> `latest_textract_result` is read at `:31` (`job_application.rb:686` `textract_results.order(created_at: :desc).first`) and stored on `context.textract_result` at `:32` (nil here).
> No-TextractResult branch (`:38-42`): enqueues `SubmitResumeToTextractJob.perform_later(job_application.id)` (`:39`), sets `context.textract_pending = true` (`:40`), returns success (`:41`).
> `CreateAiSummaryGeneration` (`:46-57`) then builds an `AiJobApplicationSummary` with `status: textract_processing`, `textract_result: nil`, `requested_by_organization_user_id` set; saves; enqueues NO generation job.
> `SubmitResumeToTextract` (`:22-27`) creates the TextractResult (`in_progress`), then `find_by(status: :textract_processing, stale: false, textract_result_id: nil)` and `update_columns(textract_result_id: new_result.id)` to link the waiting summary, and schedules `GetResumeTextFromTextractJob` (+2 min). Summary advances only when Textract text arrives.

## Record-write sites on this slice

| file:line | literal | record/column | method |
|---|---|---|---|
| `validate_ai_summary_generation.rb:39` | `SubmitResumeToTextractJob.perform_later(@job_application.id)` | (enqueue only — no DB write) | n/a |
| `create_ai_summary_generation.rb:37` | `active_ai_summary.update_columns(stale: true)` | AiJobApplicationSummary.stale | update_columns |
| `create_ai_summary_generation.rb:47-53` | `ai_job_application_summaries.build(textract_result: nil, status: :textract_processing, requested_by_organization_user_id: ...)` + `ai_summary.save` | AiJobApplicationSummary INSERT (status, textract_result_id=nil, requested_by_organization_user_id) | save |
| `submit_resume_to_textract.rb:19` | `@job_application.ai_job_application_summaries.update_all(stale: true)` | AiJobApplicationSummary.stale (all) | update_all |
| `submit_resume_to_textract.rb:22-24` | `textract_results.build(textract_job_id:, textract_job_status: 'in_progress')` + save | TextractResult INSERT (textract_job_id, textract_job_status) | save |
| `submit_resume_to_textract.rb:26` | `waiting_summary&.update_columns(textract_result_id: @textract_result.id)` | AiJobApplicationSummary.textract_result_id | update_columns |
| `submit_resume_to_textract.rb:33,39` | `@textract_result&.update_columns(textract_job_status: 'failed')` | TextractResult.textract_job_status | update_columns |

## Desync windows (AiJobApplicationSummaryStatus relevance)

- This slice does not directly write `AiJobApplicationSummaryStatus`. The new `textract_processing` summary triggers `AiJobApplicationSummary#create_status_record` (`after_commit on: :create`, per map line 500) but that path is outside T9's literal writes. No denormalized columns are written on T9.
- Dead-end window: if `SubmitResumeToTextract` raises before TextractResult save (AWS error path leaves `@textract_result` nil at `:33/:39`), the `textract_processing` summary keeps `textract_result_id: nil` and no `GetResumeTextFromTextractJob` is scheduled — no actor advances it. The job's `rescue StandardError` (`submit_resume_to_textract_job.rb`) only `ap`-logs.
