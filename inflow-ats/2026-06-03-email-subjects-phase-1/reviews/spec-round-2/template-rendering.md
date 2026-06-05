# Template Rendering -- Round 2

## Findings

Round 2 deepened verification on the rendering pipeline details.

### render_template_message response shape
Current response at line 794: `{ message_raw, message_html, template_html, has_invalid_tags, invalid_tags }`.
Spec says extend to include rendered subject and spanified subject. The naming convention for the new keys is left to the implementer (e.g., `subject_raw`, `subject_html`, `subject_template_html`). This is an implementation detail -- no spec concern.

### invalid_tags widening
Spec says widen `has_invalid_tags`/`invalid_tags` to also inspect subject. Current code at lines 787-792:
```ruby
template = Mustache::Template.new(channel_message_template.body)
known_tags = placeholder_options(sender).keys.map(&:to_s)
used_tags = template.tags
invalid_tags = used_tags - known_tags
has_invalid_tags = !invalid_tags.empty?
```
This parses `channel_message_template.body` for Mustache tags. For subject, the same logic should parse `channel_message_template.subject` for Mustache tags and merge the results. The spec's direction is clear. No issue.

### Mustache spanified substitution on raw text vs HTML
For body: the spanified substitution runs on the Redcarpet-rendered HTML (`Mustache.render(html, placeholder_options_with_spans(sender))`).
For subject: since there's no Redcarpet step, the spanified substitution runs on the raw text (after brace normalization and space cleanup). The spanified result will contain `<span>` tags inside plain text. This is fine because the spanified form is only used for the preview UI's `dangerouslySetInnerHTML` rendering -- it's never sent as an email subject.

### html_safe call in CreateStageAutomationMessage
`parse_body` in `CreateStageAutomationMessage` (line 42) ends with `.html_safe`. When this method is used for subject, `.html_safe` would be applied to the subject string. `.html_safe` is a Rails method that marks a string as safe for HTML rendering -- it doesn't modify the string content. Since the subject ends up in the `Subject:` header via `SendTemplateEmail`, which calls `message_builder.subject(subject)` (which treats it as plain text), the `.html_safe` marker is harmless but unnecessary. No real risk, but the implementer should be aware.

Note: `BulkChannelMessageSendJob#parse_body` (line 48-62) does NOT end with `.html_safe`. The two methods have different post-processing, which the spec acknowledges ("keep their existing ... post-processing").

No new issues found.

## Amendments Applied

None.
