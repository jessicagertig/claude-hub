# Implementation Round 2: FAILURE-REPORT

This implementation has 1 MED finding and requires revision before it can pass.

---

## M1 (MED): Stale banner Regenerate button lacks double-click protection

**File:** `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx`
**Lines:** 146-151

### What the Round 1 fix addressed

Round 1 M1 found that generate buttons lacked `loading`/`disabled` props. The fix agent:
1. Added `const buttonLoading = isLoadingCredits || isGenerating;` at line 45
2. Added `loading={buttonLoading} disabled={buttonLoading}` to the `Button` in `renderCreditsAction` (line 84)
3. Added `loading={buttonLoading} disabled={buttonLoading}` to the header Regenerate `Button` (line 353)

### What the fix missed

The stale banner's Regenerate button at lines 146-151 is a `Styled.StaleAction` -- a raw `styled.button`, NOT the `Button` component:

```tsx
<Styled.StaleAction onClick={handleGenerate}>
  <Styled.StaleActionIcon>
    <Icon name="refresh-cw" />
  </Styled.StaleActionIcon>
  Regenerate &middot; 1 credit
</Styled.StaleAction>
```

This button has no `disabled` prop, no `loading` state, and no visual feedback during generation. It calls `handleGenerate` directly on every click.

### Why this was missed

The Round 1 FAILURE-REPORT listed three surfaces: `renderCreditsAction` line 83, header Regenerate line 352, and "Stale banner action line 145: add `disabled={isGenerating}` or similar guard." The fix agent addressed the first two (which use the `Button` component) but did not address the third (which is a different element type requiring a different approach).

### Impact

Users viewing a stale summary can click the Regenerate button in the stale banner multiple times while a generation is in progress. Each click fires `handleGenerate`, queuing another generation request and consuming a credit.

### Fix

**Option A (minimal):** Add a `disabled` prop to `Styled.StaleAction` and wire it to `buttonLoading`:

```tsx
<Styled.StaleAction onClick={handleGenerate} disabled={buttonLoading}>
```

And add disabled styles in the styled component:

```tsx
Styled.StaleAction = styled.button((props: any) => {
  const t: any = props.theme;
  return css`
    label: PlatoTab_StaleAction;
    /* ...existing styles... */

    &:disabled {
      opacity: 0.5;
      pointer-events: none;
    }
  `;
});
```

Native `<button>` elements support `disabled` natively, which prevents click events.

**Option B (consistent):** Replace `Styled.StaleAction` with the `Button` component using `styleType="text"`, matching the header Regenerate pattern at line 353. This would require minor styling adjustments to match the stale banner's compact inline layout.
