# backward-compatibility -- Round 4

## Scope

All consumers of modified code addressed. Every reference to status enum values verified.

## Findings

### Status enum value migration

Old values removed: `in_progress` (was 1), `extracted` (was 4). Grep for `status: :in_progress` and `status: :extracted` across all `*.rb` files in `app/`:

- Zero references to `status: :in_progress` on `AiJobApplicationSummary` found.
- Zero references to `status: :extracted` on `AiJobApplicationSummary` found.
- `status: :in_progress` appears for `AiJobCriteria` (its own separate enum) and `textract_job_status: :in_progress` (TextractResult, separate enum). Both are correct -- different models.

### Integer value shifts

`succeeded` moved from 2 to 7, `failed` from 3 to 9, `textract_processing` from 6 to 1. Since the feature is not in production/staging, existing dev data will have incorrect integer mappings. This is acceptable per spec Section 3. All code uses symbols (`:succeeded`, `:failed`, etc.), not raw integers.

### Summary::Generate consumers

`Summary::Generate` is called only from `Orchestrate#run_summary`. The orchestrator passes `textract_result_id:` and calls `.generate`. No external consumers affected.

### TextractResult#generate_ai_summary consumers

Now private. Only called from `generate_ai_summary_with_credit_flow` (same class, line 70). No external callers. Verified with grep.

### AiJobApplicationSummary status consumers

Complete list (verified by grep):
1. `destroy_previous_textract_results` -- uses `status_succeeded?`. Still correct (full pipeline = safe to clean up old textract results).
2. `update_summary_status_record` -- uses `status_succeeded?`. Still correct (updates read model after full pipeline).
3. `create_status_record` -- `after_commit on: :create`. Not status-dependent. Unaffected.
4. `TextractResult#generate_ai_summary_with_credit_flow` -- `status_succeeded?`. Credit consumption at terminal state. Correct.
5. `GenerateAiJobApplicationSummaryJob` -- `status_succeeded?` in broadcast. Correct.
6. `BulkGenerateAiSummariesJob` -- `status: %i[succeeded failed]` and `status: :succeeded`. Guard and count queries. Correct with new values.
7. `CreateAiSummaryGeneration` -- `where.not(status: :failed)`, `status: :textract_processing`, `status: :pending`. All symbol names unchanged.
8. `SubmitResumeToTextract` -- `status: :textract_processing`. Symbol name unchanged.
9. `GetResumeTextFromTextractJob` -- `status: :textract_processing`. Symbol name unchanged.
10. `ValidateAiSummaryGeneration` -- references `textract_job_status_failed?` on TextractResult, not AiJobApplicationSummary status. Unaffected.

All consumers accounted for. No references to removed enum values.

## Result: PASS -- 0 findings
