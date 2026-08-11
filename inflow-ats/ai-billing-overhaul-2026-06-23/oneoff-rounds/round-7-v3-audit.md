# One-Off Purchase — Round 7 Audit (v3)

## Summary

The confirm modal is the sanctioned EXTRA and clean. After a comprehensive traced audit comparing current code against the ANALOG (WWR primary + WhatJobs secondary), excluding sanctioned and whitelisted items, there is **one actionable structural deviation**: webhook record lookup method.

## Trace Chain

**Source files traced:**
- `organization_ai_credit_purchases_controller.rb` → `organization_ai_credit_purchase.rb` → `apply_ai_credit_purchase.rb` → `stripe_webhook_handler_job.rb` → `AiCreditSubscription.tsx` → `useOrganizationAiCreditPurchase.ts` → `AiCreditPackCard.tsx` → `PurchaseAiCreditTopUpConfirmModal.tsx`
- **Analogs:** `board_wwr_listing.rb`, `board_wwr_listings_controller.rb`, `board_what_jobs_listing.rb`, `board_what_jobs_listings_controller.rb`, `board_wwr_listing_policy.rb`, `useJob.ts`, `useWhatJobsListing.ts`, `organization_ai_credit_purchase_policy.rb`, `config/routes.rb`, `db/schema.rb`

## Important Context

The current code has been refactored away from the earlier trace's "OURS" description. It now uses **two separate actions** (`charge_top_up` + `create_top_up_checkout_session`) with two hooks and a renamed model method (`charge_for_purchase`). This new structure mirrors the analog's two-action design (`create`/`create_paid_listing` + `create_checkout_session`) much more closely than the prior version.

## Confirmed Structural Matches (Verified, Not Skipped)

### Direct-Charge Controller (`charge_top_up`)
- Build → authorize via `OrganizationAiCreditPurchasePolicy#create?` → save → `charge_for_purchase` → `render_one`
- Error rescue: `StandardError => e` → `render_general_errors(["Unable to process payment: #{e.message}"])`
- **Matches:** WWR `create` (`board_wwr_listings_controller.rb:5-31`), including instance-level authorize via `BoardWwrListingPolicy#create?` → `is_org_admin?`

### Direct-Charge Model (`charge_for_purchase`)
- Combined double-charge guard: `stripe_invoice_id.present? && stripe_invoice_paid?`
- Stripe customer blank guard: `stripe_customer_id.blank?`
- **InvoiceItem:** `amount:`, `currency: 'usd'` (NOT `price:`)
- **Invoice:** `collection_method: 'charge_automatically'`, NO `auto_advance`
- **Finalization:** `Stripe::Invoice.pay`, then `update_columns(stripe_invoice_id:, stripe_invoice_item_id:, stripe_amount:)` (NO currency write)
- **Metadata:** `{ organization_ai_credit_purchase_id: id }` only
- **Matches:** WWR `create_paid_listing` (`board_wwr_listing.rb:158`), including exact metadata key pattern

### Checkout Controller (`create_top_up_checkout_session`)
- Authorize → validity guard → build (with `stripe_invoice_paid: false`) → save → `Stripe::Checkout::Session.create` in `mode: 'payment'`
- Metadata structure: three blocks (payment_intent_data, invoice_creation.invoice_data, top-level) all keyed by record id + org id
- Response: `{ url:, sessionId: }, status: :created`
- Error rescue: `Stripe::StripeError` → JSON `{ error: e.message }, status: :unprocessable_entity`
- **Matches:** WWR `create_checkout_session` (`board_wwr_listings_controller.rb:51-128`)

### Webhook One-Off Branch
- Order: metadata-id check → finalize in-handler (`purchase.finalize_stripe_payment`) → "produce the product" call (`ApplyAiCreditPurchase.call`) → return
- Interactor takes `context.purchase` directly (handler resolves the record, passes it in)
- **Matches:** WWR flow (`stripe_webhook_handler_job.rb:234-245`)

### Frontend
- `handleBuyPack` branches on `stripeDefaultPaymentMethodOnFile` → confirm modal (sanctioned EXTRA) → `chargeTopUp`; else `createTopUpCheckoutSession` with redirect
- `useChargeAiCreditTopUp` onSuccess invalidates cache target (whitelisted divergence)
- `AiCreditPackCard` Button passes `loading`/`disabled` props (behavioral-props rule satisfied)
- **Matches:** WWR `useJob.ts`, `useWhatJobsListing.ts`

## Deviations from ANALOG

### Deviation: Webhook Record Lookup Method (ACTIONABLE)

**ANALOG pattern:**
- WWR: `listing = BoardWwrListing.find(listing_id)` (`stripe_webhook_handler_job.rb:238`) — raises on missing id
- WhatJobs: `listing = BoardWhatJobsListing.find(listing_id)` (`stripe_webhook_handler_job.rb:251`) — raises on missing id
- Both wrap in guard: `if listing&.present?`

**Current code:**
- One-off branch: `purchase = OrganizationAiCreditPurchase.find_by(id: purchase_id)` (`stripe_webhook_handler_job.rb:216`)
- Guarded: `if purchase&.present?` (`stripe_webhook_handler_job.rb:218`)

**Issue:** `.find_by(id:)` returns nil silently; `.find` raises on missing id (fails fast). The guard itself matches the analog; only the lookup method differs.

**Recommendation:** Change to `.find(purchase_id)` to match analog fail-fast semantics. If the purchase doesn't exist, the webhook should raise (and retry), not silently skip.

---

## Sanctioned & Whitelisted Items (Not Deviations)

1. **Confirm modal** — sanctioned EXTRA UI pattern not in analog
2. **Price-model divergence** — whitelisted: checkout uses `Stripe::Price.list` + `line_items: [{ price: price.id }]` vs analog's inline `price_data`
3. **Frontend invalidation target** — whitelisted: `["organizationAiCreditBalance"]` vs analog's `["jobs", data.id]` (different product domain)

---

## Verdict

After excluding sanctioned items and whitelisted deviations, the current code is **structurally faithful to the ANALOG** with one actionable fix: webhook lookup method.
