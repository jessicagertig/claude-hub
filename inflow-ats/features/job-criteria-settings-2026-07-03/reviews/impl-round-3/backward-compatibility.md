# Backward Compatibility (always-on check) — Round 3

Directed focus this round: the MERGED pipeline.

- **Old positional Sidekiq payloads, both jobs**:
  - `ExtractJobCriteriaJob`: pre-deploy `perform_later(id)` payloads (including `set(wait: 30.seconds)` scheduled ones and 2-minute retry waves) invoke `perform(id)` → `requesting_organization_user_id = nil` → no broadcast, full extraction unchanged. Exhaustion block's `job.arguments.second` → nil → helper bare-returns after the failure write. Verified against the actual signature at HEAD.
  - `BulkGenerateAiSummariesJob`: signature unchanged by this feature (single hash payload). Pre-merge payloads lacking `'rescore_requested'`/`'job_id'` keys: `payload['rescore_requested']` → nil (falsy, legacy behavior); `each_iteration`'s new failure write uses only `job_application_bulk_job_status`, present for any claimed row.
- **`extract_job_criteria_immediately` kwarg**: default nil; its one pre-existing caller (`extract_job_criteria_if_needed`, job.rb:746) passes nothing. `auto_extract_job_criteria` (:700-715, both enqueue variants) and `extract_job_criteria` (:717-728) byte-untouched — pending guard + Flipper semantics preserved, still single-positional enqueues.
- **`QueueBulkAiSummaryJobs` call sites — grep re-run at HEAD**: exactly two production call sites (bulk controller `create`:13 and `all_stages`:39); BOTH pass `job:` AND `params:`. No remaining caller lacks either. (`context.params` being required is develop's own PR #3054 contract; the feature's `job` input stays optional safe-nav — spec-proven by the job-less example.)
- **`ValidateAiSummaryGeneration` callers** (grep re-run): controller :8, bulk job :61, textract_result :132/:146 — all pass `job_application:`+`organization:`; the added fail! needs nothing new from callers. `ValidateAutoAiSummaryGeneration`: job_application.rb:187 unchanged. The textract manual-waiting branch carries the new message through the existing destroy + `AI_SUMMARY_FAILED` broadcast mechanism.
- **Frontend**: `aiSummaryWebsocketPayloads.ts` existing interfaces untouched (comment + append only); `JobSetupAiSettings.tsx` existing Plato-reviews form/dirty-tracking/Save flow additive-only; develop's own bulk-rescore frontend files byte-identical to develop.

## Findings

No issues found.
