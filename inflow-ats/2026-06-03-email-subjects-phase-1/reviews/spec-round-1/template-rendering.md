# Template Rendering -- Round 1

## Findings

Verified the rendering pipeline in `render_template_message` (lines 758-799), `parse_body` in both `CreateStageAutomationMessage` and `BulkChannelMessageSendJob`, and `html_safe_apply_email`.

### render_template_message (JobApplication, line 758)
Current body pipeline:
1. Line 762: gsub `{{{` to `{{` and `}}}` to `}}` (normalize triple braces)
2. Lines 763-765: gsub known tags to triple-brace form `{{{Tag}}}` for Mustache
3. Lines 767-768: clean empty spaces and non-breaking spaces
4. Lines 773-775: Redcarpet Markdown -> HTML, then strip newlines
5. Line 780: `Mustache.render(body, placeholder_options(sender))` -- plain substitution on raw body
6. Line 781: `Mustache.render(html, placeholder_options_with_spans(sender))` -- spanified substitution on Markdown-rendered HTML
7. Line 782: `Mustache.render(html, placeholder_options_with_spans_unfilled)` -- spanified template preview on Markdown-rendered HTML
8. Lines 787-792: `invalid_tags` check on original template body

Spec says: Subject gets both Mustache passes but skips the Redcarpet step. This means for subject:
1. Same brace normalization (lines 762-765)
2. Same empty space cleanup (lines 767-768)
3. NO Redcarpet step (skip lines 773-775)
4. Mustache plain substitution (parallel to line 780)
5. Mustache spanified substitution (parallel to line 781) -- but on the raw text, not on Markdown HTML
6. Mustache spanified template preview (parallel to line 782) -- same, on raw text
7. Spec says widen `invalid_tags` to also inspect subject

This is consistent and correct. No issue with the boundary.

### html_safe_apply_email (JobApplication, line 537)
Current body pipeline: `.scrub.gsub(5 variables).gsub( , ' ').html_safe`
Spec says: apply the same gsub chain to subject. The spec mentions 5 variables here (`{{JobTitle}}`, `{{CandidateFullName}}`, `{{CandidateFirstName}}`, `{{CandidateLastName}}`, `{{OrganizationName}}`). The source at lines 538-544 confirms these 5 plus `.scrub` and the non-breaking space cleanup. No issue.

Note: `html_safe_apply_email` does NOT include `{{SenderFullName}}` or `{{SenderFirstName}}` -- those are only in `parse_body` / the template render pipeline. This is correct because apply-response emails are sent by the organization, not by a specific sender.

### parse_body in CreateStageAutomationMessage (line 30)
7-variable gsub chain: `SenderFullName`, `SenderFirstName`, `JobTitle`, `CandidateFullName`, `CandidateFirstName`, `CandidateLastName`, `OrganizationName`, plus `.scrub` and `.gsub( , ' ').html_safe`. Spec says apply to subject the same way. Consistent.

### parse_body in BulkChannelMessageSendJob (line 48)
Same 7-variable gsub chain: `SenderFullName`, `SenderFirstName`, `JobTitle`, `CandidateFullName`, `CandidateFirstName`, `CandidateLastName`, `OrganizationName`, plus `.scrub`. NOTE: this version does NOT end with `.html_safe` -- that's a difference from `CreateStageAutomationMessage`. The spec says "keep their existing signatures and post-processing" so this difference is preserved.

### clean_incoming_message (ChannelMessage, line 56)
Spec says subject must NOT go through `remove_bad_line_breaks`. Source at line 59 applies `remove_bad_line_breaks` to body only (conditioned on `body_plain_text`). Since subject is a separate column, `clean_incoming_message` won't touch it. However:

- F1 [MED] `clean_incoming_message` / The `before_create :clean_incoming_message` callback at line 20 processes the body column. It does `self.body = body_plain_text ? remove_bad_line_breaks(body_plain_text) : body`. This callback runs on ALL channel_messages, including inbound ones where `body_plain_text` is set. The spec does not explicitly state that `clean_incoming_message` should NOT process subject -- it only says "do not add a `cleaned_subject` equivalent" and "do not process subject through `remove_bad_line_breaks`". The spec's boundary statement in the Architecture section is clear enough ("Skip the Redcarpet step"), and `clean_incoming_message` is body-specific by construction. No spec amendment needed, but the implementer should be aware that `clean_incoming_message` must not be extended to touch subject.

### html_safe_body (ChannelMessage, line 182)
Spec says do not add `html_safe_subject`. Confirmed -- body needs `.html_safe` for Rails template rendering; subject goes into `Subject:` header as plain text. No issue.

### Spec references to `html_safe_apply_email` applying `.html_safe`
The apply-response subject comes from `job.apply_response_template_subject` and goes through gsub substitution. The spec says "run through the same gsub mail-merge substitution chain that `html_safe_apply_email` applies to the body." This is fine for the gsub chain, but the spec should be explicit that the `.html_safe` call at the end of `html_safe_apply_email` should NOT be applied to subject. The subject goes into the params hash as a plain string, not as an HTML-safe string.

- F2 [MED] spec / apply-response subject / The spec says "run through the same gsub mail-merge substitution chain that `html_safe_apply_email` applies to the body" but `html_safe_apply_email` ends with `.html_safe`. The implementer might copy the full chain including `.html_safe` onto subject, which is wrong -- subject is plain text for the `Subject:` header. The spec should clarify that the gsub substitutions are copied but `.html_safe` is not applied to subject.

## Amendments Applied

None -- both findings are MED. The spec's existing boundary language ("Treat subject as a plain (non-rich-text) string" and "Do not add an `html_safe_subject` model method") provides enough context for a careful implementer to get this right.
