# Angle 5: Generate/Regenerate Mutation and Credit Balance Lifecycle

## Findings

### M1 (MED): Generate/Try again/Regenerate buttons lack loading and disabled props

The analog `AiSummaryState.tsx` lines 96-99 passes both `loading={buttonLoading}` and `disabled={buttonLoading}` to the Generate button, preventing double-clicks while the mutation is in flight. The `AiJobApplicationSummaryFeedItem.tsx` lines 94-95 does the same for its retry button.

PlatoTab.tsx declares `isGenerating` (line 27) from `useGenerateAiSummary()` but never uses it. None of the `<Button>` elements at lines 83, 96, 105, 352 pass `loading` or `disabled` props.

This means:
1. Users can double-click "Generate summary" / "Try again" and queue multiple generation requests
2. Users can click "Regenerate" in the header or stale banner during an in-flight request
3. There is no visual loading indicator on the button during mutation

The plan review flagged this as LOW ("UX polish, not a spec requirement"). The spec does not explicitly require these props. However, the analog explicitly includes them, and double-generating wastes credits. Classifying as MED because it wastes user credits and the analog's pattern was not followed.

### handleGenerate replicates analog correctly

The `handleGenerate` function (lines 46-62) is a faithful copy of `AiSummaryState.tsx` `handleClick` (lines 31-47):
- Same success toast: "Summary generation queued" with `kind: "success"`
- Same error toast: `error?.data?.errors?.general?.[0] || "Failed to queue summary"` with `kind: "warning"` and `delay: 10000`
- Same mutation call: `generate({ jobApplicationId: jobApplication.id }, { onSuccess, onError })`

### Credit balance display -- correct

`totalRemaining` computed at line 44: `creditError ? 0 : creditData?.totalCreditsRemaining || 0` -- matches analog pattern.

`renderCreditsAction` (lines 79-108) correctly handles three cases:
1. Credits > 0: Button + credit hint text
2. Zero credits + admin: internalLink button to `/hire/settings/ai-billing`
3. Zero credits + non-admin: button that opens modal

### Credit hint copy -- correct per spec

- Empty state: `"Uses 1 credit . ${totalRemaining} remaining"` (line 86) -- matches spec
- Failed state: `"Uses 1 credit"` (line 87) -- matches spec
- Stale banner: `"Regenerate . 1 credit"` (line 149 via `&middot;`) -- matches spec

### Credit hint layout -- correct

`Styled.ActionColumn` (lines 970-977): `flex-direction: column; align-items: center; gap: 8px; margin-top: 18px;` -- stacked below the button, not inline. Matches spec requirement.

### Buy-credits modal -- correct

`handleBuyCredits` (lines 64-77) matches the analog `AiSummaryState.tsx` lines 68-79. Same `CenterModal`, same copy, same Close button pattern. `Styled.ModalBody` and `Styled.ModalActions` match the analog's styled components.

### Callout does NOT trigger generate -- correct

PlatoOverviewCallout.tsx: the card always calls `onOpen()` on click (line 54). No generate mutation is imported or used in this component. The "Generate" CTA is display-only text.
