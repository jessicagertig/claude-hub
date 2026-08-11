# T1 — Pass 2 Adversarial Review

**Slice:** T1 — New job application created. Trigger: `JobApplication after_commit :enqueue_new_job_application, on: [:create]` → `SubmitResumeToTextractJob`.
**Method:** Re-read current code from scratch; attempted to refute every T1 statement in `backend-flow-map-2026-06-17.md`.

## Files traced
- `app/models/job_application.rb:45` (callback reg), `:160-162` (wrapper), `:164-171` (body), `:83-92` (created_via enum)
- `app/jobs/submit_resume_to_textract_job.rb`
- `app/services/submit_resume_to_textract.rb`
- `app/services/get_resume_text_from_textract.rb`
- `app/jobs/get_resume_text_from_textract_job.rb`
- `app/interactors/find_or_create_ai_job_application_summary_status.rb`
- `app/models/textract_result.rb:114-144` (queue_ai_summary_job)
- Creation-source census: `app/interactors/create_candidate_job_application.rb:16`, `create_job_application.rb:23`, `customer_api/create_job_application.rb:29,50`, `api_public/v1/hire/jobs_controller.rb:27,29`, `api/v1/public/jobs_controller.rb:36,38,43`, `import_job_candidates_from_csv_job.rb:17,20`
- Flipper census: only `job_application.rb:167` and `job_applications_controller.rb:113`

## Verdicts

### AGREE
1. Callback reg at `job_application.rb:45` `after_commit :enqueue_new_job_application, on: [:create]`. Body `:164-171`. CONFIRMED literal.
2. `enqueue_new_job_application` enqueues `NewJobApplicationJob` (`:165`), `DocxToPdfJob` (`:166`), Flipper-gated `SubmitResumeToTextractJob` (`:167-169`), then UNCONDITIONAL `find_or_create_ai_job_application_summary_status` (`:170`). CONFIRMED literal.
3. Flipper `TEXTRACT_RESUME_PROCESSING` scoped to `job.organization` at `:167`. CONFIRMED.
4. Status-row creation NOT Flipper-gated; status row created `'none'` on fresh app (`find_or_create_ai_job_application_summary_status.rb:34` `@status_record.status = 'none'`, save `:37`). CONFIRMED — the create-path's only non-`none` outcome requires a pre-existing succeeded+non-stale summary (`:27-32`), which a fresh app cannot have.
5. Flipper checked at exactly two app sites (`job_application.rb:167`, `job_applications_controller.rb:113`). CONFIRMED via grep — no third site.
6. `created_via` enum has 8 values `:83-91`. CONFIRMED literal.
7. Source-agnostic (`on: [:create]`); all creation sites use `.save`/`.build`+save — no `insert_all` bypass for job_applications (grep returned none). CONFIRMED.
8. TextractResult terminal for T1: `in_progress` (`submit_resume_to_textract.rb:22`, saved `:24`) → `GetResumeTextFromTextractJob` (+2min, `:27`) → `succeeded` via `.update` (`get_resume_text_from_textract.rb:31`) firing `queue_ai_summary_job`. CONFIRMED.
9. T1 no-summary case takes the `else` (auto-generate) branch in `queue_ai_summary_job` (`textract_result.rb:137`), gated on `should_auto_generate_ai_summaries?` (`:138`). CONFIRMED — `ai_summary_waiting_on_textract` is nil for a fresh app (no textract_processing summary exists).
10. Retry exhaustion `cleanup_orphaned_summary` no-op when no waiting summary (`get_resume_text_from_textract_job.rb:16` `return unless summary`). CONFIRMED — true for T1 fresh-create.
11. Old-map MAP-WRONG quotes accurate: old map line 70 says `job_application.rb:150-156`; old map omits the status-row call. CONFIRMED against old map.

## DISPUTE (internal map inconsistency, T1 terminal trace)

12. **Part 1 narrative line-number drift.** Map Part 1 (line 164 of the map) says AWS-failed write is `get_resume_text_from_textract.rb:40` `update_columns(textract_job_status: 'failed')` then raise — this matches. But the map's running prose earlier (`### Polling` item 5 "line 39" / item 7 "line 46") cites `:39` and `:46`. Actual code: AWS-failed `update_columns` is at `get_resume_text_from_textract.rb:40`; InvalidJobId `update_columns` is at `:47`. The 5.1 table (map lines 414-415) is CORRECT (40, 47); the Part-1 narrative bullets (map lines 164, 166) are off by one (39, 46). Minor, but the narrative line refs do not match code.

## OMISSIONS (T1)

- **`has_resume` short-circuit not stated for T1 fresh-create.** For T1, `SubmitResumeToTextract` returns `'No resume attached'` at `submit_resume_to_textract.rb:10` and creates NO TextractResult when the new application has no resume attached at creation. The map documents this for T5/T6 but the T1 section (map :176-181) does not note that a resume-less new application produces no TextractResult — T1 only reaches `in_progress` when a resume is present at creation. This is a real T1 branch (the textract-not-ready vs ready fork at the very entry).
- **Self-healing re-submit loop not tied to T1.** `get_resume_text_from_textract.rb:14-17`: if `textract_job_id` is nil, re-enqueues `SubmitResumeToTextractJob` and returns. Reachable on the T1 poll path; not mentioned in the T1 section.
