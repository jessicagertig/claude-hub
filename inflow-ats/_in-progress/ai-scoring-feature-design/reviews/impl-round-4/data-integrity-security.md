# data-integrity-security -- Round 4

## Scope

Data integrity constraints, security considerations, no data loss paths.

## Findings

### Database constraints

- `ai_job_criteria.job_id`: NOT NULL, foreign key, unique index. One criteria record per job enforced at database level.
- `ai_job_criteria.status`: NOT NULL, default 0. Cannot be null.
- `ai_job_application_summary_statuses.job_application_id`: NOT NULL, foreign key, unique index. One status record per job application.
- `ai_job_application_summary_statuses.regenerating`: NOT NULL, default false.
- `ai_job_application_summary_statuses.ai_job_application_summary_id`: nullable foreign key. Correctly nullable -- not populated until a summary reaches `succeeded`.
- `score_percentage`, `criteria_results`, `integrated_role_analysis`: all nullable, no defaults. Correctly nullable -- only populated when scoring completes.

### No silent data loss

- `ExtractCriteria` on failure: sets `failed` with `error_message`. Error is preserved.
- `ScoreJobApplication` on failure: sets `failed` or `retrying` with `error_message`. Error preserved.
- `IntegrateAnalysis` on failure: same pattern.
- `GenerateAiJobApplicationSummaryJob` exhaustion: sets `failed` with error message. No silent swallowing.

### No unauthorized data access

- All paths go through existing `AiJobApplicationSummaryPolicy` for authorization. Scoring services are invoked from the same job/textract pipeline that already has authorization gates.
- `ExtractJobCriteriaJob` operates on `AiJobCriteria` associated with a `Job` -- no user-facing endpoint bypasses authorization.
- New serializer attributes (`score_percentage`, `criteria_results`, `integrated_role_analysis`) are added to existing serializers that already have proper authorization context.

### Flipper gate

`extract_job_criteria` checks `Flipper.enabled?(:AI_APPLICANT_SUMMARY, organization)` before any criteria extraction. Feature is properly gated.

### No direct database access

All database interactions go through ActiveRecord models. No raw SQL.

## Result: PASS -- 0 findings
