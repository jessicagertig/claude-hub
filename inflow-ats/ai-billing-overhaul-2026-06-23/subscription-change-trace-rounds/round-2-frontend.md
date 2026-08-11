# Round 2 — Frontend segment audit (AccountBillingPlans.tsx → useBilling.ts → planLookups.js → api.ts → SCREEN)

Worktree: /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza

Chain traced: AccountBilling.tsx → AccountBillingPlans.tsx → PlanCard.tsx / useBilling.ts → api.ts → planLookups.js

Overall: the trace's frontend line numbers and identifier names are almost entirely correct. The discrepancies below are (a) two real structural omissions (PlanCard's current-plan/free branch that gates the change button; the free-plan filter before the map; the `.data` unwrap of billingPrices in the parent), (b) one stopped-short thread the trace declared "not opened" but is trivially resolvable, and (c) a few precise-line / wording slips.

---

DISCREPANCY 1 (STRUCTURAL — change button is conditionally rendered; trace presents it as always rendered)
TRACE SAYS (item 16): "`plansWithButtonText.map` renders `<PlanCard ... />` ... Inside `PlanCard.tsx` the change button is `Styled.Button` (`PlanCard.tsx:207-214` ...) `onClick={handleOnClickSubscriptionAction}`" — presented as the unconditional render path to the change handler.
ACTUAL CODE: PlanCard branches at `PlanCard.tsx:199` — `{isCurrentPlan || isFreePlan ? (<ManageBillingActions .../>) : (<Styled.Button .../>)}`. The `Styled.Button` that fires `handleOnClickSubscriptionAction` only renders in the ELSE branch (`:206-215`). When `isCurrentPlan` or `isFreePlan`, PlanCard renders `ManageBillingActions` instead and there is NO change button. The trace omits this gate entirely.
file:line: /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountBilling/PlanCard.tsx:199-215

DISCREPANCY 2 (STRUCTURAL — free plan filtered out before the map; trace omits)
TRACE SAYS (item 16): "`plansWithButtonText.map` renders ..." — implies all plans from `plansWithButtonText` reach a PlanCard.
ACTUAL CODE: `plansWithButtonText` is built from `plans.filter((plan) => plan.key !== "free").map(...)` at `AccountBillingPlans.tsx:177-178`. The free plan (`key === "free"`) is filtered out before button-text mapping and before the render `.map`. The trace never mentions this `.filter`.
file:line: /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:177-178

DISCREPANCY 3 (STOPPED-SHORT THREAD — parent component IS resolvable; `billingPrices` prop is `.data`-unwrapped, not the raw render payload)
TRACE SAYS (Unresolved identifiers, line 146): "The ancestor component that calls `useBillingPrices` and passes `billingPrices` down to `AccountBillingPlans` was not opened; the hook/endpoint chain producing the data is confirmed, but not the exact parent file." And item 13: "`render json: price_list` (`:540`, `billingPrices` prop, SCREEN terminal)" — implies the rendered payload is the prop.
ACTUAL CODE: parent is `AccountBilling.tsx`. It calls `useBillingPrices(...)` at `:50` (`const { data: billingPricesData, ... } = useBillingPrices(...)`), then unwraps `const billingPrices = billingPricesData != undefined ? billingPricesData.data : []` at `:54`, and passes `billingPrices={billingPrices}` to `<AccountBillingPlans>` at `:129-134`. The prop is `billingPricesData.data` (with `[]` fallback), NOT the raw hook/render payload. The trace's prices chain stops one hop short and mislabels the prop source.
file:line: /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBilling.tsx:50, :54, :129-134

DISCREPANCY 4 (IDENTIFIER/WORDING — destructured `data` is renamed; trace shows plain `data`)
TRACE SAYS (item 9): "The `{ data, isFetching: isFetchingStripeCustomerSubscription }` destructure (`AccountBillingPlans.tsx:56-61`)".
ACTUAL CODE: the destructure renames `data`: `const { data: stripeCustomerSubscriptionData, isFetching: isFetchingStripeCustomerSubscription } = useStripeCustomerSubscription({ refetchOnWindowFocus: false })`. `currentSubscription` is then derived at `:62-64` as `stripeCustomerSubscriptionData ? stripeCustomerSubscriptionData.subscription : null`. The trace's `{ data, ... }` and its claim "Frontend reads `currentSubscription` — `AccountBillingPlans.tsx:62`" skip the `stripeCustomerSubscriptionData` intermediate.
file:line: /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:56-64

DISCREPANCY 5 (WRONG LINE — onClick binding cited at the handler-definition line)
TRACE SAYS (item 16): "`onClick={handleOnClickSubscriptionAction}` (`PlanCard.tsx:98`)".
ACTUAL CODE: `:98` is where `handleOnClickSubscriptionAction` is DEFINED (`const handleOnClickSubscriptionAction = () => {`). The `onClick={handleOnClickSubscriptionAction}` JSX binding is at `:208`. Also at `:99` the handler first calls `trackEvent("plan_selected", {...})` before branching on `hasActiveSubscription` (`:100`) — the trace omits this `trackEvent` call.
file:line: /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountBilling/PlanCard.tsx:98 (def), :99 (trackEvent), :208 (onClick binding)

DISCREPANCY 6 (WORDING — `currentPriceObject` / `currentSubscriptionItemId` access is guarded, trace shows unconditional)
TRACE SAYS (item 9): "`currentSubscriptionItemId = currentSubscription.items.data[0].id` — `AccountBillingPlans.tsx:136`; `currentPriceObject = currentSubscription.items.data[0].price` — `AccountBillingPlans.tsx:67`".
ACTUAL CODE: both are short-circuit guarded. `:67` = `const currentPriceObject = currentSubscription && currentSubscription.items.data[0].price;`. `:136` = `const currentSubscriptionItemId = currentSubscription && currentSubscription.items.data[0].id;`. The trace drops the `currentSubscription &&` guard, presenting the array access as unconditional. Lines are correct; the expression shape is misstated.
file:line: /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:67, :136

DISCREPANCY 7 (LINE PRECISION — `plansWithButtonText` not at `:175`)
TRACE SAYS (item 15): "`plans / plansWithButtonText` — `AccountBillingPlans.tsx:175` (each plan carries `priceId`, `lookupKey`, `key`)".
ACTUAL CODE: `const plans = getPlansForPeriod(billingPeriod, billingPrices);` is at `:175`, but `plansWithButtonText` is defined at `:177-193` (`const plansWithButtonText = plans.filter(...).map((plan) => { ... return { ...plan, buttonText, buttonType }; })`). Lumping both at `:175` is wrong for `plansWithButtonText`; the `...plan` spread (carrying `priceId`/`lookupKey`/`key`) is at `:189`.
file:line: /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:175, :177-193

DISCREPANCY 8 (TERMINAL DETAIL — `isCurrentPlan` derivation feeding the render branch is undocumented)
TRACE SAYS: nothing — item 16 jumps from the map directly to the PlanCard change button.
ACTUAL CODE: inside the map at `:436`, `const isCurrentPlan = currentSubscription?.plan?.id === plan.priceId;` is computed and passed as `isCurrentPlan={isCurrentPlan}` (`:443`). This boolean is what drives PlanCard's `:199` branch (Discrepancy 1) — i.e. it is the SCREEN gate that decides whether a plan shows the change button or `ManageBillingActions`/`Current plan` badge. The trace omits this load-bearing computation between the map and the button.
file:line: /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:436, :443
