# Test Coverage — Round 1

## Findings

- F1 [INFO] No existing spec file for `SubmitResumeToTextract` — Change 1 test will need a new file at `spec/services/submit_resume_to_textract_spec.rb`.
- F2 [INFO] No existing spec file for `GetResumeTextFromTextractJob` — Change 2 test will need a new file at `spec/jobs/get_resume_text_from_textract_job_spec.rb`.
- F3 [INFO] Existing `spec/models/ai_job_application_summary_spec.rb` has only an enum test. Change 3 test will add to this file.
- F4 [INFO] Existing `spec/jobs/generate_ai_job_application_summary_job_spec.rb` exists but is not affected by these changes.

The spec's test requirements are sufficient for the 3 changes:
1. Change 1: Verify `textract_result_id` update after save — covers the core behavior
2. Change 2: Verify exhaustion cleanup (destroy + broadcast) — covers both outcomes
3. Change 3: Verify nil guard prevents NoMethodError — covers the defensive case

No existing tests should break from these changes:
- Change 1 adds code inside an existing `if` block — no existing behavior changes
- Change 2 adds an exhaustion block — previously the job silently discarded on exhaustion, now it cleans up
- Change 3 adds an early return guard — existing `destroy_previous_textract_results` tests (only the enum test exists, which doesn't test this callback) are unaffected

No issues found.

## Amendments Applied

None.
