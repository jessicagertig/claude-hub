# Angle 3: Hook Consolidation and Response Shape Change -- Round 4

## Fresh adversarial focus areas

1. **Response shape change.** Old: `{ aiCreditSubscription: ... }`. New: direct object or `null`. Consumer removes wrapper unwrap. Confirmed correct.

2. **Query key references.** All invalidation calls use new keys. No stale key references found.

3. **`aiCreditPrices` field name casing.** Initially concerned that `p.lookupKey` (camelCase) would not match the raw Stripe response's `lookup_key` (snake_case). **Investigated and resolved:** `api.ts:22` applies `allKeysToCamel(data)` to all `apiGet` responses, transforming `lookup_key` to `lookupKey`. Similarly, `api.ts:52` applies `allKeysToSnake(variables)` to all mutation variables, transforming `{ organizationAiCreditPurchase: { stripePriceLookupKey } }` to `{ organization_ai_credit_purchase: { stripe_price_lookup_key } }`. All field names are correctly handled by the casing middleware.

4. **`useOrganizationAiCreditPurchasePrices` response handling.** The hook returns the raw Stripe `ListObject` (after camelCase transform). The consumer accesses `pricesData.data` which corresponds to the Stripe list's `data` array. Correct.

## Findings

**No findings.**
