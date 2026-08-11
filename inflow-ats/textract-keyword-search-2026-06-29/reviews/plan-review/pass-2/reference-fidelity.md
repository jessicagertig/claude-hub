# Pass 2 — reference-fidelity

## Pass 1 corrections
None needed. Pass 1 found 0 findings.

## Fresh scrutiny

### Migration ordering
- Step 2.1 adds `structured_extraction_text` column
- Step 2.2 adds `textsearch_vector` column
- Step 2.3 creates trigger referencing both `textsearch_vector` and `structured_extraction_text`
- Step 2.4 runs `rails db:migrate` (executes all three in timestamp order)
- The trigger migration MUST run after both column migrations. Since the implementing agent generates timestamps sequentially, this is satisfied. Ordering is correct.

### fx gem installation timing
- Step 1.1-1.2: add fx to Gemfile and `bundle install` BEFORE migration steps
- Step 2.3 uses `create_trigger` which requires the fx gem to be installed
- Ordering is correct.

### Trigger rollback behavior
- Plan uses `def change` (not `def up/down`) for the trigger migration
- fx generates `drop_trigger :tsvectorupdate, on: :textract_results` on rollback
- The `sql_definition:` is only used for creation; rollback drops by name
- Reference also uses `def change`. Consistent.

### Trigger SQL schema qualification
- Plan uses `ON public.textract_results` — hardcodes `public` schema
- Reference uses the same pattern
- Standard Rails PostgreSQL setup uses `public` schema
- Consistent with reference.

### pg_search_scope internal consistency
- Step 6.3 sets `against: :structured_extraction_text` — this must point to the text column (not the jsonb column)
- Migration 2.1 creates `structured_extraction_text` as `:text` — correct type for tsvector source
- Migration 2.1 creates `structured_extraction` as `:jsonb` — this is storage, not search
- No cross-reference error between columns.

## Completeness sweep

Every reference pattern verified in Pass 1 re-confirmed:
- tsvector + GIN migration structure: matches
- Trigger creation via fx: matches (with documented sql_definition: deviation)
- Trigger SQL: only source column changes
- pg_search_scope: only `against:` changes
- search_resume_by_keyword: identical
- Gem versions: fx ~> 0.8.0, pg_search 2.3.2 unchanged

## Findings

0 BLOCKER, 0 HIGH, 0 MED, 0 LOW
