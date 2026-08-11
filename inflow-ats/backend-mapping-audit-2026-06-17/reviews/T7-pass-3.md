# T7 — Adversarial Review (Pass 3)

Slice: External resume URL lazy attachment via `AttachExternalResumeUrlJob`. Question: is Textract triggered now? (old map flagged a gap)

Code re-read from scratch. Chain followed:
`job_applications_controller.rb:56-60` → `job_application.rb:709-711 should_attach_external_resume_url?` → `attach_external_resume_url_job.rb:6-16` → `job_application.rb:641-657 attach_external_resume_url` → `job_application.rb:589-602 has_resume` → enum `job_application.rb:94-98` → `job_application.rb:164-171 enqueue_new_job_application` (after_commit on :create, `:45`) → `submit_resume_to_textract_job.rb` → frontend `WebsocketGlobalChannelHandler.tsx:152-154`.

## Verdicts

1. AGREE — Trigger chain. Controller `show` enqueues `AttachExternalResumeUrlJob.perform_later` guarded by `should_attach_external_resume_url?` (`job_applications_controller.rb:58-59`). Job calls `@job_application.attach_external_resume_url` (`attach_external_resume_url_job.rb:9`).

2. AGREE — Line ranges. `attach_external_resume_url` at `job_application.rb:641-657`; `should_attach_external_resume_url?` at `709-711` = `external_resume_status_pending? && !has_resume`; enum `external_resume_status {pending:0,uploaded:1,error:2} _prefix:true` at `:94-98`.

3. AGREE — `:uploaded` path: `if downloaded_resume.content_type == 'application/pdf'` → `resume.attach(io:..., filename:'resume.pdf')` + `update_column(:external_resume_status, :uploaded)` (`:647-649`).

4. AGREE — `:error` terminals: non-PDF content type (`:651`) and rescued `StandardError` (`:654`), both `update_column(:external_resume_status, :error)`.

5. AGREE — Textract NOT triggered after lazy attachment. `update_column` (`:649/651/654`) bypasses all callbacks. `resume.attach` is `has_one_attached :resume` (`:34`) with NO attachment callback. The only create-time enqueuer `enqueue_new_job_application` (`:45,164-171`) already fired at insert before any resume existed. Old-map gap CONFIRMED, not fixed.

6. AGREE — Broadcast: `GlobalChannel.broadcast_to(... action:'attachExternalResumeComplete' ...)` (`attach_external_resume_url_job.rb:11-12`); frontend handler only `queryCache.invalidateQueries(["jobApplication", Number(...)])` — no Textract call (`WebsocketGlobalChannelHandler.tsx:152-154`).

7. AGREE — Resting `:uploaded`: after attach, `has_resume == true` (`:589-602`) and status no longer `pending`, so a later `show` won't re-enqueue (`should_attach_external_resume_url?` needs `external_resume_status_pending?`, `:710`).

8. AGREE — Resting `:error`: no-retry resting state; `should_attach_external_resume_url?` requires `pending`, so no later `show` retries.

9. AGREE — Job rescue: `perform` body wrapped in `rescue StandardError => e` that only `ap`s (`:13-16`); no `retry_on`. Pre-rescue raise leaves no retry, no broadcast.

10. AGREE — Double-check: guard evaluated at enqueue (`controller:59`) and inside `attach_external_resume_url` (`:642`). Stale enqueue is a safe no-op.

11. DISPUTE — Map line 72 enumeration: "`SubmitResumeToTextractJob.perform_later` has 5 app enqueue sites" listing exactly `job_application.rb:168`, `validate_ai_summary_generation.rb:39`, `queue_bulk_ai_summary_jobs.rb:29`, `job_applications_controller.rb:114`, `get_resume_text_from_textract.rb:15`. WRONG COUNT/LIST. There are SIX app-code enqueue sites — `validate_ai_summary_generation.rb` has TWO: line 39 (no textract result) AND line 55 (latest failed but a prior did not). Plus TWO rake-task sites: `housekeeping_tasks.rake:409` and `:445`. The map's list omits `validate_ai_summary_generation.rb:55` and both rake sites. The T7 conclusion (attach path never triggers Textract) is unaffected, but the enumeration is factually incorrect.

## Omissions

- O1: Map omits `validate_ai_summary_generation.rb:55` as a `SubmitResumeToTextractJob` re-submit site (latest textract failed, prior not failed). Relevant because line 73/270 lists which separate triggers can later reach Textract for an `:uploaded` row and names only `validate_ai_summary_generation.rb:39`, bulk backfill, and resume replacement — the `:55` failed-retry path is another route.
- O2: Map omits the two rake-task enqueue sites `housekeeping_tasks.rake:409` and `:445` (backfill/replay) which can also reach Textract for an already-`:uploaded` imported row.

## clean = false
The T7 narrative conclusion is sound, but verdict 11 is a DISPUTE (wrong enqueue-site count/list) and there are two omissions.
