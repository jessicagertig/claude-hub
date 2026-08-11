# T7 — Adversarial Re-Audit (Pass 2)

**Slice:** External resume URL lazy attachment via `JobApplication::AttachExternalResumeUrlJob`. Question: is Textract triggered after lazy attachment? (Old map flagged a gap.)

**Method:** Re-read from scratch. Files opened and traced:
- `app/controllers/api/v1/job_applications_controller.rb:46-69` (`def show`) and `:114`
- `app/jobs/job_application/attach_external_resume_url_job.rb:1-18`
- `app/models/job_application.rb:45-46` (commit callbacks), `:94-98` (enum), `:164-171` (`enqueue_new_job_application`), `:641-657` (`attach_external_resume_url`), `:709-711` (`should_attach_external_resume_url?`)
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx:148-154`
- Global grep for `SubmitResumeToTextractJob` enqueuers.

Trace chain: `job_applications_controller.rb:58 (show)` -> `attach_external_resume_url_job.rb:9` -> `job_application.rb:642 (attach_external_resume_url)` -> `job_application.rb:649/651/654 (update_column)` [TERMINAL]; broadcast `attach_external_resume_url_job.rb:11` -> `WebsocketGlobalChannelHandler.tsx:152-153 (invalidate jobApplication query)` [TERMINAL].

---

## Verdicts on map statements

### 1. `attach_external_resume_url` line range = `job_application.rb:641-657`
AGREE. `def attach_external_resume_url` at `job_application.rb:641`, method ends `:657`.

### 2. `should_attach_external_resume_url?` at `709-711`: `external_resume_status_pending? && !has_resume`
AGREE. `job_application.rb:709-711`: `def should_attach_external_resume_url?` / `external_resume_status_pending? && !has_resume` / `end`. Enum `external_resume_status {pending:0, uploaded:1, error:2} _prefix:true` at `:94-98`, so `external_resume_status_pending?` is the generated predicate.

### 3. `:error` terminal outcomes (non-PDF content type, or rescued StandardError) via `update_column(:external_resume_status, :error)` at `651,654`
AGREE. `job_application.rb:651` `update_column(:external_resume_status, :error)` (non-`application/pdf` else branch); `:654` `update_column(:external_resume_status, :error)` (StandardError rescue). Old map documented only `:uploaded` — the `:error` outcomes are correctly captured as NEW.

### 4. `:uploaded` path via `update_column` at `648-649`
AGREE. `:647` `if downloaded_resume.content_type == 'application/pdf'`; `:648` `resume.attach(io: downloaded_resume, filename: 'resume.pdf')`; `:649` `update_column(:external_resume_status, :uploaded)`.

### 5. Job broadcasts `attachExternalResumeComplete`; frontend handler only invalidates the `jobApplication` query (no Textract call)
AGREE. `attach_external_resume_url_job.rb:11-12` `GlobalChannel.broadcast_to(@organization_user.user, action: 'attachExternalResumeComplete', payload: { jobApplicationId: job_application_id })`. `WebsocketGlobalChannelHandler.tsx:152-154`: `case "attachExternalResumeComplete":` -> `queryCache.invalidateQueries(["jobApplication", Number(data.payload.jobApplicationId)]); break;`. Single query invalidation, no Textract/AI call.

### 6. Textract is NOT triggered after lazy attachment (old map gap CONFIRMED, not fixed). `update_column` bypasses callbacks.
AGREE. `attach_external_resume_url` writes `external_resume_status` exclusively via `update_column` (`:649/651/654`); `resume.attach` (`:648`) is an ActiveStorage attachment, not a `SubmitResumeToTextractJob` enqueue. `update_column` skips validations and callbacks, so no `after_*` callback fires. Global grep confirms zero `SubmitResumeToTextractJob.perform_later` call anywhere in `attach_external_resume_url`, `AttachExternalResumeUrlJob`, or the `show` action after attach. Terminal state: `external_resume_status = uploaded|error`, a resume blob present (on the PDF path) but NO TextractResult, NO poll job, NO advancing actor. Dead end re: Textract — CONFIRMED gap, not fixed.

### 7. Chain "Controller `show` → AttachExternalResumeUrlJob → attach_external_resume_url"
AGREE. `def show` at `job_applications_controller.rb:46`; `:58-59` `JobApplication::AttachExternalResumeUrlJob.perform_later(organization_user_id: current_organization_user.id, job_application_id: params[:id]) if @job_application.should_attach_external_resume_url?`. Enqueued from the read endpoint (lazy), gated on `should_attach_external_resume_url?`.

---

## DISPUTE / imprecision

### D1. Map line 60: "only enqueuer of `SubmitResumeToTextractJob` is `enqueue_new_job_application` (create-only)."
DISPUTE (imprecise as written; conclusion still holds). `SubmitResumeToTextractJob.perform_later` has FIVE enqueue sites in app code, not one:
- `job_application.rb:168` (`enqueue_new_job_application`, `after_commit on: [:create]`)
- `validate_ai_summary_generation.rb:39` and `:55` (manual AI-summary gen, no-textract and current-failed paths)
- `queue_bulk_ai_summary_jobs.rb:29` (bulk backfill)
- `job_applications_controller.rb:114` (manual resume replacement update action)
- `get_resume_text_from_textract.rb:15` (self-heal on nil `textract_job_id`)

The map's claim is only true if scoped to "enqueuers reachable from a `JobApplication` model commit callback" — and even then it is the create-only callback. The substantive T7 point (none of these five fire from `attach_external_resume_url`'s `update_column` writes, because the attach path never invokes any of them and bypasses callbacks) is CORRECT. But the literal sentence "only enqueuer of `SubmitResumeToTextractJob` is `enqueue_new_job_application`" overstates and is false at face value. Correction: "After lazy attachment, no enqueuer of `SubmitResumeToTextractJob` runs — the attach path uses `update_column` (no callbacks) and never calls a submit enqueuer. The create-only `enqueue_new_job_application` (`job_application.rb:45,168`) already fired at insert time, before any resume existed (CSV/import rows that defer to external URL had `has_resume` false then), so it produced no TextractResult. There are five enqueue sites globally; none is on the lazy-attach path."

---

## Omissions

- **O1 — No re-submit even though a resume now exists.** The map states Textract isn't triggered but does not spell out the consequence specific to this slice: after `:uploaded`, the job_application now `has_resume == true` with a real PDF blob, yet `external_resume_status` is no longer `pending`, so a subsequent `show` will NOT re-enqueue `AttachExternalResumeUrlJob` (`should_attach_external_resume_url?` requires `external_resume_status_pending?`, `:710`), and nothing else re-submits Textract for this now-resume-bearing record on the read path. The only way this record ever reaches Textract is a separate trigger (manual AI-summary gen `validate_ai_summary_generation.rb:39`, bulk backfill `queue_bulk_ai_summary_jobs.rb:29`, or manual resume replacement `job_applications_controller.rb:114`). The lazy-attach path itself terminates with a resume present and zero Textract scheduling.

- **O2 — `:error` terminal also has no retry/advancing actor.** On the non-PDF or StandardError branch the record rests at `external_resume_status = error` (`:651/654`). `should_attach_external_resume_url?` requires `pending`, so a later `show` will not retry. No actor re-attempts the external URL download. Dead end for the attachment itself (independent of Textract). The map lists the `:error` outcome as NEW but does not flag it as a no-retry resting state.

- **O3 — Job-level rescue swallows errors silently.** `AttachExternalResumeUrlJob#perform` wraps the whole body in `rescue StandardError => e` that only `ap`s (`attach_external_resume_url_job.rb:13-16`). If `JobApplication.find`/`OrganizationUser.find` raises, or the model method raises before its own rescue, the job neither retries (no `retry_on`) nor broadcasts `attachExternalResumeComplete`; the frontend never invalidates and the UI shows a perpetual pending state. Not in the map.

- **O4 — Enqueue guard duplication.** `should_attach_external_resume_url?` is checked twice: once at enqueue (`job_applications_controller.rb:59`) and again inside `attach_external_resume_url` (`job_application.rb:642` `return unless should_attach_external_resume_url?`). Benign defensive double-check; worth a one-line note since it means a stale enqueue (status changed between enqueue and run) is a safe no-op.

---

## clean = false
Reason: D1 (imprecise/false-at-face-value map statement) plus non-empty omissions O1-O4.
