# Plain English Summary + Blast Radius — job-criteria-settings

Produced before spec-review Round 1, per the phase prompt ("verify and update rather than re-derive" — SPEC.md sections 1, 2, and 13 carry the technical equivalents; this file is the plain-English rendering, verified against the live source tree at worktree HEAD `05c9513ef`).

## Plain English Summary

When Plato reviews candidates, it scores them against criteria it extracted from the job description — but today users cannot see those criteria anywhere, cannot tell when they were extracted, and cannot redo the extraction. This feature adds a "Job criteria" section to the per-job Plato AI settings tab that shows:

- a card with when criteria were last extracted and how many landed in each tier (Core / Preferred / Bonus),
- a read-only slide-over listing every criterion grouped by tier,
- a "Regenerate criteria" button (confirmation modal first) that re-runs extraction asynchronously; while it runs, the button shows loading driven by backend status (survives page reload), and a WebSocket toast announces completion or failure,
- distinct empty states for "never extracted", "extraction found nothing", and "extraction failed".

On the backend, one new enforcement rule: when the latest completed extraction found zero criteria, no new AI summary reviews may start (they would burn pipeline steps and money scoring against nothing). The UI's zero-found empty state explains this to the user.

## Blast Radius

**New surface:** 2 endpoints (`GET`/`POST /api/v1/jobs/:job_id/ai_job_criteria`), 1 controller, 1 serializer, 1 query-hook file, 2 modal components, 1 WebSocket event, 3 new spec files.

**Shared infrastructure modified (the real blast radius):**
- `Job#extract_job_criteria_immediately` / `#extract_job_criteria_if_needed` gating change — affects the automatic extraction path (publish / description change) AND the summary pipeline's lazy extraction (textract_result.rb:70).
- Zero-criteria review guard added at 4 sites: `ValidateAiSummaryGeneration`, `ValidateAutoAiSummaryGeneration`, `QueueBulkAiSummaryJobs`, and the shared funnel `TextractResult#generate_ai_summary_with_credit_flow`. Every one of the 7 traced AI-review entry points passes through at least one of these — a wrong predicate would block reviews for affected jobs everywhere.
- `ExtractJobCriteriaJob` gains an optional second positional argument + completion broadcasts at 3 sites (in-flight Sidekiq payload compatibility adjudicated in Round 1 — see flag 4 ruling).
- `BulkGenerateAiSummariesJob#each_iteration` claim-row fix — validation-failed candidates now mark their claim row `:failed` instead of leaving it stuck `:processing` (previously permanently un-queueable). Changes bulk completion-toast accounting for validation failures.
- `Api::V1::BulkAiJobApplicationSummariesController` passes `job: @job` to the queue interactor (both actions).
- `ExtractCriteria` / `ScoreJobApplication`: literal failure strings → shared constants (no behavior change).
- Frontend: `JobSetupAiSettings.tsx` gains the section + sidebar (SettingsContainer layout shifts to the hasSidebar variant at lg); `WebsocketGlobalChannelHandler.tsx` gains one case; `aiSummaryWebsocketPayloads.ts` gains one interface.

**Explicitly untouched:** scoring pipeline internals (`Orchestrate`, `ScoreJobApplication` guard placement), `AiJobCriteria#resume_waiting_summaries`, the existing Plato-reviews FormSection / dirty tracking / Save flow, `jobs.internal_job_criteria` (dead column, decided OUT), `auto_extract_job_criteria` / `extract_job_criteria` (deliberate guard-set asymmetry preserved).
