# One-Off Purchase — Round 1 Audit (v3)

Structural deviation audit comparing current one-off purchase implementation against analogous board-listing charge flows (WWR primary analog, WhatJobs secondary). Sanctioned deviations and whitelisted naming items excluded per project CLAUDE.md. All findings below are reportable unless marked "legitimate omission."

---

## Deviations Found

### 1. Direct-charge authorization policy

| Aspect | Analog (WWR) | Ours |
|--------|--------------|------|
| **Pattern** | `BoardWwrListingsController#create` uses `authorize @listing` → `BoardWwrListingPolicy#create?` (object-level policy on the listing record) | `charge_top_up` uses `authorize :billing, :checkout?` — no object-level `OrganizationAiCreditPurchasePolicy#create?` on the pre-built purchase record |
| **File** | `app/controllers/api/v1/board_wwr_listings_controller.rb:19` | `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:76` |
| **Finding** | DEVIATION — object-level authz vs. action-level authz on the same code path |

---

### 2. `Stripe::InvoiceItem` metadata carries extra descriptor keys

| Aspect | Analog | Ours |
|--------|--------|------|
| **Keys** | Record id ONLY: `{ board_wwr_listing_id: id }` | Four keys: `{ organization_id, organization_ai_credit_purchase_id, stripe_price_lookup_key, ai_credit_pack_top_up: 'true' }` |
| **File** | `board_wwr_listing.rb:135-137` | `organization_ai_credit_purchase.rb:141-146` |
| **Finding** | DEVIATION — `stripe_price_lookup_key` and `ai_credit_pack_top_up` are added Stripe metadata fields not present in analog; `organization_id` is extra |

---

### 3. `Stripe::Invoice` metadata carries extra descriptor keys

| Aspect | Analog | Ours |
|--------|--------|------|
| **Keys** | Record id ONLY: `{ board_wwr_listing_id: id }` | Four keys: `{ organization_id, organization_ai_credit_purchase_id, stripe_price_lookup_key, ai_credit_pack_top_up: 'true' }` |
| **File** | `board_wwr_listing.rb:148-150` | `organization_ai_credit_purchase.rb:153-158` |
| **Finding** | DEVIATION — `stripe_price_lookup_key` and `ai_credit_pack_top_up` are added Stripe metadata fields; `organization_id` is extra |

---

### 4. Webhook resolves purchase via triple-fallback interactor instead of direct record-id find

| Aspect | Analog | Ours |
|--------|--------|------|
| **Resolution** | Direct: `BoardWwrListing.find(listing_id)` where `listing_id = object.metadata.board_wwr_listing_id.to_i` | Interactor: `ApplyAiCreditPurchase.call(...)` which resolves with primary `find_by(id: purchase_id)` + two fallbacks (`stripe_checkout_session_id`, `stripe_invoice_id`) |
| **File** | `stripe_webhook_handler_job.rb:235-241` | `stripe_webhook_handler_job.rb:213-220` + `apply_ai_credit_purchase.rb:46-51` |
| **Finding** | DEVIATION — indirect resolution via interactor + fallback chain vs. direct record lookup |

---

### 5. Direct-charge `Stripe::InvoiceItem` uses `price:` (id reference) not `amount:`/`currency:` (hardcoded)

| Aspect | Analog | Ours |
|--------|--------|------|
| **API Call** | `Stripe::InvoiceItem.create(customer:, amount: amount, currency: 'usd', description:, metadata:)` — hardcoded amount in cents | `Stripe::InvoiceItem.create(customer:, price: price.id, description:, metadata:)` — uses resolved Stripe Price id |
| **File** | `board_wwr_listing.rb:130-138` | `organization_ai_credit_purchase.rb:137-147` |
| **Finding** | DEVIATION — amount sourced from Stripe Price record vs. hardcoded locally computed amount |

---

### 6. Checkout-session `line_items` uses `price:` (id reference) not `price_data:` (inline definition)

| Aspect | Analog | Ours |
|--------|--------|------|
| **API Call** | `line_items: [{ price_data: { currency: 'usd', product_data: { name:, description: }, unit_amount: amount }, quantity: 1 }]` — inline price_data | `line_items: [{ price: price.id, quantity: 1 }]` — resolved Stripe Price id |
| **File** | `board_wwr_listings_controller.rb:83-93` | `organization_ai_credit_purchases_controller.rb:163` |
| **Finding** | DEVIATION — same root divergence as #5: amount sourced from Stripe Price vs. hardcoded locally |

---

### 7. Checkout-session `invoice_creation.invoice_data.metadata` carries extra descriptor keys

| Aspect | Analog | Ours |
|--------|--------|------|
| **Keys** | `{ board_wwr_listing_id, job_id }` | `{ organization_id, organization_ai_credit_purchase_id, stripe_price_lookup_key, ai_credit_pack_top_up: 'true' }` |
| **File** | `board_wwr_listings_controller.rb:105-108` | `organization_ai_credit_purchases_controller.rb:176-181` |
| **Finding** | DEVIATION — extra descriptor keys (`stripe_price_lookup_key`, `ai_credit_pack_top_up`); `job_id` omission is a legitimate structural difference (no job association on purchase) |

---

### 8. Checkout-session top-level `metadata` carries extra descriptor keys

| Aspect | Analog | Ours |
|--------|--------|------|
| **Keys** | `{ board_wwr_listing_id, organization_id, job_id }` | `{ organization_ai_credit_purchase_id, organization_id, stripe_price_lookup_key, ai_credit_pack_top_up: 'true' }` |
| **File** | `board_wwr_listings_controller.rb:111-114` | `organization_ai_credit_purchases_controller.rb:184-189` |
| **Finding** | DEVIATION — `stripe_price_lookup_key` and `ai_credit_pack_top_up` added; `job_id` omission legitimate |

---

### 9. Model lacks the analog's `after_update` re-charge callback

| Aspect | Analog | Ours |
|--------|--------|------|
| **Callback** | `after_update :handle_after_update` calls `charge_for_listing unless stripe_invoice_paid` — model re-charges on update | No `after_update` callback; `charge_for_purchase` invoked explicitly from controller only |
| **File** | `board_wwr_listing.rb:9` + `:67-72` | `organization_ai_credit_purchase.rb` (no update action in controller) |
| **Finding** | STRUCTURAL ABSENCE — no update action in ours, so this is a legitimate omission. Flagging for completeness. |

---

### 10. Webhook does not pass `checkout_session_id` to the interactor, but interactor expects it as fallback #1

| Aspect | Analog | Ours |
|--------|--------|------|
| **Call** | n/a — direct record lookup | `ApplyAiCreditPurchase.call(...)` called WITHOUT `checkout_session_id:` argument from webhook (line 213-220) |
| **Fallback** | n/a | Interactor reads `context.checkout_session_id` as fallback #1 (line 47-48) — always nil from this caller |
| **File** | n/a | `stripe_webhook_handler_job.rb:213-220` + `apply_ai_credit_purchase.rb:47-48` |
| **Finding** | DEAD CODE — interactor declares fallback #1 but the webhook (the sole caller for this branch) never supplies it. Fallback is unreachable from this code path. |

---

## Summary

**Total Deviations:** 10 findings
- **Reportable structural divergences:** 8 (items 1–8, 10)
- **Legitimate structural omissions:** 2 (items 9, plus `job_id` in items 7–8)

**Areas of Divergence:**
1. **Authorization pattern:** object-level vs. action-level authz
2. **Stripe metadata inflation:** four extra fields across InvoiceItem, Invoice, and checkout-session metadata
3. **Price sourcing:** amount resolution via Stripe Price id vs. hardcoded locally computed amount
4. **Webhook resolution:** indirect interactor fallback chain vs. direct record lookup
5. **Dead code:** unreachable fallback in interactor resolution chain

**Note on Scope:** The current implementation has been refactored from an earlier single-action design into a two-action / two-hook split (matching the analog's structure) with proper `finalize_stripe_payment` webhook choke-point, `last_updated_by_organization_user` stamping, and `stripe_invoice_paid: false` initial state. The deviations above represent what structural divergences remain after that refactor.

---

## File References

| File | Purpose |
|------|---------|
| `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/models/organization_ai_credit_purchase.rb` | Ours: model (deviations 2, 3, 5, 9) |
| `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` | Ours: controller (deviations 1, 6, 7, 8) |
| `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/jobs/stripe_webhook_handler_job.rb` | Ours: webhook handler (deviations 4, 10) |
| `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/interactors/apply_ai_credit_purchase.rb` | Ours: interactor (deviations 4, 10) |
| `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/models/board_wwr_listing.rb` | Analog: WWR model (primary reference) |
| `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/board_wwr_listings_controller.rb` | Analog: WWR controller (primary reference) |
| `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/models/board_what_jobs_listing.rb` | Analog: WhatJobs model (secondary reference) |
| `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/board_what_jobs_listings_controller.rb` | Analog: WhatJobs controller (secondary reference) |
