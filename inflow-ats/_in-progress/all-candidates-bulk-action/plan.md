# All Candidates Bulk Action — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Summary

Add a job-level "Run Plato" action that scores all candidates across all hiring stages at once, with optional rescore. A CTA card in the job stages sidebar opens one of three modals (no description, no candidates, or confirm review-all). The backend reuses the existing `QueueBulkAiSummaryJobs` interactor and `BulkGenerateAiSummariesJob` with a `kind` parameter that switches downstream mailer and broadcast link between per-stage and all-stages flows.

## Open PRs — Conflict Check

| PR | Branch | Overlap |
|---|---|---|
| #3035 messaging-improvements | `messaging-improvements` | `job_serializer.rb` (2 lines) — low risk, branch is old/stale |

No other open PRs touch files in scope.

## Pattern Precedents

### Backend

**Controller — `BulkAiJobApplicationSummariesController#create`** (`app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb:6-28`):
- `authorize :ai_job_application_summary, :bulk_create?` at top
- Find job via `current_organization.jobs.find(params[:job_id])`
- Call interactor, render json on success, `render_general_errors` on failure
- Private `bulk_ai_job_application_summary_params` permits nested keys

**Interactor — `QueueBulkAiSummaryJobs`** (`app/interactors/queue_bulk_ai_summary_jobs.rb`):
- Reads `context.organization`, `context.user`, `context.job_application_ids`
- Lines 36-40: `:current` filter (the one `rescore_requested` skips)
- Lines 43-45: `:processing` filter (always applies)
- Lines 82-89: `perform_later` payload hash with string keys

**Job — `BulkGenerateAiSummariesJob`** (`app/jobs/bulk_generate_ai_summaries_job.rb`):
- `notify_complete` (class method, lines 123-145): builds `hiringStageLink`, broadcasts, calls mailer `.deliver_later`
- `notify_failure` (class method, lines 148-172): broadcasts `AI_SUMMARY_BULK_FAILED`, calls mailer `.deliver_later`
- Both are `private_class_method`

**Mailer — `BulkJobApplicationAiSummaryResultMailer`** (`app/mailers/bulk_job_application_ai_summary_result_mailer.rb`):
- `complete(user_id, job_id, succeeded_count, failed_count, skipped_count, hiring_stage_id)` — builds `message_params` hash, calls `Emails::SendTemplateEmail.new(message_params).send`
- `failed(user_id, job_id, total_queued_count)` — same pattern
- Template aliases: `user-bulk-ai-summary-complete`, `user-bulk-ai-summary-failed`

**Serializer — `Api::V1::JobSerializer`** (`app/serializers/api/v1/job_serializer.rb:4-56`):
- Long attributes list, no method needed for simple column attributes
- Custom methods for computed attributes (e.g., `description`, `active_wwr_listing`)

### Frontend

**Mutation hook — `useBulkGenerateAiSummaries`** (`app/javascript/shared/queryHooks/useBulkGenerateAiSummaries.ts`):
- Imports `apiPost` from `"./api"`
- Typed params interface, async function calling `apiPost({ path, variables })`
- Hook wraps `useMutation`, invalidates query keys in `onSuccess`

**Modal — `BulkGenerateAiSummariesConfirmModal`** (`app/javascript/ats/src/views/jobApplications/BulkGenerateAiSummariesConfirmModal.tsx`):
- Imports: `CenterModal`, `Button`, `FormContainer`, `useModalContext`, `useToastContext`, `useOrganizationAiCreditBalance`, mutation hook, `validateBulkGenerateAiSummaries`, `trackEvent`
- `dismissModalWithAnimation(() => onCancel)` for close
- Credit check: `data?.totalCreditsRemaining || 0`, shortfall computed, validation gate via `validateBulkGenerateAiSummaries({ availableCredits })`
- `FormContainer` wraps body with `errors` state + `buttons` prop
- Button: `loading={isLoading} disabled={isLoading || processableCount === 0}`
- Toast on success (queued/skipped/pending counts), toast on error (API error or fallback)

**Sidebar — `JobStagesContainer`** (`app/javascript/ats/src/views/jobApplications/JobStagesContainer.tsx`):
- `Styled.Sidebar` (line 121-140): contains two `Styled.List` blocks separated by a `Styled.Divider`
- `job` prop comes from `JobContainer` (line 370-377) which passes the full serialized object
- `Styled.Sidebar` is currently a plain `div` — needs `display: flex; flex-direction: column` for `margin-top: auto` pinning

**Handoff designs** (`/Users/jessica/Projects/genuine-article-images/run-plato-cta-handoff/`):
- Starting point for all 6 frontend components + hook
- Corrections per approved-decisions.md (decisions 11-14): prop naming, handler naming, variable renames, modal owns mutation, `dismissModalWithAnimation`
- Route corrections: `/setup/job_post` → `/setup/description`, `/hire/settings/integrations/plato` → `/hire/settings/plato-ai`, raw `<a href>` → `Link` from react-router-dom

## Files to Create or Modify

### New files
| File | Purpose |
|---|---|
| `app/mailers/bulk_all_stages_ai_summary_result_mailer.rb` | Mailer for all-stages completion/failure emails |
| `app/javascript/ats/src/views/jobApplications/PlatoSparkleIcon.tsx` | Sparkle SVG icon |
| `app/javascript/ats/src/views/jobApplications/useRunPlatoCtaModals.tsx` | Shared hook for CTA modal branching |
| `app/javascript/ats/src/views/jobApplications/RunPlatoCtaCardV1.tsx` | CTA card — centered layout (active) |
| `app/javascript/ats/src/views/jobApplications/RunPlatoCtaCardV2.tsx` | CTA card — header-row layout (built, not rendered) |
| `app/javascript/ats/src/views/jobApplications/RunPlatoReviewAllModal.tsx` | Confirm modal — owns mutation, credit check |
| `app/javascript/ats/src/views/jobApplications/RunPlatoAddDescriptionModal.tsx` | Gate modal — no description |
| `app/javascript/ats/src/views/jobApplications/RunPlatoNoCandidatesModal.tsx` | Informational modal — no candidates |
| `spec/mailers/bulk_all_stages_ai_summary_result_mailer_spec.rb` | Mailer spec |

### Modified files
| File | Change |
|---|---|
| `config/routes.rb` | Add collection block with `post :all_stages` |
| `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb` | Add `all_stages` action, add `rescore_requested` to params |
| `app/interactors/queue_bulk_ai_summary_jobs.rb` | Accept `kind`/`rescore_requested`, skip `:current` filter, pass `kind` to payload |
| `app/jobs/bulk_generate_ai_summaries_job.rb` | Branch `notify_complete`/`notify_failure` on `kind` |
| `app/serializers/api/v1/job_serializer.rb` | Add `ai_job_application_summaries_count`, `should_auto_generate_ai_summaries` |
| `app/javascript/shared/queryHooks/useBulkGenerateAiSummaries.ts` | Add all-stages mutation function and hook |
| `app/javascript/ats/src/views/jobApplications/JobStagesContainer.tsx` | Render `RunPlatoCtaCardV1` in sidebar, add flex column to `Styled.Sidebar` |
| `spec/interactors/queue_bulk_ai_summary_jobs_spec.rb` | Add contexts for `kind` and `rescore_requested` |
| `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` | Add examples for `kind`-based branching |

## A. Backend Changes

**Read before starting:** `cursor_rules/core_critical_rules.md`, `cursor_rules/backend/_base.md`

### A.1 Route

**Read:** `cursor_rules/backend/controllers/controller_patterns_and_crud.md`

- [ ] A.1.1 Modify `config/routes.rb:199`. Change `resources :bulk_ai_job_application_summaries, only: [:create]` to include a collection block with `post :all_stages`

### A.2 Controller action

**Read:** `cursor_rules/backend/controllers/controller_patterns_and_crud.md`, `cursor_rules/backend/controllers/controller_error_handling.md`, `cursor_rules/backend/code_style_and_structure.md`

- [ ] A.2.1 Add `all_stages` action to `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb`
  - [ ] A.2.1.1 `authorize :ai_job_application_summary, :bulk_create?` (same as `create`)
  - [ ] A.2.1.2 Find job: `@job = current_organization.jobs.find(bulk_ai_job_application_summary_params[:job_id])`
  - [ ] A.2.1.3 Resolve IDs: `@job.job_applications.pluck(:id)` — all candidates, no filters
  - [ ] A.2.1.4 Call interactor: `QueueBulkAiSummaryJobs.call(organization: current_organization, user: current_user, job_application_ids: ids_to_process, kind: 'all_stages', rescore_requested: bulk_ai_job_application_summary_params[:rescore_requested])` — use method-level rescue for errors, same response rendering as `create`
  - [ ] A.2.1.5 Render same response shape as `create` (json with `queued_count`, `skipped_count`, `any_textract_pending`)

- [ ] A.2.2 Add `:rescore_requested` to `bulk_ai_job_application_summary_params` (line 49 — one params method per controller, CLAUDE.md rule #5)

### A.3 Interactor modifications

**Read:** `cursor_rules/backend/interactors/interactor_patterns_and_structure.md`

- [ ] A.3.1 Modify `app/interactors/queue_bulk_ai_summary_jobs.rb`
  - [ ] A.3.1.1 When `context.rescore_requested` is truthy, skip the `:current` status filter at lines 36-40. Wrap those lines in a conditional: only run when `!context.rescore_requested`
  - [ ] A.3.1.2 The `:processing` filter at lines 43-45 always applies (unchanged)
  - [ ] A.3.1.3 Add `'kind' => context.kind || 'single_hiring_stage'` to the `BulkGenerateAiSummariesJob.perform_later` payload hash at lines 82-89

### A.4 Job dispatch branching

**Read:** `cursor_rules/backend/background_jobs.md`

- [ ] A.4.1 Modify `app/jobs/bulk_generate_ai_summaries_job.rb`, `self.notify_complete` method (lines 123-145)
  - [ ] A.4.1.1 Read `kind = payload['kind'] || 'single_hiring_stage'`
  - [ ] A.4.1.2 Build `hiringStageLink` based on `kind`: `"all_stages"` → `"/jobs/#{payload['job_id']}/stages"`, otherwise existing stage link
  - [ ] A.4.1.3 Broadcast remains unchanged (same action `AI_SUMMARY_BULK_COMPLETE`, same payload shape)
  - [ ] A.4.1.4 Branch mailer call: `"all_stages"` → `BulkAllStagesAiSummaryResultMailer.complete(user.id, payload['job_id'], succeeded, failed, skipped).deliver_later`, otherwise existing mailer with `payload['hiring_stage_id']`

- [ ] A.4.2 Modify `self.notify_failure` method (lines 148-172)
  - [ ] A.4.2.1 Read `kind = payload['kind'] || 'single_hiring_stage'`
  - [ ] A.4.2.2 Branch mailer call: `"all_stages"` → `BulkAllStagesAiSummaryResultMailer.failed(user.id, payload['job_id'], total_queued_count).deliver_later`, otherwise existing mailer

### A.5 New mailer

**Read:** `cursor_rules/backend/_base.md`

- [ ] A.5.1 Create `app/mailers/bulk_all_stages_ai_summary_result_mailer.rb`
  - [ ] A.5.1.1 Class `BulkAllStagesAiSummaryResultMailer < ApplicationMailer`
  - [ ] A.5.1.2 `complete(user_id, job_id, succeeded_count, failed_count, skipped_count)` — no `hiring_stage_id`. Find `@user` and `@job`. Build link: `"#{Variables::AtsRootUrl}/jobs/#{@job.id}/stages"`. Build `message_params` hash matching `BulkJobApplicationAiSummaryResultMailer#complete` structure. Template alias: `user-bulk-all-stages-ai-summary-complete`. Call `Emails::SendTemplateEmail.new(message_params).send`
  - [ ] A.5.1.3 `failed(user_id, job_id, total_queued_count)` — same signature as existing. Template alias: `user-bulk-all-stages-ai-summary-failed`. Same `message_params` structure as existing mailer's `failed`

### A.6 Serializer

**Read:** `cursor_rules/backend/serializers.md`

- [ ] A.6.1 Modify `app/serializers/api/v1/job_serializer.rb`
  - [ ] A.6.1.1 Add `ai_job_application_summaries_count` to the attributes list (existing column, no method needed)
  - [ ] A.6.1.2 Add `should_auto_generate_ai_summaries` to the attributes list
  - [ ] A.6.1.3 Add method `def should_auto_generate_ai_summaries` that returns `object.should_auto_generate_ai_summaries?`

## B. Frontend Changes

**Read before starting:** `cursor_rules/core_critical_rules.md`, `cursor_rules/frontend/_base.md`

### B.1 Mutation hook

**Read:** `cursor_rules/frontend/react_query/react_query_mutations_and_cache.md`

- [ ] B.1.1 Modify `app/javascript/shared/queryHooks/useBulkGenerateAiSummaries.ts`
  - [ ] B.1.1.1 Add new interface `BulkGenerateAllStagesParams` with `jobId: number` and `rescoreRequested: boolean`
  - [ ] B.1.1.2 Add new async function `bulkGenerateAllStagesAiSummaries` that calls `apiPost({ path: "/bulk_ai_job_application_summaries/all_stages", variables: { bulkAiJobApplicationSummary: params } })`
  - [ ] B.1.1.3 Add new exported hook `useBulkGenerateAllStagesAiSummaries` wrapping the mutation. On success, invalidate: `"jobApplicationsForStage"`, `"jobApplication"`, `["organizationAiCreditBalance"]`, `"job"`

### B.2 New components — utility

- [ ] B.2.1 Create `app/javascript/ats/src/views/jobApplications/PlatoSparkleIcon.tsx` from handoff file (`/Users/jessica/Projects/genuine-article-images/run-plato-cta-handoff/PlatoSparkleIcon.tsx`). Strip JSDoc comments

### B.3 New hook — useRunPlatoCtaModals

**Read:** `cursor_rules/frontend/react_hooks.md`

- [ ] B.3.1 Create `app/javascript/ats/src/views/jobApplications/useRunPlatoCtaModals.tsx` from handoff file, applying these corrections:
  - [ ] B.3.1.1 Rename `handleRunPlato` → `handleOnClickRunPlato` (decision 12)
  - [ ] B.3.1.2 Remove the placeholder `useMutation` entirely (decision 14) — the modal owns its mutation (decision 13), so the hook holds no mutation state
  - [ ] B.3.1.3 Keep `handleNoDescription`, `handleNoCandidates`, `handleReviewAll` as internal branch handlers
  - [ ] B.3.1.4 `handleReviewAll` opens `RunPlatoReviewAllModal` with `onCancel` only — no `onSubmit`, no `isSubmitting` (decision 13)
  - [ ] B.3.1.5 Strip JSDoc comments
  - [ ] B.3.1.6 Keep `trackEvent` calls and `useModalContext` imports as-is
  - [ ] B.3.1.7 Export the `RunPlatoCtaCardProps` type and `useRunPlatoCtaModals` function

### B.4 CTA cards

**Read:** `cursor_rules/frontend/components/component_architecture.md`, `cursor_rules/frontend/ui_styling.md`

- [ ] B.4.1 Create `app/javascript/ats/src/views/jobApplications/RunPlatoCtaCardV1.tsx` from handoff file
  - [ ] B.4.1.1 Strip JSDoc comments
  - [ ] B.4.1.2 Use `handleOnClickRunPlato` (not `handleRunPlato`) from the hook
  - [ ] B.4.1.3 Verify all theme tokens against `app/javascript/ats/styles/theme.ts:3-56`: `t.color.gray[100]`, `t.color.gray[600]`, `t.color.gray[900]`
  - [ ] B.4.1.4 Check `text-wrap: pretty` browser support — remove if unsupported in target browsers

- [ ] B.4.2 Create `app/javascript/ats/src/views/jobApplications/RunPlatoCtaCardV2.tsx` from handoff file
  - [ ] B.4.2.1 Same corrections as V1 (JSDoc strip, handler rename, theme verification)
  - [ ] B.4.2.2 Verify `t.color.white`, `t.color.gray[200]` exist in theme

### B.5 RunPlatoReviewAllModal

**Read:** `cursor_rules/frontend/modals/modal_form_and_confirmation_patterns.md`, `cursor_rules/frontend/modals/modal_state_errors_and_loading.md`

- [ ] B.5.1 Create `app/javascript/ats/src/views/jobApplications/RunPlatoReviewAllModal.tsx`
  - [ ] B.5.1.1 Start from handoff file, then REPLACE the external mutation pattern with internal ownership per `BulkGenerateAiSummariesConfirmModal` analog (decision 13)
  - [ ] B.5.1.2 Props: `onCancel` only. Receives `candidatesCount`, `summaryCount`, `jobId` for the mutation
  - [ ] B.5.1.3 Rename variables per decision 12: `reReview` → `rescore`, `willReview` → `candidatesToScoreCount`, `reReviewExisting` → `rescoreRequested`
  - [ ] B.5.1.4 Import and use `useBulkGenerateAllStagesAiSummaries` from `@shared/queryHooks/useBulkGenerateAiSummaries`
  - [ ] B.5.1.5 Import and use `useOrganizationAiCreditBalance` from `@shared/queryHooks/useOrganizationAiCreditBalance` — derive `available`, compute `shortfall`, same pattern as `BulkGenerateAiSummariesConfirmModal:47-50`
  - [ ] B.5.1.6 Import and use `validateBulkGenerateAiSummaries` from `@shared/lib/validateWithYup` — validate before submit, set `errors` state, same pattern as `BulkGenerateAiSummariesConfirmModal:56-64`
  - [ ] B.5.1.7 Wrap body in `FormContainer` with `errors` state and `buttons` prop
  - [ ] B.5.1.8 "Review all" button: `loading={isLoading} disabled={isLoading || candidatesToScoreCount === 0}` (known failure pattern #11)
  - [ ] B.5.1.9 Close: `dismissModalWithAnimation(() => onCancel)` — import from `useModalContext`
  - [ ] B.5.1.10 Toast on success: build parts string from response `queuedCount`, `skippedCount`, `anyTextractPending` — same pattern as `BulkGenerateAiSummariesConfirmModal:75-88`
  - [ ] B.5.1.11 Toast on error: `error?.data?.errors?.general?.[0] || "Failed to queue summaries"` — same pattern as `BulkGenerateAiSummariesConfirmModal:92-97`
  - [ ] B.5.1.12 Strip JSDoc comments, keep `propTypes = {}` / `defaultProps = {}`
  - [ ] B.5.1.13 Import `trackEvent` and track `"run_plato_review_all_confirmed"` on successful submit

### B.6 RunPlatoAddDescriptionModal

**Read:** `cursor_rules/frontend/modals/modal_form_and_confirmation_patterns.md`

- [ ] B.6.1 Create `app/javascript/ats/src/views/jobApplications/RunPlatoAddDescriptionModal.tsx` from handoff file
  - [ ] B.6.1.1 Fix route: change `/jobs/${job.id}/setup/job_post` → `/jobs/${job.id}/setup/description`
  - [ ] B.6.1.2 Strip JSDoc comments

### B.7 RunPlatoNoCandidatesModal

**Read:** `cursor_rules/frontend/modals/modal_form_and_confirmation_patterns.md`

- [ ] B.7.1 Create `app/javascript/ats/src/views/jobApplications/RunPlatoNoCandidatesModal.tsx` from handoff file
  - [ ] B.7.1.1 Fix route: change `/jobs/${job.id}/setup/job_post` → `/jobs/${job.id}/setup/description` in the primary action button
  - [ ] B.7.1.2 Fix route: change `/hire/settings/integrations/plato` → `/hire/settings/plato-ai`
  - [ ] B.7.1.3 Replace raw `<Styled.Link href=...>` elements with `Link` from `react-router-dom` for inline navigation links (org settings, per-job AI settings)
  - [ ] B.7.1.4 Keep `/jobs/${job.id}/setup/ai` as-is (verified correct)
  - [ ] B.7.1.5 Strip JSDoc comments

### B.8 Sidebar integration

**Read:** `cursor_rules/frontend/components/component_architecture.md`

- [ ] B.8.1 Modify `app/javascript/ats/src/views/jobApplications/JobStagesContainer.tsx`
  - [ ] B.8.1.1 Import `RunPlatoCtaCardV1` from `"@ats/src/views/jobApplications/RunPlatoCtaCardV1"`
  - [ ] B.8.1.2 Render `RunPlatoCtaCardV1` inside `Styled.Sidebar` after the second `Styled.List` block (line 139), before the closing `</Styled.Sidebar>` tag (line 140)
  - [ ] B.8.1.3 Pass individual props: `job={{ id: job.id }}`, `jobApplicationsCount={job.jobApplicationsCount}`, `jobApplicationsSummaryCount={job.aiJobApplicationSummariesCount}`, `autoGenerateEnabled={job.shouldAutoGenerateAiSummaries}`, `jobDescription={job.description}`
  - [ ] B.8.1.4 Add `display: flex; flex-direction: column;` to `Styled.Sidebar` (line 204-219) so the CTA card's `margin-top: auto` pins to bottom

## C. Test Changes

**Read before starting:** `cursor_rules/core_critical_rules.md` (test-related rules)

### C.1 Interactor spec updates

- [ ] C.1.1 Modify `spec/interactors/queue_bulk_ai_summary_jobs_spec.rb`
  - [ ] C.1.1.1 Add context `"when rescore_requested is true"`: create a candidate with `AiJobApplicationSummaryStatus` status `:current`, call with `rescore_requested: true`, verify candidate IS queued (not filtered)
  - [ ] C.1.1.2 Add example verifying default behavior without `rescore_requested`: candidate with `:current` status IS filtered out (existing behavior, make explicit)
  - [ ] C.1.1.3 Add example verifying `kind` passes through: call with `kind: 'all_stages'`, verify the enqueued `BulkGenerateAiSummariesJob` payload includes `'kind' => 'all_stages'`
  - [ ] C.1.1.4 Add example verifying `kind` defaults: call without `kind`, verify payload includes `'kind' => 'single_hiring_stage'`
  - [ ] C.1.1.5 Add example verifying `:processing` filter always applies even with `rescore_requested: true`

### C.2 Job spec updates

- [ ] C.2.1 Modify `spec/jobs/bulk_generate_ai_summaries_job_spec.rb`
  - [ ] C.2.1.1 Add context `"when kind is all_stages"` under `#on_complete` / `notify_complete`:
    - [ ] Verify broadcast `hiringStageLink` is `/jobs/:id/stages` (no stage suffix)
    - [ ] Verify mailer dispatched is `BulkAllStagesAiSummaryResultMailer.complete` (not `BulkJobApplicationAiSummaryResultMailer`)
    - [ ] Verify `.deliver_later` is called on the mailer return value
  - [ ] C.2.1.2 Add context `"when kind is all_stages"` under `notify_failure`:
    - [ ] Verify mailer dispatched is `BulkAllStagesAiSummaryResultMailer.failed`
    - [ ] Verify `.deliver_later` is called
  - [ ] C.2.1.3 Add context `"when kind is absent"` verifying existing behavior unchanged (existing mailer, stage link)

### C.3 New mailer spec

- [ ] C.3.1 Create `spec/mailers/bulk_all_stages_ai_summary_result_mailer_spec.rb`
  - [ ] C.3.1.1 Follow `spec/mailers/ai_credit_notification_mailer_spec.rb` pattern: `instance_double(Emails::SendTemplateEmail, send: true)`, stub `Emails::SendTemplateEmail.new` to return the double
  - [ ] C.3.1.2 Test `complete`: verify `Emails::SendTemplateEmail` receives correct `message_params` — template alias `user-bulk-all-stages-ai-summary-complete`, variables include job-level link `"#{Variables::AtsRootUrl}/jobs/#{job.id}/stages"`, no `hiring_stage_id` in variables
  - [ ] C.3.1.3 Test `failed`: verify template alias `user-bulk-all-stages-ai-summary-failed`, variables include `total_queued_count`
  - [ ] C.3.1.4 Verify `.deliver_later` chaining at call sites (test via the job spec contexts in C.2, not here — the mailer itself doesn't chain delivery)

## D. Validation and Constraints

- The `kind` parameter is a plain string, not a Ruby enum — `"single_hiring_stage"` or `"all_stages"`
- Existing `create` action and callers unchanged — `kind` defaults to `"single_hiring_stage"` when absent
- `:processing` filter always applies regardless of `rescore_requested`
- `RunPlatoReviewAllModal` credit validation matches `BulkGenerateAiSummariesConfirmModal`: zero-credit gate, shortfall warning, inline balance display
- All mailer `.deliver_later` calls verified per known failure pattern #4
- Button `loading`+`disabled` props per known failure pattern #11
- No `??` operator (CLAUDE.md rule #11) — use `||` instead
- No `useMemo` for derived counts (CLAUDE.md rule #13) — `candidatesToScoreCount` is a plain expression
- No deliberate `undefined` (CLAUDE.md rule #9)

## E. Documentation Impact

- Postmark templates `user-bulk-all-stages-ai-summary-complete` and `user-bulk-all-stages-ai-summary-failed` must be created externally before the mailer can send. Template content follows existing `user-bulk-ai-summary-complete` / `user-bulk-ai-summary-failed` but references "all candidates in this job" instead of a specific hiring stage
- No code documentation changes needed

## F. Risks and Open Questions

1. **Postmark templates** — must be created externally. The mailer will silently fail if templates don't exist. Low risk: can be created alongside the PR
2. **Large jobs** — a job with thousands of candidates creates thousands of `BulkAiSummaryJobApplication` rows and a long-running `BulkGenerateAiSummariesJob`. The existing `job_iteration_max_job_runtime = 10.minutes` guard handles this, but very large jobs may hit it. No change from existing behavior
3. **`text-wrap: pretty`** — handoff CSS uses this. Check browser support; remove if needed
4. **Sidebar flex change** — adding `display: flex; flex-direction: column` to `Styled.Sidebar` could affect existing layout. The sidebar currently contains two `Styled.List` blocks and a `Styled.Divider` — flex column should preserve their existing flow layout, but verify visually

## G. Estimated Scope

- **New files:** 9 (1 mailer, 7 frontend components, 1 mailer spec)
- **Modified files:** 9 (1 route, 1 controller, 1 interactor, 1 job, 1 serializer, 1 mutation hook, 1 container, 2 specs)
- **Total:** ~18 files, estimated ~800-1000 lines of new code (frontend components are the bulk — styled components are verbose)
