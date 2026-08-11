# Spec Review — Round 5 Verdict
**Date:** 2026-06-23 03:30

## Counts
- BLOCKER: 0
- HIGH: 0
- MED: 2
- LOW: 0

## Findings
- test-coverage F1 [MED]: W6 breaks `ai_job_criteria_spec.rb:62-64`'s `.with(textract_result_id:)` enqueue matcher (RSpec `.with` is exact; the new `requesting_organization_user_id:` param makes it mismatch). Amended: update the existing assertion + grep siblings.
- test-coverage F2 [MED]: C8 (destroy->record_failure) breaks `get_resume_text_from_textract_job_spec.rb:32-36` and `:72-78` "destroys the summary" assertions, and the file was missing from the spec's update list. Amended: flag the inversions + add the file to the test plan.

Both are Known Failure Pattern #6 test-ripples (existing spec assertions that the signature/behavior changes break). All other angles clean.

## Amendments Applied
- W6 test (line 98): update `ai_job_criteria_spec.rb:62-64` `.with` for the new param.
- W1/C8 (line 36): invert `get_resume_text_from_textract_job_spec.rb` destroy assertions to persist-as-failed.
- Test plan summary (line 168): add `get_resume_text_from_textract_job_spec.rb`; note the ai_job_criteria_spec update.

## Verdict: FAIL
Two MED test-ripples found and amended (real build-breakers for the implementation). The clean-pass streak (Round 4 PASS) is broken; the counter resets. Rounds 6-7 should run clean.
