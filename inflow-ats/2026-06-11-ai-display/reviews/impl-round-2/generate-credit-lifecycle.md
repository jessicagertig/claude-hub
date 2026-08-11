# Angle 5: Generate/Regenerate Mutation and Credit Lifecycle

## Verdict: PASS (with 1 MED finding)

## Round 1 M1 fix verification

**PARTIALLY FIXED.** Round 1 M1 found that generate buttons lacked `loading`/`disabled` props. The fix agent added:
- `const buttonLoading = isLoadingCredits || isGenerating;` at line 45 -- CORRECT
- `renderCreditsAction` Button at line 84: `loading={buttonLoading} disabled={buttonLoading}` -- CORRECT
- Header Regenerate Button at line 353: `loading={buttonLoading} disabled={buttonLoading}` -- CORRECT

**BUT** the stale banner Regenerate button at line 146 (`Styled.StaleAction onClick={handleGenerate}`) is a raw `<button>` element, NOT the `Button` component. It receives no `disabled` or `loading` prop. It can still be double-clicked.

See M1 in Findings below.

## Generate handler

Lines 47-63: Exact copy of `AiSummaryState.tsx` lines 31-47.
- Calls `generate({ jobApplicationId: jobApplication.id }, { onSuccess, onError })` -- CORRECT
- Success toast: "Summary generation queued", kind: "success" -- MATCHES
- Error toast: `error?.data?.errors?.general?.[0] || "Failed to queue summary"`, kind: "warning", delay: 10000 -- MATCHES

## Credit balance

- `useOrganizationAiCreditBalance()` at line 28 -- CORRECT
- `totalRemaining = creditError ? 0 : creditData?.totalCreditsRemaining || 0` at line 44 -- MATCHES analog pattern

## Out-of-credits handling (renderCreditsAction)

- `totalRemaining > 0`: shows Button + credit hint -- CORRECT (lines 81-91)
- Admin: `<Button type="internalLink" link="/hire/settings/ai-billing">` -- MATCHES analog (lines 94-101)
- Non-admin: `<Button onClick={handleBuyCredits}>` opens CenterModal -- MATCHES analog (lines 104-108)
- handleBuyCredits at lines 65-78: modal content matches `AiSummaryState.tsx` lines 68-79

## Credit hint copy

- Empty state: "Uses 1 credit . N remaining" (line 87 via conditional) -- MATCHES spec
- Failed state: "Uses 1 credit" (line 88 via conditional fallback) -- MATCHES spec
- Stale banner: "Regenerate . 1 credit" (line 150 via `&middot;`) -- MATCHES spec

## Action layout

- `Styled.ActionColumn` at line 971: `flex-direction: column; align-items: center; gap: 8px; margin-top: 18px;` -- MATCHES spec requirement for stacked layout, NOT inline.

## WebSocket

No additional WebSocket handling in new components. The existing `WebsocketGlobalChannelHandler` handles `AI_SUMMARY_COMPLETE` and invalidates the relevant queries. CORRECT per spec.

## Findings

### M1 (MED): Stale banner Regenerate lacks double-click protection

**File:** `PlatoTab.tsx` line 146
**What happens:** `Styled.StaleAction` is a raw `<button>` (`styled.button`). It calls `handleGenerate` on click but has no `disabled` state tied to `buttonLoading`. While the header Regenerate `Button` and the `renderCreditsAction` `Button` both received `loading`/`disabled` props in the Round 1 M1 fix, the stale banner's Regenerate was missed because it is not a `Button` component.

**Impact:** Users viewing a stale summary can double-click the stale banner's Regenerate and queue multiple generation requests, each consuming a credit.

**Fix:** Add a disabled check: either pass `disabled={buttonLoading}` as a prop to `Styled.StaleAction` and add `pointer-events: none; opacity: 0.5;` in the styled component when disabled, or replace `Styled.StaleAction` with the `Button` component using `styleType="text"` (matching the header Regenerate pattern).
