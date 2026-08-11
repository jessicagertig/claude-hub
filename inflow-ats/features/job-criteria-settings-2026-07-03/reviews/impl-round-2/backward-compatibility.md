# Backward Compatibility (always-on check) — Round 2

Round-2 focus: compatibility of the MERGED state (feature + PR #3054).

- **`ExtractJobCriteriaJob`**: optional positional second arg — old `[id]` Sidekiq payloads (scheduled/retry waves) still valid; the three untouched model enqueue sites still pass one arg. Unchanged by the merge.
- **`extract_job_criteria_immediately` kwarg**: default nil; sole pre-existing caller (`_if_needed`) passes nothing. Unchanged by the merge.
- **`QueueBulkAiSummaryJobs` inputs after the merge**: `job` remains optional/safe-nav (guard at :19). `params` is now effectively REQUIRED on the success path (`context.params[:rescore_requested]` at :41/:97 — raises NoMethodError on a nil `context.params`) — but that requirement is develop's PR #3054 contract, not this feature's; the only production caller (bulk controller, both actions) supplies it. The feature's `job:` addition does not widen or narrow that contract.
- **Validators gain one fail each**: all existing callers re-traced at HEAD (manual single, bulk per-record, textract both branches incl. develop's unified waiting-summary lookup, auto x2) — every caller handles a generic failure message via its existing mechanism; the textract manual-waiting branch still destroys the waiting summary and broadcasts `AI_SUMMARY_FAILED` (textract_result.rb:138-140).
- **Develop's `latest_ai_job_application_summary` unification vs feature code**: the feature reads only `job.latest_ai_job_criteria` / `latest_succeeded_ai_job_criteria` — disjoint associations; the funnel's succeeded-summary early-return predates both sides. No interaction.
- **`aiSummaryWebsocketPayloads.ts`**: existing interfaces untouched; header comment updated only.
- **`JobSetupAiSettings.tsx`**: dirty tracking / Save flow additive-only (round 1 verified; file unchanged since).
- **Sidekiq at deploy of the MERGE**: in-flight `BulkGenerateAiSummariesJob` payloads enqueued pre-merge lack `'rescore_requested'` → `payload['rescore_requested']` = nil → `ai_summary_rescore_requested` falsy → legacy behavior preserved (develop's design; verified nil-safe).

## Findings

No issues found.
