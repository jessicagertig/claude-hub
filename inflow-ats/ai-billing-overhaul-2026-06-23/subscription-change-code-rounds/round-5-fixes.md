# Round 5 — Fix Log (subscription-change code)

## D1 — EXTRA isMostPopular-gated PromoBadge ("Most popular") SCREEN element with no analog counterpart

**FIXED** — `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiSubscriptionTierCard.tsx`

Removed both the EXTRA render branch and the EXTRA styled component so the static skeleton matches the analog `PlanCard.tsx`, which only DECLARES `isMostPopular?` (line 54) and never reads it.

- Removed the render branch at former lines 41-43:
  `{!isCurrentPlan && tier.isMostPopular && (<Styled.PromoBadge>Most popular</Styled.PromoBadge>)}`
- Removed the `Styled.PromoBadge` styled component definition (former lines 212-227, `AiSubscriptionTierCard_PromoBadge`).
- KEPT the interface field `isMostPopular?: boolean;` (line 15) — this MATCHES the analog `PlanCard.tsx:54`, which also declares the optional field without reading it. Removing the field would be a deviation in the other direction (analog has it declared-only).

Result: `AiSubscriptionTierCard.tsx` now contains exactly one occurrence of `isMostPopular` — the interface declaration at line 15 — with zero reads, zero render branches, and no `PromoBadge` styled component, structurally identical to the analog `PlanCard.tsx` (declared-only field, no `PromoBadge` skeleton).

Not forced by the data model: `isMostPopular` has zero producers anywhere in `app/` (`aiCreditPrices`/`planHelpers.ts` never set it), so the branch was always falsy and rendered nothing. Removing the EXTRA skeleton is a pure structural match with no behavior change and no regression. Not whitelisted.
