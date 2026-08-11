# callback-side-effects-and-guards

## Checked

1. `broadcast_status_change` uses `status_changed?` (correct for `before_update`). NOT `saved_change_to_status?` (which is for after_commit/after_save). Correct.
2. `BROADCAST_STATUSES` includes: `textract_processing`, `extracting`, `summarizing`, `scoring`, `integrating`, `succeeded`, `failed`. Excludes: `pending`, `awaiting_job_criteria`, `retrying`. Matches spec.
3. Existing `after_commit` callbacks:
   - `create_status_record`: `on: :create` only. Not triggered by `update`. Safe.
   - `destroy_previous_textract_results`: guarded by `saved_change_to_status? && status_succeeded?`. Only fires on succeeded. Safe.
   - `update_summary_status_record`: guarded by `saved_change_to_status? && status_succeeded?`. Only fires on succeeded. Safe.
4. All three callbacks have correct guards that filter intermediate statuses. No new callbacks fire unexpectedly.
5. The `broadcast_status_change` rescue ensures broadcast failures never prevent status transitions from persisting. Critical for rescue-path `update` calls that set `failed`/`retrying`.

## Findings

None.
