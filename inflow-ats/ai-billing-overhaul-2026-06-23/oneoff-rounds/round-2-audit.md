# One-Off Purchase — Round 2 Audit

Now I have all the data I need. Let me compile the full audit. Here is my systematic row-by-row comparison of every trace claim against the actual code:

---

**TRACE vs ACTUAL CODE -- Row-by-row audit of the one-off purchase flow**

I verified every row in the structural trace at `/Users/jessica/claude-hub/inflow-ats/ai-billing-overhaul-2026-06-23/traces/oneoff-purchase-trace.md` against the actual code in `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/`. Below are all unsanctioned deviations found (non-whitelisted, non-sanctioned).

---

## DEVIATION: charge_default_payment_method signature

| Aspect | Claim | Actual |
|---|---|---|
| Analog | `board_wwr_listing.rb:112` -- `charge_for_listing` takes zero arguments; calculates `amount` internally via `calculate_charge_amount` | |
| Ours | `organization_ai_credit_purchase.rb:123` -- `charge_default_payment_method(price)` takes a `price` argument; controller resolves the Stripe Price and passes it in | |
| Trace says | Model has its own `Stripe::Price.list` call (row 34, a SECOND call) | |
| Actual | Controller's `Stripe::Price.list` result is passed as `price` to the model method | |
| Status | TRACE WRONG -- double Stripe API call inside model does not exist in current code |

## DEVIATION: direct-charge controller response

| Aspect | Claim | Actual |
|---|---|---|
| Analog | `board_wwr_listings_controller.rb:23` -- `render_one(@listing, Api::V1::BoardWwrListingSerializer)` (serialized listing) | |
| Ours | `organization_ai_credit_purchases_controller.rb:108` -- `render_one(purchase, Api::V1::OrganizationAiCreditPurchaseSerializer)` | |
| Trace says | `render json: { charged: true }` (row 42) | |
| Actual | Full serialized purchase record via `render_one` | |
| Status | TRACE WRONG -- actual code now matches analog pattern |

## DEVIATION: checkout response -- sessionId and status present

| Aspect | Claim | Actual |
|---|---|---|
| Analog | `board_wwr_listings_controller.rb:120` -- `render json: { url: session.url, sessionId: session.id }, status: :created` | |
| Ours | `organization_ai_credit_purchases_controller.rb:150` -- `render json: { redirectUrl: session.url, sessionId: session.id }, status: :created` | |
| Trace says | `render json: { redirectUrl: session.url }` with no `sessionId`, no `status: :created` (row 46) | |
| Actual | HAS both `sessionId: session.id` and `status: :created` | |
| Status | TRACE WRONG -- `sessionId` and `status: :created` were added after trace written. Code now closer to analog. Only remaining difference is key name `redirectUrl` vs `url` (whitelisted). |

## DEVIATION: InvoiceItem description field

| Aspect | Claim | Actual |
|---|---|---|
| Analog | `board_wwr_listing.rb:130-138` -- `Stripe::InvoiceItem.create` includes `description: @final_description` | |
| Ours | `organization_ai_credit_purchase.rb:131-141` -- `Stripe::InvoiceItem.create` includes `description:` | |
| Trace structural table | `description:` is "MISSING in ours" | |
| Actual | `"AI Credit Top-Up -- #{name_from_lookup_key}"` at line 134 | |
| Status | TRACE WRONG -- field exists in current code |

## DEVIATION: Invoice description field

| Aspect | Claim | Actual |
|---|---|---|
| Analog | `board_wwr_listing.rb:143-151` -- `Stripe::Invoice.create` includes `description: 'We Work Remotely Listing'` | |
| Ours | `organization_ai_credit_purchase.rb:143-153` -- `Stripe::Invoice.create` includes `description:` | |
| Trace structural table | `description:` is "MISSING in ours" | |
| Actual | `'AI Credit Top-Up'` at line 146 | |
| Status | TRACE WRONG -- field exists in current code |

## DEVIATION: Invoice auto_advance field

| Aspect | Claim | Actual |
|---|---|---|
| Analog | `board_wwr_listing.rb:143-151` -- does NOT include `auto_advance` | |
| Ours | `organization_ai_credit_purchase.rb:143-153` -- actual code does NOT include `auto_advance: true` | |
| Trace structural table | `auto_advance: true` is "EXTRA in ours" | |
| Actual | No `auto_advance` field present | |
| Status | TRACE WRONG -- actual code does not have it |

## DEVIATION: update_columns stripe_amount source

| Aspect | Claim | Actual |
|---|---|---|
| Analog | `board_wwr_listing.rb:158` -- `update_columns(stripe_amount: amount)` where `amount` = locally computed `calculate_charge_amount` result | |
| Ours (trace) | `stripe_amount: paid_invoice.amount_paid` (Stripe-reported amount from pay response) | |
| Ours (actual) | `organization_ai_credit_purchase.rb:157` -- `update_columns(stripe_amount: amount)` where `amount = price.unit_amount` (line 124) | |
| Status | TRACE WRONG -- actual uses pre-charge price amount, not post-charge paid amount. Conceptually closer to analog (both determined before charge) |

## DEVIATION: update_columns currency field

| Aspect | Claim | Actual |
|---|---|---|
| Analog | does NOT write `currency` | |
| Ours (trace) | `currency: paid_invoice.currency` | |
| Ours (actual) | `update_columns(stripe_invoice_id: invoice.id, stripe_invoice_item_id: invoice_item.id, stripe_amount: amount)` | |
| Trace structural table | `currency:` is "EXTRA in ours" | |
| Status | TRACE WRONG -- no currency field written |

## DEVIATION: Checkout Session payment_method_types

| Aspect | Claim | Actual |
|---|---|---|
| Analog | does NOT include `payment_method_types` | |
| Ours (trace) | `payment_method_types: ['card']` is "EXTRA in ours" | |
| Ours (actual) | `organization_ai_credit_purchases_controller.rb:112-142` -- `purchase_top_up` checkout session does NOT include `payment_method_types: ['card']` | |
| Note | (Present in separate `checkout` action for subscriptions at line 36, but NOT in one-off path) | |
| Status | TRACE WRONG -- actual code does not have it in purchase_top_up |

## DEVIATION: Checkout Session payment_intent_data

| Aspect | Claim | Actual |
|---|---|---|
| Analog | `board_wwr_listings_controller.rb:95-101` -- includes `payment_intent_data: { metadata: { board_wwr_listing_id:, organization_id:, job_id: } }` | |
| Ours (trace) | "MISSING in ours" | |
| Ours (actual) | `organization_ai_credit_purchases_controller.rb:116-122` -- INCLUDES `payment_intent_data: { metadata: { organization_ai_credit_purchase_id:, organization_id:, stripe_price_lookup_key: } }` | |
| Status | TRACE WRONG -- field exists in current code |

## DEVIATION: Checkout Session invoice_data description

| Aspect | Claim | Actual |
|---|---|---|
| Analog | `board_wwr_listings_controller.rb:103-109` -- `invoice_data` includes `description: @final_invoice_description` | |
| Ours (trace) | "omitted" | |
| Ours (actual) | `organization_ai_credit_purchases_controller.rb:126` -- `invoice_data` includes `description: 'AI Credit Top-Up'` | |
| Status | TRACE WRONG -- field exists in current code |

## DEVIATION: Checkout Session stripe_price_lookup_key in metadata

| Aspect | Claim | Actual |
|---|---|---|
| Analog | N/A (no lookup keys) | |
| Ours (trace) | `stripe_price_lookup_key` in top-level `metadata:` block (row 43) | |
| Ours (actual) | `stripe_price_lookup_key` IS in `payment_intent_data.metadata` (line 120) and `invoice_creation.invoice_data.metadata` (line 130), but NOT in top-level `metadata` (which has `{ organization_id:, organization_ai_credit_purchase_id:, ai_credit_pack_top_up: 'true' }`) | |
| Status | TRACE PARTIALLY WRONG -- does not distinguish which metadata block contains which keys |

## DEVIATION: Webhook checkout_session_id lookup

| Aspect | Claim | Actual |
|---|---|---|
| Analog | WWR webhook does NOT look up checkout sessions | |
| Ours (trace) | `Stripe::Checkout::Session.list(payment_intent: object.payment_intent, limit: 1)` at lines 216-218 (rows 4-5); `checkout_session_id` passed to `ApplyAiCreditPurchase` | |
| Ours (actual) | `stripe_webhook_handler_job.rb:212-221` -- does NOT perform `Stripe::Checkout::Session.list` call. Passes `invoice_id: object.id` but NOT `checkout_session_id` | |
| Status | TRACE WRONG -- checkout session lookup does not exist in current code |

## DEVIATION: Webhook ApplyAiCreditPurchase call shape

| Aspect | Claim | Actual |
|---|---|---|
| Ours (trace) | `checkout_session_id: checkout_session_id` passed (row 5) | |
| Ours (actual) | `stripe_webhook_handler_job.rb:213-220` -- `ApplyAiCreditPurchase.call` passes `{ kind: :one_off, organization_id:, amount_cents:, currency:, purchase_id:, invoice_id: }` | |
| Note | `apply_one_off` in interactor still has fallback logic for `checkout_session_id` (line 47-48), but webhook caller never provides it for this flow | |
| Status | TRACE WRONG -- actual does not pass `checkout_session_id` |

## BUG: Notification job exception capture

| File | `notification/paid_ai_credit_pack_purchased_job.rb:12-14` |
|---|---|
| Issue | `rescue ActiveRecord::RecordNotFound` does NOT capture exception into variable `e`, but line 14 references `ap e` |
| Result | Raises `NameError: undefined local variable or method 'e'` at runtime, masking original error |
| Fix | Change to `rescue ActiveRecord::RecordNotFound => e` |
| Status | ACTUAL BUG (not a trace discrepancy) |

## DEVIATION: Notifications -- broadcast + job

| Aspect | Claim | Actual |
|---|---|---|
| Analog | `board_wwr_listing.rb:173+` -- `broadcast_event`, `broadcast_show_growl`, `Notification::PaidWwrListingCreatedJob.perform_later` | |
| Ours (trace) | Both "WebSocket broadcast" and "Internal notification job" are "MISSING in ours" | |
| Ours (actual) | `apply_ai_credit_purchase.rb:94-101` -- HAS BOTH: `GlobalChannel.broadcast_to` (growl) + `Notification::PaidAiCreditPackPurchasedJob.perform_later` | |
| Status | TRACE WRONG -- both were added after trace written |

## DEVIATION: Double-charge guard shape

| Aspect | Claim | Actual |
|---|---|---|
| Analog | `board_wwr_listing.rb:115` -- `return if stripe_invoice_id.present? && is_active?` | |
| Ours (trace) | Checks "only `stripe_invoice_id` presence" | |
| Ours (actual) | `organization_ai_credit_purchase.rb:126` -- `return if stripe_invoice_id.present? && stripe_invoice_paid?` (both conditions) | |
| Status | TRACE WRONG about single-condition guard. Actual is structurally closer to analog (two conditions), though second condition differs: analog checks `is_active?` (domain status), ours checks `stripe_invoice_paid?` (Stripe flag). |

---

## Summary of Findings

The trace document is significantly stale relative to the current code. Many items the trace marks as MISSING or EXTRA have been fixed in the actual code since the trace was written.

### Genuine code-vs-analog deviations (not already sanctioned/whitelisted)

**NONE.** The actual code has been brought into closer alignment with the analog than the trace documents. The sanctioned deviations (confirmation modal, record source, naming) are the only structural differences remaining.

### Trace-vs-code mismatches (14 items where trace is wrong about what code does)

1. **Row 34 (Stripe::Price.list)** — Trace claims model has its own call; actual code accepts `price` as argument from controller
2. **Row 42 (direct-charge response)** — Trace claims `{ charged: true }`; actual is `render_one(purchase, Serializer)`
3. **Row 46 (checkout response)** — Trace claims no `sessionId` or `status: :created`; actual has both
4. **Structural table: InvoiceItem description** — Trace claims MISSING; actual has `description:`
5. **Structural table: Invoice description** — Trace claims MISSING; actual has `description:`
6. **Structural table: Invoice auto_advance** — Trace claims EXTRA `auto_advance: true`; actual does not have it
7. **Row 40 / Structural table: update_columns** — Trace claims `paid_invoice.amount_paid` and `currency:`; actual uses `price.unit_amount` and no currency
8. **Structural table: payment_method_types** — Trace claims EXTRA `['card']`; actual does not have it in purchase_top_up
9. **Structural table: payment_intent_data** — Trace claims MISSING; actual has it
10. **Structural table: invoice_data description** — Trace claims omitted; actual has `description: 'AI Credit Top-Up'`
11. **Rows 4-5 / Structural table: Checkout session lookup** — Trace claims EXTRA `Stripe::Checkout::Session.list` call in webhook; actual does not have it
12. **Structural table: WebSocket broadcast** — Trace claims MISSING; actual has `GlobalChannel.broadcast_to`
13. **Structural table: Internal notification job** — Trace claims MISSING; actual has `Notification::PaidAiCreditPackPurchasedJob`
14. **Structural table: Double-charge guard** — Trace claims single-condition; actual has two conditions (`stripe_invoice_id.present? && stripe_invoice_paid?`)

### One actual bug found (not a trace discrepancy)

`/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/jobs/notification/paid_ai_credit_pack_purchased_job.rb:12-14` — Exception variable capture error. Should be `rescue ActiveRecord::RecordNotFound => e`.

---

## Conclusion

The trace is not reliable as a specification document for code review. It documents code that no longer exists (14 stale claims). The actual one-off purchase implementation is now closer to the analog than the trace represents. For any future review cycles, use the actual code files directly as the source of truth, not the trace document.
