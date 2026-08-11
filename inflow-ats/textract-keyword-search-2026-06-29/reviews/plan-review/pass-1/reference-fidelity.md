# Pass 1 — reference-fidelity

## Fact Check

### tsvector column migration (plan step 2.2)
- Plan: `add_column :textract_results, :textsearch_vector, :tsvector` + `add_index :textract_results, :textsearch_vector, using: "gin"`
- Reference (`20260106002106_add_textsearch_vector_to_textract_results.rb`): identical structure
- **VERIFIED** -- exact match

### Trigger migration (plan step 2.3)
- Plan: `create_trigger :tsvectorupdate, on: :textract_results, sql_definition: <<-SQL`
- Reference (`20260106002844_create_trigger_tsvectorupdate.rb`): `create_trigger :tsvectorupdate, on: :textract_results` (bare, loads from `db/triggers/tsvectorupdate_v01.sql`)
- **INTENTIONAL DEVIATION** -- `*.sql` is gitignored (`.gitignore` line 43). Plan uses `sql_definition:` inline. Spec documents this decision. fx 0.8.0 supports `sql_definition:` (confirmed via Gemfile.lock in reference branch: `fx (0.8.0)` with `activerecord (>= 6.0.0)`)

### Trigger SQL (plan step 2.3)
- Plan: `tsvector_update_trigger('textsearch_vector', 'pg_catalog.simple', 'structured_extraction_text')`
- Reference: `tsvector_update_trigger('textsearch_vector', 'pg_catalog.simple', 'textract_job_result_text')`
- **VERIFIED** -- only last argument changed (source column). Built-in Postgres function, not custom PL/pgSQL

### pg_search_scope (plan step 6.3)
- Plan matches reference exactly: `dictionary: 'simple'`, `tsvector_column: 'textsearch_vector'`, `prefix: true`, highlight config with `StartSel`/`StopSel`/`MaxFragments: 3`/`MaxWords: 20`/`MinWords: 7`/`ShortWord: 3`/`FragmentDelimiter: ' .... '`, `ranked_by: ":tsearch"`
- Only `against:` changed from `:textract_job_result_text` to `:structured_extraction_text`
- **VERIFIED** -- read reference `textract_result.rb` lines 15-33

### search_resume_by_keyword (plan step 6.4)
- Plan matches reference exactly: `search_params[:search_term].presence`, `return none`, `.with_pg_search_rank`, `.with_pg_search_highlight`, `.order(Arel.sql('pg_search_rank DESC'))`, `.limit(limit)`, default limit 15
- **VERIFIED** -- read reference `textract_result.rb` lines 38-47

### fx gem version (plan step 1.1)
- Plan: `gem "fx", "~> 0.8.0"`
- Reference Gemfile line 162: `gem "fx", "~> 0.8.0"`
- Main Gemfile: no fx gem (grep confirmed)
- **VERIFIED** -- version matches, needs adding

### pg_search gem (no change)
- Main Gemfile line 125: `gem 'pg_search', '2.3.2'`
- Reference Gemfile line 122: `gem 'pg_search', '2.3.2'`
- Already used by 4 models (Candidate, Organization, Job, User)
- Plan correctly does not modify. Compatible with Ruby 3.1 / Rails 6.1
- **VERIFIED**

## Completeness

| Spec requirement | Plan step | Status |
|-----------------|-----------|--------|
| tsvector column | 2.2 | Present |
| GIN index | 2.2 | Present |
| fx trigger | 2.3 | Present |
| Trigger uses built-in Postgres function | 2.3 | Present |
| pg_search_scope matches reference (only against: changes) | 6.3 | Present |
| search_resume_by_keyword matches reference | 6.4 | Present |
| fx gem ~> 0.8.0 added | 1.1 | Present |
| pg_search 2.3.2 unchanged | -- | Present |

## Full-stack analog completeness (always-on)

Reference has: migration (tsvector+GIN), migration (fx trigger), backfill, model (pg_search_scope + search method), controller, serializer.

Controller and serializer are explicitly OUT OF SCOPE per spec. All in-scope layers have corresponding plan steps:
- Migration (tsvector+GIN): step 2.2
- Migration (fx trigger): step 2.3
- Backfill: steps 7.1-7.2
- Model (pg_search_scope + search method): steps 6.1, 6.3, 6.4

## Analog structural matching (always-on)

| Reference pattern | Plan implementation | Match? |
|------------------|-------------------|--------|
| `add_column :textract_results, :textsearch_vector, :tsvector` | Step 2.2: identical | SAME |
| `add_index :textract_results, :textsearch_vector, using: "gin"` | Step 2.2: identical | SAME |
| `create_trigger :tsvectorupdate, on: :textract_results` | Step 2.3: adds `sql_definition:` | DOCUMENTED DEVIATION (gitignore) |
| Trigger SQL: only source column changes | Step 2.3: `structured_extraction_text` | SAME (expected change) |
| `pg_search_scope` config: all keys/values | Step 6.3: only `against:` changes | SAME (expected change) |
| `search_resume_by_keyword`: full method | Step 6.4: identical | SAME |
| Backfill uses raw SQL | Steps 7.1-7.2: uses service | EXPECTED DEVIATION (needs GPT-4o-mini) |

No undocumented deviations found.

## Findings

0 BLOCKER, 0 HIGH, 0 MED, 0 LOW
