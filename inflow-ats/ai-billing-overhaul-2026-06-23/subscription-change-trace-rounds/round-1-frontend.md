# Round 1 — Frontend Segment — Adversarial Audit of subscription-change-analog-trace.md

Reviewer: "frontend". Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.

Segment: the FRONTEND chain to the SCREEN and to where requests leave for the backend —
`AccountBillingPlans.tsx`, `useBilling.ts`, `planLookups.js`, `api.ts`.

Chains traced:
- `AccountBillingPlans.tsx` → `PlanCard.tsx` → `handleChangeSubscriptionWithGate` → `usePlanLimitsGate.ts` (gate) / `handleChangeSubscriptionViaStripePortal` OR `handleUpdateWithPaymentMethod` → `useBilling.ts` (`changeSubscriptionViaStripePortal` / `updateWithPaymentMethod`) → `api.ts` (`apiPost` → `apiMutate` → `allKeysToSnake`) → `config/routes.rb`
- `AccountBillingPlans.tsx` → `useStripeCustomerSubscription` → `getStripeCustomerSubscription` → `api.ts` `apiGet` (`allKeysToCamel`) → route `customer_subscription`
- `AccountBillingPlans.tsx` → `getPlansForPeriod` (`planLookups.js`) → `currentOrganizationPlanOptions` / `billingPrices`

---

## D1 — Change-call chain OMITS the plan-limits gate (`usePlanLimitsGate` / `checkPlanLimitsGate`) entirely

**TRACE SAYS** (item 16, line 36): `handleChangeSubscriptionWithGate` — `AccountBillingPlans.tsx:322` → "joins `plan.priceId` + `currentSubscriptionItemId`". That is the only thing the trace attributes to this handler, then it proceeds directly to `handleChangeSubscriptionViaStripePortal`.

**ACTUAL CODE**: `handleChangeSubscriptionWithGate` first calls `const result = checkPlanLimitsGate(plan.lookupKey)` and branches on `result.shouldProceed`. Only when `shouldProceed` is true does it proceed to a portal call. When false it fires `trackEvent("plan_change_blocked_modal_shown", ...)` and `openModal(<PlanChangeBlockedModal ... />)`. The gate hook is `usePlanLimitsGate` imported from `@shared/hooks/usePlanLimitsGate`. The trace's skeleton, its "CHANGE call chain", and its "Unresolved identifiers" never mention `usePlanLimitsGate`, `checkPlanLimitsGate`, `result.shouldProceed`, `result.modalData`, `PlanChangeBlockedModal`, or `trackEvent`. This is a missing load-bearing branch in the chain, not a side note.

`AccountBillingPlans.tsx:35` (import), `:52` (`const { checkPlanLimitsGate } = usePlanLimitsGate()`), `:322-350` (handler body); hook file `app/javascript/shared/hooks/usePlanLimitsGate.ts`.

---

## D2 — Change-call chain OMITS the payment-method branch (`handleUpdateWithPaymentMethod` / `useUpdateWithPaymentMethod`)

**TRACE SAYS** (items 16-19): `handleChangeSubscriptionWithGate` → `handleChangeSubscriptionViaStripePortal` → `useChangeSubscriptionViaStripePortal` → `changeSubscriptionViaStripePortal` → `apiPost(/billing/change_subscription_portal_session)`. Presented as the single, unconditional change path.

**ACTUAL CODE**: inside the `shouldProceed` branch, the handler branches on `currentOrganization.stripeDefaultPaymentMethodOnFile`. If TRUE → `handleChangeSubscriptionViaStripePortal`. If FALSE → `handleUpdateWithPaymentMethod`, which calls the `useUpdateWithPaymentMethod` hook → `updateWithPaymentMethod` const → `apiPost({ path: '/billing/update_payment_method_and_subscription_portal_session', variables: { priceId, subscriptionItemId, returnUrl } })`. The trace omits this entire alternate POST path (a different route, `update_payment_method_and_subscription_portal_session`, `routes.rb:170`) and its hook/const. The hooks `useUpdateWithPaymentMethod`/`updateWithPaymentMethod` ARE imported and used in the component.

`AccountBillingPlans.tsx:326` (branch), `:243-278` (`handleUpdateWithPaymentMethod`), `:130-133` (`useUpdateWithPaymentMethod`); `useBilling.ts:61-74` (`updateWithPaymentMethod`), `:194-205` (`useUpdateWithPaymentMethod`).

---

## D3 — Skeleton OMITS `PlanCard.tsx`, the component that renders the change button to the SCREEN and invokes the change handler

**TRACE SAYS** (items 15→16): jumps from `plans / plansWithButtonText` (`AccountBillingPlans.tsx:175`) directly to `handleChangeSubscriptionWithGate` (`:322`). No intermediary component named; the terminal-to-SCREEN component is never identified.

**ACTUAL CODE**: `plansWithButtonText.map(...)` renders a `<PlanCard ... onChangeSubscription={handleChangeSubscriptionWithGate} ... />` for each plan (`AccountBillingPlans.tsx:435-457`). The actual button the user clicks lives in `PlanCard.tsx` (`Styled.Button onClick={handleOnClickSubscriptionAction}`, `PlanCard.tsx:207-214`), and `handleOnClickSubscriptionAction` calls `onChangeSubscription(plan)` (`PlanCard.tsx:95`). The trace's chain skips the SCREEN-rendering component and the callpoint where the click originates — the thread to the SCREEN stops short.

`AccountBillingPlans.tsx:439-456` → `PlanCard.tsx:88` (prop), `:95` (invocation), `:207-214` (button).

---

## D4 — `getPlansForPeriod` lookup-key MATCH is at line 560, not 553

**TRACE SAYS** (item 14, line 31; and price-model table line 84): `getPlansForPeriod` — `planLookups.js:553` → "matches `price.lookupKey.includes(planConfig.key)`" at `:553`.

**ACTUAL CODE**: line 553 is only the function signature `export const getPlansForPeriod = (period, billingPrices = []) => {`. The actual match `const priceData = planDataMatches.find((price) => price.lookupKey.includes(planConfig.key));` is at `planLookups.js:560`. The trace attributes the match expression to the wrong line.

`planLookups.js:553` (signature) vs `:560` (match).

---

## D5 — `priceId` assignment includes a `|| null` fallback the trace drops

**TRACE SAYS** (item 14, line 31): "sets `priceId = priceData.id` (`planLookups.js:568`)". Price-model table (line 84): "→ `priceId = priceData.id`".

**ACTUAL CODE**: `planLookups.js:568` is `priceId: priceData?.id || null,` — optional chaining plus a `|| null` fallback when no matching price is found. The trace's `priceData.id` omits both the `?.` and the `|| null`. (Adjacent, same object: `price: priceData ? priceData.unitAmount / 100 : 0` at `:564` — a `: 0` fallback — also undocumented, relevant since the price renders on the SCREEN.)

`planLookups.js:568` (priceId), `:564` (price fallback).

---

## D6 — `getPlansForPeriod` also filters `billingPrices` by recurring interval before matching — trace omits this step

**TRACE SAYS** (item 14): `getPlansForPeriod` "matches `price.lookupKey.includes(planConfig.key)`, sets `priceId = priceData.id`". Presents a single match step over `billingPrices`.

**ACTUAL CODE**: the function first filters `currentOrganizationPlanOptions` by `plan.period === period` into `planConfigs` (`:554`) AND filters `billingPrices` by `period.includes(price?.recurring?.interval)` into `planDataMatches` (`:555-557`); the lookup-key match then runs over `planDataMatches`, not raw `billingPrices`. The period/interval pre-filter (the origin of which Stripe prices are even eligible) is omitted from the trace.

`planLookups.js:554-557`.

---

## D7 — `handleChangeSubscriptionViaStripePortal` input signature is `{ priceId, subscriptionItemId }`, not "adds returnUrl"

**TRACE SAYS** (item 17, line 37): `handleChangeSubscriptionViaStripePortal` — `AccountBillingPlans.tsx:283` "(adds `returnUrl: '/hire/settings/billing'`)". This frames the handler as taking `priceId` and adding `returnUrl`.

**ACTUAL CODE**: the handler's parameter object is `{ priceId, subscriptionItemId }` (`AccountBillingPlans.tsx:283-289`); it then passes `{ priceId, subscriptionItemId, returnUrl: "/hire/settings/billing" }` to the mutate fn (`:290-295`). The trace omits `subscriptionItemId` as an explicit input parameter of this handler (it is the carrier of `currentSubscriptionItemId` into the POST). The `returnUrl` add is correct.

`AccountBillingPlans.tsx:283-295`.

---

## D8 — `useChangeSubscriptionViaStripePortal` onSuccess invalidates `["currentOrganization"]` — undocumented terminal side effect

**TRACE SAYS**: item 18 (line 38) names `useChangeSubscriptionViaStripePortal` (`useBilling.ts:181`) but documents no behavior; the success terminal of the change call is presented as `window.location.href = data.redirectUrl` only (implied via the controller `redirectUrl` render at backend item 30).

**ACTUAL CODE**: `useChangeSubscriptionViaStripePortal` (`useBilling.ts:181-192`) has an `onSuccess` that calls `queryClient.invalidateQueries(["currentOrganization"])`. Additionally the component's own `onSuccess` (`AccountBillingPlans.tsx:297-304`) logs then `window.location.href = data.redirectUrl`, and `onError` (`:305-314`) reads `error?.data?.errors?.general?.[0]` and calls `addToast(...)`. The trace records neither the react-query cache-invalidation terminal nor the component-level onError toast terminal for this segment.

`useBilling.ts:181-192`; `AccountBillingPlans.tsx:296-316`.

---

## D9 — `getStripeCustomerSubscription` const definition line is correct, but the hook is consumed as a destructured `{ data, isFetching }` whose `data.subscription` is the SCREEN source — trace stops at the const

**TRACE SAYS** (item 9, line 23): "Frontend reads `currentSubscription` — `AccountBillingPlans.tsx:62`". It then derives item-id and price object lines.

**ACTUAL CODE**: confirmed `AccountBillingPlans.tsx:62-64` sets `currentSubscription = stripeCustomerSubscriptionData ? stripeCustomerSubscriptionData.subscription : null`, sourced from `useStripeCustomerSubscription({ refetchOnWindowFocus: false })` destructured as `{ data: stripeCustomerSubscriptionData, isFetching: isFetchingStripeCustomerSubscription }` (`:56-61`). `isFetchingStripeCustomerSubscription` gates an early `return <LoadingIndicator .../>` (`:352-354`) — a SCREEN terminal (loading state) the trace omits. (This is a thread-stops-short on the SCREEN side, not a wrong line.)

`AccountBillingPlans.tsx:56-64`, `:352-354`.

---

## D10 — `currentOrganizationPlanOptions` `value` vs `key` description is imprecise

**TRACE SAYS** (price-model table, line 85): `currentOrganizationPlanOptions` — "`key`=Stripe lookup_key substring, `value`=internal plan alias" (`planLookups.js:3`).

**ACTUAL CODE**: line 3 is correct as the array start. But the semantics are reversed/garbled: `value` holds the full plan-name string (e.g. `"plan_ats_tier_starter_v2"`) which becomes `plan.lookupKey` (`:569`) and is what `checkPlanLimitsGate(plan.lookupKey)` and the change handler consume; `key` holds the short substring (e.g. `"starter_v2"`) used for the Stripe-price `lookupKey.includes()` match (`:560`). Calling `value` the "internal plan alias" and `key` the "Stripe lookup_key substring" inverts which one is matched against the live Stripe `lookupKey`: it is `key` (substring) that is matched, and `value` (full) that is surfaced as `plan.lookupKey`. The trace's own item-14 chain matches on `planConfig.key`, contradicting this table row's labeling.

`planLookups.js:3-76` (array), `:560` (key match), `:569` (value→lookupKey).

---

## D11 — `apiPost` path for the change call is correct, but trace omits `apiMutate` as the actual transport layer

**TRACE SAYS** (item 19, line 39): `changeSubscriptionViaStripePortal` → `apiPost({...})` "(`allKeysToSnake` → `price_id`, `subscription_item_id`, `return_url`)".

**ACTUAL CODE**: `apiPost` (`api.ts:25-28`) does NOT itself call `allKeysToSnake`; it delegates to `apiMutate({ method: "post", ... })` (`api.ts:40-68`), and it is `apiMutate` at `:52` that applies `data: skipKeysToSnake ? variables : allKeysToSnake(variables)`. The response is run through `allKeysToCamel(data)` at `:67`, and the error path runs `allKeysToCamel(response.data)` at `:56`. The trace attributes `allKeysToSnake` to `apiPost` and never names `apiMutate`, the function where the snake transform and the CSRF header (`Rails.csrfToken()`, `:50`) actually live. (Field names `price_id`/`subscription_item_id`/`return_url` are the expected output of the transform.)

`api.ts:25-28` (`apiPost`), `:40-68` (`apiMutate`), `:52` (snake), `:67` (camel).

---

## Notes / confirmed-correct (no discrepancy)

- `apiGet` at `api.ts:5` with `allKeysToCamel` (`:22`) — correct (item 4).
- `useStripeCustomerSubscription` `useBilling.ts:245`, `getStripeCustomerSubscription` `:98`, `useBillingPrices` `:266`, `getPrices` `:102`, `useChangeSubscriptionViaStripePortal` `:181`, `changeSubscriptionViaStripePortal` `:46` — all line-correct (items 2,3,10,11,18,19).
- Routes `change_subscription_portal_session` `routes.rb:169`, `prices` `:174`, `customer_subscription` `:177` — correct (a duplicate member-route block exists at `:195-200`, not the path the frontend hits; not a defect).
- `currentSubscriptionItemId` `AccountBillingPlans.tsx:136`, `currentPriceObject` `:67` — line-correct (item 9).
- `getPlansForPeriod` signature line `:553` and `lookupKey: planConfig.value` `:569` — line-correct (the match-line attribution in D4 is the defect).
