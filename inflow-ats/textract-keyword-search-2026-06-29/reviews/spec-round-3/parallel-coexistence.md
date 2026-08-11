# Parallel Coexistence — Round 3

## Findings

No issues found.

## Verified

- Summary pipeline unchanged (line 230, line 251): explicitly out of scope. `AiJobApplicationAction::Summary::Generate#generate` still runs Call 1 extraction, stores on `AiJobApplicationSummary.structured_data`.
- No write conflicts: new extraction writes to `TextractResult.structured_extraction` / `structured_extraction_text`. Summary pipeline writes to `AiJobApplicationSummary.structured_data`. Different columns, different models.
- AiApiRequest tracking coexistence: the new extraction uses `call_type: 'keyword_extraction'` (line 174), while the summary pipeline uses `call_type: 'extraction'` (generate.rb:56). Different call_type values prevent conflation in cost reporting. Both use `requestable` polymorphic — new uses `TextractResult`, existing uses `AiJobApplicationSummary`. No overlap.
- `after_commit` callback isolation: the new extraction callback guards on `saved_change_to_textract_job_result_text?` (line 197). When the extraction service updates `structured_extraction` / `structured_extraction_text`, that triggers `after_commit` but the guard returns false (only `structured_extraction_text` changed, not `textract_job_result_text`). No re-trigger. The existing `queue_ai_summary_job` callback has the same guard — also no re-trigger. Confirmed safe.
- Duplicate API cost acknowledged (line 230): both paths make GPT-4o-mini calls until cutover. Intentional.
