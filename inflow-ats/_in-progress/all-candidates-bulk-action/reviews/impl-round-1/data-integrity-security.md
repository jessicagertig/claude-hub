# Data Integrity & Security — Round 1

## Findings

No issues found.

Verified:
- Authorization: `authorize :ai_job_application_summary, :bulk_create?` — same policy as `create`, org-level check
- Job lookup: `current_organization.jobs.find(...)` — scoped to current org, prevents cross-org access
- Candidate resolution: `@job.job_applications.pluck(:id)` — scoped to the found job, which is scoped to the org
- Strong params: `rescore_requested` added to existing permit list — additive, no injection risk
- No SQL injection: uses ActiveRecord methods throughout
- No XSS: React escapes by default; no `dangerouslySetInnerHTML`
- `:processing` filter always applies: prevents duplicate processing even with rescore
- Credit validation: `validateBulkGenerateAiSummaries` gates zero-credit submissions
