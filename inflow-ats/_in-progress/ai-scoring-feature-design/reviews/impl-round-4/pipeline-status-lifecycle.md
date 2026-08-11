# pipeline-status-lifecycle -- Round 4

## Scope

Verify the redesigned 10-value `status` enum on `AiJobApplicationSummary`, all transitions, entry/exit paths, and no dead-end states.

## Findings

### Enum definition

`AiJobApplicationSummary` defines 10 statuses with `_prefix: true`:
`pending: 0`, `textract_processing: 1`, `extracting: 2`, `summarizing: 3`, `awaiting_job_criteria: 4`, `scoring: 5`, `integrating: 6`, `succeeded: 7`, `retrying: 8`, `failed: 9`.

Matches spec Section 3 exactly.

### Transition paths verified

1. `pending` -> `extracting`: `Summary::Generate` line 32 (`update_columns(status: :extracting)`)
2. `extracting` -> `summarizing`: `Summary::Generate` line 68 (via `extraction_update_params`)
3. `summarizing` -> `awaiting_job_criteria`: `Orchestrate#check_criteria_and_score` line 72 (`update_columns(status: :awaiting_job_criteria)`)
4. `awaiting_job_criteria` -> `scoring`: `ScoreJobApplication#score` line 32 (`update_columns(status: :scoring)`)
5. `scoring` -> `integrating`: `ScoreJobApplication#score` line 99 (via `update_params`)
6. `integrating` -> `succeeded`: `IntegrateAnalysis#integrate` line 49 (via `update_params`)
7. Any -> `retrying`: `Summary::Generate` line 173, `ScoreJobApplication` line 107, `IntegrateAnalysis` line 57 (all on `CustomErrorAiSummary`)
8. Any -> `failed`: `Summary::Generate` lines 178/182, `ScoreJobApplication` lines 112/116, `IntegrateAnalysis` lines 62/66, `GenerateAiJobApplicationSummaryJob` lines 19/44

### Summary::Generate no longer sets succeeded

Spec Section 3 says `Summary::Generate` must NOT set `succeeded`. Verified: `final_update_params` at line 162 contains only `headline`, `summary_text`, `structured_data` -- no `status` key. The status remains at `summarizing` after Call 4.

### Orchestrator resume logic

All 10 statuses handled in the `case` statement:
- `pending`, `textract_processing`, `extracting`, `retrying` -> `run_summary` + `check_criteria_and_score`
- `summarizing` -> checks `summary_complete?`, then `check_criteria_and_score`
- `awaiting_job_criteria` -> `check_criteria_and_score`
- `scoring` -> checks `criteria_results.present?`, then `run_scoring` or `run_integration`
- `integrating` -> `run_integration`
- `succeeded`, `failed` -> returns (terminal)

No dead-end states. Every non-terminal status has a clear path forward.

### `retrying` status handling

`retrying` is set by `CustomErrorAiSummary` rescues and triggers a re-raise. The job's `retry_on` catches it and re-runs. On re-entry, the orchestrator sees `retrying` in the first `when` branch and re-runs the summary from scratch. Correct per spec.

## Result: PASS -- 0 findings
