# Angle 1: Stripe Webhook and Checkout Hardening — Round 6

## Round 5 HIGH Findings — Verification

All 9 HIGH findings from Round 5 are FIXED:

1. `apply_one_off_from_invoice` (46 lines) -- REMOVED. Top-up `invoice.paid` now processes inline: looks up checkout session from `payment_intent`, calls existing `apply_one_off`.
2. `stripe_checkout_session_id` validation -- REVERTED to `presence: true, if: :one_off?` (line 53 of model).
3. `charge.refunded` handler -- REMOVED.
4. `customer.subscription.updated` AI branch -- REMOVED.
5. `customer.subscription.deleted` AI branch -- REMOVED.
6. `handle_credit_pack_invoice_paid` -- RESTORED to spec version (13 lines, lines 389-403 of webhook handler).
7. `subscription_status_for_stripe` -- REMOVED.
8-9. Code duplication across interactor/webhook -- RESOLVED by removal of `apply_one_off_from_invoice` and restoration of `handle_credit_pack_invoice_paid`.

## Current State Review

### `checkout.session.completed` AI subscription branch (lines 58-69)

Spec-compliant. Finds purchase by `stripe_checkout_session_id`, sets `stripe_subscription_id` via `update_columns`, returns. Uses `update_columns` to skip validations intentionally (comment explains why). Logs error if purchase not found.

### `invoice.paid` top-up branch (lines 182-191)

Spec-compliant per Note #4. The branch checks `ai_credit_pack_top_up` metadata, looks up the checkout session from `payment_intent` via `Stripe::Checkout::Session.list`, then delegates to `ApplyAiCreditPurchase.call(session: checkout_session, kind: :one_off)`. This reuses the existing `apply_one_off` method.

### `invoice.paid` listing branches above guard (lines 193-223)

Spec-compliant per Note #4 / Phase E.2.2. Both `board_wwr_listing_id` and `board_what_jobs_listing_id` branches are now above the `CustomStripeSubscriptionMissingError` guard with explicit `return` statements.

### `invoice.paid` subscription credit pack branch (lines 226-240)

Spec-compliant. After the guard, retrieves subscription, checks if it's a credit pack subscription via `OrganizationAiCreditPurchase.subscription_key?`, delegates to `handle_credit_pack_invoice_paid`. The else branch handles base plan invoices with period update and credit reset.

### `handle_credit_pack_invoice_paid` (lines 389-403)

Spec-compliant per Note #9B-5. Finds existing purchase by `stripe_subscription_id`, updates `amount_cents_paid` and `currency` from invoice, then calls `ApplyAiCreditPurchase.call(invoice: invoice, price: price, kind: :subscription)`. Simple, correct, no duplication.

### Controller `purchase_top_up` invoice_creation (lines 84-105)

Spec-compliant per Note #4. `invoice_creation: { enabled: true, invoice_data: { metadata: { organization_id, stripe_price_lookup_key, ai_credit_pack_top_up: 'true' } } }`.

### Controller `checkout` creates purchase record (lines 46-58)

Spec-compliant per Note #9B-5. Creates `OrganizationAiCreditPurchase` with `kind: :subscription`, `stripe_checkout_session_id`, `stripe_price_lookup_key`, `subscription_credits_per_period`.

## Findings

### MED F1 — `amount_cents_paid: 0` hardcoded at checkout

**File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:52`

Purchase record created at checkout sets `amount_cents_paid: 0`. At this point no payment has been collected. The validation allows nil (`unless: -> { subscription? && stripe_subscription_id.blank? }`), so nil would be more semantically correct. However, 0 passes validation and gets overwritten by `handle_credit_pack_invoice_paid` on first `invoice.paid`. Functionally harmless.

### MED F2 — Interactor docstring describes wrong caller

**File:** `app/interactors/apply_ai_credit_purchase.rb:4`

Docstring says `checkout.session.completed -> call(session: session, kind: :one_off)`. This was accurate before the refactor but is now misleading. One-off top-ups are now called from the `invoice.paid` handler (which looks up the checkout session internally). The interactor interface (`session`, `:one_off`) is correct -- only the comment about which webhook event triggers it is wrong.

### MED F3 — Rescue block restructuring beyond spec

**File:** `app/jobs/stripe_webhook_handler_job.rb:241-255`

The original `invoice.paid` handler had a single `rescue StandardError => e` that silently swallowed all errors. The new code splits this into three tiers: `Stripe::StripeError` (swallowed with logging), `ActiveRecord::RecordInvalid/RecordNotFound` (swallowed with logging), and `StandardError` (logged and re-raised). The re-raise on unexpected errors changes retry behavior -- Sidekiq will retry the webhook delivery. While arguably better behavior, this is a change beyond what the spec explicitly requested. The spec only addresses the `invoice.paid` branching structure, not the error handling strategy.

## Verdict: PASS (0 HIGH, 3 MED)
