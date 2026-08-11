# Angle 4: Downgrade Scheduling — Round 1

## Checks performed

1. Verified `handle_subscription_schedule_downgrade` method (lines 342-401 confirmed)
2. Verified `subscription_schedule.updated/created` dispatch (lines 326-328 confirmed)
3. Verified `downgrade_detected?` logic against AI credit lookup keys
4. Verified the interactor's Stripe-first pattern against `CancelAiCreditSubscription` analog
5. Checked edge case: existing pending schedule

## Findings

### D1: `downgrade_detected?` does not recognize AI credit subscription lookup keys — Discord/engagement notifications will NOT fire — MED

**Location:** SPEC.md lines 183-184, 905-909

**Problem:** The spec says (line 184): "the `handle_subscription_schedule_downgrade` method in `StripeWebhookHandlerJob` already handles `subscription_schedule.updated` and `subscription_schedule.created` events — it detects downgrades and fires Discord notification + engagement report jobs."

The sequence diagram (lines 905-909) says:
```
-> handle_subscription_schedule_downgrade detects downgrade
-> Fires Discord notification and engagement report jobs
```

This is incorrect. `downgrade_detected?` (lines 403-413 of `stripe_webhook_handler_job.rb`) uses:
```ruby
plan_tiers = %w[free starter growth scale enterprise]
```

AI credit subscription lookup keys are `plato_ai_credit_subscription_small`, `plato_ai_credit_subscription_medium`, `plato_ai_credit_subscription_large`. None of these contain "free", "starter", "growth", "scale", or "enterprise". Both `current_tier` and `next_tier` would resolve to `0` (the `|| 0` default), and `next_tier < current_tier` would be `false`.

The handler WILL execute (it finds the org by `stripe_customer_id` and the phases have different prices), but `downgrade_detected?` will return `false`, so the Discord/engagement notifications will silently not fire.

**Impact:** The spec makes a false claim about existing behavior. The implementer may rely on this claim and not realize notifications are missing. Whether AI credit downgrades SHOULD fire these notifications is a product decision — but the spec must not claim they already do.

**Fix:** Amend the spec to state that `downgrade_detected?` currently only handles ATS plan tiers, NOT AI credit subscription tiers. Either: (a) note that AI credit downgrade notifications are out of scope and remove the claim, or (b) add `downgrade_detected?` modification to the spec's scope to also handle AI credit lookup keys. Given the spec says "No data model changes" and is focused on the subscription change flow, option (a) is simpler.

### D2: Pending schedule edge case is an explicit TBD — LOW (informational)

**Location:** SPEC.md lines 188-189

**Problem:** The spec says "If the subscription already has a pending schedule, the create call may need to update the existing schedule instead." This is an acknowledged TBD. The `Stripe::SubscriptionSchedule.create(from_subscription: ...)` call will fail with a `Stripe::InvalidRequestError` if the subscription already has an active schedule.

This affects the case where a user downgrades, then tries to downgrade again (to a different tier) before the first downgrade takes effect. Or upgrades after scheduling a downgrade.

**Severity:** LOW — the spec explicitly acknowledges this as a TBD and the error would be caught by the Stripe error rescue. The user would see an error toast. A follow-up spec can address the edge case if needed.

## Verdict

1 MED finding (D1). Requires spec amendment.
