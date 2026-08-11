# T6 — CSV Bulk Import — Adversarial Review (pass-6)

Slice: CSV bulk import (`external_resume_url` present, no resume file at creation). Trace Textract behavior for imported rows to terminal.

Re-read from scratch against current code. Files traced:
`job_csv_import_controller.rb:4,16` → `import_job_candidates_from_csv_job.rb:6-25` → `create_candidate_job_application.rb:6-37` → `job_application.rb:45 (after_commit), :164-171 (enqueue_new_job_application), :160-162, :589-602 (has_resume), :94-98 (enum), :641-657 (attach_external_resume_url), :709-711 (should_attach_external_resume_url?)` → `find_or_create_ai_job_application_summary_status.rb:6-45` → `submit_resume_to_textract_job.rb:6-8` → `submit_resume_to_textract.rb:8-10,22` → `job_applications_controller.rb:46,56-60 (show)` → `attach_external_resume_url_job.rb:3,6-16`.

## Verdicts

1. **AGREE** — Chain `CSV → ImportJobCandidatesFromCsvJob → CreateCandidateJobApplication (WITHOUT resume_url:) → candidate.save → after_commit` (map line 367). `import_job_candidates_from_csv_job.rb:14-22` calls `CreateCandidateJobApplication.call(job:, candidate_data:, job_application_data:)` with NO `resume_url:` kwarg; `create_candidate_job_application.rb:10` `@resume_url = context.resume_url` is therefore nil and `:24 attach_resume_url unless @resume_url.blank?` is skipped; `:27 context.fail!(error: @candidate) unless @candidate.save`. The `on: [:create]` after_commit is `job_application.rb:45`.

2. **AGREE** — `external_resume_status: record['Resume URL'].nil? ? nil : :pending` at `import_job_candidates_from_csv_job.rb:21`; `external_resume_url: record['Resume URL']` at `:20`. Present-URL → `:pending` + url stored; no file at creation.

3. **AGREE** — Present-URL row: no file at creation → `SubmitResumeToTextract` exits at `has_resume` false → NO TextractResult. `submit_resume_to_textract.rb:10 return 'No resume attached' unless @job_application.has_resume`; build is at `:22` (after the early return). `has_resume` def `job_application.rb:589-602`; with no attachment `resume.attached?` is false (`:590,601`).

4. **AGREE** — Status row created `'none'` via `job_application.rb:170 find_or_create_ai_job_application_summary_status`. For a fresh row: `find_or_create_ai_job_application_summary_status.rb:22` else, `:23` `latest_ai_job_application_summary` nil (assoc `job_application.rb:31`), `:34 @status_record.status = 'none'`, `:37` save.

5. **AGREE** — Flipper GATE. `enqueue_new_job_application` enqueues `SubmitResumeToTextractJob` only inside `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)` (`job_application.rb:167-169`). Flag OFF → submit never enqueued → `submit_resume_to_textract.rb:10` early-exit never reached → same terminal (no TextractResult).

6. **AGREE** — `assign_attributes(job_application_data)` at `create_candidate_job_application.rb:22` applies to BOTH candidate branches (runs after the `:14-20` if/else), so `external_resume_url`, `external_resume_status: :pending`, `created_via_bulk_manual_add` apply to new and existing candidates' job_applications alike. Candidate `created_via_manual_add` applies only to the newly-built candidate branch (`:18`); the existing-candidate branch (`:15-16`) does not apply `candidate_data`.

7. **AGREE** — No-URL sub-case: `external_resume_status` nil and `external_resume_url` nil → `should_attach_external_resume_url?` (`job_application.rb:709-711`, `external_resume_status_pending? && !has_resume`) false → no lazy attach ever, no Textract ever. Benign terminal.

8. **AGREE** — Resume terminal (present-URL): later `show` (`job_applications_controller.rb:46,56-59`) enqueues `JobApplication::AttachExternalResumeUrlJob.perform_later(...)` if `should_attach_external_resume_url?` (`:58-59`); job `attach_external_resume_url_job.rb:9` calls `attach_external_resume_url` (`job_application.rb:641-657`) which on PDF does `resume.attach` + `update_column(:external_resume_status, :uploaded)` (`:648-649`). `update_column` bypasses callbacks AND `enqueue_new_job_application` is `on: [:create]` only — so Textract is never triggered on the attach/import/read path. Terminal is permanent ON THIS PATH (correctly scoped; a separate manual generate via `validate_ai_summary_generation.rb:39` can still re-enter once `has_resume?` is true, which the map states at line 382/383).

9. **AGREE** — `created_via`: candidate `:created_via_manual_add` (`import_job_candidates_from_csv_job.rb:17`; enum 0 `job_application.rb:84`), job_application `:created_via_bulk_manual_add` (`:20`; enum 4 `job_application.rb:88`).

10. **AGREE** — `external_resume_status` enum `{pending:0, uploaded:1, error:2}, _prefix:true` at `job_application.rb:94-98`.

11. **AGREE** — Attach job class/signature/broadcast: `class JobApplication::AttachExternalResumeUrlJob` (`attach_external_resume_url_job.rb:3`), `perform(job_application_id:, organization_user_id:)` (`:6`), `OrganizationUser.find` (`:7`), broadcasts `attachExternalResumeComplete` (`:11`), rescue `:13-16` only `ap`s.

## Omissions

- **O1** — The map's T6 "Chain" (line 367) and File (line 368) start at `ImportJobCandidatesFromCsvJob`; they OMIT the actual trigger entry point: `Api::V1::JobCsvImportController#create` (`app/controllers/api/v1/job_csv_import_controller.rb:4`) which runs `ValidateJobCsvImport.call(...)` (`:8`) and enqueues `ImportJobCandidatesFromCsvJob.perform_later(...)` at `:16-17`. (Non-Textract, but it is the entry actor for the slice.)

- **O2** — The map never states the directory of `submit_resume_to_textract.rb`; the file lives at `app/services/submit_resume_to_textract.rb` (a service, class `SubmitResumeToTextract`, method `#submit_resume`), NOT under `app/interactors/`. The map's bare `submit_resume_to_textract.rb:NN` citations are line-accurate but the path qualifier is absent/ambiguous. (Same for the job: `SubmitResumeToTextractJob#perform` calls `service.submit_resume`, `submit_resume_to_textract_job.rb:7-8`.)

- **O3** (minor, out-of-Textract-scope) — On the new-candidate branch, `CreateCandidateJobApplication` retrieves the job_application via `@candidate.job_applications.first` (`create_candidate_job_application.rb:19`) — the auto-built join record from `@job.candidates.build` (`:18`, `job.candidates` is `through: :job_applications`, `job.rb:38`). The map's T6 narrative does not surface this build-vs-retrieve asymmetry between branches; immaterial to the Textract terminal (both branches reach the same `after_commit`).

## Conclusion

Every T6 Textract claim in the map verifies against current code. Disputes: none. Omissions: O1 (controller entry), O2 (service file path/dir), O3 (minor association detail). clean = false (omissions non-empty).
