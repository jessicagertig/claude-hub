# Deep Investigation — All Candidates Bulk Action

## 1. Backend endpoint

### Existing route
`config/routes.rb:199` — `resources :bulk_ai_job_application_summaries, only: [:create]`
Collection route pattern used elsewhere: billing, ai_credit_purchases, jobs, users, notifications.

### Existing controller
`app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb`
- `create` action handles per-stage selection
- Uses `RoleFitFilterable` concern for role-fit filter passthrough
- `resolve_job_application_ids` has two paths: explicit IDs or stage-based resolution
- Authorizes via `authorize :ai_job_application_summary, :bulk_create?`

### Authorization policy
`app/policies/ai_job_application_summary_policy.rb:12-14`
- `bulk_create?` delegates to `can_use_ai_credits?` — org-level check (admin or hiring_team_ai_credits_control_enabled)
- Not stage- or job-specific. Same policy works for all-stages action.

## 2. Interactor — QueueBulkAiSummaryJobs

`app/interactors/queue_bulk_ai_summary_jobs.rb`
- Inputs: `context.organization`, `context.user`, `context.job_application_ids`
- No hiring_stage_id reference anywhere in interactor — fully stage-agnostic
- Lines 36-39: drops candidates with `AiJobApplicationSummaryStatus` status `:current` — this is the filter `rescore_requested` would skip
- Lines 43-45: drops candidates already claimed by another bulk batch (status `:processing`)
- Lines 64-75: creates `BulkAiSummaryJobApplication` rows with partial unique index protection

## 3. Job serializer — ai_job_application_summaries_count

- Column on `jobs` table: `db/schema.rb:907` — `t.integer "ai_job_application_summaries_count", default: 0, null: false`
- Migration: `db/migrate/20260622182504_add_ai_summary_and_criteria_columns_to_jobs.rb`
- Maintained by `counter_culture` in `app/models/ai_job_application_summary_status.rb:7` — increments for status `current` or `regenerating`
- NOT in `app/serializers/api/v1/job_serializer.rb` or `app/serializers/api/v1/shallow_job_serializer.rb`
- NOT referenced anywhere in frontend code
- Per serializer rules: regular column, just add to attributes list, no method needed

## 4. Downstream effects — stage assumptions

### BulkGenerateAiSummariesJob (`app/jobs/bulk_generate_ai_summaries_job.rb`)
- Line 85: `'hiring_stage_id' => first.hiring_stage_id` — passed to `notify_complete` and `notify_failure`
- Line 133: `hiringStageLink: "/jobs/#{payload['job_id']}/stages/#{payload['hiring_stage_id']}/applicants"` — stage-specific completion link
- Line 143: `hiring_stage_id` passed to mailer

### Mailer (`app/mailers/bulk_job_application_ai_summary_result_mailer.rb`)
- Line 4: `def complete(user_id, job_id, succeeded_count, failed_count, skipped_count, hiring_stage_id)`
- Line 8: `hiring_stage_link = "#{Variables::AtsRootUrl}/jobs/#{@job.id}/stages/#{hiring_stage_id}/applicants"`
- `hiring_stage_id` builds a stage-specific link in the email

### WebSocket broadcast handler (`app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx`)
- Line 259-285: `AI_SUMMARY_BULK_COMPLETE` handler
- Line 279: `linkTo: payload.hiringStageLink` — toast links to stage-specific URL
- Payload type `AiSummaryBulkCompletePayload` in `app/javascript/shared/types/aiSummaryWebsocketPayloads.ts:11-16` has `hiringStageLink: string`

### Summary of stage coupling downstream
Three places assume a single hiring stage:
1. Job — builds the hiringStageLink and passes hiring_stage_id to mailer
2. Mailer — receives hiring_stage_id, builds stage link in email
3. WebSocket handler — renders stage link in toast

For all-stages: link should point to the job level (e.g., `/jobs/:id/stages`) instead of a specific stage.

## 5. Frontend trigger — job-level UI

### JobContainer (`app/javascript/ats/src/views/jobApplications/JobContainer.tsx`)
- Lines 227-249: `jobActions()` renders a `DropdownMenu` with label "Job options"
- Contains: Add new candidate, Import candidates, Export candidates, Export resumes
- Has access to `job` object via `useJobStore` and `useJob` query
- Has `useModalContext` for opening modals
- Has `useFeatureGate` and `FeatureFlipper` patterns for feature gating
- `job.jobApplicationsCount` and `job.description` already available

## 6. Frontend confirm modal

Existing analog: `app/javascript/ats/src/views/jobApplications/BulkGenerateAiSummariesConfirmModal.tsx`
- Takes jobId, hiringStageId, candidate counts, credit info
- Uses `useOrganizationAiCreditBalance` for credit check
- Uses `useBulkGenerateAiSummaries` mutation
- Shows processable count, credit shortfall warning

## 7. Frontend empty state modals

Three cases identified by user (designs pending from Claude AI):
- No job description
- No candidates
- (Third case TBD — user will share designs)

Available data for empty state checks:
- `job.description` — in job serializer, available in JobContainer
- `job.jobApplicationsCount` — in job serializer, available in JobContainer

## 8. Frontend mutation

Existing file: `app/javascript/shared/queryHooks/useBulkGenerateAiSummaries.ts`
- 36 lines, single exported function
- New function goes in same file with different params interface
- Needs to POST to `/bulk_ai_job_application_summaries/all_stages`
- Invalidation: same query keys plus potentially `job` query for updated count
