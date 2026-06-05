# Always-On Checks -- Round 2

## Source Accuracy

Round 2 verified additional source details not covered in Round 1:

| Reference | Verified | Status |
|---|---|---|
| `Emails::SendTemplateEmail#add_subject` raises on blank | line 72-74: confirmed | OK |
| `SendBulkMessageToCandidates` passes `context.params` to job | line 18: confirmed | OK |
| `CreateChannelMessageTemplate` line 11 body cleanup | confirmed, subject not affected | OK |
| `UpdateChannelMessageTemplate` passes `context.params` to `.update` | line 16: confirmed | OK |
| `ChannelMessage.duplicate_message_exists?` checks body only | line 48-49: confirmed | OK |
| `notify_team` subject is different from `notify_candidate` subject | line 30: `"#{@job.title} - New message from #{@candidate.full_name}"` confirmed | OK |
| `HiringStageMessageAutomationsController` permitted params | line 61: `:channel_message_template_id, :hiring_stage_id, :frequency, :enabled` -- no `:subject`, confirmed | OK |
| Factory `create_test_message` in `api_factories.rb` | line 95-103: does not include subject, nullable column means no breakage | OK |

No source accuracy issues found.

## Test Coverage

Re-confirmed Round 1 finding: the spec has no test plan section. This remains a MED concern. The implementation plan should address:
- Cypress test for single-send with subject
- Cypress test for template creation/editing with subject
- Cypress test for bulk send with subject
- Verification that automation-triggered messages carry the template's subject
- Verification that the mailer fallback works for NULL subject

## Backward Compatibility

Round 2 additional checks:

- `CreateChannelMessageTemplate` interactor: passes `template_params` (derived from controller `context.params`) to `.build()`. Adding `:subject` to permitted params means it flows through. No breaking change.
- `UpdateChannelMessageTemplate` interactor: passes `context.params` to `.update()`. Adding `:subject` to permitted params means it flows through. No breaking change.
- `Emails::SendTemplateEmail#add_subject` raises on blank: the mailer fallback ensures subject is never blank. No breaking change.
- `ChannelMessage.duplicate_message_exists?` checks body only: unchanged behavior. Two messages with same body but different subjects would not be flagged. Acceptable.

No backward compatibility issues found.

## Full-Stack Analog Completeness

Round 2 additional verification -- checked all creation paths:

| Creation path | Subject handling | Status |
|---|---|---|
| `Channel#send_message_to_candidate` | `email.subject` captured | Covered |
| `Channel#send_message_to_company` | `email.subject` captured | Covered |
| `BulkChannelMessageSendJob` | `parse_text` substitutes subject | Covered |
| `CreateChannelMessage` | controller passes `subject:` in params | Covered |
| `CreateStageAutomationMessage` | `parse_text` substitutes + job passes template subject | Covered |
| `CreateOrganizationChannelMessage` | callers pass `subject:` in params | Covered |
| `Organization#add_default_channel_message_templates` | seed data includes `subject:` | Covered |
| `CreateChannelMessageTemplate` | controller permits `:subject` | Covered |

No missing creation paths.

## Amendments Applied

None.
