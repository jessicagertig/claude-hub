# security-and-privacy -- Round 1

## Findings

### Sanitization

1. `ChannelMessagesController`: `sanitize(next_params[:subject])` added (line 37), guarded by `if next_params.key?(:subject)`. Mirrors body sanitization pattern. PASS.
2. `BulkChannelMessagesController`: `sanitize(next_params[:subject])` added (line 83), guarded by `if next_params.key?(:subject)`. Mirrors body sanitization pattern. PASS.
3. `JobsController`: `sanitize(sanitized_params[:apply_response_template_subject])` added (lines 272-274), guarded by `if sanitized_params.key?(:apply_response_template_subject)`. Mirrors `apply_response_template` sanitization pattern. PASS.
4. `ChannelMessageTemplatesController`: No sanitization added for template subject. PASS -- consistent with existing behavior: the template controller does NOT sanitize template body either. Templates go through `render_template_message`'s Mustache passes which are sanitized at the consumer level.

### Anonymization

5. `CandidatesController` anonymization loop (lines 146-147): `text_replacer` called on `channel_message.subject` for both `real_first_name` and `real_last_name`. PASS.
6. `text_replacer` handles nil gracefully (`return text if text.blank?` at line 225 of candidates_controller.rb) -- historical messages with NULL subject won't raise. PASS.

### XSS surface

7. `ChannelMessageTemplateSelectionModal.tsx` line 44-46: Subject displayed via `{mailMerge.subjectRaw}` as text content (not `dangerouslySetInnerHTML`). PASS -- no XSS risk.
8. `ChannelMessageNew.tsx` line 159: Subject displayed via `FormInput` value prop. PASS -- no XSS risk.
9. All other frontend surfaces display subject via `FormInput` value props. PASS.

No issues found.
