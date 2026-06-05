# pipeline-parity -- Round 2

## Findings

Re-verified all four pipelines with fresh scrutiny.

### Additional checks this round:

1. Verified `wrap_parameters format: [:json]` in `config/initializers/wrap_parameters.rb` ensures Rails auto-wraps JSON request bodies. `useChannelMessage.ts` sends `{ channelId, body, subject }` flat, and Rails wraps it under `channel_message` for `params.require(:channel_message).permit(:body, :subject)`. PASS.

2. Verified `apiPost` in `api.ts` line 52 calls `allKeysToSnake(variables)` on outgoing payloads. `subject` is already snake_case, so no transformation needed. PASS.

3. Verified `apiGet` in `api.ts` line 22 calls `allKeysToCamel(data)` on incoming responses. Backend response keys `subject_raw`, `subject_html`, `template_subject_html` correctly become `subjectRaw`, `subjectHtml`, `templateSubjectHtml` on the frontend. PASS.

4. Verified `useChannelMessage.ts` was NOT modified (no diff). This is correct -- the hook passes `variables` directly to `apiPost`, so `subject` flows through without explicit code changes. PASS.

5. Verified `useChannelMessageTemplate.ts` was NOT modified (no diff). Same reason -- hooks pass `variables` directly. PASS.

6. Verified edge case: when `@message_params[:subject]` is nil (template with NULL subject), `parse_text(nil)` returns `''` via the blank guard. Empty string passes `CustomChannelMessageValidator` (no `{{...}}` pattern). Mailer fallback triggers via `.presence` returning nil for `''`. Full chain is correct. PASS.

No issues found.
