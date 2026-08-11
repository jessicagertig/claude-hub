# callback-side-effects-and-guards (Round 2)

## Re-verified

1. All three existing callbacks (`create_status_record`, `destroy_previous_textract_results`, `update_summary_status_record`) have guards that correctly filter intermediate statuses.
2. `broadcast_status_change` uses `status_changed?` (dirty tracking, not saved tracking). Correct for `before_update`.
3. `BROADCAST_STATUSES` excludes `pending`, `awaiting_job_criteria`, `retrying`. These statuses transition silently.
4. The rescue in `broadcast_status_change` is the correct pattern for `before_update` callbacks -- prevents ActionCable failures from aborting the database transaction.
5. The `before_update` fires before `after_commit`, so the broadcast is sent before the transaction commits. This is intentional (optimistic broadcast per spec). If the transaction rolls back, the frontend will get a stale invalidation, but the next query will return the correct state. Not a bug.

## Findings

None.
