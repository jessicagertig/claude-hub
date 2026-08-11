# Reinventing the Wheel

## Verdict: PASS

### Findings

None.

### Verification

- Service reuses existing prompt class `AiJobApplicationAction::Summary::Prompts::ResumeStructuredData` -- does NOT duplicate the prompt or schema
- Service reuses existing `AiClient` -- does NOT create a new HTTP client or API wrapper
- Service reuses existing `AiClient.calculate_cost` -- does NOT implement cost calculation
- Error class follows existing `CustomErrorTextract` / `CustomErrorAiSummary` pattern -- does NOT invent a new error hierarchy
- Job follows existing `GetResumeTextFromTextractJob` retry/exhaustion pattern -- same `retry_on` shape, same logging approach
- Model callback follows existing `queue_ai_summary_job` pattern -- same `after_commit on: [:create, :update]`, same guards
- `AiApiRequest` creation follows existing `generate.rb:296-313` pattern -- same fields, same `calculate_cost` call
- `pg_search_scope` and `search_resume_by_keyword` copied from reference implementation -- no reinvention
- Backfill job follows existing data migration patterns in the codebase
- No new gems beyond `fx` (which is required for trigger management and used in the reference)
