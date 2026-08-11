# Layer 3 — Trigger + Search Verification

**Agent:** l3-trigger-search
**Method:** `RAILS_ENV=test bundle exec rails runner`

---

## Test Results

| Test | Result |
|------|--------|
| Test 1: Postgres trigger auto-updates tsvector | **PASS** |
| Test 2: pg_search_scope returns results | **PASS** |
| Test 3: Prefix matching works | **PASS** |
| Test 4: Blank search returns none | **PASS** |

### Test 1: Trigger auto-updates tsvector

Created a TextractResult, set `structured_extraction_text` via `update_columns`. Reloaded and verified `textsearch_vector` is populated.

- Before text: `textsearch_vector` = `""` (empty)
- After text `'Ruby developer with Rails experience building web applications'`:
  `textsearch_vector` = `'applications':8 'building':6 'developer':2 'experience':5 'rails':4 'ruby':1 'web':7 'with':3`
- Trigger correctly tokenized all words using `pg_catalog.simple` dictionary (no stemming).

### Test 2: pg_search_scope returns results

Searched `TextractResult.search_resume_by_keyword({ search_term: 'Ruby' })`.

- Found 1 result matching the created TextractResult
- `pg_search_rank` = `0.06079271`
- `pg_search_highlight` = `<span class="highlight">Ruby</span> developer with Rails experience building web applications`
- Highlight wraps the matched term correctly.

### Test 3: Prefix matching works

Searched `TextractResult.search_resume_by_keyword({ search_term: 'Rub' })`.

- Found 1 result — prefix matching via `prefix: true` works correctly.

### Test 4: Blank search returns none

- `search_resume_by_keyword({ search_term: '' })` → 0 results (no error)
- `search_resume_by_keyword({ search_term: nil })` → 0 results (no error)

### Note: `.count` incompatibility

Calling `.count` on `search_resume_by_keyword` results raises `PG::UndefinedColumn: ERROR: column "count_column" does not exist`. This is a known pg_search 2.3.2 issue with `with_pg_search_rank` subqueries. Use `.to_a.size` instead. This is a pre-existing pg_search limitation, not a regression from this feature.

---

**VERDICT: 4/4 PASS**
