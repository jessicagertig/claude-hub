# T6 — CSV Bulk Import — Adversarial Review (pass 4)

Slice: T6 — CSV bulk import (`external_resume_url` present, no resume file at creation). Trace Textract behavior for imported rows to terminal.

Candidate map: `backend-flow-map-2026-06-17.md`, Trigger 6 section (lines 70-78).

Re-verified from scratch against current code. Chain of files read:
- `app/jobs/import_job_candidates_from_csv_job.rb`
- `app/interactors/create_candidate_job_application.rb`
- `app/models/job_application.rb` (`:45` callback, `:83-91` created_via enum, `:94-98` external_resume_status enum, `:164-171` enqueue_new_job_application, `:589-602` has_resume, `:641-657` attach_external_resume_url, `:709-711` should_attach_external_resume_url?)
- `app/services/submit_resume_to_textract.rb`
- `app/interactors/find_or_create_ai_job_application_summary_status.rb`
- `app/controllers/api/v1/job_applications_controller.rb` (`:56-63` show)
- `app/jobs/job_application/attach_external_resume_url_job.rb`

## Verdicts

### Claim 1 (CHANGED) — `enqueue_new_job_application` calls `find_or_create_ai_job_application_summary_status` (`job_application.rb:170`); CSV rows land at `'none'`.
AGREE. `job_application.rb:170` `find_or_create_ai_job_application_summary_status`. Fresh CSV row has no summary → `FindOrCreate` else branch, `latest_ai_job_application_summary` nil → `@status_record.status = 'none'` (`find_or_create_ai_job_application_summary_status.rb:34`).

### Claim 2 (MAP-WRONG) — status enum value is `'none'`, not a 10-value pipeline status.
AGREE. `find_or_create_ai_job_application_summary_status.rb:34`.

### Claim 3 (MAP-WRONG pass-2) — `external_resume_status` set conditionally `record['Resume URL'].nil? ? nil : :pending`.
AGREE. `import_job_candidates_from_csv_job.rb:21` literal: `external_resume_status: record['Resume URL'].nil? ? nil : :pending`.

### Claim 4 (CONFIRMED + Flipper gate) — present-URL row stores `external_resume_url` + `:pending`, no file at creation; Textract exits early at `has_resume` false → NO TextractResult; status row `'none'`; gated by `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, ...)` at `job_application.rb:167`.
AGREE. `import_job_candidates_from_csv_job.rb:20-21` sets `external_resume_url` + `:pending`. `CreateCandidateJobApplication` attaches a file only via `attach_resume_url unless @resume_url.blank?` (`:24`) — but `csv_records` pass NO `resume_url` key (only `external_resume_url` inside `job_application_data`), so `context.resume_url` is nil and no blob is attached. `has_resume` returns `resume.attached?` (`job_application.rb:601`), false. `SubmitResumeToTextract#submit_resume` returns `'No resume attached'` at `submit_resume_to_textract.rb:10` before the build at `:22`. Flipper gate confirmed `job_application.rb:167`.

### Claim 5 (NEW, terminal traced to T7) — later `show` → `AttachExternalResumeUrlJob` → `attach_external_resume_url` downloads + attaches via `update_column(:external_resume_status, :uploaded)` (`:649`); `update_column` bypasses callbacks, so Textract still never triggered.
AGREE. `job_applications_controller.rb:58-59` enqueues `JobApplication::AttachExternalResumeUrlJob` when `should_attach_external_resume_url?`. Job calls `@job_application.attach_external_resume_url` (`attach_external_resume_url_job.rb:9`). Model method attaches the PDF and `update_column(:external_resume_status, :uploaded)` (`job_application.rb:648-649`). `update_column` bypasses callbacks; no `SubmitResumeToTextractJob` enqueue on this path. Confirmed.

### Claim 6 (NEW, no-URL sub-case terminal) — `record['Resume URL']` nil → `external_resume_status` nil → `should_attach_external_resume_url?` false → both attach and controller enqueue no-op; no resume, no Textract ever.
AGREE. `should_attach_external_resume_url?` = `external_resume_status_pending? && !has_resume` (`job_application.rb:710`). With `external_resume_status` nil, `external_resume_status_pending?` is false → false. `attach_external_resume_url` returns at `:642`; controller enqueue guard at `:59` is false.

### Claim 7 (NEW, created_via precision) — `CreateCandidateJobApplication` reuses an existing candidate's job_applications association (`:14-20`); for a pre-existing email it builds the job_application on the existing candidate (`:16`) without applying `candidate_data`; `assign_attributes(job_application_data)` at `:22` applies to BOTH branches; so `external_resume_url`, `external_resume_status: :pending`, and `created_via_bulk_manual_add` are applied to the existing-candidate's job_application too; candidate `created_via_manual_add` claim holds only for a newly built candidate (`:18`).
AGREE. `create_candidate_job_application.rb:14` `if organization_candidates.any?`; `:16` `@job_application = @candidate.job_applications.build(job_id: @job.id)` (no `candidate_data`); `:18` `@candidate = @job.candidates.build(@candidate_data.merge(...))`; `:22` `@job_application.assign_attributes(@job_application_data) unless @job_application_data.blank?` applies to both branches. `created_via_bulk_manual_add` is in `job_application_data` (`import_job_candidates_from_csv_job.rb:20`), `created_via_manual_add` is in `candidate_data` (`:17`).

## Omissions

None material to the Textract terminal. Minor observations (not contradictions, the map's terminal stands):

1. The map does not explicitly state that `CreateCandidateJobApplication` itself enqueues no Textract job — the ONLY Textract trigger on the CSV path is the shared `after_commit :enqueue_new_job_application, on: [:create]` (`job_application.rb:45`), which fires on the new job_application's create commit (via `@candidate.save` at `create_candidate_job_application.rb:27`, autosaving the built job_application). This is implied by the cross-reference to T1/T4/T5's shared callback but not spelled out in the T6 section. Not a dispute — the terminal (no TextractResult) is unaffected.

2. The map does not note that even after `:uploaded` makes `has_resume` true, `should_attach_external_resume_url?` requires `external_resume_status_pending?` so a later `show` will not re-enqueue (`job_application.rb:710`). This IS documented in the T7 section (lines 86-87), which T6 cross-references, so it is covered overall.

## Conclusion

All seven T6 statements verify against literal code. Omissions are cross-referenced elsewhere in the map, not gaps in the documented terminal. clean = true.
