# T7 Adversarial Review — Pass 5

Slice: T7 — External resume URL lazy attachment via `JobApplication::AttachExternalResumeUrlJob`. Verify whether Textract is/is not triggered after lazy attachment; trace to terminal.

Re-audited from scratch against current code. Files opened:
- `app/jobs/job_application/attach_external_resume_url_job.rb`
- `app/controllers/api/v1/job_applications_controller.rb:50-119`
- `app/models/job_application.rb:44-46, 94-98, 160-171, 589-657, 685-711`
- `app/interactors/validate_ai_summary_generation.rb` (full)
- `app/jobs/application_job.rb`
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx:150-154`
- `lib/tasks/housekeeping_tasks.rake` (grep for SubmitResumeToTextract)

Chain: `job_applications_controller.rb:58` -> `attach_external_resume_url_job.rb:6-16` -> `job_application.rb:641-657` (`attach_external_resume_url`) -> `job_application.rb:709-711` (`should_attach_external_resume_url?`) -> `job_application.rb:94-98` (enum) -> `WebsocketGlobalChannelHandler.tsx:152-154`.

## Verdicts on candidate-map T7 statements (lines 88-101)

1. **Job class namespace `JobApplication::AttachExternalResumeUrlJob`, controller uses fully-namespaced name** — AGREE. `attach_external_resume_url_job.rb:3` `class JobApplication::AttachExternalResumeUrlJob < ApplicationJob`; `job_applications_controller.rb:58` `JobApplication::AttachExternalResumeUrlJob.perform_later(...)`.

2. **`perform(job_application_id:, organization_user_id:)`; broadcast target via `OrganizationUser.find(organization_user_id)` (:7) -> `@organization_user.user` (:11); controller supplies `current_organization_user.id`** — AGREE. `attach_external_resume_url_job.rb:6` signature; `:7` `@organization_user = OrganizationUser.find(organization_user_id)`; `:11` `GlobalChannel.broadcast_to(@organization_user.user, ...)`; `job_applications_controller.rb:58` `organization_user_id: current_organization_user.id`.

3. **`attach_external_resume_url` at `job_application.rb:641-657`; `should_attach_external_resume_url?` at 709-711 (`external_resume_status_pending? && !has_resume`); enum `{pending:0,uploaded:1,error:2} _prefix:true` at :94-98** — AGREE. Method body 641-657; predicate `:709-711` literal `external_resume_status_pending? && !has_resume`; enum `:94-98`.

4. **`:error` terminals via `update_column(:external_resume_status, :error)` (`:651,654`)** — AGREE. `:651` (non-PDF content type), `:654` (rescued StandardError).

5. **`:uploaded` path: `if content_type == 'application/pdf'` -> `resume.attach(io:..., filename: 'resume.pdf')` + `update_column(:external_resume_status, :uploaded)` (`:647-649`)** — AGREE. `:647` `if downloaded_resume.content_type == 'application/pdf'`; `:648` attach; `:649` `update_column(:external_resume_status, :uploaded)`.

6. **Job broadcasts `attachExternalResumeComplete`; frontend handler only invalidates `jobApplication` query, no Textract call (`attach_external_resume_url_job.rb:11-12`, `WebsocketGlobalChannelHandler.tsx:152-154`)** — AGREE. Job `:11-12` action `'attachExternalResumeComplete'`; handler `:152-153` `queryCache.invalidateQueries(["jobApplication", Number(data.payload.jobApplicationId)])`; no Textract enqueue/call in handler.

7. **Textract is NOT triggered after lazy attachment; `update_column` (`:649/651/654`) bypasses callbacks; none of the SubmitResumeToTextractJob enqueue sites runs on the read path** — AGREE. `update_column` is the ActiveRecord skip-callbacks/validations writer (framework boundary). The attach body (641-657) calls no Submit enqueuer. The only create-path enqueuer is `enqueue_new_job_application` registered `on: [:create]` (`job_application.rb:45`), which fired at insert before the resume existed; the read path (`show`) only enqueues `AttachExternalResumeUrlJob`, which never calls Submit. CONFIRMED gap.

8. **6 app-code SubmitResumeToTextractJob enqueue sites + 2 rake sites** — AGREE. grep yields exactly: `job_application.rb:168`, `validate_ai_summary_generation.rb:39`, `validate_ai_summary_generation.rb:55`, `queue_bulk_ai_summary_jobs.rb:29`, `job_applications_controller.rb:114`, `get_resume_text_from_textract.rb:15`; rake `housekeeping_tasks.rake:409` and `:445`.

9. **Most-direct Textract re-entry for `:uploaded` no-TextractResult row is `validate_ai_summary_generation.rb:38-39`, gated by `has_resume?` at :27; `:55` requires a failed latest TextractResult with non-failed/absent prior** — AGREE. `:27` `context.fail!(...) unless has_resume?`; `:38` `unless @latest_textract_result`; `:39` Submit enqueue. `:46` `elsif @latest_textract_result.textract_job_status_failed?` then `:52` `if previous_textract_result&.textract_job_status_failed?` else `:55` Submit. Distinct preconditions confirmed.

10. **Resting `:uploaded`: `has_resume == true`, status no longer `pending`, later `show` won't re-enqueue (`should_attach_external_resume_url?` needs `external_resume_status_pending?`, `:710`); nothing on read path re-submits Textract** — AGREE. `:710` predicate requires `external_resume_status_pending?`; after `:649` status is `uploaded`, so predicate false.

11. **Resting `:error`: no-retry; `should_attach_external_resume_url?` requires `pending`, so later `show` won't retry; no actor re-attempts** — AGREE. Same predicate `:710`; `error` != `pending`.

12. **Job rescue: whole body wrapped in `rescue StandardError => e` that only `ap`s (`:13-16`); no `retry_on` (`ApplicationJob` empty). If `OrganizationUser.find`/`JobApplication.find` raises or model method raises before its own rescue, no retry, no broadcast -> perpetual pending UI** — AGREE. `attach_external_resume_url_job.rb:13-16` rescue only `ap`s; `application_job.rb:1-5` is empty (no `retry_on`). Note: `attach_external_resume_url`'s own inner `rescue` (`:653-655`) converts download/attach errors to `:error` status, so a model-level failure flips to `:error` and the broadcast at `:11` still fires; the perpetual-pending mode requires a raise OUTSIDE that inner rescue — specifically `OrganizationUser.find` (`:7`) or `JobApplication.find` (`:8`) raising RecordNotFound BEFORE `:9`. Map's phrasing ("before its own rescue") is consistent with this.

13. **NOTE: `should_attach_external_resume_url?` checked twice — at enqueue (`job_applications_controller.rb:59`) and inside `attach_external_resume_url` (`job_application.rb:642`); stale enqueue is a safe no-op** — AGREE. Controller `:59` `... if @job_application.should_attach_external_resume_url?`; method `:642` `return unless should_attach_external_resume_url?`.

## Omissions

None material. The T7 section traces the path to all three terminals (`:uploaded`, `:error`, perpetual-pending-on-find-raise), correctly states Textract is NOT triggered, and gives the re-entry route. Minor observations that do not contradict the map:
- `attach_external_resume_url` downloads via `URI.open(external_resume_url)` (`job_application.rb:645`, open-uri / Kernel#open framework boundary). The map describes the download but does not name `URI.open`; not load-bearing for the slice conclusion.
- `has_resume` (`job_application.rb:589-602`) has a side effect: an attached-but-non-DOCUMENT_CONTENT_TYPES resume is purged and returns false. Not reachable on the `:uploaded` happy path (attached blob is `application/pdf`), so it does not affect the T7 terminal. Not an omission worth flagging.

## Conclusion

Every T7 map statement verified AGREE against literal current code. The central question — is Textract triggered after lazy attachment? — is answered: NO. `update_column` bypasses the `after_commit` callbacks, and no enqueuer runs on the read/attach path. The old map's gap is CONFIRMED (still present), not fixed.

clean = true
