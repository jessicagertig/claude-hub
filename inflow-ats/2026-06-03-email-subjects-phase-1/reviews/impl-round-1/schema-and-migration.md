# schema-and-migration -- Round 1

## Findings

### Migration (20260603212057_add_subject_and_mailgun_message_id_to_channel_messages.rb)

1. Four columns added: PASS.
   - `channel_messages.subject` (string, null: true)
   - `channel_messages.mailgun_message_id` (string, null: true)
   - `channel_message_templates.subject` (string, null: true)
   - `jobs.apply_response_template_subject` (string, null: true)

- F1 [MED] Migration uses `def change` which auto-generates the `down` method via `remove_column`. The plan specified "The `down` method should remove all four columns." The auto-generated reversibility from `change` achieves this. Not a blocker -- Rails handles this correctly.

### Validator rename

2. `custom_channel_message_body_validator.rb` deleted. PASS.
3. `custom_channel_message_validator.rb` created with class `CustomChannelMessageValidator`. PASS.
4. Logic identical to original: `validate_each` checks `value =~ /{{\s*[\w.]+\s*}}/i`. PASS.
5. Example usage comment updated from `custom_channel_message_body` to `custom_channel_message` (line 8). PASS.

### ChannelMessage model

6. `validates :body, custom_channel_message: true` (line 24) -- old key correctly replaced. PASS.
7. `validates :subject, custom_channel_message: true` (line 25) -- new validation added. PASS.
8. No presence validation on subject. PASS.
9. No `html_safe_subject`, no `cleaned_subject` methods added. PASS.
10. Subject not processed through `clean_incoming_message`. PASS.

### Backward compatibility

11. All columns nullable -- existing rows unaffected. PASS.
12. Validator rename has only one call site (`channel_message.rb` line 24), which is updated. PASS.
13. `parse_body` -> `parse_text` are private methods, called only within their own class. No external callers broken. PASS.
14. Serializer additions are additive (new key in JSON response). PASS.
15. `render_template_message` response shape adds new keys (`subject_raw`, `subject_html`, `template_subject_html`) -- existing consumers (`useMailMerge`) ignore unknown keys. PASS.

No blocking issues found.
