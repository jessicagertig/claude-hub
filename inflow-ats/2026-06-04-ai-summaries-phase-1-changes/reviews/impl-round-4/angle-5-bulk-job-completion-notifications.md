# Angle 5: Bulk Job Completion Notifications -- Round 4

## Fresh adversarial focus areas

1. **`notify_failure` total_queued_count calculation.** `(payload['job_application_ids']&.size || 0) + (payload['skipped_count'] || 0)`. If `job_application_ids` is nil, `.size` would raise NoMethodError, but the `&.` safe navigation returns nil, which `|| 0` handles. If `skipped_count` is nil, `|| 0` handles it. Correct.

2. **`on_complete` edge case: succeeded == 0 && failed == 0.** Falls into `else` branch, calls `notify_complete` with 0/0 counts. This is correct per spec: "if succeeded == 0 AND failed > 0, call notify_failure; otherwise call notify_complete."

3. **`notify_failure` called from `discard_on`/`retry_on` blocks.** These blocks run at class level. `notify_failure` is a `private_class_method`. The blocks can access it because they evaluate in the class context. Same pattern as existing `update_remaining_statuses_to_failed`. Correct.

4. **`notify_complete` called from `on_complete` via `self.class.send`.** Uses `send` to bypass `private_class_method` access restriction from instance context. `self.class.send(:notify_failure, payload)` in the failure branch is consistent. Correct.

5. **Mailer `.deliver_later` chains.** Both `BulkJobApplicationAiSummaryResultMailer.complete(...).deliver_later` and `.failed(...).deliver_later` are chained. Known failure pattern #4 satisfied.

## Findings

**No findings.**
