# Angle: Generate/Regenerate Mutation and Credit Balance Lifecycle

## Verdict: PASS

### Generate handler

PlatoTab.tsx lines 47-63: Exact copy of `AiSummaryState.tsx` lines 31-47. Success toast: "Summary generation queued", `kind: "success"`. Error toast: `error?.data?.errors?.general?.[0] || "Failed to queue summary"`, `kind: "warning"`, `delay: 10000`. Correct.

### Credit balance

Line 44: `totalRemaining = creditError ? 0 : creditData?.totalCreditsRemaining || 0`. Matches spec pattern from `AiSummaryState.tsx` line 28.

### Double-click prevention (Round 1 M1 + Round 2 M1)

Line 45: `buttonLoading = isLoadingCredits || isGenerating`. Applied to:
- `renderCreditsAction` Button: line 84, `loading={buttonLoading} disabled={buttonLoading}` -- PASS
- Header Regenerate Button: line 353, `loading={buttonLoading} disabled={buttonLoading}` -- PASS
- Stale banner StaleAction: line 146, `disabled={buttonLoading}` with `&:disabled { opacity: 0.5; pointer-events: none; }` at line 541 -- PASS (Round 2 M1 fix verified)

All three generate/regenerate surfaces have double-click protection.

### Credit hint copy

- Empty state: "Uses 1 credit . N remaining" (line 87: conditional on `buttonLabel === "Generate summary"`)
- Failed state: "Uses 1 credit" (line 88: fallback branch)
- Stale banner: "Regenerate . 1 credit" (line 150: literal `&middot;`)

All match spec copy.

### Credit hint layout

Styled.ActionColumn (lines 975-982): `flex-direction: column; align-items: center; gap: 8px; margin-top: 18px`. Button + hint stacked below, centered. NOT inline. Matches spec requirement.

### Zero-credits handling

`renderCreditsAction` lines 93-108: When `totalRemaining <= 0`:
- Admin: `<Button type="internalLink" link="/hire/settings/ai-billing">Buy more credits</Button>` -- matches AiSummaryState analog
- Non-admin: `<Button onClick={handleBuyCredits}>Buy more credits</Button>` -- triggers CenterModal with "Admin access required" header

### Buy-credits modal

Lines 65-78: Exact copy of `AiSummaryState.tsx` lines 68-79. `headerTitleText="Admin access required"`, body text about contacting admin, Close button calls `removeModal`.

### Callout does NOT trigger generate

PlatoOverviewCallout.tsx: The "Generate" CTA at line 46 is a label string. The card's `onClick={onOpen}` (line 54) always navigates to the Plato tab. No generate mutation is called from the callout. Correct.

### No findings.
