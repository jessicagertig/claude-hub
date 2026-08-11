# S-D Pass-3 Adversarial Review — Resume-replacement re-generation

Re-audited from scratch against current code. Slice S-D = a prior summary already exists (succeeded) for a job_application and a new resume/Textract result arrives.

## Files traced
- `app/services/submit_resume_to_textract.rb`
- `app/models/textract_result.rb`
- `app/services/ai_job_application_action/orchestrate.rb`
- `app/services/ai_job_application_action/summary/generate.rb`
- `app/interactors/create_ai_summary_generation.rb`
- `app/interactors/find_or_create_ai_job_application_summary_status.rb`
- `app/models/ai_job_application_summary.rb`
- `app/jobs/generate_ai_job_application_summary_job.rb`
- `app/models/job_application.rb` (assoc :29,:31,:32; latest_textract_result :685-687; find_or_create :160-162; enqueue :164-171)
- `app/models/job.rb` (should_auto_generate_ai_summaries? :914-922)

## Verdicts on candidate-map S-D claims (lines 111-117, 158-162)

### AGREE
1. **Prior succeeded summary becomes succeeded+stale via `update_all(stale: true)`** — `submit_resume_to_textract.rb:18-20`. The stale-marking `unless ...where(status: :textract_processing, stale: false).exists?` is true for a succeeded prior summary (not textract_processing), so `update_all(stale: true)` runs; `update_all` sets only `stale`, status stays `succeeded`. New `in_progress` result built at `:22`. AGREE.
2. **New TextractResult has ZERO associated summaries; `:25-26` relinks ONLY textract_processing waiting summaries** — `submit_resume_to_textract.rb:25` `find_by(status: :textract_processing, stale: false, textract_result_id: nil)`; the prior summary is `succeeded` so it is not relinked and stays on the OLD result. AGREE.
3. **Auto path: `Orchestrate#call` selects latest summary JobApplication-scoped, no stale filter** — `orchestrate.rb:15` `@job_application.ai_job_application_summaries.order(created_at: :desc).first`; picks up the stale-succeeded summary; `:16` `return unless @ai_job_application_summary` passes (non-nil). AGREE.
4. **`succeeded` branch returns; `run_summary`/`Summary::Generate` never runs** — `orchestrate.rb:46-48` matches `status_succeeded?` → `return`. `run_summary` (`:63-66`) is the only caller of `Summary::Generate` (`:64`), reached only from the pending/textract_processing/extracting/summarizing/retrying branches (`:22-34`). Never reached → no new summary. AGREE. (Note: `Summary::Generate.create` at `generate.rb:35` is the first-summary creator but is unreachable here.)
5. **MAP-WRONG correction that old "charges 1 credit" is FALSE; no credit on auto path** — `generate_ai_summary_with_credit_flow` re-fetches at `textract_result.rb:77` `ai_job_application_summaries.order(created_at: :desc).first` = `self.ai_job_application_summaries` (TextractResult has_many, `:5`), scoped to the NEW result which is empty → nil; `:82` `return unless ai_job_application_summary&.status_succeeded?` returns; `:84` `CreateAiCreditBalanceTransaction` (the only consumption site in app/) never reached. AGREE.
6. **Scope distinction `orchestrate.rb:15` (JobApplication-scoped) vs `textract_result.rb:77` (TextractResult-scoped)** — verified both literally. `:15` uses `@job_application.ai_job_application_summaries`; `:77` uses bare `ai_job_application_summaries` inside a TextractResult instance method = `self.ai_job_application_summaries`. AGREE.
7. **`textract_result.rb:67-68` guard does NOT short-circuit** — `:67` `latest_ai_summary = job_application.latest_ai_job_application_summary` (`job_application.rb:31` has_one ordered desc, NO stale filter → returns the stale-succeeded summary); `:68` `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`. Stale-succeeded: `status_succeeded?` true but `!stale?` false → guard false → flow continues into `find_or_create…`. AGREE.
8. **Status row set to 'regenerating', driven by status row's own `ai_job_application_summary` pointer at find_or_create :12, not latest_ai_job_application_summary** — credit-flow `:70` → `find_or_create_ai_job_application_summary_status` (`job_application.rb:160-162`). `find_or_create_ai_job_application_summary_status.rb:11` `if @status_record` (row exists, eagerly created), `:12` `summary = @status_record.ai_job_application_summary` (pointer to prior succeeded summary, set when it succeeded via `update_summary_status_record` `ai_job_application_summary.rb:74-76`), `:14` `if summary&.status_succeeded?` true → `:15` `update_columns(status: 'regenerating')`. AGREE.
9. **Status row NEVER reset to 'current'** — reset is `update_summary_status_record` (`ai_job_application_summary.rb:30,57`), after_commit on:update, gated `:69` `saved_change_to_status? && status_succeeded?`. On the auto S-D path no summary is ever status-updated to succeeded (the stale one's status is never changed), so it never fires. AGREE. Also `set_initial_summary_pending` (`textract_result.rb:98-108`) no-ops: `:102` requires `status_none? || status_initial_summary_pending?`, but the row is now 'regenerating'. AGREE.
10. **Stuck-'regenerating' with stale denormalized data, no new generation, no credit** — terminal state confirmed. AGREE.
11. **MANUAL regen variant works** — `CreateAiSummaryGeneration` `:30-34` `.where.not(status: :failed).where(stale: false).order(created_at: :desc).first` excludes the stale-succeeded summary → `active_ai_summary` nil; `:36-38` staling guard; with textract ready `validation_result.textract_pending` false → `:60-64` builds NEW `:pending` summary attached to `validation_result.textract_result` (the new result), `:70-74` saves + enqueues `GenerateAiJobApplicationSummaryJob`. `textract_result.rb:77` then finds that NEW summary on the new result → `:82` passes → `:84` charges credit on success. AGREE.

### RECONCILIATION NOTE (lines 158-162)
AGREE. Both scope claims verified: `orchestrate.rb:15` JobApplication-scoped picks up the stale-succeeded summary (so `:16` passes and the `succeeded` branch returns), and `textract_result.rb:77` TextractResult-scoped is empty on the new result (so `:82` returns nil → no credit). The two-scenario split (S-C no pre-existing summary vs S-D stale-succeeded) is accurate.

## DISPUTES
None. Every S-D statement verified against literal code.

## OMISSIONS (map does not state these for S-D)
1. **`ai_summary_status_change` broadcast fires on the 'regenerating' transition.** `find_or_create_ai_job_application_summary_status.rb:16-20` broadcasts `JobChannel ... event: 'ai_summary_status_change'` immediately after `update_columns(status: 'regenerating')` at `:15`. The map's S-D section (line 116) names the 'regenerating' write but omits that this same code path emits a JobChannel broadcast. (Per F1, that event invalidates only the single-summary + single-job-application queries, NOT the infinite list — so the stale denormalized score keeps rendering on the list.)
2. **Bridge entry on the auto S-D path: which branch of `queue_ai_summary_job`.** The map's S-D section does not state that the auto path enters via the `else` branch of `queue_ai_summary_job` (`textract_result.rb:137-143`): no `textract_processing, stale:false` waiting summary exists (`:121-123`), so it takes the auto branch, gated on `should_auto_generate_ai_summaries?` (`:138`, `job.rb:914-922`), re-validates (`:140`), and enqueues `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)` with NO requesting user (`:142`) → no `AI_SUMMARY_COMPLETE` toast (`generate_ai_job_application_summary_job.rb:34` requires `requesting_organization_user_id`). This is the entry actor that reaches `generate_ai_summary_with_credit_flow`; cross-referenced in the T-C/Trigger-C section but not tied into the S-D trace.
3. **The branch-logic checkpoint (textract-ready vs not-ready) for S-D.** Slice instructions ask which branch the path takes. For S-D auto, the new TextractResult reaches `succeeded` with text (`textract_job_result_text` present) before the bridge runs (`queue_ai_summary_job` `:115` returns unless text present), so the path is the textract-READY branch — it proceeds straight into the AI pipeline attempt (Orchestrate) rather than parking a summary at `textract_processing`. The map records the outcome but not this branch designation explicitly for S-D.

## Record-write sites on the S-D auto path
- `submit_resume_to_textract.rb:19` `@job_application.ai_job_application_summaries.update_all(stale: true)` — col `stale` (update_all).
- `submit_resume_to_textract.rb:22-24` build+save new `TextractResult` (status in_progress).
- `find_or_create_ai_job_application_summary_status.rb:15` `@status_record.update_columns(status: 'regenerating')` — col `status` (update_columns). NO denormalized columns cleared (score_percentage/headline/integrated_role_analysis retain prior values → desync window).
- (No write to any `AiJobApplicationSummary`; no `CreateAiCreditBalanceTransaction`; status row never advanced off 'regenerating'.)

clean = false (omissions present; all verdicts AGREE).
