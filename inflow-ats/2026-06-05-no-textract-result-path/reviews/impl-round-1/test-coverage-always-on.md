# Test Coverage (always-on check) — Impl Round 1

## Findings

Verified test files:
- `spec/services/submit_resume_to_textract_spec.rb` — NEW. Tests Change 1: verifies `textract_result_id` is updated on waiting summary, verifies `GetResumeTextFromTextractJob` is enqueued, verifies no-op when no waiting summary exists. 3 tests, all passing.
- `spec/jobs/get_resume_text_from_textract_job_spec.rb` — NEW. Tests Change 2: verifies summary destroyed, verifies `AI_SUMMARY_FAILED` broadcast, verifies no-op when no summary, verifies silent cleanup for auto-generated summaries. 4 tests, all passing.
- `spec/models/ai_job_application_summary_spec.rb` — MODIFIED. Tests Change 3: verifies no error when status changes to succeeded with nil `textract_result_id`. 1 test, passing.
- `spec/jobs/generate_ai_job_application_summary_job_spec.rb` — UNMODIFIED. All 12 existing tests passing. No regressions.

Test approach for Change 2: extracted exhaustion logic into `cleanup_orphaned_summary` class method and tested it directly. This mirrors the pattern in `bulk_generate_ai_summaries_job_spec.rb:112-126` which tests `notify_failure` directly rather than simulating full retry exhaustion.

No issues found.
