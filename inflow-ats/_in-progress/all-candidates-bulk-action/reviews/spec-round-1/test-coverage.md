# Test Coverage — Round 1

## Findings

- F1 [HIGH] The spec has NO test requirements section. Per known failure pattern #3, "Every spec and implementation plan must state which existing tests need updating and what new test coverage is required." The REVIEW-ANGLES.md identifies:

  Existing specs needing updates:
  - `spec/interactors/queue_bulk_ai_summary_jobs_spec.rb` — new `kind` and `rescore_requested` context params
  - `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` — `kind`-based branching in `notify_complete` and `notify_failure`

  New specs needed:
  - Controller spec for `BulkAiJobApplicationSummariesController#all_stages` (no existing controller spec for `#create`)
  - Mailer spec for `BulkAllStagesAiSummaryResultMailer`

  Add a test requirements section.

## Amendments Applied

- Added "Test requirements" section to spec with the four items above
