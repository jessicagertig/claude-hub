# credit-consumption-timing — Round 1

## Findings

- F1 [HIGH] `destroy_previous_textract_results` callback fires on `status_succeeded?` transition -- but with the new enum, `Summary::Generate` must NOT set `succeeded` (see pipeline-status-lifecycle F1). If this callback fires when the orchestrator eventually sets `succeeded`, it would destroy earlier TextractResults AFTER the scoring pipeline has potentially read resume text from them. The callback at ai_job_application_summary.rb line 39 checks `saved_change_to_status? && status_succeeded?`. With the extended pipeline, by the time `succeeded` fires, the summary's textract_result has been used for both summary AND scoring. The textract cleanup should still be correct (it only destroys TextractResults with `created_at` BEFORE the summary's textract_result), but verify this doesn't interact badly with the scoring pipeline if scoring reads from the textract_result. **Fix:** Add a note confirming that `destroy_previous_textract_results` is safe to fire at the new `succeeded` point because scoring reads from `textract_result.textract_job_result_text` synchronously during the pipeline (not asynchronously after the pipeline completes).

- F2 [LOW] The spec says "Credit consumed only after `AiJobApplicationSummary` status reaches `succeeded`." The check is in textract_result.rb line 79: `return unless ai_job_application_summary&.status_succeeded?`. Since `status_succeeded?` is a Rails enum method that checks the symbol (not the integer), this naturally works with the redesigned enum. No issue here -- just confirming the claim is correct.

- F3 [LOW] The spec says "Entry type in `AiCreditBalanceTransaction` TBD." This is acceptable for a spec -- the plan should decide.
