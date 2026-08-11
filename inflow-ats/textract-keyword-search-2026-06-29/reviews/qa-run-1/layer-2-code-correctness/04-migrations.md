# Layer 2 — Migration Code Correctness

**Files reviewed:**
- `db/migrate/20260630050052_add_structured_extraction_columns_to_textract_results.rb`
- `db/migrate/20260630050053_add_textsearch_vector_to_textract_results.rb`
- `db/migrate/20260630050054_create_trigger_tsvectorupdate.rb`
- `db/data/20260630050055_enqueue_structured_extraction_backfill.rb`

---

## Findings

```
FINDING-ID: L2-MIG-1
SEVERITY: MED
FILE: db/migrate/20260630050053_add_textsearch_vector_to_textract_results.rb
LINE: 3-4
BUG: The `unless column_exists?` / `unless index_exists?` guards inside
`def change` prevent clean rollback. During `down`, Rails re-runs the `change`
body with `CommandRecorder` intercepting migration commands. But `column_exists?`
is a query method — it queries the live database. At rollback time the column
EXISTS (it was added during `up`), so `unless true` skips the `add_column` call,
the recorder never sees it, and no inverse `remove_column` is generated. Result:
`rails db:rollback` on this migration silently does nothing — the column and
index persist.

Not a runtime bug — the migration works correctly going forward. Only affects
the case where someone needs to fully roll back this migration. Manual cleanup
(`remove_column :textract_results, :textsearch_vector` + drop index) would be
required. Other migrations in this codebase use the same pattern
(e.g., active_storage, acts_as_taggable_on) so it's an established-if-imperfect
convention.
```

---

## Checks that passed

1. **Migration order:** Timestamps enforce correct order: columns (50052) → tsvector+GIN (50053) → trigger (50054) → data migration (50055). The trigger references `textsearch_vector` and `structured_extraction_text` — both columns are created in earlier migrations. Correct.

2. **Trigger SQL:** `tsvector_update_trigger('textsearch_vector', 'pg_catalog.simple', 'structured_extraction_text')` — argument order matches the Postgres built-in signature: `tsvector_update_trigger(tsvector_column, text_search_config, source_column)`. Correct.

3. **Rollback safety (other migrations):**
   - Migration 1 (columns): Uses bare `def change` with `add_column`. Fully reversible. Clean.
   - Migration 3 (trigger): Uses `def up/down`. `down` explicitly drops the new trigger and recreates the old one with `textract_job_result_text`. Rollback is explicit and correct.
   - Data migration: `down` raises `ActiveRecord::IrreversibleMigration`. Correct — can't un-enqueue a background job.

4. **Data migration timing:** `BackfillStructuredExtractionJob.perform_later` enqueues to Sidekiq asynchronously. Schema migrations 50052-50054 run first and commit before data migration 50055 runs. By the time Sidekiq picks up the backfill job, all columns and the trigger exist. No timing issue.

5. **GIN index:** `using: 'gin'` is the correct index type for tsvector columns.

6. **Column types:** `jsonb` for structured data, `text` for flattened text, `tsvector` for the search vector — all correct.

---

**VERDICT: 1 MED finding (L2-MIG-1: rollback impaired by `unless` guards in `def change`)**
