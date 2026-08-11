# websocket-broadcast-pipeline

## Checked

1. `BROADCAST_STATUSES` constant matches spec: `%w[textract_processing extracting summarizing scoring integrating succeeded failed]`. Positioned after enum, before validates. Correct.
2. `before_update :broadcast_status_change` callback -- spec says `before_update`, implementation matches. Guard uses `status_changed?` (correct for before_update, not `saved_change_to_status?` which is for after_commit). Correct.
3. Second guard: `BROADCAST_STATUSES.include?(status)`. Correct.
4. Broadcast payload: `JobChannel.broadcast_to(job_application.job, event: 'ai_summary_status_change', payload: { jobApplicationId: job_application.id })`. Matches `BoardWwrListing` analog.
5. Rescue wrapping: `rescue StandardError => e` with `Rails.logger.error(e)` and `ap e`. Correct -- prevents broadcast failures from aborting the transaction.
6. `ap` logging after both guards: two `ap` calls. Matches plan.
7. `WebsocketJobChannelHandler` -- new case `"ai_summary_status_change"` invalidates both `["jobApplication"]` and `["aiJobApplicationSummary"]`. Follows existing pattern.
8. Existing `GlobalChannel` broadcasts unchanged -- `AI_SUMMARY_COMPLETE` and `AI_SUMMARY_FAILED` still fire. New broadcast supplements, does not replace.
9. Test coverage: 4 test groups -- broadcasts for each BROADCAST_STATUS, does not broadcast for excluded statuses, does not broadcast when status unchanged, does not broadcast on create. All present.

## Findings

None.
