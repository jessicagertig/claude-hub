# Reference Fidelity — Round 1

## Findings

- F1 [HIGH] SPEC.md lines 35-36 + 153 / Trigger migration requires `db/triggers/tsvectorupdate_v01.sql` SQL file, which the spec does not mention / The `fx` gem's `create_trigger :tsvectorupdate, on: :textract_results` (without `sql_definition:`) reads the trigger SQL from `db/triggers/tsvectorupdate_v01.sql` (confirmed by reading `fx-0.8.0/lib/fx/definition.rb:23` and `fx-0.8.0/lib/fx/statements/trigger.rb:47`). The reference branch originally committed this file in `b7c463a52` with the correct `tsvector_update_trigger()` SQL. The file was later removed when `.gitignore` negation patterns (`!db/triggers/*.sql`) were stripped. The main branch has `*.sql` in `.gitignore` (line 43), which will prevent `db/triggers/tsvectorupdate_v01.sql` from being tracked. / Fix: The spec must either (a) specify that `db/triggers/tsvectorupdate_v01.sql` must be created with the trigger SQL AND that `.gitignore` must be updated to add `!db/triggers/*.sql` (matching the pattern from reference commit `b7c463a52`), OR (b) change the migration to use `sql_definition:` inline instead of file-based lookup, which avoids the file and gitignore issue entirely. Option (b) is simpler — the reference's file-based approach was abandoned mid-development of that branch.

- F2 [MED] SPEC.md line 88, review angle "always-on checks" / `pg_search` 2.3.2 compatibility is flagged but not resolved / The spec says "Verify version compatibility" but does not state the finding. The review angle says "Jessica flagged that the pg_search version may need to change from 2.3.2." Verified: `pg_search` 2.3.2 is the resolved version in the main `Gemfile.lock` and is actively used in 4 models (`Candidate`, `Organization`, `Job`, `User`) with `PgSearch::Model`. The version works with the current Ruby 3.1/Rails 6.1/PG stack. However, `pg_search` 2.3.2 was released circa 2020. The latest major version is 2.3.7 (Dec 2023), which includes bug fixes for `tsvector_column` + `highlight` combination usage. The reference branch used 2.3.2 but was never deployed. / Fix: The spec should explicitly state the `pg_search` version decision — either "keep 2.3.2 (confirmed working in 4 other models)" or "upgrade to 2.3.7 for bug fixes relevant to tsvector+highlight." Given that 4 models already depend on 2.3.2, upgrading is a scope expansion. Recommend documenting "use 2.3.2 (already in Gemfile, version compatibility confirmed)" and deferring any upgrade to a separate task.

## Verified — No Findings

- **tsvector column migration:** Spec lines 152-153 correctly match reference migration `20260106002106_add_textsearch_vector_to_textract_results.rb` — `add_column :textract_results, :textsearch_vector, :tsvector` + `add_index :textract_results, :textsearch_vector, using: "gin"`.

- **pg_search_scope config:** Spec lines 53-73 reproduce the reference exactly — every key (`against:`, `dictionary:`, `tsvector_column:`, `prefix:`, `highlight:` with all 7 sub-keys, `ranked_by:`) matches the reference model lines 15-33. Spec line 85 correctly states only `against:` changes.

- **search_resume_by_keyword class method:** Spec lines 74-82 reproduce the reference method exactly (lines 38-47). Signature `(search_params, limit = 15)`, guard, scope chain, ordering, limit — all match.

- **Trigger SQL:** Spec lines 44-47 correctly reproduce the reference trigger SQL from `schema.rb` line 1208. Uses `tsvector_update_trigger()` built-in Postgres function (not custom PL/pgSQL) with arguments `('textsearch_vector', 'pg_catalog.simple', 'textract_job_result_text')`. Spec line 49 correctly states only the third argument changes.

- **fx gem version:** Spec line 90 says `~> 0.8.0`, matching reference Gemfile line 162 and Gemfile.lock resolution to `0.8.0`.

- **fx gem not in main Gemfile:** Confirmed — no `fx` entry in main `Gemfile`. Spec line 90 correctly states "NOT in main Gemfile. Needs adding."

- **Backfill deviation:** Spec lines 175-176 correctly document the expected deviation from reference backfill — API call needed vs. raw SQL UPDATE.

## Amendments Needed

1. **F1:** Add a new subsection under "### Migrations" (after item 4) specifying either the trigger SQL file path and `.gitignore` update, or the alternative `sql_definition:` inline approach.

2. **F2:** Add an explicit note under "### Gems required" resolving the `pg_search` version question.
