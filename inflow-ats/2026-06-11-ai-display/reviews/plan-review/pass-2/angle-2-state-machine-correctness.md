# Pass 2 -- Angle 2: State Machine Correctness

## Pass 1 Verification

No findings from Pass 1. All 6 states verified correct.

## Fresh Scrutiny

### Edge case: summary exists with unknown status

If the backend adds a new status value in the future (e.g., `"queued"`), the PlatoTab state machine would fall through all 6 conditions and render nothing. This is acceptable for v1 -- the type definition is exhaustive for current status values and any new status would require code changes anyway. Not a finding.

### Edge case: callout vs tab state ordering for `textract_processing`

In PlatoTab, `textract_processing` is its own state (row 3: PlatoProcessing). In PlatoOverviewCallout, `textract_processing` is grouped with generating states (row 4: "Plato is reading the resume..."). The plan correctly groups them in the callout (Task 3.2, row 4: `status is one of "pending", "in_progress", "extracted", "textract_processing"`). This matches the spec's callout table which lists row 4 as "Generating (pending/in_progress/extracted/textract_processing)." CORRECT.

### Stale check in callout

The callout (Task 3.2) checks stale before not-stale for succeeded status (rows 1-2). The tab state machine (Task 4.11) does not distinguish stale at the top-level state switch -- it renders PlatoSucceeded for all succeeded summaries, and the stale banner is a conditional within PlatoSucceeded (Task 4A.2). This is consistent: the callout has distinct copy for stale vs not-stale, while the tab handles it internally. CORRECT.

### No summary check: `aiSummary != null` vs `summaryExists`

Plan Task 4.3 defines `const summaryExists = aiSummary != null;`. This uses loose equality (`!=`) which catches both `null` and `undefined`. The `aiJobApplicationSummary` field on `jobApplication` is either an object or null/absent. Loose equality is correct here and matches the codebase's use of `!= undefined` patterns. CORRECT.

## Findings

No HIGH or MED findings.
