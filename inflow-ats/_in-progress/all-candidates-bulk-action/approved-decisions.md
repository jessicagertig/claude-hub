# Approved Decisions

## 1. Route and controller

New endpoint is a collection route on the existing `bulk_ai_job_application_summaries` resource. Route: `post :all_stages`. Full path: `POST /api/v1/bulk_ai_job_application_summaries/all_stages`. Action: `BulkAiJobApplicationSummariesController#all_stages`.

## 2. Interactor params

`QueueBulkAiSummaryJobs` gets two new context params: `kind` (distinguishes per-stage vs all-stages) and `rescore_requested` (when true, skips the filter that drops candidates with `AiJobApplicationSummaryStatus` status `:current`). The interactor passes `kind` through to the `BulkGenerateAiSummariesJob` payload.

## 3. Background job

No new job class. `BulkGenerateAiSummariesJob` stays as-is for iteration logic. `on_complete` reads `kind` from the payload and dispatches to the appropriate mailer and broadcast (different link URL, different copy).

## 4. Mailer

New mailer file for the all-stages case. Separate from the existing `BulkJobApplicationAiSummaryResultMailer`, which stays unchanged for per-stage bulk jobs. The new mailer uses a job-level link (`/jobs/:job_id/stages`) instead of a stage-specific link.

## 5. Job serializer

Add `ai_job_application_summaries_count` to the `Api::V1::JobSerializer` attributes list. Column already exists on `jobs` table, maintained by `counter_culture` on `AiJobApplicationSummaryStatus`. No method needed — regular column attribute.

## 5a. Job serializer — should_auto_generate_ai_summaries

Add `should_auto_generate_ai_summaries` to `Api::V1::JobSerializer`. Predicate method on `Job` (`should_auto_generate_ai_summaries?`), so serializer needs an explicit method that delegates without the `?`.

## 6. React Query mutation

New exported function in the existing `app/javascript/shared/queryHooks/useBulkGenerateAiSummaries.ts` file. Different params interface (no `hiringStageId`, no `includedJobApplicationIds`/`excludedJobApplicationIds`/`roleFit` — just `jobId` and `rescoreRequested`). POSTs to `/bulk_ai_job_application_summaries/all_stages`.

## 7. Frontend empty state modals

Three modal states when the user triggers the all-candidates action:
1. No job description
2. No candidates + auto-generate is on (`shouldAutoGenerateAiSummaries` true)
3. No candidates + auto-generate is off (`shouldAutoGenerateAiSummaries` false)

User has designs for these from Claude AI, will port over. Data needed for the checks: `job.description`, `job.jobApplicationsCount`, `job.shouldAutoGenerateAiSummaries` (decisions 5 and 5a cover the serializer additions).

## 8. `kind` values

Two values: `"single_hiring_stage"` for the existing per-stage flow, `"all_stages"` for the new all-candidates flow. Passed as a string in the job payload, not a Ruby enum.

## 9. New mailer naming

Class: `BulkAllStagesAiSummaryResultMailer`. File: `app/mailers/bulk_all_stages_ai_summary_result_mailer.rb`. Same two methods as the existing mailer (`complete` and `failed`), but without the `hiring_stage_id` param and with a job-level link.

## 10. Broadcast

Leave the existing `AI_SUMMARY_BULK_COMPLETE` broadcast as-is for now. No changes to the action type, payload shape, or WebSocket handler. Revisit later if distinct copy is needed.

## 11. CTA card receives individual props, not the job object

The card components (`RunPlatoCtaCardV1`, `RunPlatoCtaCardV2`) receive individual props (`jobTitle`, `jobDescription`, `autoGenerateEnabled`, etc.) passed by the parent component. They do not receive a `job` object. Prop names are independent of serializer attribute names — `jobTitle` is fine even though the serializer uses `title`, `jobDescription` is fine even though the serializer uses `description`, `autoGenerateEnabled` is fine even though the serializer uses `should_auto_generate_ai_summaries`.

## 12. Handler and variable naming corrections

Top-level click handler: `handleRunPlato` → `handleOnClickRunPlato` (matches codebase convention `handleOnClick` + action for button click handlers in `JobStageMenu`).

Branch target handlers keep shorter names (not click handlers, just internal routing targets): `handleNoDescription`, `handleNoCandidates`, `handleReviewAll`.

Variable renames in `RunPlatoReviewAllModal`:
- `reReview` → `rescore` (local checkbox state)
- `willReview` → `candidatesToScoreCount` (derived count)
- `reReviewExisting` → `rescoreRequested` (prop/param name, aligns with backend context param from decision 2)

## 13. Modal pattern and close pattern follow codebase conventions

`RunPlatoReviewAllModal` owns its mutation internally (per `BulkGenerateAiSummariesConfirmModal` analog and cursor_rules modal form pattern). It receives `onCancel` only, not `onSubmit`/`isSubmitting` from the parent.

Modal close uses `dismissModalWithAnimation(() => onCancel)` (per `BulkGenerateAiSummariesConfirmModal` analog), not `removeModal()`.

## 14. Replace placeholder mutation with real hook

The placeholder `useMutation` in `useRunPlatoCtaModals` is replaced with the real mutation function from `app/javascript/shared/queryHooks/useBulkGenerateAiSummaries.ts` (the new all-stages function from decision 6). Since the modal now owns the mutation (decision 13), the hook no longer needs to hold or pass mutation state.

## 15. CTA card variants — build both, implement V1

Build both `RunPlatoCtaCardV1` and `RunPlatoCtaCardV2` components. Both share the `useRunPlatoCtaModals` hook. The parent (`JobStagesContainer`) renders V1 (centered gradient disc layout). V2 (header-row layout) exists as an available alternative but is not rendered in V1 implementation.
