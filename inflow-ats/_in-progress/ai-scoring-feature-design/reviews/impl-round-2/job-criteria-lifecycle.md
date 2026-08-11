# job-criteria-lifecycle — Implementation Review Round 2

## Files reviewed

- `app/models/ai_job_criteria.rb` — model, status enum, `after_commit` callback
- `app/models/job.rb` — `extract_job_criteria` (lines 688-703), `handle_description_change` (lines 705-711), `description_meaningfully_changed?` (lines 713-717), `handle_before_update` (line 480), `handle_status_changed_to_published` (line 560)
- `app/jobs/extract_job_criteria_job.rb` — job execution, retry, guard
- `app/services/ai_job_application_action/scoring/extract_criteria.rb` — extraction service

## Findings

No findings.

1. **`extract_job_criteria` matches spec Section 7:** Flipper gate (line 689), pending guard (line 693), status reset for existing records (line 696), new record creation (lines 698-699), save check (line 699), 2-minute delayed enqueue (line 702).
2. **Debounce mechanism correct:** `pending` status + early return on `status_pending?` (line 693). Edits 2-5 during 2-minute window return immediately. Job reads latest description at execution time.
3. **`handle_description_change` guards correct:** `description_changed?` (line 706), `published?` (line 707), `description_meaningfully_changed?` (line 708). All three must pass. Matches spec Section 7.
4. **`description_meaningfully_changed?` implementation:** Strips HTML via `ActionView::Base.full_sanitizer.sanitize`, lowercases, removes non-alpha with `gsub(/[^a-z]/, '')`, strict equality comparison. Matches spec exactly (strips HTML, removes non-alpha including digits, lowercase, strict equality).
5. **`handle_description_change` placed in `handle_before_update`:** Line 480, alongside `handle_status_change` (line 479). Matches spec Section 7.
6. **`extract_job_criteria` called from `handle_status_changed_to_published`:** Line 560. Matches spec Section 7.
7. **`AiJobCriteria.resume_waiting_summaries`:** Fires on `update` `after_commit`, guards on `saved_change_to_status? && status_succeeded?`. Finds all `awaiting_job_criteria` summaries, enqueues `GenerateAiJobApplicationSummaryJob` for each. Uses `update` for `succeeded` transition (not `update_columns`) to fire the callback. Matches spec Section 1.
8. **`ExtractJobCriteriaJob`:** `find_by` guard (line 13-14), delegates to `ExtractCriteria`, retry pattern matches analog (`retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3` with exhaustion block). Matches spec Section 7.
9. **`in_progress` status not triggering early return:** `extract_job_criteria` only returns early on `status_pending?`. For `in_progress`, it resets to `pending` (line 696). Matches spec: "The only status that triggers an early return is `pending`."
