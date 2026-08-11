# S-D Adversarial Review — Pass 4

**Slice:** S-D — Resume-replacement re-generation (prior summary exists; new resume/Textract arrives).
**Method:** Re-read code from scratch; refute every map claim for S-D against literal code.

## Code chain traced

`app/services/submit_resume_to_textract.rb:8-41`
→ `app/models/textract_result.rb:7` (`after_commit :queue_ai_summary_job`)
→ `app/models/textract_result.rb:114-144` (`queue_ai_summary_job`, ELSE branch :137-143)
→ `app/models/job.rb:914` (`should_auto_generate_ai_summaries?`)
→ `app/interactors/validate_ai_summary_generation.rb:6-61`
→ `app/jobs/generate_ai_job_application_summary_job.rb:24-46` (`:32` calls credit flow)
→ `app/models/textract_result.rb:61-89` (`generate_ai_summary_with_credit_flow`)
→ `app/models/job_application.rb:160-162, 685-687, 31` (`find_or_create…`, `latest_textract_result`, `latest_ai_job_application_summary`)
→ `app/interactors/find_or_create_ai_job_application_summary_status.rb:6-45`
→ `app/services/ai_job_application_action/orchestrate.rb:9-50`
→ `app/models/ai_job_application_summary.rb:29-30,57-98` (`update_summary_status_record`)
→ `app/interactors/create_ai_summary_generation.rb:19-78` (manual variant)

## Verdicts

### Map line 129 — prior succeeded summary becomes succeeded+stale:true; new in_progress result has zero summaries
AGREE. `submit_resume_to_textract.rb:18-20` runs `@job_application.ai_job_application_summaries.update_all(stale: true)` (status untouched). `:22` builds the new `in_progress` result; `:25-26` relink only `status: :textract_processing, ..., textract_result_id: nil` summaries, so the prior succeeded summary stays on the OLD result.
Note: the `update_all` is CONDITIONAL on the `unless ... exists?` guard at `:18`; for the S-D scenario (prior summary succeeded, not textract_processing) the guard is false so update_all runs — outcome holds.

### Map line 130 — new result succeeds WITH text; bridge takes ELSE branch; no requesting user
AGREE. `textract_result.rb:115` `return unless textract_job_result_text.present?`; `:121-123` waiting query finds none (prior summary is succeeded, not textract_processing); `:137` else; `:138` `should_auto_generate_ai_summaries?` gate; `:140` re-validate; `:142` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)` with NO `requesting_organization_user_id` → no AI_SUMMARY_COMPLETE toast (`generate_ai_job_application_summary_job.rb:34` requires the id).

### Map line 131 — Orchestrate selects latest with no stale filter (JobApplication-scoped → old stale-succeeded); succeeded branch returns; run_summary never runs
AGREE. `orchestrate.rb:15` `@ai_job_application_summary = @job_application.ai_job_application_summaries.order(created_at: :desc).first` (no stale filter, JobApplication-scoped); `:16` passes; `:46-48` `when status_succeeded?, status_failed? → return`; `run_summary`/`Summary::Generate` at `:63-64` never runs.

### Map line 132 — NO credit charged; re-fetch at textract_result.rb:77 is TextractResult-scoped (empty on new result)
AGREE. `textract_result.rb:77` `ai_job_application_summary = ai_job_application_summaries.order(created_at: :desc).first` — bare `ai_job_application_summaries` is `self.ai_job_application_summaries`, the new TextractResult's has_many (`textract_result.rb:5`), empty on the new result → nil; `:82` `return unless ai_job_application_summary&.status_succeeded?` returns; `:84` `CreateAiCreditBalanceTransaction.call` never reached. The scope contrast (orchestrate.rb:15 JobApplication-scoped vs textract_result.rb:77 TextractResult-scoped) is exactly as the map states.

### Map line 133 — new :67-68 guard does NOT short-circuit (stale-succeeded fails !stale?)
AGREE. `textract_result.rb:67-68` `latest_ai_summary = job_application.latest_ai_job_application_summary` / `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`. Prior summary is stale → `!stale?` false → no return; flow continues to `:70` find_or_create.

### Map line 134 — status row set to 'regenerating' (driven by status-row's denormalized pointer at :12), never reset to 'current'; no credit (pure no-op)
AGREE. `generate_ai_summary_with_credit_flow:70` calls `find_or_create_ai_job_application_summary_status`; `find_or_create…:9` loads existing row; `:12` `summary = @status_record.ai_job_application_summary`; `:14` `if summary&.status_succeeded?` (true — update_all left status succeeded); `:15` `@status_record.update_columns(status: 'regenerating')`. No later summary reaches `succeeded`, so `update_summary_status_record` (`ai_job_application_summary.rb:69` `after_commit on: :update`, guarded `saved_change_to_status? && status_succeeded?`) never fires → row STUCK at `regenerating` with stale denormalized score/headline/analysis. No credit (per line 132). 
Sub-note verified: `:72 set_initial_summary_pending` is a no-op here because `:102` requires `status_none? || status_initial_summary_pending?` and the row is now `regenerating`.

### Map line 135 — regenerating transition emits JobChannel ai_summary_status_change
AGREE. `find_or_create…:16-20` `JobChannel.broadcast_to(job_application.job, event: 'ai_summary_status_change', payload: {...})` fired immediately after `:15`.

### Map line 136 — MANUAL regen variant works (filters stale:false, stales mismatched, builds NEW pending, enqueues; textract_result.rb:77 finds NEW summary → credit on success)
AGREE. `create_ai_summary_generation.rb:30-34` `active_ai_summary = ... where.not(status: :failed).where(stale: false).order(created_at: :desc).first` excludes the stale-succeeded summary; `:36-38` stales a mismatched-textract active summary; `:60-64` builds NEW `:pending` attached to `validation_result.textract_result`; `:70-74` saves + enqueues `GenerateAiJobApplicationSummaryJob`. The new summary lives on the new result, so `textract_result.rb:77` finds it → credit charged on success.

### Reconciliation note lines 188-189 (S-D = prior succeeded-but-stale)
AGREE. `orchestrate.rb:15` picks the stale-succeeded (JobApplication-scoped), `:16` passes, `:46-48` succeeded branch returns; `textract_result.rb:77` TextractResult-scoped empty → nil → `:82` return; no credit. Matches verified code.

## Omissions (minor)

1. The map's Trigger D does not state that the S-D auto continuation is GATED on `should_auto_generate_ai_summaries?` (`textract_result.rb:138`). When auto-gen is OFF, the bridge else branch returns at `:138` and the status row is NEVER flipped to `regenerating` — it stays at its prior value (`current`) with now-stale denormalized data, and the prior summary stays `stale:true` with no further actor. This OFF terminal is documented under the T2 changelog (map line 35) but not repeated in the Trigger D (S-D) section; a reader consulting only the S-D section would miss it. (Not a dispute — the ON-path claims are all correct.)

2. The map (line 129) does not note that the `update_all(stale: true)` is conditional on the `unless ... textract_processing/stale:false exists?` guard (`submit_resume_to_textract.rb:18`). For the S-D scenario the guard evaluates to allow the update, so the stated outcome holds; the conditionality is simply unstated.

Both omissions are non-contradicting context, so all verdicts remain AGREE, but per the skepticism rule omissions being non-empty sets clean = false.
