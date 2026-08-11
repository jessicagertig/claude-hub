# textract-trigger ordering & concurrency (W2) — Round 1

Traced whether Textract is submitted exactly once and always on a Textract-acceptable format across the three submit sites, plus W1's synchronous pre-create preserving the stale/relink invariant.

Chain: `job_application.rb:164-171,689-702,733-751` -> `docx_to_pdf_job.rb:6-15` -> `job_applications_controller.rb:107-116` -> `submit_resume_to_textract.rb:8-41`.

## Findings

- **F1 [HIGH]** -- W2 introduces a PDF Textract DOUBLE-SUBMIT. SPEC.md W2 (line 53) says: in `DocxToPdfJob#perform`, "after `handle_possible_docx_resume` returns, enqueue `SubmitResumeToTextractJob.perform_later(@job_application.id)` gated on `Flipper.enabled?(...)`. Place it AFTER the `handle_possible_docx_resume` call so it runs whether conversion succeeded or failed." This enqueue is NOT conditioned on the resume being docx. But `DocxToPdfJob.perform_later` is enqueued UNCONDITIONALLY for every application -- `job_application.rb:166` (intake) and `job_applications_controller.rb:112` (T2, for any resume type). And the W2 `enqueue_new_job_application`/T2 branch already submits `SubmitResumeToTextractJob` at intake for the non-docx (PDF) path (SPEC.md line 52/54, the `else` branch). So for a PDF resume:
  1. intake `else` branch -> `SubmitResumeToTextractJob` (submit #1)
  2. `DocxToPdfJob#perform` runs (enqueued at `:166`): `handle_possible_docx_resume` returns early (not docx, `:734`), then the NEW unconditional enqueue fires `SubmitResumeToTextractJob` (submit #2)

  Result: every PDF resume submits Textract twice -> two `send_to_textract` AWS calls (cost), two `TextractResult` rows, a race between two `GetResumeTextFromTextractJob`, and ambiguous stale/relink/C7 handling. Today there is NO PDF double-submit (intake submits once; `DocxToPdfJob` does nothing Textract-related for PDF). This is a cost + correctness regression introduced by W2.

  Fix: condition the `DocxToPdfJob` Textract enqueue on `@job_application.resume_is_docx` (only docx deferred its submit; PDF already submitted at intake). Since `handle_possible_docx_resume` does its own `return unless resume_is_docx` (`:734`) but the new enqueue is OUTSIDE that method, the enqueue needs its own docx guard: e.g. `return unless @job_application.resume_is_docx` before it, or wrap `if @job_application.resume_is_docx && Flipper.enabled?(...)`. APPLIED.

- **F2 [LOW]** -- `DocxToPdfJob#perform` uses `@job_application` (correct ivar; SPEC.md line 53 uses `@job_application.job.organization` -- correct). But the Flipper org reference should match the existing sites for consistency: `enqueue_new_job_application` uses `job.organization` (`:167`), the controller uses `current_organization` (`:113`), and `DocxToPdfJob` should use `@job_application.job.organization` (matches the model site). SPEC.md line 53 already says `@job_application.job.organization` -- correct, no change. Noting for completeness; no amendment.

## Verified-correct (no change)
- Non-docx-non-PDF resume (e.g. image/txt) and no-resume: `resume_is_docx` returns nil (`:698` `return unless resume_content_type`; non-matching content type), so the intake `else` branch fires (submits Textract, matching today). With F1's docx guard added, `DocxToPdfJob` does NOT also submit for these (correct -- no new double). The Textract no-op for no-resume (`submit_resume_to_textract.rb:10`) is unchanged. CONFIRMED.
- docx conversion FAILURE: `handle_possible_docx_resume` rescues internally (`:747-751`), `resume_docx_to_pdf` not attached; with F1's docx guard the new enqueue STILL fires (it is after the call, guarded only on docx, not on conversion success), so `SubmitResumeToTextract` submits the raw docx (`:15` falls back to `resume`) -> Textract fails -> W1 summary eventually -> C8 `record_failure`. Same as today (no regression), candidate recoverable. The ONLY skip is a raise from `JobApplication.find` at `docx_to_pdf_job.rb:7` (caught by the `perform` rescue `:12-15`) -- acceptable. CONFIRMED.
- Defense-in-depth gating: all three submit sites stay `TEXTRACT_RESUME_PROCESSING`-gated (intake `:167`, controller `:113`, new `DocxToPdfJob` enqueue per spec). CONFIRMED. Spec correctly keeps the gate on the moved enqueue (hub "Hard rules cannot be rationalized away").
- W1 stale/relink ordering under W2: the W1 summary is created synchronously at intake regardless of docx/PDF; for docx the `SubmitResumeToTextractJob` is deferred to `DocxToPdfJob`, but whenever it runs, `submit_resume_to_textract.rb:18` sees the `textract_processing`/`stale:false` summary -> skips `update_all(stale:true)` -> relink `:25-26`. The deferral does not break the invariant. CONFIRMED.
- Out-of-scope recovery actors (`validate_ai_summary_generation.rb:39,55`, `queue_bulk_ai_summary_jobs.rb:29`) remain docx-race-exposed -- SPEC.md line 58 correctly scopes them out (lower severity, run after conversion usually completes). CONFIRMED (approved baseline).
- One-params-method rule: the controller change is control-flow only (no new params method). CONFIRMED (SPEC.md line 54).

## Amendments Applied
- SPEC.md W2 (line 53): condition the new `DocxToPdfJob` `SubmitResumeToTextractJob` enqueue on `@job_application.resume_is_docx` (guard before the enqueue) to prevent the PDF double-submit; clarified that `DocxToPdfJob` runs for all resume types so the docx guard is required.
