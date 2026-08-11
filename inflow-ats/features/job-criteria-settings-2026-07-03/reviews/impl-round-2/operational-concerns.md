# Operational Concerns (always-on) — Round 2

- **Deploy safety of the merged state:** old positional `[id]` ExtractJobCriteriaJob payloads still valid; pre-merge BulkGenerateAiSummariesJob payloads without `'rescore_requested'` degrade to legacy behavior (nil → falsy — nil-safe, verified). No migrations, no config changes.
- **Pre-existing breakage re-verified at the NEW base:** the 9 `on_complete` failures in `bulk_generate_ai_summaries_job_spec.rb` are unchanged by the merge (develop did not touch the spec file; identical failing lines and error as round 1). Still out of scope; still worth a separate investigation ticket.
- **Upstream note for Jessica:** develop (639458b9d) carries its own failing bulk-controller-spec examples (PR #3054 made `rescore_requested` required but did not update 4+ request examples). This branch's merge fixed them locally; develop remains broken until this branch merges back or develop is patched.
- **Logging/error handling:** unchanged since round 1 (codebase `ap` + `Rails.logger.error` shape; no empty rescues).
- **Performance:** unchanged since round 1 (2-3 small queries per settings-tab GET; one predicate read per validation).
- **Observability:** every terminal write site broadcasts when a requester exists; payload-driven button state resolves on refetch even if the socket message is missed.

## Findings

No issues found.
