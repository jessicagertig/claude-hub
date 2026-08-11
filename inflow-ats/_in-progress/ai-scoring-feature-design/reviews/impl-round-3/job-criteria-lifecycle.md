# job-criteria-lifecycle -- Round 3

## Files reviewed

- `app/models/ai_job_criteria.rb`
- `app/models/job.rb` (working tree for uncommitted methods)
- `app/jobs/extract_job_criteria_job.rb`
- `app/services/ai_job_application_action/scoring/extract_criteria.rb`

## Assessment

Conditional on the uncommitted `job.rb` changes being committed:

1. **`AiJobCriteria` model:** Correct enum (4 values), `after_commit :resume_waiting_summaries` with `saved_change_to_status?` guard. Uses `find_each` for multiple waiting summaries. Correct per spec Section 1.

2. **`Job#extract_job_criteria`:** Flipper gate, pending debounce, reset for all non-pending statuses, `find_or_create_by` pattern via `build`/`save`, 2-minute delay. Correct per spec Section 7.

3. **`Job#handle_description_change`:** Three guard clauses (`description_changed?`, `published?`, `description_meaningfully_changed?`). Added to `handle_before_update` after `handle_status_change`. Correct per spec Section 7.

4. **`Job#description_meaningfully_changed?`:** Uses `ActionView::Base.full_sanitizer.sanitize`, strips non-alpha with `gsub(/[^a-z]/, '')`, lowercases, strict equality. Correctly ignores digit-only and whitespace-only changes. Correct per spec Section 7.

5. **`ExtractJobCriteriaJob`:** Has exhaustion block on `retry_on CustomErrorAiSummary` (correct per Known Failure Pattern #14 -- analog structural matching). `find_by` guard. Delegates to `ExtractCriteria` service.

6. **`ExtractCriteria` service:** Call 1 + Call 2, heading tier override, dedup, uses `update` (not `update_columns`) for succeeded transition to fire callback. Three-tier error handling matching analog pattern.

**All lifecycle paths verified. No issues beyond the uncommitted-changes BLOCKER.**

## Findings

No NEW findings.
