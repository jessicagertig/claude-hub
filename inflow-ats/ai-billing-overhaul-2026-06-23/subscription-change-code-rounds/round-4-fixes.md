# Round 4 — Fix Log (subscription-change flow 5)

## D1 — Change-button `buttonType` derived from never-populated `isMostPopular` instead of from button text — FIXED

**Analog:** `buttonType = getPlanButtonType(buttonText)` (`AccountBillingPlans.tsx:186`; `getPlanButtonType` def `planLookups.js:578-584`) maps button TEXT to style: `"Upgrade" | "Start plan" | "Start free trial"` → `"primary"`, else `"secondary"`. It reaches the SCREEN as `styleType={plan.buttonType || "secondary"}` (`PlanCard.tsx:211`). The analog's `PlanCard` declares `isMostPopular?` (`PlanCard.tsx:54`) but never reads it for styling — `buttonType` is sourced exclusively from `buttonText`.

**Ours (before):** `buttonType: !isSubscribed && (tier as any).isMostPopular ? "primary" : "secondary"` (`AiCreditSubscription.tsx:294`). `isMostPopular` is declared (`AiSubscriptionTierCard.tsx:15`) and read (`AiSubscriptionTierCard.tsx:41`) but never produced — `aiCreditPrices` (`planHelpers.ts`) never sets it; zero producers exist. So `buttonType` was always `"secondary"` and an "Upgrade" tier never received primary styling. The analog's sole input (button text) was ignored.

**Fix (analog-faithful, sourcing buttonType from buttonText):**

- Added `deriveTierButtonType(buttonText)` to `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/aiSubscriptionHelpers.ts` mirroring the analog's `getPlanButtonType`: returns `"primary"` for `"Upgrade"` and `"Subscribe"` (the AI-credit start action, analog of the analog's `"Start plan"`/`"Start free trial"`), else `"secondary"`.
  - file:line `aiSubscriptionHelpers.ts:41-52` (new function)
- Imported `deriveTierButtonType` in `AiCreditSubscription.tsx`.
  - file:line `AiCreditSubscription.tsx:25`
- At the tier-card call site, computed `buttonText` once and set `buttonType: deriveTierButtonType(buttonText)` — exactly the analog's `getPlanButtonType(buttonText)` pattern. Removed the `isMostPopular`-gated expression.
  - file:line `AiCreditSubscription.tsx:288, 294-295`

**Terminal:** `styleType={tier.buttonType || "secondary"}` (`AiSubscriptionTierCard.tsx:67`) now renders a primary button for an "Upgrade" (or "Subscribe") tier, matching the analog SCREEN terminal `styleType={plan.buttonType || "secondary"}` (`PlanCard.tsx:211`).

**Note (out of D1 scope, left unchanged):** The dormant `isMostPopular` PromoBadge in `AiSubscriptionTierCard.tsx` (declared `:15`, read for the badge at `:41`) is an EXTRA display element with no analog producer, so it never renders. D1 is scoped to `buttonType` sourcing; removing the badge would be an unscoped change. `buttonType` no longer touches `isMostPopular`, so the finding is resolved. The analog's `PlanCard` also declares an unused `isMostPopular?`, so a dormant declaration is itself analog-consistent.

**Whitelist:** none added — D1 was a genuine structural mismatch (buttonType not sourced from buttonText), not forced by the data model.
