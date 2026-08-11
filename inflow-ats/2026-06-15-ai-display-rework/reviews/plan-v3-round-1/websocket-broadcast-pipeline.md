# websocket-broadcast-pipeline -- Round 1

## Fact Check

- Spec says `before_update :broadcast_status_change`. Plan A.1.2 matches. CONFIRMED.
- Existing `after_commit` callbacks end at line 29 (`after_commit :update_summary_status_record, on: :update`). Plan says "after line 29." CONFIRMED.
- `before_update :handle_before_update` on `Job` at `job.rb:60` -- CONFIRMED.
- `before_update :handle_before_update` on `Organization` at `organization.rb:57` -- CONFIRMED.
- Guard: `status_changed?` correct for `before_update` (dirty attribute, not saved). Existing callbacks use `saved_change_to_status?` correct for `after_commit` (line 51, 60). CONFIRMED.
- `BROADCAST_STATUSES` plan value matches spec exactly: `%w[textract_processing extracting summarizing scoring integrating succeeded failed]`. Excludes `pending`, `awaiting_job_criteria`, `retrying`. CONFIRMED.
- Broadcast shape: `JobChannel.broadcast_to(job_application.job, event: 'ai_summary_status_change', payload: { jobApplicationId: job_application.id })`. Analog: `BoardWwrListing#broadcast_event` at line 268: `JobChannel.broadcast_to(job, event: event, payload: { ... })`. Same structure. CONFIRMED.
- `app/channels/job_channel.rb`: standard ActionCable channel, `subscribed` finds Job by `params[:jobId]`, calls `stream_for job`. Receives broadcasts without code changes. CONFIRMED.
- `WebsocketJobChannelHandler.tsx`: switch at line 54, existing wwr cases at lines 55-56, `queryClient` in dependency array at line 78 `[refetchJob, queryClient, jobId]`. CONFIRMED.
- `WebsocketGlobalChannelHandler.tsx`: `AI_SUMMARY_COMPLETE` at lines 212-228 invalidates `["jobApplication"]`, `["aiJobApplicationSummary"]`, `["organizationAiCreditBalance"]`. `AI_SUMMARY_FAILED` at lines 231-241 invalidates `["jobApplication"]`, `["organizationAiCreditBalance"]` (does NOT invalidate `["aiJobApplicationSummary"]`). CONFIRMED.
- Plan correctly notes both channels can fire for `succeeded` and React Query deduplicates.
- Rescue wrapper in `broadcast_status_change` uses `Rails.logger.error(e)` + `ap e`. Follows error handling rules. CONFIRMED.

## Completeness

| Spec requirement | Plan step | Status |
|---|---|---|
| `before_update :broadcast_status_change` | A.1.2 | Covered |
| `BROADCAST_STATUSES` constant | A.1.1 | Covered |
| Guard: `status_changed?` then `BROADCAST_STATUSES.include?` | A.1.3 | Covered |
| `ap` logging after guards | A.1.3 | Covered |
| Rescue wrapper around broadcast | A.1.3 | Covered |
| JobChannel broadcast shape | A.1.3 | Covered |
| Frontend `ai_summary_status_change` case | C.1.1 | Covered |
| Invalidates both query keys | C.1.1 | Covered |
| Global channel broadcasts remain | P4 | Documented |

## Findings

No issues found.
