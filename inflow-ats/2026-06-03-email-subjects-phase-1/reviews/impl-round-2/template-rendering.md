# template-rendering -- Round 2

## Findings

Re-verified `render_template_message` with focus on the Mustache/Redcarpet boundary and edge cases.

### Additional checks this round:

1. Verified `message_raw` uses pre-Redcarpet `body` (line 801) while `message_html` uses post-Redcarpet `html` (line 802). Subject correctly uses `subject_prepared` (line 806) which never passes through Redcarpet. The parallel is exact: `message_raw` ↔ `subject_raw` (both pre-Redcarpet with substitution), `message_html` ↔ `subject_html` (body post-Redcarpet, subject skips Redcarpet -- both with spans). PASS.

2. Verified edge case: when `channel_message_template.subject` is nil, line 784 sets `subject_source = ''`. All downstream operations (gsub, Mustache.render) work on empty string. Response includes `subject_raw: ''`, `subject_html: ''`, `template_subject_html: ''`. Frontend `if (mailMerge?.subjectRaw)` returns false for empty string. Subject stays as the default. Correct. PASS.

3. Verified edge case: when `channel_message_template.subject` contains `{{UnknownTag}}`, line 814 creates a `Mustache::Template` from it, line 818 computes `subject_invalid_tags = subject_template.tags - known_tags`, which will include `UnknownTag`. `has_invalid_tags` will be true. Frontend shows invalid tag warning. PASS.

4. Verified `clean_incoming_message` does NOT touch subject. Line 60: `self.body = body_plain_text ? remove_bad_line_breaks(body_plain_text) : body`. Only `body` and `body_sanitized_html` are modified. Subject is inert in this callback. PASS.

No issues found.
