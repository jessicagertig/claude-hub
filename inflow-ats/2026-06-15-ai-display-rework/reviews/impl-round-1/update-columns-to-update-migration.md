# update-columns-to-update-migration

## Checked

1. `orchestrate.rb` line 72: `update_columns` -> `update`. 1 call site. Correct.
2. `score_job_application.rb`: 5 `update_columns` -> `update` conversions (lines 23, 32, 115, 120, 124). Correct count, all converted.
3. `integrate_analysis.rb`: 3 `update_columns` -> `update` conversions (lines 59, 64, 68). Correct count, all converted.
4. `summary/generate.rb` NOT modified. Correct per plan.
5. Existing callbacks verified safe with intermediate statuses:
   - `destroy_previous_textract_results`: guarded by `saved_change_to_status? && status_succeeded?`. Only fires on succeeded.
   - `update_summary_status_record`: guarded by `saved_change_to_status? && status_succeeded?`. Only fires on succeeded.
   - `create_status_record`: `on: :create` only. Not affected by `update`.

## Findings

### LOW: Unchecked `update` return values in happy-path service code

`orchestrate.rb` line 72, `score_job_application.rb` lines 23 and 32 call `update` without checking the return value. Rule 12 says "Always Check save/update Return Values." However, these were `update_columns` before (which also didn't check returns), the only validation is `validates :status, presence: true` which always passes for valid enum values, and the plan explicitly notes this is safe. The rescue-path calls are similarly unchecked but are secondary error handling where failure to persist error status is a minor concern vs. the primary error. Not blocking.
