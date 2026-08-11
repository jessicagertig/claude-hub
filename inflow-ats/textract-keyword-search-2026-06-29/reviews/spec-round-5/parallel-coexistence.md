# Parallel Coexistence — Round 5

## Findings

No issues found.

## Verified

- **Summary pipeline unchanged** (spec line 230, 251): `AiJobApplicationAction::Summary::Generate#generate` Call 1 (lines 46-58) continues to extract structured data via GPT-4o-mini and store on `AiJobApplicationSummary.structured_data`. Explicitly out of scope.
- **No write conflicts**: New extraction writes to `TextractResult.structured_extraction` / `structured_extraction_text`. Summary pipeline writes to `AiJobApplicationSummary.structured_data`. Different columns on different models.
- **AiApiRequest coexistence**: New extraction uses `call_type: 'keyword_extraction'` with `requestable: TextractResult`. Summary pipeline uses `call_type: 'extraction'` with `requestable: AiJobApplicationSummary`. Distinct on both dimensions — no conflation in cost reporting.
- **Callback isolation**: New `after_commit` callback guards on `saved_change_to_textract_job_result_text?`. When extraction service updates `structured_extraction_text`, the callback fires again but guard returns false — no re-trigger. Same guard on existing `queue_ai_summary_job` — also no re-trigger.
- **Duplicate API cost**: Both paths call GPT-4o-mini until cutover. Spec line 230 acknowledges this and states cutover plan.
