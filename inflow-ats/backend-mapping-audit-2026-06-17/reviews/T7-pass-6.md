# T7 Adversarial Review — Pass 6

**Slice:** T7 — External resume URL lazy attachment via `JobApplication::AttachExternalResumeUrlJob`. Verify whether Textract is triggered after lazy attachment.

**Method:** Re-read all code from scratch. Files traced:
`app/jobs/job_application/attach_external_resume_url_job.rb` → `app/models/job_application.rb:641-657` (`attach_external_resume_url`), `:709-711` (`should_attach_external_resume_url?`), `:94-98` (enum), `:589-590` (`has_resume`), `:45/:164-171` (`enqueue_new_job_application`) → `app/controllers/api/v1/job_applications_controller.rb:56-59` (enqueue) → `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx:152-154` (frontend handler) → `app/jobs/application_job.rb` (no retry_on) → enqueue-site census across `app/`, `lib/` for `SubmitResumeToTextractJob.perform_later`.

## Verdicts (map T7 section, lines 99-112)

1. **AGREE** — Namespaced job class `JobApplication::AttachExternalResumeUrlJob` at `attach_external_resume_url_job.rb:3`; controller enqueue fully namespaced at `job_applications_controller.rb:58`.

2. **AGREE** — `perform(job_application_id:, organization_user_id:)` at `attach_external_resume_url_job.rb:6`; `OrganizationUser.find(organization_user_id)` at `:7` → `@organization_user.user` at `:11`; controller supplies `current_organization_user.id` at `job_applications_controller.rb:58`. If `OrganizationUser.find` (:7) raises, broadcast (:11) never reached. Confirmed.

3. **AGREE** — `attach_external_resume_url` at `job_application.rb:641-657`; `should_attach_external_resume_url?` at `:709-711` = `external_resume_status_pending? && !has_resume` (`:710`). Enum `{pending:0,uploaded:1,error:2} _prefix:true` at `:94-98`.

4. **AGREE** — `:error` terminals: non-PDF content type → `update_column(:external_resume_status, :error)` at `:651`; rescued `StandardError` → `update_column(:external_resume_status, :error)` at `:654`.

5. **AGREE** — `:uploaded` path: `if downloaded_resume.content_type == 'application/pdf'` (`:647`) → `resume.attach(io: downloaded_resume, filename: 'resume.pdf')` (`:648`) + `update_column(:external_resume_status, :uploaded)` (`:649`).

6. **AGREE** — Broadcast `attachExternalResumeComplete` at `attach_external_resume_url_job.rb:11-12`; frontend handler at `WebsocketGlobalChannelHandler.tsx:152-154` invalidates only `["jobApplication", Number(data.payload.jobApplicationId)]` (`:153`), no Textract call. (Map cites the file without path; the live file is `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx`; the other copy under `app/javascript/shared/websockets/` has no `attachExternalResumeComplete` case.)

7. **AGREE (core gap claim)** — Textract NOT triggered after lazy attachment. `update_column` at `:649/:651/:654` bypasses callbacks (Rails framework). The attach path calls no `SubmitResumeToTextractJob` enqueuer. The create-only `enqueue_new_job_application` (`job_application.rb:45`, `on: [:create]`; submit at `:168`) fired at insert before any resume existed. Old map gap CONFIRMED-not-fixed.

8. **AGREE** — 6 app-code `SubmitResumeToTextractJob.perform_later` sites: `job_application.rb:168`, `validate_ai_summary_generation.rb:39`, `validate_ai_summary_generation.rb:55`, `queue_bulk_ai_summary_jobs.rb:29`, `job_applications_controller.rb:114`, `get_resume_text_from_textract.rb:15`. Plus 2 rake sites: `lib/tasks/housekeeping_tasks.rake:409`, `:445`. Census matches exactly.

9. **AGREE** — Direct Textract re-entry for `:uploaded`-but-no-TextractResult row is `validate_ai_summary_generation.rb:38-39` (`unless @latest_textract_result` → submit), gated by `has_resume?` at `:27` (true post-upload). `:55` fires only when latest TextractResult exists and is `textract_job_status_failed?` with non-failed/absent prior (`:46-57`) — different precondition. Confirmed.

10. **AGREE** — Resting `:uploaded`: `has_resume == true`, `external_resume_status` no longer `pending`, so `should_attach_external_resume_url?` (`:710`) false → later `show` won't re-enqueue; no read-path Textract resubmit.

11. **AGREE** — Resting `:error`: `should_attach_external_resume_url?` requires `pending` (`:710`); `:error` won't retry; no actor re-attempts.

12. **AGREE** — Job rescue: `rescue StandardError => e` only `ap`s (`attach_external_resume_url_job.rb:13-16`); `ApplicationJob` empty, no `retry_on` (`application_job.rb`). No retry, no broadcast on raise → perpetual pending UI.

13. **AGREE** — `should_attach_external_resume_url?` checked twice: enqueue (`job_applications_controller.rb:59`) and inside `attach_external_resume_url` (`job_application.rb:642`). Stale enqueue is a safe no-op.

## Omissions

- **Controller passes `params[:id]`, not the resolved record id.** The enqueue at `job_applications_controller.rb:58-59` passes `job_application_id: params[:id]` (the raw URL param, which may be a hash_id — the finder at `:56` uses `id_or_hash_id(params[:id])`). The job then calls `JobApplication.find(job_application_id)` at `attach_external_resume_url_job.rb:8` with that raw param. If `params[:id]` is a hash_id rather than a numeric id, `JobApplication.find` would raise `RecordNotFound` (caught by the job's `rescue` at :13), so the attach never runs. The map narrates the param signature (line 101) but does not note that the controller forwards the unresolved `params[:id]` while the record was located via `id_or_hash_id`. This is a real divergence surface on the T7 slice.

- **Broadcast target is `@organization_user.user`, not the OrganizationUser.** `GlobalChannel.broadcast_to(@organization_user.user, ...)` at `attach_external_resume_url_job.rb:11`. The map line 101 says "`@organization_user.user` (`:11`)" — actually present, so this is covered. (No omission.)

## Conclusion

clean = false (one substantive omission: controller forwards unresolved `params[:id]` to `JobApplication.find`). All 13 T7 map statements AGREE against literal code.
