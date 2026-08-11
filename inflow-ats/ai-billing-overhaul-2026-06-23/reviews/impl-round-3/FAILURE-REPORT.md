# Implementation Review Round 3 -- Failure Report

**Verdict: FAIL** (0 BLOCKER, 0 HIGH, 1 MED, 0 LOW)

---

## MED-1: Out-of-scope rewrite of `customer_subscription` action

**Severity:** MED
**File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:360-375`

### Description

The `customer_subscription` action was completely rewritten with different behavior. This action is NOT listed as modified in the spec or plan. The spec says the controller modifications are: add `preview_subscription_change` and `commit_subscription_change`; remove three portal actions. `customer_subscription` was supposed to remain unchanged.

### What changed

| Aspect | Old (committed) | New (working tree) |
|--------|----------------|-------------------|
| Data source | Local DB lookup (`OrganizationAiCreditPurchase.find_by`) then `Stripe::Subscription.retrieve` on the specific subscription ID | `Stripe::Subscription.list` (all customer subs) then filter by lookup key |
| Stripe expand | `expand: ['items.data.price.tiers']` | No expand param |
| Filtering | `kind: :subscription, subscription_status: [:active, :past_due]` via ActiveRecord scope | String matching on `lookup_key.include?('credit') \|\| lookup_key.include?('plato')` |
| Status priority | Local DB enforces `[:active, :past_due]` | `trialing > active > first` in Ruby |
| Nil handling | Explicit `if nil? then render nil` | `|| []` fabricated fallback (known failure pattern #13) |
| Begin block | `begin...rescue...end` inside `else` | Method-level rescue (improvement) |

### Risk

The frontend's `useAiCreditCustomerSubscription` hook calls `GET /ai_credit_purchases/customer_subscription` and the response feeds into `AiCreditSubscription.tsx` which uses the subscription object to display tier card states. Two specific risks:

1. **Missing `price.tiers` expansion:** The old version expanded `items.data.price.tiers` in the Stripe API call. The new version does not. If any frontend code reads `price.tiers` from the subscription object, it will get undefined instead of the expanded data.

2. **Different subscription selection:** The old version used a model-scoped query that only finds `subscription` kind purchases with `active` or `past_due` status. The new version lists all customer subscriptions and filters by lookup key string matching, which could match subscriptions the old code would not have returned (or miss ones it would have).

### Fix

Revert the `customer_subscription` action to its committed version. A minimal begin-block cleanup (keeping the same data source and logic) is acceptable:

```ruby
def customer_subscription
  organization_ai_credit_purchase = current_organization.organization_ai_credit_purchases
    .subscription.find_by(subscription_status: [:active, :past_due])
  if organization_ai_credit_purchase.nil? || organization_ai_credit_purchase.stripe_subscription_id.nil?
    render json: { subscription: nil }
  else
    render json: { subscription: organization_ai_credit_purchase.stripe_subscription }
  end
rescue StandardError => e
  Sentry.capture_exception(e)
  Rails.logger.error(e)
  render json: { errors: ['Unable to load subscription'] }
end
```

The `ap` debug lines from the old version can also be removed as cleanup.

If the full data-source rewrite is desired, it needs:
1. Its own spec entry documenting the behavioral change
2. Frontend impact analysis (does anything read `price.tiers`?)
3. Test coverage for the new behavior
4. Removal of the `|| []` fabricated fallback

---

## What NOT to change

The following are confirmed correct and must not be modified:

- `app/interactors/apply_ai_credit_upgrade.rb` -- all angles pass
- `app/interactors/schedule_ai_credit_subscription_downgrade.rb` -- all angles pass
- `app/jobs/stripe_webhook_handler_job.rb` -- billing_reason branch is correct
- `config/routes.rb` -- route changes are correct
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/UpdateAiCreditSubscriptionConfirmModal.tsx` -- modal is correct
- `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` -- hooks are correct
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` -- handleSelectTier is correct
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/aiSubscriptionHelpers.ts` -- deriveTierButtonText is correct
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` -- `preview_subscription_change` and `commit_subscription_change` are correct
- All test files -- coverage is complete
- `app/models/organization_ai_credit_purchase.rb` -- validations must remain intact
