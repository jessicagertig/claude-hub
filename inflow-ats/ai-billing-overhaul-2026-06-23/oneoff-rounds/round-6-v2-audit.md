# One-Off Purchase — Round 6 Audit (v2)

I now have complete coverage of both analog paths and our implementation. I have traced every identifier through both the analog and our code. Let me compile the structural deviations.

Chain traced:
- ANALOG WWR: `JobDistributionWeWorkRemotely.tsx` → `useJob.ts`/`useWwrListing.ts` → `board_wwr_listings_controller.rb` → `board_wwr_listing.rb` → `stripe_webhook_handler_job.rb`
- ANALOG WhatJobs: `WhatJobsSidebarActions.tsx` → `useWhatJobsListing.ts` → `board_what_jobs_listings_controller.rb` → `board_what_jobs_listing.rb` → webhook
- OURS: `AiCreditSubscription.tsx` → `useOrganizationAiCreditPurchase.ts` → `organization_ai_credit_purchases_controller.rb` → `organization_ai_credit_purchase.rb` → `apply_ai_credit_purchase.rb` → webhook

After tracing both analogs (WWR primary, WhatJobs secondary) and our current code end-to-end, the current working tree has been refactored into a two-action structure (`charge_top_up` + `create_top_up_checkout_session`) that closely mirrors the analog's `create` + `create_checkout_session` split. Most of the earlier deviations have been resolved or fall under sanctioned/whitelisted items.

## Findings

Applying the sanctioned-deviation list and all 11 whitelist items to the current working tree:

**No remaining actionable structural deviations.**

The current working tree (`inflow-ats.billing-bonanza`) has been refactored from the single-action shape into a two-action shape that structurally mirrors the analog:

- `charge_top_up` (organization_ai_credit_purchases_controller.rb:75) mirrors `BoardWwrListingsController#create`: pre-create record with `last_updated_by_organization_user` (controller:96), `authorize purchase` (controller:99) → `OrganizationAiCreditPurchasePolicy#create?` → `is_org_admin?` (matching `authorize @listing` → `BoardWwrListingPolicy#create?` → `is_org_admin?`), `purchase.save` then `purchase.charge_for_purchase` (controller:107), `render_one(...Serializer)` (controller:108), `rescue StandardError` → `render_general_errors(["Unable to process payment: #{e.message}"])` (controller:112-114) — identical to board_wwr_listings_controller.rb:5-31.

- `create_top_up_checkout_session` (controller:123) mirrors `#create_checkout_session`: `authorize :billing, :checkout?` (controller:124), unwrapped params via `checkout_top_up_params` (controller:447-449, mirroring `checkout_listing_params` board_wwr_listings_controller.rb:137-139), pre-create with `stripe_invoice_paid: false` (controller:146), `Stripe::Checkout::Session.create` with three metadata blocks (controller:150-175), `render json: { url:, sessionId: }, status: :created` (controller:177), `rescue Stripe::StripeError` → `render json: { error: e.message }, status: :unprocessable_entity` (controller:181-183) — identical to board_wwr_listings_controller.rb:51-128.

- `charge_for_purchase` (organization_ai_credit_purchase.rb:131) mirrors `charge_for_listing`: double-charge guard (whitelisted predicate), customer-blank guard, InvoiceItem→Invoice→pay→`update_columns(stripe_invoice_id:, stripe_invoice_item_id:, stripe_amount:, currency:)` (organization_ai_credit_purchase.rb:165) — matches board_wwr_listing.rb:158.

- Webhook one-off branch (stripe_webhook_handler_job.rb:212-232) mirrors the WWR branch: record-id metadata key, `finalize_stripe_payment` then business-work (`ApplyAiCreditPurchase` standing in for `create_on_wwr`), early `return`.

- Frontend: `useChargeAiCreditTopUp` (useOrganizationAiCreditPurchase.ts:107, wrapped payload) mirrors `createBoardWwrListing`; `useCreateAiCreditTopUpCheckoutSession` (useOrganizationAiCreditPurchase.ts:129, unwrapped payload) mirrors `createWwrCheckoutSession`; `handleCreateTopUpDirectCharge`/`handleCreateTopUpCheckoutSession` (AiCreditSubscription.tsx:158, 180) mirror `handleCreateBoardWwrListing`/`handleCreateCheckoutSession`, with `window.location.href = data.url` on the checkout path (AiCreditSubscription.tsx:188).

Every divergence located falls under either the sanctioned list or one of the 11 whitelist items (notably: `price: price.id` vs inline `price_data` = whitelist 8; double-charge 2nd predicate `stripe_invoice_paid?` = whitelist 1/7; direct-charge invalidation `["organizationAiCreditBalance"]` = whitelist 9; no `after_update` charge callback = whitelist 6; grant-once guard = whitelist 5; `redirectUrl` subscription reads = whitelist 2; spec/schema.rb staleness = whitelist 4).

## Files Traced

- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/models/organization_ai_credit_purchase.rb`
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/interactors/apply_ai_credit_purchase.rb`
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/jobs/stripe_webhook_handler_job.rb`
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts`
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`
- Analog: `board_wwr_listings_controller.rb`, `board_wwr_listing.rb`, `board_what_jobs_listings_controller.rb`, `board_what_jobs_listing.rb`, `useJob.ts`, `useWwrListing.ts`, `useWhatJobsListing.ts`, `JobDistributionWeWorkRemotely.tsx`, `WhatJobsSidebarActions.tsx`

## Note on Serializer Usage

The frontend's `useChargeAiCreditTopUp` onSuccess ignores the response body and only invalidates `["organizationAiCreditBalance"]` (useOrganizationAiCreditPurchase.ts:110-112), and `handleCreateTopUpDirectCharge` onSuccess inspects no response fields (AiCreditSubscription.tsx:162). The direct-charge controller returns a serialized purchase record via `render_one(purchase, ...Serializer)` (controller:108), exactly matching the WWR analog's `render_one(@listing, ...Serializer)` (board_wwr_listings_controller.rb:23). This is faithful to the analog, which also discards the serialized body on the direct-charge onSuccess (JobDistributionWeWorkRemotely.tsx:269-272). Returning a serialized body the frontend ignores is mirrored in the analog, so it is not a deviation.
