# Angle: Generate/Regenerate Mutation and Credit Balance Lifecycle

## Files checked
- `PlatoTab.tsx` -- `handleGenerate` lines 47-63, `handleBuyCredits` lines 65-78, `renderCreditsAction` lines 80-109, header Regenerate line 353, stale banner Regenerate line 146
- `PlatoOverviewCallout.tsx` -- CTA labels (display-only, no mutation)
- `AiSummaryState.tsx` -- analog lines 31-47 (generate), lines 58-91 (credits)

## Findings

No findings.

## Verification

### Generate mutation
`handleGenerate` (lines 47-63) matches the analog `handleClick` from `AiSummaryState.tsx` lines 31-47 exactly:
- Calls `generate({ jobApplicationId: jobApplication.id })`
- Success toast: `"Summary generation queued"`, `kind: "success"`
- Error toast: `error?.data?.errors?.general?.[0] || "Failed to queue summary"`, `kind: "warning"`, `delay: 10000`

### Double-click protection (all 3 surfaces)
1. **Header Regenerate** (line 353): `loading={buttonLoading} disabled={buttonLoading}` on `<Button>`. Correct.
2. **Stale banner Regenerate** (line 146): `disabled={buttonLoading}` on `<Styled.StaleAction>` (a `<button>` element). The styled component has `&:disabled { opacity: 0.5; pointer-events: none; }` at lines 541-544. Correct (Round 2 fix verified).
3. **Generate/Try again buttons** (line 84): `loading={buttonLoading} disabled={buttonLoading}` on `<Button>`. Correct.

### Credit balance
- `totalRemaining` computed at line 44: `creditError ? 0 : creditData?.totalCreditsRemaining || 0`. Matches analog pattern.
- `buttonLoading` at line 45: `isLoadingCredits || isGenerating`. Both variables are consumed (Round 1 L1/L2 fix verified).

### Credit hint copy
- Empty state (`"Generate summary"`): `"Uses 1 credit · ${totalRemaining} remaining"` (line 87). Matches spec.
- Failed state (not `"Generate summary"`): `"Uses 1 credit"` (line 88). Matches spec.
- Stale banner: `"Regenerate · 1 credit"` (line 150, uses `&middot;` entity). Matches spec.

### Stacked layout
`Styled.ActionColumn` (line 975-982): `flex-direction: column; align-items: center; gap: 8px; margin-top: 18px;`. Credit hint is stacked below button, NOT inline. Matches spec.

### Zero credits handling
- Admin: `<Button type="internalLink" link="/hire/settings/ai-billing">` (line 97). Matches analog.
- Non-admin: `<Button onClick={handleBuyCredits}>` (line 106) opens `CenterModal` (lines 65-78). Content matches analog. `Styled.ModalBody` and `Styled.ModalActions` match `AiSummaryState.tsx` lines 205-221.

### Callout does NOT trigger mutation
`PlatoOverviewCallout.tsx`: `onClick={onOpen}` is on the card (line 54). No `handleGenerate` call exists in the component. The "Generate" CTA label (line 46) is display-only text. Correct per spec.
