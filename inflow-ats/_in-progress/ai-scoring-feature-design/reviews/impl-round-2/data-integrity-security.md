# data-integrity-security — Implementation Review Round 2

## Files reviewed

- All new models, services, and jobs
- Migrations
- Serializers

## Findings

No findings.

1. **Foreign key constraints:** Both new migrations use `foreign_key: true`. `ai_job_criteria.job_id` has unique index. `ai_job_application_summary_statuses.job_application_id` has unique index. Correct.
2. **No mass assignment vulnerabilities:** New models do not use `attr_accessible` or `permit` — they are backend-only models, not exposed through controller params. Status records are created internally via callbacks and interactors.
3. **No direct user input to AI prompts:** All prompt content comes from database fields (job description HTML, resume text, criteria results). No user-controlled free text is injected into system prompts.
4. **`update_columns` for intermediate states:** `update_columns` bypasses validations and callbacks, used for `in_progress`, `scoring`, `awaiting_job_criteria`, `retrying`, `failed` transitions. `update` used for `succeeded` transitions (where callbacks must fire). This distinction is spec-mandated and correct.
5. **No SQL injection:** All queries use Rails parameterized queries. `where(status: :awaiting_job_criteria)`, `where(job_application_id: ...)`, etc.
6. **Serializer does not expose sensitive data:** New serializer attributes (`score_percentage`, `criteria_results`, `integrated_role_analysis`) are evaluation data, not credentials or PII.
7. **Flipper gate enforced:** `extract_job_criteria` checks `Flipper.enabled?(:AI_APPLICANT_SUMMARY, organization)` before enqueuing criteria extraction. Organizations without the feature flag cannot trigger criteria extraction.
