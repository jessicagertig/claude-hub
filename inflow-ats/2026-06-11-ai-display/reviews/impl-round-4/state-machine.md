# Angle: State Machine Correctness

## Files checked
- `PlatoTab.tsx` -- `renderBody()` lines 322-342
- `PlatoOverviewCallout.tsx` -- state branching lines 21-51

## Findings

No findings.

## Verification

### PlatoTab state machine (lines 322-342)

Evaluation order matches spec (SPEC.md lines 57-64):
1. `summaryExists && status === "succeeded"` -- succeeded
2. `summaryExists && (status === "pending" || status === "in_progress" || status === "extracted")` -- generating
3. `summaryExists && status === "textract_processing"` -- processing
4. `summaryExists && status === "failed"` -- failed
5. `!summaryExists && jobApplication.hasResume` -- empty
6. `return renderNoResume()` -- no resume (fallthrough default)

All 6 states are mutually exclusive and exhaustive. The `summaryExists` guard prevents the no-summary branches from matching when a summary exists with any status. `textract_processing` is correctly separated from the other generating statuses.

### PlatoOverviewCallout state machine (lines 21-51)

Evaluation order matches spec (SPEC.md lines 105-112):
1. `summaryExists && status === "succeeded"` -- succeeded (stale/not-stale handled inside, lines 22-26). Both branches set CTA to "View" and subtitle to `aiSummary.headline`.
2. `summaryExists && status === "failed"` -- failed
3. `summaryExists && (status === "pending" || status === "in_progress" || status === "extracted" || status === "textract_processing")` -- generating (correctly groups `textract_processing` with other generating states per the callout's spec table)
4. `!summaryExists && jobApplication.hasResume` -- has resume, CTA is "Generate"
5. `else` -- no resume (catches `!summaryExists && !jobApplication.hasResume`)

The spec table says "Generate" CTA for the no-summary+has-resume state. The spec also says "All CTA labels are display-only text. The card always navigates to the Plato tab on click; it never triggers the useGenerateAiSummary mutation directly." Implementation confirms: `onClick={onOpen}` is on the card, not on the CTA. Correct.

### Round 1 H1 verification

Round 1 found the callout checked stale-before-succeeded. This was fixed in Round 1 by restructuring. The current order checks succeeded first, then branches on stale within that block. Matches spec.
