# Pass 2: Angles 5-6 (Frontend data flow, Portal removal) — Fresh scrutiny

## Verdict: PASS (0 BLOCKER, 0 HIGH, 0 MED, 0 LOW)

## Checks performed

### 1a. Query key `aiCreditCustomerSubscription`

**Verified:** `useOrganizationAiCreditPurchase.ts` line 184: `useQuery(["aiCreditCustomerSubscription"], ...)`. Plan's invalidation key matches exactly.

### 1b. `priceDollars` type

**Verified:** `AiCreditTier` interface at `AiSubscriptionTierCard.tsx` line 10: `priceDollars: number`. Computed at `planHelpers.ts` line 117: `price.unitAmount / 100`. Always a number — `.toFixed(2)` is safe.

### 1c. `currentCredits` variable

**Verified:** `AiCreditSubscription.tsx` lines 66-70:
```typescript
const currentSubscriptionTier = isSubscribed && currentPlanLookupKey
  ? subscriptionTiers.find((tier) => tier.lookupKey === currentPlanLookupKey)
  : null;
const currentCredits = currentSubscriptionTier ? currentSubscriptionTier.credits : null;
```
Type is `number | null`. Plan's `isDowngrade` computation `currentCredits != null && tier.credits < currentCredits` correctly handles the null case (evaluates to `false` when `currentCredits` is null, which is correct — no downgrade determination when credits are unknown).

### 1d. `currentPlanLookupKey` variable

**Verified:** `AiCreditSubscription.tsx` line 58: `const currentPlanLookupKey = currentPriceObject?.lookupKey;`. Type is `string | undefined`. Plan's usage as fallback for `currentPlanLookupKeyFromPreview` is correct — it provides the current plan's lookup key when no negative line item exists in the preview.

### 1e. `removeModal` and `openModal` availability

**Verified:** `AiCreditSubscription.tsx` line 49: `const { openModal, removeModal } = useModalContext();`. Both available — used extensively in the component (e.g., `handleBuyPack` at line 252, `handleCancelClick` at line 270).

### 1f. `addToast` availability

**Verified:** `AiCreditSubscription.tsx` line 48: `const addToast = useToastContext();`. Available — used in every error handler and in `handleCancelClick` success.

### 2. `handleSelectTier` completeness

**Verified:** Current `handleSelectTier` at lines 158-170:
```typescript
const handleSelectTier = (tier: AiCreditTier) => {
  if (currentOrganization.stripeDefaultPaymentMethodOnFile) {
    handleChangeSubscriptionViaStripePortal({
      priceId: tier.priceId,
      subscriptionItemId: currentSubscriptionItemId,
    });
  } else {
    handleUpdateWithPaymentMethod({
      priceId: tier.priceId,
      subscriptionItemId: currentSubscriptionItemId,
    });
  }
};
```

The function:
1. Reads `currentOrganization.stripeDefaultPaymentMethodOnFile` to fork between portal and payment-method-update flows
2. Passes `tier.priceId` and `currentSubscriptionItemId` to whichever handler

The new flow replaces ALL of this. No local state is set. No side effects beyond the mutation call. The `currentSubscriptionItemId` is no longer needed by the new flow (the backend extracts the subscription item ID from the live Stripe subscription). The `stripeDefaultPaymentMethodOnFile` check is no longer needed (the new flow doesn't fork on payment method presence — the backend preview returns payment method info, and if no payment method exists, the Stripe calls fail with a user-visible error).

Plan B.3.7 correctly notes: "The `stripeDefaultPaymentMethodOnFile` check at line 159 inside `handleSelectTier` is removed as part of the function replacement. The check at line 250 inside `handleBuyPack` is NOT removed -- it's for the top-up flow." Verified: line 250 is indeed in `handleBuyPack`, not in `handleSelectTier`.

No missing state, no missing side effects. The replacement is complete.
