# Always-On Checks — Round 1

## Source Accuracy

### Verified correct:
- `textract_results` table in `db/schema.rb:1222` — columns match spec (textract_job_id, textract_job_status, textract_job_result, textract_job_result_text, job_application_id). No textsearch_vector/structured_extraction/structured_extraction_text yet — those are new.
- `GetResumeTextFromTextract` at `app/services/get_resume_text_from_textract.rb` with `parse_resume_text` method — confirmed.
- `TextractResult` at `app/models/textract_result.rb:7` has `after_commit :queue_ai_summary_job, on: [:create, :update]` — confirmed.
- `queue_ai_summary_job` guards on `textract_job_result_text.present?` and `saved_change_to_textract_job_result_text?` (lines 115-116) — confirmed.
- `pg_search` at 2.3.2 in Gemfile (line 125) and Gemfile.lock (resolved 2.3.2) — confirmed. Dependencies: `activerecord >= 5.2`, `activesupport >= 5.2`. Project has activerecord 6.1.7.7 — compatible. Highlight and rank features confirmed present in installed gem.
- `pg_search` already used on Candidate, Organization, Job, User — no compatibility risk adding to TextractResult.
- `fx` NOT in main Gemfile — confirmed. Reference has `gem "fx", "~> 0.8.0"`, resolved to 0.8.0. Dependencies: `activerecord >= 6.0.0`, `railties >= 6.0.0` — compatible with Rails 6.1.
- `resume_structured_data.rb` at `app/services/ai_job_application_action/summary/prompts/resume_structured_data.rb` — confirmed. Schema matches spec exactly (name, email, phone, location, links, professional_summary, stated_experience, work_experience, education, skills, certifications).
- `tsvector_update_trigger` IS a real Postgres built-in with confirmed signature `(tsvector_column_name, dictionary, source_column_name)` from reference schema.rb.
- Spec correctly identifies `parse_resume_text` success moment at line 31 (`@textract_result.update(update_textract_params)`).
- Associations on TextractResult match: `belongs_to :job_application`, `has_many :ai_job_application_summaries`.
- Enum values match: `not_started: 0`, `in_progress: 1`, `succeeded: 2`, `failed: 3`.

### Findings

- F1 [HIGH] SPEC.md lines 35-36: spec references `db/migrate/20260106002844_create_trigger_tsvectorupdate.rb` trigger migration and says to "match reference trigger pattern exactly." The `fx` gem's `create_trigger :tsvectorupdate, on: :textract_results` requires a SQL definition file at `db/triggers/tsvectorupdate_v01.sql`. This file does not exist in the reference branch's `db/` directory (no `db/triggers/` directory at all), and the spec does not mention it. Without this file the migration will fail with a file-not-found error. The spec must add:
  1. A `db/triggers/tsvectorupdate_v01.sql` file containing the trigger SQL
  2. The content: `CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE ON public.textract_results FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('textsearch_vector', 'pg_catalog.simple', 'structured_extraction_text');`

  The reference branch likely had this file when the migration ran but it wasn't committed, or the database was loaded from schema.rb which dumps the trigger inline via `sql_definition:`.

## Test Coverage

- F2 [HIGH] SPEC.md (entire document): no test section. Per pipeline Known Failure Pattern #3: "Every spec and implementation plan must state which existing tests need updating and what new test coverage is required. 'No tests' is acceptable only when explicitly documented with reasoning." The spec adds: a new service (structured extraction), a new callback or call site change, 3 new columns, a trigger, and model-level pg_search configuration. This requires:

  **Existing tests that may need updating:**
  - `spec/models/textract_result_ai_trigger_spec.rb` — tests `queue_ai_summary_job` callback. If the new extraction is added as a separate `after_commit` callback, these tests may need to stub or account for it.
  - `spec/jobs/get_resume_text_from_textract_job_spec.rb` — tests the job's `perform` method which calls `parse_resume_text`. If the new extraction is called inside `parse_resume_text`, this spec needs updating.

  **New tests needed:**
  - Service unit test: extraction call, structured_extraction storage, flattening to structured_extraction_text, error handling (API failure doesn't raise)
  - Model test: `pg_search_scope :search_resume_text` works with structured_extraction_text, `search_resume_by_keyword` returns results
  - Integration/callback test: Textract success triggers extraction service
  - Idempotency test: calling service twice on same TextractResult overwrites cleanly

## Backward Compatibility

### Verified safe:
- No serializers reference TextractResult (grep confirmed zero hits in `app/serializers/`)
- No controllers reference textract_result (grep confirmed zero hits in `app/controllers/`)
- No routes, views, or frontend code reference textract_result (grep confirmed zero hits)
- TextractResult is consumed only internally (model callbacks, jobs, services)
- Adding `include PgSearch::Model` is safe — already on 4 other models
- New columns are nullable — existing records unaffected
- `textsearch_vector` column nullable — trigger sets to NULL when source is NULL

No findings.

## Full-Stack Analog Completeness

### Verified:
- Reference has: migration (tsvector + GIN), migration (fx trigger), backfill (data migration), model (pg_search_scope + search method), controller, serializer
- Spec explicitly marks controller and serializer OUT OF SCOPE — documented
- All IN-SCOPE layers covered: migrations (spec lines 150-154), service (lines 157-162), model (lines 170-171), backfill (lines 174-176)
- `pg_search_scope` and `search_resume_by_keyword` are in scope — needed for backfill verification and future controller work

No findings.

## Analog Structural Matching

### Verified matches:
- Migration: `add_column :textract_results, :textsearch_vector, :tsvector` + `add_index ... using: "gin"` — spec line 152-153 describes same pattern
- Trigger: `create_trigger :tsvectorupdate, on: :textract_results` — spec line 153-154 matches
- Trigger SQL: `tsvector_update_trigger('textsearch_vector', 'pg_catalog.simple', ...)` with only last arg changed — spec lines 42-49 correct
- `pg_search_scope` config: `against:`, `tsvector_column:`, `dictionary:`, `prefix:`, `highlight:`, `ranked_by:` — spec lines 53-82 match reference exactly, changing only `against:` to `:structured_extraction_text`
- `search_resume_by_keyword` method: `search_params[:search_term].presence`, `search_resume_text`, `with_pg_search_rank`, `with_pg_search_highlight`, `order(Arel.sql('pg_search_rank DESC'))`, `.limit(limit)` — spec lines 74-82 match reference
- Backfill: expected deviation (API call vs raw SQL) documented at spec lines 176

### Findings

- F3 [MED] SPEC.md lines 150-154: the spec describes 4 migration steps but doesn't mention the `db/triggers/tsvectorupdate_v01.sql` file as a required artifact alongside the migrations. This is the same gap as F1 but from the structural matching angle — the reference pattern uses `fx` which requires a SQL definition file. The migration list should include "Create `db/triggers/tsvectorupdate_v01.sql` with trigger SQL" as a prerequisite for migration #4.

(F3 is a sub-finding of F1 from a different angle — the amendment for F1 covers both.)

## Amendments Applied

Amendments deferred to the parent agent's spec editing pass.

## Summary

| Severity | Count |
|----------|-------|
| BLOCKER  | 0     |
| HIGH     | 2     |
| MED      | 1     |
