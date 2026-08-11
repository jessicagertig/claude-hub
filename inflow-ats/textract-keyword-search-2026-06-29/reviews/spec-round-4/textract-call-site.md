# Textract Call Site — Round 4

## Findings

No issues found.

## Verified

- **`after_commit` callback** (spec lines 129, 197): Fully specified. New callback on TextractResult alongside existing `queue_ai_summary_job`. Guards on `textract_job_result_text.present?` and `saved_change_to_textract_job_result_text?` — same guards as existing callback (confirmed at textract_result.rb:115-116).
- **No re-trigger on extraction update**: When the extraction service updates `structured_extraction` and `structured_extraction_text` on the TextractResult, `after_commit` fires again, but `saved_change_to_textract_job_result_text?` returns false (only `structured_extraction_text` changed). No infinite loop, no double-enqueue.
- **Background job requirement** (spec line 195): Explicitly stated — GPT-4o-mini call MUST NOT run synchronously. Matches codebase pattern where existing callback only enqueues `GenerateAiJobApplicationSummaryJob.perform_later` (textract_result.rb:128, 142).
- **Retry/exhaustion** (spec lines 201-203): `retry_on CustomErrorStructuredExtraction, wait: 5.minutes, attempts: 3` with exhaustion block. Matches `GetResumeTextFromTextractJob` pattern (get_resume_text_from_textract_job.rb:6).
- **Failure isolation** (spec line 204): Extraction job runs independently. If extraction fails, AI summary pipeline unaffected — confirmed by separate callbacks, separate jobs, no shared state.
- **Consistency between sections**: "Integration point" (line 129) says `after_commit` callback. "Changes > Call site" (lines 193-204) says same. No inconsistency.
- **Ordering**: Extraction fires AFTER `textract_job_result_text` is persisted — the `after_commit` pattern guarantees the update is committed before callbacks fire.
