# Always-On A4: Full-Stack Analog Completeness -- Round 4

## Re-verified

All analog checks from Round 3 re-confirmed.

## Additional analog verification

### Request/response key casing (cross-cutting concern)
- Frontend mutations send camelCase keys
- `api.ts:52` transforms to snake_case via `allKeysToSnake`
- Backend receives snake_case via `params.require(:organization_ai_credit_purchase).permit(:stripe_price_lookup_key)`
- Backend responses use snake_case (serializers or raw Stripe objects)
- `api.ts:22,67` transforms responses to camelCase via `allKeysToCamel`
- Frontend reads camelCase keys

This matches the existing app-wide convention. No analog deviation.

### `render json: nil` for empty show
- `OrganizationAiCreditPurchasesController#show` renders `render json: nil` when no active subscription found
- The frontend hook types the return as `OrganizationAiCreditPurchase | null`
- Consumer checks `subscription` truthiness before accessing properties
- Correct pattern.

## Findings

**No findings.**
