# Layer 2 — Code Correctness: TextractResult Model

**File reviewed:** `app/models/textract_result.rb`

---

## Checks

### 1. Callback ordering

Two `after_commit` callbacks on `[:create, :update]`:
- `queue_ai_summary_job` (line 10)
- `queue_structured_extraction_job` (line 11)

Rails `after_commit` callbacks run in definition order and each runs independently — one raising does not prevent the other from firing. Both only enqueue Sidekiq jobs (`perform_later`), so neither blocks. **No issue.**

### 2. Callback guards

`queue_structured_extraction_job` (lines 184-188) guards on:
- `textract_job_result_text.present?`
- `saved_change_to_textract_job_result_text?`

Same guards as the existing `queue_ai_summary_job` (lines 153-154). `saved_change_to_X?` is available in `after_commit` callbacks in Rails 6.1 (ActiveRecord preserves `previous_changes` through the commit). The existing callback has worked in production for months using the identical pattern. **No issue.**

### 3. pg_search_scope correctness

- `against: :structured_extraction_text` — the column pg_search uses for `ts_headline()` highlighting
- `tsvector_column: 'textsearch_vector'` — the pre-built tsvector column used for matching

The Postgres trigger builds `textsearch_vector` FROM `structured_extraction_text`, so the two are consistent. pg_search with a `tsvector_column` option queries the pre-built vector for matching and uses the `against` column for highlighting. This is the standard pg_search pattern for pre-built tsvector columns. **No issue.**

### 4. search_resume_by_keyword edge cases

- `search_params[:search_term].presence` — `.presence` returns `nil` for `nil`, `""`, and whitespace-only strings (`"   ".presence` → `nil`). All covered.
- SQL injection: pg_search parameterizes search terms via `plainto_tsquery()` / `to_tsquery()`. The search term never appears in raw SQL. **No issue.**

### 5. has_many :ai_api_requests — dependent option

No `dependent:` is specified (line 8). Analogs (`AiJobApplicationSummary` line 6, `AiJobCriteria` line 5) also have `has_many :ai_api_requests, as: :requestable` with no `dependent:` option. This is consistent.

`TextractResult` CAN be destroyed: `JobApplication` has `has_many :textract_results, dependent: :destroy` (job_application.rb:28). Destroying a TextractResult leaves orphaned `AiApiRequest` records with a dangling `requestable_id`. However, this matches the existing pattern — destroying an `AiJobApplicationSummary` (which TextractResult does via `dependent: :destroy` on line 7) also orphans its AiApiRequests the same way. This is a pre-existing codebase-wide pattern, not a new bug. **No issue (pre-existing pattern).**

### 6. Scope collision

`include PgSearch::Model` adds: `pg_search_scope` class method, `.multisearch` class method, `.pg_search_multisearchable` class method, and `.reindex` class method. None of these collide with existing TextractResult methods. The scope name `search_resume_text` and method `search_resume_by_keyword` are unique — no other model or method in the codebase uses these names. **No issue.**

---

## Findings

None.

**VERDICT: CLEAN — 0 findings**
