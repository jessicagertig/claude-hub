# spec-compliance — Impl Round 1

## Findings

### Change 1: SubmitResumeToTextract
- Spec: "find the AiJobApplicationSummary on @job_application where status: :textract_processing, stale: false, and textract_result_id is nil, then call update_columns(textract_result_id: @textract_result.id)"
- Implementation: `find_by(status: :textract_processing, stale: false, textract_result_id: nil)` + `&.update_columns(textract_result_id: @textract_result.id)`
- MATCH

### Change 2: GetResumeTextFromTextractJob
- Spec: "Add an exhaustion block to the existing retry_on declaration. When retries are exhausted: find the AiJobApplicationSummary on the job application where status: :textract_processing and stale: false, destroy it, and call broadcast_ai_summary_failed on the job application's latest TextractResult to notify the requesting_organization_user_id from the destroyed AiJobApplicationSummary."
- Implementation: Exhaustion block delegates to `cleanup_orphaned_summary` class method which does exactly this: finds summary, destroys it, finds latest TextractResult, calls `broadcast_ai_summary_failed`.
- MATCH (extracted to class method is a minor structural deviation for testability, but behavior is identical)

### Change 3: AiJobApplicationSummary
- Spec: "Add return unless textract_result to destroy_previous_textract_results, before the existing return unless saved_change_to_status? && status_succeeded? guard."
- Implementation: `return unless textract_result` at line 38, before existing guard at line 39.
- MATCH

### Test requirements
- Change 1 test: verifies `textract_result_id` update after save. MATCH.
- Change 2 test: verifies summary destroyed and `AI_SUMMARY_FAILED` broadcast. MATCH.
- Change 3 test: verifies no error when `textract_result_id` is nil and status changes to succeeded. MATCH.

No issues found.
