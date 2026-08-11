# Conventions Review — cursor_rules/backend/services.md

Repo: /Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings (HEAD 68e5e6a4e)
Diff: `git diff develop...HEAD -- app/services/ai_job_application_action/scoring/extract_criteria.rb app/services/ai_job_application_action/scoring/score_job_application.rb`

No issues found.

Diff shape verified: exactly three one-line string-literal → constant substitutions, nothing beyond.
- extract_criteria.rb:62 — `'No criteria sections found in job description'` → `AiJobCriteria::ZERO_CRITERIA_NO_SECTIONS_ERROR_MESSAGE`
- extract_criteria.rb:122 — `'No criteria extracted from job description'` → `AiJobCriteria::ZERO_CRITERIA_NONE_EXTRACTED_ERROR_MESSAGE`
- score_job_application.rb:43 — `'Criteria array is empty'` → `AiJobCriteria::ZERO_CRITERIA_EMPTY_ARRAY_ERROR_MESSAGE`

All three constants are defined in app/models/ai_job_criteria.rb:7-9 with values identical to the replaced literals.

Rules checked (services.md): class naming (no "Service"), descriptive public method names, IDs-from-jobs / objects-in-request-cycle, simple values, keyword arguments, find_by vs find, error handling patterns (method-level rescue, raise-for-retry, specific rescues, logging), guard clauses, memoization, namespacing/location. None are affected or violated by the touched lines; the pre-existing `update_columns(status: :failed, error_message: ...)` + `return` pattern is unchanged apart from the constant swap.
