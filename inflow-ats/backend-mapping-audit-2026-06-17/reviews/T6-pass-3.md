# T6 — CSV Bulk Import — Pass-3 Adversarial Review

Slice: T6 (CSV bulk import; `external_resume_url` present, no resume file at creation). Trace Textract for imported rows to terminal.

Candidate map under review: `backend-flow-map-2026-06-17.md` (changelog lines 58-65; detail lines 257-263).

Files traced (read from scratch):
`import_job_candidates_from_csv_job.rb` → `create_candidate_job_application.rb` → `job_application.rb:31,32,45,82-98,164-171,589-602,641-657,709-711` → `find_or_create_ai_job_application_summary_status.rb` → `submit_resume_to_textract.rb` → `job_applications_controller.rb:50-63,114` → `job_application/attach_external_resume_url_job.rb` → grep of all `SubmitResumeToTextractJob` enqueue sites.

## Verdicts

### CLAIM (line 59): `enqueue_new_job_application` calls `find_or_create_ai_job_application_summary_status` (`job_application.rb:170`); CSV rows land at status `'none'`.
AGREE. `job_application.rb:170` `find_or_create_ai_job_application_summary_status` (unconditional, inside `enqueue_new_job_application`, registered `after_commit ... on: [:create]` at `:45`). `find_or_create_ai_job_application_summary_status.rb:22` else-branch → `:34` `@status_record.status = 'none'` → `:37` save (no prior summary; `latest_ai_job_application_summary` `has_one` at `job_application.rb:31` is nil for a fresh row).

### CLAIM (line 60/61): `external_resume_status` is set CONDITIONALLY — `import_job_candidates_from_csv_job.rb:21`: `external_resume_status: record['Resume URL'].nil? ? nil : :pending`.
AGREE. `import_job_candidates_from_csv_job.rb:21` literal: `external_resume_status: record['Resume URL'].nil? ? nil : :pending`. `should_attach_external_resume_url?` requires `external_resume_status_pending?` (`job_application.rb:710`).

### CLAIM (line 62/260): Present-URL CSV row stores `external_resume_url` + `external_resume_status: :pending`, no file at creation; Textract exits early at `has_resume` false → NO TextractResult; status row `'none'`.
AGREE with caveat. `import_job_candidates_from_csv_job.rb:14-22` calls `CreateCandidateJobApplication` WITHOUT `resume_url:`, so `@resume_url` is nil and `attach_resume_url` is skipped (`create_candidate_job_application.rb:24`); `job_application_data` (incl. `external_resume_url`, `external_resume_status: :pending`) applied via `assign_attributes` at `create_candidate_job_application.rb:22` (both candidate branches). No file attached → `has_resume` false (`job_application.rb:589-601`) → `submit_resume_to_textract.rb:10` `return 'No resume attached' unless @job_application.has_resume` → no TextractResult.
CAVEAT (omission, not contradiction): `SubmitResumeToTextract` only runs if `enqueue_new_job_application` enqueued `SubmitResumeToTextractJob`, which is Flipper-gated `TEXTRACT_RESUME_PROCESSING` at `job_application.rb:167`. If Flipper is OFF the job never enqueues; the `submit_resume_to_textract.rb:10` early-exit is reached only when Flipper is ON. Either way: no TextractResult. The T6 detail narrative omits this gate (the T1 detail at line 220 notes it).

### CLAIM (line 63/263): Resume terminal — later `show` (`job_applications_controller.rb:58-59`) → `AttachExternalResumeUrlJob` → `attach_external_resume_url` (`job_application.rb:641-657`) attaches via `update_column(:external_resume_status, :uploaded)` (`:649`); `update_column` bypasses callbacks, Textract STILL never triggered. PERMANENT no-Textract terminal even after the file is present.
AGREE. `job_applications_controller.rb:58-59` enqueues `JobApplication::AttachExternalResumeUrlJob` if `should_attach_external_resume_url?`. Job at `job_application/attach_external_resume_url_job.rb:9` calls `@job_application.attach_external_resume_url`. Model method `job_application.rb:647-649`: PDF → `resume.attach(...)` + `update_column(:external_resume_status, :uploaded)`. `update_column` bypasses `after_commit` callbacks; the only Textract-enqueuing model callback is `enqueue_new_job_application` which is `on: [:create]` and already fired at insert. None of the `SubmitResumeToTextractJob` enqueue sites runs on the read/attach path.

### CLAIM (line 64/261): No-URL sub-case — `external_resume_status` nil → `should_attach_external_resume_url?` false → no resume, no Textract ever (benign terminal).
AGREE. `import_job_candidates_from_csv_job.rb:21` → nil; `job_application.rb:709-710` `should_attach_external_resume_url?` = `external_resume_status_pending? && !has_resume`, nil status fails the `_pending?` check → controller enqueue (`:59`) and method (`:642`) both no-op.

### CLAIM (line 65/262): `created_via` — candidate `:created_via_manual_add` only for a NEWLY built candidate (existing-candidate reuse via `create_candidate_job_application.rb:14-20` does not apply `candidate_data`); job_application `:created_via_bulk_manual_add`.
AGREE. `create_candidate_job_application.rb:18` (new candidate) builds with `@candidate_data` (which carries `created_via: :created_via_manual_add` from `import_job_candidates_from_csv_job.rb:17`). Existing-candidate branch `:14-16` builds the job_application on the existing candidate WITHOUT `candidate_data`. `job_application_data.created_via = :created_via_bulk_manual_add` (`import_job_candidates_from_csv_job.rb:20`) applied to both branches via `assign_attributes` (`:22`). Enum values: `created_via_manual_add:0`, `created_via_bulk_manual_add:4` (`job_application.rb:84,88`).

### CLAIM (line 258): Chain `CreateCandidateJobApplication (called WITHOUT resume_url:) → candidate.save → after_commit`.
AGREE. `import_job_candidates_from_csv_job.rb:14-22` passes no `resume_url:`. `create_candidate_job_application.rb:27` `context.fail!(error: @candidate) unless @candidate.save`; the job_application is autosaved through the candidate, firing `after_commit :enqueue_new_job_application, on: [:create]` (`job_application.rb:45`). NOTE: new-candidate branch uses `@job.candidates.build` where `job.candidates` is `has_many through: :job_applications` (`job.rb:38`), so the candidate AND an intermediate job_application are built; `@candidate.job_applications.first` (`create_candidate_job_application.rb:19`) retrieves it. The map does not detail this through-association mechanism but its stated conclusion (the on:create after_commit fires) holds.

## Omissions

1. **Flipper gate inside the T6 narrative.** The T6 detail (map lines 62, 260) describes Textract exiting at `submit_resume_to_textract.rb:10`, but `SubmitResumeToTextract` runs only when `enqueue_new_job_application` enqueued the job, gated on `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)` at `job_application.rb:167`. When the flag is OFF, no job is enqueued and the `:10` early-exit is never reached. Same terminal (no TextractResult), but the cited mechanism is reached only with the flag ON. (T1 detail line 220 notes this; T6 does not.)

2. **Enqueue-site count is wrong (cross-ref into T7, but load-bearing for the T6 "Textract STILL never triggered" claim).** The map (T7, line 72, and referenced from T6 line 269) lists FIVE `SubmitResumeToTextractJob` enqueue sites and names only one of the two in `validate_ai_summary_generation.rb`. Grep of `app/` shows SIX call sites: `job_application.rb:168`, `validate_ai_summary_generation.rb:39`, `validate_ai_summary_generation.rb:55`, `queue_bulk_ai_summary_jobs.rb:29`, `job_applications_controller.rb:114`, `get_resume_text_from_textract.rb:15`. The missing site is `validate_ai_summary_generation.rb:55` (the failed-only resubmit). The T6 terminal conclusion is unaffected (none of the six runs on the read/attach path), but the enumeration the map relies on to justify "Textract STILL never triggered" is incomplete.

3. **`assign_attributes(job_application_data)` applies to BOTH candidate branches.** The map's existing-candidate caveat (line 65/262) correctly notes `candidate_data` is not applied to a reused candidate, but does not state that `job_application_data` (carrying `external_resume_url`/`external_resume_status: :pending`/`created_via_bulk_manual_add`) IS applied to both branches at `create_candidate_job_application.rb:22`. This is what makes the present-URL terminal identical for new and existing candidates; worth stating explicitly.

## clean = false
