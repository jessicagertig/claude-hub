# Backward Compatibility — Round 4

Fix-commit deltas examined for compatibility breaks:

- **Fresh read vs `reload` (fix 1):** the only behavioral divergence is the deleted-row case — `reload` raises `ActiveRecord::RecordNotFound`, `find_by` returns nil → silent return, no broadcast. Strictly more defensive; no caller depended on the exception (all three call sites either guard the row themselves or would have crashed). In-flight Sidekiq payloads unaffected (signature untouched — flag 4 standing).
- **Log line (fix 2):** additive; no control-flow change; claim-row lifecycle identical.
- **Shared tiers constant (fix 3):** pure relocation; rendered DOM and copy byte-identical (verified against 9ed954142^); no import cycle (`jobCriteriaTiers.ts` imports nothing).
- **Error state (fix 4):** changes rendering only when `useAiJobCriteria` errors — previously that case fell through to the never-extracted EmptyState WITH a Generate button against unknown server state; that was the bug being fixed, per the adjudicated report.
- **Token swaps (fixes 5-7):** computed CSS values identical (5px/7px/14px/12px/1rem/450) — zero visual delta.
- **Focus rings (fix 8):** additive pseudo-class; no existing style overridden.

Existing flows re-confirmed untouched at HEAD: dirty tracking / Save / `useUpdateJob` in JobSetupAiSettings; `QueueBulkAiSummaryJobs` callers; the four `ExtractJobCriteriaJob.perform_later` enqueue sites.

## Findings

No issues found.
