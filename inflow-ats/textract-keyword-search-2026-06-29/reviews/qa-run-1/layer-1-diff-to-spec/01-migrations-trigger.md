# Layer 1 — Migrations + Trigger

**Reviewer focus:** Migrations (3 schema + 1 data) and Postgres trigger  
**Files reviewed:**
- `db/migrate/20260630050052_add_structured_extraction_columns_to_textract_results.rb`
- `db/migrate/20260630050053_add_textsearch_vector_to_textract_results.rb`
- `db/migrate/20260630050054_create_trigger_tsvectorupdate.rb`
- `db/data/20260630050055_enqueue_structured_extraction_backfill.rb`

**Reference files compared:**
- `inflow-ats.keyword-search-connect-version/db/migrate/20260106002106_add_textsearch_vector_to_textract_results.rb`
- `inflow-ats.keyword-search-connect-version/db/migrate/20260106002844_create_trigger_tsvectorupdate.rb`
- `inflow-ats.keyword-search-connect-version/db/data/20260106200000_backfill_textract_tsvector.rb`

---

## Findings

```
FINDING-ID: L1-MT-1
SEVERITY: HIGH
FILE: db/migrate/20260630050053_add_textsearch_vector_to_textract_results.rb
SPEC SECTION: Migrations, item 3 ("match reference migration exactly")
DEVIATION: The spec says "match reference migration exactly." The reference migration
uses bare `add_column` and `add_index` with no guards:

  Reference:
    add_column :textract_results, :textsearch_vector, :tsvector
    add_index :textract_results, :textsearch_vector, using: "gin"

  Implementation:
    add_column :textract_results, :textsearch_vector, :tsvector unless column_exists?(:textract_results, :textsearch_vector)
    add_index :textract_results, :textsearch_vector, using: 'gin' unless index_exists?(:textract_results, :textsearch_vector)

The `unless column_exists?` / `unless index_exists?` guards are not in the
reference. This is a structural deviation from "match exactly."

NOTE: The guards are likely defensive against re-running in an environment
where the reference branch's migration was previously applied. Whether this
deviation is acceptable is the owner's call.
```

```
FINDING-ID: L1-MT-2
SEVERITY: HIGH
FILE: db/migrate/20260630050054_create_trigger_tsvectorupdate.rb
SPEC SECTION: Migrations, item 4 (trigger migration code block)
DEVIATION: The spec shows `def change` with `create_trigger`:

  Spec:
    def change
      create_trigger :tsvectorupdate, on: :textract_results, sql_definition: <<-SQL
        ...
      SQL
    end

  Implementation:
    def up
      execute 'DROP TRIGGER IF EXISTS tsvectorupdate ON textract_results'
      create_trigger :tsvectorupdate, on: :textract_results, sql_definition: <<-SQL ... SQL
    end
    def down
      execute 'DROP TRIGGER IF EXISTS tsvectorupdate ON textract_results'
      create_trigger :tsvectorupdate, on: :textract_results, sql_definition: <<-SQL
        ... 'textract_job_result_text' ...
      SQL
    end

Three deviations from the spec's code block:
1. `def up/down` instead of `def change`
2. Added `execute 'DROP TRIGGER IF EXISTS ...'` before each `create_trigger`
3. Added a `down` method that restores the old trigger with `textract_job_result_text`

NOTE: `def change` with `sql_definition:` inline likely cannot auto-reverse
(fx has no previous version SQL to revert to), making `up/down` technically
necessary. The `DROP TRIGGER IF EXISTS` is defensive cleanup for environments
where a prior trigger may exist. The `down` restoring the old trigger is
thoughtful rollback behavior. All three deviations may be justified — but the
spec shows `def change` and the implementation does not match.
```

---

## Checks that passed

1. **Migration 1 (columns):** Adds `structured_extraction` (jsonb) and `structured_extraction_text` (text). Both nullable, no defaults. Uses `def change`. Matches spec exactly.

2. **Migration order:** Timestamps enforce correct order: columns (50052) → tsvector+GIN (50053) → trigger (50054) → data migration (50055). Correct.

3. **Trigger SQL:** Uses `tsvector_update_trigger('textsearch_vector', 'pg_catalog.simple', 'structured_extraction_text')` — built-in Postgres function, NOT custom PL/pgSQL. Only the last argument changed from reference (`textract_job_result_text` → `structured_extraction_text`). Matches spec.

4. **Trigger uses `sql_definition:` inline:** Not a separate SQL file. Correct per spec (`.gitignore` has `*.sql` on line 43).

5. **Data migration:** `up` calls `BackfillStructuredExtractionJob.perform_later`. `down` raises `ActiveRecord::IrreversibleMigration`. Matches spec and reference pattern.

6. **Data migration has `frozen_string_literal: true`:** Present. Matches reference backfill pattern.

---

**VERDICT: 2 HIGH findings (L1-MT-1, L1-MT-2)**
