# HANDOFF — Surface job-criteria failures on the Plato candidate display

**Branch:** `qa-refinements` (source repo `/Users/jessica/wrk/wrk-corp/inflow-ats`). All changes below are **UNCOMMITTED**.
**Companion:** `approved-decisions.md` (same dir) has the confirmed design decisions.

## Goal
When job-criteria extraction fails **deterministically** (the job description yields no usable criteria), surface it on the candidate's Plato tab so the user knows to fix the job description — instead of the summary hanging in `awaiting_job_criteria` forever. Criteria failures must **not** toast (often ephemeral, one-per-candidate would be noise).

## Deterministic criteria errors (the 3 hardcoded strings in `ExtractCriteria`)
- `'Job description is blank'`
- `'No criteria sections found in job description'`
- `'No criteria extracted from job description'`
(The 4th, `'Criteria array is empty'` at `score_job_application.rb`, is **dead code** — a succeeded criteria always has a non-empty array. Left untouched.)

## What's built (all uncommitted)
1. **`app/services/ai_job_application_action/scoring/score_job_application.rb`** — at the criteria checkpoint: criteria `failed` → `@ai_job_application_summary.update(status: :failed, error_message: ai_job_criteria.error_message)` (uses `update`, broadcasts, no update_columns); `pending`/`in_progress`/`retrying` → `awaiting_job_criteria` (waits); `blank` → await + `extract_job_criteria`.
2. **`app/models/ai_job_criteria.rb`** — new public `fail_waiting_summaries` (mirrors sibling `resume_waiting_summaries`): fails the job's `awaiting_job_criteria` summaries via `update`, copying `error_message`.
3. **`app/services/ai_job_application_action/scoring/extract_criteria.rb`** — calls `@ai_job_criteria.fail_waiting_summaries` at **all 3** deterministic failure sites (right after each `update_columns(status: :failed, ...)`). The criteria record itself stays `update_columns` (no toast).
4. **`app/models/ai_job_application_summary.rb`** — `JOB_CRITERIA_ERROR_MESSAGES` constant (the 3) + `failed_due_to_no_job_criteria?` (`status_failed?` && error_message ∈ the 3).
5. **`app/serializers/api/v1/ai_job_application_summary_serializer.rb`** — exposes `failed_due_to_no_job_criteria`.
6. **`app/javascript/shared/types/aiJobApplicationSummary.ts`** — added `failedDueToNoJobCriteria?: boolean`.
7. **`app/javascript/ats/src/views/jobApplications/Plato/PlatoTabEmptyState.tsx`** — override in `resolveStatus` for `status === "failed" && failedDueToNoJobCriteria`: title "Plato needs clearer job requirements", message "...Update the job description, then try again.", **"Try again" button** (`refresh-cw`, `onClick = options.onClick = handleGenerate`), footnote null. (Also renamed `opts`→`options` per request.)
8. **`app/javascript/ats/src/views/jobApplications/PlatoTab.tsx`** — failed branch passes `failedDueToNoJobCriteria={fullSummary.failedDueToNoJobCriteria}`.

## PRIMARY RESEARCH TASK (why a new session)
**What happens to the bulk claim rows (`BulkAiSummaryJobApplication`, table `bulk_ai_summary_job_applications`) when job criteria fail in a bulk job?**

Findings so far (verify, don't trust):
- Enum: `processing: 0, done: 1, failed: 2, deferred: 3` (`bulk_ai_summary_job_application.rb:10`). Default is `processing` (0) — Jessica's "pending".
- `bulk_generate_ai_summaries_job.rb`: each iteration calls `result.textract_result.generate_ai_summary_with_credit_flow`, then unconditionally `job_application_bulk_job_status.update_columns(status: :done)` on normal return. Our criteria-failure path sets the **summary** to `failed` via `update` (no raise), so the iteration returns normally → the claim row is set **`:done` even though the summary failed**.
- BUT criteria extraction is async (`ExtractJobCriteriaJob`). In bulk, a summary can be parked `awaiting_job_criteria` and the claim row set `:done` before criteria resolves; when criteria fails async, `fail_waiting_summaries` fails the summary — claim row already `:done`.
- `rescue StandardError` in the iteration only logs (no status update) → those rows stay `processing`. `rescue CustomErrorAiSummary` re-raises → `retry_on`; check the exhaustion block for whether it marks rows.
- `on_complete` computes `done`/`deferred`/`failed` counts for the bulk result mailer/UI.

Questions to answer:
1. What terminal state do claim rows actually end in when criteria fails (`done`? `processing`? `failed`?)?
2. Is marking `:done` when the summary failed wrong for the bulk result email / counts?
3. If rows can stay `processing` ("pending") forever, where and how should they be resolved?

## Other open items
- **Inline "Edit job description" link** in the no-criteria message → `/jobs/${jobId}/setup/description` (analogs: `RunPlatoAddDescriptionModal.tsx:32`; inline-link pattern `RunPlatoNoCandidatesModal.tsx:61` `Styled.InlineLink`). Needs `jobId` passed from `PlatoTab` to `PlatoTabEmptyState`. NOT done.
- **Footnote** — RESOLVED. No-criteria state is now a hybrid of the standard failed state: message says "so no credit was used", footnote restored to `Uses 1 credit · {creditsRemaining} remaining` (retry spends one on success).
- **No rspec** written for: score checkpoint failed-branch, `fail_waiting_summaries`, `failed_due_to_no_job_criteria?`. Rspec is not in the pre-commit gate.
- **Commit** when ready — inflow-ats commit detached (Cypress pre-commit can exceed 10 min); never `--no-verify`.

## Open — summary appears stuck on `awaiting_job_criteria`
Observed on staging: summary 287 (job_application 8684) sat on the Plato loading state after its criteria failed.
- The failed-summary update is **async** — it fires from `ExtractJobCriteriaJob` → `ExtractCriteria`'s `criteria_sections.empty?` branch (`extract_criteria.rb:61`) → `AiJobCriteria#fail_waiting_summaries`, NOT synchronously with the user. In the repro, criteria 13's Call 1 returned only `non_criteria` sections, so it should have failed summary 287 when that job finished (~19:34:07).
- Diagnose: `AiJobApplicationSummary.find(287).status`
  - `failed` → backend worked; the Plato tab did not refetch off the `ai_summary_status_change` broadcast — it's stuck on the `awaiting_job_criteria` loading state (`PlatoLoadingState`). **Frontend refetch/refresh bug.**
  - still `awaiting_job_criteria` → `fail_waiting_summaries` didn't catch it (check the criteria's `job` vs the summary's `job`, or a swallowed error in the summary `update`).

## Recovery flow (design intent)
User sees the no-criteria failed state → edits the job description → `handle_criteria_extraction_after_commit` re-extracts criteria on meaningful description change → user clicks **Try again** (regenerate) → criteria now exists → summary succeeds. Note: failed summaries do **not** auto-resume (only `awaiting_job_criteria` do via `resume_waiting_summaries`), which is why the manual "Try again" button is required.
