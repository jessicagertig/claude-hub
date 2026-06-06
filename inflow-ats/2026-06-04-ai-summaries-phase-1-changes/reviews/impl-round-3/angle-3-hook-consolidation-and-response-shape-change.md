# Angle 3: Hook Consolidation and Response Shape Change -- Round 3

## Files reviewed

- `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` (new)
- `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingAiCredits.tsx`
- `app/javascript/shared/lib/planHelpers.ts`
- `app/javascript/shared/types/organizationAiCreditPurchase.ts` (new)
- Verified 4 old hook files deleted

## Findings

**No new findings.**

All hooks match spec:
- `useOrganizationAiCreditPurchase`: GET `/ai_credit_purchases`, query key `["organizationAiCreditPurchase"]`, returns `OrganizationAiCreditPurchase | null` (no wrapper)
- `useCheckoutAiCreditPack`: POST `/ai_credit_purchases/checkout`, variables `{ organizationAiCreditPurchase: params }`, invalidates `["organizationAiCreditPurchase"]`
- `usePurchaseAiCreditTopUp`: POST `/ai_credit_purchases/purchase_top_up`, variables `{ organizationAiCreditPurchase: params }`, invalidates `["organizationAiCreditBalance"]`
- `useCancelAiCreditSubscription`: PUT `/ai_credit_purchases/cancel`, invalidates both query keys
- `useOrganizationAiCreditPurchasePrices`: GET `/ai_credit_purchases/prices`, query key `["organizationAiCreditPurchasePrices"]`
- `AccountBillingAiCredits` removes wrapper unwrap, removes hardcoded tiers, uses `aiCreditPrices` from `planHelpers.ts`
- `aiCreditPrices` function uses camelCased Stripe fields and correct credit amounts
- Type file correctly renamed from `aiCreditSubscription.ts` to `organizationAiCreditPurchase.ts`
