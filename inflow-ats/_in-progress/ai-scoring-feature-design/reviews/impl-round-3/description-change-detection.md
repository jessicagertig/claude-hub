# description-change-detection -- Round 3

## Files reviewed

- `app/models/job.rb` lines 476-484 (working tree) -- `handle_before_update`
- `app/models/job.rb` lines 705-717 (working tree) -- `handle_description_change`, `description_meaningfully_changed?`

## Assessment

1. **`handle_description_change` placement:** Called from `handle_before_update` after `handle_status_change`, before `UpdateDistributionsJob`. Correct placement per spec Section 7.

2. **Guard ordering:** `description_changed?` -> `published?` -> `description_meaningfully_changed?`. All three guards present. Correct per spec Section 7.

3. **`description_meaningfully_changed?` implementation:**
   - Uses `ActionView::Base.full_sanitizer.sanitize` (matches existing `description_without_html` at line 677-678)
   - Strips non-alpha via `gsub(/[^a-z]/, '')` (digits intentionally removed per spec)
   - Lowercases both
   - Strict inequality comparison
   - Correct per spec Section 7.

4. **Transaction timing:** `extract_job_criteria` runs inside `handle_before_update` (inside `before_update` callback). Creates/updates `AiJobCriteria` and enqueues job inside the transaction. If Job save fails, AiJobCriteria save rolls back but Sidekiq job is in Redis. Job's `find_by` guard handles this. Matches existing pattern (`UpdateDistributionsJob` in same callback). Correct per spec Section 7 note.

## Findings

No findings.
