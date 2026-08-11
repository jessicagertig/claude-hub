# job-criteria-lifecycle -- Round 4

## Scope

`AiJobCriteria` creation via `Job#extract_job_criteria`, debounce, `handle_description_change` guards, `description_meaningfully_changed?`, `ExtractJobCriteriaJob`, and the `after_commit` callback for resume.

## Findings

### AiJobCriteria model

- `belongs_to :job`, `has_many :ai_api_requests, as: :requestable` -- correct.
- Status enum with `_prefix: true`: `pending: 0`, `in_progress: 1`, `succeeded: 2`, `failed: 3` -- matches spec Section 1.
- `validates :status, presence: true` -- present.
- `after_commit :resume_waiting_summaries, on: [:update]` with guard `saved_change_to_status? && status_succeeded?` -- correct. Uses `saved_change_to_status?` (not `status_changed?`), matching the `AiJobApplicationSummary#destroy_previous_textract_results` pattern.

### resume_waiting_summaries callback

Finds `job.ai_job_application_summaries.where(status: :awaiting_job_criteria)` and enqueues `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: ...)` for each. Uses `find_each` for batch safety. Matches spec Section 1.

### Job#extract_job_criteria

- Flipper gate: `return unless Flipper.enabled?(:AI_APPLICANT_SUMMARY, organization)` -- correct.
- Debounce: `return if existing_ai_job_criteria&.status_pending?` -- returns only on `pending`. Does NOT return on `in_progress` (spec says `in_progress` does not return early).
- New record path: `self.ai_job_criteria = AiJobCriteria.new(job: self, status: :pending)` then `return unless ai_job_criteria.save` -- save return value checked per `core_critical_rules.md` Rule 11.
- Existing record path: `existing_ai_job_criteria.update_columns(status: :pending, error_message: nil)` -- resets to `pending` and clears error. Uses `update_columns` to bypass `after_commit` (no false resume). Correct per spec.
- Enqueue: `ExtractJobCriteriaJob.set(wait: 2.minutes).perform_later(ai_job_criteria.id)` -- 2-minute delay per spec.

### Job#handle_description_change

Called from `handle_before_update` alongside `handle_status_change`. Guards: `description_changed?`, `published?`, `description_meaningfully_changed?`. Calls `extract_job_criteria`. Matches spec Section 7.

### Job#description_meaningfully_changed?

Strips HTML with `ActionView::Base.full_sanitizer.sanitize`, lowercases, removes non-alpha (`gsub(/[^a-z]/, '')`). Digits stripped intentionally per spec. Strict equality comparison. Matches spec Section 7.

### ExtractJobCriteriaJob

- Queue: `:default` -- correct.
- `retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3` with exhaustion block that sets `failed` -- matches analog `GenerateAiJobApplicationSummaryJob`. Exhaustion block present per Known Failure Pattern #14.
- `find_by` guard: `return unless ai_job_criteria` -- handles rolled-back records from transaction failures.
- Error handling: `CustomErrorAiSummary` re-raises, `StandardError` sets `failed` and does not re-raise.

### Job#handle_status_changed_to_published

`extract_job_criteria` added as the last line. Correct per spec Section 7.

## Result: PASS -- 0 findings
