# Approved Decisions — Surface job-criteria failures to the candidate display

Deterministic criteria errors (the 3 hardcoded strings in `ExtractCriteria`):
- `'Job description is blank'`
- `'No criteria sections found in job description'`
- `'No criteria extracted from job description'`

---

## Backend — fail the summary when criteria is failed (score checkpoint)

In `score_job_application.rb`, at the point a summary evaluates the job's latest criteria:
- Criteria **failed** → `@ai_job_application_summary.update(status: :failed, error_message: ai_job_criteria.error_message)` and return. Uses `update` (NOT `update_columns`) so it broadcasts and the display updates live.
- Criteria **pending / in_progress / retrying** → set `awaiting_job_criteria` and wait (does not fail).
- Criteria **blank** → set `awaiting_job_criteria` + `@job.extract_job_criteria`.

## Backend — fail already-parked summaries when criteria fails

`AiJobCriteria#fail_waiting_summaries` — fails the job's summaries currently in `awaiting_job_criteria` via `update`, copying the criteria's `error_message`. Mirrors the sibling `resume_waiting_summaries`. Called from `ExtractCriteria` at all 3 deterministic failure sites. The blank-description case should rarely fire, but the guard stays.

The `AiJobCriteria` record itself stays on `update_columns` (no toast for the criteria failure). Only the **summary** uses `update` (broadcasts).

## Frontend failure signal

Signal for the frontend to branch the failed state = a **computed boolean** `failed_due_to_no_job_criteria` (frontend: `failedDueToNoJobCriteria`).

- NOT a new status enum value. NOT a stored column.
- `true` when the summary is `status_failed?` AND its `error_message` is one of the 3 deterministic criteria strings.
- Model: `AiJobApplicationSummary#failed_due_to_no_job_criteria?` (uses `JOB_CRITERIA_ERROR_MESSAGES` constant), exposed via the summary serializer. String match lives once, on the backend.
- Rationale: a new status value would ripple into `BROADCAST_STATUSES`, the frontend status union, the `PlatoLoadingState` maps, and every status switch — no behavioral payoff, since "failed is failed."

## Frontend failed-state copy

`PlatoTabEmptyState`, when `failedDueToNoJobCriteria` and status `failed`:
- Title: "Plato needs clearer job requirements"
- Message: "Plato couldn't find requirements in this job's description. Update the job description, then regenerate."
- No action button, no credit footnote.
