# Pass 1 -- Angle 2: State Machine Correctness

## Fact Check

### PlatoTab state machine (Plan Task 4.11)

Plan evaluation order:
1. `summaryExists && status === "succeeded"` --> PlatoSucceeded
2. `summaryExists && (status === "pending" || status === "in_progress" || status === "extracted")` --> PlatoGenerating
3. `summaryExists && status === "textract_processing"` --> PlatoProcessing
4. `summaryExists && status === "failed"` --> PlatoFailed
5. `!summaryExists && jobApplication.hasResume` --> PlatoEmpty
6. `!summaryExists && !jobApplication.hasResume` --> PlatoNoResume

Spec evaluation order (SPEC.md "State machine" section):
1. `status === "succeeded"` --> PlatoSucceeded
2. `status` is `"pending"` or `"in_progress"` or `"extracted"` --> PlatoGenerating
3. `status === "textract_processing"` --> PlatoProcessing
4. `status === "failed"` --> PlatoFailed
5. No summary exists AND `jobApplication.hasResume` is truthy --> PlatoEmpty
6. No summary exists AND `jobApplication.hasResume` is falsy --> PlatoNoResume

MATCH: Plan and spec agree on all 6 conditions and their evaluation order.

### Mutual exclusivity and exhaustiveness

The `AiJobApplicationSummary` type (aiJobApplicationSummary.ts line 2) defines status as: `"pending" | "in_progress" | "extracted" | "succeeded" | "failed" | "textract_processing"`. All 6 status values are covered in rows 1-4 (succeeded, pending/in_progress/extracted, textract_processing, failed). Rows 5-6 handle the no-summary case. The conditions are exhaustive given the type definition.

The `summaryExists` guard in rows 1-4 prevents false matches on rows 5-6 when a summary exists with any status. The conditions are mutually exclusive.

### PlatoOverviewCallout state machine (Plan Task 3.2)

Plan evaluation order:
1. Summary exists AND `status === "succeeded"` AND `stale === true` --> stale
2. Summary exists AND `status === "succeeded"` AND NOT stale --> succeeded
3. Summary exists AND `status === "failed"` --> failed
4. Summary exists AND status is one of pending/in_progress/extracted/textract_processing --> generating
5. No summary AND hasResume --> generate CTA
6. No summary AND !hasResume --> no resume

Spec evaluation order (SPEC.md "State-dependent copy" table):
Row 1: Succeeded, not stale
Row 2: Succeeded, stale
Row 3: Failed
Row 4: Generating (pending/in_progress/extracted/textract_processing)
Row 5: No summary AND has resume
Row 6: No summary AND no resume

The spec table lists succeeded-not-stale before succeeded-stale, but the plan reverses this to check stale first (rows 1-2 in plan). This is functionally equivalent since both are under `status === "succeeded"` and the stale/not-stale split is exhaustive. No issue.

### Analog comparison

The analog in `AiJobApplicationSummaryFeedItem.tsx` (line 82-84):
```
const isGenerating = status === "pending" || status === "in_progress" || status === "extracted";
```
Then lines 84-108 handle: textract_processing, isGenerating, failed, succeeded (with stale sub-check). This matches the plan's conditions.

The analog in `AiSummaryState.tsx` handles the no-summary case with `hasResume === false` check (line 50). The plan's `!summaryExists && !jobApplication.hasResume` matches this.

### textract_processing grouping in callout vs tab

In the PlatoTab, `textract_processing` gets its own distinct state (PlatoProcessing -- row 3). In the PlatoOverviewCallout, `textract_processing` is grouped with the generating states (row 4: "Plato is reading the resume..."). This matches the spec: the callout table row 4 explicitly lists "Generating (pending/in_progress/extracted/textract_processing)".

## Completeness

- All 6 states from spec are addressed in both PlatoTab and PlatoOverviewCallout -- COMPLETE
- The stale flag is handled as orthogonal to status (only applies when succeeded) -- CORRECT
- The callout's "Generate" CTA is display-only text, not a mutation trigger -- ADDRESSED in plan Task 3.6 ("ALL CTA labels are display-only text")

## Findings

No HIGH or MED findings.
