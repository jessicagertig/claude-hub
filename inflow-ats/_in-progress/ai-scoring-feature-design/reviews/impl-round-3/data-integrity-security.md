# data-integrity-security -- Round 3

## Assessment

1. **Database constraints:** Unique indexes on `ai_job_criteria.job_id` and `ai_job_application_summary_statuses.job_application_id`. Foreign keys on both. `status` NOT NULL with default. Correct.

2. **No direct SQL/psql:** All database access through ActiveRecord. Correct per global rules.

3. **Flipper gating:** `extract_job_criteria` checks `Flipper.enabled?(:AI_APPLICANT_SUMMARY, organization)`. Reuses existing flag. Correct per spec Section 8.

4. **No fabricated fallback values:** `criterion_source&.dig('contains_title_technology') || false` in `ScoreJobApplication` uses `false` as the fallback for a boolean field. This is the correct semantic default (absence of title_technology match = false), not a fabricated value. Acceptable per Known Failure Pattern #13.

5. **No credential/secret exposure:** Prompt files do not contain secrets. API keys accessed via `Variables::OPENAI_API_KEY` (existing pattern).

6. **Polymorphic requestable:** `AiApiRequest` already supports polymorphic `requestable`. Adding `AiJobCriteria` as a new `requestable_type` requires no schema change -- Rails handles it. No data integrity risk.

## Findings

No findings.
