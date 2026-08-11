# All Candidates Bulk Action — SPEC

## Summary

Add a job-level "Run Plato" action that scores all candidates across all hiring stages at once, with an optional rescore for candidates who already have summaries. The entry point is a CTA card pinned to the bottom of the job stages sidebar. Clicking the card opens one of three modals depending on job state: a gate if the job has no description, an informational modal if the job has no candidates, or a confirmation modal to launch the bulk run. The backend reuses the existing `QueueBulkAiSummaryJobs` interactor and `BulkGenerateAiSummariesJob` with a `kind` parameter that switches downstream behavior (mailer, broadcast link) between per-stage and all-stages flows.

## Stack scope

Backend and frontend. Backend: one new route, one new controller action, interactor parameter additions, job dispatch branching, one new mailer. Frontend: six new components (two CTA card variants, three modals, one icon), one new hook, one new mutation function, two new serializer attributes, one modified container.

## Data model changes

None. The `ai_job_application_summaries_count` column already exists on `jobs` (added in migration `20260622182504_add_ai_summary_and_criteria_columns_to_jobs`), maintained by `counter_culture` in `AiJobApplicationSummaryStatus`. No new tables, columns, or indexes.

## API changes

### New endpoint

`POST /api/v1/bulk_ai_job_application_summaries/all_stages`

**Request params:** `job_id` (integer, required), `rescore_requested` (boolean, optional, defaults false).

**Response:** Same shape as the existing `create` action — `queued_count`, `skipped_count`, `any_textract_pending` on success; error rendering on interactor failure.

### Serializer additions

Add two attributes to `Api::V1::JobSerializer` (`app/serializers/api/v1/job_serializer.rb`):

- `ai_job_application_summaries_count` — existing integer column on `jobs`, add to the attributes list with no method needed
- `should_auto_generate_ai_summaries` — add to the attributes list and add a method that delegates to `object.should_auto_generate_ai_summaries?` (strips the trailing `?` for serialization)

## Backend changes

### Route

Modify `config/routes.rb:199`. Expand `resources :bulk_ai_job_application_summaries, only: [:create]` to include a collection block with `post :all_stages`.

### Controller action

Add `all_stages` action to `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb`.

- Authorize with `authorize :ai_job_application_summary, :bulk_create?` (same as `create` — org-level, not stage-specific)
- Find the job via `current_organization.jobs.find`
- Resolve job application IDs via `@job.job_applications.pluck(:id)` — all candidates in the job, regardless of hiring stage (no role-fit filter, no explicit inclusion/exclusion lists)
- Call `QueueBulkAiSummaryJobs.call` passing `organization`, `user`, `job_application_ids`, `kind: 'all_stages'`, and `rescore_requested` from params
- Render the same response shape as `create`
- Add `rescore_requested` to the existing `bulk_ai_job_application_summary_params` method (one params method per controller per CLAUDE.md rule #5 — extra permitted keys from the `create` flow are harmless when absent from the request)

### Interactor modifications

Modify `app/interactors/queue_bulk_ai_summary_jobs.rb`:

- Accept two new context params: `context.kind` (string) and `context.rescore_requested` (boolean)
- When `rescore_requested` is truthy, skip the filter at lines 36-40 that drops candidates with `AiJobApplicationSummaryStatus` status `:current`
- Always keep the filter at lines 43-45 that drops candidates with `BulkAiSummaryJobApplication` status `:processing` (prevents duplicate in-flight jobs regardless of rescore)
- Add `kind` to the `BulkGenerateAiSummariesJob` payload at lines 82-89, defaulting to `"single_hiring_stage"` when `context.kind` is not provided

### Job dispatch branching

Modify `app/jobs/bulk_generate_ai_summaries_job.rb`:

In `notify_complete` (lines 126-135):
- Read `kind` from the payload
- When `kind` is `"all_stages"`, build `hiringStageLink` as `/jobs/#{payload['job_id']}/stages` (job-level, no stage suffix)
- When `kind` is `"single_hiring_stage"` or absent, keep the existing link `/jobs/#{payload['job_id']}/stages/#{payload['hiring_stage_id']}/applicants`
- Broadcast `AI_SUMMARY_BULK_COMPLETE` with the computed link (same action type, same payload shape — the `hiringStageLink` field carries a job-level URL for all-stages runs)

In the mailer dispatch (lines 137-144):
- When `kind` is `"all_stages"`, call `BulkAllStagesAiSummaryResultMailer.complete` with params `user_id`, `job_id`, `succeeded_count`, `failed_count`, `skipped_count` (no `hiring_stage_id`)
- When `kind` is `"single_hiring_stage"` or absent, keep the existing `BulkJobApplicationAiSummaryResultMailer.complete` call unchanged

In `notify_failure` (lines 148-172):
- Same branching: `"all_stages"` dispatches to `BulkAllStagesAiSummaryResultMailer.failed`, otherwise existing mailer

### New mailer

Create `app/mailers/bulk_all_stages_ai_summary_result_mailer.rb`, class `BulkAllStagesAiSummaryResultMailer`.

Two methods, following the structure of `app/mailers/bulk_job_application_ai_summary_result_mailer.rb`:

- `complete(user_id, job_id, succeeded_count, failed_count, skipped_count)` — no `hiring_stage_id` parameter. Build the link as `"#{Variables::AtsRootUrl}/jobs/#{@job.id}/stages"`. Use a new Postmark template alias `user-bulk-all-stages-ai-summary-complete`
- `failed(user_id, job_id, total_queued_count)` — same signature as the existing mailer's `failed`. Use a new Postmark template alias `user-bulk-all-stages-ai-summary-failed`

Both call sites in `BulkGenerateAiSummariesJob` (`notify_complete` and `notify_failure`) must chain `.deliver_later` on the new mailer, per known failure pattern #4.

Note: Postmark templates `user-bulk-all-stages-ai-summary-complete` and `user-bulk-all-stages-ai-summary-failed` must be created in Postmark before the mailer can send. Template content follows the existing `user-bulk-ai-summary-complete` / `user-bulk-ai-summary-failed` templates but references "all candidates in this job" instead of a specific hiring stage.

## Frontend changes

### New mutation

Add to `app/javascript/shared/queryHooks/useBulkGenerateAiSummaries.ts`:

- New params type with `jobId` (number) and `rescoreRequested` (boolean)
- New function that POSTs to `/bulk_ai_job_application_summaries/all_stages` with `{ bulkAiJobApplicationSummary: { jobId, rescoreRequested } }`
- New hook `useBulkGenerateAllStagesAiSummaries` wrapping the mutation
- On success, invalidate query keys: `jobApplicationsForStage`, `jobApplication`, `organizationAiCreditBalance`, and `job` (the last one for the updated `aiJobApplicationSummariesCount`)

### New components

All new files in `app/javascript/ats/src/views/jobApplications/`:

**`PlatoSparkleIcon.tsx`** — Four-point sparkle SVG icon component. Stroked to match Feather icon weight. From handoff file.

**`useRunPlatoCtaModals.tsx`** — Shared hook consumed by both CTA card variants. Exports `useRunPlatoCtaModals` and the `RunPlatoCtaCardProps` type.

Props type: `job` (object with `id: number`), `jobApplicationsCount` (number), `jobApplicationsSummaryCount` (number), `autoGenerateEnabled` (boolean), `jobDescription` (string, optional).

The hook uses `useModalContext` for `openModal`/`removeModal`. Exports `handleOnClickRunPlato` as the top-level click handler, which branches:
1. No `jobDescription` → open `RunPlatoAddDescriptionModal`, track `run_plato_no_description_shown`
2. `jobApplicationsCount === 0` → open `RunPlatoNoCandidatesModal`, track `run_plato_no_candidates_shown`
3. Otherwise → open `RunPlatoReviewAllModal`, track `run_plato_review_all_clicked`

Internal branch handlers: `handleNoDescription`, `handleNoCandidates`, `handleReviewAll`. The hook does NOT hold mutation state — the modal owns its mutation (decision 13).

**`RunPlatoCtaCardV1.tsx`** — Centered layout: gradient disc with `PlatoSparkleIcon`, description text, "Run Plato" button. Pinned to sidebar bottom via `margin-top: auto`. Uses `useRunPlatoCtaModals` for button click. Background `t.color.gray[100]`, border-radius `0.625rem`. Button uses `styleType="white"` with width override matching `JobStageMenu` pattern.

**`RunPlatoCtaCardV2.tsx`** — Header-row layout: smaller disc + "Plato review" title on one line, left-aligned description, button. Same hook, same button. White background with `t.color.gray[200]` border. Build this component but do not render it from the parent in this implementation.

**`RunPlatoReviewAllModal.tsx`** — Confirmation modal for the happy path. Uses `CenterModal` with `headerTitleText` "Review all candidates".

Receives `onCancel` only (no `onSubmit` or `isSubmitting` from parent). Owns its mutation internally via `useBulkGenerateAllStagesAiSummaries` from `app/javascript/shared/queryHooks/useBulkGenerateAiSummaries.ts`.

Credit check: use `useOrganizationAiCreditBalance` following `BulkGenerateAiSummariesConfirmModal` (`app/javascript/ats/src/views/jobApplications/BulkGenerateAiSummariesConfirmModal.tsx`) — derive `available` from `data?.totalCreditsRemaining`, compute `shortfall`, show shortfall warning when `shortfall > 0 && processableCount > 0`, validate with `validateBulkGenerateAiSummaries`. Use `FormContainer` with `errors` state for credit validation error display, following `BulkGenerateAiSummariesConfirmModal`.

Local state: `rescore` (boolean, checkbox for re-scoring existing summaries). Derived: `candidatesToScoreCount` — when `rescore` is true, equals `candidatesCount`; otherwise `Math.max(candidatesCount - summaryCount, 0)`.

Body copy shows candidate count and credit usage. Checkbox for "Also re-review candidates that already have a review" with subtitle. Statement box (mail icon) about email notification and skip conditions. Actions: "Review all" primary button with `loading` and `disabled` props (disabled when loading or when `candidatesToScoreCount` is 0), following `BulkGenerateAiSummariesConfirmModal` and known failure pattern #11. "Cancel" secondary button.

Close uses `dismissModalWithAnimation(() => onCancel)`, not `removeModal()`. Success/error toasts via `useToastContext` — success shows queued/skipped/pending counts, error shows the API error message or a fallback, following `BulkGenerateAiSummariesConfirmModal` toast patterns.

**`RunPlatoAddDescriptionModal.tsx`** — Gate modal when `jobDescription` is empty. Uses `CenterModal` with `headerTitleText` "Add a job description first". Body explains why Plato needs a description. Statement box (file-text icon) directs user to Job setup. Primary action: `type="internalLink"` Button linking to `/jobs/${job.id}/setup/description`. Secondary: "Cancel" button calling `onCancel`.

**`RunPlatoNoCandidatesModal.tsx`** — Informational modal when `jobApplicationsCount` is 0. Uses `CenterModal` with `headerTitleText` "No candidates yet". Body explains no candidates to score.

Content branches on `autoGenerateEnabled`:
- **ON:** "No need to worry" reassurance that auto-review handles incoming applicants. One task: "Write a specific job description for best scoring results" (file-text icon)
- **OFF:** "Two things get Plato ready" — turn on automatic review (sliders icon, links to `/hire/settings/plato-ai` for org settings and `/jobs/${job.id}/setup/ai` for per-job settings) and write a description (file-text icon)

Inline links in the OFF variant's text (org settings, per-job settings) use `Link` from `react-router-dom` instead of raw `<a href>` elements. Primary action: `type="internalLink"` Button linking to `/jobs/${job.id}/setup/description`. Secondary: "Dismiss" button calling `onCancel`.

### Modified container

Modify `app/javascript/ats/src/views/jobApplications/JobStagesContainer.tsx`:

- Import `RunPlatoCtaCardV1`
- Render `RunPlatoCtaCardV1` inside `Styled.Sidebar`, after the second `Styled.List` block (setup/distribution/metrics links), before the closing `Styled.Sidebar` tag
- Add `display: flex; flex-direction: column` to `Styled.Sidebar` so the CTA card's `margin-top: auto` pins it to the bottom (the sidebar is currently a plain `div`)
- Pass individual props (not the job object): `job` (object with `id`), `jobApplicationsCount` from the job query, `jobApplicationsSummaryCount` from the new `aiJobApplicationSummariesCount` serializer attribute, `autoGenerateEnabled` from the new `shouldAutoGenerateAiSummaries` serializer attribute, `jobDescription` from the job's `description`

## Authorization

No new policies. The existing `AiJobApplicationSummaryPolicy#bulk_create?` (`app/policies/ai_job_application_summary_policy.rb:12-14`) delegates to `can_use_ai_credits?`, which is an org-level check (admin or `hiring_team_ai_credits_control_enabled`). This works for the all-stages action without modification.

## Constraints and requirements

- The `kind` parameter is a plain string in the job payload (`"single_hiring_stage"` or `"all_stages"`), not a Ruby enum
- The existing `create` action and its callers are unchanged — `kind` defaults to `"single_hiring_stage"` when absent from the interactor context
- The `:processing` filter in `QueueBulkAiSummaryJobs` (lines 43-45) always applies, even with `rescore_requested` — prevents duplicate in-flight processing
- `RunPlatoReviewAllModal` must include credit balance validation matching `BulkGenerateAiSummariesConfirmModal` — zero-credit gate, shortfall warning, inline balance display
- `text-wrap: pretty` in the CTA card description styled components: verify browser support during implementation; remove if unsupported in target browsers
- The `hiringStageLink` field name in `AiSummaryBulkCompletePayload` (`app/javascript/shared/types/aiSummaryWebsocketPayloads.ts:11-16`) stays unchanged — for all-stages runs it carries a job-level URL instead of a stage URL

## Test requirements

### Existing specs to update

- `spec/interactors/queue_bulk_ai_summary_jobs_spec.rb` — add contexts for `kind` and `rescore_requested` params: verify `rescore_requested` skips the `:current` filter, verify `kind` passes through to the job payload, verify existing behavior unchanged when neither param is provided
- `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` — add examples for `kind`-based branching in `notify_complete` and `notify_failure`: verify `"all_stages"` dispatches to `BulkAllStagesAiSummaryResultMailer`, verify absent `kind` dispatches to existing `BulkJobApplicationAiSummaryResultMailer`, verify `hiringStageLink` uses job-level URL for `"all_stages"`

### New specs

- Controller spec for `BulkAiJobApplicationSummariesController#all_stages` — authorize, job lookup, interactor call with correct params, response shape (no existing controller spec for `#create` exists)
- Mailer spec for `BulkAllStagesAiSummaryResultMailer` — `complete` and `failed` methods, verify `Emails::SendTemplateEmail` call, verify job-level link construction, verify `.deliver_later` chaining at call sites

## Existing patterns to follow

- **Controller action:** `BulkAiJobApplicationSummariesController#create` (`app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb:6-28`) — authorization, job lookup, interactor call, response rendering
- **Modal ownership of mutation:** `BulkGenerateAiSummariesConfirmModal` (`app/javascript/ats/src/views/jobApplications/BulkGenerateAiSummariesConfirmModal.tsx`) — modal owns mutation, `dismissModalWithAnimation`, toast notifications, credit balance check, `FormContainer` with errors
- **Handler naming:** `JobStageMenu` (`app/javascript/ats/src/views/jobApplications/JobStageMenu.tsx`) — `handleOnClick` + action convention for button click handlers
- **CTA card button override:** `JobStageMenu.Styled.Button` — `styled(Button)` with `!important` width override
- **Sidebar placement:** `JobStagesContainer` (`app/javascript/ats/src/views/jobApplications/JobStagesContainer.tsx`) — `Styled.Sidebar` contains the stage navigation; CTA card goes after the stage list, pinned to bottom via `margin-top: auto`
- **Mutation hook:** `useBulkGenerateAiSummaries` (`app/javascript/shared/queryHooks/useBulkGenerateAiSummaries.ts`) — mutation function shape, query invalidation pattern
- **Mailer:** `BulkJobApplicationAiSummaryResultMailer` (`app/mailers/bulk_job_application_ai_summary_result_mailer.rb`) — method signatures, Postmark template usage, link construction
- **Interactor context params:** `QueueBulkAiSummaryJobs` (`app/interactors/queue_bulk_ai_summary_jobs.rb:15`) — existing reads from `context`
