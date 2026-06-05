# Schema and Migration -- Round 1

## Findings

### Column additions
Spec says add to one migration:
- `channel_messages.subject` (nullable string) -- correct, no backfill needed.
- `channel_message_templates.subject` (nullable string) -- correct.
- `jobs.apply_response_template_subject` (nullable string) -- correct.
- `channel_messages.mailgun_message_id` (nullable string) -- column only, no code uses it in phase 1. Correct.

All columns are nullable, which means existing rows won't be affected. No default value, no NOT NULL constraint. Backward compatible.

### Validator rename
- File: `app/validators/custom_channel_message_body_validator.rb` -> `custom_channel_message_validator.rb`
- Class: `CustomChannelMessageBodyValidator` -> `CustomChannelMessageValidator`
- Rails convention: the validator key derives from the class name. `CustomChannelMessageBodyValidator` maps to `custom_channel_message_body:`. `CustomChannelMessageValidator` maps to `custom_channel_message:`.
- Single call site at `channel_message.rb:24`: `validates :body, custom_channel_message_body: true` -> `validates :body, custom_channel_message: true`.
- New line: `validates :subject, custom_channel_message: true`.
- Verified: no other files reference `custom_channel_message_body` (grep confirmed only the validator file and the model line).

The validator itself (line 13) does `value =~ /{{\s*[\w.]+\s*}}/i` -- it checks whether unreplaced `{{...}}` patterns remain in the text. This makes sense for both body and subject: after mail-merge substitution, no `{{...}}` patterns should survive. Applying this to subject is correct.

Note: the validator adds an error to `record.errors[attribute]` using `<<`, so the error message is the same for both body and subject. The error message says "Message not sent. An invalid placeholder formatted like {{Something}} was found." This message is body-centric in phrasing but applies equally to subject. No spec amendment needed.

### Column type
Spec says "nullable string" for all new columns. It does not specify a character limit. Rails `string` columns are `varchar(255)` by default in PostgreSQL. For subject lines, 255 characters is sufficient (email subject lines are typically under 78 characters by RFC 2822 recommendation, though technically unlimited). The spec's choice of `string` over `text` is appropriate for a subject line.

For `mailgun_message_id`, Mailgun message IDs are typically under 100 characters. `varchar(255)` is sufficient.

### No backfill
Spec explicitly states no backfill of existing rows. Historical messages will have `NULL` subject. The mailer fallback handles NULL/blank subjects. Correct.

### No model-level presence validation on subject
Spec explicitly states this. The backend allows NULL subject for legacy rows. The frontend enforces non-blank via yup. This is internally consistent.

No issues found.

## Amendments Applied

None.
