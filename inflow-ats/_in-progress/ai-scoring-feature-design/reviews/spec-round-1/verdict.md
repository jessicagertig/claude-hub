# Spec Review Round 1 — Verdict

## Finding Counts

| Severity | Count |
|----------|-------|
| BLOCKER | 0 |
| HIGH | 4 |
| MED | 7 |
| LOW | 9 |

## HIGH findings (amended)

1. **pipeline-status-lifecycle F1** — `Summary::Generate` final status not specified for new enum. `succeeded` would fire prematurely. **Amendment:** Added "Required Changes to `AiJobApplicationAction::Summary::Generate`" section to SPEC.md Section 3 specifying all status reference updates.

2. **pipeline-status-lifecycle F2** — `Summary::Generate` uses `status_in_progress?` and `status: :in_progress` which don't exist in the new enum. **Amendment:** Same section as F1 — listed all mapping changes.

3. **credit-consumption-timing F1** — `destroy_previous_textract_results` fires on `succeeded` transition — need to confirm it's safe to fire later in the pipeline. **Partially amended:** Added note about integer renumbering. The callback is safe because it destroys TextractResults older than the current one, and scoring reads from the current textract_result synchronously. No spec change needed for the callback itself.

4. **description-change-detection F1** — `extract_job_criteria` saves a record and enqueues a job inside `before_update` (inside transaction). Job could fire after transaction rollback. **Amendment:** Added note to Section 7 documenting the behavior and that the job's guard handles it safely.

## MED findings (amended)

1. **pipeline-status-lifecycle F3** — Resume points incomplete (missing `extracting` and `summarizing`). **Amendment:** Added resume points.

2. **pipeline-status-lifecycle F4** — Integer value renumbering not called out. **Amendment:** Added note to Section 3.

3. **job-criteria-lifecycle F1** — `extract_job_criteria` doesn't guard against `in_progress` status. **Amendment:** Updated guard to include `in_progress`.

4. **job-criteria-lifecycle F2** — Overwrite path for existing `succeeded`/`failed` records not specified. **Amendment:** Clarified flow for all existing record states.

5. **concurrency-and-race-conditions F1** — `ExtractCriteria` must use `update` (not `update_columns`) for `succeeded`. **Amendment:** Added explicit requirement to Section 4.

6. **data-model-contracts F1** — Spec lists 4 prompt files but 8 exist. **Amendment:** Updated to list all 8 with active vs. experimental classification.

7. **always-on-checks F3** — No test plan section (Known Failure Pattern #3). **Amendment:** Added Section 9 with test plan.

## Verdict: FAIL

4 HIGH findings and 7 MED findings required 9 spec amendments. Proceeding to Round 2.
