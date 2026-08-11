# credit-consumption-timing -- Round 3

## Files reviewed

- `app/models/textract_result.rb` line 75: `status_succeeded?` gate
- `app/models/ai_job_application_summary.rb` enum: `succeeded: 7`
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb` line 49: sets `status: :succeeded`
- `app/interactors/create_ai_credit_balance_transaction.rb` (not modified -- receives summary post-check)

## Exhaustive status_succeeded? reference audit

```
grep -rn "status_succeeded\|status: :succeeded" --include="*.rb" app/ spec/
```

All references verified:
- `textract_result.rb:75` -- gates credit consumption. `succeeded` = full pipeline complete. Correct.
- `ai_job_application_summary.rb:53` -- `destroy_previous_textract_results` callback. Fires on `succeeded`. Correct.
- `ai_job_application_summary.rb:61` -- `update_summary_status_record` callback. Fires on `succeeded`. Correct.
- `generate_ai_job_application_summary_job.rb:61` -- broadcast status check. `succeeded` = full pipeline. Correct.
- `integrate_analysis.rb:49` -- sets `succeeded` as terminal state. Correct.
- `bulk_generate_ai_summaries_job.rb:50,89` -- status guards. Correct.
- Various spec files -- use symbol `:succeeded`, which maps correctly.

**No `Summary::Generate` sets `succeeded` anymore** (in working tree -- the committed code still does, which is part of BLOCKER-1).

## Assessment

Credit consumption timing is correct: credit consumed only when `IntegrateAnalysis` sets `succeeded` after the full pipeline (summary + scoring + integration) completes. 1 credit per evaluation, not per step.

## Findings

No NEW findings.
