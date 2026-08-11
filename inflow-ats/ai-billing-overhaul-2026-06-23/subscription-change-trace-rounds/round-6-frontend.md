# Round 6 — Adversarial Audit: FRONTEND chain to the SCREEN

Reviewer: "frontend". Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.
Segment: `AccountBillingPlans.tsx`, `useBilling.ts`, `planLookups.js`, `api.ts`, plus the `PlanCard.tsx` / `AccountBilling.tsx` render terminals the frontend chain reaches.

Files traced this round (all confirmed read against current code):
`AccountBilling.tsx -> AccountBillingPlans.tsx -> useBilling.ts -> api.ts -> planLookups.js -> PlanCard.tsx`
`config/routes.rb` (route line numbers only, for the apiGet/apiPost endpoints).

## Verdict

The trace's frontend segment is overwhelmingly accurate at the line-number / identifier level. Every cited line for `useBilling.ts` (46, 55-57, 61-74, 98, 102, 181, 189, 194, 202, 245, 266), `api.ts` (5, 22, 25-28, 40-68, 50, 52, 56, 67), `planLookups.js` (3, 553, 554, 555-557, 560, 564, 568, 569, 571, 578, 594), `AccountBilling.tsx` (50, 54, 122-134), `AccountBillingPlans.tsx` (34-39, 41, 56-64, 67-76, 136-142, 158-170, 175-193, 195-209, 243-278, 283-294, 303, 305-314, 322-348, 352-354, 370-396, 408/413, 424-431, 435-457), and `PlanCard.tsx` (95, 98-105, 151, 199, 200-205, 207-214) was verified correct. Route lines 169/170/174/177/178 verified correct.

The discrepancies below are WRONG-TERMINAL and OMITTED-THREAD findings, not wrong line numbers. The two `currentPlanLookupKey` / `currentPlanBillingPeriod` "SCREEN terminal" claims (D1, D2) are the only outright-WRONG claims; the rest are threads the trace stops short of, or props it presents as live data flow that are actually dead.

---

### D1 — `currentPlanBillingPeriod` passed to PlanCard is a DEBUG-LOGGER terminal, not a SCREEN terminal

TRACE SAYS (item 9): "`currentPlanBillingPeriod` ... is passed `currentPlanBillingPeriod={currentPlanBillingPeriod}` to every `<PlanCard>` (`:445`, SCREEN terminal)."

ACTUAL CODE: Inside `PlanCard.tsx`, `currentPlanBillingPeriod` is destructured (`PlanCard.tsx:80`) and its ONLY consumer is the `window.logger("%c[PlanCard] render", ...)` debug object (`PlanCard.tsx:157`). It is never referenced in PlanCard's JSX. The terminal inside PlanCard is `window.logger`, NOT the SCREEN. (The prop IS passed at `AccountBillingPlans.tsx:445` — that part is correct.)

file:line: `PlanCard.tsx:80`, `PlanCard.tsx:157` (no JSX use)

---

### D2 — `currentPlanLookupKey` passed to PlanCard reaches PostHog/logger, not a SCREEN render

TRACE SAYS (item 9): "`currentPlanLookupKey = currentPriceObject?.lookupKey` (`:68`) is passed `currentPlanLookupKey={currentPlanLookupKey}` to every `<PlanCard>` (`:444`, SCREEN terminal)."

ACTUAL CODE: Inside `PlanCard.tsx`, `currentPlanLookupKey` is destructured (`PlanCard.tsx:79`) and consumed only by (a) `trackEvent("plan_selected", { current_plan_lookup_key: currentPlanLookupKey, ... })` (`PlanCard.tsx:99`, a PostHog analytics terminal) and (b) the `window.logger` debug object (`PlanCard.tsx:156`). Neither is a SCREEN render. The prop never reaches JSX inside PlanCard. (`currentPlanLookupKey` DOES reach a real SCREEN terminal via a different path — `getPlanButtonText(currentPriceObject.lookupKey, ...)` at `AccountBillingPlans.tsx:181` producing the button label — but that is the local `currentPriceObject.lookupKey`, not the prop threaded into PlanCard.)

file:line: `PlanCard.tsx:79`, `PlanCard.tsx:99`, `PlanCard.tsx:156`

---

### D3 — `subscriptionItemId` prop passed to PlanCard is a DEAD/unused prop

TRACE SAYS (item 9): "`currentSubscriptionItemId = currentSubscription && currentSubscription.items.data[0].id` (`AccountBillingPlans.tsx:136`, the value passed as `subscriptionItemId` to `PlanCard` and into both change handlers ...)." Item 16: "passing ... `subscriptionItemId={currentSubscriptionItemId}` (`:449`)."

ACTUAL CODE: `subscriptionItemId` is declared in `PlanCardProps` (`PlanCard.tsx:71`) but is NOT destructured in the component parameter list (`PlanCard.tsx:75-89`) and is never referenced in PlanCard's body (grep confirms the only occurrence in the file is the interface declaration at line 71). The prop passed at `AccountBillingPlans.tsx:449` is therefore inert — PlanCard never reads it. The `currentSubscriptionItemId` that actually reaches the backend is the closure-captured value read directly inside `handleChangeSubscriptionWithGate` (`AccountBillingPlans.tsx:329` and `:334`), NOT anything routed through PlanCard. The trace presents the PlanCard prop as part of the data flow ("the value passed as `subscriptionItemId` to `PlanCard`") without noting it is a dead prop — the item-id flow to the backend does not pass through PlanCard at all.

file:line: `PlanCard.tsx:71` (declared), absent from `PlanCard.tsx:75-89` (not destructured), `AccountBillingPlans.tsx:329`/`:334` (real source via closure)

---

### D4 — `isCurrentPlan` has an additional SCREEN terminal the trace omits (the "Current plan" badge)

TRACE SAYS (item 9 / item 16): `isCurrentPlan = currentSubscription?.plan?.id === plan.priceId` (`:436`) is "the per-PlanCard SCREEN gate that selects `ManageBillingActions` vs the change `Styled.Button`." The trace documents only the `ManageBillingActions` vs `Styled.Button` branch (`PlanCard.tsx:199`).

ACTUAL CODE: Inside PlanCard, `isCurrentPlan` also feeds `const showCurrentPlanBadge = isCurrentPlan || isFreePlan` (`PlanCard.tsx:160`), which gates THREE additional SCREEN renders: the `<SavingsBadge>Current plan</SavingsBadge>` (`PlanCard.tsx:167`), the savings `<Tooltip>` "You are saving $X per year" (`PlanCard.tsx:168-176`), and the `!showCurrentPlanBadge && savings > 0` `<SavingsBadge>Save $X/year</SavingsBadge>` (`PlanCard.tsx:177-179`). The trace stops `isCurrentPlan` at the button-branch terminal and omits the `showCurrentPlanBadge` SCREEN terminals.

file:line: `PlanCard.tsx:160`, `PlanCard.tsx:167`, `PlanCard.tsx:168-176`, `PlanCard.tsx:177-179`

---

### D5 — `plan.price` (the `: 0` fallback) thread stops at planLookups.js:564; trace never follows it to its SCREEN render

TRACE SAYS (item 14): "`price: priceData ? priceData.unitAmount / 100 : 0` (`:564`, the `: 0` fallback ... renders on SCREEN)." The trace asserts it "renders on SCREEN" but never names where.

ACTUAL CODE: `plan.price` flows into PlanCard and is consumed by `const displayPrice = billingPeriod === "yearly" ? Math.round(plan.price / 12) : plan.price` (`PlanCard.tsx:90`) and `const savings = billingPeriod === "yearly" ? Math.round((plan.price / 12) * 2) : 0` (`PlanCard.tsx:91`). `displayPrice` renders at `${displayPrice}` (`PlanCard.tsx:183`, SCREEN terminal); `savings` renders at "Save ${savings}/year" (`PlanCard.tsx:178`) and "You are saving ${savings} per year" (`PlanCard.tsx:170`, SCREEN terminals). The trace claims a SCREEN terminal exists but stops the thread two hops short (at `planLookups.js:564`), never reaching `displayPrice`/`savings` or the `${displayPrice}` JSX.

file:line: `PlanCard.tsx:90`, `PlanCard.tsx:91`, `PlanCard.tsx:183`, `PlanCard.tsx:170`, `PlanCard.tsx:178`

---

### D6 — `useChangeSubscriptionViaStripePortal` / `useUpdateWithPaymentMethod` onSuccess emit a `window.logger`; trace lists only the invalidateQueries terminal

TRACE SAYS (item 18): "`useChangeSubscriptionViaStripePortal` (hook) — `useBilling.ts:181`; `onSuccess` invalidates `queryClient.invalidateQueries(['currentOrganization'])` (`:189`)." (Item 18b analogous for `useUpdateWithPaymentMethod` `:202`.)

ACTUAL CODE: Each hook's `onSuccess` first calls `window.logger("%c[useBilling] useChangePlanStripePortalSession", ...)` (`useBilling.ts:185-188`) BEFORE the invalidate at `:189`; `useUpdateWithPaymentMethod` likewise logs at `useBilling.ts:198-201` before invalidating at `:202`. The trace omits the logger statement that precedes each invalidate. (Minor — the invalidate line numbers are correct.)

file:line: `useBilling.ts:185-188`, `useBilling.ts:198-201`

---

## Notes (verified-correct, no discrepancy)

- `getPlanButtonText` (`planLookups.js:594`) terminal logic verified: signature `(currentPlanLookupKey, targetPlanLookupKey, targetPeriod)`, fallback `"Change plan"` at `:608`, `"Upgrade"`/`"Change plan"` at `:618` — matches the trace's button-label SCREEN-terminal claim (`PlanCard.tsx:213`).
- `getPlanButtonType` (`planLookups.js:578`) `"primary"`/`"secondary"` resolution verified; feeds `styleType={plan.buttonType || "secondary"}` (`PlanCard.tsx:211`) — matches.
- `apiGet` `allKeysToCamel` at `api.ts:22` and `apiMutate` `allKeysToSnake`(`:52`)/`allKeysToCamel`(`:67`/`:56`) verified; `price_id`/`subscription_item_id`/`return_url` snake-conversion claim is structurally correct (transform applied to the whole `variables` object).
- The 3-way conditional render gate in `AccountBilling.tsx:122-135` verified exactly as the trace describes (FreeTrial / AccountBillingPlans / Unsubscribed).
- `billingPrices = billingPricesData != undefined ? billingPricesData.data : []` (`AccountBilling.tsx:54`) `[]`-fallback verified.
