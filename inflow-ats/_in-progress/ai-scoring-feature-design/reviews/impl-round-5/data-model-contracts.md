# data-model-contracts -- Round 5

## Scope
jsonb shape consistency, `AiJobApplicationSummaryStatus` read model sync, new columns nullable/defaulted correctly, polymorphic `AiApiRequest` for `AiJobCriteria`.

## Files reviewed
- `db/migrate/20260311120000_create_ai_job_application_summaries.rb`
- `db/migrate/20260611120000_create_ai_job_criteria.rb`
- `db/migrate/20260611120001_create_ai_job_application_summary_statuses.rb`
- `db/schema.rb` lines 168-195
- `app/serializers/api/v1/ai_job_application_summary_serializer.rb`
- `app/serializers/api/v1/ai_job_application_summary_shallow_serializer.rb`
- `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb`
- `app/serializers/api/v1/shallow_job_application_serializer.rb`
- `app/controllers/api/v1/job_applications_controller.rb`

## New columns on `ai_job_application_summaries`

- `score_percentage` (decimal, nullable, no default) -- correct per spec
- `criteria_results` (jsonb, nullable, no default) -- correct per spec
- `integrated_role_analysis` (text, nullable, no default) -- correct per spec

## `criteria_results` shape consistency

Written by `ScoreJobApplication` (line 86-95): array of objects with keys `criterion_text`, `tier`, `contains_title_technology`, `score`, `reasoning`, `summary`. Matches spec Section 3 schema exactly.

Read by `IntegrateAnalysis` (line 27): `@ai_job_application_summary.criteria_results || []`. Passed to prompt. Shape consumed correctly.

Exposed by `AiJobApplicationSummarySerializer`: listed in `attributes`. No transformation needed -- jsonb column serialized as-is.

## `AiJobCriteria.criteria` shape consistency

Written by `ExtractCriteria` after dedup (line 110-113): array of objects with keys `text`, `tier`, `tier_reasoning`, `binary`, `contains_title_technology`, `source_heading`, `source_text`. `duplicate` field removed (line 113). Matches spec Section 1.

Read by `ScoreJobApplication` (line 36): `ai_job_criteria.criteria`. Passed to prompt messages. Also used for `criterion_source` lookup (line 89) matching on `text` field.

## `AiApiRequest` polymorphic

`AiJobCriteria` declares `has_many :ai_api_requests, as: :requestable`. `ExtractCriteria` creates `AiApiRequest` with `requestable: @ai_job_criteria`. The `ai_api_requests` table has `requestable_type` and `requestable_id` polymorphic columns. New `requestable_type` of `AiJobCriteria` works without any migration or config change -- Rails polymorphic associations handle arbitrary types.

## `AiJobApplicationSummaryStatus` read model

- Created by `after_commit :create_status_record` on `AiJobApplicationSummary` create (line 27, 45-49)
- Also created by `CreateAiSummaryGeneration` interactor via `find_or_create_by` (belt and suspenders)
- Updated by `after_commit :update_summary_status_record` on succeeded (line 29, 60-69)
- Serialized by `AiJobApplicationSummaryStatusSerializer` with `id`, `ai_job_application_summary_id`, `regenerating`
- Eager loaded in `JobApplicationsController` via `.includes(:ai_job_application_summary_status)`

## Serializer additions

- Full serializer: `score_percentage`, `criteria_results`, `integrated_role_analysis` added
- Shallow serializer: `score_percentage` added
- `ShallowJobApplicationSerializer`: `has_one :ai_job_application_summary_status` with dedicated serializer

## Findings

None.
