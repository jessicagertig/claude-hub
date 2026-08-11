# Spec Review Complete

**Final verdict: READY FOR PLANNING**

**Two consecutive full passes achieved:** Rounds 4 and 5 both produced 0 MED+ findings and 0 amendments.

## Plain English Summary

This feature adds keyword search over job application resumes. Currently, when someone uploads a resume, Amazon Textract extracts raw text via OCR. But raw OCR text is messy — layout artifacts, broken formatting, noise — making direct search unreliable. This feature takes that raw OCR text and runs it through GPT-4o-mini to produce a clean, structured version (name, work history, skills, education, etc.), stores the structured data on the TextractResult record, flattens it into searchable plain text, and indexes it with a Postgres tsvector + GIN index for fast full-text search. The extraction happens automatically when Textract completes, via a background job. Existing resumes are backfilled via a one-time background job. The existing AI summary pipeline continues unchanged in parallel until the new extraction is stable.

## Blast Radius

- **textract_results table:** 3 new columns (structured_extraction jsonb, structured_extraction_text text, textsearch_vector tsvector) + GIN index + Postgres trigger
- **TextractResult model:** new PgSearch include, search scope, search method, ai_api_requests association, new after_commit callback
- **New service:** ExtractStructuredResumeData — calls GPT-4o-mini, stores structured data, flattens to text
- **New background job:** ExtractStructuredResumeDataJob — retry with exhaustion
- **New custom error class:** CustomErrorStructuredExtraction
- **New data migration + backfill job:** enqueues one-time backfill of existing records
- **Gemfile:** add fx gem (~> 0.8.0)
- **If wrong:** failure affects only the new search index capability. Existing Textract pipeline, AI summary generation, and all other functionality are unaffected. No serializers expose TextractResult columns, so no data leakage risk.

## Round-by-Round Summary

| Round | Verdict | BLOCKER | HIGH | MED | LOW | Key findings |
|-------|---------|---------|------|-----|-----|-------------|
| 1 | FAIL | 0 | 3 | 9 | 3 | Missing trigger SQL file + gitignore conflict; flattening algorithm unspecified; no test section; background job not specified; backfill scope/rate/deploy issues |
| 2 | FAIL | 0 | 0 | 5 | 1 | Internal inconsistency (Integration point OR vs decided); model section incomplete; AiApiRequest call_type/organization unspecified; custom error class generic |
| 3 | FAIL | 0 | 0 | 1 | 0 | Test description contradicted service error behavior (said "does not raise" vs raises CustomErrorStructuredExtraction) |
| 4 | PASS | 0 | 0 | 0 | 0 | Clean |
| 5 | PASS | 0 | 0 | 0 | 0 | Clean |

**Totals across all rounds:** 0 BLOCKER, 3 HIGH, 15 MED, 4 LOW — all resolved.

## Open Questions

None. All questions raised during review were resolved via amendments.
