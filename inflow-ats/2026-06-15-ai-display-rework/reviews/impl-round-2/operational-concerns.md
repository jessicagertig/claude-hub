# operational-concerns (Round 2)

## Re-verified

1. Performance: ~6 extra broadcast calls per pipeline run (one per intermediate status transition). Lightweight ActionCable messages. Acceptable.
2. Double invalidation on `succeeded`: harmless, React Query deduplicates.
3. Monotonic checklist state: `Math.max(prev, target)` prevents regression. Out-of-order messages handled correctly.
4. Brief flash of empty state while `useAiJobApplicationSummary` loads when `statusValue === "current"` but `fullSummary` is undefined. Pre-existing behavior (same flash existed before rework with the old data source). Not a regression.

## Findings

None.
