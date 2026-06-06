# Angle 1: Stripe Webhook and Checkout Hardening -- Round 2

## Scope

Round 1 H1 (invoice.paid top-up handler passing invoice as session) has been fixed with the new `apply_one_off_from_invoice` method. Reviewing the fix and surrounding Stripe flows.

## Findings

### F1 (CLEAR) -- `apply_one_off_from_invoice` correctly extracts from invoice metadata

The new method at `app/interactors/apply_ai_credit_purchase.rb:84-130` extracts `organization_id` and `stripe_price_lookup_key` from `invoice.metadata` instead of calling `Stripe::Checkout::Session.list_line_items`. The idempotency guard uses `stripe_invoice_id` + `kind: :one_off`. This is correct and resolves H1.

### F2 (CLEAR) -- `invoice.paid` handler correctly passes `invoice:` context

`stripe_webhook_handler_job.rb:215`: `ApplyAiCreditPurchase.call(invoice: object, kind: :one_off)` -- the interactor now branches on `context.invoice` presence (line 18) and routes to `apply_one_off_from_invoice`. No more type mismatch.

### F3 (CLEAR) -- `checkout.session.completed` subscription linking uses `update_columns` with explanatory comment

Lines 58-68: correctly finds purchase by `stripe_checkout_session_id`, sets `stripe_subscription_id` via `update_columns`. Comment explains why validations are skipped. `return` prevents base-plan handling.

### F4 (CLEAR) -- `handle_credit_pack_invoice_paid` now sets `amount_cents_paid` and `currency`

Lines 474-475: `amount_cents_paid: invoice.amount_paid, currency: invoice.currency` added to the `existing.update(...)` call. Subscription purchases created at checkout with `amount_cents_paid: 0` will be populated on first `invoice.paid`.

### F5 (CLEAR) -- `else` branch removed from `handle_credit_pack_invoice_paid`

The branch that called `ApplyAiCreditPurchase.call(invoice: ..., kind: :subscription)` is removed. If no existing purchase is found, the method silently returns (no error log). This matches the spec's intent that purchases must exist from checkout. However, the silence is a MED concern -- see operational-concerns.

### F6 (CLEAR) -- `invoice.paid` branch ordering

Top-up metadata check (line 211) is BEFORE `raise CustomStripeSubscriptionMissingError` (line 253). WWR and WhatJobs listing branches (lines 222, 235) are also BEFORE the guard, each with `return` statements. This prevents orgs without base plans from hitting the subscription-missing guard on non-subscription invoices.

### F7 (CLEAR) -- Webhook spec updated to test invoice-based top-up

The spec at `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` now tests `invoice.paid` with `ai_credit_pack_top_up` metadata (not `checkout.session.completed` with `mode: 'payment'`). The spec no longer stubs `Stripe::Checkout::Session.list_line_items` with an invoice ID, which was the Round 1 masking issue.

## Verdict: 0 findings. PASS for this angle.
