# Layer 1 — Diff-to-Spec Review: Model Changes (TextractResult)

**Focus area:** Model changes to `app/models/textract_result.rb`
**Files compared:**
- Branch: `/Users/jessica/wrk/wrk-corp/inflow-ats/app/models/textract_result.rb`
- Reference: `~/wrk/wrk-corp/inflow-ats.keyword-search-connect-version/app/models/textract_result.rb`
- Analogs: `ai_job_application_summary.rb`, `ai_job_criteria.rb`

## Checks performed

| # | Check | Result |
|---|-------|--------|
| 1 | `pg_search_scope` config matches reference — ONLY `against:` changed to `:structured_extraction_text` | PASS — all 10 config keys identical; only `against:` differs |
| 2 | `search_resume_by_keyword` matches reference exactly | PASS — identical signature, body, chain; only a comment removed |
| 3 | `has_many :ai_api_requests, as: :requestable` matches analogs | PASS — identical to `AiJobApplicationSummary:6` and `AiJobCriteria:5` |
| 4 | `after_commit` callback has same guards as existing `queue_ai_summary_job` | PASS — both use `textract_job_result_text.present?` + `saved_change_to_textract_job_result_text?` |
| 5 | New callback is unconditional (no org/validation/feature-gate checks) | PASS — spec explicitly says extraction is unconditional |
| 6 | `include PgSearch::Model` placement at top of class body, before `belongs_to` | PASS — line 4, matches reference |
| 7 | Callback enqueues `ExtractStructuredResumeDataJob.perform_later(id)` | PASS — line 188 |
| 8 | Both `after_commit` callbacks declared alongside each other on `[:create, :update]` | PASS — lines 10-11 |

## VERDICT: CLEAN — 0 findings
