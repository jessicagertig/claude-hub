# Angle 5: Bulk Job Completion Notifications -- Round 3

## Files reviewed

- `app/jobs/bulk_generate_ai_summaries_job.rb`
- `app/mailers/bulk_job_application_ai_summary_result_mailer.rb` (new)
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx`
- `app/javascript/shared/types/aiSummaryWebsocketPayloads.ts`
- `spec/jobs/bulk_generate_ai_summaries_job_spec.rb`

## Findings

**No new findings.**

All requirements met:
- Declaration order: `discard_on StandardError` first, `retry_on CustomErrorAiSummary` second -- correct per ActiveJob reverse-order lookup
- `notify_failure` called from both `discard_on` and `retry_on` exhaustion blocks
- `notify_complete` called from `on_complete` for success path
- `notify_failure` called from `on_complete` when `succeeded == 0 && failed > 0`
- Both mailer calls chain `.deliver_later` (known failure pattern #4 satisfied)
- `notify_failure` guards with `return unless payload` and `return unless user`
- `notify_complete` and `notify_failure` are class methods with `private_class_method`
- Spec verifies retry/discard ordering via `rescue_handlers` index comparison
- Spec stubs mailer with `instance_double(ActionMailer::MessageDelivery)` and verifies `.deliver_later`
- Frontend `AI_SUMMARY_BULK_FAILED` handler uses `payload.message`, `kind: "warning"`, `delay: 20000`, invalidates correct queries
- `AiSummaryBulkFailedPayload` type has `jobTitle: string` and `message: string`
