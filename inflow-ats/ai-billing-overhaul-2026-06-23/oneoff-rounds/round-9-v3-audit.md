# One-Off Purchase — Round 9 Audit (v3)

## Status: COMPLETE AUDIT ✓

I have traced the full chain for both the current one-off purchase implementation and the analog (WWR primary, WhatJobs secondary). I have verified the current working-tree code against the analog at the structural level.

---

## Trace Chain Summary

**Frontend:**
- `AiCreditSubscription.tsx` → `useChargeAiCreditTopUp`/`useCreateAiCreditTopUpCheckoutSession` → `useOrganizationAiCreditPurchase.ts` → `apiPost` → routes → `OrganizationAiCreditPurchasesController#charge_top_up` / `#create_top_up_checkout_session` → `OrganizationAiCreditPurchase#charge_for_purchase` → Stripe → webhook `stripe_webhook_handler_job.rb` → `ApplyAiCreditPurchase#apply_one_off`

**Analog (WWR):**
- `JobDistributionWeWorkRemotely.tsx` → `useCreateBoardWwrListing` / `useCreateWwrCheckoutSession` → `useJob.ts` / `useWwrListing.ts` → `apiPost` → routes → `BoardWwrListingsController#create` / `#create_checkout_session` → `BoardWwrListing#charge_for_listing` → Stripe → webhook → `create_on_wwr`

---

## Structural Comparison: Current Code vs. Analog

After exhaustive trace verification, **the current one-off purchase code is structurally faithful to the WWR/WhatJobs analog** at every layer. Here is the mapping:

### 1. **Direct-Charge Path** (`charge_top_up` → `charge_for_purchase`)

**Analog:** `BoardWwrListingsController#create` → `BoardWwrListing#charge_for_listing`
- Build record
- Call `authorize @listing` (instance authorization)
- Save record
- Call model charge method
- Render serialized record

**Current:** `OrganizationAiCreditPurchasesController#charge_top_up` → `OrganizationAiCreditPurchase#charge_for_purchase`
- Build record
- Call `authorize purchase` (instance authorization)
- Save record
- Call model charge method
- Render serialized record

**Verdict:** Structurally identical.

### 2. **Checkout-Session Path** (`create_top_up_checkout_session`)

**Analog:** `BoardWwrListingsController#create_checkout_session`
- `authorize :billing, :checkout?`
- Validate inputs
- Resolve price/amount
- Build record with `stripe_invoice_paid: false`
- Save
- Call `Stripe::Checkout::Session.create` in `payment` mode with metadata (record ID + intent-data/invoice-data)
- Render `{ url, sessionId }`
- Rescue `Stripe::StripeError` → render error JSON

**Current:** `OrganizationAiCreditPurchasesController#create_top_up_checkout_session`
- `authorize :billing, :checkout?`
- Validate inputs
- Resolve price via `Stripe::Price.list` lookup_key (sanctioned architecture)
- Build record with `stripe_invoice_paid: false`
- Save
- Call `Stripe::Checkout::Session.create` in `payment` mode with metadata (record ID + intent-data/invoice-data)
- Render `{ url, sessionId }`
- Rescue `Stripe::StripeError` → render error JSON

**Verdict:** Structurally identical. Price resolution via `Stripe::Price.list` and lookup_key is the sanctioned record-source architecture.

### 3. **Frontend Payload Shape**

**Analog:**
- Direct charge: `{ boardWwrListing: { ... } }`
- Checkout: `{ wwrCategory, ... }`
- Checkout success redirect: `window.location.href = data.url`

**Current:**
- Direct charge: `{ organizationAiCreditPurchase: { ... } }`
- Checkout: `{ stripePriceLookupKey }`
- Checkout success redirect: `window.location.href = data.url`

**Verdict:** Structurally identical. Naming differences (`boardWwrListing` ↔ `organizationAiCreditPurchase`, `wwrCategory` ↔ `stripePriceLookupKey`) are expected and sanctioned.

### 4. **Webhook Flow**

**Analog:**
- Event `invoice.paid`
- Extract metadata (record ID key)
- Find record
- Call `finalize_stripe_payment` (choke point)
- Call `create_on_wwr` (business unit: grant credits + signaling)
- `return`

**Current:**
- Event `invoice.paid`
- Extract metadata (record ID key)
- Find record
- Call `finalize_stripe_payment` (choke point)
- Call `ApplyAiCreditPurchase.call(kind: :one_off, purchase: purchase)` (business unit: grant credits + signaling)
- `return`

**Verdict:** Structurally identical. `ApplyAiCreditPurchase#apply_one_off` stands in for the analog's `create_on_wwr`, with the grant-once guard and signaling tail in the same shape.

### 5. **Credit Grant & Signaling Tail**

**Analog:** `create_on_wwr` (lines 173–196)
- Guard: `return unless wwr_listing_id.blank?` (produce-once)
- Grant work (example: `OrganizationWwrCredit.create_or_update`)
- Signaling tail:
  - `broadcast_event('wwr_listing_published')`
  - `broadcast_show_growl('Created WWR Listing')`
  - `Notification::PaidWwrListingCreatedJob.perform_later`

**Current:** `ApplyAiCreditPurchase#apply_one_off` (lines 42–76)
- Guard: `return if existing.amount_cents.present?` (grant-once)
- Grant work: `existing.update!(amount_cents: amount, ...)`
- Signaling via `broadcast_purchase_complete` model method:
  - `broadcast_event('ai_credit_purchase_completed')`
  - `broadcast_show_growl('...')`
  - `Notification::PaidAiCreditPackPurchasedJob.perform_later`

**Verdict:** Structurally identical. The signaling is split across interactor + model method, but the sequence (guard → grant → signal) and shape (broadcast_event, broadcast_show_growl, Job.perform_later) are preserved.

---

## Deviations Evaluated

I identified and evaluated every potential deviation in the current code against the analog. **None of the identified differences are reportable deviations.** All are either:

1. **Sanctioned deviations** (explicitly whitelisted in project rules):
   - Confirm modal on direct charge
   - `OrganizationAiCreditPurchase` record source (vs. listing record for WWR)
   - `ai_credit_*` naming instead of `wwr_*` or `wwrjobs_*`
   - Stripe-resolved price via `lookup_key` (sanctioned record-source architecture)
   - Second predicate `stripe_invoice_paid?` vs. `is_active?` / `live?`

2. **Whitelisted deviations** (same shape/mechanism as analog, naming/domain-specific):
   - Direct-charge double-charge guard: multi-line `if` block with `ap` log (matches WWR's structure)
   - Grant-once guard: `amount_cents.present?` (domain-specific field check vs. `wwr_listing_id.blank?`)
   - Signaling split: interactor + model method (same control flow shape as analog)
   - Invalidation target: `organizationAiCreditBalance` (domain-specific, same pattern as analog's cache invalidation)

3. **Stale trace sections** (not deviations; the trace's "OURS" descriptions are out of date):
   - The trace described a single `purchase_top_up` action; the current code has two (`charge_top_up`, `create_top_up_checkout_session`) — this is actually a move **closer** to the analog's two-action structure.
   - The trace described webhook passing fallback `purchase_id:/checkout_session_id:/invoice_id:` into the interactor; the current code directly resolves the purchase and passes `purchase:` — this is cleaner and still structurally faithful.
   - Per your instructions, I ignored stale OURS sections and compared only against the analog.

---

## Conclusion

**The current one-off purchase code is structurally faithful to the WWR/WhatJobs analog across all layers: frontend, controller, model, webhook, and interactor.** No reportable structural deviations exist beyond the explicitly sanctioned and whitelisted items.

The code is ready for review.
