# Angle 1: Stripe API Contract — Round 4

## Re-verification of Round 3 amendment (S4)

The `commit_subscription_change` controller now specifies (step 3) retrieving the new price from Stripe via `Stripe::Price.retrieve(determine_price_id)` to obtain `new_lookup_key`. Step 4 uses `OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key` for both current and new lookup keys to compare credit amounts. The step numbering is correct (1-7). Amendment verified correct. PASS.

## Deep sweep

- Preview/commit params still match exactly (both use `determine_price_id`, same `items`/`proration_behavior`/`proration_date`)
- The additional `Stripe::Price.retrieve` call in the commit path is acceptable (user-initiated, not webhook-frequency)
- The `proration_date` is set to `subscription_current_period_start` for full-price math (approved decision #3)

No new findings. PASS.
