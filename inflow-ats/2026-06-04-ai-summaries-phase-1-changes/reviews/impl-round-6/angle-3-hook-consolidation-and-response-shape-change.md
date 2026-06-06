# Angle 3: Hook Consolidation and Response Shape Change — Round 6

## Review

### `useOrganizationAiCreditPurchase.ts`

Contains all five hooks per spec:

1. `useOrganizationAiCreditPurchase` -- GET `/ai_credit_purchases`, query key `["organizationAiCreditPurchase"]`, returns `OrganizationAiCreditPurchase | null`. Correct.
2. `useCheckoutAiCreditPack` -- POST `/ai_credit_purchases/checkout`, variables key `{ organizationAiCreditPurchase: params }`. Invalidates `["organizationAiCreditPurchase"]` on success. Correct.
3. `usePurchaseAiCreditTopUp` -- POST `/ai_credit_purchases/purchase_top_up`, variables key `{ organizationAiCreditPurchase: params }`. Invalidates `["organizationAiCreditBalance"]` on success. Correct.
4. `useCancelAiCreditSubscription` -- PUT `/ai_credit_purchases/cancel`. Invalidates both `["organizationAiCreditPurchase"]` and `["organizationAiCreditBalance"]`. Correct.
5. `useOrganizationAiCreditPurchasePrices` -- GET `/ai_credit_purchases/prices`, query key `["organizationAiCreditPurchasePrices"]`. Correct.

Pattern follows `useOrganizationAiCreditBalance.ts` with `refetchOnWindowFocus: false`.

### `AccountBillingAiCredits.tsx`

- Imports all five hooks from consolidated file. Correct.
- Imports `aiCreditPrices` from `planHelpers.ts`. Correct.
- No hardcoded `SUBSCRIPTION_TIERS` or `TOP_UP_TIERS`. Correct.
- Response shape: `subscription` used directly (no `.aiCreditSubscription` unwrap). Correct.
- Uses `aiCreditPrices(pricesData.data || [])` to build pack list. Correct.
- Partitions by `kind` into subscription and top-up arrays. Correct.
- `subscribe` uses `useCheckoutAiCreditPack`. Correct.
- `purchase` uses `usePurchaseAiCreditTopUp`. Correct.

### `planHelpers.ts`

- `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` with four correct packs. Correct.
- `aiCreditPrices` function matches spec exactly. Uses `p.lookupKey` (camelCased), `price.type === "recurring"`, `price.unitAmount / 100`. Correct.

### Old hook files deleted

Verified in diff: `useAiCreditSubscription.ts`, `useSubscribeToAiCreditPack.ts`, `usePurchaseAiCreditTopUp.ts`, `useCancelAiCreditSubscription.ts` are deleted.

## Findings

No findings. All spec requirements met.

## Verdict: PASS (0 HIGH, 0 MED)
