# Sanctioned Deviation #2 — Full Structural Map

"Operates on a separate OrganizationAiCreditPurchase record, not org columns."

This document maps every column, method, and webhook handler operation between the main subscription (on `organizations`) and the AI credit subscription (on `organization_ai_credit_purchases`).

---

## A. Column-by-column mapping

### Stripe identification columns

| Purpose | organizations column | organization_ai_credit_purchases column | Match? |
|---|---|---|---|
| Stripe customer | `stripe_customer_id` (string) | — (reads via `organization.stripe_customer_id`) | N/A — shared |
| Stripe subscription ID | `stripe_subscription_id` (string) | `stripe_subscription_id` (string) | SAME |
| Stripe checkout session | `stripe_checkout_session_id` (string) | `stripe_checkout_session_id` (string) | SAME |
| Stripe invoice ID | — (none) | `stripe_invoice_id` (string) | EXTRA — org has no per-invoice tracking |
| Stripe invoice item ID | — (none) | `stripe_invoice_item_id` (string) | EXTRA — added to match WWR/WhatJobs |
| Stripe invoice paid | — (none) | `stripe_invoice_paid` (boolean) | EXTRA — added to match WWR/WhatJobs |
| Stripe amount | — (none) | `stripe_amount` (integer) | EXTRA — added to match WWR/WhatJobs |

### Subscription state columns

| Purpose | organizations column | organization_ai_credit_purchases column | Match? |
|---|---|---|---|
| Subscription status | `stripe_subscription_status` (string, raw Stripe) | `subscription_status` (integer enum) | DIFFERENT type |
| Period end | `stripe_current_period_end_at` (datetime) | `subscription_current_period_end` (datetime) | DIFFERENT name |
| Period start | — (none) | `subscription_current_period_start` (datetime) | EXTRA |
| Cancel at period end | `stripe_cancel_at_period_end` (boolean) | `stripe_cancel_at_period_end` (boolean) | SAME |
| Canceled at | `subscription_canceled_at` (datetime) | `subscription_canceled_at` (datetime) | SAME |

---

## B. Instance method mapping

| Purpose | Organization method | OrganizationAiCreditPurchase method | Match? |
|---|---|---|---|
| Retrieve live Stripe subscription | `stripe_subscription` | `stripe_subscription` | SAME (byte-for-byte identical) |
| Full reconciliation | `sync_with_stripe` | — (none) | MISSING — no reconciliation method; writes inline in webhook |
| Update default payment method | `stripe_update_default_payment_method` | — (none; uses org's) | N/A — shared |
| Charge default payment method | — (none) | `charge_default_payment_method` | EXTRA — one-off purchase method (WWR analog) |
| Finalize payment | — (none) | `finalize_stripe_payment` | EXTRA — one-off purchase method (WWR analog) |

---

## C. Webhook handler comparisons

### checkout.session.completed

| Step | Main subscription (org) | AI credit subscription (purchase) |
|---|---|---|
| Find record | `find_by(stripe_checkout_session_id:)` | `find_by(stripe_checkout_session_id:)` — SAME |
| Stamp subscription ID | `organization.update(stripe_subscription_id:)` | `purchase.update_columns(stripe_subscription_id:)` — DIFFERENT (`update_columns` skips validations) |
| Stamp customer ID | `organization.update(stripe_customer_id:)` | — MISSING (org already has customer) |
| Update Stripe customer name | `Stripe::Customer.update(...)` | — MISSING |
| Copy metadata to subscription | `Stripe::Subscription.update(..., metadata:)` | — MISSING |
| Error handling | `rescue StandardError` — swallowed | Explicit nil check, no rescue — DIFFERENT |

### customer.subscription.updated

| Step | Main subscription (org) | AI credit subscription (purchase) |
|---|---|---|
| Route guard | `object.id == organization.stripe_subscription_id` | `ai_credit_subscription_plan_lookup_key?(plan_lookup_key)` — DIFFERENT |
| Update period end | `organization.update(stripe_current_period_end_at:)` | `purchase.update(subscription_current_period_end:)` — SAME pattern |
| Update period start | — (none) | `purchase.update(subscription_current_period_start:)` — EXTRA |
| Update status | `organization.update(stripe_subscription_status: object.status)` raw string | `purchase.update(subscription_status: object.status)` enum — SAME pattern |
| Update cancel at period end | `organization.update(stripe_cancel_at_period_end:)` | — MISSING |
| Update lookup key / plan | Via `sync_with_stripe` | `purchase.update(stripe_price_lookup_key:)` inline — DIFFERENT mechanism |
| Update credits | Via `PlanFeatureGate` | `purchase.update(subscription_credits_per_period:)` inline — DIFFERENT mechanism |
| Update default payment method | `stripe_update_default_payment_method` | — MISSING |
| Full sync | `sync_with_stripe` | — MISSING |

### invoice.paid

| Step | Main subscription (org) | AI credit subscription (purchase) |
|---|---|---|
| Subscription guard | `raise CustomStripeSubscriptionMissingError` | `return unless existing` (NO logging) — DIFFERENT |
| Update period end | `organization.update(stripe_current_period_end_at:)` inline | Inside `ApplyAiCreditPurchase` — DIFFERENT location |
| Stamp amount/currency | — (none) | `existing.update(stripe_amount:, currency:)` — EXTRA |
| Update default payment method | `stripe_update_default_payment_method` | — MISSING |
| Reset credits | `reset_ai_credits` | Creates new ledger entry (ADDS, not resets) — FUNDAMENTALLY DIFFERENT purpose |
| Finalize payment marker | — (none) | `finalize_stripe_payment` → `stripe_invoice_paid = true` — EXTRA (WWR analog) |
| Invoice dedup guard | — (none) | `return if existing.stripe_invoice_id == invoice.id` — EXTRA |
| Check result | N/A | Interactor result NOT checked — GAP |

### customer.subscription.deleted

| Step | Main subscription (org) | AI credit subscription (purchase) |
|---|---|---|
| Full handler | Exists: sync + canceled_at + notification + engagement report | **MISSING entirely** — no credit-pack branch |

---

## D. Missing reconciliation method

`Organization#sync_with_stripe` is a bulk reconciliation that explicitly REJECTS credit subscriptions (filters out lookup keys containing 'credit' or 'plato'). So `sync_with_stripe` cannot be reused for AI credit subscriptions. But no equivalent `sync_purchase_with_stripe` exists — all purchase state updates are inline in webhook handlers.
