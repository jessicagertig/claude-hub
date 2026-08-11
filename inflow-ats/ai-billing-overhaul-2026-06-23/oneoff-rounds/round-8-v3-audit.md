# One-Off Purchase — Round 8 Audit (v3)

## Complete Structural Trace

**Chain traced:**
`AiCreditSubscription.tsx` → `useOrganizationAiCreditPurchase.ts` → `organization_ai_credit_purchases_controller.rb` (`charge_top_up`, `create_top_up_checkout_session`) → `organization_ai_credit_purchase.rb` (`charge_for_purchase`, `finalize_stripe_payment`, `broadcast_purchase_complete`) → `stripe_webhook_handler_job.rb` (invoice.paid AI branch) → `apply_ai_credit_purchase.rb` (`apply_one_off`) → `organization_ai_credit_purchase_policy.rb` → `billing_policy.rb`, diffed against `JobDistributionWeWorkRemotely.tsx`/`WhatJobsSidebarActions.tsx` → `useJob.ts`/`useWwrListing.ts`/`useWhatJobsListing.ts` → `board_wwr_listings_controller.rb`/`board_what_jobs_listings_controller.rb` → `board_wwr_listing.rb`/`board_what_jobs_listing.rb` → webhook WWR/WhatJobs branches → `board_wwr_listing_policy.rb`.

## Context: Recent Refactor

The current working-tree code has been refactored into two controller actions (`charge_top_up` + `create_top_up_checkout_session`) that structurally mirror the analog's two-action shape (`#create` + `#create_checkout_session`). This is a substantial change from the trace's stale "OURS" section (which described a single `purchase_top_up` action using `price: price.id` in the direct-charge InvoiceItem).

Key refactor confirmations:
- Current direct-charge `charge_for_purchase` now uses `amount: amount` (not `price: price.id`) — **matches analog.**
- Controller uses `authorize purchase` (OrganizationAiCreditPurchasePolicy#create?) — **matches analog's `authorize @listing`.**
- Direct-charge build does not set `stripe_invoice_paid: false` — **matches analog.**
- Checkout build does set `stripe_invoice_paid: false` — **matches analog.**
- Invoice/InvoiceItem metadata is record-id-keyed — **matches analog.**
- Double-charge guard uses `stripe_invoice_id.present? && stripe_invoice_paid?` — **whitelisted deviation from analog's `is_active?` (sanctioned per spec review).**

The vast majority of the structure now matches.

## Genuine Remaining Deviations

After excluding sanctioned deviations and whitelisted items, here are the real differences:

---

### DEVIATION: No logging in the direct-charge model method

**ANALOG:**
- `BoardWwrListing#charge_for_listing` logs throughout:
  - `Rails.logger.info 'Attempt to charge for WWR Listing'` (board_wwr_listing.rb:114)
  - `ap` in the double-charge guard (board_wwr_listing.rb:116-117)
  - `Rails.logger.info 'Charging...'` (board_wwr_listing.rb:128)
  - `Rails.logger.info 'Invoice Has Been Finalized'` + payload (board_wwr_listing.rb:160-161)
- `BoardWhatJobsListing#charge_for_listing` mirrors:
  - `ap 'Attempt to charge for WhatJobs Listing'` (board_what_jobs_listing.rb:158)
  - `ap 'Already charged for this listing'` (board_what_jobs_listing.rb:161)
  - `ap 'Charging...'` (board_what_jobs_listing.rb:170)
  - `ap 'Invoice Has Been Finalized'` (board_what_jobs_listing.rb:195)

**OURS:**
- `OrganizationAiCreditPurchase#charge_for_purchase` (organization_ai_credit_purchase.rb:131-168) emits no log lines at any point.

---

### DEVIATION: Webhook one-off branch threads invoice amount/currency into the grant unit; the interactor then backfills `stripe_amount`/`currency`

**ANALOG:**
- The `invoice.paid` WWR branch calls `listing.finalize_stripe_payment` then `listing.create_on_wwr` (stripe_webhook_handler_job.rb:241-242) and passes **no** invoice amount.
- `create_on_wwr` (board_wwr_listing.rb:173-200) never writes `stripe_amount` or `currency` — those were stamped at charge time by `update_columns(..., stripe_amount: amount)` (board_wwr_listing.rb:158).
- WhatJobs identical: webhook calls `finalize_stripe_payment` + `create_on_what_jobs` (stripe_webhook_handler_job.rb:254-260) with no amount; no backfill in `create_on_what_jobs` (board_what_jobs_listing.rb:204-209).

**OURS:**
- The `invoice.paid` AI branch passes `amount_cents: object.amount_paid, currency: object.currency` into `ApplyAiCreditPurchase.call` (stripe_webhook_handler_job.rb:224-229).
- `apply_one_off` backfills `existing.update(stripe_amount: context.amount_cents, currency: context.currency || existing.currency)` when `existing.stripe_amount.to_i.zero?` (apply_ai_credit_purchase.rb:52-54).

**Notes:**
- For the direct-charge path this backfill is a no-op (charge_for_purchase already stamped `stripe_amount` at organization_ai_credit_purchase.rb:165).
- The amount/currency plumbing through the webhook + interactor has no analog counterpart.
- This traces to the sanctioned "price lives in Stripe, record pre-created with `stripe_amount: 0`" divergence — surfaced per the rule against rationalizing analog deviations.

---

## Everything Else Now Matches the Analog

Including:
- Two-action split (direct charge + checkout session)
- Direct-charge action: uses `authorize purchase`/`render_one(...Serializer)`/`rescue StandardError => "Unable to process payment: #{e.message}"` (organization_ai_credit_purchases_controller.rb:92-107 ↔ board_wwr_listings_controller.rb:19-30)
- Checkout action: uses `authorize :billing, :checkout?`, flat (unwrapped) params, `{ url:, sessionId: }` response, `rescue Stripe::StripeError → { error: }, :unprocessable_entity` (organization_ai_credit_purchases_controller.rb:117-184 ↔ board_wwr_listings_controller.rb:51-128)
- Direct-charge InvoiceItem uses `amount:`+`currency:`+`description:` (organization_ai_credit_purchase.rb:144-152 ↔ board_wwr_listing.rb:130-138)
- `update_columns(stripe_invoice_id:, stripe_invoice_item_id:, stripe_amount:)` (organization_ai_credit_purchase.rb:165 ↔ board_wwr_listing.rb:158)
- Webhook `finalize_stripe_payment`-then-grant ordering with grant-unit-owned signaling after a produce-once/grant-once guard (apply_ai_credit_purchase.rb:47,81 ↔ board_wwr_listing.rb:174,193-196)
- Frontend direct-charge onSuccess inspects no response fields and checkout onSuccess does `window.location.href = data.url` (AiCreditSubscription.tsx:162-168,188 ↔ JobDistributionWeWorkRemotely.tsx:269-272,339; WhatJobsSidebarActions.tsx:101-113,144)
- `last_updated_by_organization_user` stamped on both paths (organization_ai_credit_purchases_controller.rb:89,140 ↔ board_wwr_listings_controller.rb:11,60)
- Notification jobs: `Notification::PaidAiCreditPackPurchasedJob` and `Notification::PaidWwrListingCreatedJob` exist and fire from the completion tail

