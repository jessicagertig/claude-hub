# T6 Adversarial Review — Pass 7

Slice: T6 — CSV bulk import (external_resume_url present, no resume file at creation). Trace Textract for imported rows, to terminal.

Candidate map section: lines 96-106 of `backend-flow-map-2026-06-17.md` (Trigger 6 — CSV Bulk Import).

Method: re-read all cited code from scratch. Files opened and traced:
- `app/controllers/api/v1/job_csv_import_controller.rb` (entry)
- `app/jobs/import_job_candidates_from_csv_job.rb`
- `app/interactors/create_candidate_job_application.rb`
- `app/models/job_application.rb` (`:45` callback, `:83-98` enums, `:160-171` enqueue, `:589-602` has_resume, `:641-657` attach_external_resume_url, `:709-711` should_attach_external_resume_url?)
- `app/services/submit_resume_to_textract.rb`
- `app/jobs/submit_resume_to_textract_job.rb`
- `app/interactors/find_or_create_ai_job_application_summary_status.rb`
- `app/controllers/api/v1/job_applications_controller.rb:56-63` (show enqueue)
- `app/models/textract_result.rb:7` (bridge callback)
- grep of all `SubmitResumeToTextractJob` enqueue sites

## Verdicts

### CHANGED claim (line 97) — `enqueue_new_job_application` now calls `find_or_create_ai_job_application_summary_status`; CSV rows land at `'none'`
AGREE. `job_application.rb:170` `find_or_create_ai_job_application_summary_status` inside `enqueue_new_job_application` (`:164-171`), fired by `after_commit :enqueue_new_job_application, on: [:create]` (`:45`). For a fresh CSV row, `find_or_create_ai_job_application_summary_status.rb` else branch (`:22`), nil `latest_ai_job_application_summary` → `status = 'none'` (`:34`), `save` (`:37`).

### MAP-WRONG claim (line 98) — AiJobApplicationSummaryStatus enum, CSV rows land `'none'`
AGREE. `find_or_create_ai_job_application_summary_status.rb:34` writes `'none'`.

### MAP-WRONG / pass-2 claim (line 99) — `external_resume_status` set CONDITIONALLY
AGREE. `import_job_candidates_from_csv_job.rb:21` `external_resume_status: record['Resume URL'].nil? ? nil : :pending`; `external_resume_url: record['Resume URL']` at `:20`. No-URL → nil; present-URL → `:pending`. `should_attach_external_resume_url?` requires `external_resume_status_pending?` (`job_application.rb:710`), so no-URL never qualifies. Verified.

### CONFIRMED + Flipper gate / pass-3 claim (line 100) — present-URL row, no file at creation, Textract exits at has_resume false, gated on Flipper
AGREE. Present-URL row stores `external_resume_url` + `external_resume_status: :pending` (`import_job_candidates_from_csv_job.rb:20-21`), no file at creation (CSV job passes no `resume_url`; `CreateCandidateJobApplication#attach_resume_url` `:24,:34-37` no-ops). `SubmitResumeToTextract#submit_resume` returns `'No resume attached'` at `submit_resume_to_textract.rb:10` because `has_resume` is false (`job_application.rb:589-602`, `resume.attached?` false at `:590`) → no build (`:22`), no TextractResult. Status row `'none'` (`job_application.rb:170`). Flipper gate `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)` at `job_application.rb:167`; OFF → `:168` never enqueued, same terminal.

### NEW claim (line 101) — PERMANENT no-Textract terminal even after file present; show → AttachExternalResumeUrlJob → attach via update_column bypasses callbacks
AGREE. `job_applications_controller.rb:58-59` enqueues `JobApplication::AttachExternalResumeUrlJob.perform_later(... job_application_id: params[:id])` gated on `should_attach_external_resume_url?`. `attach_external_resume_url` (`job_application.rb:641-657`) attaches file then `update_column(:external_resume_status, :uploaded)` (`:649`). `update_column` bypasses callbacks (Rails framework boundary), so no Textract enqueue. Grep of all 6 app `SubmitResumeToTextractJob` enqueue sites confirms NONE is on the attach/read path. After attach, `should_attach_external_resume_url?` false (`:710` requires `external_resume_status_pending?`), so no re-enqueue. Permanent no-Textract terminal until a separate trigger.

### NEW claim (line 102) — no-URL sub-case terminal: external_resume_status nil → no attach, no Textract ever
AGREE. `import_job_candidates_from_csv_job.rb:21` nil; `should_attach_external_resume_url?` false (`job_application.rb:709-710`); controller enqueue (`:59`) and `attach_external_resume_url` (`:642`) both no-op. Benign terminal.

### NEW claim (line 103) — created_via precision; existing-candidate branch builds without candidate_data but assign_attributes applies to BOTH branches
AGREE. `create_candidate_job_application.rb:14` `if organization_candidates.any?` → `:16` build on existing candidate (no `candidate_data`); else `:18` build new candidate with `candidate_data` (`created_via: :created_via_manual_add` from job `:17`). `:22` `@job_application.assign_attributes(@job_application_data)` applies to BOTH branches → `external_resume_url`, `external_resume_status: :pending`, `created_via_bulk_manual_add` (job `:20`) applied for both. Terminal identical.

### NEW / pass-6 claim (line 104) — trigger entry actor is JobCsvImportController#create
AGREE. `job_csv_import_controller.rb:4` `def create`; `authorize job, :on_hiring_team?` at `:6`; `ValidateJobCsvImport.call(file:, job:, hiring_stage_id:)` at `:8`, bad-request render `:10-14`; `ImportJobCandidatesFromCsvJob.perform_later(organization_user_id:, job_id:, hiring_stage_id:, csv_records:)` at `:16-17`. Verified.

### NOTE / pass-6 claim (line 105) — service path and method
AGREE. `SubmitResumeToTextract` at `app/services/submit_resume_to_textract.rb`, method `submit_resume` (`:8`). `SubmitResumeToTextractJob#perform` calls `SubmitResumeToTextract.new(...).submit_resume` (`submit_resume_to_textract_job.rb:7-8`). Verified.

### NOTE / pass-6 claim (line 106) — build-vs-retrieve asymmetry; new-candidate retrieves via @candidate.job_applications.first
AGREE. `create_candidate_job_application.rb:19` `@job_application = @candidate.job_applications.first` after `@job.candidates.build(...)` at `:18`. Immaterial to Textract terminal. Verified.

## Omissions

1. **Why "no resume file at creation" holds is not anchored.** `CreateCandidateJobApplication` HAS a resume-attach path (`create_candidate_job_application.rb:24` `attach_resume_url unless @resume_url.blank?`, body `:34-37` downloads + `resume.attach`). It no-ops on the CSV path only because `ImportJobCandidatesFromCsvJob` passes NO `resume_url` key (job `:14-22` passes only `job:`/`candidate_data:`/`job_application_data:`). The map's T6 narrative asserts "no file at creation" but never cites this mechanism. If `resume_url` were passed, a file WOULD be attached at creation and the Textract terminal would differ — so the absence of `resume_url` in the CSV caller is load-bearing for the entire T6 slice and should be cited.

2. **`CreateCandidateJobApplication` validity-failure / candidate-save-failure terminals not enumerated for T6.** `create_candidate_job_application.rb:26` `context.fail!(error: @job_application) unless @job_application.valid?` and `:27` `context.fail!(error: @candidate) unless @candidate.save` are per-row rejection terminals: a failing CSV row creates NO job_application, NO status row, NO Textract. Unlike the import/apply paths (T4/T5), where the map enumerates the analogous `CreateJobApplication` failure terminals, the T6 section omits these `CreateCandidateJobApplication` rejection terminals entirely. Note the CSV job swallows the failure per-row (`import_job_candidates_from_csv_job.rb:23-24` `ap` only) and continues the loop — so one bad row does not abort the batch (distinct from T4/T5 single-transaction rollback). This is a real structural divergence the map does not capture for T6.

3. **`ImportJobCandidatesFromCsvJob` whole-job rescue not noted.** `import_job_candidates_from_csv_job.rb:28-31` `rescue StandardError` logs and swallows; a mid-loop raise aborts remaining rows but the already-created rows keep their `'none'` status and no-Textract terminal. Minor, but it is the batch-level resting behavior for the slice and is unmentioned.

## clean = false
Reason: all verdicts AGREE, but three omissions exist (the load-bearing no-`resume_url` mechanism, the `CreateCandidateJobApplication` per-row rejection terminals, and the job-level rescue).
