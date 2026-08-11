# Implementation Round 1: FAILURE-REPORT

This implementation has 1 HIGH finding and requires revision before it can pass.

---

## H1 (HIGH): PlatoOverviewCallout state evaluation order differs from spec

**File:** `app/javascript/ats/src/views/jobApplications/PlatoOverviewCallout.tsx`
**Lines:** 21-28

### What the spec says

SPEC.md lines 106-112, the callout state table lists states in this evaluation order:
1. Succeeded, not stale
2. Succeeded, stale
3. Failed
4. Generating
5. No summary AND has resume
6. No summary AND no resume

The spec explicitly says "Evaluate in the same order as PlatoTab" and "The table rows are listed in evaluation order -- first match wins."

### What the implementation does

```tsx
// Line 21-28 -- stale is checked FIRST
if (summaryExists && status === "succeeded" && aiSummary.stale === true) {
  // stale succeeded
} else if (summaryExists && status === "succeeded") {
  // non-stale succeeded
}
```

The implementation checks stale-succeeded before non-stale-succeeded, inverting the spec order for those two cases.

### Why this is HIGH (not MED)

Per the Known Failure Pattern at `~/claude-hub/CLAUDE.md`: "If the spec says X and the implementation does Y, that is HIGH or BLOCKER -- even if Y is 'functionally equivalent.' The user decides whether the deviation is acceptable, not the reviewer."

The behavior is indeed logically identical. Checking the more specific case (stale) first is arguably cleaner code. But the spec table has a defined evaluation order and the implementation deviates.

### Fix

Swap the if-else branches to match the spec order:

```tsx
if (summaryExists && status === "succeeded") {
  if (aiSummary.stale === true) {
    title = "Plato's review is out of date";
  } else {
    title = "Read what Plato thinks about this candidate";
  }
  subtitle = aiSummary.headline;
  cta = "View";
} else if (summaryExists && status === "failed") {
  // ...
```

Or keep the flat if-else style but put non-stale first:

```tsx
if (summaryExists && status === "succeeded" && aiSummary.stale !== true) {
  title = "Read what Plato thinks about this candidate";
  subtitle = aiSummary.headline;
  cta = "View";
} else if (summaryExists && status === "succeeded" && aiSummary.stale === true) {
  title = "Plato's review is out of date";
  subtitle = aiSummary.headline;
  cta = "View";
} else if ...
```

---

## M1 (MED): Generate/Regenerate buttons lack loading/disabled props

**File:** `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx`
**Lines:** 27, 31, 83, 145, 352

### What the analog does

`AiSummaryState.tsx` lines 96-99:
```tsx
<Button
  onClick={handleClick}
  loading={buttonLoading}
  disabled={buttonLoading}
  size="small"
>
```

Where `buttonLoading = isLoadingCredits || isLoading` (line 29).

### What the implementation does

The implementation destructures `isGenerating` (line 27) and `isLoadingCredits` (line 31) but never uses either variable. No generate-action Button receives `loading` or `disabled` props.

### Impact

Users can double-click any generate/regenerate/try-again button and queue multiple generation requests, each consuming a credit.

### Fix

Add to PlatoTab.tsx after the existing variable declarations:

```tsx
const buttonLoading = isLoadingCredits || isGenerating;
```

Then pass to each generate-action Button:
- `renderCreditsAction` line 83: `<Button onClick={handleGenerate} loading={buttonLoading} disabled={buttonLoading}>`
- Header Regenerate line 352: `<Button styleType="text" onClick={handleGenerate} disabled={isGenerating}>`
- Stale banner action line 145: add `disabled={isGenerating}` or similar guard
