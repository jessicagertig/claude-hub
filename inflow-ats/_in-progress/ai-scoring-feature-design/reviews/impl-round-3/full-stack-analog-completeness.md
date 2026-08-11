# full-stack-analog-completeness -- Round 3

## Assessment

Checking that the new feature has a corresponding piece for every layer of the analog pipeline (the AI summary pipeline):

| Analog Layer | Analog File | New Feature Piece | Present? |
|---|---|---|---|
| Trigger (auto) | `TextractResult after_commit` | Criteria extraction on publish via `Job#handle_status_changed_to_published` | Yes (working tree) |
| Trigger (manual) | `AiJobApplicationSummariesController#create` | N/A (scoring is part of unified pipeline, not separate trigger) | N/A |
| Trigger (bulk) | `BulkAiJobApplicationSummariesController#create` | Bulk follows same pipeline through orchestrator | Yes |
| Trigger (description change) | N/A (new) | `Job#handle_description_change` -> `extract_job_criteria` | Yes (working tree) |
| Execution (service) | `Summary::Generate` | `ExtractCriteria`, `ScoreJobApplication`, `IntegrateAnalysis` | Yes |
| Execution (orchestrator) | N/A (new) | `Orchestrate` | Yes |
| Execution (job) | `GenerateAiJobApplicationSummaryJob` | `ExtractJobCriteriaJob` | Yes |
| Post-pipeline (credit) | `CreateAiCreditBalanceTransaction` | Reuses existing, gated by `status_succeeded?` | Yes |
| Post-pipeline (notification) | `NotifyZeroAiCredits`, `NotifyLowAiCredits` | Reuses existing | Yes |
| Broadcast | `AI_SUMMARY_COMPLETE` on GlobalChannel | Reuses existing, timing shifts to full pipeline complete | Yes |
| Auth | `AiJobApplicationSummaryPolicy` | Reuses existing | Yes |
| Serialization (full) | `AiJobApplicationSummarySerializer` | New attributes added | Yes (working tree) |
| Serialization (shallow) | `AiJobApplicationSummaryShallowSerializer` | `score_percentage` added | Yes (working tree) |
| Serialization (status) | N/A (new) | `AiJobApplicationSummaryStatusSerializer` | Yes |
| Cost tracking | `AiApiRequest` polymorphic | Reuses existing with `AiJobCriteria` as new requestable_type | Yes |
| Status model | `AiJobApplicationSummary` enum | Extended to 10 values | Yes |
| Read model | N/A (new) | `AiJobApplicationSummaryStatus` | Yes |
| Retry/exhaustion | `GenerateAiJobApplicationSummaryJob` retry_on | `ExtractJobCriteriaJob` retry_on with exhaustion block | Yes |

No missing layers.

## Findings

No findings.
