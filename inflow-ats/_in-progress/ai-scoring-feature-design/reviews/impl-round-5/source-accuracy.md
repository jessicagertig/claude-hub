# source-accuracy -- Round 5

## Scope
Verify file paths, class names, method names, column names, routes, components referenced in spec exist in current source.

## Verified references

| Spec reference | Source verification |
|---------------|-------------------|
| `AiJobCriteria` model | `app/models/ai_job_criteria.rb` exists |
| `AiJobApplicationSummaryStatus` model | `app/models/ai_job_application_summary_status.rb` exists |
| `AiJobApplicationAction::Scoring::ExtractCriteria` | `app/services/ai_job_application_action/scoring/extract_criteria.rb` exists |
| `AiJobApplicationAction::Scoring::ScoreJobApplication` | `app/services/ai_job_application_action/scoring/score_job_application.rb` exists |
| `AiJobApplicationAction::Scoring::Calculate` | `app/services/ai_job_application_action/scoring/calculate.rb` exists |
| `AiJobApplicationAction::Scoring::IntegrateAnalysis` | `app/services/ai_job_application_action/scoring/integrate_analysis.rb` exists |
| `AiJobApplicationAction::Orchestrate` | `app/services/ai_job_application_action/orchestrate.rb` exists |
| `AiJobApplicationAction::Scoring::Prompts::IntegratedAnalysis` | `app/services/ai_job_application_action/scoring/prompts/integrated_analysis.rb` exists |
| `ExtractJobCriteriaJob` | `app/jobs/extract_job_criteria_job.rb` exists |
| `Api::V1::AiJobApplicationSummaryStatusSerializer` | `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb` exists |
| `TextractResult#generate_ai_summary` (now private) | `app/models/textract_result.rb` line 91 |
| `TextractResult#generate_ai_summary_with_credit_flow` | `app/models/textract_result.rb` line 61 |
| `Job#extract_job_criteria` | `app/models/job.rb` line 688 |
| `Job#handle_description_change` | `app/models/job.rb` line 705 |
| `Job#description_meaningfully_changed?` | `app/models/job.rb` line 713 |
| `Job#handle_status_changed_to_published` | `app/models/job.rb` line 544 |
| `CustomErrorAiSummary` | Referenced consistently, used in retry_on and rescue blocks |
| `AiClient` | `app/services/ai_client.rb` |
| `AiApiRequest` polymorphic `requestable` | Existing model, works for new `AiJobCriteria` type |

## Column verification

Columns verified against `db/schema.rb`:
- `ai_job_criteria`: `job_id`, `status`, `criteria`, `metadata`, `error_message`, `created_at`, `updated_at`
- `ai_job_application_summary_statuses`: `job_application_id`, `ai_job_application_summary_id`, `regenerating`, `created_at`, `updated_at`
- `ai_job_application_summaries` (new columns): `score_percentage`, `criteria_results`, `integrated_role_analysis`

## Findings

None.
