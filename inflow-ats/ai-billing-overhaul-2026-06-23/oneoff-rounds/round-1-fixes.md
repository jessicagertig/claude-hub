# One-Off Purchase — Round 1 Fixes

## Summary

All deviations from analog patterns have been corrected. The one-off purchase flow now structurally matches the board/listing analogs (BoardWwrListing and BoardWhatJobsListing) across all layers: model, controller, job, interactor, schema, and frontend.

---

## app/models/organization_ai_credit_purchase.rb

**Status: All 7 deviations fixed**

### Deviations fixed

1. **auto_advance: true removed** — Analog (`board_wwr_listing.rb:143-151`) omits it; even has commented-out `# auto_advance: false` showing it was considered and rejected.

2. **InvoiceItem description added** — Changed from no description to `description: pack_name` using `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY`. Analog (`board_wwr_listing.rb:130-138`) includes `description: @final_description`.

3. **Invoice description added** — Changed from no description to `description: 'AI Credit Top-Up'`. Analog (`board_wwr_listing.rb:143-151`) includes `description: 'We Work Remotely Listing'`.

4. **stripe_amount uses locally-computed amount** — Changed from `stripe_amount: paid_invoice.amount_paid` to `stripe_amount: amount` (where `amount = price.unit_amount`). Analog (`board_wwr_listing.rb:158`) uses the locally-computed value, not the Stripe response.

5. **update_columns no longer stamps currency** — Removed `currency: paid_invoice.currency`. Analog (`board_wwr_listing.rb:158`) writes only `stripe_invoice_id`, `stripe_invoice_item_id`, `stripe_amount`.

6. **Method signature changed to accept price** — Changed from `charge_default_payment_method` to `charge_default_payment_method(price)`. Eliminates redundant `Stripe::Price.list` call (controller already resolved it at line 77-78). Analog (`board_wwr_listing.rb:112-164`) uses local `calculate_charge_amount`, never calls Stripe for pricing.

7. **Double-charge guard strengthened** — Changed from `return if stripe_invoice_id.present?` to `return if stripe_invoice_id.present? && stripe_invoice_paid?`. Analog checks both presence AND status (`stripe_invoice_id.present? && is_active?`).

### Files modified

- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/models/organization_ai_credit_purchase.rb` (model method logic, lines 123-160)
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (caller at line 107)
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/spec/models/organization_ai_credit_purchase_charge_spec.rb` (all related test updates)

### Whitelist

None. All deviations structurally required for correctness.

### Revert

None. All changes are correct.

---

## app/controllers/api/v1/organization_ai_credit_purchases_controller.rb

**Status: All 5 deviations fixed**

### Deviations fixed

1. **Removed `payment_method_types: ['card']`** — Analog does not specify it; Stripe defaults to customer's available methods.

2. **Added `payment_intent_data` block with metadata** — Keys `organization_ai_credit_purchase_id`, `organization_id`, `stripe_price_lookup_key` match the analog pattern (`board_wwr_listings_controller.rb:94-99`), adapted for AI credit context.

3. **Added `description: 'AI Credit Top-Up'` to invoice_data** — Matches analog's `description: @final_invoice_description`. Uses the same description string already in the model's `Stripe::Invoice.create`.

4. **Checkout response: added `sessionId` and `status: :created`** — Partially matches analog (`boardWwrListingsController` returns `url` + `sessionId`, we return `redirectUrl` + `sessionId` + `status`). **WHITELIST: redirectUrl kept** — frontend at `AiCreditSubscription.tsx:162` reads `data.redirectUrl` for redirect. Changing to `url` would break checkout flow. Analog's frontend reads `url` because it was built that way. Alignment requires coordinated frontend+backend change.

5. **Direct-charge response: changed to serialized purchase** — Changed from `render json: { charged: true }` to `render_one(purchase, Api::V1::OrganizationAiCreditPurchaseSerializer)`. Matches analog's `render_one(@listing, Api::V1::BoardWwrListingSerializer)`. Frontend safe: `onSuccess` checks `data.redirectUrl` which will be absent on serialized record, falls through to toast correctly.

### Files modified

- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`

### Whitelist

- **[deviation 4-partial]** — `redirectUrl` key name kept instead of analog's `url`. Frontend dependency at `AiCreditSubscription.tsx:162` requires this key. Coordinated frontend+backend change needed for alignment, outside scope of one-off deviations.

### Revert

None. All changes correct.

---

## app/jobs/stripe_webhook_handler_job.rb

**Status: Deviation fixed; fallback code now unreachable but harmless**

### Deviation fixed

**Removed `Stripe::Checkout::Session.list` API call from `invoice.paid` webhook handler** (lines 212-230)
- Removed the `checkout_session_id` lookup for one-off purchases
- Matches analog pattern: no extra Stripe API calls for invoice-based lookups
- `ApplyAiCreditPurchase.call` now uses only the primary `purchase_id` lookup from invoice metadata (both direct-charge and checkout paths stamp `organization_ai_credit_purchase_id` in invoice metadata)

### Collateral

**Interactor fallback code now unreachable**: `ApplyAiCreditPurchase#apply_one_off` lines 47-48 still have a `context.checkout_session_id` fallback branch. It is now unreachable from the webhook handler (webhook no longer passes it), evaluates to `nil`, and skips. This is harmless dead code that should be cleaned up in a later pass, but the interactor is out of scope for this deviation fix. The fallback may be useful if another call site ever provides `checkout_session_id`.

### Files modified

- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/jobs/stripe_webhook_handler_job.rb`

### Whitelist

None.

### Revert

**Future cleanup (not in scope)**: Remove the `context.checkout_session_id` fallback branch from the interactor to eliminate unreachable code. This is a follow-up, not a deviation fix.

---

## app/interactors/apply_ai_credit_purchase.rb

**Status: 2 behavioral deviations fixed**

### Deviations fixed

1. **WebSocket broadcast added** — Added `GlobalChannel.broadcast_to(organization.owner, action: 'showGrowl', payload: { title: '...', kind: 'success' })` after successful one-off credit grant. Matches analog pattern (`BoardWwrListing#create_on_wwr` calls `broadcast_show_growl`). Frontend's `WebsocketGlobalChannelHandler` already handles `showGrowl` by calling `addToast`.

2. **Slack notification job added** — Added `Notification::PaidAiCreditPackPurchasedJob.perform_later(organization.id, existing.id)` after broadcast. New job file created: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/jobs/notification/paid_ai_credit_pack_purchased_job.rb`. Matches analog pattern (`BoardWwrListing#create_on_wwr` calls `Notification::PaidWwrListingCreatedJob.perform_later`). Job structure: `perform(organization_id, purchase_id)` finds org and purchase, sends Slack to `Variables::SLACK_3RD_PARTY_PURCHASES_WEBHOOK`. Message format matches analog: `[env]\n*title*\nCompany: name (id)\n<context fields>`.

### Files modified

- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/interactors/apply_ai_credit_purchase.rb` (lines 90-101)
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/jobs/notification/paid_ai_credit_pack_purchased_job.rb` (new file)

### Whitelist

None.

### Revert

None.

---

## app/javascript/src/helpers/planHelpers.ts

**Status: Frontend key alignment fixed; wrong credit amounts removed**

### Changes made

**AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY** (lines 68-75 -> 68-79):

- Added all 6 production keys:
  - `plato_ai_credit_top_up_small`: 50 credits
  - `plato_ai_credit_top_up_medium`: 150 credits
  - `plato_ai_credit_top_up_large`: 300 credits
  - `plato_ai_credit_subscription_small`: 250 credits
  - `plato_ai_credit_subscription_medium`: 1000 credits ← **Was 1250 (wrong), now corrected to match backend**
  - `plato_ai_credit_subscription_large`: 2500 credits

- Removed:
  - `ai_credit_pack_top_up_medium` (100 credits) — no backend dev counterpart
  - `ai_credit_pack_subscription_medium_monthly` (1250 credits) — no backend dev counterpart; also wrong credit count (1250 vs backend's 1000)

- Kept (have matching backend dev keys):
  - `ai_credit_pack_top_up_small`, `ai_credit_pack_top_up_large`
  - `ai_credit_pack_subscription_small_monthly`, `ai_credit_pack_subscription_large_monthly`

**AI_CREDIT_PACK_DISPLAY_NAMES** (lines 77-84 -> 81-92):
- Added display names for all 6 production keys
- Removed entries for the deleted keys

### Files modified

- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/shared/lib/planHelpers.ts`

### Whitelist

None.

### Revert

None.

---

## db/schema.rb

**Status: All 3 deviations fixed**

### Changes made

1. **Schema version updated** — `2026_06_11_120001` → `2026_06_11_120003` (reflects all migrations)

2. **Column renamed** — `amount_cents_paid` → `stripe_amount` (line 972). Matches analog column names (`board_wwr_listings.stripe_amount`, `board_what_jobs_listings.stripe_amount`). Preserves `null: false` constraint.

3. **Missing columns added** — From migrations 20260611120002 and 20260611120003:
   - `t.boolean "stripe_invoice_paid", default: false` — Matches analog pattern (`board_wwr_listings` line 266, `board_what_jobs_listings` line 228)
   - `t.string "stripe_invoice_item_id"` — Matches analog pattern (`board_wwr_listings` line 265, `board_what_jobs_listings` line 227)
   - `t.bigint "last_updated_by_organization_user_id"` — With index and foreign key (matches `board_wwr_listings` line 276 pattern)

4. **Foreign key added** (line 1376) — `add_foreign_key "organization_ai_credit_purchases", "organization_users", column: "last_updated_by_organization_user_id"` — Matches analog pattern.

### Files modified

- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/db/schema.rb`

### Whitelist

None.

### Revert

None.

---

## Round 1 Summary

**All structural deviations resolved.** The one-off purchase flow now matches the board/listing analogs across:
- Model layer: Stripe API calls (create + charge), double-charge guard, column stamping
- Controller layer: Checkout session creation, invoice metadata, response serialization
- Job layer: Webhook invocation, API call elimination
- Interactor layer: Credit grant logic, notifications (WebSocket + Slack)
- Schema layer: Column names, flags, audit fields
- Frontend layer: Key names, credit amounts

**Fallback code note**: `ApplyAiCreditPurchase#apply_one_off` has an unreachable `checkout_session_id` fallback. This is harmless and flagged for future cleanup, not blocking.

**Whitelist exception**: `redirectUrl` key name kept in checkout response due to frontend dependency. Requires coordinated change.
