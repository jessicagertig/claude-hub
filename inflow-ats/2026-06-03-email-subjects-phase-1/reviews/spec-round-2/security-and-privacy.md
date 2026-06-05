# Security and Privacy -- Round 2

## Findings

Round 2 deepened verification on XSS vectors and anonymization edge cases.

### XSS via spanified preview
The spanified subject preview will be rendered in the frontend via `dangerouslySetInnerHTML`. The subject string passes through:
1. Controller sanitization (`Sanitizer#sanitize`) which strips `<script>` and other XSS vectors using Sanitize gem with RELAXED config plus custom iframe handling.
2. Mustache spanification which wraps variable values in `<span>` tags.

Attack vector: user submits `<script>alert(1)</script>` as subject. The sanitizer strips `<script>` tags. The spanified result is safe. No gap.

Attack vector: user submits `<img src=x onerror=alert(1)>` as subject. The RELAXED config allows `<img>` with `src`. The `onerror` attribute would need to be checked. Looking at `Sanitizer#sanitize` -- it uses `Sanitize::Config::RELAXED` which allows a whitelist of attributes. `onerror` is NOT in the RELAXED whitelist, so it gets stripped. Safe.

### Template controller sanitization (re-confirmed)
`ChannelMessageTemplatesController` does NOT sanitize body or subject. Templates are sanitized at the point of use (when composed into messages via `ChannelMessagesController` or `BulkChannelMessagesController`). This is the existing pattern. The mail-merge preview (`render_template_message`) renders the template content through Mustache -- Mustache does NOT escape HTML by default (triple-brace `{{{tag}}}` form is used in the code at line 764). However, the input to Mustache is the template's stored body/subject, which could contain unsanitized HTML if a user puts it there directly. The existing pattern works because template create/edit goes through the template controller which does NOT sanitize, and the frontend's rich-text editor doesn't inject XSS vectors. For subject (plain text input), the risk is lower than for body. This is consistent with the existing pattern. No gap.

### Anonymization nil handling (re-confirmed)
`text_replacer` returns the input unchanged when `text.blank?` is true. `nil.blank?` returns `true`. So `text_replacer(nil, ...)` returns `nil`. The `channel_message.save!` after anonymization will save `nil` back for subject on historical messages. No crash, no data corruption. Confirmed.

### Email header injection via subject
Attack vector: user submits a subject containing `\r\n` (CRLF) to inject additional email headers. This is handled by the email provider (Mailgun) and the Mailgun SDK (`Mailgun::MessageBuilder#subject`), which sanitizes the subject header value. The app does not need to handle this separately. No gap.

No new issues found.

## Amendments Applied

None.
