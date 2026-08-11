# Round 1 — FRONTEND segment (adversarial, OURS vs analog trace)

Chain traced:
`AiCreditSubscription.tsx` → `useOrganizationAiCreditPurchase.ts` (`useAiCreditCustomerSubscription`, `useOrganizationAiCreditPurchase`) → `api.ts` (`apiGet`) → `aiSubscriptionHelpers.ts` (`splitTiers`, `deriveTierButtonText`, `formatResetDate`) → `planHelpers.ts` (`aiCreditPrices`, `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY`) → `AiSubscriptionStatus.tsx` (SCREEN). Analog: `AccountBillingPlans.tsx` → `useBilling.ts` (`useStripeCustomerSubscription`) → `api.ts` → `planLookups.js`.

Analog structural anchor: in the analog the entire current-subscription DISPLAY is derived from `currentSubscription` (the LIVE Stripe subscription from `useStripeCustomerSubscription`, trace items 9, 16). `currentOrganization.plan` (a local column) is read ONLY for the legacy-plan display *name* (`getPricingDisplayName`, `:156`), never to gate whether a subscription is shown or what its amount/period is. `isCurrentPlan = currentSubscription?.plan?.id === plan.priceId` (`:436`). No local DB `subscription_status`/period/amount column gates the analog's display anywhere.

---

## F1 (BLOCKER) — Active-subscription display gates on the LOCAL `subscription_status` column, not on the live Stripe subscription

ANALOG (trace items 9, 16, 28): the "is there an active subscription / what plan / what amount / what period" display is derived entirely from `currentSubscription` (live Stripe, from `useStripeCustomerSubscription`). Whether a subscription renders is a function of `currentSubscription` being non-null (`currentSubscription?.status`, `currentSubscription.items.data[0].price`, `currentSubscription?.plan?.id`). There is NO read of a local DB subscription-status column to decide display.

OURS: the `AiSubscriptionStatus` SCREEN block (the active-subscription banner — the exact terminal named in the symptom) is gated on `isSubscribed`, which reads the LOCAL purchase row's DB column, not the live Stripe subscription:
- `isSubscribed = subscription?.subscriptionStatus === "active" || subscription?.subscriptionStatus === "past_due"` — `AiCreditSubscription.tsx:59`. `subscription` is the result of `useOrganizationAiCreditPurchase()` (`:30`), which GETs `/ai_credit_purchases` (`useOrganizationAiCreditPurchase.ts:6`, the `#show` local row); `subscriptionStatus` is the serializer's `subscription_status` DB column (`organization_ai_credit_purchase_serializer.rb:14`). This is the live-Stripe-vs-local-column divergence that is the reported symptom: an active Stripe subscription does NOT display when the local `subscription_status` column is stale/empty.
- `isSubscribed` is passed to `<AiSubscriptionStatus isSubscribed={isSubscribed} .../>` (`AiCreditSubscription.tsx:261`), which gates the entire "Active subscription" branch (`AiSubscriptionStatus.tsx:28-42`) and the Cancel button (`:44-48`) — SCREEN terminals.

OURS already fetches the live subscription as `currentSubscription` (`AiCreditSubscription.tsx:55-57`, from `useAiCreditCustomerSubscription`, the analog-parallel hook) but uses it ONLY for `currentSubscriptionItemId` (`:58`) and the per-tier `isCurrent` badge (`:272`) — NOT to gate the active-subscription display. The display must be derived from `currentSubscription` (matching the analog), not the local `subscription_status` column.

file:line — `AiCreditSubscription.tsx:59` (and consumers `:60`, `:261-263`, `:268`, `:278`, `:282`)

---

## F2 (BLOCKER) — `currentCredits` (displayed current tier amount) derives from the LOCAL column, not the live subscription's price

ANALOG (trace items 9, 14): the current displayed plan amount is derived from `currentSubscription` → `currentPriceObject = currentSubscription && currentSubscription.items.data[0].price` (`AccountBillingPlans.tsx:67`), and the per-tier current-plan match is `currentSubscription?.plan?.id === plan.priceId`. The current amount/price always comes off the live Stripe subscription's price object.

OURS: `currentCredits = isSubscribed ? subscription?.subscriptionCreditsPerPeriod || null : null` — `AiCreditSubscription.tsx:60`. This reads `subscriptionCreditsPerPeriod` off the LOCAL purchase row (serializer `subscription_credits_per_period`, `organization_ai_credit_purchase_serializer.rb:13`), gated by the local-column `isSubscribed` (F1). The analog's equivalent (current tier amount) is derived from the live `currentSubscription.items.data[0].price` and mapped through the lookup_key. OURS should derive the current credits from the live `currentSubscription`'s price (its `lookupKey` → `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` in `planHelpers.ts:68`, the same table `aiCreditPrices` uses at `:97`), not from the local column. `currentCredits` is rendered to the SCREEN at `AiSubscriptionStatus.tsx:31` (`{currentCredits?.toLocaleString()} credits / month`).

file:line — `AiCreditSubscription.tsx:60` (rendered `AiSubscriptionStatus.tsx:31`)

---

## F3 (BLOCKER) — Renewal/period-end display derives from the LOCAL column, not the live subscription

ANALOG (trace item 9): period/renewal data on the current-subscription render comes from the live `currentSubscription` (e.g. `currentSubscription.trialEnd` `:380`, `currentSubscription.cancelAt` `:393`, `prettyDate(...)` off the live object). The live Stripe subscription is the source of period dates shown for the active subscription.

OURS: `periodEndsAt={subscription?.subscriptionCurrentPeriodEnd}` is passed to `<AiSubscriptionStatus>` (`AiCreditSubscription.tsx:263`) reading the LOCAL purchase row's `subscription_current_period_end` column (serializer `:14`). It renders to the SCREEN via `formatResetDate(periodEndsAt)` → `Renews {...}` (`AiSubscriptionStatus.tsx:33`). The analog reads renewal/period dates from the live `currentSubscription` object (e.g. `currentSubscription.currentPeriodEnd`), not a local DB column. The same period date is also passed to the cancel-confirm modal as `periodEndsAt={subscription?.subscriptionCurrentPeriodEnd}` (`AiCreditSubscription.tsx:249`) — same local-column source.

file:line — `AiCreditSubscription.tsx:263` (and `:249`; rendered `AiSubscriptionStatus.tsx:33`)

---

## F4 (HIGH) — `deriveTierButtonText` keys off local-column-derived `currentCredits`, so button text follows the wrong source

ANALOG (trace item 15): the per-plan button text is `currentPriceObject?.lookupKey ? getPlanButtonText(currentPriceObject.lookupKey, plan.lookupKey, billingPeriod) : ...` (`AccountBillingPlans.tsx:180-184`). The "what is my current plan" input to button-text is `currentPriceObject.lookupKey` — derived from the LIVE `currentSubscription`, not a local column.

OURS: `buttonText: deriveTierButtonText(isSubscribed, currentCredits, tier.credits)` (`AiCreditSubscription.tsx:278`). `deriveTierButtonText` (`aiSubscriptionHelpers.ts:30-39`) branches on `isSubscribed` (local column, F1) and compares `tierCredits` against `currentCredits` (local column, F2). So Upgrade/Downgrade/Change-plan/Subscribe labels are computed from the stale local source rather than the live subscription's current lookup_key/credits. Once F1/F2 derive `isSubscribed`/`currentCredits` from the live `currentSubscription`, this consumer is corrected by source; flagged because its inputs are the deviating locals. (The analog keys button text off the live `currentPriceObject.lookupKey`.)

file:line — `AiCreditSubscription.tsx:278`, `aiSubscriptionHelpers.ts:30-39`

---

## Notes / non-findings (verified MATCH or sanctioned)

- `currentSubscription = aiCreditCustomerSubscriptionData ? aiCreditCustomerSubscriptionData.subscription : null` (`AiCreditSubscription.tsx:55-57`) — MATCHES analog `AccountBillingPlans.tsx:62-64` (`data` renamed, `.subscription` unwrap, `null` fallback). The hook `useAiCreditCustomerSubscription` GET `/ai_credit_purchases/customer_subscription` (`useOrganizationAiCreditPurchase.ts:164-187`) is the sanctioned parallel of `useStripeCustomerSubscription` (SANCTIONED #4).
- `currentSubscriptionItemId = currentSubscription && currentSubscription.items.data[0].id` (`:58`) — MATCHES analog `:136`.
- `isCurrent = currentSubscription?.plan?.id === tier.priceId` (`:272`) — MATCHES analog `isCurrentPlan` (`:436`), correctly off the LIVE subscription.
- `isFetchingAiCreditCustomerSubscription` early-return `<LoadingIndicator label="Loading..." />` (`:254-256`) — MATCHES analog early-return loading terminal (`AccountBillingPlans.tsx:352-354`).
- `handleSelectTier` fork on `currentOrganization.stripeDefaultPaymentMethodOnFile` (`:146-157`) — MATCHES analog `handleChangeSubscriptionWithGate` fork (`:326`). Absence of the `usePlanLimitsGate`/`ValidateSubscriptionChange` gate is SANCTIONED #3 — not flagged.
- `apiGet`/`apiPost` transport, `returnUrl: "/hire/settings/plato-ai/billing"` path literal — domain-path naming, SANCTIONED #5 family — not flagged.
- `aiCreditPrices` / `splitTiers` price-table mapping (`planHelpers.ts:86-106`, `aiSubscriptionHelpers.ts:19-28`) — analog has no local price↔credits table (round-trips Stripe), but the AI-credit domain's lookup_key→credits table is SANCTIONED #5 (`ai_credit_*` naming / `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` family) — not flagged.
</content>
</invoke>
