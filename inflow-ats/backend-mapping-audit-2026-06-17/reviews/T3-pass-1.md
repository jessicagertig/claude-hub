# T3 — Clone Job Application to Another Job (pass 1)

## File trace chain

config/routes.rb:282 (`put :clone_to_job`)
→ app/controllers/api/v1/job_applications_controller.rb:132 (`def clone_to_job`)
→ app/models/job_application.rb:387 (`clone_to_job_at_hiring_stage`)
→ app/models/job_application.rb:391 (`dup`) + :401 (`resume.attach(resume.blob)`)
→ controller:139 (`new_job_application.save`)
→ app/models/job_application.rb:45 (`after_commit :enqueue_new_job_application, on: [:create]`)
→ app/models/job_application.rb:164 `enqueue_new_job_application`
→ :168 `SubmitResumeToTextractJob.perform_later(id)` (Flipper-gated)
→ :170 `find_or_create_ai_job_application_summary_status`
→ app/jobs/submit_resume_to_textract_job.rb:7 → app/services/submit_resume_to_textract.rb:8 `submit_resume`
→ submit_resume_to_textract.rb:22 (`textract_results.build(... textract_job_status: 'in_progress')`) + :27 `GetResumeTextFromTextractJob.set(wait: 2.minutes)`
→ app/jobs/get_resume_text_from_textract_job.rb:25 → app/services/get_resume_text_from_textract.rb:8 `parse_resume_text`
→ get_resume_text_from_textract.rb:31 (`@textract_result.update(... textract_job_status: 'succeeded', textract_job_result_text: ...)`)
→ app/models/textract_result.rb:7 (`after_commit :queue_ai_summary_job`)
→ textract_result.rb:114 `queue_ai_summary_job`
→ textract_result.rb:138 `job_application.job.should_auto_generate_ai_summaries?` → app/models/job.rb:914
→ (if true) textract_result.rb:142 `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)`

Also traced:
- app/interactors/clone_job_application.rb (DEAD — no callers, references undefined `clone_to_job`/`new_job_id`)
- app/interactors/find_or_create_ai_job_application_summary_status.rb
- app/models/job_application.rb:414 `complete_cloning` (`after_create`, copies question_responses only)

## Branch decision (Textract readiness)

The clone path does NOT inspect any existing Textract readiness. It unconditionally **re-submits the cloned resume blob fresh to AWS Textract** and BUILDS a brand-new `TextractResult` for the cloned job_application (submit_resume_to_textract.rb:22). It does NOT copy the original's `TextractResult` row, nor its `textract_job_result_text`. `dup` (job_application.rb:391) copies column attributes only — Rails `dup` does not copy `has_many :textract_results` or `has_many :ai_job_application_summaries` children (framework boundary: ActiveRecord `dup`).

Because the clone has zero `AiJobApplicationSummary` rows at creation, the "waiting summary" lookups all miss:
- submit_resume_to_textract.rb:25 `find_by(status: :textract_processing, stale: false, textract_result_id: nil)` → nil (nothing to back-fill)
- submit_resume_to_textract.rb:18 existence check → false → :19 `update_all(stale: true)` runs on an empty set (no-op)
- textract_result.rb:121 `where(status: :textract_processing, stale: false).first` → nil → falls to else branch :137

So the clone takes the **auto-generation gate branch** (textract_result.rb:138), not the "summary waiting on Textract" branch.

## Terminal states

1. **Flipper `:TEXTRACT_RESUME_PROCESSING` OFF** (job_application.rb:167): no `SubmitResumeToTextractJob` enqueued. Clone comes to rest with: AiJobApplicationSummaryStatus row = `none` (interactor:34), NO TextractResult, NO summary. DEAD END (no further actor).
2. **No resume on clone** (submit_resume_to_textract.rb:10 `return 'No resume attached'`): if original had no resume, `has_resume` false at job_application.rb:401 so nothing attached; service returns early, no TextractResult built. Status row = `none`. DEAD END.
3. **Textract succeeds, target job auto-generate = false** (job.rb:914 chain → false): TextractResult `succeeded` with `textract_job_result_text` saved; `queue_ai_summary_job` returns at textract_result.rb:138. Status row stays `none`. NO AI summary. Terminal — intentional dead end (no actor advances it; user must manually trigger).
4. **Textract succeeds, target job auto-generate = true**: textract_result.rb:142 enqueues `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)` with NO `requesting_organization_user_id`. AI pipeline runs (out of T3 scope downstream), summary → succeeded → status row updated to `current` by the summary pipeline.
5. **Textract fails / polls non-succeeded**: get_resume_text_from_textract.rb:41/44 `raise CustomErrorTextract` → GetResumeTextFromTextractJob retry_on (job:6) 3 attempts; on exhaustion get_resume_text_from_textract_job.rb:10 `cleanup_orphaned_summary` finds NO waiting summary for a clone (job:14-16 returns), so nothing destroyed/broadcast. TextractResult left `failed`. Status row stays `none`. DEAD END.

## AiJobApplicationSummaryStatus sync for clone

At clone creation (job_application.rb:170 → interactor): no status record exists → else branch (interactor:22). `latest_ai_job_application_summary` is nil (no summaries on clone) → interactor:34 `status = 'none'`, no denormalized columns set. Status row is created clean. No desync at creation. Desync windows are downstream (covered by the AI pipeline slice), but for T3: between Textract-succeeded and the `GenerateAiJobApplicationSummaryJob` completing (branch 4), the status row reads `none` while a summary is being generated — and transitions into `awaiting_job_criteria`/`retrying` on the summary do not broadcast (BROADCAST_STATUSES exclusion), so the clone's list-row status display can lag.

## Verdicts vs old map (Trigger 3, map lines 94-100; table row line 683)

| Behavior | Map says | Verdict |
|---|---|---|
| Chain: controller clone → save → after_commit(:enqueue_new_job_application) | line 95 same | CONFIRMED |
| `clone_to_job_at_hiring_stage` builds dup + `resume.attach(resume.blob)` | line 98 same | CONFIRMED |
| "Textract processes the cloned job_application's resume independently" / "Independent TextractResult for clone" | lines 100, 683 | CONFIRMED — fresh TextractResult built (submit_resume_to_textract.rb:22), original not copied |
| Controller file line range `128-141` | line 97 | MAP-WRONG — actual action is controller:132-145 |
| Flipper `:TEXTRACT_RESUME_PROCESSING` gate on Textract submit for clone | line 683 column | CONFIRMED (job_application.rb:167) |
| `find_or_create_ai_job_application_summary_status` creates a `none` status row on clone | ABSENT from map | NEW |
| AI summary auto-generation for clone gated on TARGET job `should_auto_generate_ai_summaries?` (no waiting-summary branch) | ABSENT from map | NEW |
| Dead `CloneJobApplication` interactor (undefined `clone_to_job`, undefined `new_job_id`, zero callers) | ABSENT from map | NEW |
| `complete_cloning` (after_create) copies only question_responses (channels/messages commented out) | ABSENT from map | NEW |

## Updated map text (replace Trigger 3)

> #### Trigger 3: Clone Job Application to Another Job
> **Chain:** `PUT /api/v1/job_applications/:id/clone_to_job` (routes.rb:282) → controller `clone_to_job` (job_applications_controller.rb:132-145) → `clone_to_job_at_hiring_stage` (job_application.rb:387) → `new_job_application.save` (controller:139) → `after_commit :enqueue_new_job_application, on: [:create]` (job_application.rb:45).
>
> - `clone_to_job_at_hiring_stage` does `dup` (job_application.rb:391) and `resume.attach(resume.blob)` if `has_resume` (job_application.rb:401). `dup` copies attributes only — the original's `TextractResult` and `AiJobApplicationSummary` rows are NOT copied.
> - `enqueue_new_job_application` (job_application.rb:164): `NewJobApplicationJob`, `DocxToPdfJob`, and — only if Flipper `:TEXTRACT_RESUME_PROCESSING` enabled for the org (job_application.rb:167) — `SubmitResumeToTextractJob.perform_later(id)`. Then `find_or_create_ai_job_application_summary_status` (job_application.rb:170) creates a fresh `AiJobApplicationSummaryStatus` with status `none` (interactor:34, since the clone has no summary).
> - `SubmitResumeToTextract#submit_resume` BUILDS a NEW `TextractResult` (`textract_job_status: 'in_progress'`, submit_resume_to_textract.rb:22) and schedules `GetResumeTextFromTextractJob` (wait 2.minutes, :27). The clone re-OCRs its resume independently; it does not reuse the original's result.
> - On Textract success, `GetResumeTextFromTextract` updates the new `TextractResult` to `succeeded` with `textract_job_result_text` (get_resume_text_from_textract.rb:31), firing `after_commit :queue_ai_summary_job` (textract_result.rb:7). Because no summary is `textract_processing` for a clone, the handler takes the else branch (textract_result.rb:137) and auto-generates a summary ONLY if the TARGET job's `should_auto_generate_ai_summaries?` is true (textract_result.rb:138, job.rb:914), via `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)` with no requesting user. If false, the clone rests at TextractResult `succeeded` + status `none` with no AI summary (manual trigger required).
> - DEAD: `app/interactors/clone_job_application.rb` (`CloneJobApplication`) is unreferenced and broken — it calls an undefined `job_application.clone_to_job(new_job_id, ...)` against an undefined local `new_job_id`. Not on any route. Live clone path is the controller action only.

## Record-write sites on the T3 slice

| file:line | literal | column | op |
|---|---|---|---|
| job_application.rb:395 | `job_application.job_id = target_job.id` | job_id (in-memory on dup) | assignment (persisted by controller:139 `save`) |
| job_application.rb:396 | `job_application.hash_id = nil` | hash_id | assignment |
| job_application.rb:397 | `job_application.hiring_stage_id = target_hiring_stage.id` | hiring_stage_id | assignment |
| job_application.rb:398 | `job_application.last_updated_by_organization_user_id = current_organization_user_id` | last_updated_by_organization_user_id | assignment |
| job_application.rb:399 | `job_application.clone_of_job_application_id = id` | clone_of_job_application_id | assignment |
| job_application.rb:400 | `job_application.created_via = 'created_via_clone'` | created_via | assignment |
| job_application.rb:401 | `job_application.resume.attach(resume.blob)` | resume (ActiveStorage attachment) | attach |
| controller:139 | `new_job_application.save` | full row INSERT | create (save) |
| submit_resume_to_textract.rb:19 | `@job_application.ai_job_application_summaries.update_all(stale: true)` | stale (no-op for clone, empty set) | update_all |
| submit_resume_to_textract.rb:22 | `textract_results.build(textract_job_id:, textract_job_status: 'in_progress')` | new TextractResult row | build (saved :24) |
| submit_resume_to_textract.rb:26 | `waiting_summary&.update_columns(textract_result_id: ...)` | textract_result_id (nil target for clone — no-op) | update_columns |
| submit_resume_to_textract.rb:33/39 | `@textract_result&.update_columns(textract_job_status: 'failed')` | textract_job_status | update_columns |
| get_resume_text_from_textract.rb:31 | `@textract_result.update(textract_job_status:, textract_job_result:, textract_job_result_text:)` | textract_job_status, textract_job_result, textract_job_result_text | update |
| get_resume_text_from_textract.rb:40/47 | `@textract_result.update_columns(textract_job_status: 'failed'...)` | textract_job_status (+ textract_job_id nil at :47) | update_columns |
| interactor find_or_create:34/37 | `@status_record.status = 'none'` then `@status_record.save` | AiJobApplicationSummaryStatus.status (+ row INSERT) | create (save) |
