# reference-fidelity -- Round 2

## Verified

- tsvector column migration: `add_column :textract_results, :textsearch_vector, :tsvector` + `add_index ... using: 'gin'` -- matches reference structure (with defensive `unless column_exists?`/`unless index_exists?` guards that the reference lacks, which is a sensible addition if the reference column already exists in the dev database)
- GIN index: same index type (`gin`), same column (`textsearch_vector`)
- Trigger: `create_trigger :tsvectorupdate, on: :textract_results` using `sql_definition:` inline (spec-directed deviation from reference's file-based SQL because `*.sql` is gitignored)
- Trigger SQL: `tsvector_update_trigger('textsearch_vector', 'pg_catalog.simple', 'structured_extraction_text')` -- only last argument changes from reference's `'textract_job_result_text'`
- Trigger migration uses `up/down` with `DROP TRIGGER IF EXISTS` before recreating -- needed because the trigger may already exist from the reference branch. Reference used `change` since it was the first implementation
- `pg_search_scope :search_resume_text` config: `dictionary: 'simple'`, `tsvector_column: 'textsearch_vector'`, `prefix: true`, highlight config (StartSel/StopSel/MaxFragments/MaxWords/MinWords/ShortWord/FragmentDelimiter), `ranked_by: ":tsearch"` -- all match reference exactly. Only `against:` changes to `:structured_extraction_text`
- `search_resume_by_keyword` class method: identical to reference (signature, guards, chain)
- `fx` gem: `gem 'fx', '~> 0.8.0'` in Gemfile, `fx (0.8.0)` resolved in Gemfile.lock -- matches reference

## Findings

No issues found.
