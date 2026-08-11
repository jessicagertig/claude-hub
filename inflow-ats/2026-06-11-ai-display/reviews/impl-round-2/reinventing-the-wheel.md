# Angle 10: Reinventing the Wheel

## Verdict: PASS

## Patterns reused from analogs

1. **Generate handler** -- Exact copy from `AiSummaryState.tsx` lines 31-47. Toast messages, error extraction path, toast kinds and delays all match. NOT reinvented.

2. **Credit balance / out-of-credits** -- Follows `AiSummaryState.tsx` lines 49-108 pattern. Admin link, non-admin modal, credit check logic all match. NOT reinvented.

3. **Modal body/actions** -- `Styled.ModalBody` and `Styled.ModalActions` match `AiSummaryState.tsx` lines 205-221. NOT reinvented.

4. **Tab container structure** -- `Styled.Container`/`Styled.Header`/`Styled.Body` follows `JobApplicationActivity.tsx` `Styled.Container`/`Styled.Title`/`Styled.Feed` pattern. NOT reinvented.

5. **NavItem linkStyles** -- Copied verbatim from `NavItem.tsx` lines 56-95. NOT reinvented.

6. **StyledLabel pattern** -- `PlatoNavLabel` adapted from `NavItem.tsx` lines 103-118 with appropriate selector changes for `<span>` vs `<svg>`. NOT reinvented.

7. **Activity feed connector** -- `::after` pseudo-element matches `Styled.Event` pattern from `JobApplicationActivity.tsx` lines 666-677. NOT reinvented.

8. **Eyebrow style** -- Follows `AiJobApplicationSummaryFeedItem.tsx` `Styled.SectionTitle` pattern (lines 317-326) with the spec-specified upgrade to `secondaryText` token. NOT reinvented.

9. **PlatoMark SVG paths** -- Taken from design handoff `PlatoMark.jsx`. NOT reinvented.

10. **Key skill sorting** -- Uses the prototype's sort logic from `ai-tab.jsx` line 247. NOT reinvented.

## Custom patterns (justified)

1. **Shimmer/dot animations** -- New to the codebase (no prior CSS keyframe animation for loading states exists). Uses Emotion `keyframes` import following the `Button/index.js` pattern. JUSTIFIED.

2. **`prefers-reduced-motion`** -- New convention for the codebase. Spec explicitly requires it. JUSTIFIED.

3. **Button-as-card (callout)** -- Spec acknowledges "no existing card-as-button analog exists." New accessible pattern. JUSTIFIED.

## Findings

None.
