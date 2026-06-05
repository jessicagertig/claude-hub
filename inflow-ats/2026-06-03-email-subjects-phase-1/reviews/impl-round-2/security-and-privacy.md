# security-and-privacy -- Round 2

## Findings

Re-verified sanitization and anonymization with fresh scrutiny.

### Additional checks this round:

1. Verified the `Sanitizer#sanitize` method is the same one used for body in all three controllers. The `include Sanitizer` is present in:
   - `ChannelMessagesController` (confirmed by the existing `sanitize(next_params[:body])` call)
   - `BulkChannelMessagesController` (confirmed by the existing `sanitize(next_params[:body])` call)
   - `JobsController` (confirmed by the existing `sanitize(sanitized_params[:apply_response_template])` call)
   PASS.

2. Verified `ChannelMessageTemplatesController` does NOT include `Sanitizer` and does NOT sanitize body. Subject follows the same pattern (no sanitization at the template level). Consistent. PASS.

3. Verified `text_replacer` nil-safety: `candidates_controller.rb` line 225 (approx): `return text if text.blank?`. Historical messages with NULL subject produce `nil`, which is `blank?`, so `text_replacer` returns nil. Then `channel_message.subject = nil` (no change). `channel_message.save!` succeeds because subject is nullable. PASS.

4. Verified XSS surface for `dangerouslySetInnerHTML`: The only `dangerouslySetInnerHTML` usage in the affected files is `ChannelMessageTemplateSelectionModal.tsx` line 49 for `mailMergeHtml` (which is the BODY template HTML). Subject is displayed as text content (`{mailMerge.subjectRaw}` at line 45), NOT via `dangerouslySetInnerHTML`. PASS.

5. Verified no other `dangerouslySetInnerHTML` usage touches subject anywhere in the diff. PASS.

No issues found.
