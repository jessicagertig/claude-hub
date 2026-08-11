# Review Angles — All Candidates Bulk Action

Generated from: SPEC.md
Date: 2026-06-24

## Subsystems touched

### Backend — modified
- `config/routes.rb:199` — add collection block with `post :all_stages`
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb` — new `all_stages` action, expand `bulk_ai_job_application_summary_params`
- `app/interactors/queue_bulk_ai_summary_jobs.rb` — accept `context.kind` and `context.rescore_requested`, conditionally skip `:current` filter, pass `kind` to job payload
- `app/jobs/bulk_generate_ai_summaries_job.rb` — branch `notify_complete` and `notify_failure` on `kind`
- `app/serializers/api/v1/job_serializer.rb` — add `ai_job_application_summaries_count` and `should_auto_generate_ai_summaries` attributes

### Backend — new
- `app/mailers/bulk_all_stages_ai_summary_result_mailer.rb` — new mailer class `BulkAllStagesAiSummaryResultMailer`

### Frontend — modified
- `app/javascript/ats/src/views/jobApplications/JobStagesContainer.tsx` — import and render `RunPlatoCtaCardV1` in `Styled.Sidebar`
- `app/javascript/shared/queryHooks/useBulkGenerateAiSummaries.ts` — new params type, function, and hook for all-stages mutation

### Frontend — new
- `app/javascript/ats/src/views/jobApplications/RunPlatoCtaCardV1.tsx`
- `app/javascript/ats/src/views/jobApplications/RunPlatoCtaCardV2.tsx`
- `app/javascript/ats/src/views/jobApplications/useRunPlatoCtaModals.tsx`
- `app/javascript/ats/src/views/jobApplications/RunPlatoReviewAllModal.tsx`
- `app/javascript/ats/src/views/jobApplications/RunPlatoAddDescriptionModal.tsx`
- `app/javascript/ats/src/views/jobApplications/RunPlatoNoCandidatesModal.tsx`
- `app/javascript/ats/src/views/jobApplications/PlatoSparkleIcon.tsx`

### Tests — existing (may need updates)
- `spec/interactors/queue_bulk_ai_summary_jobs_spec.rb` — new `kind` and `rescore_requested` context params
- `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` — `kind`-based branching in `notify_complete` and `notify_failure`

### Tests — new (expected)
- Controller spec for `all_stages` action
- Mailer spec for `BulkAllStagesAiSummaryResultMailer`

## Full-stack analog

The existing per-stage bulk AI summary generation flow:

- **Frontend trigger:** `JobStageMenu` (`app/javascript/ats/src/views/jobApplications/JobStageMenu.tsx`) — `handleOnClickGenerateAiSummaries` (:120) opens `BulkGenerateAiSummariesConfirmModal`
- **Frontend modal:** `BulkGenerateAiSummariesConfirmModal` (`app/javascript/ats/src/views/jobApplications/BulkGenerateAiSummariesConfirmModal.tsx`) — owns mutation via `useBulkGenerateAiSummaries`, uses `useOrganizationAiCreditBalance` (:47), `validateBulkGenerateAiSummaries` (:58), `dismissModalWithAnimation` (:53), `useToastContext` (:42), `FormContainer` with `errors` state (:160), `trackEvent` (:76)
- **Frontend mutation:** `useBulkGenerateAiSummaries` (`app/javascript/shared/queryHooks/useBulkGenerateAiSummaries.ts`) — POSTs to `/bulk_ai_job_application_summaries`, invalidates `jobApplicationsForStage`, `jobApplication`, `organizationAiCreditBalance`
- **API route:** `POST /api/v1/bulk_ai_job_application_summaries` — `config/routes.rb:199`
- **Controller:** `BulkAiJobApplicationSummariesController#create` (`app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb:6-28`) — `authorize :ai_job_application_summary, :bulk_create?`, `resolve_job_application_ids` (:32-46), calls `QueueBulkAiSummaryJobs`
- **Authorization:** `AiJobApplicationSummaryPolicy#bulk_create?` (`app/policies/ai_job_application_summary_policy.rb:12-14`) — delegates to `can_use_ai_credits?` (org-level)
- **Interactor:** `QueueBulkAiSummaryJobs` (`app/interactors/queue_bulk_ai_summary_jobs.rb`) — filters `:current` (:36-40), filters `:processing` (:43-45), creates `BulkAiSummaryJobApplication` rows (:64-75), enqueues `BulkGenerateAiSummariesJob` (:82-89)
- **Background job:** `BulkGenerateAiSummariesJob` (`app/jobs/bulk_generate_ai_summaries_job.rb`) — `JobIteration::Iteration`, `notify_complete` (:123-145) broadcasts `AI_SUMMARY_BULK_COMPLETE` and calls mailer `.deliver_later`, `notify_failure` (:148-172) broadcasts `AI_SUMMARY_BULK_FAILED` and calls mailer `.deliver_later`
- **Mailer:** `BulkJobApplicationAiSummaryResultMailer` (`app/mailers/bulk_job_application_ai_summary_result_mailer.rb`) — `complete` (:4-29) takes `hiring_stage_id`, builds stage link, sends via `Emails::SendTemplateEmail`; `failed` (:31-51)
- **WebSocket handler:** `WebsocketGlobalChannelHandler` (`app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx`) — `AI_SUMMARY_BULK_COMPLETE` (:259-285) shows toast with `linkTo: payload.hiringStageLink`, invalidates queries; `AI_SUMMARY_BULK_FAILED` (:246-257)
- **Payload types:** `AiSummaryBulkCompletePayload` (`app/javascript/shared/types/aiSummaryWebsocketPayloads.ts:11-16`) — `hiringStageLink: string`
- **Serializer:** `Api::V1::JobSerializer` (`app/serializers/api/v1/job_serializer.rb`) — currently has `job_applications_count` (:15), needs two new attributes
- **Validation:** `validateBulkGenerateAiSummaries` (`app/javascript/shared/lib/validateWithYup.ts:548-561`) — checks `availableCredits >= 1`

**Priority rule:** Where the full-stack analog deviates from convention, the analog wins. Note the deviation so the reviewer doesn't flag it.

Known analog conventions that MUST be carried over:
- Modal owns its mutation (not passed from parent) — `BulkGenerateAiSummariesConfirmModal:43,66-100`
- `dismissModalWithAnimation(() => onCancel)` for close — `BulkGenerateAiSummariesConfirmModal:53,90`
- Credit balance check + shortfall warning + validation gate — `BulkGenerateAiSummariesConfirmModal:47-50,58-64,161-167`
- `.deliver_later` on every mailer invocation — `bulk_generate_ai_summaries_job.rb:144,171` (per known failure pattern #4)
- `Emails::SendTemplateEmail` for sending — `bulk_job_application_ai_summary_result_mailer.rb:28,50`
- Handler naming: `handleOnClick` + action for button click handlers — `JobStageMenu:98,120,142`
- `Button` `loading` and `disabled` props — `BulkGenerateAiSummariesConfirmModal:137-138` (per known failure pattern #11)
- `trackEvent` for PostHog — `BulkGenerateAiSummariesConfirmModal:76`

## Angles

### 1. backend-contract
**What this covers:** The API contract between frontend and backend — route, controller params, interactor inputs, job payload shape, serializer output, and whether the all-stages action's request/response matches the analog's shape where it should and diverges only where the spec explicitly requires.
**Files across all layers:**
- `config/routes.rb:199`
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb`
- `app/interactors/queue_bulk_ai_summary_jobs.rb`
- `app/jobs/bulk_generate_ai_summaries_job.rb` (payload shape)
- `app/serializers/api/v1/job_serializer.rb`
- `app/javascript/shared/queryHooks/useBulkGenerateAiSummaries.ts`
- `app/javascript/ats/src/views/jobApplications/RunPlatoReviewAllModal.tsx` (consumes response)
- `app/javascript/ats/src/views/jobApplications/JobStagesContainer.tsx` (consumes serializer attributes)
**Analog files for comparison:**
- Controller `create` action (:6-28, :48-55) — param shape, interactor call, response rendering
- Interactor context reads (:15) and payload build (:82-89) — new params must merge cleanly with existing
- Mutation hook (`useBulkGenerateAiSummaries.ts`) — request shape, query invalidation
**Convention context:**
- `cursor_rules/backend/controllers/` — controller patterns
- `cursor_rules/backend/serializers.md` — serializer attribute conventions
- `cursor_rules/core_critical_rules.md` rule #5 — one params method per controller
- `cursor_rules/core_critical_rules.md` rule #7 — snake_case backend, camelCase frontend

### 2. kind-dispatch
**What this covers:** The `kind` parameter's lifecycle from frontend request through controller, interactor, job payload, and branching in `notify_complete`/`notify_failure` to the correct mailer and broadcast link. Verifies that existing per-stage behavior is unchanged when `kind` is absent or `"single_hiring_stage"`, and that `"all_stages"` routes to the new mailer and job-level link.
**Files across all layers:**
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb` — `all_stages` action sets `kind`
- `app/interactors/queue_bulk_ai_summary_jobs.rb` — receives `context.kind`, passes to payload
- `app/jobs/bulk_generate_ai_summaries_job.rb` — `notify_complete` (:123-145) and `notify_failure` (:148-172) branch on `kind`
- `app/mailers/bulk_all_stages_ai_summary_result_mailer.rb` — new mailer
- `app/mailers/bulk_job_application_ai_summary_result_mailer.rb` — existing mailer, must remain unchanged
- `app/javascript/shared/types/aiSummaryWebsocketPayloads.ts` — `hiringStageLink` field carries different URL
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx:259-285` — renders `hiringStageLink` as toast link
**Analog files for comparison:**
- Existing `notify_complete` (:123-145) — link construction at :133, mailer call at :137-144
- Existing `notify_failure` (:148-172) — mailer call at :167-171
**Convention context:**
- `cursor_rules/backend/background_jobs.md` — job patterns
- Known failure pattern #4 — `.deliver_later` on every mailer call
- Known failure pattern #8 — trace guard ordering before adding branches

### 3. rescore-filter
**What this covers:** The `rescore_requested` param's effect on the `:current` status filter in `QueueBulkAiSummaryJobs`. When true, candidates with `AiJobApplicationSummaryStatus` status `:current` must NOT be dropped from the working set. The `:processing` filter must ALWAYS apply regardless. Verifies the existing `create` flow is unaffected (no `rescore_requested` → filter applies as before).
**Files across all layers:**
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb` — passes `rescore_requested` from params
- `app/interactors/queue_bulk_ai_summary_jobs.rb:36-45` — both filters, conditional skip
- `app/models/ai_job_application_summary_status.rb` — `:current` status definition
- `app/models/bulk_ai_summary_job_application.rb` — `:processing` status definition
- `app/javascript/ats/src/views/jobApplications/RunPlatoReviewAllModal.tsx` — `rescore` checkbox drives `rescoreRequested` param
- `app/javascript/shared/queryHooks/useBulkGenerateAiSummaries.ts` — new mutation passes `rescoreRequested`
**Analog files for comparison:**
- Existing interactor filter (:36-40) — the exact lines being conditionally skipped
**Convention context:**
- `cursor_rules/backend/interactors/` — interactor patterns

### 4. modal-behavior
**What this covers:** All three modal components match codebase conventions — mutation ownership, close pattern, credit check, validation gate, loading/disabled states, toast notifications, error handling, PostHog tracking. The `RunPlatoReviewAllModal` must structurally match `BulkGenerateAiSummariesConfirmModal` in all behavioral aspects (not just layout).
**Files across all layers:**
- `app/javascript/ats/src/views/jobApplications/RunPlatoReviewAllModal.tsx`
- `app/javascript/ats/src/views/jobApplications/RunPlatoAddDescriptionModal.tsx`
- `app/javascript/ats/src/views/jobApplications/RunPlatoNoCandidatesModal.tsx`
- `app/javascript/ats/src/views/jobApplications/useRunPlatoCtaModals.tsx`
- `app/javascript/shared/queryHooks/useOrganizationAiCreditBalance.ts` — credit balance hook
- `app/javascript/shared/lib/validateWithYup.ts:548-561` — validation function
- `app/javascript/shared/context/ModalContext.tsx` — `openModal`, `removeModal`, `dismissModalWithAnimation`
- `app/javascript/shared/context/ToastContext.tsx` — `addToast`
- `app/javascript/shared/lib/posthog.ts` — `trackEvent`
**Analog files for comparison:**
- `BulkGenerateAiSummariesConfirmModal.tsx` — complete behavioral template:
  - Mutation ownership (:43, :66-100)
  - `dismissModalWithAnimation(() => onCancel)` (:53, :90)
  - Credit balance (:47-50)
  - Shortfall warning (:161-167)
  - Validation gate (:58-64)
  - `loading`/`disabled` on Button (:137-138)
  - Toast on success/error (:77-98)
  - `trackEvent` (:76)
  - `FormContainer` with errors (:160)
**Convention context:**
- `cursor_rules/frontend/modals/` — modal patterns
- `cursor_rules/frontend/react_query/` — mutation patterns
- `cursor_rules/core_critical_rules.md` rule #9 — never deliberately set `undefined`
- `cursor_rules/core_critical_rules.md` rule #10 — never fabricate fallback values
- Known failure pattern #11 — copy behavioral props, not just layout
- Known failure pattern #13 — never fabricate fallback values for absent data

### 5. sidebar-integration
**What this covers:** The CTA card's integration into `JobStagesContainer` — correct data flow from the job query to the card's props, correct placement in `Styled.Sidebar`, pinning to bottom via `margin-top: auto`, and that both V1 and V2 components compile and V1 renders.
**Files across all layers:**
- `app/javascript/ats/src/views/jobApplications/JobStagesContainer.tsx` — parent container, `Styled.Sidebar` (:121-140)
- `app/javascript/ats/src/views/jobApplications/RunPlatoCtaCardV1.tsx`
- `app/javascript/ats/src/views/jobApplications/RunPlatoCtaCardV2.tsx`
- `app/javascript/ats/src/views/jobApplications/PlatoSparkleIcon.tsx`
- `app/serializers/api/v1/job_serializer.rb` — `aiJobApplicationSummariesCount` and `shouldAutoGenerateAiSummaries` must be available in frontend
- `app/javascript/ats/styles/theme.ts` — color tokens used by styled components
**Analog files for comparison:**
- `JobStageMenu` (`app/javascript/ats/src/views/jobApplications/JobStageMenu.tsx`) — handler naming convention `handleOnClick*` (:98, :120, :142), `styled(Button)` width override
**Convention context:**
- `cursor_rules/frontend/ui_styling.md` — Emotion styling patterns
- `cursor_rules/core_critical_rules.md` rule #2 — theme colors must exist
- Known failure pattern #1 — Emotion theme utilities are complete CSS declarations
- Known failure pattern #12 — separate styled components for variants, not conditional props

### 6. mailer-parity
**What this covers:** The new `BulkAllStagesAiSummaryResultMailer` matches the existing `BulkJobApplicationAiSummaryResultMailer` in structure — `Emails::SendTemplateEmail` usage, message_params shape, variable names, `.deliver_later` chaining at the call site, and that the only differences are the absence of `hiring_stage_id`, the job-level link, and the template alias.
**Files across all layers:**
- `app/mailers/bulk_all_stages_ai_summary_result_mailer.rb` — new mailer
- `app/mailers/bulk_job_application_ai_summary_result_mailer.rb` — analog mailer
- `app/jobs/bulk_generate_ai_summaries_job.rb:137-144,167-171` — call sites, must chain `.deliver_later`
- `app/services/emails/send_template_email.rb` — delivery mechanism (read-only, verify interface)
**Analog files for comparison:**
- `BulkJobApplicationAiSummaryResultMailer` — complete structural template:
  - `complete` (:4-29): params shape, `Variables::AtsRootUrl` link, `Emails::SendTemplateEmail`, tags
  - `failed` (:31-51): params shape
**Convention context:**
- Known failure pattern #4 — `.deliver_later` on every mailer invocation
- `cursor_rules/core_critical_rules.md` rule #3 — use `ap` not `pp`

## Always-on checks

These apply to every feature regardless of angles:

### Source accuracy
The review agent verifies every file path, class, method, column, route, and component the spec references against the current source.

### Test coverage
The review agent checks what existing tests cover the affected code and what new tests the spec should require.

Existing test files that may need updates:
- `spec/interactors/queue_bulk_ai_summary_jobs_spec.rb` — new context params `kind` and `rescore_requested`
- `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` — `kind`-based branching

New test files expected:
- Controller spec for `BulkAiJobApplicationSummariesController#all_stages` (note: no existing controller spec for `#create` exists)
- Mailer spec for `BulkAllStagesAiSummaryResultMailer`

### Backward compatibility
The review agent identifies all consumers of modified code and verifies they are addressed.

Key backward compatibility points:
- `QueueBulkAiSummaryJobs` — existing `create` caller does not pass `kind` or `rescore_requested`; interactor must default gracefully
- `BulkGenerateAiSummariesJob` — existing payloads have no `kind` key; job must treat absent `kind` as `"single_hiring_stage"`
- `bulk_ai_job_application_summary_params` — adding `rescore_requested` to the permit list must not break existing `create` requests that don't include it
- `Api::V1::JobSerializer` — adding attributes is additive; frontend consumers that destructure will not break

### Full-stack analog completeness
The review agent verifies the new feature has a corresponding piece for every layer of the analog pipeline. A missing layer is a BLOCKER.

Analog layers → new feature mapping:
| Analog layer | Analog file | New feature equivalent |
|---|---|---|
| Frontend trigger | `JobStageMenu:120` | `useRunPlatoCtaModals` `handleOnClickRunPlato` |
| Frontend modal | `BulkGenerateAiSummariesConfirmModal` | `RunPlatoReviewAllModal` (+ 2 gate modals) |
| Frontend mutation | `useBulkGenerateAiSummaries` | New all-stages function in same file |
| API route | `POST /bulk_ai_job_application_summaries` | `POST /bulk_ai_job_application_summaries/all_stages` |
| Controller action | `#create` | `#all_stages` |
| Authorization | `bulk_create?` | Same policy, no change |
| Interactor | `QueueBulkAiSummaryJobs` | Same interactor, new params |
| Background job | `BulkGenerateAiSummariesJob` | Same job, branching on `kind` |
| Mailer | `BulkJobApplicationAiSummaryResultMailer` | `BulkAllStagesAiSummaryResultMailer` |
| WebSocket broadcast | `AI_SUMMARY_BULK_COMPLETE` | Same action, different link value |
| Serializer | `JobSerializer` | Same serializer, new attributes |

### Analog structural matching
The review agent greps for analog files, reads their parameter interfaces, retry/exhaustion patterns, callback patterns, and error handling shapes, and diffs them against the new code. Layer completeness ("it has a controller") without structural matching ("the controller accepts the same parameter shape") is insufficient. A structural mismatch is BLOCKER.

What to compare:
- **Controller parameter interfaces:** the existing `create` uses `params.require(:bulk_ai_job_application_summary).permit(...)`. The new `all_stages` must wrap its params in the same top-level key `bulk_ai_job_application_summary` and use the same single params method (expanded with `rescore_requested`). Per CLAUDE.md rule #5, there must be ONE params method.
- **Controller response shape:** `all_stages` must return the same JSON keys as `create` — `queued_count`, `skipped_count`, `any_textract_pending`. The mutation hook's response type must match.
- **Interactor error handling:** `create` renders `render_general_errors([result.error])` on failure. `all_stages` must do the same.
- **Job payload shape:** `kind` is additive to the existing payload keys (`bulk_job_id`, `user_id`, `hiring_stage_id`, `job_id`, `job_application_ids`, `skipped_count`). For all-stages, `hiring_stage_id` in the payload will be from `first.hiring_stage_id` (first candidate's stage) — this is fine because the all-stages path ignores it in link construction.
- **Mailer method signatures:** `BulkAllStagesAiSummaryResultMailer.complete` must follow the same pattern as the analog's `complete` — `User.find`, `Job.find`, `Emails::SendTemplateEmail.new(message_params).send`, with the same `from`/`to`/`list_unsubscribe`/`tags` structure.
- **Mailer `.deliver_later`:** both call sites in `notify_complete` and `notify_failure` must chain `.deliver_later`. Missing this means the email is silently never sent (known failure pattern #4).

Real failures this would have caught: (1) `BulkAiJobApplicationSummariesController` accepted raw `job_application_ids` from the frontend instead of following the `job_id` + `hiring_stage_id` + `included/excluded` pattern used by bulk move and bulk message controllers. Passed a full QA round unflagged. (2) `GenerateAiJobApplicationSummaryJob` lacked an exhaustion block on `retry_on` despite `GetResumeTextFromTextractJob` and `BulkGenerateAiSummariesJob` both having one. Users saw multiple failure toasts before retries exhausted.
