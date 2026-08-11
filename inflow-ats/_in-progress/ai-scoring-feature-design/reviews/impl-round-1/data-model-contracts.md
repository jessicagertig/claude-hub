# Data Model Contracts -- Round 1

## Findings

No issues found.

`criteria_results` jsonb shape in `ScoreJobApplication` (lines 80-92) matches the spec schema: `criterion_text`, `tier`, `contains_title_technology`, `score`, `reasoning`, `summary`. `AiJobCriteria.criteria` jsonb written by `ExtractCriteria` matches spec: `text`, `tier`, `tier_reasoning`, `binary`, `contains_title_technology`, `source_heading`, `source_text` (with `duplicate` correctly removed before storage). `AiJobApplicationSummaryStatus` read model correctly has `job_application_id` uniqueness (both model validation and database index). Migrations are correct: `ai_job_criteria` has unique index on `job_id`, `ai_job_application_summary_statuses` has unique index on `job_application_id`. New columns on `ai_job_application_summaries` are all nullable with no default per spec. `AiApiRequest` polymorphic `requestable` works for `AiJobCriteria` (existing polymorphic setup, no table changes needed).
