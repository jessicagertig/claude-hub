# Round 7 — Frontend segment audit (ADVERSARIAL REVIEWER "frontend")

Subject: ANALOG subscription-change frontend chain to the SCREEN.
Worktree audited: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`
Files traced: `AccountBillingPlans.tsx` → `useBilling.ts` → `api.ts` / `planLookups.js` / `PlanCard.tsx` / `AccountBilling.tsx` (parent) → `usePlanLimitsGate.ts` / `config/routes.rb`.

## Summary

The frontend trace is line-accurate to a very high degree. Every hook line number (`useBilling.ts`), const line number, `api.ts` transport claim, `planLookups.js` (`getPlansForPeriod`/`getPlanButtonText`/`getPlanButtonType`), `PlanCard.tsx` render/branch line, `AccountBilling.tsx` parent ternary, route line, and the `AccountBillingPlans.tsx` handler/JSX line numbers I verified MATCHED the real code. The discrepancies below are OMISSIONS of real consumers/terminals and one content inaccuracy in a rendered string — not wrong line numbers.

---

## DISCREPANCY 1 — Omitted `currentPlanLookupKey` ANALYTICS terminal at `:339`

TRACE SAYS: (item 9) enumerates `currentPlanLookupKey`'s consumers as the `<PlanCard>` prop (`:444`) → `trackEvent('plan_selected', ...)` in PlanCard (`PlanCard.tsx:99`) + the `window.logger` debug literal (`PlanCard.tsx:156`), asserting "it is never rendered in JSX" and reaches the screen only via the separate `getPlanButtonText` path. Item 17 mentions the `:339` `trackEvent('plan_change_blocked_modal_shown', {...})` call but does NOT name `currentPlanLookupKey` as one of its arguments.

ACTUAL CODE: `AccountBillingPlans.tsx:339` — `trackEvent("plan_change_blocked_modal_shown", { current_plan_lookup_key: currentPlanLookupKey, target_plan_lookup_key: plan.lookupKey })`. `currentPlanLookupKey` is read DIRECTLY here, a second ANALYTICS terminal inside the `AccountBillingPlans` component itself (not via the PlanCard prop). The trace's consumer enumeration for `currentPlanLookupKey` is incomplete.

file:line — `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:339`

---

## DISCREPANCY 2 — Omitted `currentPlanDisplayName` SCREEN terminal at `:412`

TRACE SAYS: (item 9) does not list `currentPlanDisplayName` at all. It enumerates the legacy-plan-copy SCREEN renders as `currentPriceObject?.interval || currentPriceObject?.recurring?.interval` at `:408`/`:413` and `Free for ${trialEndDays}` at `:415`.

ACTUAL CODE: `AccountBillingPlans.tsx:156` — `const currentPlanDisplayName = getPricingDisplayName(currentOrganization.plan);` rendered to the SCREEN at `:412` — `` ` the ${currentPlanDisplayName} ${...}ly pricing plan` `` inside the `isOnLegacyPlan` `<CurrentSubscription>` block. This is a SCREEN terminal (deriving from `currentOrganization.plan` via `getPricingDisplayName`, imported `:36`) that the trace omits.

file:line — `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:156` (def) / `:412` (render)

---

## DISCREPANCY 3 — Incomplete `<PlanCard>` prop enumeration: `hasActiveSubscription`, `hasCoupon`, `stripePromoCode`, `onCreateBillingPortalSession` omitted

TRACE SAYS: (items 9 + 16) enumerates the `<PlanCard>` props as `isCurrentPlan` (`:443`), `currentPlanLookupKey` (`:444`), `currentPlanBillingPeriod` (`:445`), `subscriptionItemId` (`:449`), `isLoading` (`:450-452`), `isLoadingButton` (`:453`), `onChangeSubscription` (`:455`). It never documents the props `hasActiveSubscription={hasActiveSubscription}` (`:446`), `hasCoupon={hasCoupon}` (`:447`), `stripePromoCode={currentOrganization.stripePromoCode}` (`:448`), or `onCreateBillingPortalSession={handleCreateBillingPortalSession}` (`:454`).

ACTUAL CODE: `AccountBillingPlans.tsx:446-454` passes all four. Inside `PlanCard`, the `isCurrentPlan || isFreePlan` true branch renders `<ManageBillingActions hasActiveSubscription={hasActiveSubscription} hasCoupon={hasCoupon} stripePromoCode={stripePromoCode} onCreateBillingPortalSession={onCreateBillingPortalSession} />` (`PlanCard.tsx:200-205`) — a SCREEN terminal (the "Current plan" / free-plan management UI) that the trace's "`currentSubscription` MULTIPLE SCREEN-render terminals" section never reaches. The trace stops the `isCurrentPlan`-true branch at "renders `ManageBillingActions` and there is NO change button" without tracing the four props that feed it.

file:line — `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:446`,`:447`,`:448`,`:454` → `PlanCard.tsx:200-205`

---

## DISCREPANCY 4 — Rendered string at `:415` quoted wrong (drops `!hasCoupon` co-gate and trailing period)

TRACE SAYS: (item 9) "`trialEndDays` ... render inside the legacy-plan copy at `:415` (`Free for ${trialEndDays}`, SCREEN terminal)." Presents the render as gated only by `isTrialing` and the literal as `` `Free for ${trialEndDays}` ``.

ACTUAL CODE: `AccountBillingPlans.tsx:415` — `{isTrialing && !hasCoupon && `Free for ${trialEndDays}.`}`. The render is co-gated by `!hasCoupon` (not just `isTrialing`), and the literal includes a trailing period (`Free for ${trialEndDays}.`). The trace's quotation drops both.

file:line — `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:415`

---

## Verified-correct (no discrepancy), for the record

- Component `AccountBillingPlans` `:41`; `useStripeCustomerSubscription` destructure `:56-61`; `currentSubscription` `:62-64`; `currentPriceObject` `:67`; `currentPlanLookupKey` `:68`; `currentPlanBillingInterval` `:69-70`; `currentPlanBillingPeriod` `:71-76`; `currentSubscriptionItemId` `:136`; `currentProductPrice` `:137-142` (only consumer is `window.logger` `:200` — confirmed); `isTrialing` `:158-161`; `trialEndDays` `:163`; `hasCoupon` `:165-168`; `discount` `:169`; `coupon` `:170`; trialing block `:370-382`; cancelAtPeriodEnd block `:384-396`; coupon render `:424-431`; `.map` open `:435`; `isCurrentPlan` `:436`; `<PlanCard>` `:439-456`.
- Handlers: `handleChangeSubscriptionWithGate` `:322`; `checkPlanLimitsGate` `:323`; fork `:326`; portal `:327-330`; payment-method `:332-335`; blocked branch trackEvent `:339`, modal const `:340-347`, `openModal(modal)` `:348`; `handleChangeSubscriptionViaStripePortal` `:283-289` (returnUrl `:294`, onSuccess `:303`, onError `:305-314`); `handleUpdateWithPaymentMethod` `:243-278` (onSuccess `:263`, onError `:265-274`); early-return `LoadingIndicator` `:352-354`.
- `useBilling.ts`: `getStripeCustomerSubscription` `:98`; `getPrices` `:102`; `changeSubscriptionViaStripePortal` `:46` (apiPost `:55-57`); `updateWithPaymentMethod` `:61-74`; `useChangeSubscriptionViaStripePortal` `:181` (logger `:185-188`, invalidate `:189`); `useUpdateWithPaymentMethod` `:194` (logger `:198-201`, invalidate `:202`); `useStripeCustomerSubscription` `:245`; `useBillingPrices` `:266`.
- `api.ts`: `apiGet` `:5` (allKeysToCamel `:22`); `apiPost` `:25-28`; `apiMutate` `:40-68` (CSRF `:50`, allKeysToSnake `:52`, allKeysToCamel responses `:67` / errors `:56`).
- `planLookups.js`: `getPlansForPeriod` `:553-574` (planConfigs `:554`, planDataMatches `:555-557`, priceData `:560`, `price: ...: 0` `:564`, `priceId` `:568`, `lookupKey: planConfig.value` `:569`, `key` `:571`); `getPlanButtonType` `:578`; `getPlanButtonText` `:594`; `currentOrganizationPlanOptions` `:3` (starter row value `plan_ats_tier_starter_v2` / key `starter_v2` `:13`/`:18` — confirmed).
- `PlanCard.tsx`: `subscriptionItemId` declared `:71`, absent from destructure `:75-89` (DEAD PROP — confirmed); `displayPrice` `:90`; `savings` `:91`; `handleOnClickSubscriptionAction` `:98` (trackEvent `:99`, branch `:100`, `handleChangeSubscription`→`onChangeSubscription(plan)` `:95`/`:101`, `onCreateNewSubscription` `:103`); `isFreePlan` `:151`; debug logger `:153-158`; `showCurrentPlanBadge` `:160`; `Current plan` badge `:167`; savings tooltip `:168-176`; `Save $/year` `:177-179`; price render `:183`; button branch `:199`; `ManageBillingActions` `:200-205`; change `Styled.Button` `:207-214` (onClick `:208`, loading `:209`, disabled `:210`, styleType `:211`, label `:213`).
- `AccountBilling.tsx`: `useBillingPrices` `:50`; `.data` unwrap `:54` (`[]` fallback); 3-way ternary `:122-134`/`:135`; `AccountBillingPlans` props passed `:129-134`.
- Routes: `customer_subscription` `:177`; `prices` `:174`; `change_subscription_portal_session` `:169`; `update_payment_method_and_subscription_portal_session` `:170`; `continue_change_subscription_portal_session` `:178`.
