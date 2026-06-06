# Implementation Plan — No TextractResult Path Fix

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Summary

When a user triggers AI summary generation on a job application that has a resume but no `TextractResult` record, the system now kicks off Textract processing and creates a `textract_processing` placeholder summary. Three gaps prevent this path from completing: (1) the placeholder summary never gets linked to the TextractResult once created, (2) if Textract retries exhaust, the placeholder is orphaned forever, and (3) a nil-guard crash exists in `destroy_previous_textract_results`. This plan fixes all three.

## Pattern Precedents

### Exhaustion block pattern
**File:** `app/jobs/bulk_generate_ai_summaries_job.rb:17-21`
```ruby
retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3 do |current_job, error|
  payload = current_job.arguments.first
  update_remaining_statuses_to_failed(payload)
  notify_failure(payload)
end
```
Change 2 follows this pattern: `retry_on ... do |current_job, error|` block for exhaustion cleanup.

### update_columns for targeted writes
**File:** `app/services/submit_resume_to_textract.rb:33,39` — already uses `update_columns` for targeted attribute writes that skip callbacks. Change 1 uses the same pattern.

### Guard clause pattern
**File:** `app/models/ai_job_application_summary.rb:38` — `return unless saved_change_to_status? && status_succeeded?` is the existing guard. Change 3 adds a preceding guard in the same style.

## Files to Modify

| File | What changes |
|---|---|
| `app/services/submit_resume_to_textract.rb` | Add 2 lines inside `if @textract_result.save` block: find waiting summary, update its `textract_result_id` |
| `app/jobs/get_resume_text_from_textract_job.rb` | Add exhaustion block to `retry_on`: find summary, destroy, broadcast failure |
| `app/models/ai_job_application_summary.rb` | Add `return unless textract_result` guard to `destroy_previous_textract_results` |
| `spec/services/submit_resume_to_textract_spec.rb` | NEW — test for Change 1 |
| `spec/jobs/get_resume_text_from_textract_job_spec.rb` | NEW — test for Change 2 |
| `spec/models/ai_job_application_summary_spec.rb` | Add test for Change 3 |

## Backend Changes

### Task A: Change 1 — Update textract_result_id on waiting summary

**Read before working:** `cursor_rules/backend/services.md`, `cursor_rules/backend/code_style_and_structure.md`

- [ ] A.1: In `app/services/submit_resume_to_textract.rb`, inside the `if @textract_result.save` block (after line 24, before line 27), add:
  - [ ] A.1.1: Find the waiting summary: `waiting_summary = @job_application.ai_job_application_summaries.find_by(status: :textract_processing, stale: false, textract_result_id: nil)`
  - [ ] A.1.2: Update it if found: `waiting_summary&.update_columns(textract_result_id: @textract_result.id)`

### Task B: Change 2 — Retry exhaustion cleanup

**Read before working:** `cursor_rules/backend/background_jobs.md`, `cursor_rules/backend/code_style_and_structure.md`

- [ ] B.1: In `app/jobs/get_resume_text_from_textract_job.rb`, change the `retry_on` declaration to include an exhaustion block:
  - [ ] B.1.1: Replace `retry_on CustomErrorTextract, wait: 5.minutes, attempts: 3` with:
    ```ruby
    retry_on CustomErrorTextract, wait: 5.minutes, attempts: 3 do |job, _error|
      job_application = JobApplication.find_by(id: job.arguments.first)
      next unless job_application

      summary = job_application.ai_job_application_summaries
        .find_by(status: :textract_processing, stale: false)
      next unless summary

      requesting_org_user = OrganizationUser.find_by(id: summary.requested_by_organization_user_id)
      summary.destroy

      textract_result = job_application.textract_results.order(created_at: :desc).first
      textract_result&.send(:broadcast_ai_summary_failed, requesting_org_user, 'Resume processing failed after multiple attempts.')
    end
    ```
  - [ ] B.1.2: Note: `broadcast_ai_summary_failed` is private on TextractResult. Use `send(:broadcast_ai_summary_failed, ...)` to call it from outside, matching how the method guards on nil `requesting_organization_user` internally. The summary must be destroyed BEFORE the broadcast so the user doesn't see a stale `textract_processing` status on reload.

### Task C: Change 3 — Nil guard on destroy_previous_textract_results

**Read before working:** `cursor_rules/backend/code_style_and_structure.md`

- [ ] C.1: In `app/models/ai_job_application_summary.rb`, add `return unless textract_result` as the FIRST line of `destroy_previous_textract_results` (before the existing `return unless saved_change_to_status? && status_succeeded?` guard at line 38).

## Test Plan

### Task D: Test for Change 1

**Read before working:** `cursor_rules/backend/code_style_and_structure.md`

- [ ] D.1: Create `spec/services/submit_resume_to_textract_spec.rb`
  - [ ] D.1.1: Set up: create a `job_application` with a resume, create a `textract_processing` `AiJobApplicationSummary` with `textract_result_id: nil` and `stale: false`
  - [ ] D.1.2: Stub `TextractResumeParser::Client` to return a mock textract response with a `job_id`
  - [ ] D.1.3: Call `SubmitResumeToTextract.new(job_application.id).submit_resume`
  - [ ] D.1.4: Assert the summary's `textract_result_id` is now set to the newly created `TextractResult`'s id
  - [ ] D.1.5: Assert `GetResumeTextFromTextractJob` was enqueued

### Task E: Test for Change 2

**Read before working:** `cursor_rules/backend/background_jobs.md`

- [ ] E.1: Create `spec/jobs/get_resume_text_from_textract_job_spec.rb`
  - [ ] E.1.1: Test exhaustion: set up a `job_application` with a `TextractResult` and a `textract_processing` summary. Simulate exhaustion by calling the exhaustion block directly (or use `perform_now` with a stub that raises `CustomErrorTextract` 3 times)
  - [ ] E.1.2: Assert the `textract_processing` summary is destroyed
  - [ ] E.1.3: Assert `broadcast_ai_summary_failed` was called (or verify GlobalChannel broadcast)

### Task F: Test for Change 3

- [ ] F.1: In `spec/models/ai_job_application_summary_spec.rb`, add a test:
  - [ ] F.1.1: Create an `AiJobApplicationSummary` with `textract_result_id: nil` and `status: :pending`
  - [ ] F.1.2: Update its status to `succeeded`
  - [ ] F.1.3: Assert no error is raised (the nil guard prevents `NoMethodError` on `textract_result.created_at`)

## Validation and Constraints

No new validations needed. The changes are:
- Change 1: targeted `update_columns` (skips validations intentionally — only setting FK)
- Change 2: `destroy` on the summary (standard Rails destroy)
- Change 3: early return guard (no validation involved)

## Frontend Changes

None. The frontend already handles `textract_processing` status display and `AI_SUMMARY_FAILED` WebSocket events.

## Documentation Impact

None.

## Risks and Open Questions

1. **Change 2 uses `send` to call private method:** `broadcast_ai_summary_failed` is private on TextractResult. Using `send` is a pragmatic choice — the alternative is making the method public or extracting it, both of which expand scope beyond the fix. The method already has internal nil guards.

2. **Pre-existing gap (not addressed):** If `SubmitResumeToTextract#submit_resume` fails at the AWS call before creating a TextractResult, the `textract_processing` summary is orphaned. This is outside the 3-change scope.

## Estimated Scope

- 3 files modified (service, job, model)
- 2 new test files, 1 modified test file
- ~10 lines of production code, ~60-80 lines of test code
