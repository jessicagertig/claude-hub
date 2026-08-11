# Round 8 — FRONTEND segment (adversarial, OURS vs analog trace)

Worktree audited: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.

## Chain traced (file → file → terminal)

`OrganizationAiBilling.tsx` (parent, analog `AccountBilling.tsx`)
→ `useOrganizationAiCreditPurchasePrices` (`useOrganizationAiCreditPurchase.ts:145-162`, analog `useBillingPrices` `useBilling.ts:266`) → `apiGet /ai_credit_purchases/prices`
→ `<AiCreditSubscription pricesData={pricesData} />` rendered UNCONDITIONALLY (`OrganizationAiBilling.tsx:30`; analog renders `AccountBillingPlans` via a 3-way `hasActiveSubscription` parent ternary `AccountBilling.tsx:122-134`)
→ `AiCreditSubscription.tsx` (analog `AccountBillingPlans.tsx`)
  → `useAiCreditCustomerSubscription` (`useOrganizationAiCreditPurchase.ts:168-187` → `apiGet /ai_credit_purchases/customer_subscription`)
  → `api.ts` (`apiGet` + `allKeysToCamel` `:22`)
  → [controller `customer_subscription` (`organization_ai_credit_purchases_controller.rb:420-435`) renders RAW live `organization_ai_credit_purchase.stripe_subscription` (`:430`) / `{ subscription: nil }` (`:427`) / error (`:434`) — verified this round at the controller boundary]
  → back into `AiCreditSubscription.tsx`: `currentSubscription` (`:53-55`) / `currentSubscriptionItemId` (`:56`) / `currentPriceObject` (`:57`) / `currentPlanLookupKey` (`:58`) / `isSubscribed` (`:59-60`) / `currentSubscriptionTier` (`:66-69`) / `currentCredits` (`:70`) / `currentPeriodEnd` (`:71`) / `cancelAtPeriodEnd` (`:72`) / `cancelAt` (`:73`) / per-tier `isCurrent` (`:311`) / `buttonText` (`:312`)
  → `aiSubscriptionHelpers.ts` (`splitTiers` `:19-28`, `deriveTierButtonText` `:30-37`, `deriveTierButtonType` `:44-49`, `formatResetDate` `:4-6`)
  → `planHelpers.ts` (`aiCreditPrices` `:104-124`, `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` `:74-87`, `AI_CREDIT_PACK_DISPLAY_NAMES` `:89-102`)
  → SCREEN: `AiSubscriptionStatus.tsx` (`isSubscribed ? "Active subscription" + {currentCredits?.toLocaleString()} credits / month + renew/cancel copy : "No active subscription" …` `:32-58`), `AiSubscriptionTierCard.tsx` (`{tier.buttonText}` `:79`, `styleType={tier.buttonType || "secondary"}` `:77`, `loading={isLoadingButton}` `:75`, `disabled={isLoading}` `:76`, `Current plan` tag `:53`/`:71`).

Analog chain: `AccountBilling.tsx` → `AccountBillingPlans.tsx` → `useBilling.ts` (`useStripeCustomerSubscription` `:245`, `getStripeCustomerSubscription` `:98`) → `api.ts` → `planLookups.js` (`getPlansForPeriod` `:553`, `getPlanButtonText` `:594`, `getUnsubscribedPlanButtonText` `:586`, `getPlanButtonType` `:578`) → `PlanCard.tsx`.

## Verdict: ZERO non-sanctioned deviations this round.

The round-7 frontend D1 fix is present and verified correct (`aiSubscriptionHelpers.ts:35-36`):

```ts
if (!isSubscribed) return "Subscribe";
return currentCredits != null && tierCredits > currentCredits ? "Upgrade" : "Change plan";
```

This now structurally matches the analog `getPlanButtonText` (`planLookups.js:594-619`): the unsubscribed label is gated on subscription STATE alone (`!isSubscribed`, AI analog of `getUnsubscribedPlanButtonText`'s state-gated `"Start plan"`/`"Start free trial"`, W5); the subscribed credits-lookup-miss case (`currentCredits == null`) falls through to the subscribed fallback `"Change plan"` (analog's `if (!currentPlan || !targetPlan) return "Change plan"` `:607-609`); the upgrade-vs-other comparison `tierCredits > currentCredits ? "Upgrade" : "Change plan"` mirrors the analog's `targetPlan.jobLimit > currentPlan.jobLimit ? "Upgrade" : "Change plan"` (`:619`), with credits as the AI-domain rank metric (SANCTIONED #5 / W4). The conflation that round-7 flagged is gone; no SUBSCRIBED org routes to the UNSUBSCRIBED label on a lookup miss.

## Symptom path re-confirmed end to end

Every current-subscription display value derives from the LIVE Stripe subscription returned by `customer_subscription`, never from a local `subscription_status` column:
- `isSubscribed` = live `status === "active" || "past_due"` (`AiCreditSubscription.tsx:59-60`) — SANCTIONED #4.
- `currentCredits` resolves the live `currentPlanLookupKey` against the same `subscriptionTiers` the cards render (`:66-70`); the lookup table is W4-sanctioned, but the KEY driving it (`currentPlanLookupKey` `:58`) is read off the live `currentPriceObject.lookupKey`.
- `currentPeriodEnd` / `cancelAtPeriodEnd` / `cancelAt` (`:71-73`) read off the live object; render the renew/cancel copy and gate the cancel button (`AiSubscriptionStatus.tsx:36-58`).
- per-tier `isCurrent = currentSubscription?.plan?.id === tier.priceId` (`:311`) off the live `.plan.id` — MATCHES analog `:436`.
No local-column gating remains anywhere in this segment.

## Re-verified MATCHES (independent trace this round)

- **Live-subscription unwrap** `currentSubscription = aiCreditCustomerSubscriptionData ? aiCreditCustomerSubscriptionData.subscription : null` (`:53-55`) = analog `:62-64`.
- **`currentSubscriptionItemId`/`currentPriceObject`/`currentPlanLookupKey`** (`:56`/`:57`/`:58`) = analog `:136`/`:67`/`:68` (same `&&` short-circuit + `?.`, off the live object). Closure-captured `currentSubscriptionItemId` in `handleSelectTier` (`:162`/`:167`) = analog capture in `handleChangeSubscriptionWithGate` (`:329`/`:334`); analog's DEAD `subscriptionItemId` PlanCard prop correctly NOT reproduced.
- **Create-vs-change action fork** — `AiSubscriptionTierCard.handleOnClickSubscriptionAction` (`:40-46`) reads `hasActiveSubscription` → `onSelect` (change) vs `onCreateNewSubscription` (create) = analog `PlanCard.tsx:98-103`. `handleCreateNewSubscription` → `subscribe` checkout mutation (`AiCreditSubscription.tsx:180-194`, render shape `{ redirectUrl }` at controller `:60`, read `data.redirectUrl` `:185`) is the AI-domain analog of `onCreateNewSubscription`.
- **Change handlers** — `handleChangeSubscriptionViaStripePortal` / `handleUpdateWithPaymentMethod` (`:82-156`) pass `{ priceId, subscriptionItemId, returnUrl: "/hire/settings/plato-ai/billing" }`, `onSuccess → window.location.href = data.redirectUrl`, `onError → addToast({ title: error?.data?.errors?.general?.[0] || <fallback>, kind: "error" })` = analog `:283-316`/`:243-278`. `returnUrl` domain path SANCTIONED #5.
- **Payment-method fork** — `handleSelectTier` forks on `currentOrganization.stripeDefaultPaymentMethodOnFile` (`:159`) → portal vs payment-method path = analog `:326`.
- **`loading`+`disabled`** — `loading={isLoadingButton}` (= `isFetchingAiCreditCustomerSubscription`) + `disabled={isLoading}` on `AiSubscriptionTierCard.tsx:75-76` = analog `PlanCard.tsx:209-210`. Same fetch flag gates the early-return `<LoadingIndicator label="Loading..." />` (`:291-293`) = analog's two fetch-flag SCREEN terminals (`:352-354` + `:453`). `isLoading` additionally includes `isSubscribing` (`:323`) — consistent with the W5 merged create/change button (the create mutation's loading legitimately belongs to the same button), not a deviation.
- **`deriveTierButtonType`** (`aiSubscriptionHelpers.ts:44-49`) maps TEXT→style: `"Upgrade"`/`"Subscribe"`→primary, else secondary = analog `getPlanButtonType` (`planLookups.js:578-584`), `"Subscribe"` being the single AI-domain analog of `"Start plan"`/`"Start free trial"` (W5). Reaches `styleType={tier.buttonType || "secondary"}` (`AiSubscriptionTierCard.tsx:77`) = analog `PlanCard.tsx:211`.
- **Hooks transport** — change/update mutation hooks emit `window.logger` DEBUG line + invalidate `['currentOrganization']` (= analog `useBilling.ts:185-189`/`:198-202`) PLUS `['organizationAiCreditPurchase']` (extra invalidation SANCTIONED #2). Route literals SANCTIONED #5 / W2.
- **`api.ts`** — `apiGet` (`allKeysToCamel` `:22`), `apiPost`/`apiMutate` (CSRF `:50`, `allKeysToSnake` `:52`, `allKeysToCamel` `:67`/`:56`) MATCH analog structure.

## Non-findings (verified forced / sanctioned — not flagged)

- Unconditional parent render of `AiCreditSubscription` (no 3-way `hasActiveSubscription` ternary); subscribed/unsubscribed fork relocated INTO `AiSubscriptionStatus`'s `isSubscribed ? … : …` (`AiSubscriptionStatus.tsx:32-52`) + subtitle ternary (`AiCreditSubscription.tsx:307`); current-plan branch renders static `Styled.CurrentTag` instead of `<ManageBillingActions>` — SANCTIONED W5.
- `currentCredits` headline via local `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` (`planHelpers.ts:74-87/115`) — SANCTIONED W4 (table existence); the lookupKey driving it is live-Stripe-derived.
- Absence of `usePlanLimitsGate`/`ValidateSubscriptionChange`/`PlanChangeBlockedModal` before the change fork — SANCTIONED #3 (no job-limit gate).
- `splitTiers(pricesData.data || [])` `.data` unwrap inside `AiCreditSubscription` (`:52`, `aiSubscriptionHelpers.ts:23`) vs analog's parent-level unwrap (`AccountBilling.tsx:54`) — placement-only; same data + `[]` fallback reaches the chain; naming SANCTIONED #5.
- No billing-period (`yearly`/`monthly`) toggle; absent `trialing`/`coupon`/legacy-plan sub-blocks (analog `:370-431`, `getPlansForPeriod` period filter `planLookups.js:555`) — main-plan-only product features; forced domain difference (AI credit subscription is monthly-only).
- `#show` / `useOrganizationAiCreditPurchase` query — SANCTIONED W3; `AiCreditSubscription.tsx` does not import it (not on this SCREEN path).
- `isMostPopular` interface field (`AiSubscriptionTierCard.tsx:15`) declared but never read — MATCHES analog `PlanCard.tsx:54` (declared-only).

---

deviation_count: 0
