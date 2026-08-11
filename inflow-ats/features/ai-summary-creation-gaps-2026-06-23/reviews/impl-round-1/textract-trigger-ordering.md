# textract-trigger ordering & concurrency (W2) — Round 1

Traced: `job_application.rb#enqueue_new_job_application:164-177` → `docx_to_pdf_job.rb:6-22` → `job_applications_controller.rb#update:110-116` → `submit_resume_to_textract.rb:8-30`.

## Findings

W2 is implemented correctly with defense-in-depth gating at every submit site:
- Intake (`job_application.rb:170`): `if !resume_is_docx && Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)` — PDFs submit directly, docx defers. `DocxToPdfJob.perform_later(id)` stays unconditional (viewer needs it).
- `DocxToPdfJob` (`docx_to_pdf_job.rb:15-18`): `return unless @job_application.resume_is_docx` (prevents the PDF double-submit), `return unless Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, ...)`, then enqueue. Placed AFTER `handle_possible_docx_resume` (line 8) and BEFORE the method-level `rescue` (line 19), so on conversion failure (rescued internally inside `handle_possible_docx_resume`) Textract is still attempted with the raw docx — no regression vs today.
- T2 controller (`job_applications_controller.rb:113`): `if !job_application.resume_is_docx && Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, current_organization)`, using the local block variable `job_application` (not an ivar). No second params method added — control-flow only.
- The W1 synchronous pre-create preserves the `submit_resume_to_textract.rb:18-26` stale/relink ordering: the `textract_processing`/`stale:false` W1 summary makes the `:18` guard true → `update_all(stale:true)` skipped → relink at `:25-26` attaches the new `TextractResult` to the W1 summary (built with `textract_result_id:nil`). Verified by reading.

No defense-in-depth gap; every Textract submit site re-checks `TEXTRACT_RESUME_PROCESSING`. No double-submit on the PDF path. No issues found. (Test gap for the controller branch is in `test-coverage.md`.)
