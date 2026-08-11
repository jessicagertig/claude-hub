# T3 Adversarial Review (Pass 2) — Clone Job Application

Slice: T3 — Clone job application to another job. Does cloning create a TextractResult, trigger Textract, or copy an existing result?

Re-traced from scratch against current code. Chain:
`config/routes.rb:282` → `job_applications_controller.rb:132-145 (clone_to_job)` → `job_application.rb:387-412 (clone_to_job_at_hiring_stage)` → controller `:139 new_job_application.save` → `job_application.rb:45 after_commit :enqueue_new_job_application` → `:164-171` → `SubmitResumeToTextractJob` / `find_or_create_ai_job_application_summary_status`; plus `:47 after_create :complete_cloning` → `:414-437`.

## Verdicts on map statements

### Changelog T3 bullet 1 — controller line range
Map: "`def clone_to_job` at `app/controllers/api/v1/job_applications_controller.rb:132-145`; route `put :clone_to_job` at `config/routes.rb:282`."
AGREE. `clone_to_job` spans controller lines 132-145; route at routes.rb:282 (`put :clone_to_job`).

### Changelog T3 bullet 2 — fresh status row 'none' via FindOrCreate else branch
Map: "Clone creates a fresh `AiJobApplicationSummaryStatus` row with status `'none'` via `FindOrCreateAiJobApplicationSummaryStatus` (else branch, `:34`)."
AGREE. enqueue_new_job_application:170 calls find_or_create. The cloned app is a fresh `dup` with no summaries, so `@status_record` is nil (no row) and `latest_ai_job_application_summary` is nil → else branch → `'none'` at find_or_create_ai_job_application_summary_status.rb:34.

### Changelog T3 bullet 3 — auto-gen gated on TARGET job, no requesting user
Map: "Clone AI auto-generation gated solely on the TARGET job's `should_auto_generate_ai_summaries?` (`textract_result.rb:137-142`, `job.rb:914`); enqueued with no requesting user."
AGREE. The cloned app has no `textract_processing` summary, so `queue_ai_summary_job` takes the else branch (textract_result.rb:137). Guard `return unless job_application&.job&.should_auto_generate_ai_summaries?` at :138 (job.rb:914-922). Enqueue at :142 passes only `textract_result_id:` (no requesting_organization_user_id) → no AI_SUMMARY_COMPLETE toast.

### Changelog T3 bullet 4 — CloneJobApplication is dead code
Map: "`CloneJobApplication` is DEAD CODE: zero callers, calls an undefined `job_application.clone_to_job` and an undefined local `new_job_id` (`clone_job_application.rb:22`). Not on any route."
AGREE. grep for `CloneJobApplication` returns only self-references (clone_job_application.rb:3,8). No `def clone_to_job` exists on any model (only `clone_to_job_at_hiring_stage`); line 22 calls `job_application.clone_to_job(new_job_id, context.user.id)` — `clone_to_job` undefined on the model and `new_job_id` undefined local. No route references this interactor (the route maps to the controller action of the same name, not the interactor).

### Changelog T3 bullet 5 — complete_cloning copies only question_responses
Map: "`complete_cloning` (after_create, `:414-437`) copies only `question_responses`; channel/message cloning is commented out. Does not touch Textract or AI summaries."
AGREE. complete_cloning at job_application.rb:414-437; channels/messages block commented (:420-428); only `original.question_responses.reverse_each { question_responses << dup }` (:430-436). No Textract/AI reference. Registered `after_create :complete_cloning` at :47.

### Trigger 3 narrative (lines 190-196) — dup copies attributes only; no clone of textract/summaries; fresh independent Textract
Map: "`dup` copies attributes only (`:391`); original `textract_results` and `ai_job_application_summaries` are NOT cloned. `resume.blob` re-attached (`:401`); `created_via='created_via_clone'`; `clone_of_job_application_id` set. Controller `.save` (line 139) fires `after_commit :enqueue_new_job_application` → Flipper-gated fresh Textract submit + status row `'none'`."
AGREE. `job_application = dup` at :391 (Rails framework dup copies columns only; child has_many/has_one records keyed on job_application_id are not copied). Resume re-attach `resume.attach(resume.blob) if has_resume` at :401. `created_via = 'created_via_clone'` at :400; `clone_of_job_application_id = id` at :399. Controller :139 saves; after_commit on:[:create] (:45) fires enqueue_new_job_application; Textract submit Flipper-gated at :167 (`TEXTRACT_RESUME_PROCESSING`, scoped `job.organization`).

### Terminal-state claim — clone produces a fresh independent TextractResult, takes the no-waiting-summary (auto) branch
SubmitResumeToTextract for the clone: stale `update_all` at :19 is a no-op (no summaries); builds fresh `in_progress` TextractResult at :22; `waiting_summary` find_by at :25 returns nil (no summaries) → no link; schedules poll at :27. On poll success, `queue_ai_summary_job` else branch (auto). AGREE — fully consistent with the map.

### Trigger Matrix row 3 (line 494)
Map: "Clone | `clone_to_job` (`:132-145`) → save → after_commit | Blob copy | TEXTRACT_RESUME_PROCESSING | created `'none'` | Fresh independent TextractResult."
AGREE on all cells.

## Omissions
None material. The map's T3 coverage is complete: it states the branch taken (no-waiting-summary auto branch via the target job's auto-gen gate), the terminal (fresh independent TextractResult; no copied result; no copied summary), the status-row creation (`'none'`), the dead-code interactor, complete_cloning scope, and the Flipper gate. Two minor, non-load-bearing notes (not omissions worth flagging):
- Controller :139 is `new_job_application.errors.empty? && new_job_application.save`; the map says "save (line 139)" which is accurate.
- The blob re-attach is conditional on `has_resume` (:401); a clone of a resume-less application creates no TextractResult (SubmitResumeToTextract returns "No resume attached" at :10). The matrix's "Blob copy" cell implies a resume exists; this is the normal case and the map's Trigger 6/no-resume terminal logic covers the resume-less variant generally.

## Verdict
clean = true. Every T3 statement verified AGREE against literal code; no omissions.

## Record-write sites on the T3 path
- `job_application.rb:399` `job_application.clone_of_job_application_id = id` (in-memory dup attribute; persisted on controller save) — JobApplication.clone_of_job_application_id
- `job_application.rb:400` `job_application.created_via = 'created_via_clone'` — JobApplication.created_via
- `job_application.rb:401` `job_application.resume.attach(resume.blob) if has_resume` — ActiveStorage attachment
- controller `:139` `new_job_application.save` — JobApplication insert (fires after_commit/after_create)
- `submit_resume_to_textract.rb:19` `update_all(stale: true)` — no-op for clone (no summaries)
- `submit_resume_to_textract.rb:22/24` `textract_results.build(textract_job_status: 'in_progress')` saved — fresh TextractResult.textract_job_status (build+save)
- `find_or_create_ai_job_application_summary_status.rb:34` `@status_record.status = 'none'` saved at :37 — AiJobApplicationSummaryStatus.status (save, new row)
- `job_application.rb:435` `question_responses << new_question_response` (complete_cloning) — QuestionResponse copy (insert)
