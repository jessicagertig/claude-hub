# T2 Adversarial Review — Pass 7

Slice T2 — Manual resume upload / replacement (internal app). Controller `update` action resume-param path → `SubmitResumeToTextractJob`; stale-marking of any existing `AiJobApplicationSummary`; fate of the `AiJobApplicationSummaryStatus` row.

Re-traced from scratch against current code. Chain followed:
`job_applications_controller.rb:88-126` → `submit_resume_to_textract_job.rb:6-12` → `submit_resume_to_textract.rb:8-41` → `textract_result.rb:7,114-144,61-89,98-108` → `ai_job_application_summary.rb:29-31,57-98,23,102` → `find_or_create_ai_job_application_summary_status.rb:6-45` → `orchestrate.rb:9-50` → `job_application.rb:32,160-171,589` → `job.rb:914-922` → `ai_job_application_summary_status.rb:9-13` → `queue_bulk_ai_summary_jobs.rb:36-40`.

## Verdicts

All T2 claims verified AGREE.

1. **L31 — change-detection in controller update, not a model callback; comments at controller :109,111.** AGREE — `job_applications_controller.rb:109` (`# Calling this here becuase ActiveRecord does not have a changed/dirty tracker for ActiveStorage attachments`) and `:111` (`# Have to do this here because there is no AR callback...`). No model `after_commit` drives T2.

2. **L32 / L341,343 — Textract enqueue gated on `temp_params.key?(:resume) && temp_params[:resume].present?` (presence, not mere key); blank `:resume` rejected at the controller gate before the in-service `has_resume`.** AGREE — `job_applications_controller.rb:110`.

3. **L33 / L344 — controller-side Flipper gate `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, current_organization)`; flag OFF → resume replaced (`:107`) but no Textract, no stale, prior summary stays succeeded+non-stale, status row stays current.** AGREE — `job_applications_controller.rb:113-114`, `:107`. Scope is `current_organization` (controller-side), paralleling model-side `job.organization` at `job_application.rb:167` — map states this parallel correctly.

4. **L34 — `DocxToPdfJob.perform_later` co-enqueued immediately before Textract, both perform_later no ordering; SubmitResumeToTextract prefers resume_docx_to_pdf.** AGREE — `job_applications_controller.rb:112` then `:114`; `submit_resume_to_textract.rb:15`.

5. **L35 — `regenerating` IS set, at find_or_create...:14-15, guarded on the row's associated summary being status_succeeded? (:12,14-15).** AGREE — `find_or_create_ai_job_application_summary_status.rb:12` (`summary = @status_record.ai_job_application_summary`), `:14` (`if summary&.status_succeeded?`), `:15` (`@status_record.update_columns(status: 'regenerating')`).

6. **L36 — credit-flow guard `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`; stale-succeeded no longer short-circuits.** AGREE — `textract_result.rb:67-68`. `latest_ai_summary = job_application.latest_ai_job_application_summary` (`:67`) is `has_one ... order(created_at: :desc)` with NO stale filter (`job_application.rb:31`), so a stale-succeeded summary is selected and `!stale?` is false → no early return.

7. **L37 — `after_commit :create_status_record, on: :create` no longer exists on AiJobApplicationSummary.** AGREE — `ai_job_application_summary.rb:29-31` shows only `destroy_previous_textract_results` and `update_summary_status_record` (both `on: :update`) plus `before_update :broadcast_status_change`. No create_status_record callback.

8. **L38 — status enum has 4 values, no `regenerating` boolean column; `regenerating` written as enum value 3 via update_columns at :15.** AGREE — `ai_job_application_summary_status.rb:9-13` (`none:0, initial_summary_pending:1, current:2, regenerating:3`); `find_or_create...:15` `update_columns(status: 'regenerating')`.

9. **L39 — `update_summary_status_record` sets `status: 'current'` via `.update`, no regenerating column.** AGREE — `ai_job_application_summary.rb:74-80` `.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)`.

10. **L40 / L348 — STUCK `regenerating` terminal on T2 auto-continuation (not a current→regenerating→current round trip).** AGREE on full chain:
   - prior succeeded summary staled: `submit_resume_to_textract.rb:18-19` `update_all(stale: true)` (status stays succeeded).
   - new TextractResult succeeds → bridge else branch `textract_result.rb:137` (no `textract_processing`/`stale:false` waiting summary, `:121-123` returns nil).
   - credit flow no early-return at `:68` (stale fails `!stale?`).
   - `FindOrCreate` flips row to `regenerating` (`find_or_create...:14-15`, driven by status row's denormalized `ai_job_application_summary` pointer `:12`).
   - `Orchestrate` selects stale-succeeded summary (`orchestrate.rb:15` JobApplication-scoped, NO stale filter), `:16` passes, succeeded branch returns (`:46-48`).
   - no new summary → `update_summary_status_record` never fires (`ai_job_application_summary.rb:69` guard `saved_change_to_status? && status_succeeded?`) → row STUCK `regenerating` with OLD denormalized data.
   - Recovery only via later MANUAL (T9/S-A) or BULK (S-B) that builds a fresh `:pending` summary filtering `where(stale: false)`. Confirmed the bulk pre-filter excludes only `:current` rows (`queue_bulk_ai_summary_jobs.rb:36-40`), so a stuck-`regenerating` candidate IS processed (map L350).

11. **L41 / L349 — auto-gen GATE: ON → bridge re-validates :140 and enqueues if result.success? :142 → STUCK regenerating; OFF → bridge returns at :138, row NEVER flipped to regenerating, stays current with stale denormalized data, prior summary left stale:true with no further actor.** AGREE — `textract_result.rb:138` (`return unless job_application&.job&.should_auto_generate_ai_summaries?`), `:140`, `:142`; `should_auto_generate_ai_summaries?` at `job.rb:914-922`.

12. **L42 — else/auto branch enqueues with NO requesting_organization_user_id → no AI_SUMMARY_COMPLETE toast.** AGREE — `textract_result.rb:142` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)` (no requesting_organization_user_id arg).

13. **L44 — `update_all(stale: true)` guarded by `unless ...where(status: :textract_processing, stale: false).exists?`; common T2 scenario the guard passes; if a non-stale textract_processing summary exists the update_all is SKIPPED.** AGREE — `submit_resume_to_textract.rb:18-19`.

14. **L45 — waiting-summary relink `find_by(status: :textract_processing, stale: false, textract_result_id: nil)` then `update_columns(textract_result_id:)`; in the guarded-skip window this relinks the in-flight waiting summary onto the new TextractResult and redirects the bridge to the IF branch (:125).** AGREE — `submit_resume_to_textract.rb:25-26`; bridge selector `textract_result.rb:121-123` then IF branch `:125`.

15. **L46 — rescue-swallow resting state: job rescues StandardError and only aps (:9-11); service rescues InvalidS3ObjectException and StandardError, sets `@textract_result&.update_columns(textract_job_status: 'failed')` (:31-40); new TextractResult lands failed, no continuation, already-staled prior summary left succeeded+stale:true.** AGREE — `submit_resume_to_textract_job.rb:9-11`; `submit_resume_to_textract.rb:31-35` (InvalidS3ObjectException, `:33`) and `:36-40` (StandardError, `:39`).

16. **L345 — controller update creates NO AiJobApplicationSummary, does not call CreateAiSummaryGeneration; submit service creates no summary.** AGREE — `job_applications_controller.rb:88-126`; `submit_resume_to_textract.rb` builds only a `TextractResult` (`:22`), no summary.

17. **L346 — status row NOT touched by SubmitResumeToTextract; only summary-table write is the conditional `update_all(stale: true)`; no status-row reference in the service or the controller update path.** AGREE — confirmed by reading `submit_resume_to_textract.rb:1-42` (no `ai_job_application_summary_status`) and the update action `:88-126` (no status-row reference).

18. **L43 — no-resume removal terminal: `has_resume` false → `submit_resume_to_textract.rb:10` returns 'No resume attached' before stale update_all (:18-19) and before build (:22); reachable only when controller passes non-blank :resume whose attachment yields has_resume false.** AGREE — `submit_resume_to_textract.rb:9` (JobApplication not found), `:10` (No resume attached), `:18-19`, `:22`; `has_resume` def `job_application.rb:589`.

## Omissions

None for the T2 slice. The map covers: the controller change-detection surface and its in-code comments; the presence (not key) gate; the controller-side Flipper gate and its flag-OFF resting state; DocxToPdfJob co-enqueue ordering; the conditional `update_all(stale: true)` stale-marking and its guard; the waiting-summary relink and its guarded-skip redirect; the bridge else/auto branch; the auto-gen gate (ON and OFF); the FindOrCreate regenerating flip and its status-only write (denormalized data persists); the Orchestrate stale-succeeded no-op; the STUCK-`regenerating` terminal with no advancing actor; the no-credit outcome; the no-toast outcome; the rescue-swallow failed-TextractResult resting state; the no-resume-removal terminal; and recovery only via later manual/bulk regen. All record writes on the slice are enumerated in the X0 census (L818-823): TextractResult build at `submit_resume_to_textract.rb:22`, failed via `update_columns` at `:33/:39`, stale `update_all` at `:19`, waiting-summary relink `update_columns` at `:26`; status-row `regenerating` `update_columns` at `find_or_create...:15`; status-row `current` `.update` at `ai_job_application_summary.rb:74`.

## Record-write sites confirmed on the T2 slice

- `submit_resume_to_textract.rb:19` — `ai_job_application_summaries.update_all(stale: true)` — column `stale` — `update_all` (callback-bypassing), conditional on `:18` guard.
- `submit_resume_to_textract.rb:22/24` — `textract_results.build(textract_job_id:, textract_job_status: 'in_progress')` + `.save` — columns `textract_job_id`, `textract_job_status` — insert (fires `after_commit :queue_ai_summary_job` on create, but bridge `:115` short-circuits since `textract_job_result_text` is blank at build).
- `submit_resume_to_textract.rb:26` — `waiting_summary&.update_columns(textract_result_id:)` — column `textract_result_id` — `update_columns` (callback-bypassing), guarded-skip window only.
- `submit_resume_to_textract.rb:33/39` — `@textract_result&.update_columns(textract_job_status: 'failed')` — column `textract_job_status` — `update_columns` (callback-bypassing), rescue paths.
- `find_or_create_ai_job_application_summary_status.rb:15` — `@status_record.update_columns(status: 'regenerating')` — column `status` only (denormalized columns NOT cleared) — `update_columns` (callback-bypassing).
- `ai_job_application_summary.rb:74-80` — `.update(ai_job_application_summary_id:, status: 'current', score_percentage:, headline:, integrated_role_analysis:)` — recovery write, reached only on a later manual/bulk regen, not on the T2 auto path.

clean = true (all verdicts AGREE; omissions empty).
