# Angle 3: Hook Consolidation and Response Shape Change -- Round 2

## Scope

Deletion of four hook files, new `useOrganizationAiCreditPurchase.ts`, `AccountBillingAiCredits.tsx` refactor, `planHelpers.ts` additions.

## Findings

### F1 (CLEAR) -- Consolidated hook file implements all five hooks

`useOrganizationAiCreditPurchase.ts` exports `useOrganizationAiCreditPurchase` (GET), `useCheckoutAiCreditPack` (POST), `usePurchaseAiCreditTopUp` (POST), `useCancelAiCreditSubscription` (PUT), `useOrganizationAiCreditPurchasePrices` (GET). Query keys, paths, and invalidation patterns match spec.

### F2 (CLEAR) -- Response shape unwrap removed

`AccountBillingAiCredits.tsx` no longer accesses `subscriptionData?.aiCreditSubscription`. The new hook returns `OrganizationAiCreditPurchase | null` directly.

### F3 (CLEAR) -- Hardcoded tiers replaced with Stripe-fetched prices

`SUBSCRIPTION_TIERS` and `TOP_UP_TIERS` arrays removed. `useOrganizationAiCreditPurchasePrices` fetches from API. `aiCreditPrices(pricesData.data || [])` transforms. Partitioned by `kind`.

### F4 (CLEAR) -- Variables keys updated

`{ organizationAiCreditPurchase: params }` used in checkout and top-up hooks.

### F5 (CLEAR) -- Old hook files deleted

`useAiCreditSubscription.ts`, `useSubscribeToAiCreditPack.ts`, `usePurchaseAiCreditTopUp.ts`, `useCancelAiCreditSubscription.ts` all deleted.

### F6 (CLEAR) -- `planHelpers.ts` additions match spec

`AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` has four correct keys. `aiCreditPrices` transforms `stripePrices` using `lookupKey`, `type`, `unitAmount`, `recurring`. The `prices` array is typed as `any[]` to avoid TS errors.

### F7 (CLEAR) -- Type file renamed

`aiCreditSubscription.ts` deleted, `organizationAiCreditPurchase.ts` created with `OrganizationAiCreditPurchase` interface and `OrganizationAiCreditPurchaseStatus` type.

## Verdict: 0 findings. PASS for this angle.
