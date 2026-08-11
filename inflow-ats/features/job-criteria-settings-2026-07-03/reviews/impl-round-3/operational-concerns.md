# Operational Concerns (always-on) — Round 3

- **Deploy safety**: old positional `[id]` ExtractJobCriteriaJob payloads valid against the new optional-positional signature (nil default → helper bare-returns); pre-merge BulkGenerateAiSummariesJob hash payloads without `'rescore_requested'` degrade to nil/falsy. No migrations, no config/env changes, no new queues.
- **Pre-existing breakage**: the 9 `on_complete` failures re-verified this round by an independent suite run — identical example lines and error to round 2 (see test-coverage.md). Out of scope; separate-ticket note stands.
- **Upstream note for Jessica (unchanged from round 2)**: develop (639458b9d) itself still carries failing bulk-controller-spec examples from PR #3054's required `rescore_requested`; this branch's merge reconciliation fixes them here only.
- **Logging/error handling**: codebase `ap` log shape in the job paths; no empty rescues; every terminal write site broadcasts when a requester exists.
- **Performance**: settings-tab GET issues a handful of single-row indexed `ai_job_criteria` lookups per request (serializer methods each hit `latest_*`); negligible for a per-job settings view and consistent with rounds 1-2's assessment. Guard predicate adds one single-row read per validation.
- **Observability/resilience**: payload-driven button state self-heals on refetch even if the socket message is missed; POST is idempotent while in-flight.

## Findings

No issues found.
