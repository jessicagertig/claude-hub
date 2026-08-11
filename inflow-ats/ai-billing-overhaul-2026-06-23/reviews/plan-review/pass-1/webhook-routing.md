# Angle 2: Webhook Event Routing — Pass 1

## Verdict: PASS (0 BLOCKER, 0 HIGH, 0 MED, 0 LOW)

All claims verified against the live source tree at `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/jobs/stripe_webhook_handler_job.rb`.

## Verification results

| # | Claim | Verified |
|---|-------|----------|
| 1 | `handle_subscription_credit_pack_invoice_paid` at lines 472-490 | ✅ Exact match |
| 2 | Method finds by `stripe_subscription_id`, stamps payment info, calls `ApplyAiCreditPurchase.call` | ✅ Correct — lines 473-476 find, 479-487 stamp, 489 dispatch |
| 3 | Payment-info stamp ends at line 487, `ApplyAiCreditPurchase.call` at line 489 | ✅ Correct — branch goes between them |
| 4 | Guard `raise CustomStripeSubscriptionMissingError` at line 477 | ✅ Exact match |
| 5 | Invoice.paid dispatch at lines 222-306, routing at lines 283-284 | ✅ Correct |
| 6 | `CustomStripeSubscriptionMissingError` at line 286 in ELSE branch, does not affect credit-pack invoices | ✅ Correct — line 286 inside `else` of the `if subscription_lookup_key && ...` check |
| 7 | `customer.subscription.updated` handler at lines 111-165 updates `stripe_price_lookup_key` + `subscription_credits_per_period`, does NOT grant credits | ✅ Correct — updates at lines 135-141, no credit granting |
| 8 | `handle_subscription_schedule_downgrade` at lines 342-401 | ✅ Exact match |
| 9 | `subscription_schedule.updated/created` dispatch at lines 326-328 | ✅ Exact match |
| 10 | `downgrade_detected?` at lines 403-413, only recognizes ATS plan tiers | ✅ Method body at 403-414, tier list is `%w[free starter growth scale enterprise]` — no AI credit lookup keys |
| 11 | `stripe-invoice-subscription-update-example.json` exists with `billing_reason: "subscription_update"` | ✅ Confirmed |

## Guard ordering (known failure pattern #8)

Verified: The only guard in `handle_subscription_credit_pack_invoice_paid` is `raise CustomStripeSubscriptionMissingError if organization_ai_credit_purchase.nil?` at line 477, which fires before any billing_reason branching. This guard applies correctly to ALL invoice types — a missing purchase is an error regardless of billing_reason. No guard between method entry and the proposed billing_reason branch would reject upgrade invoices.

## Routing correctness

Verified: The `invoice.paid` dispatch at line 283 checks `OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?(subscription_lookup_key)` and routes to `handle_subscription_credit_pack_invoice_paid` at line 284. This routing operates on the subscription's current lookup key (retrieved live from Stripe at line 281), not on invoice metadata. The plan's proposed `billing_reason` branch inside the handler is correctly placed after the routing decision.

## Note (not a finding)

The `customer.subscription.updated` handler at lines 130-134 uses the shortened variable name `purchase` for the `OrganizationAiCreditPurchase` record. This is pre-existing code not modified by this plan — the plan correctly notes in A.6 that `CancelAiCreditSubscription` uses the same violation and says "DO NOT copy."
