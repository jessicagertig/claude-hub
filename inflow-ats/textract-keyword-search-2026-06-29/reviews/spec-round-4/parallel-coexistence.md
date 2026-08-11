# Parallel Coexistence — Round 4

## Findings

No issues found.

## Verified

- **Summary pipeline unchanged** (spec lines 228-230, 247-251): `AiJobApplicationAction::Summary::Generate#generate` not modified. Call 1 extraction (generate.rb:46-58) continues to run, stores on `AiJobApplicationSummary.structured_data`.
- **No write conflicts**: New extraction writes to `TextractResult.structured_extraction` and `TextractResult.structured_extraction_text`. Summary pipeline writes to `AiJobApplicationSummary.structured_data`. Different columns, different models. Both read `textract_job_result_text` (read-only).
- **AiApiRequest coexistence**: New extraction uses `call_type: 'keyword_extraction'` (spec line 174), `requestable: TextractResult`. Summary pipeline uses `call_type: 'extraction'` (generate.rb:56), `requestable: AiJobApplicationSummary`. Different call_type values and different requestable types — no conflation in cost reporting or queries.
- **Callback isolation**: Both `queue_ai_summary_job` and the new extraction callback guard on `saved_change_to_textract_job_result_text?`. When the extraction service updates `structured_extraction`/`structured_extraction_text`, neither callback re-fires (different column changed). No interference.
- **Duplicate API cost**: Both paths make GPT-4o-mini calls on the same input until cutover. Spec line 230 acknowledges this and documents the plan to remove the duplicate once stable.
