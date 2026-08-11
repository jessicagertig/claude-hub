# Layer 1 — Backfill (Diff-to-Spec)

**Focus:** Backfill job + data migration
**Files reviewed:**
- `app/jobs/backfill_structured_extraction_job.rb`
- `db/data/20260630050055_enqueue_structured_extraction_backfill.rb`
**Reference compared:** `inflow-ats.keyword-search-connect-version/db/data/20260106200000_backfill_textract_tsvector.rb`

## Checklist

### BackfillStructuredExtractionJob

| Spec requirement | Code | Status |
|---|---|---|
| Scope: `succeeded` + `structured_extraction IS NULL` + text present | `.where(textract_job_status: :succeeded, structured_extraction: nil).where.not(textract_job_result_text: [nil, ''])` | MATCH |
| `find_each(batch_size: 100)` | Line 20 | MATCH |
| `sleep 0.2` per record | Line 24 | MATCH |
| Per-record `rescue StandardError` with log + continue | Lines 25-28 | MATCH |
| Uses same `ExtractStructuredResumeData` service | Line 21 | MATCH |
| Resumable via `IS NULL` guard | `structured_extraction: nil` in scope | MATCH |
| No `retry_on` (unlike real-time job) | No `retry_on` declaration | MATCH |

### Data migration (EnqueueStructuredExtractionBackfill)

| Spec requirement | Code | Status |
|---|---|---|
| Only enqueues job (no inline iteration/AI calls) | `BackfillStructuredExtractionJob.perform_later` | MATCH |
| `perform_later` (not `perform_now`) | Line 5 | MATCH |
| `down` raises `ActiveRecord::IrreversibleMigration` | Line 9 | MATCH |

### Reference comparison

The reference backfill uses raw SQL `UPDATE ... SET textsearch_vector = to_tsvector(...)` inline in the data migration. The new implementation uses a background job that calls the `ExtractStructuredResumeData` service per record. This is an **expected deviation** documented in the spec: "The reference backfill uses raw SQL because it only needs to set a tsvector from existing text. The new backfill MUST call the service because it needs the GPT-4o-mini extraction step."

Both use `ActiveRecord::IrreversibleMigration` in `down` — pattern match.

## VERDICT: CLEAN — 0 findings
