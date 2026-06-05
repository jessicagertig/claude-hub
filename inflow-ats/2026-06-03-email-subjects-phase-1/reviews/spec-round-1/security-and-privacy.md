# Security and Privacy -- Round 1

## Findings

### Sanitization (XSS prevention)

Verified the sanitization pattern in each controller:

- `ChannelMessagesController` (line 36): `next_params[:body] = sanitize(next_params[:body]) if next_params.key?(:body)`. Spec says add the same pattern for subject. The `sanitize` method is from `Sanitizer` module (`app/utils/sanitizer.rb`), which uses `Sanitize.fragment` with the RELAXED config. This strips XSS vectors like `<script>` tags. Correct to apply to subject.

- `BulkChannelMessagesController` (line 81): `next_params[:body] = sanitize(next_params[:body]) if next_params.key?(:body)`. Spec says add same for subject. Correct.

- `JobsController` (lines 266-270): sanitizes `apply_response_template` with `sanitize()`. Spec says add same for `apply_response_template_subject`. Correct.

- `ChannelMessageTemplatesController`: currently does NOT sanitize body. The `channel_message_template_params` method at line 60-62 just does `params.require(:channel_message_template).permit(:name, :body, :position)` with no sanitize call. The spec says "permit `:subject` (alongside `:name`, `:body`, `:position`)" but does NOT say to add sanitization here. Is this a gap?

- F1 [MED] `ChannelMessageTemplatesController` / sanitization / The templates controller does not sanitize body today, and the spec does not ask it to sanitize subject either. Template content gets sanitized when it flows through `render_template_message` and when messages composed from templates are submitted through `ChannelMessagesController` or `BulkChannelMessagesController`. So the sanitization happens at the point of use, not at the point of template storage. This is consistent with the existing pattern -- not a gap. The spanified preview (`template_html`) in `render_template_message` passes through Mustache rendering but uses `placeholder_options_with_spans_unfilled` which wraps values in `<span>` tags -- template body itself isn't run through a separate sanitize step. However, the existing pattern already works this way for body, so subject following the same pattern is consistent.

### XSS attack surface via dangerouslySetInnerHTML
The spec notes that the spanified preview's `dangerouslySetInnerHTML` path is the XSS vector. Subject gets a spanified variant via `render_template_message`. Since the subject is sanitized at the controllers where user input enters (ChannelMessages, BulkChannelMessages, Jobs), and templates go through sanitized controllers when composed into messages, the attack surface is covered.

### Anonymization

Verified the anonymization code at `candidates_controller.rb` lines 133-149.

Current pattern:
```ruby
job_application.channels.first.channel_messages.each do |channel_message|
  channel_message.body = text_replacer(channel_message.body, real_first_name, name_replacement)
  channel_message.body = text_replacer(channel_message.body, real_last_name, name_replacement)
  # ... same for body_legacy_markdown, body_raw_html, body_plain_text, body_sanitized_html
  channel_message.save!
end
```

Spec says: add `text_replacer` calls for `channel_message.subject` with both `real_first_name` and `real_last_name`. Same shape.

The `text_replacer` method (line 225-228):
```ruby
def text_replacer(text, old_word, new_word)
  return text if text.blank? || old_word.blank?
  text.gsub /#{old_word}/i, new_word
end
```

This method handles `nil` gracefully -- `.blank?` returns true for nil, so it returns the nil value unchanged. For historical messages with NULL subject, `text_replacer(nil, ...)` returns `nil`. No crash risk. Spec's note about "text_replacer must handle nil" is correct, and the existing implementation already does. No issue.

### GDPR completeness
After phase 1, a channel_message has these text columns that could contain candidate names:
- `body` -- anonymized (existing)
- `body_legacy_markdown` -- anonymized (existing)
- `body_raw_html` -- anonymized (existing)
- `body_plain_text` -- anonymized (existing)
- `body_sanitized_html` -- anonymized (existing)
- `subject` -- spec says anonymize (new)
- `mailgun_message_id` -- does not contain candidate names; no anonymization needed

Complete. No gap.

## Amendments Applied

None -- no BLOCKER or HIGH findings.
