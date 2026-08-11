# T9 Adversarial Review — Pass 7

**Slice:** T9 / Trigger A — Manual single generation, no-TextractResult sub-path: `ValidateAiSummaryGeneration` kicks off Textract; trace the validate path and the state the summary is left in.

**Files re-read from scratch:**
- `app/interactors/validate_ai_summary_generation.rb` (full)
- `app/controllers/api/v1/ai_job_application_summaries_controller.rb` (full)
- `app/interactors/create_ai_summary_generation.rb` (full)
- `app/services/submit_resume_to_textract.rb` (full)
- `app/models/job_application.rb:685-687` (`latest_textract_result`)
- `app/models/textract_result.rb:110-144` (`queue_ai_summary_job`, bridge)

Trace chain: `ai_job_application_summaries_controller.rb:8` → `validate_ai_summary_generation.rb:38-42` → `submit_resume_to_textract.rb:22` (async, later) ; `controller:17` → `create_ai_summary_generation.rb:30-58` ; later bridge `textract_result.rb:114-143`.

---

## Verdicts on candidate-map T9 statements

All claims below verified AGREE against literal code.

1. **"`has_job_description?` fail-fast guard at `validate_ai_summary_generation.rb:29`, def `81-83`."** AGREE — `:29` `context.fail!(...) unless has_job_description?`; `:81-83` `@job_application.job&.description.present?`.

2. **"Fail-fast chain precedes the Textract submit: `:24-25` nil guards, `:26` flipper, `:27` has_resume, `:28` credits, `:29` has_job_description."** AGREE — lines 24,25,26,27,28,29 exactly as cited; all `context.fail!` precede the `:38` branch.

3. **"After `context.textract_result` assigned (`:31-32`): `:38-42` unless @latest_textract_result → submit + textract_pending=true + return."** AGREE — `:31` assign `@latest_textract_result`, `:32` `context.textract_result = @latest_textract_result`; `:38` `unless @latest_textract_result`, `:39` `SubmitResumeToTextractJob.perform_later(@job_application.id)`, `:40` `context.textract_pending = true`, `:41` `return`.

4. **"`:44-45` textract_text_ready? → textract_pending=false; `:46-57` latest-failed-but-prior-not → re-submit `:55` + textract_pending `:56`; `:52-53` both-failed fail!; `:58-59` else → textract_pending=true."** AGREE — `:44` `if textract_text_ready?`, `:45` false-set; `:46` `elsif ...failed?`; `:52` `if previous_textract_result&.textract_job_status_failed?`, `:53` fail!; `:55` re-submit, `:56` pending; `:58` `else`, `:59` `context.textract_pending = true`.

5. **"CHANGED — no-TextractResult branch is `:38-42` (was `:37-41`)."** AGREE — current branch is `:38-42`; the new `has_job_description?` guard at `:29` shifted lines down by one.

6. **"MAP-WRONG (old map) — `context.textract_result` assigned unconditionally at `:31-32`, nil on the no-result path; `latest_textract_result` def `job_application.rb:685-687`, nil when none."** AGREE — `:31-32` assign before any branch; `job_application.rb:685-687` `textract_results.order(created_at: :desc).first`.

7. **"T9 waiting-summary terminal carries `requested_by_organization_user_id` (`create_ai_summary_generation.rb:47-51`, `:50`), sourced from `context.user` (`controller:20`)."** AGREE — `:47-51` builds `textract_processing` summary with `requested_by_organization_user_id: context.user&.current_organization_user&.id` at `:50`; `controller:20` `user: current_user`.

8. **"Bridge threads requesting user into `GenerateAiJobApplicationSummaryJob` at `textract_result.rb:130`; if-branch re-validates `:126`."** AGREE — `:126` `ValidateAiSummaryGeneration.call(...)`, `:128-131` enqueue with `requesting_organization_user_id: ai_summary_waiting_on_textract.requested_by_organization_user_id` (`:130`).

9. **"Active-summary REUSE sub-case on no-Textract path: lookup `create_ai_summary_generation.rb:30-34` (`.where.not(status: :failed).where(stale: false).order(created_at: :desc).first`); mismatch guard `:36-39` treats `nil != nil` as false so a prior textract_processing/`textract_result_id: nil` summary is NOT staled; reused/returned `:41-44`; no build, no enqueue, while Validate already submitted Textract (`validate_ai_summary_generation.rb:39`)."** AGREE — `:30-34` exact query; `:36` `active_ai_summary.textract_result_id != job_application.latest_textract_result&.id` (nil-vs-nil = false on no-result path); `:41-44` reuse-return; submit confirmed at `validate_ai_summary_generation.rb:39`.

10. **"FRESH-BUILD sub-case: when active_ai_summary nil (`:34`), NEW `:textract_processing` summary built+saved `:47-53`, returned WITHOUT enqueue, waiting for the poll/bridge."** AGREE — `:46` `if validation_result.textract_pending`, `:47-51` build, `:53` `if ai_summary.save`, `:57` `return` (no `perform_later` in this arm).

11. **"textract-READY sub-branch off the same Create entry: when textract_pending false (`validate:44-45`), Create `:46` else arm builds `:pending` (`:60-64`), saves `:70`, enqueues `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: validation_result.textract_result.id, requesting_organization_user_id: context.user.current_organization_user.id)` (`:71-74`)."** AGREE — `:60-64` `:pending` build, `:70` save, `:71-74` synchronous enqueue.

12. **"Active-summary reuse/mismatch-stale runs before the `:46` branch, applies on ready path; matched-id reuse returns `:41-44` with no enqueue; mismatched staled via `update_columns(stale: true)` (`:37`) then fresh `:pending` `:60-64`."** AGREE — `:36-39` precedes `:46`; `:37` `active_ai_summary.update_columns(stale: true)`.

13. **"Asymmetric nil-safety: `:73` reads `context.user.current_organization_user.id` WITHOUT safe-nav; build sites `:50`/`:63` use `&.`."** AGREE — `:73` unguarded chain; `:50` and `:63` both `context.user&.current_organization_user&.id`.

14. **"async-ordering NOTE: nil-match relies on `latest_textract_result&.id` nil during synchronous Create because `validate:39` submit is async and `submit_resume_to_textract.rb:22` builds the in_progress TextractResult only when the job later runs."** AGREE — `submit_resume_to_textract.rb:22` `@job_application.textract_results.build(textract_job_id: ..., textract_job_status: 'in_progress')` runs inside the async job (`perform_later` at `validate:39`).

15. **"submit-time stale guard PRESERVES the waiting summary: `unless ...where(status: :textract_processing, stale: false).exists?` (`submit_resume_to_textract.rb:18`) TRUE → `update_all(stale: true)` (`:19`) SKIPPED; relink `:25-26`."** AGREE — `:18` guard, `:19` `update_all(stale: true)`, `:25` `find_by(status: :textract_processing, stale: false, textract_result_id: nil)`, `:26` `update_columns(textract_result_id: @textract_result.id)`.

16. **"On manual T9, Validate invoked WITHOUT user (`controller:8-11` passes only job_application + organization); user supplied only to Create (`:17-21`, `:20`). Pre-validate gates: authorize (`:6`), scoping via `exists(...)` (`:5`)."** AGREE — `controller:8-11` Validate args = job_application, organization only; `:17-21` Create with `user: current_user` at `:20`; `:5` `exists(current_organization.job_applications...)`, `:6` `authorize :ai_job_application_summary, :create?`.

17. **"Bridge waiting-summary query filters only `status: :textract_processing, stale: false`, no `textract_result_id` filter (`textract_result.rb:121-123`); found independent of relink."** AGREE — `:121-123` `where(status: :textract_processing, stale: false).first`, no id filter.

---

## Omissions

None material. The T9 section is exhaustive: it covers both no-Textract sub-cases (REUSE / FRESH-BUILD), the ready-path sibling branch, the failed/both-failed/in_progress sibling branches, the async-ordering dependency, the stale-guard preservation, the relink independence, and the no-user-on-Validate nuance. Every line citation re-verified against current code with zero discrepancies.

One minor co-location (not an omission of fact): the controller `create` wraps everything in `exists(current_organization.job_applications.where(id: params[:job_application_id]), ...)` (`:5`), so a job_application outside the current organization yields "Job application not found" before Validate runs — already captured by the `:5` scoping note in changelog line 169.

## Verdict

clean = true (all verdicts AGREE, omissions empty).
