# analog-structural-matching -- Round 1

## Findings

No issues found.

## Verified structural comparison (reference vs implementation)

### Migration structure

**Reference (`20260106002106`):**
```ruby
def change
  add_column :textract_results, :textsearch_vector, :tsvector
  add_index :textract_results, :textsearch_vector, using: "gin"
end
```

**Implementation (`20260630050053`):**
```ruby
def change
  add_column :textract_results, :textsearch_vector, :tsvector unless column_exists?(:textract_results, :textsearch_vector)
  add_index :textract_results, :textsearch_vector, using: 'gin' unless index_exists?(:textract_results, :textsearch_vector)
end
```

Structural match: SAME (column type, index type, column name). Deviations: idempotency guards (defensive), single quotes on 'gin' (cursor_rules style). Neither changes behavior.

### Trigger creation

**Reference (`20260106002844`):**
```ruby
def change
  create_trigger :tsvectorupdate, on: :textract_results
end
```

**Implementation (`20260630050054`):**
```ruby
def up
  execute 'DROP TRIGGER IF EXISTS tsvectorupdate ON textract_results'
  create_trigger :tsvectorupdate, on: :textract_results, sql_definition: <<-SQL
    ... tsvector_update_trigger('textsearch_vector', 'pg_catalog.simple', 'structured_extraction_text')
  SQL
end
def down
  execute 'DROP TRIGGER IF EXISTS tsvectorupdate ON textract_results'
  create_trigger :tsvectorupdate, on: :textract_results, sql_definition: <<-SQL
    ... tsvector_update_trigger('textsearch_vector', 'pg_catalog.simple', 'textract_job_result_text')
  SQL
end
```

Structural match: SAME trigger name, table, and fx API. Deviation: uses `sql_definition:` inline (per spec -- `*.sql` is gitignored) and `def up/down` for reversibility. The reference used file-based trigger SQL; the implementation uses inline SQL. This is a spec-documented deviation.

### Trigger SQL

**Reference:** `tsvector_update_trigger('textsearch_vector', 'pg_catalog.simple', 'textract_job_result_text')`
**Implementation:** `tsvector_update_trigger('textsearch_vector', 'pg_catalog.simple', 'structured_extraction_text')`

Structural match: SAME built-in function, same tsvector column, same dictionary. Only the source column name changes. This is the single intentional deviation per spec.

### pg_search_scope config

| Setting | Reference | Implementation | Match |
|---|---|---|---|
| against: | :textract_job_result_text | :structured_extraction_text | DIFFERENT (intentional) |
| dictionary: | 'simple' | 'simple' | SAME |
| tsvector_column: | 'textsearch_vector' | 'textsearch_vector' | SAME |
| prefix: | true | true | SAME |
| StartSel: | '<span class="highlight">' | '<span class="highlight">' | SAME |
| StopSel: | '</span>' | '</span>' | SAME |
| MaxFragments: | 3 | 3 | SAME |
| MaxWords: | 20 | 20 | SAME |
| MinWords: | 7 | 7 | SAME |
| ShortWord: | 3 | 3 | SAME |
| FragmentDelimiter: | ' .... ' | ' .... ' | SAME |
| ranked_by: | ":tsearch" | ":tsearch" | SAME |

Only `against:` changed, as specified.

### search_resume_by_keyword

| Element | Reference | Implementation | Match |
|---|---|---|---|
| Method signature | `(search_params, limit = 15)` | `(search_params, limit = 15)` | SAME |
| Guard | `search_params[:search_term].presence` | `search_params[:search_term].presence` | SAME |
| Return on no term | `none` | `none` | SAME |
| Query chain | `.with_pg_search_rank.with_pg_search_highlight.order(Arel.sql('pg_search_rank DESC')).limit(limit)` | identical | SAME |

### Backfill

**Reference:** Raw SQL `UPDATE textract_results SET textsearch_vector = to_tsvector('simple', textract_job_result_text) WHERE textract_job_result_text IS NOT NULL AND textsearch_vector IS NULL`

**Implementation:** Job-based, iterates with `find_each`, calls `ExtractStructuredResumeData` service per record.

This is an EXPECTED deviation documented in the spec: the new backfill needs the GPT-4o-mini extraction step (cannot be done with raw SQL). The tsvector update happens automatically via the trigger when `structured_extraction_text` is written.
