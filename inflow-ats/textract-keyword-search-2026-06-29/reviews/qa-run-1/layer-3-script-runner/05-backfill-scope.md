# Layer 3 — Backfill Scope Verification

**Method:** `RAILS_ENV=test bundle exec rails runner`
**Server:** `http://app.lvh.me:5007` (test mode)

## Tests

### Test 1: Scope eligibility

Created 5 TextractResult records with different states and verified the backfill scope `TextractResult.where(textract_job_status: :succeeded, structured_extraction: nil).where.not(textract_job_result_text: [nil, ''])` includes only the eligible record.

| Record | Status | Text | Extraction | Expected | Actual |
|--------|--------|------|------------|----------|--------|
| A | succeeded | present | nil | IN scope | IN scope |
| B | succeeded | present | `{}` | NOT in scope | NOT in scope |
| C | failed | present | nil | NOT in scope | NOT in scope |
| D | succeeded | nil | nil | NOT in scope | NOT in scope |
| E | succeeded | `''` | nil | NOT in scope | NOT in scope |

**PASS**

### Test 2: Resumability

1. Created a TextractResult eligible for backfill → verified IN scope
2. Set `structured_extraction` to `{ 'name' => 'Test' }` via `update_columns`
3. Verified record is NO LONGER in scope

This proves re-running the backfill job skips already-processed records.

**PASS**

---

**VERDICT: PASS — 2/2 tests passed, 0 findings**
