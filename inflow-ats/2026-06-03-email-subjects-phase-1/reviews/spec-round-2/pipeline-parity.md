# Pipeline Parity -- Round 2

## Findings

Round 2 deepened verification on creation paths and the email delivery chain.

### All channel_message creation paths verified
Exhaustive grep for `channel_messages.(create|build|new)` found 7 paths (2 inbound, 4 outbound, 1 commented-out dead code). All are covered by the spec:
1. `Channel#send_message_to_candidate` (inbound) -- spec covers `email.subject` capture
2. `Channel#send_message_to_company` (inbound) -- spec covers `email.subject` capture
3. `BulkChannelMessageSendJob#perform` -- spec covers via `parse_text`
4. `CreateChannelMessage` (single-send) -- controller passes `subject:` in params
5. `CreateStageAutomationMessage` -- spec covers via `parse_text` + automation job passing template subject
6. `CreateOrganizationChannelMessage` (apply-response) -- callers pass `subject:` in params
7. `SendBulkMessageToCandidates` commented-out code -- dead path, not a concern

### Email delivery chain
`notify_candidate` builds `message_params` with `subject:` and passes to `Emails::SendTemplateEmail`. `SendTemplateEmail#add_subject` at line 72-74 raises `"No subject provided"` if subject is blank. The spec's mailer fallback to the hardcoded literal ensures `subject:` is never blank in `message_params`. Critical path confirmed correct.

### Template creation paths
Two creation paths:
1. `Organization#add_default_channel_message_templates` -- spec covers adding `subject:` to seed data
2. `CreateChannelMessageTemplate` interactor -- controller permits `:subject`, flows through to `.build(template_params)`

### CreateChannelMessageTemplate non-breaking-space cleanup
`CreateChannelMessageTemplate` line 11 cleans ` ` from body: `template_params = context.params.merge(body: context.params[:body]&.gsub(/ /, ' '))`. This cleanup is not applied to subject. Since subject does not go through Redcarpet (the reason body needs this cleanup), this is acceptable. The spec's existing boundary ("skip the Redcarpet step for subject") implicitly covers this.

### Duplicate message check
`ChannelMessage.duplicate_message_exists?` at line 48-49 checks only body, not subject. Used in `BulkChannelMessageSendJob` line 15 and `CreateChannelMessage` line 16. Two messages with same body but different subjects would not be flagged as duplicates. This is acceptable -- the duplicate check prevents accidental double-sends, and changing subject alone is intentional.

No new issues found.

## Amendments Applied

None.
