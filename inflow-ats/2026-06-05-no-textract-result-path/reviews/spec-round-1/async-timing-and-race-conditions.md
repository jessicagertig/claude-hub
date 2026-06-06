# async-timing-and-race-conditions — Round 1

## Findings

- F1 [MED] If `SubmitResumeToTextract#submit_resume` fails at the AWS call (line 16: `parser.send_to_textract`) before building the TextractResult, no TextractResult is created and Change 1 never runs. The `textract_processing` summary created by `CreateAiSummaryGeneration` is orphaned with nil `textract_result_id` — stuck forever. Change 2 only handles `GetResumeTextFromTextractJob` exhaustion (Textract polling failures), not `SubmitResumeToTextract` failure (initial submission failures). This gap is OUTSIDE the 3 spec changes and is a pre-existing gap in the overall design, so MED per scope rules.

- F2 [INFO] Ordering verification: Change 1 runs synchronously inside `submit_resume` at line 24 (inside `if @textract_result.save`). `GetResumeTextFromTextractJob` is enqueued at line 27 with a 2-minute delay. When Textract completes and `GetResumeTextFromTextract` updates the TextractResult, the `queue_ai_summary_job` callback fires. By that time, Change 1 has already set `textract_result_id`. No race condition between Change 1 and `queue_ai_summary_job`. Verified safe.

- F3 [INFO] Double-click protection: If the user clicks "generate" again while `textract_processing`, `CreateAiSummaryGeneration` at line 30-34 finds the existing active summary (non-failed, non-stale) and returns it. No duplicate summary created. Safe.

## Amendments Applied

None.
