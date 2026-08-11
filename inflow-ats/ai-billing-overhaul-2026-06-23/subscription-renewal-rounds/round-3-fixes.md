# Round 3 — Fixes (AI-credit subscription renewal analog audit)

Audit reported 3 deviations. Result: 2 FIXED, 1 WHITELISTED.

---

## DEVIATION 1 — Missing-record guard logs nothing (analog raises + logs) — FIXED

**Analog:** `stripe_webhook_handler_job.rb:263` `raise CustomStripeSubscriptionMissingError if organization.stripe_subscription_id.nil?` — on the anomalous "expected subscription record absent" state the analog RAISES, which falls through to `rescue StandardError => e` (now at `:279`) and logs the UNEXPECTED error.

**OURS (before):** `handle_subscription_credit_pack_invoice_paid` at `stripe_webhook_handler_job.rb:454` had `return unless organization_ai_credit_purchase` — silent return, no log, on the analog's exact anomalous state (we only routed here because the lookup_key matched an AI credit subscription, so a missing `OrganizationAiCreditPurchase` is the anomaly).

**Fix:** `app/jobs/stripe_webhook_handler_job.rb:454` — replaced the silent `return unless organization_ai_credit_purchase` with `raise CustomStripeSubscriptionMissingError if organization_ai_credit_purchase.nil?`. The handler is called at `:261` inside the shared `begin` block (`:211`) guarded by the rescues at `:273`–`:283`; the raise is caught by `rescue StandardError => e` at `:279` and logged exactly as the analog's raise is, restoring error-logging parity. Reused the existing `CustomStripeSubscriptionMissingError` class the analog raises.

---

## DEVIATION 2 — Dead `price` parameter threaded through the interactor — FIXED

**Analog:** `ResetAiCredits#call` (`reset_ai_credits.rb`) takes only the organization (via the balance); no Stripe Price is passed. The allocation is resolved internally.

**OURS (before):** a Stripe Price object was threaded from `stripe_webhook_handler_job` (`subscription_price`) → `handle_subscription_credit_pack_invoice_paid(invoice, price)` → `ApplyAiCreditPurchase.call(..., price: price, ...)` → `apply_subscription(invoice, price)`, but `price` was never referenced in any method body. The granted amount comes from `organization_ai_credit_purchase.subscription_credits_per_period`, not the Price.

**Fix:** removed the dead parameter end-to-end:
- `app/jobs/stripe_webhook_handler_job.rb:258` — removed the now-unused `subscription_price = stripe_subscription.items.data.first&.price` local (it had no remaining reader).
- `app/jobs/stripe_webhook_handler_job.rb:260` (call site) — `handle_subscription_credit_pack_invoice_paid(object)` (was `(object, subscription_price)`).
- `app/jobs/stripe_webhook_handler_job.rb:449` — `def handle_subscription_credit_pack_invoice_paid(invoice)` (was `(invoice, price)`).
- `app/jobs/stripe_webhook_handler_job.rb:466` — `ApplyAiCreditPurchase.call(invoice: invoice, kind: :subscription, purchase: organization_ai_credit_purchase)` (dropped `price: price`).
- `app/interactors/apply_ai_credit_purchase.rb:16` — `apply_subscription(context.invoice)` (was `apply_subscription(context.invoice, context.price)`).
- `app/interactors/apply_ai_credit_purchase.rb:24` — `def apply_subscription(invoice)` (was `(invoice, price)`).

Intent: match the analog's interface — the per-renewal grant takes only what it needs (the invoice / persisted purchase record) and resolves the credit amount internally, with no dead Stripe Price object threaded through. Specs pass `price:` into the interactor context (Interactor gem accepts arbitrary context keys); the subscription specs assert on credit-balance effects, not on `price:` being passed, so the removal does not break them. Both files pass `ruby -c`.

---

## DEVIATION 3 — Extra idempotency/grant-once guard absent in the analog — WHITELISTED

**Analog:** `ResetAiCredits#call` (`reset_ai_credits.rb`) has NO idempotency guard — it runs unconditionally every renewal.

**OURS:** `apply_ai_credit_purchase.rb` `apply_subscription` has `return if organization_ai_credit_purchase.stripe_invoice_id == invoice.id`.

**Why FORCED (not fixable):** the analog grants by ZERO-THEN-RESET of the `:monthly` bucket — it debits `monthly_credits_remaining` to 0, then credits `new_allocation` — so a duplicate renewal is self-correcting and idempotent by construction; no guard is needed. OURS grants ADDITIVELY: a single `:subscription_credit_pack_purchase_credit` credit of `subscription_credits_per_period` into the `:addon_subscription` bucket with no preceding zero-out. A duplicate `invoice.paid` delivery (Stripe redelivers webhooks) would DOUBLE-GRANT credits without the guard. The grant-once guard is required for correctness and exists only because the credit-pack subscription's additive `addon_subscription` bucket is a different product from the main plan's reset-style `:monthly` allocation. Forced by the data-model/product difference.

**Action:** appended as entry #1 to `AGENT-WHITELIST-subscription-renewal.md`. No code change.
