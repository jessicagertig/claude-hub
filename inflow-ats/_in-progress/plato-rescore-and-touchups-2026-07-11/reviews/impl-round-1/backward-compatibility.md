# backward-compatibility (always-on) — Round 1

- `useGenerateAiSummary` / `GenerateParams.rescoreRequested` now REQUIRED. Consumers: `PlatoTab.tsx` (updated, F4) and `AiSummaryState.tsx` (deleted, F5). Grep of `app/javascript` for `generate({ ... jobApplicationId ...})` → no third survivor. No compile break.
- `BulkGenerateAiSummariesConfirmModal` `Props` interface unchanged — callers pass the same props; only internal copy/state added. No caller change needed.
- `RunPlatoReviewAllModal` `Props` unchanged.
- `BulkAllStagesAiSummaryResultMailer.complete(user_id, job_id, succeeded, failed, skipped, total)` and `.failed(user_id, job_id, total_queued_count)` signatures UNCHANGED — `user_id` retained (just no longer read). Enqueuing callers pass identical args; mailer job invocation unaffected.
- Interactor `CreateAiSummaryGeneration.call(job_application:, validation_result:, user:)` signature unchanged.
- Controller `create`/`show` routes unchanged; new strong-param `require` only affects `create` (the frontend always sends the boolean now).

## Findings
No issues found.
