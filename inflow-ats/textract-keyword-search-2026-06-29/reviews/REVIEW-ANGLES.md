# Review Angles — Textract Keyword Search

Generated from: SPEC.md
Date: 2026-06-29

## Subsystems touched

- `textract_results` table — 3 new columns (`structured_extraction` jsonb, `structured_extraction_text` text, `textsearch_vector` tsvector)
- `TextractResult` model (`app/models/textract_result.rb`) — `pg_search_scope` addition
- New service — structured data extraction (calls GPT-4o-mini)
- `GetResumeTextFromTextract` (`app/services/get_resume_text_from_textract.rb`) — call site for new service
- Postgres trigger via `fx` gem — auto-updates tsvector on text column change
- `Gemfile` — add `fx` gem (pg_search already present)
- 4 schema migrations + 1 data migration (backfill)

## Full-stack analog

**Reference implementation:** `keyword-search-connect-version` worktree at `~/wrk/wrk-corp/inflow-ats.keyword-search-connect-version/`

This is a direct predecessor, not a pattern analog. The new feature reuses its migration structure, trigger approach, model config, and gem setup, changing only the source column (from raw `textract_job_result_text` to cleaned `structured_extraction_text`).

Reference files:
- Migration: `db/migrate/20260106002106_add_textsearch_vector_to_textract_results.rb` — tsvector column + GIN index
- Migration: `db/migrate/20260106002844_create_trigger_tsvectorupdate.rb` — fx trigger creation
- Backfill: `db/data/20260106200000_backfill_textract_tsvector.rb` — raw SQL backfill
- Model: `app/models/textract_result.rb` — `pg_search_scope :search_resume_text` with simple dictionary, prefix, highlight
- Trigger SQL: `tsvector_update_trigger('textsearch_vector', 'pg_catalog.simple', 'textract_job_result_text')` — built-in Postgres function, NOT custom PL/pgSQL
- Controller: `app/controllers/api/v1/connect_members_search_controller.rb` — `resume_search` action (out of scope but shows consumption pattern)
- Serializer: `app/serializers/api/v1/resume_search_result_serializer.rb` (out of scope)
- Gems: `pg_search` 2.3.2, `fx` ~> 0.8.0

**Extraction analog:** `app/services/ai_job_application_action/summary/prompts/resume_structured_data.rb` — the existing GPT-4o-mini extraction prompt/schema. The new service reuses this prompt and schema, called at a different point in the pipeline.

**Priority rule:** Where the reference implementation deviates from convention, the reference wins. The only intentional deviation from the reference is the source column change (`textract_job_result_text` → `structured_extraction_text`).

## Angles

### 1. reference-fidelity

**What this covers:** Does every migration, trigger, model config, and gem version match the reference implementation? Deviations only where the structured-extraction source column requires them.

**Specific checks:**
- tsvector column migration matches reference structure (column type, no default)
- GIN index migration matches reference (same index type, same column)
- `create_trigger` call matches reference (same trigger name, same table, `fx` gem pattern)
- Trigger SQL uses `tsvector_update_trigger()` built-in Postgres function (NOT custom PL/pgSQL), with `'pg_catalog.simple'` dictionary — only the source column name changes
- `pg_search_scope` config matches reference: `against:` points to text column, `tsvector_column:` points to tsvector column, same `dictionary`, `prefix`, `highlight`, `ranked_by` settings
- `search_resume_by_keyword` class method matches reference signature and behavior
- `fx` gem version matches reference (~> 0.8.0)

**Files across all layers:**
- All new migrations
- `app/models/textract_result.rb`
- `Gemfile`

**Analog files for comparison:**
- `~/wrk/wrk-corp/inflow-ats.keyword-search-connect-version/db/migrate/20260106002106_add_textsearch_vector_to_textract_results.rb`
- `~/wrk/wrk-corp/inflow-ats.keyword-search-connect-version/db/migrate/20260106002844_create_trigger_tsvectorupdate.rb`
- `~/wrk/wrk-corp/inflow-ats.keyword-search-connect-version/db/data/20260106200000_backfill_textract_tsvector.rb`
- `~/wrk/wrk-corp/inflow-ats.keyword-search-connect-version/app/models/textract_result.rb`
- `~/wrk/wrk-corp/inflow-ats.keyword-search-connect-version/Gemfile`

**Convention context:** `cursor_rules/core_critical_rules.md`

### 2. extraction-service

**What this covers:** New service that calls GPT-4o-mini to extract structured data from resume text. Prompt, schema, error handling, storage, and flattening logic.

**Specific checks:**
- Prompt and JSON schema match existing extraction at `app/services/ai_job_application_action/summary/prompts/resume_structured_data.rb` (same system prompt, same response schema, same model)
- Service stores structured result in `structured_extraction` (jsonb) on TextractResult
- Service flattens structured data into `structured_extraction_text` (text) — verify flattening produces searchable text (all fields concatenated, no JSON syntax in output)
- Error handling: API failure must NOT prevent Textract success from completing. Extraction is supplementary — a failed extraction should not break the Textract pipeline
- Idempotency: calling the service again on the same TextractResult should overwrite cleanly, not duplicate or error

**Files across all layers:**
- New service file (wherever created)
- `app/services/ai_job_application_action/summary/prompts/resume_structured_data.rb` (existing prompt to match)
- `app/services/ai_job_application_action/summary/generate.rb` (existing extraction call at lines 46-58)
- `app/models/textract_result.rb`

**Convention context:** `cursor_rules/core_critical_rules.md`, `cursor_rules/backend/services_and_interactors.md` (if exists)

### 3. textract-call-site

**What this covers:** Where and how the new extraction service gets called when Textract succeeds.

**Specific checks:**
- Call site is in `GetResumeTextFromTextract#parse_resume_text` (lines 24-37) or via an `after_commit` callback on TextractResult — either way, verify it fires on Textract success
- Failure isolation: if the extraction service raises (API timeout, bad response, rate limit), the Textract success path must still complete. The `textract_job_result_text` update and existing `queue_ai_summary_job` callback must not be blocked
- Ordering: extraction call happens AFTER `textract_job_result_text` is persisted (it needs that text as input)
- No interference with existing `after_commit :queue_ai_summary_job` callback — both should fire independently

**Files across all layers:**
- `app/services/get_resume_text_from_textract.rb` (lines 24-37 — the success handler)
- `app/models/textract_result.rb` (lines 7, 114-143 — existing callback)
- `app/jobs/get_resume_text_from_textract_job.rb`

**Convention context:** `cursor_rules/core_critical_rules.md`

### 4. backfill-data-migration

**What this covers:** Data migration that backfills `structured_extraction` and `structured_extraction_text` for existing succeeded TextractResults.

**Specific checks:**
- Scoping: only `textract_job_status = succeeded` AND `structured_extraction IS NULL` — skips already-processed records
- Rate limiting: each record makes a GPT-4o-mini API call. Verify batching and delay between calls
- Resumability: if the migration fails mid-run (API error, timeout), re-running should pick up where it left off (the `IS NULL` guard handles this)
- Backfill uses the same service as the real-time path (not a separate extraction implementation)
- Compare against reference backfill pattern (`db/data/20260106200000_backfill_textract_tsvector.rb`) — reference uses raw SQL UPDATE, but the new backfill MUST call the service (not raw SQL) because it needs the GPT-4o-mini extraction step

**Files across all layers:**
- New data migration file
- Reference: `~/wrk/wrk-corp/inflow-ats.keyword-search-connect-version/db/data/20260106200000_backfill_textract_tsvector.rb`

### 5. parallel-coexistence

**What this covers:** Existing AI summary pipeline continues unchanged. No interference between old and new extraction paths.

**Specific checks:**
- `AiJobApplicationAction::Summary::Generate#generate` (lines 46-58) is NOT modified — the existing Call 1 extraction still runs, still stores on `AiJobApplicationSummary.structured_data`
- New extraction stores on `TextractResult.structured_extraction` — completely separate column on a different model
- Both read `textract_job_result_text` as input — verify no write conflicts (both are read-only consumers of this column)
- `after_commit :queue_ai_summary_job` callback still fires normally after the new service runs

**Files across all layers:**
- `app/services/ai_job_application_action/summary/generate.rb`
- `app/models/textract_result.rb`
- New service file

## Always-on checks

These apply regardless of angles. Each check has specific verification steps — reviewers must complete ALL steps, not just confirm "looks right."

### Source accuracy

Every file path, class name, method name, column name, and gem version the spec references must be verified against the current source on the branch being reviewed.

**Specific verifications:**
- `textract_results` table exists in `db/schema.rb` with the columns listed in the spec
- `GetResumeTextFromTextract` class exists at the path referenced, with `parse_resume_text` method
- `TextractResult` model has `after_commit :queue_ai_summary_job` callback
- `pg_search` gem version in Gemfile — verify 2.3.2 is correct and compatible. **NOTE:** Jessica flagged that the pg_search version may need to change from 2.3.2. The reviewer MUST check: (a) does 2.3.2 work with the current Ruby/Rails/PG versions in this project? (b) is there a newer version that fixes bugs or adds features needed for this use case? (c) does the reference branch's 2.3.2 actually work, or was it pinned before an upgrade? Check `Gemfile.lock` for the resolved version.
- `fx` gem at ~> 0.8.0 — verify compatibility with Rails 6.1+
- `resume_structured_data.rb` prompt file exists at the path referenced with the schema described
- `tsvector_update_trigger` is a real Postgres built-in function (it is — but verify the argument signature: `(tsvector_column_name, dictionary, source_column_name)`)

### Test coverage

**Specific verifications:**
- Does the spec require tests? If not, flag as HIGH — new service + new migrations + new callback = mandatory test coverage
- What existing tests cover `TextractResult`, `GetResumeTextFromTextract`, and the AI summary pipeline? List them
- What new tests are needed: service unit test (extraction + flattening), callback/integration test (Textract success triggers extraction), model test (pg_search_scope works)
- Are there existing pg_search tests on the reference branch? Check `~/wrk/wrk-corp/inflow-ats.keyword-search-connect-version/spec/` for TextractResult specs

### Backward compatibility

**Specific verifications:**
- Adding columns to `textract_results` — verify no serializer, API endpoint, or frontend query returns `SELECT *` from this table (new columns could leak to the frontend)
- Adding `include PgSearch::Model` to TextractResult — verify this doesn't conflict with existing model behavior (method name collisions, scope name collisions)
- The `textsearch_vector` column is nullable — verify the trigger handles NULL `structured_extraction_text` gracefully (should set vector to NULL, not error)
- Existing code that reads `textract_results` (serializers, controllers, API responses) — verify new columns don't appear in responses unless explicitly serialized

### Full-stack analog completeness

The reference implementation has: migration (tsvector + GIN), migration (fx trigger), backfill (data migration), model (pg_search_scope + search method), controller (search endpoint), serializer (search results).

The spec explicitly puts controller and serializer OUT OF SCOPE. Verify:
- Every IN-SCOPE reference layer has a corresponding piece in the implementation
- The model's `pg_search_scope` and `search_resume_by_keyword` method are implemented even though the controller isn't — they're needed for the backfill verification and future controller work

### Analog structural matching

**Specific verifications (diff against reference):**
- Migration structure: reference `add_column :textract_results, :textsearch_vector, :tsvector` + `add_index ... using: "gin"` — implementation must match this exact pattern
- Trigger creation: reference `create_trigger :tsvectorupdate, on: :textract_results` — implementation must use the same `fx` API, not raw SQL
- Trigger SQL: reference uses `tsvector_update_trigger('textsearch_vector', 'pg_catalog.simple', 'textract_job_result_text')` — implementation changes ONLY the last argument to `'structured_extraction_text'`
- `pg_search_scope` config: reference has `against: :textract_job_result_text`, `tsvector_column: 'textsearch_vector'`, `dictionary: 'simple'`, `prefix: true`, highlight config with specific `StartSel`/`StopSel`/`MaxFragments`/`MaxWords`/`MinWords`/`ShortWord`/`FragmentDelimiter` — implementation changes ONLY `against:` to `:structured_extraction_text`
- Backfill: reference uses raw SQL `UPDATE ... SET textsearch_vector = to_tsvector(...)`. New backfill CANNOT use raw SQL (needs GPT-4o-mini call). This is an EXPECTED deviation — the reviewer must not flag it as a mismatch. The tsvector update happens automatically via the trigger when `structured_extraction_text` is written by the service.

**Any deviation not listed above is a BLOCKER** unless the implementation documents why the reference pattern cannot apply.
