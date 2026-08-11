# All Candidates Bulk Action — Session Handoff

## Branch
`all-candidates-bulk-action` (based off `ai-summary-creation-gaps`)

## Feature Summary
Users can currently bulk-generate AI summaries for selected candidates within a single hiring stage. This feature adds a job-level action that scores all candidates across all stages at once, with no individual selection. Includes a rescore option for re-scoring candidates who already have summaries.

## Where We Are in the Process
Following brainstorming-plus skill. Completed:
- Working directory: `~/claude-hub/inflow-ats/_in-progress/all-candidates-bulk-action/`
- Vague scope and rough outline (saved as non-authoritative reference files)
- Deep investigation (saved to `investigations/deep-investigation.md`)
- Decision capture: 14 decisions captured to `approved-decisions.md`
- Handoff designs received from Claude AI at `/Users/jessica/Projects/genuine-article-images/run-plato-cta-handoff/`
- Handoff audit completed — 18 findings, ALL RESOLVED (decisions 11-14 capture the resolutions)

## What's Next
All handoff audit feedback has been incorporated. Resume brainstorming-plus checklist:

1. **Ask remaining clarifying questions** (checklist item 4) — any open questions not yet covered by decisions 1-14
2. **Present design sections** (checklist item 5) — present the full design in sections for approval
3. **Write spec** from `approved-decisions.md` (checklist item 6)
4. **Spec self-review** (checklist item 7)
5. **User reviews spec** (checklist item 8)
6. **Invoke writing-plans skill** (checklist item 9)

## Approved Decisions (14 total, in approved-decisions.md)

### Backend (decisions 1-5a)
1. **Route/controller** — collection route `post :all_stages` on existing `bulk_ai_job_application_summaries` resource. `BulkAiJobApplicationSummariesController#all_stages`
2. **Interactor params** — `QueueBulkAiSummaryJobs` gets `kind` and `rescore_requested` on context. Passes `kind` to job payload
3. **Background job** — no new job class. `BulkGenerateAiSummariesJob` stays. `on_complete` reads `kind` from payload, dispatches to correct mailer/broadcast
4. **Mailer** — new file `BulkAllStagesAiSummaryResultMailer` (`app/mailers/bulk_all_stages_ai_summary_result_mailer.rb`). Same two methods (`complete`, `failed`) but no `hiring_stage_id`, uses job-level link
5. **Job serializer** — add `ai_job_application_summaries_count` to `Api::V1::JobSerializer`
5a. **Job serializer** — add `should_auto_generate_ai_summaries` (predicate delegation)

### Frontend API + state (decisions 6, 8, 10)
6. **React Query mutation** — new function in existing `app/javascript/shared/queryHooks/useBulkGenerateAiSummaries.ts`. Params: `jobId` + `rescoreRequested`. POSTs to `/bulk_ai_job_application_summaries/all_stages`
8. **`kind` values** — `"single_hiring_stage"` and `"all_stages"`, string in job payload
10. **Broadcast** — leave existing `AI_SUMMARY_BULK_COMPLETE` as-is for now

### Frontend UI (decisions 7, 9, 11-14)
7. **Empty state modals** — three modal states: no description, no candidates + auto-gen on, no candidates + auto-gen off
9. **Mailer naming** — `BulkAllStagesAiSummaryResultMailer` in `app/mailers/bulk_all_stages_ai_summary_result_mailer.rb`
11. **CTA card receives individual props, not the job object** — `jobTitle`, `jobDescription`, `autoGenerateEnabled`, etc. Prop names are independent of serializer attribute names
12. **Handler and variable naming** — top-level click handler: `handleOnClickRunPlato` (matches `handleOnClick` + action convention). Branch targets keep shorter names: `handleNoDescription`, `handleNoCandidates`, `handleReviewAll`. Variable renames: `reReview` → `rescore`, `willReview` → `candidatesToScoreCount`, `reReviewExisting` → `rescoreRequested`
13. **Modal pattern** — `RunPlatoReviewAllModal` owns its mutation internally (per `BulkGenerateAiSummariesConfirmModal` analog). Receives `onCancel` only. Close uses `dismissModalWithAnimation(() => onCancel)` not `removeModal()`
14. **Replace placeholder mutation** — placeholder `useMutation` in hook replaced with real mutation from `useBulkGenerateAiSummaries.ts`. Since modal owns mutation (decision 13), hook no longer holds mutation state

## Handoff Audit Findings — Resolution Summary

All 18 original findings are resolved:
- Items 1-4 (naming mismatches): RESOLVED — card receives individual props, names don't need to match serializer (decision 11)
- Item 5 (reReviewExisting → rescoreRequested): CONFIRMED rename (decision 12)
- Item 6 (placeholder mutation): CONFIRMED replace (decision 14)
- Item 7 (modal owns mutation): CONFIRMED per codebase convention (decision 13)
- Item 8 (dismissModalWithAnimation): CONFIRMED per codebase convention (decision 13)
- Items 9-12 (links/routes): still need fixing during implementation — `/setup/job_post` → `/setup/description`, raw `<a href>` → React Router `Link`, org settings route needs verification
- Item 13 (JSDoc comments): strip per CLAUDE.md
- Item 14 (propTypes/defaultProps): fine, matches codebase
- Item 15 (theme colors): all verified
- Item 16 (text-wrap: pretty): flag during implementation
- Item 17 (useRunPlatoCtaModals hook pattern): justified for V1/V2 sharing
- Item 18 (type="internalLink"): verified valid

## Key Files Traced

### Backend
- `config/routes.rb:199` — bulk_ai_job_application_summaries route
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb` — existing controller
- `app/controllers/concerns/role_fit_filterable.rb` — role-fit filter concern (not needed for all-stages)
- `app/interactors/queue_bulk_ai_summary_jobs.rb` — main interactor, stage-agnostic, single caller (controller)
- `app/interactors/create_bulk_ai_summary_generation.rb` — creates AiJobApplicationSummary row per candidate
- `app/jobs/bulk_generate_ai_summaries_job.rb` — JobIteration job, single caller (interactor)
- `app/mailers/bulk_job_application_ai_summary_result_mailer.rb` — existing mailer, single caller (job)
- `app/models/ai_job_application_summary_status.rb` — counter_culture for `ai_job_application_summaries_count`, role-fit scopes
- `app/models/bulk_ai_summary_job_application.rb` — per-candidate claim rows
- `app/models/job.rb:159-163` — `auto_generate_ai_summaries` enum (default/enabled/disabled)
- `app/models/job.rb:948-956` — `should_auto_generate_ai_summaries?` resolution method
- `app/models/organization.rb:965-967` — `auto_generate_ai_summaries_enabled` from settings JSONB
- `app/serializers/api/v1/job_serializer.rb` — needs `ai_job_application_summaries_count` and `should_auto_generate_ai_summaries`
- `app/policies/ai_job_application_summary_policy.rb` — `bulk_create?` is org-level, works for all-stages

### Frontend
- `app/javascript/ats/src/views/jobApplications/JobContainer.tsx` — job-level view, `jobActions()` dropdown
- `app/javascript/ats/src/views/jobApplications/JobStagesContainer.tsx` — left rail with stage nav. CTA card placement target in `Styled.Sidebar`
- `app/javascript/ats/src/views/jobApplications/JobApplicationListContainer.tsx` — per-stage list, owns `useChecklist`
- `app/javascript/ats/src/views/jobApplications/JobStageMenu.tsx` — per-stage bulk actions dropdown (handler naming analog: `handleOnClickMessageAll`, `handleOnClickGenerateAiSummaries`, `handleOnClickMoveAll`)
- `app/javascript/ats/src/views/jobApplications/BulkGenerateAiSummariesConfirmModal.tsx` — existing per-stage confirm modal (modal pattern analog: owns mutation, `dismissModalWithAnimation`, `handleOnCancel`/`handleOnConfirm`)
- `app/javascript/shared/queryHooks/useBulkGenerateAiSummaries.ts` — existing mutation hook, new all-stages function goes here
- `app/javascript/ats/styles/theme.ts` — color definitions (lines 1-56)

### Cursor Rules Read
- `cursor_rules/core_critical_rules.md`
- `cursor_rules/backend/serializers.md`
- `cursor_rules/backend/architecture.md`
- `cursor_rules/frontend/modals/modal_form_and_confirmation_patterns.md`
- `cursor_rules/frontend/modals/modal_state_errors_and_loading.md`

### Handoff Files (from Claude AI — reference only, needs corrections per decisions 11-14)
Located at `/Users/jessica/Projects/genuine-article-images/run-plato-cta-handoff/`:
- `README.md` — overview, props, branching logic, TODOs
- `useRunPlatoCtaModals.tsx` — shared hook with branching + placeholder mutation (REPLACE mutation per decision 14, RENAME handler per decision 12)
- `RunPlatoCtaCardV1.tsx` — centered layout variant
- `RunPlatoCtaCardV2.tsx` — header-row layout variant
- `RunPlatoReviewAllModal.tsx` — happy path confirm modal (MUST own mutation per decision 13, RENAME variables per decision 12)
- `RunPlatoAddDescriptionModal.tsx` — no-description gate modal (FIX route per audit item 10)
- `RunPlatoNoCandidatesModal.tsx` — no-candidates modal (FIX routes per audit items 9-11, FIX Link component per audit item 9)
- `PlatoSparkleIcon.tsx` — sparkle SVG icon

## Auto-generate Settings Investigation
- `Job#auto_generate_ai_summaries` — enum: `default` (0), `enabled` (1), `disabled` (2). Already serialized as `auto_generate_ai_summaries`
- `Organization#auto_generate_ai_summaries_enabled` — from `settings` JSONB. Already in frontend via `CurrentSessionContext`
- `Job#should_auto_generate_ai_summaries?` — resolves cascade: job enabled → true; job disabled → false; job default → org setting. NOT currently serialized (decision 5a adds it)
