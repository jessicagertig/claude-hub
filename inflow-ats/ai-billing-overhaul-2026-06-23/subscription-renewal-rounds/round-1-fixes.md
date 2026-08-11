# Subscription Renewal — Round 1 Fixes

Audit reported 4 deviations. All 4 judged FIXABLE (genuine structural gaps, NOT product-forced). All fixed to match the analog. Nothing whitelisted.

---

## Deviation 1 — Update return value not captured/checked on the payment-info update — FIXED

- **File:** `app/jobs/stripe_webhook_handler_job.rb` (`handle_subscription_credit_pack_invoice_paid`, ~:455-465)
- **Analog:** `stripe_webhook_handler_job.rb:265-269` captures `updated = organization.update(...)` and on failure logs `Rails.logger.error "...could not persist..."` + `ap organization.errors`.
- **Before:** `existing.update(stripe_amount:, currency:, stripe_invoice_item_id:)` discarded the return value; a validation failure was silently swallowed.
- **After:** captures `updated = organization_ai_credit_purchase.update(...)`; on `unless updated` logs `Rails.logger.error "Stripe invoice.paid: could not persist payment info on organization_ai_credit_purchase #{id}: #{errors...}"` + `ap organization_ai_credit_purchase.errors`. Structurally identical to the analog (capture → unless → error log → ap errors). Does not raise or return early, matching the analog which also continues after logging.

## Deviation 2 — Redundant re-lookup of the same purchase record — FIXED

- **Files:** `app/jobs/stripe_webhook_handler_job.rb:466` (call site) + `app/interactors/apply_ai_credit_purchase.rb` (`apply_subscription`, ~:29).
- **Analog:** the else branch looks up `organization` once and passes objects forward; the downstream method (`stripe_update_default_payment_method`, `reset_ai_credits`) does not re-run the same lookup.
- **Before:** the handler found the purchase at :450-453, then `apply_subscription` re-ran the identical `OrganizationAiCreditPurchase.find_by(stripe_subscription_id:, kind: :subscription)` query for the same record (`apply_ai_credit_purchase.rb:29`).
- **After:** the handler passes the already-found record forward via `ApplyAiCreditPurchase.call(..., purchase: organization_ai_credit_purchase)`. `apply_subscription` now uses `context.purchase || OrganizationAiCreditPurchase.find_by(...)` — it consumes the forwarded record and only falls back to its own lookup when none was passed. This eliminates the duplicate query on the webhook path (matching the analog's "look up once, pass forward") while keeping the interactor self-sufficient when called without `purchase:`. (The interactor spec calls `.call(invoice:, price:, kind:)` without `purchase:`, so the fallback lookup preserves that path — no spec touched.)

## Deviation 3 — Misleading hardcoded ledger description string — FIXED

- **File:** `app/interactors/apply_ai_credit_purchase.rb` (`apply_subscription`, grant ledger row, ~:60).
- **Analog:** `reset_ai_credits.rb:45` / `:58` use descriptions accurate to the event with a dynamic identifier (`'Anniversary reset — clear previous monthly bucket'`, `"Monthly credit grant for #{organization.plan}"`).
- **Before:** `description: 'Credit pack subscription first invoice'` — fires on EVERY recurring renewal, so the "first invoice" label mislabels every renewal grant.
- **After:** `description: "Credit pack subscription grant for #{organization_ai_credit_purchase.stripe_price_lookup_key}"` — accurate for every renewal and structurally parallel to the analog (descriptive prefix + dynamic identifier).

## Deviation 4 — Multi-write set not wrapped in a DB transaction — FIXED

- **File:** `app/interactors/apply_ai_credit_purchase.rb` (`apply_subscription`, ~:37-65).
- **Analog:** `reset_ai_credits.rb:34` wraps all ledger inserts + the balance metadata update in `ApplicationRecord.transaction do ... end`, so a mid-sequence failure rolls back the whole grant.
- **Before:** `existing.update` (status/period), `existing.finalize_stripe_payment`, the `AiCreditBalanceTransaction.save` grant, and `balance.update_columns` ran with no transaction wrapper; a failure partway through left partial writes committed.
- **After:** all four writes wrapped in `ApplicationRecord.transaction do ... end`, matching the analog. The `period` resolution and the early guards (`return if ... == invoice.id`, `missing_balance`) remain outside the transaction, exactly as the analog keeps its `resolve_allocation`/guards outside (analog's `now`/`new_allocation` are inside, but those are pure computation; the structural match is "all writes inside one transaction"). `fail_with_record_invalid` raising `Interactor::Failure` inside the block rolls the transaction back — identical to the analog, which also calls `fail_with_record_invalid` inside its transaction.

---

## Variable rename (incidental, part of the above edits)

Renamed the `existing` local to `organization_ai_credit_purchase` in both the handler and the interactor, and the `ledger` local to `ai_credit_balance_transaction`, per the record-naming rule (no `existing`/`ledger` standalone names for DB-backed records).

## Note on pre-existing test state (NOT introduced by these fixes, NOT in scope)

The subscription specs (`spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`, `spec/interactors/apply_ai_credit_purchase_spec.rb`) were already failing on the branch BEFORE these edits: they create `OrganizationAiCreditPurchase` with `amount_cents_paid:`, but migration `20260611120002` renamed that column to `stripe_amount`, so `ActiveModel::UnknownAttributeError: unknown attribute 'amount_cents_paid'` fires at factory time. Also the interactor's `call` dispatch no longer handles `:one_off` (only `:subscription`), so the one_off spec group fails at `:invalid_kind`. Both are pre-existing branch state outside this audit's subscription-renewal scope; specs are off-limits per the fix rules, so they were not touched. The production fixes above are validated against the analog + trace, and both modified files pass `ruby -c`.
