# async-timing-and-race-conditions — Round 2

## Findings

Re-verified async ordering and race conditions. No new findings beyond Round 1.

Specifically re-checked:
- Change 1 runs synchronously inside `submit_resume` BEFORE `GetResumeTextFromTextractJob` is enqueued (line 27). No race.
- `queue_ai_summary_job` callback fires on TextractResult `update` commit (after `GetResumeTextFromTextract` updates `textract_job_result_text`). By this time, Change 1 has already set `textract_result_id` on the summary. The callback at line 102 finds the summary by `status: :textract_processing, stale: false` — it does NOT filter by `textract_result_id`. So even if Change 1 somehow failed, the callback would still find the summary. Belt and suspenders.
- Double-click: `CreateAiSummaryGeneration` lines 30-38 check for active summary and return early. No duplicate creation.

No issues found.

## Amendments Applied

None.
