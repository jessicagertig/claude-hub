# Pass 1 — job-criteria-lifecycle

## Fact Check

### `Job#handle_before_update` (lines 475-483)

Plan G.3.1 says to add `handle_description_change` after `handle_status_change` in `handle_before_update`. Actual source at lines 475-483:

```ruby
def handle_before_update
  if changed?
    handle_status_change
    UpdateDistributionsJob.perform_later(id) unless skip_update_callback
    update_columns(display_location: location_pretty) if location_pretty_has_changed?
  end
end
```

Plan shows inserting `handle_description_change` between `handle_status_change` and `UpdateDistributionsJob.perform_later(id)`. CORRECT placement.

### `Job#handle_status_changed_to_published` (lines 542-557)

Plan G.5.1 adds `extract_job_criteria` as the last line. Actual source at lines 542-557 matches the plan's display. CORRECT.

### `Job#description_without_html` (line 677-678)

Plan G.4.1 references this as an existing method using `ActionView::Base.full_sanitizer.sanitize`. Actual: line 677-678 `ActionView::Base.full_sanitizer.sanitize(description)`. CORRECT.

### `Job` has `has_many :ai_job_application_summaries, through: :job_applications` (line 51)

Plan B.4.1 says to add `has_one :ai_job_criteria` near line 51. Actual: line 51 `has_many :ai_job_application_summaries, through: :job_applications`. CORRECT.

Plan B.1.3 checks that `job.ai_job_application_summaries` works for the `after_commit` callback query in `AiJobCriteria`. The through association exists at line 51. CORRECT.

### `GetResumeTextFromTextractJob` retry pattern (P4)

Plan claims this job uses `retry_on CustomErrorTextract, wait: 5.minutes, attempts: 3` with exhaustion block. Actual: line 6 `retry_on CustomErrorTextract, wait: 5.minutes, attempts: 3 do |job, _error|`. CORRECT.

### `before_update` transaction timing (spec Section 7)

Plan G.2.1 note says `extract_job_criteria` runs inside `handle_before_update` which is a `before_update` callback, meaning it runs inside the Job save transaction. `perform_later` pushes to Redis before transaction commits. Plan documents this as following existing patterns (e.g., `UpdateDistributionsJob.perform_later(id)` at line 479). Actual: line 479 `UpdateDistributionsJob.perform_later(id) unless skip_update_callback`. CORRECT — this is indeed an existing job enqueued from the same `before_update` callback.

### `ExtractJobCriteriaJob` retry error class

Plan G.1.1 uses `retry_on CustomErrorAiSummary`. The spec Section 7 says "Retry: same pattern as `GenerateAiJobApplicationSummaryJob`" which uses `retry_on CustomErrorAiSummary`. CORRECT.

## Completeness

- [x] `AiJobCriteria` model with status enum (B.1.1)
- [x] `after_commit` callback on `AiJobCriteria` (B.1.2)
- [x] `saved_change_to_status?` guard (not `status_changed?`) in after_commit (B.1.2)
- [x] `Job#extract_job_criteria` with Flipper gate (G.2.1)
- [x] Pending debounce (G.2.1)
- [x] `in_progress` status does NOT return early (G.2.1)
- [x] 2-minute delay on job (G.2.1)
- [x] `handle_description_change` guards (G.3.2)
- [x] `description_meaningfully_changed?` with HTML strip, digit strip, lowercase, strict equality (G.4.1)
- [x] `handle_status_changed_to_published` calls `extract_job_criteria` (G.5.1)
- [x] `ExtractJobCriteriaJob` with find_by guard, retry, exhaustion block (G.1.1)
- [x] Transaction timing documented (G.2.1 note)

## Findings

No findings. All fact claims verified. Lifecycle is complete.
