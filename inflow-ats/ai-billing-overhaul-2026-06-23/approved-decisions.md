# Approved Decisions — AI Billing Overhaul

## 1. Subscription plan changes use Stripe API, not customer portal

Subscription checkout for new subscribers continues through Stripe Checkout. When an existing subscriber upgrades or downgrades their plan, the app calls the Stripe API directly (`Stripe::Subscription.update` and `Stripe::Invoice.create_preview`) and presents a custom confirmation modal — the Stripe customer portal is not opened for plan changes.

The subscription ID remains the same through upgrade/downgrade — only the subscription item's price changes.

## 2. `Invoice.create_preview` is the source of truth for the confirmation modal

The preview call returns the actual amounts Stripe will charge. The confirmation modal displays exactly what the preview returns — no manual math, no ignoring fields. The commit call (`Subscription.update`) uses identical params to the preview call, guaranteeing what was shown matches what Stripe charges.

The preview is not just helpful metadata — it's the authoritative source for every dollar amount in the modal.

## 3. Upgrades charge full monthly price difference, not time-prorated fractions

On upgrade, the customer pays the full difference between the new plan's monthly price and the current plan's monthly price. No time-based proration.

Example: Lite ($39/mo) → Plus ($129/mo) = $90 due today, regardless of where they are in the billing cycle.

The confirmation modal shows:
- New plan line at full monthly price ($129.00)
- Credit for current plan at full monthly price (-$39.00)
- Amount due today = the difference ($90.00)

The charge happens immediately (`proration_behavior: 'always_invoice'`). The exact API params to achieve full-price math (e.g., `proration_date: current_period_start`) may need adjustment based on Stripe API behavior — the goal is what matters, not the specific param trick.

## 4. Downgrades are deferred to end of billing period via Stripe API

On downgrade, the app sends a mutation to Stripe to schedule the plan change at the end of the current billing period. The subscription stays on the current plan until then — no immediate price change, no charge today.

The exact Stripe mechanism (e.g., `SubscriptionSchedule` with phases, or `Subscription.update` with a deferral param) is TBD based on what the API supports cleanly. The goal: Stripe knows about the pending downgrade and executes it at period end automatically.

The downgrade confirmation modal shows:
- New plan name + credits/month
- Effective date (current billing period end)
- New monthly price starting that date
- Payment method on file (card brand + last 4)

No details/breakdown section — just the informational message and new price.

## 5. On upgrade, grant the difference in credits

On upgrade, the subscriber has already received their current plan's credits for this period. They are granted additional credits equal to the difference between the new plan's monthly allotment and the current plan's monthly allotment.

Example: Lite (200 credits/mo) → Plus (750 credits/mo) = 550 additional credits granted immediately.

The math parallels the charge:
- Charge: $129 - $39 = $90
- Credits: 750 - 200 = 550

Backend implementation for credit granting is a separate concern from the Stripe subscription change and modal UI, but is in scope for the current feature work.

## 6. Upgrade credits granted on `invoice.paid`, not `customer.subscription.updated`

Credits are irreversible product, not permissions. They must only be granted after payment is confirmed. `customer.subscription.updated` fires before payment clears — granting there risks delivering product that was never paid for.

Credit granting happens in the `invoice.paid` handler, using the invoice's `billing_reason` field (read-only, set by Stripe automatically) to distinguish invoice types:

- `billing_reason: 'subscription_update'` → upgrade proration invoice. The invoice line items carry both the old plan (credit line, negative amount) and the new plan (charge line, positive amount), each with `price.lookup_key`. Extract both lookup keys, compute the credit difference via `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY`, and grant the difference.
- `billing_reason: 'subscription_cycle'` → renewal. Grant full `subscription_credits_per_period`.
- `billing_reason: 'subscription_create'` → first invoice. Existing behavior.

No new columns needed (`previous_stripe_price_lookup_key`, `pending_upgrade_credit_amount`, etc.). The invoice itself carries the old and new plan lookup keys in its line items. One event, all data, correct sequencing.
