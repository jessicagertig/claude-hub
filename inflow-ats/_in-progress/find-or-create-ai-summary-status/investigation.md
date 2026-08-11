# Deep Investigation Results

## Interactor analog: FindOrCreateOrgInterviewerInvite

- `build` + explicit `save`, never `create` or `find_or_create_by`
- `context.invite` set in both found and created branches
- Found branch: set context, return early
- Failure: `context.fail!`

## Bulk path: BulkGenerateAiSummariesJob#each_iteration

- `job_application` assigned at line 32
- Idempotency check at lines 48-56 (skip already-processed)
- Validation at line 59 (`ValidateAiSummaryGeneration.call`)
- Pipeline call at line 62 (`result.textract_result.generate_ai_summary_with_credit_flow`)
- Does NOT go through `CreateAiSummaryGeneration`
- Helper call placement: between line 60 (validation passes) and line 62 (pipeline call)

## JobApplication model

- `has_one :ai_job_application_summary_status` at line 31
- `has_many :ai_job_application_summaries` at line 29
- `has_one :latest_ai_job_application_summary` at line 30
- `enqueue_new_job_application` at lines 151-157: calls NewJobApplicationJob, DocxToPdfJob, conditionally SubmitResumeToTextractJob
- No `find_or_create_ai_job_application_summary_status` method exists yet
- Helper call goes as last line of `enqueue_new_job_application`

## Call sites being removed

- `AiJobApplicationSummary#create_status_record` (after_commit on create, line 27) — `find_or_create_by` with `regenerating: false` block (already stripped to bare `find_or_create_by`)
- `CreateAiSummaryGeneration` lines 54 and 74 — `find_or_create_by` calls (already stripped of `regenerating: false`)
