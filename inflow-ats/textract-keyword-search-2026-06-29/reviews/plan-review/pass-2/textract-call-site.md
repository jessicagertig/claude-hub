# Pass 2 — textract-call-site

## Pass 1 corrections
None needed. Pass 1 found 0 findings.

## Fresh scrutiny

### Callback firing on initial TextractResult creation
- TextractResult is created before Textract processes the resume (textract_job_result_text is nil initially)
- `on: [:create, :update]` means the callback fires on both
- On create: `textract_job_result_text.present?` is FALSE → returns early. No job enqueued. Correct.
- On update (when parse_resume_text sets the text): both guards pass → job enqueued. Correct.
- This matches the existing `queue_ai_summary_job` callback behavior.

### Callback declaration order
- Plan places new callback immediately after existing:
  ```
  after_commit :queue_ai_summary_job, on: [:create, :update]
  after_commit :queue_structured_extraction_job, on: [:create, :update]
  ```
- Rails fires after_commit callbacks in declaration order
- Both callbacks are independent — order doesn't matter for correctness
- If one raises, it does not prevent the other (Rails 6.1 fires all after_commit callbacks independently)
- **Correct**

### Private method placement
- Plan says to add `queue_structured_extraction_job` as a private method
- The existing `queue_ai_summary_job` is private (textract_result.rb lines 114-143)
- The new method should be placed in the same private section
- Plan shows the implementation with correct guards
- **Correct**

### Callback passes ID, not self
- `ExtractStructuredResumeDataJob.perform_later(id)` passes the TextractResult's `id`
- Job receives positional argument: `def perform(textract_result_id)`
- Service loads record: `TextractResult.find_by(id: textract_result_id)`
- Consistent chain: callback → job (ID) → service (ID → record)
- Matches existing pattern: `queue_ai_summary_job` also passes `id` to `GenerateAiJobApplicationSummaryJob`

Wait — actually, checking the existing callback: `queue_ai_summary_job` enqueues `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)` — this uses a **keyword argument**. The plan's new callback uses a **positional argument**: `ExtractStructuredResumeDataJob.perform_later(id)`. This is consistent with the plan's job definition (`def perform(textract_result_id)` with positional arg) and matches the `GetResumeTextFromTextractJob` pattern (positional arg). Both patterns exist in the codebase; the plan is internally consistent.

### No modification to parse_resume_text
- Plan does NOT add any code to `GetResumeTextFromTextract#parse_resume_text`
- Integration is entirely via model callback
- The existing success path at lines 24-37 is untouched
- **Correct** — callback approach avoids modifying the service

## Completeness sweep

All spec requirements for the call site verified present:
- after_commit callback: step 6.5
- Same guards: step 6.5
- Enqueues job (not inline AI): step 6.5
- Failure isolation: step 5.1 (job retry/exhaustion)
- No interference with existing callback: step 6.5 (adds alongside, not modifies)
- Ordering (after text persisted): inherent in after_commit

## Findings

0 BLOCKER, 0 HIGH, 0 MED, 0 LOW
