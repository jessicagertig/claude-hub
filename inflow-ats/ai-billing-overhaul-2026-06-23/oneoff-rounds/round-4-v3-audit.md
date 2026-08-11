# One-Off Purchase — Round 4 Audit (v3)

Confirmed. Comparing the three metadata blocks:

- ANALOG WWR `payment_intent_data.metadata`: `{ board_wwr_listing_id, organization_id, job_id }` → OURS: `{ organization_ai_credit_purchase_id, organization_id }` (job_id has no analog, forced). MATCH.
- ANALOG WWR `invoice_creation.invoice_data.metadata`: `{ board_wwr_listing_id, job_id }` → OURS: `{ organization_ai_credit_purchase_id }` (job_id has no analog, forced). MATCH.
- ANALOG WWR top-level `metadata`: `{ board_wwr_listing_id, organization_id, job_id }` → OURS: `{ organization_ai_credit_purchase_id, organization_id }` (job_id has no analog, forced). MATCH.

The metadata shapes match the analog (record-id key + organization_id, minus the job-scoped `job_id` which has no org-scoped equivalent). No deviation.

I have completed the full structural comparison. Here is my final report.

---

## Structural audit: AI credit one-off purchase vs WWR/WhatJobs analog

**Files traced:** `oneoff-purchase-trace.md` (ANALOG spec) → current code [`organization_ai_credit_purchases_controller.rb`, `organization_ai_credit_purchase.rb`, `stripe_webhook_handler_job.rb`, `apply_ai_credit_purchase.rb`, `AiCreditSubscription.tsx`, `useOrganizationAiCreditPurchase.ts`, `AiCreditPackCard.tsx`, `PurchaseAiCreditTopUpConfirmModal.tsx`, `config/routes.rb`, `organization_ai_credit_purchase_policy.rb`, `organization_ai_credit_purchase_serializer.rb`] ↔ analog code [`board_wwr_listings_controller.rb`, `board_wwr_listing.rb`, `board_what_jobs_listings_controller.rb`, `board_what_jobs_listing.rb`, `useJob.ts`, `useWwrListing.ts`, `useWhatJobsListing.ts`, `JobDistributionWeWorkRemotely.tsx`, `WhatJobsSidebarActions.tsx`, `board_wwr_listing_policy.rb`, `billing_policy.rb`, `paid_wwr_listing_created_job.rb`, `paid_ai_credit_pack_purchased_job.rb`].

**Reviewing the working tree (uncommitted).** The entire one-off flow is uncommitted on branch `billing-bonanza` (per `git status`: controller, interactor, webhook, hooks, model, routes, serializer all `M`/`MM`; modal `A`; notification job `??`). This is the code under review.

### Finding: NO unsanctioned, non-whitelisted structural deviations remain.

The current working-tree code is structurally faithful to the analog. It has been refactored AWAY from the trace's stale "OURS" skeleton (which described a single `purchase_top_up` action with `charge_default_payment_method` and an `ai_credit_pack_top_up == 'true'` webhook gate) INTO the analog's actual two-action shape:

- **Two controller actions** mirroring the analog's split: `charge_top_up` (= WWR `#create` direct-charge: build → `authorize <record>` → `save` → model `charge_for_purchase` → `render_one` → `rescue StandardError` → "Unable to process payment") and `create_top_up_checkout_session` (= WWR `#create_checkout_session`: `authorize :billing, :checkout?` → flat params → pre-create record with `stripe_invoice_paid: false` → `Stripe::Checkout::Session.create` mode `payment` → `render json: { url:, sessionId: }, status: :created` → `rescue Stripe::StripeError` → `{ error: }`, :unprocessable_entity). Controller at organization_ai_credit_purchases_controller.rb:75-184.
- **Two frontend hooks** (`useChargeAiCreditTopUp` invalidating `["organizationAiCreditBalance"]`; `useCreateAiCreditTopUpCheckoutSession` with no invalidation) and **two handlers** (`handleCreateTopUpDirectCharge`, `handleCreateTopUpCheckoutSession` → `window.location.href = data.url`), mirroring `createBoardWwrListing`/`createWwrCheckoutSession` and the WhatJobs pair. useOrganizationAiCreditPurchase.ts:97-131; AiCreditSubscription.tsx:158-219.
- **Flat (unwrapped) checkout params** (`checkout_top_up_params = params.permit(:stripe_price_lookup_key)`, controller:447-449) matching WWR `checkout_listing_params` (no `require` wrapper); direct-charge keeps the wrapper (`organization_ai_credit_purchase_params`, controller:439-441) matching WWR `listing_params`.
- **Model `charge_for_purchase`** (organization_ai_credit_purchase.rb:131-168) matches `BoardWwrListing#charge_for_listing`: double-charge guard → `stripe_customer_id.blank?` guard → `InvoiceItem.create` (`amount:`/`currency:`/`description:`/record-id metadata) → `Invoice.create` (`collection_method: 'charge_automatically'`/`description:`/record-id metadata) → `Invoice.pay` → `update_columns(stripe_invoice_id, stripe_invoice_item_id, stripe_amount, ...)`.
- **Webhook one-off branch** (stripe_webhook_handler_job.rb:212-232) matches the WWR branch shape: record-id-metadata gate (`organization_ai_credit_purchase_id.present?` ↔ `board_wwr_listing_id.present?`) → `find_by(id:)` → `purchase.finalize_stripe_payment` (handler choke-point, ↔ `listing.finalize_stripe_payment`) → invoke produce-the-result unit (`ApplyAiCreditPurchase.call` ↔ `listing.create_on_wwr`) → `return`.
- **Produce-the-result tail**: grant-once guard + `broadcast_event` + `broadcast_show_growl` + `Notification::PaidAiCreditPackPurchasedJob.perform_later` (apply_ai_credit_purchase.rb:47,81 + organization_ai_credit_purchase.rb:181-185) mirrors `create_on_wwr`'s produce-once guard + `broadcast_event('wwr_listing_published')` + `broadcast_show_growl('Created WWR Listing')` + `Notification::PaidWwrListingCreatedJob.perform_later` (board_wwr_listing.rb:186-196).
- **Checkout metadata** (three blocks at controller:154-172): `payment_intent_data.metadata` and top-level `metadata` carry `{ record-id, organization_id }`; `invoice_creation.invoice_data.metadata` carries `{ record-id }` — matching the analog's `{ board_wwr_listing_id, organization_id, job_id }` / `{ board_wwr_listing_id, job_id }` minus the job-scoped `job_id`, which has no org-scoped analog (forced, not a deviation).
- **Button prop replication**: `AiCreditPackCard` passes `disabled={isLoading} loading={isLoading}` to its buy button (AiCreditPackCard.tsx:38-39), satisfying the analog prop-replication rule.

### Items intentionally NOT flagged

- **Sanctioned:** `PurchaseAiCreditTopUpConfirmModal` (EXTRA, requested); `OrganizationAiCreditPurchase` record as source instead of Organization columns; `ai_credit_*` descriptor naming.
- **Whitelisted:** double-charge guard 2nd predicate `stripe_invoice_paid?` vs `is_active?`/`live?`; no `after_update` charge callback; checkout/charge using `price: price.id` vs inline `price_data`/`unit_amount` (price lives only in Stripe); direct-charge invalidation keyed `["organizationAiCreditBalance"]` vs analog `["jobs", data.id]`; grant-once guard at apply_ai_credit_purchase.rb:47; `redirectUrl` on the subscription/portal actions; spec-suite + `db/schema.rb` staleness from the surrounding mid-refactor (schema.rb still shows `amount_cents_paid` and lacks `stripe_invoice_item_id`/`stripe_invoice_paid`/`last_updated_by_organization_user_id`, all added by migrations `20260611120002`/`20260611120003`).
