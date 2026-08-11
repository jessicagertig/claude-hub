# description-change-detection -- Round 4

## Scope

`Job#handle_description_change`, `description_meaningfully_changed?`, interaction with `handle_before_update` callbacks, transaction timing of `extract_job_criteria`.

## Findings

### handle_description_change placement

Added to `handle_before_update` after `handle_status_change`, before `UpdateDistributionsJob`. Runs inside the `if changed?` guard. Matches the existing callback pattern in `Job`.

### Guard ordering

1. `description_changed?` -- Rails dirty attribute check. Returns `false` if description was not modified in this save.
2. `published?` -- Only triggers for published jobs.
3. `description_meaningfully_changed?` -- Filters out cosmetic changes.

All three must pass before `extract_job_criteria` is called. Order is correct: cheapest checks first.

### description_meaningfully_changed? implementation

```ruby
old_text = ActionView::Base.full_sanitizer.sanitize(description_was).to_s.downcase.gsub(/[^a-z]/, '')
new_text = ActionView::Base.full_sanitizer.sanitize(description).to_s.downcase.gsub(/[^a-z]/, '')
old_text != new_text
```

- Uses `ActionView::Base.full_sanitizer.sanitize` -- same as existing `description_without_html` method.
- Removes all non-alpha characters (including digits) -- intentional per spec: "number-only changes like salary or years-of-experience do not change the extracted criteria structure."
- Lowercases before comparison.
- Returns `true` when alphabetic content differs.

Tests verify: HTML-only changes (false), whitespace-only (false), number-only (false), text changes (true), case-only (false).

### Transaction timing

`extract_job_criteria` runs inside `handle_before_update`, which is a `before_update` callback inside the Job save transaction. The `AiJobCriteria` save and `ExtractJobCriteriaJob.perform_later` both happen inside this transaction. If the outer Job save fails, the `AiJobCriteria` change rolls back but the Sidekiq job is already in Redis. The job's `find_by` guard handles this safely. This follows existing patterns (`UpdateDistributionsJob` in the same callback). Documented in spec Section 7.

### Interaction with handle_status_change

`handle_status_change` runs before `handle_description_change`. If a job is being published AND its description changes in the same save:
1. `handle_status_change` calls `handle_status_changed_to_published` which calls `extract_job_criteria`
2. `handle_description_change` checks `description_changed?` and `published?` (now true), then calls `extract_job_criteria` again

The second call sees `status_pending?` (set by the first call) and returns immediately (debounce). No double-extraction. Correct.

## Result: PASS -- 0 findings
