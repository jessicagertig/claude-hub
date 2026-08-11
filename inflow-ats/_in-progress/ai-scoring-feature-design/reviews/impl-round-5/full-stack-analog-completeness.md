# full-stack-analog-completeness -- Round 5

## Scope
Verify new feature has a corresponding piece for every layer of the analog pipeline (AI summary pipeline).

## Analog layers (17) with feature counterparts

| # | Layer | Analog | Feature |
|---|-------|--------|---------|
| 1 | Trigger (auto) | `TextractResult after_commit` -> `GenerateAiJobApplicationSummaryJob` | Same -- unchanged |
| 2 | Trigger (manual) | `AiJobApplicationSummariesController#create` -> `ValidateAiSummaryGeneration` -> `CreateAiSummaryGeneration` | Same -- unchanged |
| 3 | Trigger (bulk) | `BulkAiJobApplicationSummariesController#create` -> `QueueBulkAiSummaryJobs` | Updated -- now uses `job_id` + `hiring_stage_id` + included/excluded pattern |
| 4 | Entry point | `TextractResult#generate_ai_summary_with_credit_flow` | Same -- calls `generate_ai_summary` which now calls `Orchestrate` |
| 5 | Pipeline service | `Summary::Generate` | `Orchestrate` -> `Summary::Generate` + `ScoreJobApplication` + `IntegrateAnalysis` |
| 6 | Status enum | 6 values on `AiJobApplicationSummary` | 10 values on `AiJobApplicationSummary` |
| 7 | Credit consumption | `CreateAiCreditBalanceTransaction` after `status_succeeded?` | Same -- `succeeded` now means full pipeline |
| 8 | Notifications | `NotifyZeroAiCredits`, `NotifyLowAiCredits` | Same -- unchanged |
| 9 | Broadcast | `AI_SUMMARY_COMPLETE` in `GenerateAiJobApplicationSummaryJob` | Same -- fires after full pipeline |
| 10 | Auth | `AiJobApplicationSummaryPolicy` | Same -- unchanged |
| 11 | Full serializer | `AiJobApplicationSummarySerializer` | Updated -- 3 new attributes |
| 12 | Shallow serializer | `AiJobApplicationSummaryShallowSerializer` | Updated -- `score_percentage` |
| 13 | Cost tracking | `AiApiRequest` (polymorphic on `AiJobApplicationSummary`) | Extended -- also on `AiJobCriteria` |
| 14 | Job with retry | `GenerateAiJobApplicationSummaryJob` with `retry_on` | `ExtractJobCriteriaJob` with `retry_on` + exhaustion block; `GenerateAiJobApplicationSummaryJob` now also has exhaustion block |
| 15 | Model + callback | `AiJobApplicationSummary` with `after_commit` | `AiJobCriteria` with `after_commit`, `AiJobApplicationSummaryStatus` read model |
| 16 | Eager loading | `includes(resume_attachment: :blob)` | Added `.includes(:ai_job_application_summary_status)` |
| 17 | Flipper gate | `:AI_APPLICANT_SUMMARY` | Same -- reused, no new flag |

## Structural analog matching (pipeline failure pattern #14)

1. **Controller parameter interface:** Bulk controller now uses `job_id` + `hiring_stage_id` + `included/excluded` pattern, matching bulk move and bulk message controllers. Fix from pre-work findings.

2. **Job exhaustion blocks:** Both `ExtractJobCriteriaJob` and `GenerateAiJobApplicationSummaryJob` have exhaustion blocks on `retry_on`. Matches `GetResumeTextFromTextractJob` pattern.

3. **Callback patterns:** `AiJobCriteria#resume_waiting_summaries` mirrors `TextractResult#queue_ai_summary_job` -- callback fires after data update, finds waiting records, enqueues jobs.

## Findings

None.
