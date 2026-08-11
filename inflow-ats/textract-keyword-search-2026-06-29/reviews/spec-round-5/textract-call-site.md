# Textract Call Site — Round 5

## Findings

No issues found.

## Verified

- **after_commit callback** (spec lines 129, 197): Specified as new `after_commit` on TextractResult, alongside existing `queue_ai_summary_job` (model line 7). Same guards: `textract_job_result_text.present?` (model line 115) and `saved_change_to_textract_job_result_text?` (model line 116).
- **No infinite loop**: When the extraction service later updates `structured_extraction`/`structured_extraction_text` on the TextractResult, `after_commit` fires again. But `saved_change_to_textract_job_result_text?` returns false (only `structured_extraction_text` changed, not `textract_job_result_text`). Both callbacks return early. No re-trigger.
- **No interference with existing callback**: `queue_ai_summary_job` and the new callback both fire independently on the same `after_commit` event. Both enqueue separate Sidekiq jobs. No ordering dependency, no shared state.
- **Background job** (spec lines 199-204): `ExtractStructuredResumeDataJob` calls the service with TextractResult ID. `retry_on CustomErrorStructuredExtraction, wait: 5.minutes, attempts: 3` with exhaustion block — matches `GetResumeTextFromTextractJob` pattern (job line 6). Exhaustion: log and move on.
- **Failure isolation** (spec line 204): Extraction job is independent of `GenerateAiJobApplicationSummaryJob`. If extraction fails, AI summary pipeline is unaffected.
- **Ordering**: `after_commit` fires after the transaction commits, so `textract_job_result_text` is persisted before the extraction job runs. Correct.
- **Consistency**: "Textract success handler" section (line 129) and "Changes > Call site" section (lines 193-204) both describe `after_commit` callback. Consistent.
