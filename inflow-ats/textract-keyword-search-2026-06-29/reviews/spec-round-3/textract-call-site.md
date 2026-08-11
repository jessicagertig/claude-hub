# Textract Call Site — Round 3

## Findings

No issues found.

## Verified

- **`after_commit` callback** (line 129, 197): Fully specified. Guards on `textract_job_result_text.present?` and `saved_change_to_textract_job_result_text?`. Consistent between "Textract success handler" and "Changes > Call site" sections.
- **No infinite loop**: When the extraction service updates `structured_extraction`/`structured_extraction_text`, the `after_commit` fires again, but the guard returns early because `saved_change_to_textract_job_result_text?` is false. Verified against actual model callback at textract_result.rb:114-116.
- **Background job** (lines 199-204): Fully specified — retry with `CustomErrorStructuredExtraction`, exhaustion behavior, failure isolation.
- **No interference with existing callback**: `queue_ai_summary_job` and the new callback both fire independently. Both have the same guards, both enqueue separate jobs. No ordering dependency.
