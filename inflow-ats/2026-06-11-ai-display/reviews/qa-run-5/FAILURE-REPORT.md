# QA Run 5 -- Layer 1 Failure Report

**Layer:** diff-to-spec
**Round:** 1
**Agents dispatched:** 5
**Findings:** 1 HIGH

## HIGH findings requiring fixes

### l1-001 -- PlatoOverviewCallout connector tick clipped by overflow:hidden
**File:** app/javascript/ats/src/views/jobApplications/PlatoOverviewCallout.tsx
**Lines:** 97 (overflow:hidden), 104-113 (::after pseudo-element)
Styled.Card has overflow:hidden to contain the absolutely-positioned gradient bar. The connector tick ::after at top:100% is clipped invisible. The analog (Styled.Event) does not use overflow:hidden.
**Fix:** Remove overflow:hidden. Add border-radius to Styled.Bar left corners to contain it within the rounded card edges.

## Fix applied
Commit pending: removed overflow:hidden from Styled.Card, added border-radius to Styled.Bar left corners matching t.poly.radii.md.
