# Round 4 — Frontend segment audit (ADVERSARIAL REVIEWER "frontend")

Segment: the FRONTEND chain to the SCREEN / to the backend request boundary —
`AccountBillingPlans.tsx`, `useBilling.ts`, `planLookups.js`, `api.ts`
(`apiGet`/`apiPost`/`apiMutate`/`allKeysToSnake`/`allKeysToCamel`), plus the
ancestor `AccountBilling.tsx` and the child `PlanCard.tsx`.

Chains traced (all in `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`):
- `AccountBilling.tsx` -> `useBilling.ts` (`useBillingPrices`/`getPrices`/`apiGet`) -> `api.ts` -> SCREEN (`billingPrices` prop)
- `AccountBilling.tsx` (3-way ternary) -> `AccountBillingPlans.tsx`
- `AccountBillingPlans.tsx` -> `useBilling.ts` (`useStripeCustomerSubscription`/`getStripeCustomerSubscription`/`apiGet`) -> `api.ts` (`allKeysToCamel`) -> SCREEN (`currentSubscription`/`currentSubscriptionItemId`/`currentProductPrice`)
- `AccountBillingPlans.tsx` -> `planLookups.js` (`getPlansForPeriod` / `currentOrganizationPlanOptions`) -> `plans`/`plansWithButtonText` -> SCREEN (`PlanCard.tsx`)
- `AccountBillingPlans.tsx` (`handleChangeSubscriptionWithGate` -> `handleChangeSubscriptionViaStripePortal` / `handleUpdateWithPaymentMethod`) -> `useBilling.ts` (`useChangeSubscriptionViaStripePortal`/`changeSubscriptionViaStripePortal`, `useUpdateWithPaymentMethod`/`updateWithPaymentMethod`) -> `api.ts` (`apiPost`->`apiMutate`, `allKeysToSnake`) -> backend request boundary
- `PlanCard.tsx` (`handleOnClickSubscriptionAction` -> `handleChangeSubscription` -> `onChangeSubscription(plan)`)

Verdict: the frontend segment of the trace is exceptionally accurate. Every
file:line for the principal data-flow chain (subscription fetch, prices fetch,
the change/payment-method handlers, the apiPost/apiMutate transport, the
planLookups derivation, the PlanCard button branch) matches the real code
identifier-by-identifier and line-by-line. The only discrepancies are minor
OMITTED callpoints in the secondary "button loading/disabled state" thread —
the trace names the props `loading={isLoadingButton}` / `disabled={isLoading}`
inside PlanCard but never traces those two props back to their origins in
`AccountBillingPlans.tsx`, so the thread stops short of its true source.

---

## D1 — `isLoading` PlanCard prop thread stops short of its origin (omitted callpoint)

TRACE SAYS — item 16 documents the change `Styled.Button` with `disabled={isLoading}`
(`PlanCard.tsx:210`) but never identifies where the `isLoading` prop passed INTO
`PlanCard` comes from; the trace does not mention the `isLoading={...}` prop on the
`<PlanCard>` element nor its source expression.

ACTUAL CODE — `<PlanCard ...>` is passed
`isLoading={isLoadingChangeSubscriptionViaStripePortal || isLoadingUpdateWithPaymentMethod}`,
and those two booleans are the `isLoading` values destructured from the two mutation
hooks: `const { mutate: changeSubscriptionViaStripePortal, isLoading: isLoadingChangeSubscriptionViaStripePortal } = useChangeSubscriptionViaStripePortal();`
and `const { mutate: updateWithPaymentMethod, isLoading: isLoadingUpdateWithPaymentMethod } = useUpdateWithPaymentMethod();`.
The `disabled` state of the change button therefore terminates in the two `react-query`
mutation hooks' `isLoading` flags — a SCREEN-affecting thread the trace leaves unrooted.

file:line — `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:450-452` (PlanCard prop), `:123-126` (`isLoadingChangeSubscriptionViaStripePortal`), `:130-133` (`isLoadingUpdateWithPaymentMethod`)

---

## D2 — `isLoadingButton` PlanCard prop thread stops short of its origin (omitted callpoint)

TRACE SAYS — item 16 documents the change `Styled.Button` with `loading={isLoadingButton}`
(`PlanCard.tsx:209`) but never identifies the source of the `isLoadingButton` prop passed
INTO `PlanCard`.

ACTUAL CODE — `<PlanCard ...>` is passed
`isLoadingButton={isFetchingStripeCustomerSubscription}`. So the button's `loading`
spinner is driven by the SAME `isFetching` flag the trace already (correctly, item 9)
ties to the early-return `<LoadingIndicator>` at `:352-354`. The trace tracks
`isFetchingStripeCustomerSubscription` to the loading-indicator terminal but omits this
SECOND consumer (the PlanCard button-loading terminal). The flag has two SCREEN terminals;
the trace documents only one.

file:line — `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:453` (`isLoadingButton={isFetchingStripeCustomerSubscription}`), consumed at `PlanCard.tsx:209`

---

## Items explicitly verified as CORRECT (no discrepancy)

For the record, these specific trace claims were checked against the real code and are accurate:

- `useBilling.ts`: `getStripeCustomerSubscription` `:98`, `getPrices` `:102`, `changeSubscriptionViaStripePortal` `:46`, `updateWithPaymentMethod` `:61-74`, `useStripeCustomerSubscription` `:245`, `useBillingPrices` `:266`, `useChangeSubscriptionViaStripePortal` `:181` (onSuccess invalidates `['currentOrganization']` `:189`), `useUpdateWithPaymentMethod` `:194` (onSuccess invalidates `['currentOrganization']` `:202`).
- `api.ts`: `apiGet` `:5` (allKeysToCamel `:22`), `apiPost` `:25-28`, `apiMutate` `:40-68`, CSRF `Rails.csrfToken()` `:50`, `allKeysToSnake(variables)` `:52`, `allKeysToCamel` on response `:67` and on error `:56`, import of `allKeysToSnake`/`allKeysToCamel` from `@ats/src/lib/utils/structure` `:2`.
- `AccountBillingPlans.tsx`: subscription hook destructure `:56-61`, `currentSubscription` `:62-64`, `currentPriceObject` `:67`, `currentSubscriptionItemId` `:136`, `currentProductPrice` `:137-142`, `getPlansForPeriod(billingPeriod, billingPrices)` `:175`, `plansWithButtonText` `:177-193` (`.filter(plan.key !== 'free')` `:177-178`, `...plan` spread `:189`), early-return LoadingIndicator `:352-354`, `handleChangeSubscriptionWithGate` `:322` (`checkPlanLimitsGate(plan.lookupKey)` `:323`, fork on `stripeDefaultPaymentMethodOnFile` `:326`, portal `:327-330`, payment-method `:332-335`, `trackEvent` `:339`, modal const `:340-347`, `openModal(modal)` `:348`), `handleChangeSubscriptionViaStripePortal` `:283-289` (returnUrl `:294`, mutate `:290-316`, onSuccess redirect `:303`, onError `:305-314`), `handleUpdateWithPaymentMethod` `:243-278` (onSuccess redirect `:263`, onError `:265-274`), `.map` `:435`, `isCurrentPlan` `:436`, PlanCard `:439-457` (`isCurrentPlan={isCurrentPlan}` `:443`, `subscriptionItemId={currentSubscriptionItemId}` `:449`, `onChangeSubscription={handleChangeSubscriptionWithGate}` `:455`); imports `usePlanLimitsGate` `:35`, `PlanChangeBlockedModal` `:38`, `trackEvent` `:39`.
- `PlanCard.tsx`: `isFreePlan` `:151`, button branch `:199`, `ManageBillingActions` `:200-205`, change `Styled.Button` `:207-214` (`onClick` `:208`, `loading` `:209`, `disabled` `:210`), `handleOnClickSubscriptionAction` `:98` (`trackEvent('plan_selected', ...)` `:99`, branch on `hasActiveSubscription` `:100`, `handleChangeSubscription()` `:101` -> `onChangeSubscription(plan)` `:95`, `onCreateNewSubscription()` `:103`).
- `planLookups.js`: `getPlansForPeriod = (period, billingPrices = [])` `:553`, `planConfigs` `:554`, `planDataMatches` `:555-557`, `priceData` `:560`, `price: priceData ? priceData.unitAmount / 100 : 0` `:564`, `priceId: priceData?.id || null` `:568`, `lookupKey: planConfig.value` `:569`, `key: planConfig.key` `:571`; `currentOrganizationPlanOptions` `:3` (value `plan_ats_tier_starter_v2` / key `starter_v2`).
- `AccountBilling.tsx`: `useBillingPrices` destructure `:50`, `billingPrices` `[]` fallback `:54`, 3-way ternary `:122-134` (`AccountBillingPlansFreeTrial` `:122-127`, `AccountBillingPlans` `:128-134`, `AccountBillingPlansUnsubscribed` `:135-...`).
