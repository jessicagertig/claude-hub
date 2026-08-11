# Backend Contract — Round 2

## Findings

No issues found.

Verified:
- Route `post :all_stages` inside collection block on `bulk_ai_job_application_summaries` — correct
- Controller `all_stages` authorizes with `bulk_create?`, finds job scoped to `current_organization`, plucks all job application IDs, passes `kind: 'all_stages'` and `rescore_requested` to interactor — matches spec
- Response shape matches `create`: `queued_count`, `skipped_count`, `any_textract_pending`
- Error path uses `render_general_errors([result.error])` — matches `create` analog
- Single params method `bulk_ai_job_application_summary_params` with `rescore_requested` added — CLAUDE.md rule #5 compliant
- Serializer adds `ai_job_application_summaries_count` (column attribute, no method) and `should_auto_generate_ai_summaries` (delegating method stripping `?`) — correct
- Frontend mutation POSTs to `/bulk_ai_job_application_summaries/all_stages` with `{ bulkAiJobApplicationSummary: { jobId, rescoreRequested } }` — matches route and params
- Query invalidation includes `job` key for updated count — correct
