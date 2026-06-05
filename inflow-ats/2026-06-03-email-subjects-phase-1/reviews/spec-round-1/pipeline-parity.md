# Pipeline Parity -- Round 1

## Findings

Verified all four pipelines (single-send, bulk, automation, apply-response) plus the inbound capture path against the spec.

### Single-send pipeline
- Controller (`ChannelMessagesController`): spec says permit `:subject` and sanitize. Source at line 31 permits only `:body`. Spec correctly identifies this as a change. No issue.
- Interactor (`CreateChannelMessage`): builds channel_message from `context.params` at line 19. If the controller passes `subject:` in params, it flows through. No change needed in interactor. Spec does not ask for one. Correct.
- Model (`ChannelMessage`): spec says add `validates :subject, custom_channel_message: true`. Source at line 24 currently has only body. Spec correctly identifies this as a change. No issue.
- Mailer (`notify_candidate`): spec says read `channel_message.subject` with fallback to `"#{@job.title} at #{@organization.name}"`. Source at line 116 hardcodes this. Spec correctly identifies this as a change. No issue.
- Serializer (`ChannelMessageSerializer`): spec says expose `:subject`. Source does not currently expose it. Spec correctly identifies. No issue.

### Bulk pipeline
- Controller (`BulkChannelMessagesController`): spec says permit `:subject`, sanitize, AND add `subject:` to the hand-built hash at lines 19-24. Source confirms the hash is hand-built. Spec correctly identifies both the permit AND the explicit hash addition. No issue.
- Interactor (`SendBulkMessageToCandidates`): passes `context.params` to `BulkChannelMessageSendJob.perform_later` at line 18. If controller puts `subject:` in the params hash, it flows through. No change needed. No issue.
- Job (`BulkChannelMessageSendJob`): spec says rename `parse_body` to `parse_text` and use for both body and subject. Source at line 12 does `params.merge(body: parse_body(...))`. Post-rename, the spec intends this to also merge `subject: parse_text(...)`. Spec's description is clear on intent. No issue.

### Automation pipeline
- Job (`HiringStageMessageAutomationJob`): spec says add `subject:` to `message_params` at lines 16-20. Source confirms `message_params` at line 16-20 currently only has `body:`. Spec correctly identifies. No issue.
- Interactor (`CreateStageAutomationMessage`): spec says rename `parse_body` to `parse_text` and use for both. Source at line 16 does `@message_params.merge(body: parse_body)`. Post-rename, spec intends this to also merge `subject:`. No issue.

### Apply-response pipeline
- `JobApplication#send_candidate_confirmation_email` (line 521-534): spec says add `subject:` in the params hash passed to `CreateOrganizationChannelMessage`. Source at lines 527-531 currently only includes `body:`, `sent_by:`, `source:`. Spec correctly identifies. No issue.
- `CustomerApi::CompleteJobApplication#send_confirmation_email` (line 44-63): spec says same thing. Source at lines 55-58 currently only includes `body:`, `sent_by:`, `source:`. Spec correctly identifies. No issue.
- `CreateOrganizationChannelMessage`: builds channel_message from `context.params` at line 13. If caller passes `subject:`, it flows through. No change needed in interactor. No issue.

### Inbound capture
- `Channel#send_message_to_company` (line 32): spec says capture `email.subject`. Source at lines 35-43 builds the hash without `subject:`. Spec correctly identifies. No issue.
- `Channel#send_message_to_candidate` (line 16): spec says capture `email.subject`. Source at lines 19-29 builds the hash without `subject:`. Spec correctly identifies. No issue.

### Serializers
- `ChannelMessageSerializer`: confirmed, needs `:subject` added.
- `ChannelMessageTemplateSerializer`: confirmed, needs `:subject` added.
- `ApiPublic::V1::Hire::ChannelMessageSerializer`: confirmed, needs `:subject` added.
- `JobSerializer`: confirmed, needs `:apply_response_template_subject` added.

- F1 [MED] spec / `BulkChannelMessageSendJob` / The spec says "rename parse_body to parse_text and use each to substitute mail-merge variables in both body and subject within its calling context." This is clear in intent, but the call site at `BulkChannelMessageSendJob` line 12 currently does `params.merge(body: parse_body(user, job_application, params))`. The renamed method reads `params[:body]` inside it (line 53). After renaming to `parse_text`, the implementation plan needs to make clear that the renamed method should accept either the body or subject text as input (not hardcode `params[:body]`), OR the call site should call it twice -- once for body, once for subject. The spec's current wording ("keep their existing signatures and post-processing") might be read as "don't change the method signature," which would conflict with needing to process subject. The `CreateStageAutomationMessage` version reads `@message_params[:body]` at line 32, same issue.

  Evidence: `BulkChannelMessageSendJob` line 48-62 -- `def parse_body(user, job_application, params)` reads `params[:body]` on line 53. `CreateStageAutomationMessage` line 30-43 -- `def parse_body` reads `@message_params[:body]` on line 32.

  Fix: The spec should clarify that `parse_text` takes a text argument (the string to substitute into) rather than hardcoding `params[:body]` or `@message_params[:body]`. This is an implementation detail, but without it, an implementer following "keep their existing signatures" literally would be stuck.

## Amendments Applied

None -- finding F1 is MED, not BLOCKER. The spec says "use each to substitute mail-merge variables in both body and subject within its calling context," which is sufficient direction. The "keep their existing signatures" phrase could be clearer, but a reasonable implementer will understand that the method needs to accept a text argument now. This is an implementation-plan concern, not a spec-level gap.
