# pipeline-parity -- Round 1

## Findings

Verified every path where body flows and checked that subject follows the same path.

### Single-send pipeline
- Controller (`ChannelMessagesController`): `:subject` permitted (line 31), sanitized (line 37). PASS.
- Hook (`useChannelMessage.ts`): passes `variables` directly to `apiPost` -- `subject` is included by the caller (`ChannelMessageNew.tsx` line 112). PASS.
- Mailer (`notify_candidate`): uses `@channel_message.subject.presence || "#{@job.title} at #{@organization.name}"` (line 116). PASS.
- Serializer (`ChannelMessageSerializer`): `:subject` exposed. PASS.

### Bulk send pipeline
- Controller (`BulkChannelMessagesController`): `:subject` permitted (line 81), sanitized (line 83), added to hand-built hash (line 21). PASS.
- Hook (`useBulkMessage.ts`): `subject` added to destructured args and both payload locations (lines 7, 17, 27). PASS.
- Job (`BulkChannelMessageSendJob`): `parse_text` used for subject alongside body (line 14). PASS.

### Automation pipeline
- Job (`HiringStageMessageAutomationJob`): `subject: automation.channel_message_template.subject` added to `message_params` (line 18). PASS.
- Interactor (`CreateStageAutomationMessage`): `parse_text` used for subject (line 18). PASS.

### Apply-response template pipeline
- Model (`JobApplication#send_candidate_confirmation_email`): `subject: parse_apply_response_text(job.apply_response_template_subject)` added (line 529). PASS.
- Interactor (`CustomerApi::CompleteJobApplication#send_confirmation_email`): `subject: job_application.parse_apply_response_text(job_application.job.apply_response_template_subject)` added (line 57). PASS.
- Job model (`Job#add_default_apply_response_template`): `apply_response_template_subject: '{{JobTitle}} at {{OrganizationName}}'` added (line 349). PASS.

### Inbound capture
- Model (`Channel#send_message_to_company`): `subject: email.subject` added (line 40). PASS.
- Model (`Channel#send_message_to_candidate`): `subject: email.subject` added (line 25). PASS.

### Serializers
- `ChannelMessageSerializer`: `:subject` added. PASS.
- `ChannelMessageTemplateSerializer`: `:subject` added. PASS.
- `ApiPublic::V1::Hire::ChannelMessageSerializer`: `:subject` added. PASS.
- `JobSerializer`: `:apply_response_template_subject` added. PASS.

No issues found.
