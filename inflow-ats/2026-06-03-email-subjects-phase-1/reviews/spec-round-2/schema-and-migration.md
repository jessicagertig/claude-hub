# Schema and Migration -- Round 2

## Findings

Round 2 checked for edge cases in the migration and validator behavior.

### Migration column type confirmation
The spec says "nullable string" for all new columns. Rails `string` maps to `varchar(255)` in PostgreSQL by default. This is appropriate for:
- `channel_messages.subject` -- email subjects rarely exceed 100 characters; 255 is ample
- `channel_message_templates.subject` -- same reasoning
- `jobs.apply_response_template_subject` -- same reasoning
- `channel_messages.mailgun_message_id` -- Mailgun message IDs are under 100 characters

No issue.

### Validator behavior on nil subject
The renamed `CustomChannelMessageValidator` checks `value =~ /{{\s*[\w.]+\s*}}/i`. For nil `value`, `nil =~ /regex/` returns `nil` (falsy in Ruby), so the validator will NOT add an error. This means:
- Legacy messages with NULL subject pass validation -- correct, no regression.
- New messages with blank subject pass the custom validator -- correct, the presence check is frontend-only.
- New messages with `{{Foo}}` in subject fail validation -- correct, unreplaced variables are caught.

### Single migration for all columns
Spec says add all columns in one migration. This is clean and reduces migration count. No issue.

### No index on new columns
The spec does not mention adding database indexes on the new columns. For `subject`, there's no query that would filter or sort by subject -- no index needed. For `mailgun_message_id`, the spec says it's groundwork for phase 2. Phase 2 might need an index for lookup, but that can be added in phase 2's migration. No issue for phase 1.

No new issues found.

## Amendments Applied

None.
