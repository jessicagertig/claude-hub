# Angle 2: State Machine Correctness

## Verdict: PASS

## PlatoTab state machine (lines 322-342)

Evaluation order:
1. `summaryExists && status === "succeeded"` --> renderSucceeded
2. `summaryExists && (status === "pending" || status === "in_progress" || status === "extracted")` --> renderGenerating
3. `summaryExists && status === "textract_processing"` --> renderProcessing
4. `summaryExists && status === "failed"` --> renderFailed
5. `!summaryExists && jobApplication.hasResume` --> renderEmpty
6. Fallback --> renderNoResume

**Matches spec table at SPEC.md lines 57-64.** All 6 states present. Order is correct. `textract_processing` gets its own distinct state (row 3), separate from the generating group (row 2). Conditions are mutually exclusive and exhaustive.

## PlatoOverviewCallout state machine (lines 21-51)

Evaluation order:
1. `summaryExists && status === "succeeded"` --> with inner stale/not-stale branch
2. `summaryExists && status === "failed"` --> Failed copy
3. `summaryExists && (pending || in_progress || extracted || textract_processing)` --> Generating copy
4. `!summaryExists && jobApplication.hasResume` --> No-summary-has-resume copy
5. Fallback --> No-resume copy

**Matches spec table at SPEC.md lines 105-112.** The spec groups `textract_processing` with the other generating statuses for the callout (unlike PlatoTab where it's separate). The implementation matches this grouping at lines 33-39.

### Round 1 H1 fix verification

**VERIFIED FIXED.** Round 1 found that stale-succeeded was checked before non-stale-succeeded, deviating from the spec order. The fix restructured lines 21-28 to check `succeeded` first, then branch on `stale` within that block. The spec table puts "Succeeded, not stale" at row 1 and "Succeeded, stale" at row 2, and the implementation now matches: the outer `if` checks `succeeded`, then the inner `if/else` checks `stale`.

### Copy verification

All 6 callout title/subtitle/CTA values match SPEC.md lines 106-112:
- Succeeded not stale: "Read what Plato thinks about this candidate" / headline / "View" -- MATCHES
- Succeeded stale: "Plato's review is out of date" / headline / "View" -- MATCHES
- Failed: "Plato couldn't finish" / "No credit was used -- open to retry." / "View" -- MATCHES
- Generating: "Plato is reading the resume..." / "This will be ready in a moment." / "View" -- MATCHES
- No summary + resume: "Ask Plato to review this candidate" / "Plato reads the resume for role fit, experience, skills and gaps." / "Generate" -- MATCHES
- No summary + no resume: "Plato needs a resume" / "Add one to this candidate and Plato can review them." / "View" -- MATCHES

### Callout never triggers generate mutation

**VERIFIED.** The callout has no `useGenerateAiSummary` import. The "Generate" CTA label (for no-summary+has-resume state) is display-only text inside `Styled.Cta`. The card's `onClick={onOpen}` navigates to the Plato tab. No generation occurs from the callout.

## Findings

None.
