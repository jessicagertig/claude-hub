# Always-On Checks -- Round 1

## Source Accuracy

All file paths, class names, method names, column names, and line numbers referenced in the spec verified against the live source at `/Users/jessica/wrk/wrk-corp/inflow-ats.messaging-improvements`:

| Reference | Spec says | Actual | Status |
|---|---|---|---|
| `ChannelMessage` model | line 24: `validates :body, custom_channel_message_body: true` | line 24: confirmed | OK |
| `ChannelMessage#clean_incoming_message` | line 56 | line 56: confirmed | OK |
| `ChannelMessage#cleaned_body` | line 174 | line 174: confirmed | OK |
| `ChannelMessage#html_safe_body` | line 182 | line 182: confirmed | OK |
| `CustomChannelMessageBodyValidator` | exists at `app/validators/custom_channel_message_body_validator.rb` | confirmed | OK |
| `Channel#send_message_to_candidate` | line 16 | line 16: confirmed | OK |
| `Channel#send_message_to_company` | line 32 | line 32: confirmed | OK |
| `Job#add_default_apply_response_template` | line 346 | line 346: confirmed | OK |
| `JobApplication#send_candidate_confirmation_email` | line 521 | line 521: confirmed | OK |
| `JobApplication#html_safe_apply_email` | line 537 | line 537: confirmed | OK |
| `JobApplication#render_template_message` | line 758 | line 758: confirmed | OK |
| `render_template_message` Redcarpet at lines 773-775 | confirmed | lines 773-775: confirmed | OK |
| `render_template_message` invalid_tags at lines 787-792 | confirmed | lines 787-792: confirmed | OK |
| `Organization.default_channel_message_templates` | line 364 | line 364: confirmed | OK |
| `HiringStageMessageAutomationJob#perform` | line 6 | line 6: confirmed | OK |
| `HiringStageMessageAutomationJob` message_params | lines 16-20 | lines 16-20: confirmed | OK |
| `CreateStageAutomationMessage#parse_body` | line 30 | line 30: confirmed | OK |
| `BulkChannelMessageSendJob#parse_body` | line 48 | line 48: confirmed | OK |
| `BulkChannelMessagesController` literal hash | lines 19-24 | lines 19-24: confirmed | OK |
| `ChannelMessageMailer#notify_candidate` | line 94 | line 94: confirmed | OK |
| `notify_candidate` hardcoded subject | line 116 | line 116: `"#{@job.title} at #{@organization.name}"` confirmed | OK |
| `CandidatesController` anonymization | lines 135-146 | lines 135-146: confirmed | OK |
| `CustomerApi::CompleteJobApplication#send_confirmation_email` | line 44 | line 44: confirmed | OK |
| `ChannelMessageTemplatesMailMergeController#show` | exists | confirmed | OK |
| `Api::V1::ChannelMessageSerializer` | exists, exposes `:body` | confirmed | OK |
| `Api::V1::ChannelMessageTemplateSerializer` | exists, exposes `:body` | confirmed | OK |
| `ApiPublic::V1::Hire::ChannelMessageSerializer` | exists, exposes `:body` | confirmed | OK |
| `Api::V1::JobSerializer` | exists, exposes `:apply_response_template` | confirmed | OK |
| `Api::V1::ChannelSerializer` has_many `:channel_messages` | line 9 | line 9: confirmed | OK |
| `HiringStageMessageAutomationsController` | does not permit `:subject` | confirmed (line 61: permits only template_id, stage_id, frequency, enabled) | OK |

- F1 [HIGH] spec / `CreateStageAutomationMessage` parse_body call site / REVIEW-ANGLES.md says "rename `parse_body` to `parse_text` (line 30), use for both body and subject." The call site is actually at line 16 (`channel_message_params = @message_params.merge(body: parse_body)`), and the definition is at line 30. This is correct in the spec itself (which says "rename the existing private `parse_body` methods") but the REVIEW-ANGLES.md line reference at "line 30" refers to the definition, which is accurate.

  Similarly for `BulkChannelMessageSendJob`: REVIEW-ANGLES.md says "line 48" which is the definition. Call site is at line 12. Both correct.

  Actually, rereading: REVIEW-ANGLES.md says "rename `parse_body` -> `parse_text` (line 30)" -- this is referring to the method definition at line 30. The call sites at line 16 and line 12 respectively will also need updating. The spec correctly identifies both files. Downgrading -- this is NOT a finding, just a note about line references pointing to definitions vs call sites. Both are correct.

No source accuracy issues found.

## Test Coverage

### Existing tests
- `cypress/e2e/candidates/messages.cy.js` -- covers single-send messaging flow
- `cypress/e2e/job-setup/hiring-stage-automations.cy.js` -- covers automation setup
- No dedicated RSpec specs for the affected controllers, interactors, mailers, or models

### Test gaps the spec should address
The spec does not include a test plan section. For a feature that touches this many pipelines, the implementation plan should require:

- F2 [MED] spec / test coverage / The spec has no test coverage requirements. At minimum, the existing Cypress tests for messages and automations should be updated to verify subject is sent and received. The mailer fallback path (NULL subject -> hardcoded default) should be tested. The validator rename should be smoke-tested (a message with surviving `{{...}}` in subject should be rejected). These are implementation-plan concerns, not spec-level, but the spec should at least note which existing tests need updating.

## Backward Compatibility

### Validator rename
- `CustomChannelMessageBodyValidator` -> `CustomChannelMessageValidator`: only one call site (`channel_message.rb:24`). Grep confirmed no other references. Safe.

### parse_body rename
- `CreateStageAutomationMessage`: private method, called only at line 16. No external callers. Safe.
- `BulkChannelMessageSendJob`: private method, called only at line 12. No external callers. Safe.
- `SendBulkMessageToCandidates` has a commented-out `parse_body` (lines 47-61). This is dead code and won't break.

### Serializer additions
- Adding `:subject` to serializers is purely additive. Existing consumers that don't read `subject` will ignore it. No breaking change.

### render_template_message response shape
- Adding new keys (`subject_raw`, `subject_html`, `subject_template_html`, etc.) to the response hash is additive. The frontend consumer (`useMailMerge`) reads specific keys; new keys are ignored until the frontend is updated to consume them. No breaking change.

### Migration
- Nullable columns with no default. No impact on existing rows. No backfill. Safe.

No backward compatibility issues found.

## Full-Stack Analog Completeness

Verified against the single-send analog pipeline:

| Layer | Body (existing) | Subject (spec) | Status |
|---|---|---|---|
| Controller permit | `:body` permitted | `:subject` to be permitted | Covered |
| Controller sanitize | `sanitize(body)` | `sanitize(subject)` | Covered |
| Interactor | passes params through | no change needed | Covered |
| Model validation | `custom_channel_message_body: true` | `custom_channel_message: true` | Covered |
| Model callback | `clean_incoming_message` processes body | NOT processing subject (correct) | Covered |
| Mailer | hardcoded subject | reads `channel_message.subject` with fallback | Covered |
| Serializer | exposes `:body` | exposes `:subject` | Covered |
| Auth | `JobApplicationPolicy#send_channel_message?` | no change needed (gates action) | Covered |

No missing layers.

Verified against secondary analogs (bulk, automation, apply-response):

| Pipeline | Body path | Subject path (spec) | Status |
|---|---|---|---|
| Bulk controller | permits body, sanitizes, adds to hash | same for subject | Covered |
| Bulk job | `parse_body` substitutes body | `parse_text` substitutes both | Covered |
| Automation job | passes template body in params | passes template subject in params | Covered |
| Automation interactor | `parse_body` substitutes body | `parse_text` substitutes both | Covered |
| Apply-response (JobApplication) | `html_safe_apply_email` for body | gsub chain for subject | Covered |
| Apply-response (CustomerApi) | includes body in params | includes subject in params | Covered |
| Inbound (send_message_to_company) | captures `email.body` | captures `email.subject` | Covered |
| Inbound (send_message_to_candidate) | captures `email.body` | captures `email.subject` | Covered |

No missing layers.

## Amendments Applied

None -- no BLOCKER or HIGH findings requiring spec amendment.
