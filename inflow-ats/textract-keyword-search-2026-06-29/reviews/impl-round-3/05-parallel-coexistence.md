# Parallel Coexistence

## Verdict: PASS

### Findings

None.

### Verification

- `generate.rb` is NOT modified on the branch — verified via `git diff develop -- app/services/ai_job_application_action/summary/generate.rb` (empty diff). Existing Call 1 extraction at lines 46-58 still runs, still stores on `AiJobApplicationSummary.structured_data`.
- New extraction stores on `TextractResult.structured_extraction` — completely separate column on a different model. No overlap.
- Both paths read `textract_job_result_text` as input — no write conflicts (both are read-only consumers of this column).
- `after_commit :queue_ai_summary_job` still fires normally — it is declared first in the callback chain and runs before `queue_structured_extraction_job`.
- The service's `update` call writes `structured_extraction` and `structured_extraction_text`, which does NOT trigger the `queue_ai_summary_job` callback because `saved_change_to_textract_job_result_text?` returns false for columns other than `textract_job_result_text`.
- `get_resume_text_from_textract.rb` is also NOT modified — verified via `git diff develop` (empty diff). The Textract success path (`parse_resume_text`) is completely untouched.
- The new `AiApiRequest` records use `call_type: 'keyword_extraction'` — distinct from the summary pipeline's `'extraction'` call type. No confusion in cost auditing.
- The new `CustomErrorStructuredExtraction` error class is distinct from `CustomErrorAiSummary` — the extraction job's `retry_on` does not interfere with the summary job's `retry_on`.
