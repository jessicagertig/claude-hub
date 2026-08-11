# summary-lifecycle / state-machine — Round 2

Re-traced the lifecycle against the amended spec; verified the C8->record_failure reconciliation is internally consistent and swept for other summary-destroy/failed paths.

## Findings
No new MED+ findings.

## Re-verified correct + newly checked
- C8 -> record_failure (Round-1 F1 fix): the amended W1/C8 now routes through `record_failure` and the W5 site list includes `get_resume_text_from_textract_job.rb:19`. Consistent. The status row exists at intake; `record_failure`'s `return unless ai_job_application_summary_status` passes. The manual-case `AI_SUMMARY_FAILED` broadcast is preserved (called after record_failure when requesting user present). CONFIRMED coherent.
- ADDITIONAL summary-destroy path examined: `textract_result.rb:134` `ai_summary_waiting_on_textract.destroy` (bridge if-branch ELSE). This fires when Textract SUCCEEDS but `ValidateAiSummaryGeneration` then fails (e.g. credits exhausted between intake and Textract completion). It is NOT a terminal pipeline failure and NOT a Textract terminal failure, so D1 ("persist as failed on Textract terminal failure") does NOT apply. The candidate correctly falls to the empty "noCredits"/"ready" state (status row stays `none`; `set_initial_summary_pending` never ran because the job was not enqueued on Validate failure). Intentionally NOT a W5 record_failure site; matches existing manual behavior; changing it would be scope-creep into the bridge if-branch-else. NOTED (no defect, no amendment). Documented so it is not re-discovered as a phantom finding.
- C7 cascade + the new earlier-failed-TextractResult test: amended correctly. The W1 summary attaches to the succeeder, survives the cascade. CONFIRMED.
- broadcast_status_change is before_update only (`:31`) -> a W1 summary CREATED at textract_processing fires no broadcast; its signal flows via the status row (`set_initial_summary_pending`). Spec W1 line 32 correct. CONFIRMED.
- counter_culture decrement, C1 stale guard, no-broadcast-on-failed note: all re-confirmed correct.

## Amendments Applied (Round 2)
None.
