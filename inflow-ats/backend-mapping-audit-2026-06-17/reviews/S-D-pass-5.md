# S-D Adversarial Review — Pass 5

**Slice:** S-D — Resume-replacement re-generation (a prior summary already exists for the job_application; a new resume/TextractResult arrives).
**Candidate map:** `/Users/jessica/claude-hub/inflow-ats/backend-mapping-audit-2026-06-17/backend-flow-map-2026-06-17.md`
**Method:** Re-read all S-D code from scratch; attempted to refute every S-D statement against literal code.

## Files traced
- `app/services/submit_resume_to_textract.rb` (`:9-30`)
- `app/models/textract_result.rb` (`:5`, `:61-89`, `:98-108`, `:110-112`, `:114-144`)
- `app/services/ai_job_application_action/orchestrate.rb` (`:6,15-16,46-48,63-64,72`)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` (`:9-44`)
- `app/models/ai_job_application_summary.rb` (`:10-31,57-95`)
- `app/models/job_application.rb` (`:29-32,160-171`)
- `app/models/job.rb` (`:914-922`)
- `app/jobs/generate_ai_job_application_summary_job.rb` (`:24-34`)
- `app/interactors/create_ai_summary_generation.rb` (`:30-78`)
- `app/interactors/create_bulk_ai_summary_generation.rb` (`:34-57`)

## Verdicts (all AGREE)

1. **Prior succeeded summary → `succeeded + stale:true` via `update_all(stale: true)` (`submit_resume_to_textract.rb:18-19`), conditional on `unless ...where(status: :textract_processing, stale: false).exists?` (`:18`); new `in_progress` TextractResult built at `:22` has ZERO summaries (relink `:25-26` only handles `textract_processing` waiting summaries).** AGREE — code matches exactly. `update_all` bypasses callbacks, status stays `succeeded`. The `find_by(status: :textract_processing, stale: false, textract_result_id: nil)` at `:25` finds nothing in S-D.

2. **New result reaches `succeeded` WITH text; bridge takes the ELSE branch (no `textract_processing`/`stale:false` waiting summary, `textract_result.rb:121-123`); textract-READY branch, gated on `should_auto_generate_ai_summaries?` (`:138`), re-validates (`:140`), enqueues with NO requesting user (`:142`) → no AI_SUMMARY_COMPLETE toast.** AGREE — `:115` text guard, `:121-123` selector, `:137-143` else branch, `:142` no requesting_organization_user_id. `generate_ai_job_application_summary_job.rb:34` broadcast gated on `requesting_organization_user_id` → no toast.

3. **Auto-gen GATE: OFF → bridge returns at `:138`, row never flipped, stays `current` stale, prior summary `stale:true` no further actor; ON → STUCK `regenerating`.** AGREE — `:138` `return unless job_application&.job&.should_auto_generate_ai_summaries?`; `job.rb:914-922` confirms semantics.

4. **`Orchestrate#call` selects JobApplication-scoped `order(created_at: :desc).first` (NO stale filter, `:15`), picks the stale-succeeded summary; `:16` passes; succeeded branch returns (`:46-48`); `run_summary`/`Summary::Generate` never runs → no new summary.** AGREE — `:15-16`, `:46-48` exact. `run_summary` at `:63-64` unreached.

5. **MAP-WRONG correction (no credit): credit re-fetch `textract_result.rb:77` is `self.ai_job_application_summaries` (TextractResult-scoped, has_many `:5`), EMPTY on the new result → `:77` nil → `:82` returns → `:84` (`CreateAiCreditBalanceTransaction`) never reached. NO credit.** AGREE — `:77` is the TextractResult's own has_many; new result has zero summaries; `:84` is the sole app-code credit site (grep-confirmed: only `textract_result.rb:84`). The scope distinction vs `orchestrate.rb:15` (JobApplication-scoped) is real and load-bearing.

6. **`textract_result.rb:67-68` guard does NOT short-circuit (stale-succeeded fails `!stale?`).** AGREE — `:68` `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`; stale-succeeded → `!stale?` false → no return.

7. **Status row set to `'regenerating'` via `find_or_create_ai_job_application_summary_status.rb:14-15`, driven by the STATUS ROW's denormalized `ai_job_application_summary` pointer at `:12` (not `latest_ai_job_application_summary`); never reset to `current` (`update_summary_status_record` fires only on summary update→succeeded, `ai_job_application_summary.rb:69`).** AGREE — `:12` `summary = @status_record.ai_job_application_summary`; `:14` `if summary&.status_succeeded?` (no stale check, so stale-succeeded still flips); `:15` `update_columns(status: 'regenerating')` (status-only). `ai_job_application_summary.rb:69` guard exact.

8. **`regenerating` transition emits JobChannel `ai_summary_status_change` broadcast (`:16-20`).** AGREE — `:16-20` exact; per F1 invalidates only single-summary/single-job-application queries.

9. **Ordering: `generate_ai_summary_with_credit_flow` runs `find_or_create` (`:70`, regenerating flip) BEFORE `set_initial_summary_pending` (`:72`) BEFORE `generate_ai_summary`/Orchestrate (`:74`).** AGREE — `:70,72,74` in that order; `:72` guarded `if status_result.success?`. (In S-D `set_initial_summary_pending` no-ops at `:102` since row is `regenerating`, not `none`/`initial_summary_pending`.)

10. **MANUAL regen variant recovers: `CreateAiSummaryGeneration` filters `where(stale: false)` (`:30-34`), stales mismatched-textract active summaries (`:36-38`), builds NEW `:pending` summary attached to `validation_result.textract_result`, enqueues (`:60-74`); `textract_result.rb:77` then finds the NEW summary on the new result → credit charged on success.** AGREE — `:30-34,36-38,60-74` exact.

11. **`update_summary_status_record` re-points `ai_job_application_summary_id: id` UNCONDITIONALLY (`ai_job_application_summary.rb:75`) and writes `status: 'current'` via `.update` (`:74-80`) — sole writer reconciling a `regenerating` stale-pointer row back to `current`.** AGREE — `:74-80` exact.

12. **Part 9 §4 / 5.3 dead-end framing (stuck `regenerating` with OLD denormalized score/headline/analysis; auto-gen OFF stays `current` stale; no credit).** AGREE — consistent across map sections (lines 38, 156, 158, 297-298, 540, 547, 606, 614, 666-667, 753); all match code.

## Omissions

1. **Recovery is not "only on a later MANUAL regeneration (T9/S-A)" — BULK (S-B) recovers the stuck `regenerating` row too.** The map states recovery to `current` happens "only on a later MANUAL regeneration (T9/S-A)" (lines 38, 158, 299). But `CreateBulkAiSummaryGeneration` (`create_bulk_ai_summary_generation.rb:34-43`) filters `where(stale: false)` and stales mismatched-textract active summaries identically to `CreateAiSummaryGeneration`, so it excludes the stale-succeeded summary and builds a fresh `:pending` summary (`:50-54`) on the new result. Furthermore the bulk pre-filter only drops `status: :current` rows (`queue_bulk_ai_summary_jobs.rb:36-40`); a stuck-`regenerating` row is NOT `:current`, so the candidate is processed and recovers to `current` on success via `update_summary_status_record`. The map's Trigger-D/T2 recovery note should read "later MANUAL (S-A) OR BULK (S-B) regeneration," not manual-only. (The map's 5.3 `regenerating`-row "Reached by" cell does list "B bulk regen" as a regenerating-reacher, but the S-D recovery prose singles out manual.)

## clean = false
Reason: omission #1.
