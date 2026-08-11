# Angle 2: State Machine Correctness

## Findings

### H1 (HIGH): PlatoOverviewCallout state evaluation order differs from spec

**Spec order (SPEC.md lines 106-112):**
1. Succeeded, not stale
2. Succeeded, stale
3. Failed
4. Generating (pending/in_progress/extracted/textract_processing)
5. No summary AND has resume
6. No summary AND no resume

**Implementation order (PlatoOverviewCallout.tsx lines 21-51):**
1. Succeeded AND stale (line 21)
2. Succeeded AND not stale (line 25)
3. Failed (line 29)
4. Generating -- pending/in_progress/extracted/textract_processing (lines 33-38)
5. No summary AND has resume (line 43)
6. No summary AND no resume (line 47)

The implementation swaps rows 1 and 2 relative to the spec. This is a spec-implementation mismatch.

**Severity assessment:** The implementation order produces IDENTICAL behavior. Checking `stale === true` first, then falling through to the non-stale succeeded case, is logically equivalent to the spec's order where non-stale is checked first. Both produce the correct output for all inputs. However, per the Known Failure Pattern "Spec-implementation mismatch is HIGH" -- the user decides whether the deviation is acceptable, not the reviewer.

**Recommendation:** The implementer likely put stale-first because it is the more specific condition (subset of succeeded). This is arguably cleaner code. But it is a reordering from the spec table. The user should confirm this is acceptable.

### PlatoTab state machine -- CORRECT

PlatoTab.tsx `renderBody()` (lines 321-341) evaluates:
1. `summaryExists && status === "succeeded"` -- matches spec row 1
2. `summaryExists && (status === "pending" || status === "in_progress" || status === "extracted")` -- matches spec row 2
3. `summaryExists && status === "textract_processing"` -- matches spec row 3
4. `summaryExists && status === "failed"` -- matches spec row 4
5. `!summaryExists && jobApplication.hasResume` -- matches spec row 5
6. Default: renderNoResume -- matches spec row 6

This matches the spec evaluation order exactly.

### PlatoOverviewCallout state grouping -- CORRECT

The spec's callout table groups `textract_processing` with the other generating statuses (row 4: "pending/in_progress/extracted/textract_processing"). The implementation correctly groups all four in one branch (lines 33-38). The PlatoTab correctly separates `textract_processing` into its own state (line 331) as the spec requires.

### Callout "Generate" CTA -- CORRECT

The callout's "Generate" CTA (no-summary+has-resume, line 46) is display-only text. The card always calls `onOpen()` on click (line 54). It never triggers the generate mutation. This matches the spec requirement.
