# Parallel Coexistence — Round 1

## Verified

1. **Summary pipeline NOT modified.** Spec lines 182-186 explicitly list "Changes to the AI summary pipeline" as out of scope. `AiJobApplicationAction::Summary::Generate#generate` (lines 46-58) continues unchanged — reads `textract_job_result_text`, stores on `AiJobApplicationSummary.structured_data`.

2. **No write conflicts.** Both paths read `textract_job_result_text` (read-only). New extraction writes to `TextractResult.structured_extraction` + `TextractResult.structured_extraction_text`. Existing pipeline writes to `AiJobApplicationSummary.structured_data`. Different columns on different models — no contention.

3. **`after_commit :queue_ai_summary_job` still fires independently.** The callback guards on `saved_change_to_textract_job_result_text?` (model line 116). When the new service later updates `structured_extraction`/`structured_extraction_text` on the same TextractResult, that triggers `after_commit` again, but the guard returns early because `textract_job_result_text` hasn't changed. No double-fire of the AI summary job.

4. **No race condition.** Both the new extraction and the summary pipeline make independent GPT-4o-mini calls using the same input text. They store results on different models/columns. No shared mutable state, no ordering dependency between the two API calls.

5. **Duplicate API cost acknowledged.** Spec line 180: "Both paths read `textract_job_result_text` — no write conflicts." Spec line 180: "Once the new Textract-level extraction is stable and backfilled, remove the duplicate call from the summary pipeline." The parallel period is intentional.

## Findings

No issues found.

## Amendments Applied

None.
