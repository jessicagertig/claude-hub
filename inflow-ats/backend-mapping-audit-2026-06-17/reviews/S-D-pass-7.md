# S-D Pass-7 Adversarial Review — Resume-replacement re-generation

**Slice:** S-D — a prior summary already exists for the job_application and a new resume/Textract result arrives.
**Method:** Re-read all S-D-relevant code from scratch; attempted to refute every map statement against literal code.

## Files opened and traced
- `backend-flow-map-2026-06-17.md` (S-D section, Trigger D lines 185-197, Reconciliation 269-274, Part-9 §665, Part-7 718)
- `app/models/textract_result.rb` (1-161)
- `app/services/submit_resume_to_textract.rb` (1-42)
- `app/services/ai_job_application_action/orchestrate.rb` (1-106)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` (1-47)
- `app/models/ai_job_application_summary.rb` (1-100)
- `app/interactors/create_ai_summary_generation.rb` (1-80)
- `app/interactors/create_bulk_ai_summary_generation.rb` (1-59)
- `app/models/job_application.rb` (28-37, 160-171, 685-691)
- `app/models/job.rb` (914-921)
- `app/interactors/validate_ai_summary_generation.rb` (20-59)
- `app/controllers/api/v1/job_applications_controller.rb` (104-123)
- `app/jobs/generate_ai_job_application_summary_job.rb` (1-78)
- `app/interactors/queue_bulk_ai_summary_jobs.rb` (32-43)

## Verdicts (all AGREE)

1. **Prior succeeded summary → succeeded+stale via `update_all(stale:true)` guarded by the textract_processing/stale:false `unless`.** AGREE — `submit_resume_to_textract.rb:18` guard, `:19` `update_all(stale: true)`, `:22` builds new `in_progress` result, `:25-26` relinks only `textract_processing` waiting summaries. In the S-D scenario the only summary is succeeded (not textract_processing), guard passes, update applies.

2. **New result reaches succeeded WITH text; bridge takes ELSE/auto branch (no textract_processing/stale:false waiting summary), gated on `should_auto_generate_ai_summaries?`, enqueues with NO requesting user.** AGREE — `textract_result.rb:115` text guard, `:121-123` waiting-summary query, `:137` else, `:138` auto-gen gate, `:140` re-validate, `:142` enqueue `if result.success?` with no requesting user. `job.rb:914-921` confirms the gate semantics.

3. **Auto-gen OFF → bridge returns at `:138`; status row never flipped to regenerating, stays `current` with stale denormalized data; prior summary stays stale with no actor.** AGREE — `textract_result.rb:138` `return unless ...should_auto_generate_ai_summaries?`.

4. **Auto-gen ON: Orchestrate selects latest summary JobApplication-scoped no-stale-filter (picks the stale-succeeded one), `:16` passes, succeeded branch returns `:46-48`, run_summary never runs.** AGREE — `orchestrate.rb:15` `@job_application.ai_job_application_summaries.order(created_at: :desc).first`, `:16`, `:46-48` succeeded/failed → return.

5. **No credit charged on the auto path (scope difference).** AGREE — `textract_result.rb:77` `ai_job_application_summaries.order(created_at: :desc).first` is `self.ai_job_application_summaries` (the new TextractResult's own `has_many`, `:5`), empty on the freshly built result → `:82` `return unless ai_job_application_summary&.status_succeeded?` returns → `:84` `CreateAiCreditBalanceTransaction` never reached. The JobApplication-scoped `orchestrate.rb:15` vs TextractResult-scoped `textract_result.rb:77` distinction is real.

6. **`textract_result.rb:67-68` guard does NOT short-circuit (stale-succeeded fails `!stale?`).** AGREE — `:68` `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`; a stale summary fails the `!stale?` conjunct, so flow continues.

7. **Status row set to `regenerating`, driven by the STATUS ROW's own denormalized `ai_job_application_summary` pointer at `:12` (not `latest_ai_job_application_summary`); never reset to `current`.** AGREE — `find_or_create_ai_job_application_summary_status.rb:12` `summary = @status_record.ai_job_application_summary`, `:14` `if summary&.status_succeeded?`, `:15` `update_columns(status: 'regenerating')`. The prior `current` row points (via `update_summary_status_record`, `ai_job_application_summary.rb:75`) at the now-stale-succeeded summary, which still reports `status_succeeded?` true (staling does not change status). Reset to current only via `ai_job_application_summary.rb:69` on a summary update→succeeded, which never happens on this path.

8. **`regenerating` flip emits JobChannel `ai_summary_status_change` broadcast immediately after the `update_columns`.** AGREE — `find_or_create_ai_job_application_summary_status.rb:16-20`.

9. **`update_summary_status_record` never fires on this path (guarded on `saved_change_to_status? && status_succeeded?`).** AGREE — `ai_job_application_summary.rb:69`; no summary reaches a succeeded `.update`.

10. **`regenerating` flip writes status-only (`update_columns(status: 'regenerating')`), leaving OLD score/headline/integrated_role_analysis/ai_job_application_summary_id → stuck row renders OLD data.** AGREE — `find_or_create_ai_job_application_summary_status.rb:15` writes only `status`.

11. **`set_initial_summary_pending` no-ops on the S-D auto path: `find_or_create` flips to `regenerating` first (`:70`), then `:72` runs but the `:102` guard (`status_none? || status_initial_summary_pending?`) fails against `regenerating`.** AGREE — `textract_result.rb:70` then `:72`; `set_initial_summary_pending` `:102` guard blocks; `:104-107` not executed.

12. **Validation-failure-after-Textract sub-terminal (auto-gen ON): re-validate `:140`, enqueue only `if result.success?` `:142`; ValidateAiSummaryGeneration can fail on credits (`:28`)/job-description (`:29`); on failure `find_or_create` (`:70`) never runs, row stays `current` stale, prior summary stays succeeded+stale, silent no-op.** AGREE — `validate_ai_summary_generation.rb:28-29` fail sites; `textract_result.rb:140,142` enqueue gate; the else branch has no failure handler.

13. **MANUAL regen (S-A) recovers: `CreateAiSummaryGeneration` filters `where(stale:false)` (and `where.not(status: :failed)`), excludes the stale-succeeded summary, stales mismatched-textract active summaries, builds a NEW `:pending` on the new result, enqueues the job; `textract_result.rb:77` finds the new summary → credit on success → `update_summary_status_record` resets row to `current`.** AGREE — `create_ai_summary_generation.rb:30-34,36-38,60-64,70-74`.

14. **BULK regen (S-B) also recovers identically: `CreateBulkAiSummaryGeneration` `where(stale:false)`+`where.not(status: :failed)`, mismatch-stale, builds `:pending`; bulk pre-filter drops only `:current` rows, so a stuck-`regenerating` row IS processed.** AGREE — `create_bulk_ai_summary_generation.rb:34-38,40-42,50-54`; `queue_bulk_ai_summary_jobs.rb:36-40` filters `status: :current` only.

15. **Controller T2 entry (user-facing form of S-D): resume replaced via `job_application.update(temp_params)` `:107`, Textract enqueue gated on `temp_params.key?(:resume) && temp_params[:resume].present?` `:110` AND `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, current_organization)` `:113-114`; DocxToPdfJob co-enqueued `:112`. Flag-OFF → no Textract, prior summary stays succeeded+non-stale, row stays current.** AGREE — `job_applications_controller.rb:107,110,112,113-114`.

16. **Auto path produces no `AI_SUMMARY_COMPLETE` toast.** AGREE — bridge enqueues with no `requesting_organization_user_id` (`textract_result.rb:142`); `generate_ai_job_application_summary_job.rb:34` broadcasts only `if requesting_organization_user_id`.

## Which summary record each step operates on (S-D, the slice question)
- `SubmitResumeToTextract` builds a NEW `in_progress` TextractResult (`submit_resume_to_textract.rb:22`) with ZERO associated summaries; the prior succeeded summary stays on the OLD result and is marked `stale:true` (`:19`).
- The bridge else branch / `generate_ai_summary_with_credit_flow` → `Orchestrate#call` selects `@job_application.ai_job_application_summaries.order(created_at: :desc).first` (`orchestrate.rb:15`) = the SINGLE stale-succeeded summary (no stale filter, JobApplication-scoped). It is the newest because no newer summary was built on the auto path.
- That summary's status is `succeeded`, so Orchestrate returns at `:46-48` — it operates on (reads, does not advance) the stale-succeeded summary. No new summary is created.
- Resting state (auto-gen ON): stale-succeeded summary unchanged; status row STUCK at `regenerating` with OLD denormalized data; no credit; no advancing actor until a later MANUAL (S-A) or BULK (S-B) regen builds a fresh `:pending`.
- Resting state (auto-gen OFF, or validate-fail after Textract): status row stays `current` with stale denormalized data; prior summary stays succeeded+stale; no actor.

## Omissions
None found. The S-D section (including pass-2/3/5/6 corrections) anchors every stated mechanism on the correct file:line, including the branch checkpoint (textract-READY vs textract_processing-wait), the auto-gen gate fork, the scope-difference credit no-op, the `:102` guard suppression of `set_initial_summary_pending`, the validation-failure sub-terminal, and the manual+bulk recovery paths.

## Conclusion
clean = true. Every S-D statement verified AGREE against literal code; omissions empty.
