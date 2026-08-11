# Angle 1: Stripe API Contract — Round 3

## Re-verification of Round 2 amendment (S3)

The `CommitSubscriptionChangeParams` no longer includes `isDowngrade`. The frontend sends only `{ priceId }`. The controller description (line 114) says it determines upgrade/downgrade server-side by comparing `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY[current_lookup_key]` vs `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY[new_lookup_key]`.

## New finding

### S4: Controller lacks mechanism to obtain `new_lookup_key` from `price_id` — MED

**Location:** SPEC.md line 114

**Problem:** The spec says the controller determines upgrade/downgrade by comparing `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY[current_lookup_key]` vs `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY[new_lookup_key]`. The `current_lookup_key` is available from `organization_ai_credit_purchase.stripe_price_lookup_key`. But the controller only has the new plan's Stripe price ID (from `determine_price_id` / `params[:price_id]`) — not its lookup key.

`AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` is keyed by lookup key (e.g., `plato_ai_credit_subscription_medium`), not by Stripe price ID (e.g., `price_1S6STuAsxjgRMuPmNBF7iIKg`). There is no reverse mapping (price ID to lookup key) in the model.

To obtain `new_lookup_key`, the controller must either:
1. Call `Stripe::Price.retrieve(determine_price_id).lookup_key` (adds one Stripe API call but is authoritative)
2. Accept `lookupKey` as a frontend param (but then a malicious client could send a mismatched lookup key)

**Recommended fix:** Add to the controller spec that it retrieves the new price from Stripe to obtain the lookup key: `new_price = Stripe::Price.retrieve(determine_price_id); new_lookup_key = new_price.lookup_key`. This is authoritative, untamperable, and a single lightweight Stripe call (price retrieval is fast/cached).

## Verdict

1 MED finding (S4). Requires spec amendment.
