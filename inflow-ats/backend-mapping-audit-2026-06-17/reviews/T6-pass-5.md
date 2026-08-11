# T6 — CSV Bulk Import — Adversarial Review (pass 5)

Slice: what happens regarding Textract for CSV-imported rows (external_resume_url present, no resume file at creation), traced to terminal.

Trace chain re-derived from scratch:
`import_job_candidates_from_csv_job.rb:13-22` → `create_candidate_job_application.rb:6-30` → `candidate.save (:27)` → `job_application.rb:45 after_commit :enqueue_new_job_application` → `job_application.rb:164-171` → (Flipper `:167`) `SubmitResumeToTextractJob.perform_later (:168)` → `submit_resume_to_textract_job.rb:7-8` → `submit_resume_to_textract.rb:8-10` (early exit at `:10`, `has_resume` false) + `job_application.rb:170 find_or_create_ai_job_application_summary_status` → `find_or_create_ai_job_application_summary_status.rb:22-34` (`status='none'`). Later read path: `job_applications_controller.rb:56-59` → `JobApplication::AttachExternalResumeUrlJob` → `attach_external_resume_url (job_application.rb:641-657)` → `update_column(:external_resume_status,:uploaded) (:649)`, callbacks bypassed → no Textract.

## Map claims evaluated

1. CHANGED — `enqueue_new_job_application` also calls `find_or_create_ai_job_application_summary_status` (`job_application.rb:170`); CSV rows land `'none'`.
   AGREE. `job_application.rb:170` literal `find_or_create_ai_job_application_summary_status`; FindOrCreate else-branch `:34` `@status_record.status = 'none'`, save `:37`. Fresh CSV row has no prior summary (`latest_ai_job_application_summary` has_one `:31` is nil) so `:27` fails and `:34` runs.

2. MAP-WRONG — AiJobApplicationSummaryStatus enum: rows land `'none'`, not a 10-value pipeline status. AGREE (same evidence as #1).

3. CONFIRMED + Flipper gate — present-URL CSV row stores `external_resume_url` + `external_resume_status: :pending`, no file at creation; Textract exits at `has_resume` false (`submit_resume_to_textract.rb:10`, `job_application.rb:589-590`) → NO TextractResult; status `'none'` (`:170`). Gate `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)` (`:167`); flag OFF → submit never enqueued, same terminal.
   AGREE. `import_job_candidates_from_csv_job.rb:21` `external_resume_status: record['Resume URL'].nil? ? nil : :pending`; `:20` `external_resume_url: record['Resume URL']`. CSV calls `CreateCandidateJobApplication` with NO `resume_url:` key, so `create_candidate_job_application.rb:24` `attach_resume_url unless @resume_url.blank?` is skipped → no file at creation. `has_resume` (`:589-602`) returns `resume.attached?` → false. `submit_resume_to_textract.rb:10` `return 'No resume attached' unless @job_application.has_resume` fires before build `:22`. Gate `:167-169` confirmed.

4. NEW (terminal traced to T7) — later `show` (`job_applications_controller.rb:58-59`) → `JobApplication::AttachExternalResumeUrlJob` → `attach_external_resume_url (:641-657)` → `update_column(:external_resume_status,:uploaded) (:649)`; `update_column` bypasses callbacks → Textract STILL never triggered; permanent no-Textract terminal.
   AGREE. Controller `:58-59` enqueue gated by `should_attach_external_resume_url?`. `:649` is `update_column`. The only update-path after_commit is `track_movement` (`:46`, `:173-188`) which only handles job/stage moves — no Textract. `resume.attach (:648)` fires no Textract enqueuer. Confirmed permanent terminal.

5. No-URL sub-case — Resume URL nil → `external_resume_status` nil → `should_attach_external_resume_url?` false (needs `external_resume_status_pending?`, `:709-710`); no resume, no Textract ever.
   AGREE. `:21` yields nil; `:710` `external_resume_status_pending? && !has_resume`; nil status fails the pending check.

6. created_via — candidate `:created_via_manual_add` only for newly built candidate; job_application `:created_via_bulk_manual_add` applied to both branches via `assign_attributes` (`create_candidate_job_application.rb:22`).
   AGREE. `import_..._csv_job.rb:17` candidate `created_via: :created_via_manual_add`, `:20` JA `created_via: :created_via_bulk_manual_add`. `create_candidate_job_application.rb:14-16` existing-candidate branch builds JA without merging `candidate_data`; `:18` new-candidate branch merges it; `:22` `assign_attributes(@job_application_data)` runs for both. Enum values: `job_application.rb:84` manual_add=0, `:88` bulk_manual_add=4.

## Omissions
None material to the Textract terminal. Cross-path create-path actors (`NewJobApplicationJob`/`handle_new_job_application` `:195-204`; `DocxToPdfJob`) were verified to not touch Textract and to no-op on a resume-less row — the map's silence on them is correct, not an omission.

## Verdict
All AGREE, omissions empty → clean = true.
