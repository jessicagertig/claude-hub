# T6 — CSV Bulk Import — Adversarial Review (Pass 2)

Scope: CSV bulk import (`external_resume_url` present, no resume file at creation). Trace what happens regarding Textract for imported rows, to terminal.

Code re-read from scratch. Chain followed:
`import_job_candidates_from_csv_job.rb:14-22` → `create_candidate_job_application.rb:6-37` → `job_application.rb:45 (after_commit)` → `job_application.rb:164-171 (enqueue_new_job_application)` → `submit_resume_to_textract.rb:8-10 (has_resume guard)` / `find_or_create_ai_job_application_summary_status.rb:22-37` → terminal. Plus T7 terminal: `job_applications_controller.rb:58-59` → `attach_external_resume_url_job.rb:9` → `job_application.rb:641-657 (update_column, bypasses callbacks)`.

## Verdicts

### MAP CLAIM (changelog line 54 / Trigger 6 detail line 211 / matrix line 497): "CSV row stores `external_resume_url` + `external_resume_status: :pending`, no file at creation"
DISPUTE. The `external_resume_status` is set CONDITIONALLY, not unconditionally `:pending`.
`import_job_candidates_from_csv_job.rb:21`: `external_resume_status: record['Resume URL'].nil? ? nil : :pending`.
Correction: when the CSV row's `Resume URL` is nil, `external_resume_status` is set to `nil` (and `external_resume_url` to nil), NOT `:pending`. Only when a Resume URL is present does it land `:pending`. The map's blanket ":pending" is inaccurate for the no-URL sub-case, and that sub-case has a different terminal (the row never qualifies for lazy attachment because `should_attach_external_resume_url?` requires `external_resume_status_pending?`, `job_application.rb:710`).

### MAP CLAIM (line 209/210): "CSV → `ImportJobCandidatesFromCsvJob` → `CreateCandidateJobApplication` (called WITHOUT `resume_url:`) → `candidate.save` → `after_commit`; File `app/jobs/import_job_candidates_from_csv_job.rb:14-22`"
AGREE. `import_job_candidates_from_csv_job.rb:14-22` calls `CreateCandidateJobApplication.call(job:, candidate_data:, job_application_data:)` — no `resume_url:` key. In `create_candidate_job_application.rb:10` `@resume_url = context.resume_url` is nil → line 24 `attach_resume_url unless @resume_url.blank?` is skipped → no file attached. `candidate.save` at `create_candidate_job_application.rb:27`.

### MAP CLAIM (line 211 / 497): "no file at creation → `SubmitResumeToTextract` exits at `has_resume` false → NO TextractResult"
AGREE. `submit_resume_to_textract.rb:10`: `return 'No resume attached' unless @job_application.has_resume`. `has_resume` (`job_application.rb:589-590`) is `resume.attached?`-based; no file attached for imported rows → early return → no `textract_results.build`, no `GetResumeTextFromTextractJob`. (Reached only if `TEXTRACT_RESUME_PROCESSING` Flipper enabled, `job_application.rb:167-168`.)

### MAP CLAIM (line 211 / 497): "Status row created `'none'`"
AGREE. `job_application.rb:170` unconditionally calls `find_or_create_ai_job_application_summary_status`. For a fresh import row no status record exists, `latest_ai_job_application_summary` is nil → `find_or_create_ai_job_application_summary_status.rb:27` guard false → line 34 `@status_record.status = 'none'`, saved line 37.

### MAP CLAIM (line 212): "`created_via`: candidate `:created_via_manual_add`, job_application `:created_via_bulk_manual_add`"
AGREE. `import_job_candidates_from_csv_job.rb:17` candidate_data `created_via: :created_via_manual_add`; `:20` job_application_data `created_via: :created_via_bulk_manual_add`.

### MAP CLAIM (changelog line 52): "`enqueue_new_job_application` now also calls `find_or_create_ai_job_application_summary_status`; CSV rows land at status `'none'`"
AGREE. `job_application.rb:170`.

### MAP CLAIM (changelog line 53 / X1-X2): "AiJobApplicationSummaryStatus enum — CSV rows land at `'none'`, not a 10-value pipeline status"
AGREE. `ai_job_application_summary_status.rb` enum is `{none:0, initial_summary_pending:1, current:2, regenerating:3}`; import lands `'none'` per above.

### MAP CLAIM (matrix line 497): Flipper gate column "TEXTRACT_RESUME_PROCESSING"
AGREE. `job_application.rb:167` gates `SubmitResumeToTextractJob` behind `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)`. (Note: even when enabled, the submit early-returns on `has_resume` false for imported rows, so the gate is moot for the Textract outcome of T6.)

## Omissions

1. **Terminal not traced to rest — no connection to T7 lazy attachment.** The T6 section stops at "no TextractResult." It never states the actual terminal for an imported row's resume: on a later controller `show` (`job_applications_controller.rb:58-59`), `AttachExternalResumeUrlJob` → `attach_external_resume_url` (`job_application.rb:641-657`) downloads the URL and attaches the file via `update_column(:external_resume_status, :uploaded)` (`:649`). Because `update_column` bypasses callbacks, **Textract is STILL never triggered** for the now-attached resume. The map documents this under T7 in isolation but does not connect it to T6, so the reader of the T6 slice cannot see that imported rows reach a permanent no-Textract terminal even after the resume is physically present. The cross-link is the load-bearing terminal fact for T6.

2. **No-URL sub-case terminal.** When `record['Resume URL']` is nil, `external_resume_status` is `nil` (not pending). `should_attach_external_resume_url?` (`job_application.rb:709-710`) requires `external_resume_status_pending?`, which is false → `attach_external_resume_url` (`:642`) and the controller enqueue (`:59`) both no-op. Such a row has no resume ever and no Textract ever — a distinct benign terminal the map does not name.

3. **`CreateCandidateJobApplication` reuses an existing candidate's job_applications association rather than always building a new candidate.** `create_candidate_job_application.rb:14-20`: if a candidate with that email already exists in the org, it builds a new `job_application` on the existing candidate (`:16`) instead of `candidate.build`. Not Textract-relevant, but it means the "candidate `:created_via_manual_add`" claim only holds when the candidate is new (`:18`); for a pre-existing candidate the candidate_data merge (including `created_via`) is not applied. Minor omission affecting the created_via precision.

## Conclusion
clean = false. One DISPUTE (conditional `external_resume_status`, mapped as unconditional `:pending`) plus omissions (T6→T7 terminal not connected; no-URL sub-case; candidate-reuse path).
