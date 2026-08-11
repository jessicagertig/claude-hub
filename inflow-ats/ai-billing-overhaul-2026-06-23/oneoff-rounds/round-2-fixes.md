# One-Off Purchase — Round 2 Fixes

## Summary

Four files were reviewed for deviations from the analog pattern (WWR Listing creation):

1. **organization_ai_credit_purchase.rb** — 3 code fixes applied (method signature, amount source, currency removal)
2. **organization_ai_credit_purchases_controller.rb** — 1 code fix applied (metadata alignment)
3. **stripe_webhook_handler_job.rb** — No code changes needed (trace was inaccurate)
4. **apply_ai_credit_purchase.rb** — No code changes needed (broadcast/notification already present)
5. **paid_ai_credit_pack_purchased_job.rb** — 1 code fix applied (error binding)

---

## app/models/organization_ai_credit_purchase.rb

### Changes Made

**1. Deviation 1 (price arg → zero-arg):** Changed `charge_default_payment_method(price)` to `charge_default_payment_method` (zero arguments). The model now resolves the Stripe Price internally via `Stripe::Price.list(lookup_keys: [stripe_price_lookup_key], ...)`, matching the analog's pattern where `charge_for_listing` is self-contained and takes no arguments.

- Updated controller call at `organization_ai_credit_purchases_controller.rb:107` (removed price argument)
- Updated all spec calls in `organization_ai_credit_purchase_charge_spec.rb` (removed price argument)
- Added `Stripe::Price.list` stub to spec `before` block

**2. Deviation 5 (update_columns amount source):** Changed `stripe_amount: paid_invoice.amount_paid` to `stripe_amount: amount` where `amount = price.unit_amount`. This matches the analog which uses the pre-charge local amount (from `calculate_charge_amount`), not the post-charge Stripe response amount.

**3. Deviation 6 (currency in update_columns):** Removed `currency: paid_invoice.currency` from `update_columns`. The analog does not write currency in `update_columns`. Our record already has `currency: 'usd'` set at creation time.

**4. Deviation 7 (double-charge guard):** Already had two conditions (`stripe_invoice_id.present? && stripe_invoice_paid?`). The analog uses `stripe_invoice_id.present? && is_active?`. Our `stripe_invoice_paid?` is the domain equivalent of the analog's `is_active?` (both mean "this charge completed successfully"). No code change needed — structure already matches.

### Trace Inaccuracies

**Deviations 2, 3:** `description` field IS present in both `InvoiceItem.create` and `Invoice.create` in the analog. The trace structural table was incorrect.

**Deviation 4:** `auto_advance: true` is NOT present in `Invoice.create` in the analog. The trace structural table was incorrect.

### Files Modified

- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/models/organization_ai_credit_purchase.rb` (lines 123-165)
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (line 107)
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/spec/models/organization_ai_credit_purchase_charge_spec.rb` (added `Stripe::Price.list` stub, removed `stripe_price` arg from all calls)

### Note on Extra API Calls

The zero-arg pattern means the model makes its own `Stripe::Price.list` call, and the controller ALSO makes one at line 77 (needed for the checkout-session path's `price: price.id`). For the card-on-file path, this results in two `Stripe::Price.list` calls per purchase. The analog avoids this because its amount is hardcoded. This is acceptable for structural matching; if latency/cost becomes a concern, consider passing the already-resolved price back in.

---

## app/controllers/api/v1/organization_ai_credit_purchases_controller.rb

### Trace Inaccuracies (No Code Changes Needed)

The trace documentation was inaccurate about what the code contains. The following deviations turned out to be **trace errors, not code errors**:

- **Deviation 1:** Direct-charge response was already `render_one(purchase, Serializer)` (line 108), not `render json: { charged: true }`
- **Deviation 2:** Checkout response was already `render json: { redirectUrl: session.url, sessionId: session.id }, status: :created` (lines 150/152)
- **Deviation 3:** `payment_method_types: ['card']` was already absent from the checkout session
- **Deviation 4:** `payment_intent_data` with metadata was already present (lines 116-122)
- **Deviation 5:** `description: 'AI Credit Top-Up'` was already present in `invoice_data` (line 127)

### Changes Made

**Deviation 6: Metadata alignment across three checkout session blocks.** Aligned the three metadata blocks to match the analog's structural pattern (top-level `metadata` = `payment_intent_data.metadata` = identical full key set):

- Added `ai_credit_pack_top_up: 'true'` to `payment_intent_data.metadata` (was missing)
- Added `stripe_price_lookup_key: lookup_key` to top-level `metadata` (was missing)
- Reordered top-level `metadata` keys to match `payment_intent_data.metadata` order for consistency

### Files Modified

- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (metadata block alignment)

---

## app/jobs/stripe_webhook_handler_job.rb

### No Code Changes Needed

The code at lines 212-221 (invoice.paid AI credit one-off branch) already matches the analog pattern:

- Does NOT perform a `Stripe::Checkout::Session.list` call
- Does NOT pass `checkout_session_id` to `ApplyAiCreditPurchase.call`
- Passes only `invoice_id: object.id`

Both of these match the analog (WWR), which also does no checkout session lookup in its `invoice.paid` handler.

### Trace Inaccuracies

**Deviations 1-2:** The trace documentation described code that does not exist:

- Trace rows 4-5 (lines 462-465) describe a `Stripe::Checkout::Session.list` call at `stripe_webhook_handler_job.rb:216-218` that does not exist in the actual file
- Trace row 5 (lines 468-479) shows `checkout_session_id: checkout_session_id` in the `ApplyAiCreditPurchase.call` kwargs, but the actual call (file lines 213-220) passes only `invoice_id: object.id` with no `checkout_session_id` parameter

The webhook handler code is already correct. No changes needed.

---

## app/interactors/apply_ai_credit_purchase.rb

### No Code Changes Needed

Both the `GlobalChannel.broadcast_to` (growl broadcast) and `Notification::PaidAiCreditPackPurchasedJob` are already present in the code and structurally match the analog.

### Structural Comparison

The analog's `create_on_wwr` post-payment sequence:

1. External API call (WWR listing creation) → NOT applicable to AI credits
2. `update_columns(wwr_listing_id:, wwr_slug:, ...)` → NOT applicable (no external resource)
3. `broadcast_event` via `JobChannel` → NOT applicable (AI credits are org-level, no job context)
4. `broadcast_show_growl` via `GlobalChannel` → ✓ Our lines 94-98 match this exact pattern
5. `Notification::PaidWwrListingCreatedJob.perform_later(org_id, job_id)` → ✓ Our line 101 does `Notification::PaidAiCreditPackPurchasedJob.perform_later(organization.id, existing.id)`

The trace's structural table incorrectly marked the broadcast and notification job as MISSING. They exist in the code.

### Files Modified

None. The code at `app/interactors/apply_ai_credit_purchase.rb:94-101` already contains the required patterns.

---

## app/jobs/notification/paid_ai_credit_pack_purchased_job.rb

### Changes Made

**Error binding fix:** Added `=> e` to `rescue ActiveRecord::RecordNotFound` on line 12. Without it, `ap e` on line 14 would raise `NameError: undefined local variable or method 'e'`, masking the original `RecordNotFound`.

### Note on Analog Bug

The analog (`paid_wwr_listing_created_job.rb`) has the identical bug at its lines 12-14 — `rescue ActiveRecord::RecordNotFound` without `=> e` but `ap e` on line 14. Our fix diverges from the analog's literal text but matches its obvious intent. The analog itself needs the same fix.

### Files Modified

- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/jobs/notification/paid_ai_credit_pack_purchased_job.rb` (line 12)
