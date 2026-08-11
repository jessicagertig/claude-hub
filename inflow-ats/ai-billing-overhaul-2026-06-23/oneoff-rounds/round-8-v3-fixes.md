# One-Off Purchase — Round 8 Fixes (v3)

Everything is confirmed. Both deviations are fixed and structurally match the analog:

**DEVIATION 1 (logging):** `charge_for_purchase` now has all four analog log points at the structurally-equivalent positions:
- `Rails.logger.info 'Attempt to charge for AI Credit Top-Up'` (↔ analog line 114 `'Attempt to charge for WWR Listing'`)
- `ap 'Already charged for this AI Credit Top-Up'` inside the double-charge guard (↔ analog line 116 `ap 'Hmm...'`)
- `Rails.logger.info 'Charging...'` before `Stripe::InvoiceItem.create` (↔ analog line 128 `'Charging...'`)
- `Rails.logger.info 'Invoice Has Been Finalized'` + `Rails.logger.info [invoice_item, paid_invoice]` after `update_columns` (↔ analog lines 160-161)

**DEVIATION 2 (amount/currency plumbing):** The webhook one-off branch now calls `ApplyAiCreditPurchase.call(kind: :one_off, purchase: purchase)` with no invoice amount (↔ analog `listing.create_on_wwr` with no args), and the `apply_one_off` backfill block is removed (↔ analog `create_on_wwr` never writes `stripe_amount`/`currency`). `stripe_amount` is stamped only at charge time by `charge_for_purchase` (↔ analog `charge_for_listing`).

---

## Summary of changes

Both genuine deviations from the findings were FIXED to match the WWR/WhatJobs analog. Nothing was whitelisted. The current working-tree code already matched the analog on every other point the findings enumerated (two-action split, `authorize`, `amount:` InvoiceItem, metadata keys, rescue shapes, frontend onSuccess handlers, etc.), so no changes were needed there.

### DEVIATION 1 — Logging absent from the direct-charge model method (FIXED)
File: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/models/organization_ai_credit_purchase.rb`
Added the four analog log points to `charge_for_purchase`, matching `BoardWwrListing#charge_for_listing`:
- `Rails.logger.info 'Attempt to charge for AI Credit Top-Up'` after method entry
- converted the bare double-charge `return` into an `if` block with `ap 'Already charged for this AI Credit Top-Up'` (mirroring analog's `ap` inside the guard)
- `Rails.logger.info 'Charging...'` immediately before `Stripe::InvoiceItem.create`
- `Rails.logger.info 'Invoice Has Been Finalized'` + `Rails.logger.info [invoice_item, paid_invoice]` immediately after `update_columns`

### DEVIATION 2 — Webhook threaded invoice amount/currency into the grant unit, which backfilled (FIXED)
The analog passes no amount to the grant unit (`listing.create_on_wwr`) and never backfills `stripe_amount`/`currency`; the amount is stamped only at charge time by `charge_for_listing#update_columns`. Our `charge_for_purchase` already stamps `stripe_amount` the same way, so the webhook→interactor backfill was extra plumbing with no analog counterpart. Removed it:
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/jobs/stripe_webhook_handler_job.rb` — the one-off branch now calls `ApplyAiCreditPurchase.call(kind: :one_off, purchase: purchase)` (dropped `amount_cents: object.amount_paid, currency: object.currency`).
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/interactors/apply_ai_credit_purchase.rb` — removed the `if existing.stripe_amount.to_i.zero? && context.amount_cents.present? ... existing.update(stripe_amount:, currency:)` block from `apply_one_off`, and removed the now-obsolete `amount_cents`/`currency` lines from the method's accepted-context doc comment. (Checkout-path purchases keep `stripe_amount: 0`, which is valid against the model's `presence + >= 0` validation and is the structural equivalent of the analog's checkout path leaving `stripe_amount` unstamped.)

### Spec updates (required by the production change; failure patterns #6, ghost-tests)
File: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/spec/interactors/apply_ai_credit_purchase_spec.rb`
- Removed the ghost test `'persists stripe_amount from the invoice onto the given record'` — it asserted the backfill that no longer exists (and would now fail).
- Removed the obsolete `amount_cents:`/`currency:` keys from `one_off_params`, `direct_charge_params`, the `:missing_purchase` call, and the `:missing_balance` call, so the spec's call signature matches production (`kind: :one_off, purchase: ...`).

No frontend change was required: neither fix altered a controller response key (both fixes are server-internal — model logging and webhook/interactor argument plumbing). The `charge_top_up` response is still `render_one(... Serializer)` and `create_top_up_checkout_session` still returns `{ url, sessionId }`, both already matching the analog.

### Verification
- In-scope specs fully green: `apply_ai_credit_purchase_spec.rb` + `organization_ai_credit_purchase_charge_spec.rb` = 23 examples, 0 failures; one-off webhook examples in `stripe_webhook_handler_ai_credits_spec.rb` = all green (13 one-off-scoped examples, 0 failures).
- 6 failures in `stripe_webhook_handler_ai_credits_spec.rb` are PRE-EXISTING and OUT OF SCOPE (subscription `invoice.paid` renewal + `customer.subscription.updated` upgrade paths). Proven pre-existing: they fail at `stripe_webhook_handler_job.rb:139` (`Time.at(object.current_period_start)`) on subscription test doubles missing the `current_period_start` stub — a code path my diff never touches. I confirmed they fail identically with DEVIATION 2 temporarily reverted, then restored my fix.

WHITELIST: none.
