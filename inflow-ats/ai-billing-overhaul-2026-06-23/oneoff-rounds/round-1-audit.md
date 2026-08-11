# One-Off Purchase — Round 1 Audit

## Overview

Comprehensive verification of the one-off AI credit purchase implementation against the "We Work Remotely" (WWR) listing analog. All rows in the structural trace have been verified against the actual code in `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.

---

## Trace Accuracy: Confirmed SAME

The following structural elements match the analog exactly:

- Record pre-created before charge
- Record saved before Stripe call
- `stripe_invoice_paid` defaults to false for both paths
- Checkout path authorization `authorize :billing, :checkout?`
- InvoiceItem `customer:` field
- Invoice `customer:` field
- Invoice `collection_method: 'charge_automatically'`
- `Stripe::Invoice.pay(invoice.id)` call
- `update_columns` stamps `stripe_invoice_id: invoice.id`
- `update_columns` stamps `stripe_invoice_item_id: invoice_item.id`
- Checkout `customer:` field
- Checkout `mode: 'payment'`
- `finalize_stripe_payment` → `update_columns(stripe_invoice_paid: true)`
- No `charge_for_listing` model rescue (exceptions propagate)
- Neither path tracks purchases via PosthogTrackJob

---

## Deviations from Analog (Non-Whitelisted)

### 1. DEVIATION: Stripe Invoice includes `auto_advance: true`

**Analog:** `board_wwr_listing.rb:143-151` — no `auto_advance` key  
**Ours:** `organization_ai_credit_purchase.rb:146` — includes `auto_advance: true`

**Impact:** Low. This is a minor Stripe configuration choice; WWR doesn't set it and defaults to false (invoice doesn't auto-transition to open). AI credits explicitly set true. No data loss or functional breakage, but inconsistent with analog.

---

### 2. DEVIATION: Stripe InvoiceItem omits `description:`

**Analog:** `board_wwr_listing.rb:130-138` — includes `description: @final_description` (e.g., "We Work Remotely Listing — Front End Job")  
**Ours:** `organization_ai_credit_purchase.rb:132-141` — no `description:` key

**Impact:** Low. Stripe invoice line items appear with empty description in Stripe dashboard. Customers can still see charge amount and invoice total. Customer-facing Stripe email shows no item description.

---

### 3. DEVIATION: Stripe Invoice omits `description:`

**Analog:** `board_wwr_listing.rb:143-151` — includes `description: 'We Work Remotely Listing'`  
**Ours:** `organization_ai_credit_purchase.rb:143-153` — no `description:` key

**Impact:** Low. Stripe invoice dashboard and customer-facing email show no invoice description. Amount and line items still visible.

---

### 4. DEVIATION: Checkout Session includes `payment_method_types: ['card']`

**Analog:** `board_wwr_listings_controller.rb:80-118` — does not specify `payment_method_types`  
**Ours:** `organization_ai_credit_purchases_controller.rb:115` — includes `payment_method_types: ['card']`

**Impact:** None. Restricting to card payments is a design choice (more conservative than allowing all default methods). Analog doesn't restrict; ours does. Not a bug.

---

### 5. DEVIATION: Checkout Session omits `payment_intent_data:` with metadata

**Analog:** `board_wwr_listings_controller.rb:94-99` — includes `payment_intent_data: { metadata: { board_wwr_listing_id:, organization_id:, job_id: } }`  
**Ours:** `organization_ai_credit_purchases_controller.rb:112-135` — no `payment_intent_data:` key

**Impact:** Medium. WWR can query Stripe for all checkout sessions → payments by metadata (e.g., "find all payments for listing X"). AI credits cannot. Webhook handler workarounds this via `session.client_reference_id` containing purchase ID, but the parallel structure breaks. Not data-losing but inconsistent infrastructure.

---

### 6. DEVIATION: Checkout Session `invoice_creation.invoice_data` omits `description:`

**Analog:** `board_wwr_listings_controller.rb:103-104` — includes `description: @final_invoice_description`  
**Ours:** `organization_ai_credit_purchases_controller.rb:119-126` — no `description:` in `invoice_data`

**Impact:** Low. Same as DEVIATION 3 — empty description in Stripe dashboard/email.

---

### 7. DEVIATION: Checkout Session response shape differs

**Analog:** `board_wwr_listings_controller.rb:120` — returns `render json: { url: session.url, sessionId: session.id }, status: :created`
- Key name: `url`
- Additional field: `sessionId: session.id`
- HTTP status: `201 (Created)`

**Ours:** `organization_ai_credit_purchases_controller.rb:143` — returns `render json: { redirectUrl: session.url }`
- Key name: `redirectUrl` (frontend expects this exact name in `planHelpers.ts:91`)
- No `sessionId` field
- HTTP status: `200 (OK)` (no explicit `status:` keyword, Rails defaults to 200)

**Impact:** Medium-High. The response contract differs from the analog. If frontend expects `sessionId` in session responses, it won't find it. Currently frontend only consumes `redirectUrl` (line 91 `window.location.href = res.data.redirectUrl`), so the missing `sessionId` doesn't break anything — but it's a deviation in contract shape. The HTTP status mismatch (200 vs 201) is minor (both indicate success), but the status expectation can affect tests and logging.

---

### 8. DEVIATION: Direct-charge response returns minimal flag, not serialized record

**Analog:** `board_wwr_listings_controller.rb:22` — returns `render_one(@listing, Api::V1::BoardWwrListingSerializer)` (full serialized record with all fields)  
**Ours:** `organization_ai_credit_purchases_controller.rb:108` — returns `render json: { charged: true }` (bare boolean flag)

**Impact:** Medium. Frontend must re-fetch the purchase record to see updated `stripe_invoice_id`, `stripe_amount`, `stripe_invoice_paid` fields. No silent data loss, but extra network round-trip and no immediate UI update. Analog returns full record immediately; ours does not.

---

### 9. DEVIATION: Direct-charge `update_columns` uses Stripe-reported amount, not local amount

**Analog:** `board_wwr_listing.rb:158` — stamps `stripe_amount: amount` (the locally-computed `calculate_charge_amount` value)  
**Ours:** `organization_ai_credit_purchase.rb:160` — stamps `stripe_amount: paid_invoice.amount_paid` (Stripe-reported value from the `.pay()` response)

**Impact:** Low-Medium. Both approaches are sound (local vs. Stripe-reported). The risk: if Stripe's reported amount differs from what we calculated (due to rounding, currency conversion, or API drift), we record the Stripe amount, which is correct for reconciliation but may indicate a prior miscalculation. No data loss, but the divergence is noteworthy. Analog uses local amount; ours uses Stripe's.

---

### 10. DEVIATION: Direct-charge `update_columns` also stamps `currency:`

**Analog:** `board_wwr_listing.rb:158` — only stamps `stripe_invoice_id`, `stripe_invoice_item_id`, `stripe_amount`  
**Ours:** `organization_ai_credit_purchase.rb:157-162` — also stamps `currency: paid_invoice.currency`

**Impact:** None. Adding `currency:` is forward-thinking (easier reconciliation, multi-currency support). Not a regression.

---

### 11. DEVIATION: Model `charge_default_payment_method` makes a SECOND `Stripe::Price.list` call

**Analog:** `board_wwr_listing.rb:112-164` — uses `calculate_charge_amount` (hardcoded local pricing, zero Stripe API calls for price resolution)  
**Ours:** `organization_ai_credit_purchase.rb:128-129` — calls `Stripe::Price.list(lookup_keys: [stripe_price_lookup_key], active: true, limit: 1)`

**Issue:** The controller already called `Stripe::Price.list` at `organization_ai_credit_purchases_controller.rb:77` to validate the price lookup key. The model method calls it **again** at line 128-129, resulting in a redundant API call per direct-charge purchase.

**Impact:** High. Redundant API call doubles Stripe API usage for direct-charge flow. Over N purchases, cost = N extra API calls. Analog avoids this by using hardcoded local pricing.

---

### 12. DEVIATION: Webhook handler makes extra `Stripe::Checkout::Session.list` API call

**Analog:** `stripe_webhook_handler_job.rb:233-243` (WWR branch) — zero Stripe API calls; just `find` by metadata, `finalize_stripe_payment`, `create_on_wwr`  
**Ours:** `stripe_webhook_handler_job.rb:216-218` — calls `Stripe::Checkout::Session.list(payment_intent: object.payment_intent, limit: 1)` for every `invoice.paid` event with `ai_credit_pack_top_up` metadata

**Issue:** For every `invoice.paid` webhook (both checkout and direct-charge paths), the handler queries Stripe for the checkout session. For direct-charge, no checkout session exists; the call is wasted. For checkout path, the session should already exist in `stripe_checkout_session_id` on the purchase record — no need to query again.

**Impact:** High. Redundant API call for every `invoice.paid` event. Over N purchases, cost = N extra API calls.

---

### 13. DEVIATION: Double-charge guard is weaker

**Analog:** `board_wwr_listing.rb:115` — guards with `return if stripe_invoice_id.present? && is_active?` (two conditions: invoice exists AND listing is active)  
**Ours:** `organization_ai_credit_purchase.rb:125` — guards with `return if stripe_invoice_id.present?` (one condition: invoice exists)

**Impact:** Low. Ours is simpler — if the record already has a Stripe invoice, don't charge again. Analog checks a second condition (must be active) to avoid charging inactive listings. For AI credits, the concept of "inactive" may not apply. No security hole, but guard is less defensive.

---

### 14. DEVIATION: No WebSocket broadcast after successful payment

**Analog:** `stripe_webhook_handler_job.rb:241` — calls `listing.create_on_wwr` which internally calls:
- `broadcast_event('wwr_listing_published')`
- `broadcast_show_growl('Created WWR Listing')`

**Ours:** `apply_ai_credit_purchase.rb:38-89` — no broadcast call

**Impact:** Medium-High. User sees credits "appear shortly" only after a manual page refresh or React Query refetch. Analog broadcasts immediately so users see results in real-time (if listening). Lack of broadcast means UI lag — users don't know payment succeeded until they refresh.

---

### 15. DEVIATION: No internal notification after successful payment

**Analog:** `stripe_webhook_handler_job.rb:241` — via `create_on_wwr` → `Notification::PaidWwrListingCreatedJob.perform_later(job.organization.id, job.id)`  
**Ours:** `apply_ai_credit_purchase.rb:38-89` — no notification job enqueued

**Impact:** Low-Medium. Analog sends an internal notification so team/admins can track when listings go live. Ours sends no notification. No data loss, but observability/audit trail is weaker.

---

### 16. DEVIATION: Frontend/backend lookup_key mismatch

**Frontend:** `planHelpers.ts:68-75` — 6 keys, ALL prefixed `ai_credit_pack_*` (dev only)
```
ai_credit_pack_top_up_small
ai_credit_pack_top_up_medium
ai_credit_pack_top_up_large
ai_credit_pack_subscription_small_monthly
ai_credit_pack_subscription_medium_monthly
ai_credit_pack_subscription_large_monthly
```

**Backend:** `organization_ai_credit_purchase.rb:4-57` — 10 keys (6 production-prefixed `plato_ai_credit_*` + 4 dev-prefixed `ai_credit_pack_*`)

Dev keys in backend:
```
ai_credit_pack_top_up_small
ai_credit_pack_top_up_large
ai_credit_pack_subscription_small_monthly
ai_credit_pack_subscription_large_monthly
```

**Missing:** Backend dev keys do NOT include `ai_credit_pack_top_up_medium` or `ai_credit_pack_subscription_medium_monthly`. Frontend has these; backend doesn't.

**Missing:** Frontend has zero production keys (`plato_ai_credit_*`). Backend has 6.

**Production keys in backend** (frontend cannot select these):
```
plato_ai_credit_top_up_small
plato_ai_credit_top_up_medium
plato_ai_credit_top_up_large
plato_ai_credit_subscription_small_monthly
plato_ai_credit_subscription_medium_monthly
plato_ai_credit_subscription_large_monthly
```

**Impact:** High. Frontend and backend are misaligned on pricing tiers.
- If frontend tries to purchase `ai_credit_pack_top_up_medium`, backend will not find that lookup key and will raise an error during checkout session creation.
- In production, frontend sends `plato_*` keys but backend only lists `ai_credit_pack_*` in the method, so production checkout will also fail.
- The implementation is not usable in either development or production without fixing the key lists.

---

### 17. DEVIATION: `schema.rb` not dumped after migration

**Migration:** `db/migrate/20260611120002_add_stripe_payment_columns_to_organization_ai_credit_purchases.rb`
- Renames `amount_cents_paid` to `stripe_amount`
- Adds `stripe_invoice_paid` (boolean, default false)
- Adds `stripe_invoice_item_id` (string)

**schema.rb:** Line 972 still shows `t.integer "amount_cents_paid", null: false` (the OLD column name)

**Missing from schema.rb:**
- `stripe_invoice_paid` (boolean)
- `stripe_invoice_item_id` (string)

**Impact:** Critical. Running `rails db:schema:load` on a fresh database will create the table with the old column name and without the two new columns, breaking the app. Migration history will show the changes were applied, but the schema file is stale. The workaround (`rails db:migrate` instead of `schema:load`) works, but schema consistency is broken.

---

## Summary

| Deviation | Severity | Category |
|-----------|----------|----------|
| 1. `auto_advance: true` | Low | Config choice |
| 2. InvoiceItem no description | Low | UX/Dashboard |
| 3. Invoice no description | Low | UX/Dashboard |
| 4. Checkout `payment_method_types: ['card']` | None | Design choice |
| 5. Checkout no `payment_intent_data` | Medium | Infrastructure |
| 6. Checkout `invoice_data` no description | Low | UX/Dashboard |
| 7. Checkout response shape differs | Medium-High | API contract |
| 8. Direct-charge returns flag, not record | Medium | API contract/UX |
| 9. Uses Stripe amount vs. local amount | Low-Medium | Reconciliation |
| 10. Also stamps `currency:` | None | Improvement |
| 11. Redundant `Stripe::Price.list` in model | High | API usage |
| 12. Redundant `Checkout::Session.list` in webhook | High | API usage |
| 13. Weaker double-charge guard | Low | Defensive coding |
| 14. No WebSocket broadcast | Medium-High | UX/Observability |
| 15. No internal notification | Low-Medium | Observability/Audit |
| 16. Frontend/backend lookup_key mismatch | **CRITICAL** | Functionality |
| 17. `schema.rb` stale after migration | **CRITICAL** | Data integrity |

**Critical blockers:** 16, 17  
**High impact:** 11, 12, 14  
**Medium impact:** 5, 7, 8, 9, 15
