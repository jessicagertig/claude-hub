# Pass 1 — parallel-coexistence

## Fact Check

### Existing pipeline unchanged
- `AiJobApplicationAction::Summary::Generate#generate` (lines 46-58): NOT modified by any plan step
- Plan's "Files to Modify" table lists only 2 files: `Gemfile` and `app/models/textract_result.rb`. No changes to `generate.rb`
- **VERIFIED**

### Separate storage
- New extraction: `TextractResult.structured_extraction` (jsonb) -- different model
- Existing extraction: `AiJobApplicationSummary.structured_data` -- different model
- No column name collision. Different tables entirely
- **VERIFIED**

### No write conflicts
- Both paths READ `textract_job_result_text` as input
- New path WRITES to `TextractResult.structured_extraction` + `structured_extraction_text`
- Existing path WRITES to `AiJobApplicationSummary.structured_data`
- No shared write target
- **VERIFIED**

### Existing callback fires normally
- `after_commit :queue_ai_summary_job, on: [:create, :update]` at line 7 -- unchanged
- New callback added alongside, does not modify or replace existing
- When both callbacks fire, they enqueue independent jobs
- **VERIFIED**

### Backward compatibility (always-on)
- **Serializer/controller exposure:** No serializer or controller references `TextractResult` columns directly. Grep confirmed no `SELECT *` risk. New columns (`structured_extraction`, `structured_extraction_text`, `textsearch_vector`) will not leak to frontend
- **PgSearch::Model inclusion:** 4 models already include `PgSearch::Model` (Candidate, Organization, Job, User). No method name or scope name collisions (`search_resume_text` is specific to TextractResult)
- **Nullable tsvector:** `textsearch_vector` is nullable (no `null: false`). When `structured_extraction_text` is NULL, the Postgres `tsvector_update_trigger()` built-in sets `textsearch_vector` to NULL. No errors
- **Existing code reading textract_results:** No serializers expose these columns. No controllers return TextractResult directly
- **VERIFIED** -- all checks pass

## Completeness

| Spec requirement | Plan step | Status |
|-----------------|-----------|--------|
| Generate#generate unchanged | -- (no steps touch it) | Present |
| Separate storage (different model+column) | 2.1, 4.1 | Present |
| Both read textract_job_result_text (no conflicts) | 4.1 | Present |
| queue_ai_summary_job still fires | 6.5 (new callback alongside) | Present |
| No data leakage via serializers | -- (verified no exposure) | Present |

## Findings

0 BLOCKER, 0 HIGH, 0 MED, 0 LOW
