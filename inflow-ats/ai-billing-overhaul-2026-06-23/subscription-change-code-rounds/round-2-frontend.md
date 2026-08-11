# Round 2 — FRONTEND segment (adversarial, OURS vs analog trace)

Chain traced (file → file → terminal):
`OrganizationAiBilling.tsx` (parent, analog `AccountBilling.tsx`) → `AiCreditSubscription.tsx` → `useOrganizationAiCreditPurchase.ts` (`useAiCreditCustomerSubscription` → `apiGet` `/ai_credit_purchases/customer_subscription`) → `api.ts` (`apiGet` + `allKeysToCamel`) → controller `customer_subscription` (returns RAW live Stripe subscription object, verified) → back to `AiCreditSubscription.tsx` deriving `currentSubscription`/`currentPriceObject`/`currentPlanLookupKey`/`isSubscribed`/`currentCredits`/`currentPeriodEnd` → `aiSubscriptionHelpers.ts` (`splitTiers`, `deriveTierButtonText`, `formatResetDate`) → `planHelpers.ts` (`aiCreditPrices`, `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY`) → SCREEN (`AiSubscriptionStatus.tsx`, `AiSubscriptionTierCard.tsx`).
Analog: `AccountBilling.tsx` → `AccountBillingPlans.tsx` → `useBilling.ts` (`useStripeCustomerSubscription`) → `api.ts` → `planLookups.js` → `PlanCard.tsx`.

## Status of Round 1 findings (re-verified — ALL FIXED)

Round 1's BLOCKERs F1–F4 (the reported symptom: active subscription does not display because display gated on the LOCAL `subscription_status` column) are resolved. Current code derives the entire active-subscription display from the LIVE Stripe subscription, matching the analog:
- `isSubscribed = currentSubscription?.status === "active" || currentSubscription?.status === "past_due"` — `AiCreditSubscription.tsx:60-61` (live status, was the local `subscriptionStatus` column).
- `currentCredits` from `currentPlanLookupKey = currentPriceObject?.lookupKey` (live) → `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` — `AiCreditSubscription.tsx:58-65` (was the local `subscriptionCreditsPerPeriod` column). `?? null`, no fabricated fallback.
- `currentPeriodEnd = currentSubscription?.currentPeriodEnd` — `AiCreditSubscription.tsx:66` (live Unix ts, was the local `subscriptionCurrentPeriodEnd` column).
- `useOrganizationAiCreditPurchase()` (`#show` local-row hook) no longer imported/called; no remaining `subscriptionStatus`/`subscriptionCreditsPerPeriod`/`subscriptionCurrentPeriodEnd` reads (grep-verified).
- Controller `customer_subscription` returns the RAW live Stripe object (`organization_ai_credit_purchase.stripe_subscription`), exactly paralleling the analog's `current_organization.stripe_subscription` — so `currentSubscription.status`/`.items.data[0].price`/`.plan.id`/`.currentPeriodEnd` all resolve off the live object. Verified MATCH.

Remaining deviations below.

---

## D1 (MED) — No `cancelAtPeriodEnd` display state derived from the live subscription

ANALOG (trace line 30): `currentSubscription?.cancelAtPeriodEnd` gates a distinct `<CurrentSubscription>` SCREEN block rendering `prettyDate(currentSubscription.cancelAt)` (`AccountBillingPlans.tsx:384-396`). The pending-cancellation state is DERIVED FROM THE LIVE Stripe subscription and surfaced to the user ("scheduled to cancel on {date}").

OURS: nowhere in the AI segment is `currentSubscription.cancelAtPeriodEnd` (or `.cancelAt`) read — grep-verified zero hits in `accountPlatoAi/` and `useOrganizationAiCreditPurchase.ts`. The active-subscription banner unconditionally renders `Renews {formatResetDate(periodEndsAt)} · unused monthly credits roll over` (`AiSubscriptionStatus.tsx:33`) whenever `isSubscribed` is true. OURS HAS a cancel flow (`handleCancelClick` → `useCancelAiCreditSubscription` → `CancelAiCreditSubscription`) that sets the subscription to cancel at period end on Stripe; after a user cancels, the live `currentSubscription.cancelAtPeriodEnd` becomes true, but OURS still shows "Active subscription / Renews {date} / Cancel subscription" with no indication it is scheduled to cancel. This is a live-subscription-derived display state the analog has and OURS lacks. Unlike the analog's trialing/coupon/legacy-plan sub-blocks (which are main-plan-only product features and correctly absent here), `cancel_at_period_end` is a generic Stripe subscription state that applies to the AI credit subscription and is reachable via OURS' own cancel flow — so its absence is a structural deviation, not a forced domain difference.

file:line — `AiCreditSubscription.tsx` (no derivation; missing); render terminal `AiSubscriptionStatus.tsx:33`

---

## D2 (LOW) — Tier-card change button omits the live-fetch `loading` prop the analog's button carries

ANALOG (trace item 16): the per-plan change `Styled.Button` receives BOTH `loading={isLoadingButton}` (`PlanCard.tsx:209`, where `isLoadingButton = isFetchingStripeCustomerSubscription`, the customer-subscription fetch flag threaded from `AccountBillingPlans.tsx:453`) AND `disabled={isLoading}` (`PlanCard.tsx:210`, the change-mutation flag). The fetch flag is a SECOND SCREEN terminal (the first being the early-return `<LoadingIndicator>` at `AccountBillingPlans.tsx:352-354`).

OURS: `AiSubscriptionTierCard`'s change button has only `disabled={isLoading}` (`AiSubscriptionTierCard.tsx:61-64`), where `isLoading = isSubscribing || isLoadingChangeSubscriptionViaStripePortal || isLoadingUpdateWithPaymentMethod` (`AiCreditSubscription.tsx:289`, the mutation flags — MATCHES the analog's `disabled`). It has NO `loading={...}` prop tied to `isFetchingAiCreditCustomerSubscription`; that fetch flag is consumed ONLY by the early-return `<LoadingIndicator label="Loading..." />` (`AiCreditSubscription.tsx:260-262`, MATCHES the analog's first terminal). So OURS has the early-return terminal but drops the analog's second (button-`loading`) terminal of the same fetch flag.

Mitigation noted: because OURS early-returns the entire component while `isFetchingAiCreditCustomerSubscription` is true (identical to the analog's early return), the tier cards never render during that fetch, making the button-`loading` prop unreachable/redundant in BOTH OURS and the analog. Flagged for completeness per "report EVERY deviation"; effectively cosmetic given the shared early return.

file:line — `AiSubscriptionTierCard.tsx:61-64` (missing `loading` prop); fetch flag `AiCreditSubscription.tsx:260-262`, threaded card prop site `AiCreditSubscription.tsx:289`

---

## Notes / non-findings (verified MATCH or sanctioned — not flagged)

- `currentSubscription = aiCreditCustomerSubscriptionData ? aiCreditCustomerSubscriptionData.subscription : null` (`AiCreditSubscription.tsx:54-56`) — MATCHES analog `:62-64` (`data` renamed, `.subscription` unwrap, `null` fallback).
- `currentSubscriptionItemId = currentSubscription && currentSubscription.items.data[0].id` (`:57`) — MATCHES analog `:136` (falsy when no sub; only read on the change path).
- `currentPriceObject = currentSubscription && currentSubscription.items.data[0].price` (`:58`) and `currentPlanLookupKey = currentPriceObject?.lookupKey` (`:59`) — MATCH analog `:67`/`:68`.
- `isCurrent = currentSubscription?.plan?.id === tier.priceId` (`:278`) — MATCHES analog `isCurrentPlan = currentSubscription?.plan?.id === plan.priceId` (`:436`), correctly off the LIVE `.plan.id`.
- `handleSelectTier` fork on `currentOrganization.stripeDefaultPaymentMethodOnFile` (`:151-163`) — MATCHES analog `handleChangeSubscriptionWithGate` fork (`:326`). Absence of `usePlanLimitsGate`/`ValidateSubscriptionChange`/`PlanChangeBlockedModal` is SANCTIONED #3 — not flagged.
- `currentCredits` derived via the local `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` table keyed on the LIVE `currentPlanLookupKey` (analog derives the displayed amount directly off the live price's `unitAmount`, with no local table) — forced: credit counts are AI-domain metadata, not a native Stripe price field; the lookupKey→credits table is SANCTIONED #5 (`AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` family) and is the same table `aiCreditPrices` uses for the tier cards. Not flagged.
- Absent `trialing`/`coupon`/legacy-plan display sub-blocks (analog `:370-431`) — main-plan-only product features (no trials/coupons/legacy plans in the AI credit subscription); forced domain difference. Not flagged.
- `pricesData` passed whole to the child and unwrapped via `splitTiers(pricesData.data || [])` inside `AiCreditSubscription`, vs the analog unwrapping `billingPricesData.data` in the PARENT (`AccountBilling.tsx:54`) and passing the array down — placement difference only; same data reaches the prices chain, and `splitTiers`/`aiCreditPrices` naming is SANCTIONED #5. Not flagged (outside the display-gating terminals; parent file is outside this segment).
- `apiGet`/`apiPost` transport, `returnUrl: "/hire/settings/plato-ai/billing"`, `/ai_credit_purchases/...` route literals — domain-path naming, SANCTIONED #5 / WHITELIST W2 family. Not flagged.
- `useChangeAiCreditSubscriptionViaStripePortal`/`useUpdateAiCreditSubscriptionWithPaymentMethod` `onSuccess` invalidate `['currentOrganization']` (analog `useBilling.ts:189`/`:202`) PLUS `['organizationAiCreditPurchase']` — the extra AI-purchase-row invalidation is forced by the data model (OrganizationAiCreditPurchase row), SANCTIONED #2 family. Not flagged.
</content>
</invoke>
