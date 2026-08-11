# Angle: State Machine Correctness

## Verdict: PASS

### PlatoTab state machine (lines 322-342)

Evaluation order:
1. `summaryExists && status === "succeeded"` -- correct
2. `summaryExists && (pending || in_progress || extracted)` -- correct (PlatoGenerating)
3. `summaryExists && status === "textract_processing"` -- correct (PlatoProcessing, separate state)
4. `summaryExists && status === "failed"` -- correct (PlatoFailed)
5. `!summaryExists && jobApplication.hasResume` -- correct (PlatoEmpty)
6. fallthrough -- correct (PlatoNoResume)

Matches spec table (SPEC.md lines 57-64). All 6 states are mutually exclusive and exhaustive. The `textract_processing` state is correctly separated from the generating group (matching the spec's distinct row 3 vs row 2).

### PlatoOverviewCallout state machine (lines 21-51)

Evaluation order:
1. `summaryExists && status === "succeeded"` with stale/not-stale branch inside -- matches spec rows 1-2
2. `summaryExists && status === "failed"` -- matches spec row 3
3. `summaryExists && (pending || in_progress || extracted || textract_processing)` -- matches spec row 4 (all four statuses grouped together for callout, which differs from PlatoTab's separate textract_processing treatment, per spec)
4. `!summaryExists && jobApplication.hasResume` -- matches spec row 5
5. fallthrough -- matches spec row 6

Copy for each state matches the spec table (lines 105-112). CTA labels are all display-only text. The "Generate" CTA for no-summary+has-resume is a label only -- the card's `onClick={onOpen}` always navigates, never triggers generate. Correct.

### Stale flag handling

In PlatoOverviewCallout, the stale check is nested inside the succeeded block (lines 22-27). In PlatoTab's succeeded layout, `aiSummary.stale === true` conditionally renders the stale banner (line 138). Both correctly treat stale as orthogonal to status, only relevant when succeeded.

### Round 1 H1 verification

The state evaluation order in PlatoOverviewCallout was restructured in Round 1 fix to check succeeded first, then branch on stale within that block. Verified in Round 2. The current code maintains that fix.

### No findings.
