# data-integrity-security -- Round 5

## Scope
Data validation, authorization, input sanitization, SQL injection prevention, mass assignment.

## Files reviewed
- All new models, controllers, services
- `db/schema.rb` constraints

## Authorization

`BulkAiJobApplicationSummariesController#create` has `authorize :ai_job_application_summary, :bulk_create?` at line 5. Job found via `current_organization.jobs.find(...)` -- scoped to org. Hiring stage found via `@job.hiring_stages.find(...)` -- scoped to job. No authorization bypass.

## Strong parameters

`bulk_ai_job_application_summary_params` permits only `:job_id`, `:hiring_stage_id`, `included_job_application_ids: []`, `excluded_job_application_ids: []`. No mass assignment vulnerability.

## Database constraints

- `ai_job_criteria.job_id`: NOT NULL, FK, unique index -- prevents orphans and duplicates
- `ai_job_application_summary_statuses.job_application_id`: NOT NULL, FK, unique index
- `ai_job_application_summary_statuses.ai_job_application_summary_id`: nullable FK (correct -- set after first success)
- `ai_job_criteria.status`: NOT NULL, default 0
- `ai_job_application_summary_statuses.regenerating`: NOT NULL, default false

## Input validation

- `AiJobCriteria`: `validates :status, presence: true` (redundant with NOT NULL + default, but matches analog)
- `AiJobApplicationSummaryStatus`: `validates :job_application_id, uniqueness: true` (application-level enforcement of DB unique index)
- No validation on jsonb columns -- spec says "trust the AI pipeline output"

## SQL injection

No raw SQL in any new code. All queries use ActiveRecord methods (`where`, `find_by`, `find`, `order`). `resolve_job_application_ids` uses `.map(&:to_i)` on IDs -- sanitizes input.

## Data leakage

New serializer attributes (`score_percentage`, `criteria_results`, `integrated_role_analysis`) are behind the same authorization gates as existing AI summary attributes. No new API endpoints exposing sensitive data without auth.

## Findings

None.
