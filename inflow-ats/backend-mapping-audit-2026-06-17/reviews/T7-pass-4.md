# T7 Adversarial Review — Pass 4

**Slice:** T7 — External resume URL lazy attachment via `JobApplication::AttachExternalResumeUrlJob`. Verify whether Textract is triggered after lazy attachment.

**Candidate map under refutation:** `backend-flow-map-2026-06-17.md` (T7 section, lines 79-89; cross-refs at 75, 85).

**Method:** Re-read code from scratch. Files traced:
`app/controllers/api/v1/job_applications_controller.rb:56-59` (show → enqueue) → `app/jobs/job_application/attach_external_resume_url_job.rb:1-18` → `app/models/job_application.rb:641-657` (`attach_external_resume_url`), `:709-711` (`should_attach_external_resume_url?`), `:94-98` (enum), `:45-48` (callbacks), `:164-171` (`enqueue_new_job_application`), `:173-184` (`track_movement`) → `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx:152-154` → `app/interactors/validate_ai_summary_generation.rb:25-60` → `app/jobs/application_job.rb:1-4`. Enqueue-site census via grep over `app/` + `lib/`.

---

## Verdicts

### Map line 80 — `attach_external_resume_url` line range `641-657`; `should_attach_external_resume_url?` at `709-711` (`external_resume_status_pending? && !has_resume`); enum `{pending:0,uploaded:1,error:2} _prefix:true` at `:94-98`
**AGREE.** `job_application.rb:641` `def attach_external_resume_url`, ends `:657`. `:709-711` `def should_attach_external_resume_url? / external_resume_status_pending? && !has_resume`. Enum `:94-98` `enum external_resume_status: { pending:0, uploaded:1, error:2 }, _prefix: true`.

### Map line 81 — `:error` terminal via `update_column(:external_resume_status, :error)` at `:651,654`
**AGREE.** `job_application.rb:651` `update_column(:external_resume_status, :error)` (non-PDF else); `:654` `update_column(:external_resume_status, :error)` (rescue StandardError, `:653`).

### Map line 82 — `:uploaded` path: `if content_type == 'application/pdf'` → `resume.attach(...)` + `update_column(:uploaded)` at `:647-649`
**AGREE.** `:647` `if downloaded_resume.content_type == 'application/pdf'`, `:648` `resume.attach(io: downloaded_resume, filename: 'resume.pdf')`, `:649` `update_column(:external_resume_status, :uploaded)`.

### Map line 83 — Job broadcasts `attachExternalResumeComplete`; FE handler only invalidates `jobApplication` query (no Textract) — `attach_external_resume_url_job.rb:11-12`, `WebsocketGlobalChannelHandler.tsx:152-154`
**AGREE.** Job `:11-12` `GlobalChannel.broadcast_to(@organization_user.user, action: 'attachExternalResumeComplete', payload: { jobApplicationId: job_application_id })`. FE `:152-154` `case "attachExternalResumeComplete": queryCache.invalidateQueries(["jobApplication", Number(data.payload.jobApplicationId)]); break;` — no Textract call, only the single-jobApplication query invalidation.

### Map line 84 — Textract NOT triggered after lazy attachment; `update_column` bypasses callbacks; the create-only `enqueue_new_job_application` (`:45,168`) fired at insert before any resume existed
**AGREE.** `attach_external_resume_url` writes only via `update_column` (`:649/651/654`), which bypasses all AR callbacks. The sole Textract-submitting callback on the model is `after_commit :enqueue_new_job_application, on: [:create]` (`job_application.rb:45`; body submits at `:168` gated on `TEXTRACT_RESUME_PROCESSING`). The other update callback `after_commit :track_movement, on: [:update]` (`:46`, body `:173-184`) handles only job/stage moves — no Textract — and would not fire under `update_column` anyway. No submit enqueuer is called on the attach path. Central T7 conclusion holds.

### Map line 85 — `SubmitResumeToTextractJob.perform_later` has 6 app sites + 2 rake sites
**AGREE.** grep over `app/` + `lib/` yields exactly: `job_application.rb:168`, `validate_ai_summary_generation.rb:39`, `validate_ai_summary_generation.rb:55`, `queue_bulk_ai_summary_jobs.rb:29`, `job_applications_controller.rb:114`, `get_resume_text_from_textract.rb:15` (6 app), plus `lib/tasks/housekeeping_tasks.rake:409` and `:445` (2 rake; remaining rake hits at `:503/507/515/517` are counting/logging, not enqueues). None run on the read/attach path. Enumeration confirmed.

### Map line 86 — Resting `:uploaded`: `has_resume == true`, no longer pending → later `show` won't re-enqueue (`:710`); nothing on read path re-submits Textract
**AGREE.** After `:uploaded`, `external_resume_status_pending?` is false → `should_attach_external_resume_url?` (`:710`) false → controller `show` guard (`:59`) and method guard (`:642`) both no-op. No read-path Textract re-submit.

### Map line 87 — Resting `:error`: also no-retry; `should_attach_external_resume_url?` requires `pending` so a later show won't retry
**AGREE.** `:error` is not `pending` → `should_attach_external_resume_url?` (`:710`) false → no retry on subsequent `show`. No actor re-attempts.

### Map line 88 — Job wraps body in `rescue StandardError` that only `ap`s (`:13-16`); no `retry_on`; if `find` raises or model method raises before its own rescue, job neither retries nor broadcasts
**AGREE.** `attach_external_resume_url_job.rb:13-16` `rescue StandardError => e / ap 'Attach External Resume Url Error' / ap e`. No `retry_on`/`discard_on` on the job or on `ApplicationJob` (`application_job.rb:1-4` is empty). The two `.find` calls (`:7` `OrganizationUser.find`, `:8` `JobApplication.find`) and the model call (`:9`) precede the broadcast (`:11`); any raise routes to the swallow-only rescue, skipping the broadcast → frontend never invalidates → perpetual pending UI.

### Map line 89 (NOTE) — `should_attach_external_resume_url?` checked twice: enqueue (`job_applications_controller.rb:59`) and inside `attach_external_resume_url` (`:642`); stale enqueue is a safe no-op
**AGREE.** Controller `:59` `... if @job_application.should_attach_external_resume_url?`; method `:642` `return unless should_attach_external_resume_url?`. Double-guard confirmed; method-level guard makes a stale enqueue a no-op.

### Map line 75 (T6 cross-ref) — later `show` (`job_applications_controller.rb:58-59`) enqueues the job → `attach_external_resume_url` (`:641-657`) → `update_column(:uploaded)` (`:649`); `update_column` bypasses callbacks so Textract STILL never triggered
**AGREE.** Show action `:56` finds the job_application, `:58-59` enqueues `JobApplication::AttachExternalResumeUrlJob` guarded on `should_attach_external_resume_url?`. Path confirmed; Textract-not-triggered conclusion holds.

---

## Omissions

1. **Job class namespace.** The map labels the file/class `attach_external_resume_url_job.rb` / `AttachExternalResumeUrlJob` throughout (lines 75, 83, 88). The actual class is `JobApplication::AttachExternalResumeUrlJob` and the file lives at `app/jobs/job_application/attach_external_resume_url_job.rb`. The controller enqueue at `job_applications_controller.rb:58` uses the fully namespaced `JobApplication::AttachExternalResumeUrlJob`. Per the no-paraphrase rule the map should use the real namespaced identifier.

2. **Job parameter signature.** The map does not state the job's keyword signature: `perform(job_application_id:, organization_user_id:)` (`:6`). The `organization_user_id` resolves the broadcast target via `OrganizationUser.find(organization_user_id)` (`:7`) → `@organization_user.user` (`:11`); the controller supplies `organization_user_id: current_organization_user.id` (`:58`). This is the data that determines WHO receives `attachExternalResumeComplete` and is load-bearing for the "frontend never invalidates" failure mode (line 88) — if `OrganizationUser.find` raises, no broadcast.

3. **Most-direct Textract re-entry route for an uploaded-no-textract row.** Map line 85 calls out `validate_ai_summary_generation.rb:55` and the two rake sites as "routes that can reach Textract for an already-`:uploaded` imported row." For a freshly `:uploaded` row that has NO TextractResult at all, the reaching branch is actually `validate_ai_summary_generation.rb:38-39` (`unless @latest_textract_result → SubmitResumeToTextractJob.perform_later`), gated by the `has_resume?` check passing at `:27` (now true post-upload). Line 55 fires only when the latest TextractResult exists and is `textract_job_status_failed?` with a non-failed/absent prior — a different precondition. Line 39 is in the map's enumerated 6-site list, but the map's prose attributes the uploaded-row re-entry specifically to `:55`+rake, omitting the more direct `:39` route.

---

**clean = false** (all verdicts AGREE, but omissions are non-empty).
