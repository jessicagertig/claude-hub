# description-change-detection — Implementation Review Round 2

## Files reviewed

- `app/models/job.rb` — `handle_before_update` (line 476-485), `handle_description_change` (lines 705-711), `description_meaningfully_changed?` (lines 713-717), `extract_job_criteria` (lines 688-703)

## Findings

No findings.

1. **`handle_description_change` positioned correctly in `handle_before_update`:** Line 480, after `handle_status_change` (line 479), before `UpdateDistributionsJob` (line 481). All three fire inside the `changed?` guard (line 478).
2. **Guard chain correct:** `description_changed?` -> `published?` -> `description_meaningfully_changed?`. All three required. If the job is not published, no extraction occurs (correct: unpublished jobs have no applicants to score).
3. **`description_meaningfully_changed?` algorithm correct:** Strips HTML via `ActionView::Base.full_sanitizer.sanitize`, converts to string with `.to_s` (handles nil), lowercases with `.downcase`, removes non-alpha with `.gsub(/[^a-z]/, '')`, strict equality comparison. This correctly handles: whitespace-only changes (no-op), number-only changes like salary (no-op), HTML restructuring without text changes (no-op), and actual text changes (meaningful).
4. **`before_update` timing and transaction concern acknowledged:** The spec explicitly addresses this: "Setting `pending` and saving BEFORE enqueuing is what makes the debounce work." The implementation matches. `extract_job_criteria` saves the `AiJobCriteria` record (line 696 or 699) before enqueuing (line 702). If the outer Job save fails, the `AiJobCriteria` save rolls back but the Sidekiq job fires. The job's `find_by` guard handles this safely.
5. **Interaction with publish callback:** Both `handle_status_changed_to_published` (line 560) and `handle_description_change` (line 710) call `extract_job_criteria`. On first publish, `handle_status_change` fires `handle_status_changed_to_published` which calls `extract_job_criteria`. `handle_description_change` also fires but `description_changed?` is likely false (publish doesn't change description), so it returns early. No double-enqueue.
