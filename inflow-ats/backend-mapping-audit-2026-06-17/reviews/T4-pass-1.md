# T4 — Customer API Apply: Textract Trigger Trace (Pass 1)

**Angle:** T4 — The public/customer API apply endpoint that creates a job application; trace whether and how Textract is triggered, to terminal.

## Files traced (explicit chain)

```
config/routes.rb:499-501
  -> app/controllers/api_public/v1/hire/job_applications_controller.rb:62  (def apply)
       -> app/interactors/customer_api/validate_job_application_apply.rb        (validate + decode resume base64)
       -> app/interactors/customer_api/create_job_application.rb                (build candidate + job_application, attach resume, candidate.save)
       -> app/interactors/customer_api/complete_job_application.rb              (question responses + confirmation email)
  -> (transaction commits) app/models/job_application.rb:45  after_commit :enqueue_new_job_application, on: [:create]
       -> app/models/job_application.rb:164-171  def enqueue_new_job_application
            -> app/models/job_application.rb:167-169  Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization) -> SubmitResumeToTextractJob.perform_later(id)
                 -> app/jobs/submit_resume_to_textract_job.rb
                      -> app/services/submit_resume_to_textract.rb   (has_resume guard; build TextractResult in_progress; enqueue GetResumeTextFromTextractJob wait:2.min)
                           -> app/jobs/get_resume_text_from_textract_job.rb  (retry_on CustomErrorTextract attempts:3, exhaustion -> cleanup_orphaned_summary)
                                -> app/services/get_resume_text_from_textract.rb  (poll AWS; on succeeded -> update textract_job_status + textract_job_result_text; on failed -> raise CustomErrorTextract)
                                     -> app/models/textract_result.rb:7  after_commit :queue_ai_summary_job, on: [:create, :update]
                                          -> app/models/textract_result.rb:114-144 def queue_ai_summary_job
                                               -> app/models/job.rb:914 should_auto_generate_ai_summaries?
            -> app/models/job_application.rb:170  find_or_create_ai_job_application_summary_status
                 -> app/interactors/find_or_create_ai_job_application_summary_status.rb  (creates AiJobApplicationSummaryStatus, status 'none' for fresh apply)
       -> app/models/job_application.rb:589-602  has_resume (corrupt-file purge guard)
```

## The apply endpoint

Route: `config/routes.rb:499-501`
```
499:          resources :job_applications, only: [:index, :show] do
500:            collection do
501:              post :apply
```
(import is the next line, `502: post :import`.)

Controller action `app/controllers/api_public/v1/hire/job_applications_controller.rb:62`:
```
62:  def apply
...
66:    ctx = job_application_context(:created_via_customer_api_apply)
68:    ActiveRecord::Base.transaction do
69:      @result = CustomerApi::ValidateJobApplicationApply.call(ctx)
72:      @result = CustomerApi::CreateJobApplication.call(@result)
75:      @result = CustomerApi::CompleteJobApplication.call(@result)
77:    end
```

**Textract is NOT triggered directly by any of the three interactors.** None of `ValidateJobApplicationApply`, `CreateJobApplication`, or `CompleteJobApplication` references Textract, SubmitResumeToTextract, or any summary generation. The Textract trigger is entirely a side effect of the `JobApplication` `after_commit :enqueue_new_job_application, on: [:create]` model callback.

## Where the JobApplication is persisted (commit point)

`CreateJobApplication` builds the application via `candidate.job_applications.build(...)` and attaches the decoded resume BEFORE save:
- `app/interactors/customer_api/create_job_application.rb:50-57` build + `attach_resume(job_application)`
- `app/interactors/customer_api/create_job_application.rb:70-78` `attach_resume`: `job_application.resume.attach(io: StringIO.new(context.decoded_resume), ...)` — only `return unless context.decoded_resume.present?` (line 71).
- New-candidate branch persists via `save_new_candidate(candidate)` -> `candidate.save` (`:62-68`), which saves the built job_application + attached resume.
- Existing-candidate branch (`:28-41`) builds + `job.candidates.push(candidate)` (line 40) — the push persists the association; the actual job_application row is read back at `:23` `context.job_application = candidate.job_applications.where(job_id: job.id).order(created_at: :desc).first`.

Because the controller wraps all three interactors in `ActiveRecord::Base.transaction`, the `after_commit` callback does not fire until the whole transaction commits (after CompleteJobApplication). So the resume is already attached at the time `enqueue_new_job_application` runs.

## The trigger callback

`app/models/job_application.rb:45`:
```
45:  after_commit :enqueue_new_job_application, on: [:create]
```
`app/models/job_application.rb:164-171`:
```
164:  def enqueue_new_job_application
165:    NewJobApplicationJob.perform_later(id) # calls handle_new_job_application
166:    DocxToPdfJob.perform_later(id)
167:    if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)
168:      SubmitResumeToTextractJob.perform_later(id)
169:    end
170:    find_or_create_ai_job_application_summary_status
171:  end
```
- Textract is **gated** by `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)` (line 167). If disabled for the org, Textract is never submitted on the apply path.
- `find_or_create_ai_job_application_summary_status` (line 170) runs unconditionally — it creates the denormalized `AiJobApplicationSummaryStatus` row.

## AiJobApplicationSummaryStatus on the apply path

`app/models/job_application.rb:160-162`:
```
160:  def find_or_create_ai_job_application_summary_status
161:    FindOrCreateAiJobApplicationSummaryStatus.call(job_application: self)
```
For a brand-new apply there is no existing `ai_job_application_summary_status` and no `latest_ai_job_application_summary`, so `app/interactors/find_or_create_ai_job_application_summary_status.rb` falls into:
```
@status_record = job_application.build_ai_job_application_summary_status
... (latest summary absent) ...
else
  @status_record.status = 'none'
end
unless @status_record.save ...
```
**Result: one AiJobApplicationSummaryStatus row is created with status `'none'`, all denormalized columns (ai_job_application_summary_id, score_percentage, headline, integrated_role_analysis) nil. NO AiJobApplicationSummary record is created by the apply path.**

## SubmitResumeToTextract (branch logic)

`app/services/submit_resume_to_textract.rb`:
```
return 'JobApplication not found' unless @job_application
return 'No resume attached' unless @job_application.has_resume         # guard
resume_for_textract = @job_application.has_resume_docx_to_pdf ? @job_application.resume_docx_to_pdf : @job_application.resume
textract = parser.send_to_textract(@job_application.hash_id, resume_for_textract)

unless @job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).exists?
  @job_application.ai_job_application_summaries.update_all(stale: true)
end

@textract_result = @job_application.textract_results.build(textract_job_id: textract.job_id, textract_job_status: 'in_progress')
if @textract_result.save
  waiting_summary = @job_application.ai_job_application_summaries.find_by(status: :textract_processing, stale: false, textract_result_id: nil)
  waiting_summary&.update_columns(textract_result_id: @textract_result.id)
  GetResumeTextFromTextractJob.set(wait: 2.minutes).perform_later(@job_application.id)
...
rescue ... => e
  @textract_result&.update_columns(textract_job_status: 'failed')
```
**Apply-path specifics:** a fresh apply has NO AiJobApplicationSummary, so:
- `.where(status: :textract_processing, stale: false).exists?` is FALSE -> `update_all(stale: true)` runs against zero summary rows (no-op).
- `waiting_summary` is nil -> no summary->textract_result linkage.
- TextractResult is created `in_progress`; `GetResumeTextFromTextractJob` enqueued with wait 2 minutes.

This is the **"Textract IS submitted, no summary waiting"** branch. The apply path never takes the "summary goes to textract_processing and waits" branch — that branch only exists when an AiJobApplicationSummary in `textract_processing` already exists (manual/auto summary-generation paths), which the apply endpoint does not create.

## Terminal states

`app/jobs/get_resume_text_from_textract_job.rb` -> `app/services/get_resume_text_from_textract.rb`:
- **SUCCESS:** `textract_job.job_status.downcase == 'succeeded'` -> `@textract_result.update(textract_job_status: 'succeeded', textract_job_result:, textract_job_result_text: ...)`. **Terminal status: TextractResult `succeeded`.**
- **FAILED (AWS reports failed):** `@textract_result.update_columns(textract_job_status: 'failed')` then `raise CustomErrorTextract` -> job retries (3 attempts, wait 5 min). On exhaustion, `GetResumeTextFromTextractJob.cleanup_orphaned_summary` runs but finds no `textract_processing` summary on the apply path -> `return unless summary` -> no-op. **Terminal status: TextractResult `failed`.**
- **Other status (still processing):** `raise CustomErrorTextract` -> retry. After 3 exhausted attempts, TextractResult stays `in_progress` (never set to failed in the "else" branch — only the explicit AWS-`failed` branch sets it). **Possible resting state: TextractResult stuck `in_progress` with no further actor (dead end).**
- **InvalidJobIdException:** `@textract_result.update_columns(textract_job_status: 'failed', textract_job_id: nil)`.
- **InvalidS3ObjectException / StandardError in SubmitResumeToTextract:** TextractResult set `failed`.

## After Textract succeeds: queue_ai_summary_job (terminal AI branch)

`app/models/textract_result.rb:7` `after_commit :queue_ai_summary_job, on: [:create, :update]` fires when the apply-path TextractResult is updated to `succeeded` with text.

`app/models/textract_result.rb:114-144`:
```
114:  def queue_ai_summary_job
115:    return unless textract_job_result_text.present?
116:    return unless saved_change_to_textract_job_result_text?
...
121:    ai_summary_waiting_on_textract = job_application.ai_job_application_summaries
122:      .where(status: :textract_processing, stale: false).first
125:    if ai_summary_waiting_on_textract           # NOT taken on apply path (no summary exists)
...
137:    else
138:      return unless job_application&.job&.should_auto_generate_ai_summaries?
140:      result = ValidateAiSummaryGeneration.call(...)
142:      GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id) if result.success?
```
On the apply path there is no `textract_processing` summary, so the `else` branch (line 137) is taken:
- If `job.should_auto_generate_ai_summaries?` is FALSE (`app/models/job.rb:914-922`, default falls through to `organization.auto_generate_ai_summaries_enabled`), **the chain rests: TextractResult `succeeded`, AiJobApplicationSummaryStatus `none`, NO AiJobApplicationSummary. This is a clean terminal state with no further actor.**
- If TRUE and `ValidateAiSummaryGeneration` succeeds, `GenerateAiJobApplicationSummaryJob` is enqueued — handing off to the AI-summary pipeline (out of T4 scope; that is the auto-generate slice).

## Desync windows (AiJobApplicationSummaryStatus)

On the apply path the status row is created `'none'` and stays `'none'` unless auto-generation runs. If auto-generation later succeeds, the Status row update happens inside that pipeline (not the apply path). The apply path itself opens no desync window beyond creating the `'none'` row — but note that on the auto-generate branch, the window between TextractResult `succeeded` and the GenerateAiJobApplicationSummaryJob completing is one where the Status row reads `'none'` while a summary is being produced. (BROADCAST_STATUSES desync is in the summary pipeline, not the apply path.)

## Verdicts vs old map

| Behavior | Map says | Verdict |
|---|---|---|
| Apply endpoint at `job_applications_controller.rb:62-94`, created_via `created_via_customer_api_apply` | Trigger 4, lines 102-109 | CONFIRMED |
| Chain: interactor builds+saves job_application -> after_commit :enqueue_new_job_application | "Interactor creates candidate + job_application -> candidate.save -> after_commit" (map:103) | CONFIRMED |
| Textract gated by Flipper TEXTRACT_RESUME_PROCESSING | map table row 4 (line 684) lists guard | CONFIRMED |
| `enqueue_new_job_application` also calls `find_or_create_ai_job_application_summary_status` (creates Status row 'none') | ABSENT from map (map never mentions the Status row being created on the apply/creation path; AiJobApplicationSummaryStatus has no section) | NEW |
| Apply path creates NO AiJobApplicationSummary; TextractResult succeeds then queue_ai_summary_job else-branch gated on should_auto_generate_ai_summaries? | Map describes the trigger to SubmitResumeToTextract but does not trace the apply path's terminal (no-summary -> auto-generate gate) | NEW / CHANGED (map stops at the trigger; current code's terminal gate documented here) |
| Existing-candidate branch uses `job.candidates.push` and re-reads job_application | ABSENT from map | NEW |

## Record-write sites on the T4 slice (file:line + literal + column + op)

1. `app/interactors/customer_api/create_job_application.rb:62-66` — `candidate.save` (persists built JobApplication + attached resume) — JobApplication insert (all columns: job_id, created_via, source, last_updated_by_organization_user_id) — `save` (full).
2. `app/interactors/customer_api/create_job_application.rb:40` — `job.candidates.push(candidate)` (existing-candidate branch) — Candidate/Job association + JobApplication persist — association save.
3. `app/interactors/customer_api/create_job_application.rb:73-77` — `job_application.resume.attach(io: StringIO.new(context.decoded_resume), ...)` — ActiveStorage attachment (resume) — attach.
4. `app/interactors/find_or_create_ai_job_application_summary_status.rb` — `@status_record = job_application.build_ai_job_application_summary_status; @status_record.status = 'none'; @status_record.save` — AiJobApplicationSummaryStatus insert (status='none', denormalized cols nil) — `save` (full).
5. `app/services/submit_resume_to_textract.rb` — `@job_application.ai_job_application_summaries.update_all(stale: true)` — AiJobApplicationSummary.stale (NO-OP on apply path; zero rows) — `update_all`.
6. `app/services/submit_resume_to_textract.rb` — `@textract_result = @job_application.textract_results.build(textract_job_id:, textract_job_status: 'in_progress'); @textract_result.save` — TextractResult insert (textract_job_id, textract_job_status='in_progress') — `save` (full).
7. `app/services/submit_resume_to_textract.rb` — `waiting_summary&.update_columns(textract_result_id: @textract_result.id)` — AiJobApplicationSummary.textract_result_id (nil/no-op on apply path) — `update_columns`.
8. `app/services/submit_resume_to_textract.rb` (rescue blocks) — `@textract_result&.update_columns(textract_job_status: 'failed')` — TextractResult.textract_job_status — `update_columns`.
9. `app/services/get_resume_text_from_textract.rb` — `@textract_result.update(textract_job_status: 'succeeded', textract_job_result:, textract_job_result_text: ...)` — TextractResult.textract_job_status + textract_job_result + textract_job_result_text — `update` (full, fires callbacks incl. queue_ai_summary_job).
10. `app/services/get_resume_text_from_textract.rb` — `@textract_result.update_columns(textract_job_status: 'failed')` (AWS failed branch) — TextractResult.textract_job_status — `update_columns`.
11. `app/services/get_resume_text_from_textract.rb` — `@textract_result.update_columns(textract_job_status: 'failed', textract_job_id: nil)` (InvalidJobIdException) — TextractResult.textract_job_status + textract_job_id — `update_columns`.
12. `app/models/job_application.rb:594-596` (within has_resume, only if corrupt file) — `resume.purge_later` / `resume_docx_to_pdf.purge_later` — ActiveStorage detach — purge.

## Note on `import` action (sibling, not apply)

`app/controllers/api_public/v1/hire/job_applications_controller.rb:97` `import` runs only `ValidateJobApplicationImport` + `CreateJobApplication` (NO CompleteJobApplication). It still persists the JobApplication via `candidate.save`, so the same `after_commit :enqueue_new_job_application` fires and triggers the identical Textract chain. Map Trigger 5 (lines 111-116) says "Same interactor chain as Apply" — that is MAP-WRONG in detail: import omits `CompleteJobApplication` (no question responses / no confirmation email), but the Textract-relevant chain (CreateJobApplication -> after_commit) is identical. The Textract behavior is the same; the interactor list differs.
