# parallel-coexistence -- Round 1

## Findings

No issues found.

## Verified

- **AI summary pipeline unchanged**: `AiJobApplicationAction::Summary::Generate#generate` was NOT modified in this branch (not in the diff). The existing Call 1 extraction (lines 46-58) still runs, still stores on `AiJobApplicationSummary.structured_data`.

- **Separate storage**: New extraction stores on `TextractResult.structured_extraction` (jsonb column on `textract_results` table). Existing extraction stores on `AiJobApplicationSummary.structured_data` (jsonb column on `ai_job_application_summaries` table). Completely separate models and tables -- no write conflicts possible.

- **Both read same input**: Both the new service and the existing pipeline read `textract_job_result_text` as input. This is a read-only operation on both sides -- no write conflicts.

- **Callback independence**: `queue_ai_summary_job` and `queue_structured_extraction_job` are separate `after_commit` callbacks. They fire independently after the same commit. The new callback does not modify any state that `queue_ai_summary_job` reads or depends on.

- **Separate error domains**: The new service raises `CustomErrorStructuredExtraction`. The existing pipeline raises `CustomErrorAiSummary`. The new job retries on `CustomErrorStructuredExtraction`. The existing `GenerateAiJobApplicationSummaryJob` retries on `CustomErrorAiSummary`. No cross-contamination between error types -- the re-raise in `ExtractStructuredResumeData` (CustomErrorAiSummary -> CustomErrorStructuredExtraction) ensures this.

- **Separate AiApiRequest tracking**: New extraction uses `call_type: 'keyword_extraction'` with `requestable: textract_result`. Existing pipeline uses `call_type: 'extraction'` with `requestable: ai_summary`. Distinct call_type values and different requestable types prevent confusion in cost auditing.
