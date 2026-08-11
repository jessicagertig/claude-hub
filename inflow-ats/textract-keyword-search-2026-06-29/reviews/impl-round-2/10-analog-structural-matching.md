# analog-structural-matching -- Round 2

## Structural comparison

### Migration structure

| Element | Reference | Implementation | Match |
|---|---|---|---|
| Column type | `:tsvector` | `:tsvector` | SAME |
| Column default | None | None | SAME |
| Index type | `using: "gin"` | `using: 'gin'` | SAME (quote style only) |
| Defensive guards | None | `unless column_exists?` / `unless index_exists?` | DIFFERENT -- sensible addition for environments where reference migration was already applied |

### Trigger creation

| Element | Reference | Implementation | Match |
|---|---|---|---|
| API | `create_trigger :tsvectorupdate, on: :textract_results` | Same | SAME |
| SQL location | File-based (`db/triggers/tsvectorupdate_v01.sql`) | Inline `sql_definition:` | DIFFERENT -- spec-directed (`.sql` gitignored) |
| Migration method | `change` | `up/down` with `DROP TRIGGER IF EXISTS` | DIFFERENT -- needed because trigger may already exist |
| Trigger function | `tsvector_update_trigger()` (Postgres built-in) | Same | SAME |
| Dictionary | `'pg_catalog.simple'` | `'pg_catalog.simple'` | SAME |
| Source column | `'textract_job_result_text'` | `'structured_extraction_text'` | DIFFERENT -- intentional (only allowed deviation) |
| Target column | `'textsearch_vector'` | `'textsearch_vector'` | SAME |

### pg_search_scope config

| Element | Reference | Implementation | Match |
|---|---|---|---|
| `against:` | `:textract_job_result_text` | `:structured_extraction_text` | DIFFERENT -- intentional |
| `dictionary:` | `'simple'` | `'simple'` | SAME |
| `tsvector_column:` | `'textsearch_vector'` | `'textsearch_vector'` | SAME |
| `prefix:` | `true` | `true` | SAME |
| `StartSel` | `'<span class="highlight">'` | `'<span class="highlight">'` | SAME |
| `StopSel` | `'</span>'` | `'</span>'` | SAME |
| `MaxFragments` | `3` | `3` | SAME |
| `MaxWords` | `20` | `20` | SAME |
| `MinWords` | `7` | `7` | SAME |
| `ShortWord` | `3` | `3` | SAME |
| `FragmentDelimiter` | `' .... '` | `' .... '` | SAME |
| `ranked_by:` | `":tsearch"` | `":tsearch"` | SAME |

### search_resume_by_keyword

| Element | Reference | Implementation | Match |
|---|---|---|---|
| Signature | `(search_params, limit = 15)` | `(search_params, limit = 15)` | SAME |
| Guard | `search_params[:search_term].presence` / `return none` | Same | SAME |
| Chain | `.with_pg_search_rank.with_pg_search_highlight.order(...).limit(limit)` | Same | SAME |

### Backfill

Expected deviation: reference uses raw SQL `UPDATE ... SET textsearch_vector = to_tsvector(...)`. Implementation uses `ExtractStructuredResumeData` service (needs GPT-4o-mini call). Spec-approved deviation.

## Findings

No issues found. All deviations from reference are either spec-directed or are the single intentional source-column change.
