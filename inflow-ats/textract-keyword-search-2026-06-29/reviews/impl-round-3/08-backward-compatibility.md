# Backward Compatibility

## Verdict: PASS

### Findings

None.

### Verification

- No serializer references TextractResult — `grep -rn 'TextractResult\|textract_result' app/serializers/` returns no results. New columns (`structured_extraction`, `structured_extraction_text`, `textsearch_vector`) will not leak to the frontend.
- No controller queries TextractResult directly — `grep -rn 'TextractResult\.' app/controllers/` returns no results. Data access goes through model methods and service classes.
- Adding `include PgSearch::Model` does not conflict with existing model behavior — `search_resume_text` and `search_resume_by_keyword` are new names that don't collide with any existing method or scope on `TextractResult`.
- `textsearch_vector` column is nullable — the Postgres `tsvector_update_trigger()` built-in handles NULL `structured_extraction_text` gracefully by setting `textsearch_vector` to NULL. No error on NULL input.
- `structured_extraction` (jsonb) and `structured_extraction_text` (text) columns are both nullable with no default — they won't cause issues for existing code that creates TextractResult records without these columns.
- The new `after_commit :queue_structured_extraction_job` callback fires independently after the existing `after_commit :queue_ai_summary_job`. The existing callback runs first (declaration order in the model). If the new callback raises, the existing one has already completed successfully.
- The `queue_structured_extraction_job` callback guards on `saved_change_to_textract_job_result_text?` — it does not fire when the service writes `structured_extraction` or `structured_extraction_text`, preventing infinite callback loops.
