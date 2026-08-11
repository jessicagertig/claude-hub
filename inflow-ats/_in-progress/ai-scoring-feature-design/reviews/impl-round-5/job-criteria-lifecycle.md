# job-criteria-lifecycle -- Round 5

## Scope
`AiJobCriteria` creation via `Job#extract_job_criteria`, debounce mechanism, `handle_description_change` guards, `description_meaningfully_changed?`, `ExtractJobCriteriaJob`, `after_commit` callback for resume.

## Files reviewed
- `app/models/ai_job_criteria.rb` (full file)
- `app/models/job.rb` lines 476-717
- `app/jobs/extract_job_criteria_job.rb` (full file)
- `app/services/ai_job_application_action/scoring/extract_criteria.rb` (full file)

## `extract_job_criteria` verified

1. **Flipper gate:** `return unless Flipper.enabled?(:AI_APPLICANT_SUMMARY, organization)` -- line 689
2. **Debounce:** `return if existing_ai_job_criteria&.status_pending?` -- line 693. Only `pending` triggers early return. `in_progress` does NOT return early (resets to `pending` per spec).
3. **Reset existing:** `update_columns(status: :pending, error_message: nil)` -- line 696
4. **Create new:** `AiJobCriteria.new(job: self, status: :pending)` -> `return unless ai_job_criteria.save` -- lines 698-699
5. **Enqueue:** `ExtractJobCriteriaJob.set(wait: 2.minutes).perform_later(ai_job_criteria.id)` -- line 702
6. **Guard clause style:** bare `return` throughout -- per `core_critical_rules.md` Rule 8

## `handle_description_change` verified

Three guards in correct order:
1. `return unless description_changed?` -- line 706
2. `return unless published?` -- line 707
3. `return unless description_meaningfully_changed?` -- line 708
Then calls `extract_job_criteria` -- line 710

## `description_meaningfully_changed?` verified

Strips HTML via `ActionView::Base.full_sanitizer.sanitize`, lowercases, removes non-alpha chars (`gsub(/[^a-z]/, '')`). Intentionally removes digits per spec. Strict inequality comparison.

## Callback placement

`handle_description_change` added to `handle_before_update` at line 480, after `handle_status_change` at line 479. `extract_job_criteria` added as last line of `handle_status_changed_to_published` at line 560.

## `after_commit` callback on `AiJobCriteria`

- Uses `saved_change_to_status?` (not `status_changed?`) -- correct for `after_commit` context
- Guards on `status_succeeded?`
- Uses `find_each` for multiple waiting summaries
- Enqueues `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id:)`

## Transaction safety

`extract_job_criteria` runs inside `handle_before_update` (inside the Job save transaction). If the Job save fails, `AiJobCriteria` save rolls back but Sidekiq job is already enqueued. Job's `find_by` guard handles this -- finds no record, returns. Follows existing pattern (`UpdateDistributionsJob` in same callback).

## Findings

None.
