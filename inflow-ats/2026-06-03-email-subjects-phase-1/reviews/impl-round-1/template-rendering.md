# template-rendering -- Round 1

## Findings

### render_template_message (job_application.rb lines 771-837)

1. Subject source read with `|| ''` fallback (line 784). PASS.
2. Triple-brace normalization applied to subject (line 785). PASS.
3. Per-tag triple-brace wrapping loop applied to subject (lines 786-788). PASS.
4. Zero-width space and NBSP cleanup applied to subject (line 789). PASS.
5. **Redcarpet exclusion: Subject does NOT go through `markdown.render()` at lines 794-796.** PASS -- this is the critical boundary and it is correctly enforced.
6. Three Mustache passes applied to subject (lines 806-808): `subject_raw`, `subject_html`, `template_subject_html`. PASS.
7. Invalid tags check extended to subject (lines 817-820): `subject_template.tags - known_tags` combined with body's invalid tags into `all_invalid_tags`. PASS.
8. Response hash includes all three subject keys (lines 826-828). PASS.

### parse_text in CreateStageAutomationMessage (lines 33-47)

9. Blank guard `return '' if text.blank?` at line 34. PASS.
10. Same 7-variable gsub chain as body. PASS.
11. Ends with `.html_safe` (line 46) -- inherited from original `parse_body`, harmless for subject (goes into Mailgun header, not ERB). PASS.

### parse_text in BulkChannelMessageSendJob (lines 51-66)

12. Blank guard `return '' if text.blank?` at line 52. PASS.
13. Same 7-variable gsub chain. PASS.
14. Does NOT call `.html_safe` -- correctly preserves existing difference from interactor version. PASS.

### parse_apply_response_text (job_application.rb lines 548-558)

15. Blank guard `return '' if text.blank?` at line 549. PASS.
16. Same 5-variable gsub chain as `html_safe_apply_email` (no SenderFullName/SenderFirstName -- correct, apply-response templates don't have sender context). PASS.
17. Does NOT call `.html_safe` -- correct, subject doesn't need it. PASS.

### clean_incoming_message boundary

18. `clean_incoming_message` (channel_message.rb line 57) only touches `body` and `body_sanitized_html`. Subject is not processed through `remove_bad_line_breaks`. PASS.

No issues found.
