# T7 Adversarial Review — Pass 7

**Slice:** T7 — External resume URL lazy attachment via `JobApplication::AttachExternalResumeUrlJob`. Verify whether Textract is/ is not triggered after lazy attachment. Trace to terminal.

**Candidate map under review:** `backend-flow-map-2026-06-17.md`, T7 section lines 108-122.

**Method:** Re-read all T7 code from scratch. Files opened and traced:
- `app/controllers/api/v1/job_applications_controller.rb:50-69, 105-116`
- `app/jobs/job_application/attach_external_resume_url_job.rb:1-18`
- `app/models/job_application.rb:94-98 (enum), 589-590 (has_resume), 641-657 (attach), 709-711 (should_attach)`
- `app/controllers/application_controller.rb:127-130 (id_or_hash_id)`
- `app/interactors/validate_ai_summary_generation.rb:20-79`
- `app/services/get_resume_text_from_textract.rb:15`
- `app/jobs/application_job.rb:1-5`
- `app/javascript/.../WebsocketGlobalChannelHandler.tsx:152-154`
- enqueue-site census via grep across `app/`, `lib/`

---

## Verdicts (each candidate-map T7 statement)

### Map line 109 — job class namespace `JobApplication::AttachExternalResumeUrlJob` at `attach_external_resume_url_job.rb:3`; controller enqueue uses fully-namespaced name at `job_applications_controller.rb:58`
**AGREE.** `attach_external_resume_url_job.rb:3` `class JobApplication::AttachExternalResumeUrlJob < ApplicationJob`. Controller `:58` `JobApplication::AttachExternalResumeUrlJob.perform_later(...)`.

### Map line 110 — `perform(job_application_id:, organization_user_id:)` at `:6`; `OrganizationUser.find(organization_user_id)` `:7` → `@organization_user.user` `:11`; controller supplies `current_organization_user.id`; if `OrganizationUser.find` raises, no broadcast
**AGREE.** `attach_external_resume_url_job.rb:6` signature exact. `:7` `@organization_user = OrganizationUser.find(organization_user_id)`. `:11` `GlobalChannel.broadcast_to(@organization_user.user, ...)`. Controller `:58` `organization_user_id: current_organization_user.id`. `:7` is before the body and the broadcast at `:11`; a raise there is caught by `rescue StandardError` `:13`, so no broadcast.

### Map line 111 — `attach_external_resume_url` at `job_application.rb:641-657`; `should_attach_external_resume_url?` at `709-711` (`external_resume_status_pending? && !has_resume`); enum `external_resume_status {pending:0,uploaded:1,error:2} _prefix:true` at `:94-98`
**AGREE.** Method body spans `:641-657` (def `:641`, closing `end` `:657`). `:709-711` `def should_attach_external_resume_url?` / `:710` `external_resume_status_pending? && !has_resume`. Enum `:94-98`, `_prefix: true` at `:98`.

### Map line 112 — `:error` terminal via `update_column(:external_resume_status, :error)` at `job_application.rb:651,654`
**AGREE.** `:651` (non-PDF content-type branch) and `:654` (rescue branch) both `update_column(:external_resume_status, :error)`.

### Map line 113 — `:uploaded` path: `if content_type == 'application/pdf'` → `resume.attach(io:..., filename: 'resume.pdf')` + `update_column(:external_resume_status, :uploaded)` at `:647-649`
**AGREE.** `:647` `if downloaded_resume.content_type == 'application/pdf'`; `:648` `resume.attach(io: downloaded_resume, filename: 'resume.pdf')`; `:649` `update_column(:external_resume_status, :uploaded)`.

### Map line 114 — Job broadcasts `attachExternalResumeComplete`; frontend handler only invalidates the `jobApplication` query (no Textract call) — `attach_external_resume_url_job.rb:11-12`, `WebsocketGlobalChannelHandler.tsx:152-154`
**AGREE.** Job `:11-12` `action: 'attachExternalResumeComplete', payload: { jobApplicationId: job_application_id }`. Handler `:152` `case "attachExternalResumeComplete":` `:153` `queryCache.invalidateQueries(["jobApplication", Number(data.payload.jobApplicationId)]);` `:154` `break;`. No Textract invocation in the handler.

### Map line 115 — Textract NOT triggered after lazy attachment (old gap CONFIRMED, not fixed); `update_column` bypasses callbacks; no submit enqueue site runs on the read/attach path
**AGREE.** `attach_external_resume_url` (`:641-657`) calls `resume.attach` + `update_column` only; it contains no `SubmitResumeToTextractJob` call. `update_column` is the ActiveRecord single-column writer that skips validations and callbacks (Rails framework boundary). The `enqueue_new_job_application` callback is `on: [:create]` and fired at insert (verified `job_application.rb:168` is the only model-callback submit site, inside the create-only `enqueue_new_job_application`). So after lazy attachment, no Textract job is enqueued by the attach path. **Direct answer to the slice question: Textract is NOT triggered by lazy attachment — the old map's gap remains real.**

### Map line 116 — `SubmitResumeToTextractJob.perform_later` has 6 app-code sites + 2 rake sites
**AGREE.** Grep across `app/` and `lib/` (excluding specs) yields exactly six app sites: `job_application.rb:168`, `validate_ai_summary_generation.rb:39`, `validate_ai_summary_generation.rb:55`, `queue_bulk_ai_summary_jobs.rb:29`, `job_applications_controller.rb:114`, `get_resume_text_from_textract.rb:15`. Plus two rake sites: `lib/tasks/housekeeping_tasks.rake:409` and `:445`. Matches exactly.

### Map line 117 — for a freshly `:uploaded` no-TextractResult row, the manual-generate re-entry is `validate_ai_summary_generation.rb:38-39` (`unless @latest_textract_result` → submit), gated by `has_resume?` at `:27` (now true post-upload); `:55` is for the latest-failed-with-non-failed-prior case
**AGREE.** `:27` `context.fail!(...) unless has_resume?`; `has_resume?` `:69-71` returns `@job_application.has_resume`, which is true after `:uploaded` (real PDF blob attached at `:648`). `:31` `@latest_textract_result = @job_application.latest_textract_result` (nil for the no-TextractResult row). `:38-39` `unless @latest_textract_result` → `SubmitResumeToTextractJob.perform_later(@job_application.id)`. `:46` `elsif @latest_textract_result.textract_job_status_failed?` then `:52-53` both-failed fail / `:55` resubmit — the `:55` precondition requires a present latest failed result, distinct. Confirmed.

### Map line 118 — resting `:uploaded`: `has_resume == true`, but `external_resume_status` no longer `pending`, so a later `show` won't re-enqueue (needs `external_resume_status_pending?`, `:710`); nothing on read path re-submits Textract
**AGREE.** Post-upload `external_resume_status == :uploaded` (value 1, `:96`), so `external_resume_status_pending?` is false; `should_attach_external_resume_url?` `:710` short-circuits false. Controller `:59` enqueue is gated on `should_attach_external_resume_url?` so no re-enqueue. Read path contains no Textract submit.

### Map line 119 — resting `:error` is a no-retry resting state; `should_attach_external_resume_url?` requires `pending`, so a later `show` won't retry; no actor re-attempts
**AGREE.** `:error` (value 2) likewise fails `external_resume_status_pending?` at `:710`; controller `:59` won't re-enqueue. No `retry_on` (see next).

### Map line 120 — job wraps body in `rescue StandardError => e` that only `ap`s (`:13-16`); no `retry_on` (`ApplicationJob` empty); if `OrganizationUser.find`/`JobApplication.find` raises, no retry and no `attachExternalResumeComplete` broadcast → perpetual pending UI
**AGREE.** `attach_external_resume_url_job.rb:13` `rescue StandardError => e`, `:14` `ap 'Attach External Resume Url Error'`, `:15` `ap e`. `app/job_application/attach_external_resume_url_job.rb` declares no `retry_on`; `application_job.rb:1-5` is empty (`class ApplicationJob < ActiveJob::Base; end`). A raise at `:7` or `:8` precedes the `:11` broadcast → caught at `:13`, no broadcast, no retry. Confirmed.

### Map line 121 — `should_attach_external_resume_url?` checked twice (enqueue `job_applications_controller.rb:59`, and inside `attach_external_resume_url` `job_application.rb:642`); a stale enqueue is a safe no-op
**AGREE.** Controller `:59` `... if @job_application.should_attach_external_resume_url?`. Method `:642` `return unless should_attach_external_resume_url?`. Double-guard confirmed; second guard makes a stale enqueue a no-op.

### Map line 122 — controller forwards UNRESOLVED `params[:id]`: record found via `find_by(id_or_hash_id(params[:id]))` `:56`, but enqueues `job_application_id: params[:id]` (raw) `:58-59`; job calls `JobApplication.find(job_application_id)` `:8`; `find` resolves by PK only, so a `hash_id` param raises `RecordNotFound`, caught by `rescue StandardError` `:13` → silent perpetual pending
**AGREE.** Controller `:56` `find_by(id_or_hash_id(params[:id]))`; `id_or_hash_id` (`application_controller.rb:127-130`) returns `{ id: ... }` for numeric, `{ hash_id: ... }` otherwise. Controller `:59` `job_application_id: params[:id]` (raw param, not `@job_application.id`). Job `:8` `JobApplication.find(job_application_id)`. `JobApplication` defines no `self.find` override and no friendly_id (grep clean), so `find` is the stock PK finder; a non-numeric `hash_id` string raises `ActiveRecord::RecordNotFound`, caught at job `:13`. Confirmed real hazard.

---

## Omissions

None material to the T7 slice. Every load-bearing fact (Textract-not-triggered terminal, both resting states, the rescue/no-retry perpetual-pending failure mode, the unresolved-param hazard, the re-entry route via `validate_ai_summary_generation.rb:39`, the double-guard, the broadcast/frontend behavior, the full enqueue-site census) is present and line-accurate. The candidate map's T7 section is notably thorough; pass-3/4/6 corrections already folded in the items earlier passes missed.

One very minor, non-load-bearing note (NOT counted as an omission against clean, since it does not change any T7 behavior or terminal): `attach_external_resume_url` logs via `Rails.logger.error e` (`job_application.rb:655`) inside its own model-level rescue (`:653-656`) BEFORE the job-level rescue would ever see an error from the download/content-type branch — i.e. a download/non-PDF failure is swallowed at the model level and lands the record at `:error` (a clean resting state), and does NOT propagate to the job's `rescue` or prevent the `attachExternalResumeComplete` broadcast at job `:11`. The map's "perpetual pending" failure mode (line 120/122) is therefore specifically the `OrganizationUser.find`/`JobApplication.find` raise BEFORE `:11`, which the map already states correctly. This is a clarification consistent with the map, not a contradiction.

---

## Conclusion

All 14 candidate-map T7 statements AGREE against current code. No omissions. **clean = true.**
