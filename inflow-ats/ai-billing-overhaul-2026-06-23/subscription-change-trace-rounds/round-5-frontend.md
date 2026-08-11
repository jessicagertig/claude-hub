# Round 5 — Frontend chain audit (AccountBillingPlans.tsx, useBilling.ts, planLookups.js, api.ts, PlanCard.tsx)

Reviewer: ADVERSARIAL "frontend". Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.

Files traced:
`AccountBilling.tsx → AccountBillingPlans.tsx → useBilling.ts → api.ts → (planLookups.js) → PlanCard.tsx`, plus the camel/snake transform boundary `api.ts → @ats/src/lib/utils/structure`.

Overall: the trace's line-number and identifier mapping for the frontend segment is unusually accurate — nearly every `file:line` claim verified exactly (hooks at useBilling.ts:181/194/245/266; consts at :46/:61/:98/:102; apiGet api.ts:5/:22; apiMutate api.ts:40-68 with CSRF :50, allKeysToSnake :52, allKeysToCamel :56/:67; getPlansForPeriod planLookups.js:553-571; PlanCard branch :199 / Styled.Button :207-214 / handleOnClickSubscriptionAction :98-105; AccountBillingPlans handlers :243-278 / :283-317 / :322-350; PlanCard props :439-456; AccountBilling.tsx 3-way ternary :122-146). The discrepancies below are the ones found.

---

## Discrepancy 1 — `currentProductPrice` is NOT a SCREEN terminal (wrong terminal)

TRACE SAYS (item 9): "The ONLY SCREEN fallback actually downstream of this `currentPriceObject` guard is `currentProductPrice` (`AccountBillingPlans.tsx:137-142`, gated by `currentPriceObject != undefined`), which is a NESTED ternary ... the TIERED SCREEN branch reads `currentPriceObject.tiers[0].unitAmount / 100.0` (`:140`, a distinct field/value-to-SCREEN path), the non-tiered branch reads `currentPriceObject.unitAmount / 100.0` (`:141`); `null` (`:142`) is the no-price-object fallback." — i.e. it labels `currentProductPrice` and its tiered/non-tiered branches as paths that render on the SCREEN.

ACTUAL CODE: `currentProductPrice` is defined at AccountBillingPlans.tsx:137-142 but its ONLY consumer is the debug call `window.logger("%c[AccountBillingPlans] render", ..., { ... currentProductPrice ... })` at AccountBillingPlans.tsx:200 (inside the logger object literal :195-209). It is never referenced in JSX and never reaches the screen. Its terminal is a `window.logger` debug call, not the SCREEN. The "TIERED SCREEN branch"/"value-to-SCREEN path" characterization is a wrong terminal.

file:line — AccountBillingPlans.tsx:137-142 (def) and :200 (sole consumer, window.logger)

---

## Discrepancy 2 — False "ONLY ... downstream of this guard" claim; other consts derive from `currentPriceObject` and DO reach the SCREEN

TRACE SAYS (item 9): "The ONLY SCREEN fallback actually downstream of this `currentPriceObject` guard is `currentProductPrice`".

ACTUAL CODE: Multiple other consts are derived from `currentPriceObject` and several DO reach the screen as PlanCard props (whereas `currentProductPrice` does not):
- `currentPlanLookupKey = currentPriceObject?.lookupKey` (AccountBillingPlans.tsx:68) → passed `currentPlanLookupKey={currentPlanLookupKey}` to `<PlanCard>` (:444), and used in `getPlanButtonText(currentPriceObject.lookupKey, ...)` (:181) producing the rendered button label.
- `currentPlanBillingInterval = currentPriceObject?.interval || currentPriceObject?.recurring?.interval` (:69-70) → feeds `currentPlanBillingPeriod`.
- `currentPlanBillingPeriod` (:71-76) → passed `currentPlanBillingPeriod={currentPlanBillingPeriod}` to `<PlanCard>` (:445); also `currentPriceObject?.interval || currentPriceObject?.recurring?.interval` is rendered directly in the legacy-plan copy at :408/:413.
So "ONLY ... downstream of this guard is currentProductPrice" is false: currentProductPrice is NOT a screen terminal, and these sibling consts ARE.

file:line — AccountBillingPlans.tsx:68, :69-70, :71-76, :181, :408, :413, :444-445

---

## Discrepancy 3 — Trace omits `getPlanButtonText` / `getPlanButtonType` from the chain to the SCREEN (rendered button label/type)

TRACE SAYS (item 15): "`plansWithButtonText` is then built at `AccountBillingPlans.tsx:177-193`: `plans.filter(...).map((plan) => { ... return { ...plan, buttonText, buttonType }; })`". The trace names `buttonText`/`buttonType` only as spread fields and never names the functions that produce them or traces them to the SCREEN.

ACTUAL CODE: `buttonText` is produced by `getPlanButtonText(currentPriceObject.lookupKey, plan.lookupKey, billingPeriod)` (AccountBillingPlans.tsx:181, def `planLookups.js:594`) with fallbacks `"Upgrade"` / `"Change plan"` (:182-184); `buttonType` is produced by `getPlanButtonType(buttonText)` (:186, def `planLookups.js:578`). Both are imported at AccountBillingPlans.tsx:34. These feed PlanCard's rendered button: `{plan.buttonText}` (PlanCard.tsx:213) and `styleType={plan.buttonType || "secondary"}` (:211) — a SCREEN terminal (the visible button label and visual style). The trace stops short of these two identifiers and their SCREEN terminal.

file:line — AccountBillingPlans.tsx:34 (import), :180-186; planLookups.js:578 (getPlanButtonType), :594 (getPlanButtonText); PlanCard.tsx:211, :213

---

## Discrepancy 4 — Trace omits the multiple SCREEN terminals of `currentSubscription` (trialing / cancelAtPeriodEnd / coupon render branches)

TRACE SAYS (item 9): traces `currentSubscription` (`:62-64`) only into `currentPriceObject`, `currentSubscriptionItemId`, `currentProductPrice`, and `isFetching...`; under the stated goal of mapping "every component, hook, const, variable, prop, to where data renders on the screen."

ACTUAL CODE: `currentSubscription` has several additional SCREEN-render terminals the trace does not enumerate:
- `currentSubscription?.status === "trialing"` gates a `<CurrentSubscription>` block rendering `prettyDate(currentSubscription.trialEnd)` (AccountBillingPlans.tsx:370-382).
- `currentSubscription?.cancelAtPeriodEnd` gates a block rendering `prettyDate(currentSubscription.cancelAt)` (:384-396).
- `isTrialing` (:158-161) and `trialEndDays` (:163) derive from `currentSubscription` and render at :415.
- `hasCoupon`/`discount`/`coupon` (:165-170) derive from `currentSubscription` and render `{coupon.percentOff}% off until {prettyDate(discount.end)}` (:424-431).
- `isCurrentPlan = currentSubscription?.plan?.id === plan.priceId` (:436) — the SCREEN gate that selects ManageBillingActions vs the change Button in PlanCard.

file:line — AccountBillingPlans.tsx:158-170, :370-396, :415, :424-431, :436

---

## Discrepancy 5 — `currentProductPrice` described as "the no-price-object fallback" `null` reaching SCREEN; actually only logged

TRACE SAYS (item 9): "`null` (`:142`) is the no-price-object fallback." framed within the SCREEN-fallback narrative.

ACTUAL CODE: The `null` branch at AccountBillingPlans.tsx:142 is the else of the `currentProductPrice` ternary, whose only consumer is `window.logger` (:200). There is no SCREEN fallback here at all; the `null` is logged, never rendered. (Restatement of the root error in Discrepancy 1, called out separately because the trace presents the `null` branch as a SCREEN terminal.)

file:line — AccountBillingPlans.tsx:142, :200
