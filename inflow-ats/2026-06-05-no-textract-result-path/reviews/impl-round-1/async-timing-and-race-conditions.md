# async-timing-and-race-conditions — Impl Round 1

## Findings

Verified async ordering:
- Change 1 at line 25-26 runs synchronously BEFORE `GetResumeTextFromTextractJob` enqueue at line 27. Correct.
- `update_columns` is a direct SQL update (no callbacks, no validations). Fast and atomic. No race window.
- The `queue_ai_summary_job` callback on TextractResult fires when `textract_job_result_text` is set. By that time, `textract_result_id` is already updated on the summary. Correct.

Verified exhaustion block:
- The exhaustion block in `get_resume_text_from_textract_job.rb:6-8` delegates to `cleanup_orphaned_summary`. The block receives `job` and `_error` from ActiveJob's retry exhaustion handler. `job.arguments.first` is `job_application_id`. Correct.

No issues found.
