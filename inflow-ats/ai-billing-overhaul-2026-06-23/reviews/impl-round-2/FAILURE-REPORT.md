# Implementation Review Round 2 -- FAILURE REPORT

## BLOCKER-1: Uncommitted changes include unspec'd model validation removal

### Location
`app/models/organization_ai_credit_purchase.rb` -- uncommitted diff (working tree only, not yet committed to the `billing-bonanza` branch)

### Problem
The working tree version of `OrganizationAiCreditPurchase` has ALL 8 `validates` declarations removed (27 lines deleted between lines 87-113 of the committed version). The committed branch still has these validations. The spec says "No data model changes" and the plan makes no mention of validation changes.

Removed validations:
```ruby
validates :stripe_price_lookup_key, presence: true,
                                   inclusion: { in: ->(_) { OrganizationAiCreditPurchase.ai_credit_lookup_keys } }
validates :kind, presence: true

validates :stripe_subscription_id,
          presence: true,
          if: -> { subscription? && stripe_checkout_session_id.blank? }
validates :subscription_credits_per_period,
          presence: true,
          numericality: { greater_than: 0 },
          if: :subscription?
validates :subscription_current_period_start,
          :subscription_current_period_end,
          presence: true,
          if: -> { subscription? && stripe_subscription_id.present? }
validates :stripe_amount,
          presence: true,
          numericality: { greater_than_or_equal_to: 0 },
          unless: -> { subscription? && stripe_subscription_id.blank? }
validates :currency,
          presence: true,
          unless: -> { subscription? && stripe_subscription_id.blank? }

validates :one_off_credits_granted,
          presence: true,
          numericality: { greater_than: 0 },
          if: :one_off?
```

### Impact
Without these validations, any `.save` or `.update` call throughout the codebase will accept malformed purchase records:
- Missing `stripe_price_lookup_key` or a lookup key not in `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY`
- Missing `kind`
- Subscription records with no `stripe_subscription_id` (when not in checkout flow)
- Subscription records with zero or nil `subscription_credits_per_period`
- Subscription records with no period start/end dates (when subscription_id is present)
- Records with nil/negative `stripe_amount`
- Records with nil `currency`
- One-off records with zero or nil `one_off_credits_granted`

These fields are set by interactors, webhook handlers, and controller actions. The validations are the last line of defense against data corruption on a payment-critical model.

### Fix
Restore the validations by reverting the model file to the committed version:

```bash
cd /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza
git checkout -- app/models/organization_ai_credit_purchase.rb
```

If the validations genuinely need to be changed (e.g., to accommodate a new code path that saves partial records), that change must be:
1. Documented in the spec with explicit reasoning
2. Included in the plan
3. Reviewed in its own cycle

### Also noted (not blocking, but out-of-scope changes in working tree)

1. **`AccountBillingAiCredits.tsx` deletion** (319 lines) -- This component is deleted from the working tree but is not mentioned in the spec, plan, or FAILURE-REPORT from Round 1. If this deletion is intentional (perhaps the component is being superseded), it needs to be spec'd separately.

2. **`delay: 30000` additions** -- Several pre-existing toast calls had their `delay` changed to 30000ms (or had `delay: 30000` added). These are at lines 167, 180, 219, 258 of `AiCreditSubscription.tsx`. Minor and harmless, but not documented in any finding or plan.

### What NOT to change (verified correct in Round 2)

1. `app/interactors/apply_ai_credit_upgrade.rb` -- correct
2. `app/interactors/schedule_ai_credit_subscription_downgrade.rb` -- correct
3. `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` -- `preview_subscription_change` and `commit_subscription_change` correct
4. `app/jobs/stripe_webhook_handler_job.rb` -- `billing_reason` routing correct
5. `config/routes.rb` -- portal routes removed, new routes added, correct
6. `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` -- hooks correct
7. `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` -- H1 fix correct, preview+modal flow correct
8. `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/aiSubscriptionHelpers.ts` -- "Downgrade" button text correct
9. `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/UpdateAiCreditSubscriptionConfirmModal.tsx` -- correct
10. All spec files -- correct
