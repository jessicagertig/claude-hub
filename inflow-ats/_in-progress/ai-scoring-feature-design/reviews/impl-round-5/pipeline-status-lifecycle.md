# pipeline-status-lifecycle -- Round 5

## Scope
Redesigned `status` enum on `AiJobApplicationSummary` (10 values), every transition path, entry/exit for each status, no dead-end states.

## Files reviewed
- `app/models/ai_job_application_summary.rb` (full file)
- `app/services/ai_job_application_action/summary/generate.rb` (full file)
- `app/services/ai_job_application_action/orchestrate.rb` (full file)
- `app/services/ai_job_application_action/scoring/score_job_application.rb` (full file)
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb` (full file)
- `app/interactors/create_ai_summary_generation.rb` (full file)
- `app/models/textract_result.rb` (full file)
- `app/jobs/generate_ai_job_application_summary_job.rb` (full file)

## Transition map verified

| Status | Set by | Advances to |
|--------|--------|-------------|
| `pending` (0) | `CreateAiSummaryGeneration` | `extracting` (via `Summary::Generate`) |
| `textract_processing` (1) | `CreateAiSummaryGeneration` (textract pending path) | `extracting` (via `Summary::Generate`) |
| `extracting` (2) | `Summary::Generate` line 32 | `summarizing` (via `Summary::Generate` line 65) |
| `summarizing` (3) | `Summary::Generate` line 65 | `awaiting_job_criteria` (via `Orchestrate.check_criteria_and_score` line 72) |
| `awaiting_job_criteria` (4) | `Orchestrate.check_criteria_and_score` line 72, `ScoreJobApplication` line 23 | `scoring` (via `Orchestrate` -> `ScoreJobApplication`) |
| `scoring` (5) | `ScoreJobApplication` line 33 | `integrating` (via `ScoreJobApplication` line 101) |
| `integrating` (6) | `ScoreJobApplication` (status set in update_params) | `succeeded` (via `IntegrateAnalysis` line 51) |
| `succeeded` (7) | `IntegrateAnalysis` line 51 | Terminal |
| `retrying` (8) | `Summary::Generate` line 173, `ScoreJobApplication` line 107, `IntegrateAnalysis` line 57 | Re-enters at appropriate resume point via `Orchestrate` case statement |
| `failed` (9) | Multiple error handlers | Terminal |

Every status is reachable. No dead-end states. `retrying` is handled by the orchestrator case statement (line 25) alongside `pending`, `textract_processing`, and `extracting` -- re-runs summary from beginning.

## `Summary::Generate` no longer sets `succeeded`

Verified: `final_update_params` at line 162 contains only `headline`, `summary_text`, `structured_data`. No `status:` key. Status remains at `summarizing` after `Summary::Generate` completes. Orchestrator's `check_criteria_and_score` advances to `awaiting_job_criteria`.

## Findings

None.
