# test-coverage — Round 5

Fresh-eyes #6 grep sweep for EXISTING test assertions that the spec's changes will BREAK (test-ripple), across every signature/behavior change.

## Findings
- F1 [MED] -- W6 breaks the existing enqueue assertion in `ai_job_criteria_spec.rb:62-64`. It asserts `have_enqueued_job(GenerateAiJobApplicationSummaryJob).with(textract_result_id: textract_result.id)` (single-key). RSpec `.with` matches args EXACTLY; W6 adds `requesting_organization_user_id:` -> the actual args become two-key -> the existing matcher MISMATCHES -> the test FAILS. The spec's W6 test guidance added a new assertion but did not flag updating the existing `.with`. Fix: spec now requires updating `:62-64` to include `requesting_organization_user_id:`, and grepping spec/ for other `.with(...)` enqueue matchers on this job (Known Failure Pattern #6). The `:84` `.exactly(2).times` assertion has no `.with` -> unaffected. APPLIED.

- F2 [MED] -- C8 breaks THREE existing assertions in `get_resume_text_from_textract_job_spec.rb` AND the file was missing from the spec's update list. The W1/C8 change converts `cleanup_orphaned_summary` from `summary.destroy` to `summary.record_failure(...)`. Existing tests: `:32-36` `'destroys the textract_processing summary'` (asserts `count 1->0`) and `:72-78` `'destroys the summary without broadcasting'` (nil-user) both assert DESTRUCTION -> they BREAK (the summary now persists as `failed`). `:38-48` `'broadcasts AI_SUMMARY_FAILED to the requesting user'` still passes (broadcast preserved) but should also assert the summary persists. The file was NOT in the test plan summary (line 168). Fix: spec's W1/C8 now flags the inversions and the test plan summary adds `get_resume_text_from_textract_job_spec.rb`. APPLIED.

## Re-verified correct (ripple sweep — these are SAFE)
- `submit_resume_to_textract_spec.rb`: already tests the relink (`:25-41`) and stale-marking (`:76-89`) that W1 RELIES on; W1 doesn't change `SubmitResumeToTextract`, so these still pass. The spec's "update IF it asserts the entry-time enqueue" hedge is correct (it asserts relink/stale, not enqueue). SAFE.
- `SubmitResumeToTextractJob` enqueue assertions exist only in `queue_bulk_ai_summary_jobs_spec.rb` (bulk path, out of scope). No `enqueue_new_job_application`/`DocxToPdfJob` test asserts the intake Textract enqueue. SAFE -- W2's branch change has no existing intake-enqueue test to break (the spec adds new ones).
- `ai_job_application_summary_status_spec.rb`: no exhaustive-enum assertion that the new `failed: 4` value would break (no `defined_enums`/full-enum-list assertion). SAFE -- the spec's "update for the new enum value" (line 142) is additive.
- W4 inversion of `ai_job_application_summary_spec.rb:57-62` already flagged (line 113). SAFE.

## Amendments Applied (Round 5)
- SPEC.md W6 (line 98): update existing `ai_job_criteria_spec.rb:62-64` `.with` matcher for the new param; grep spec/ for siblings.
- SPEC.md W1/C8 (line 36): flag inverting `get_resume_text_from_textract_job_spec.rb:32-36/72-78` destroy->persist-as-failed assertions.
- SPEC.md test plan summary (line 168): add `get_resume_text_from_textract_job_spec.rb`; note the `ai_job_criteria_spec.rb:62-64` update.
