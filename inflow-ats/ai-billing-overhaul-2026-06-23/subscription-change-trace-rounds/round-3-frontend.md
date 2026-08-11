# Round 3 — Frontend chain audit (subscription-change analog trace)

Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`
Segment: AccountBillingPlans.tsx, useBilling.ts, planLookups.js, api.ts, plus parent AccountBilling.tsx (item 13) and PlanCard.tsx (item 16).

Chains traced (frontend → screen / → backend request):
- `AccountBilling.tsx` (parent, `useBillingPrices`, `billingPrices` prop) → `AccountBillingPlans.tsx` → `useStripeCustomerSubscription`/`useBillingPrices` (`useBilling.ts`) → `getStripeCustomerSubscription`/`getPrices` → `apiGet` (`api.ts`) → backend (out of segment).
- `AccountBillingPlans.tsx` → `getPlansForPeriod` (`planLookups.js`) → `plansWithButtonText` → `PlanCard.tsx` → `handleOnClickSubscriptionAction` → `onChangeSubscription` → `handleChangeSubscriptionWithGate` → `handleChangeSubscriptionViaStripePortal`/`handleUpdateWithPaymentMethod` → `changeSubscriptionViaStripePortal`/`updateWithPaymentMethod` (`useBilling.ts`) → `apiPost` → `apiMutate` (`api.ts`, `allKeysToSnake`/CSRF) → backend.
- Screen terminals: `<LoadingIndicator>` early-return, PlanCard render (`Current plan` badge / change button), `window.location.href = data.redirectUrl` redirects, `addToast` error toasts, `PlanChangeBlockedModal`.

Verdict: the frontend segment of the trace is substantially accurate. All major identifiers, hooks, consts, line numbers, fork logic, and terminals verified correct. Discrepancies found are minor (imprecise line-range/quoting and two structural omissions). No load-bearing identifier is wrong.

---

## Discrepancy 1 (structural omission — parent branch selection)

TRACE SAYS — item 13: the parent `AccountBilling.tsx` unwraps `billingPrices` and passes it "to `<AccountBillingPlans>` (`AccountBilling.tsx:129-134`)", presenting `AccountBillingPlans` as the view rendered for an org with an active subscription.

ACTUAL CODE — `AccountBilling.tsx:122-135` is a three-way ternary. `AccountBillingPlans` is rendered ONLY in the MIDDLE branch (`: hasActiveSubscription ?`, lines 128-134). The FIRST branch renders `AccountBillingPlansFreeTrial` when `currentOrganization.eligibleForFreeTrial && hasActiveSubscription` (lines 122-127), and the THIRD renders `AccountBillingPlansUnsubscribed` (lines 135+). The trace never mentions that an active-subscription org that is `eligibleForFreeTrial` does NOT reach `AccountBillingPlans` at all — it gets the sibling `AccountBillingPlansFreeTrial`. The analog's entry view is conditional, not unconditional.

file: `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBilling.tsx:122-134`

---

## Discrepancy 2 (signature mis-quoted — missing default param)

TRACE SAYS — item 14: "`getPlansForPeriod(period, billingPrices)` — `app/javascript/ats/src/lib/planLookups.js:553` (signature)".

ACTUAL CODE — the signature is `export const getPlansForPeriod = (period, billingPrices = []) => {`. The second parameter has a default of `= []` (empty-array fallback for when no prices are supplied), which the trace's quoted signature omits.

file: `app/javascript/ats/src/lib/planLookups.js:553`

---

## Discrepancy 3 (structural imprecision — modal is assigned to a const, not inlined)

TRACE SAYS — item 17, blocked branch: "`openModal(<PlanChangeBlockedModal .../>)` (`:340-348`...)", presenting the modal element as passed inline to `openModal`.

ACTUAL CODE — the JSX is first assigned to a local `const modal` (`AccountBillingPlans.tsx:340-347`), and then `openModal(modal)` is called on a separate line (`:348`). `openModal` is not invoked with an inline `<PlanChangeBlockedModal />` argument; it receives the `modal` variable.

file: `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:340-348`

---

## Discrepancy 4 (imprecise fallback location — `price ? ... : 0` is not in AccountBillingPlans)

TRACE SAYS — item 9: the `currentSubscription &&` guard on `currentPriceObject` "feeds the `price ? ... : 0` / `currentProductPrice ... : null` SCREEN fallbacks" (`AccountBillingPlans.tsx:67`).

ACTUAL CODE — there is no `price ? ... : 0` expression in `AccountBillingPlans.tsx`. The `: 0` price fallback lives in `planLookups.js:564` (`price: priceData ? priceData.unitAmount / 100 : 0`), which is gated by `priceData` (derived from `billingPrices`), NOT by `currentSubscription` / `currentPriceObject`. Only the `currentProductPrice ... : null` fallback (`AccountBillingPlans.tsx:137-142`, gated by `currentPriceObject != undefined`) is actually downstream of the `currentPriceObject` guard the trace describes. Conflating the two fallbacks attributes the planLookups `: 0` fallback to the wrong file and the wrong guard.

file: `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:67`, `app/javascript/ats/src/lib/planLookups.js:564`

---

## Notes (verified correct — no discrepancy)

- `useBilling.ts`: `useStripeCustomerSubscription` :245, `getStripeCustomerSubscription` :98, `useBillingPrices` :266, `getPrices` :102 (`apiGet({ path: '/billing/prices' })` :103), `useChangeSubscriptionViaStripePortal` :181 (`onSuccess` invalidate `['currentOrganization']` :189), `changeSubscriptionViaStripePortal` :46 (apiPost :55-57), `useUpdateWithPaymentMethod` :194 (invalidate :202), `updateWithPaymentMethod` :61-74 — all confirmed.
- `api.ts`: `apiGet` :5 (`allKeysToCamel` :22); `apiPost` :25-28 → `apiMutate` :40-68 (CSRF `Rails.csrfToken()` :50, `allKeysToSnake` :52, `allKeysToCamel` response :67 / error :56) — all confirmed.
- `AccountBillingPlans.tsx`: destructure rename to `stripeCustomerSubscriptionData` :56-61; `currentSubscription` :62-64; `currentPriceObject` :67; `currentSubscriptionItemId` :136; loading early-return `<LoadingIndicator label="Loading..." />` :352-354; `getPlansForPeriod(billingPeriod, billingPrices)` :175; `plansWithButtonText` filter :178 / spread :189; `.map` :435, `isCurrentPlan` :436, PlanCard :439-457 (`isCurrentPlan` :443, `subscriptionItemId` :449, `onChangeSubscription` :455); `handleChangeSubscriptionWithGate` :322 (`checkPlanLimitsGate` :323, fork on `stripeDefaultPaymentMethodOnFile` :326, portal :327-330, payment-method :332-335, `trackEvent('plan_change_blocked_modal_shown')` :339); `handleChangeSubscriptionViaStripePortal` :283-289 (`returnUrl` :294, mutate :290-316, `window.location.href = data.redirectUrl` :303, error toast :305-314); `handleUpdateWithPaymentMethod` :243-278 (redirect :263, error toast :265-274); imports `usePlanLimitsGate` :35, `PlanChangeBlockedModal` :38, `trackEvent` :39 — all confirmed.
- `PlanCard.tsx`: `handleOnClickSubscriptionAction` :98 (`trackEvent('plan_selected')` :99, branch on `hasActiveSubscription` :100, `handleChangeSubscription()` :101 → `onChangeSubscription(plan)` :95, else `onCreateNewSubscription()` :103); `isFreePlan` :151; button branch `{isCurrentPlan || isFreePlan ? ...}` :199 (`ManageBillingActions` :200-205, `Styled.Button` :207-214 with `onClick` :208, `loading` :209, `disabled` :210) — all confirmed.
- `planLookups.js`: `currentOrganizationPlanOptions` :3 (`value`/`key` examples correct); `getPlansForPeriod` body — `planConfigs` :554, `planDataMatches` :555-557, `priceData` :560, `price: ... : 0` :564, `priceId` :568, `lookupKey: planConfig.value` :569, `key` :571 — all confirmed.
- `AccountBilling.tsx`: `useBillingPrices` destructure :50, `billingPrices` unwrap :54 (`[]` fallback) — confirmed.
