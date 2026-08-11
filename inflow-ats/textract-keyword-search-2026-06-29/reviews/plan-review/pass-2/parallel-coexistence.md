# Pass 2 — parallel-coexistence

## Pass 1 corrections
None needed. Pass 1 found 0 findings.

## Fresh scrutiny

### Dual extraction paths: data consistency
- Existing path (AI summary pipeline): `generate.rb:46-58` calls GPT-4o-mini with the same prompt, stores result on `AiJobApplicationSummary.structured_data`
- New path (Textract completion): `ExtractStructuredResumeData` calls GPT-4o-mini with the same prompt, stores result on `TextractResult.structured_extraction`
- Both use the same `ResumeStructuredData.messages(resume_text:, job_title:)` prompt class
- LLM outputs may differ between calls (non-deterministic), but the prompt and schema are identical
- No consistency requirement between the two stored values — they serve different purposes (summary pipeline vs search index)
- **Acceptable**

### Timing: both paths can run concurrently
- `after_commit :queue_ai_summary_job` enqueues `GenerateAiJobApplicationSummaryJob`
- `after_commit :queue_structured_extraction_job` enqueues `ExtractStructuredResumeDataJob`
- Both jobs run in the `:default` Sidekiq queue
- Both make independent GPT-4o-mini API calls
- No shared state between the two jobs (different models, different columns)
- If both run simultaneously, no conflict — they write to different records/columns
- **Correct**

### Additional AI API cost
- Each Textract success now triggers TWO GPT-4o-mini calls (extraction job + summary pipeline Call 1)
- Both use the same prompt (same token count per call)
- This doubles the Call 1 cost per resume
- The spec says "Once the new Textract-level extraction is stable and backfilled, remove the duplicate call from the summary pipeline"
- **By design** — temporary redundancy during transition period

### No model-level conflicts from PgSearch inclusion
- Adding `include PgSearch::Model` to TextractResult
- PgSearch defines class methods: `pg_search_scope`, `multisearchable`
- The scope name `search_resume_text` is unique to TextractResult — no collision with other models' scopes
- PgSearch methods are module-level, not instance-level — no conflict with existing instance methods on TextractResult
- **Verified** — no method name collisions

## Completeness sweep

All spec requirements for parallel coexistence verified:
- Existing pipeline unchanged: no plan steps touch generate.rb
- Separate storage: different model + different column
- No write conflicts: both read textract_job_result_text, write to different targets
- Both callbacks fire independently: step 6.5

## Findings

0 BLOCKER, 0 HIGH, 0 MED, 0 LOW
