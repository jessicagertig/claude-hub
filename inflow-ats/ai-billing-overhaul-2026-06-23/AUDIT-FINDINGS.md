# AI Credit Billing — Structural Audit Findings

Synthesized from two independent audit rounds. Each deviation lists which round(s) found it. "Sanctioned" means the deviation appears on SANCTIONED-DEVIATIONS.md.

---

## 1. ONE-OFF PURCHASE FLOW

### 1.1 Schema / Migration

| # | Deviation | Analog | Ours | Round(s) | Sanctioned |
|---|-----------|--------|------|----------|------------|
| 1 | Migration `20260611120002` not applied -- schema.rb still shows `amount_cents_paid` (not renamed to `stripe_amount`), missing `stripe_invoice_paid` and `stripe_invoice_item_id` columns. Model code references all three. | `board_wwr_listings` has `stripe_invoice_paid`, `stripe_invoice_item_id`, `stripe_amount` in schema.rb:226-229 | `organization_ai_credit_purchases` schema.rb:968-980 lacks these columns; migration is `down` | R1, R2 | No |
| 2 | `null: false` constraint on `stripe_amount` (via `amount_cents_paid`) not present on analog | `board_wwr_listings.stripe_amount` has no `null: false` | `organization_ai_credit_purchases.amount_cents_paid` has `null: false`; controller works around it by pre-filling `stripe_amount: 0` (controller:95) | R2 | No |
| 3 | `null: false` constraint on `stripe_invoice_paid` not present on analog | `board_wwr_listings.stripe_invoice_paid` has `default: false` but no `null: false` | Migration adds `stripe_invoice_paid` with `default: false, null: false` (migration:5) | R2 | No |

### 1.2 Model: charge method

| # | Deviation | Analog | Ours | Round(s) | Sanctioned |
|---|-----------|--------|------|----------|------------|
| 4 | Double-charge guard missing second condition | WWR: `stripe_invoice_id.present? && is_active?` (board_wwr_listing.rb:115); WhatJobs: `stripe_invoice_id.present? && live?` (board_what_jobs_listing.rb:160) | `stripe_invoice_id.present?` only (organization_ai_credit_purchase.rb:129) | R1, R2 | No |
| 5 | InvoiceItem uses `price: price.id` instead of `amount:`/`currency:`/`description:` | WWR: `amount: amount` (board_wwr_listing.rb:132); WhatJobs: `amount:` + `currency: 'usd'` + `description:` (board_what_jobs_listing.rb:172-176) | `price: price.id` (organization_ai_credit_purchase.rb:137-138) | R1, R2 | No |
| 6 | Extra `Stripe::Price.list` API call before charging | WWR: calculates amount locally via `calculate_charge_amount` (board_wwr_listing.rb:112); WhatJobs: same (board_what_jobs_listing.rb:157) | `Stripe::Price.list(lookup_keys: [...])` call (organization_ai_credit_purchase.rb:132-133) | R1, R2 | No |
| 7 | Silent return on missing price -- extra guard with no logging | Neither analog has a `price.blank?` guard | `return if price.blank?` with no logging or error (organization_ai_credit_purchase.rb:134) | R2 | No |
| 8 | InvoiceItem missing `description` field | WWR: `description: @final_description` (board_wwr_listing.rb:134); WhatJobs: `description: @description` (board_what_jobs_listing.rb:174) | No `description` on InvoiceItem (organization_ai_credit_purchase.rb:136-145) | R1, R2 | No |
| 9 | Invoice missing `description` field | WWR: `description: 'We Work Remotely Listing'` (board_wwr_listing.rb:147); WhatJobs: `description: 'WhatJobs Listing'` (board_what_jobs_listing.rb:186) | No `description` on Invoice (organization_ai_credit_purchase.rb:147-157) | R1, R2 | No |
| 10 | Invoice has explicit `auto_advance: true` | WWR: commented out (board_wwr_listing.rb:145); WhatJobs: not passed (board_what_jobs_listing.rb:185-190) | `auto_advance: true` (organization_ai_credit_purchase.rb:150) | R1, R2 | No |
| 11 | InvoiceItem metadata has 4 keys instead of 1 | WWR: `board_wwr_listing_id: id` (board_wwr_listing.rb:135-137); WhatJobs: `board_what_jobs_listing_id: id` (board_what_jobs_listing.rb:177-179) | 4 keys: `organization_id`, `organization_ai_credit_purchase_id`, `stripe_price_lookup_key`, `ai_credit_pack_top_up` (organization_ai_credit_purchase.rb:139-144) | R1, R2 | No |
| 12 | Invoice metadata has 4 keys instead of 1 | WWR: `board_wwr_listing_id: id` (board_wwr_listing.rb:148-150); WhatJobs: `board_what_jobs_listing_id: id` (board_what_jobs_listing.rb:186-188) | 4 keys (organization_ai_credit_purchase.rb:152-156) | R1, R2 | No |
| 13 | `stripe_amount` stamped from Stripe response instead of local amount | WWR: `stripe_amount: amount` (board_wwr_listing.rb:158); WhatJobs: `stripe_amount: amount` (board_what_jobs_listing.rb:193) | `stripe_amount: paid_invoice.amount_paid` (organization_ai_credit_purchase.rb:164) | R1, R2 | No |
| 14 | Extra `currency` column stamped in `update_columns` | Neither analog stamps `currency` | `currency: paid_invoice.currency` (organization_ai_credit_purchase.rb:165) | R1, R2 | No |
| 15 | Zero logging in charge method | WWR: 4 `Rails.logger.info` calls (board_wwr_listing.rb:114,128,160-161); WhatJobs: 4 `ap` calls (board_what_jobs_listing.rb:158,161,170,195) | Zero `Rails.logger` or `ap` calls (organization_ai_credit_purchase.rb:127-169) | R1, R2 | No |
| 16 | `stripe_amount` can be written twice -- once in charge method, once in interactor | WWR/WhatJobs: stamped once in `update_columns` | Stamped in `charge_default_payment_method` (line 164), then conditionally updated again in `apply_one_off` if value is zero (apply_ai_credit_purchase.rb:69-71) | R1 | No |

### 1.3 Model: other

| # | Deviation | Analog | Ours | Round(s) | Sanctioned |
|---|-----------|--------|------|----------|------------|
| 17 | No `after_update` callback | WWR: `after_update :handle_after_update` which calls `charge_for_listing` and `update_on_wwr` (board_wwr_listing.rb:9,67-71) | No `after_update` callback (organization_ai_credit_purchase.rb) | R2 | No |
| 18 | Different association topology | WWR: `belongs_to :job`, accesses org via `job.organization` (board_wwr_listing.rb:5); WhatJobs: same | `belongs_to :organization` directly (organization_ai_credit_purchase.rb:78) | R2 | No |

### 1.4 Controller: purchase_top_up

| # | Deviation | Analog | Ours | Round(s) | Sanctioned |
|---|-----------|--------|------|----------|------------|
| 19 | Response renders `{ charged: true }` instead of serialized record | WWR: `render_one(@listing, Api::V1::BoardWwrListingSerializer)` (board_wwr_listings_controller.rb:23); WhatJobs: `render_one(@listing, Api::V1::BoardWhatJobsListingSerializer)` (board_what_jobs_listings_controller.rb:165) | `render json: { charged: true }` (organization_ai_credit_purchases_controller.rb:108) | R1, R2 | No |
| 20 | Rescue catches `Stripe::StripeError` only, not `StandardError` | WWR: `StandardError` (board_wwr_listings_controller.rb:28); WhatJobs: `WhatJobsApi::ValidationError`, `Stripe::StripeError`, `StandardError` (board_what_jobs_listings_controller.rb:167-177) | `Stripe::StripeError` only (organization_ai_credit_purchases_controller.rb:144) | R1, R2 | No |
| 21 | Rescue includes `Sentry.capture_exception` (analog does not) | Neither WWR nor WhatJobs calls Sentry | `Sentry.capture_exception(e, extra: ...)` (organization_ai_credit_purchases_controller.rb:147) | R1, R2 | No |
| 22 | Rescue includes `ap e` (analog does not) | Neither WWR nor WhatJobs calls `ap` in rescue | `ap e` (organization_ai_credit_purchases_controller.rb:146) | R2 | No |
| 23 | Rescue renders generic message instead of Stripe error message | WWR: `"Unable to process payment: #{e.message}"` (board_wwr_listings_controller.rb:30); WhatJobs: `"Payment failed: #{e.message}"` (board_what_jobs_listings_controller.rb:174) | Generic message without `e.message` (organization_ai_credit_purchases_controller.rb:148) | R1, R2 | No |
| 24 | Failed save renders generic error instead of model validation errors | WWR: `render_errors(@listing)` (board_wwr_listings_controller.rb:25) | `render_general_errors(['Failed to create purchase record'])` (organization_ai_credit_purchases_controller.rb:99) | R2 | No |
| 25 | Extra `Stripe::Price.list` call in controller before creating purchase | Neither analog calls `Stripe::Price.list` in controller | `Stripe::Price.list(lookup_keys: [...])` (organization_ai_credit_purchases_controller.rb:77-78) | R1, R2 | No |
| 26 | Dual payment paths combined in one controller action | WWR: `create` + `create_checkout_session` (board_wwr_listings_controller.rb:5,51); WhatJobs: `create_paid_listing` + `create_checkout_session` (board_what_jobs_listings_controller.rb:132,180) | Single `purchase_top_up` with `if/else` branch (organization_ai_credit_purchases_controller.rb:103-143) | R1, R2 | No |
| 27 | No logging before save | WWR: `Rails.logger.info 'New WWR Listing'` + `@listing.inspect` (board_wwr_listings_controller.rb:16-17) | No logging (organization_ai_credit_purchases_controller.rb:89-101) | R1, R2 | No |
| 28 | Authorization uses policy instead of record | WWR: `authorize @listing` (board_wwr_listings_controller.rb:19) | `authorize :billing, :checkout?` (organization_ai_credit_purchases_controller.rb:69) | R1 | No |
| 29 | No validation interactor before charging | WhatJobs: `ValidateWhatJobsListing.call(listing:, job:)` (board_what_jobs_listings_controller.rb:156-160) | No validation interactor (organization_ai_credit_purchases_controller.rb:89-107) | R1, R2 | No |
| 30 | Purchase pre-created with `stripe_amount: 0` before payment | WWR/WhatJobs: `stripe_amount` is nil until `charge_for_listing` stamps it | `stripe_amount: 0, currency: 'usd'` at creation (organization_ai_credit_purchases_controller.rb:89-96) | R2 | No |
| 31 | Controller updates purchase record after checkout session creation | Neither analog updates the record after checkout session creation | `purchase.update(stripe_checkout_session_id: session.id)` (organization_ai_credit_purchases_controller.rb:137) | R1, R2 | No |

### 1.5 Controller: checkout session path

| # | Deviation | Analog | Ours | Round(s) | Sanctioned |
|---|-----------|--------|------|----------|------------|
| 32 | Checkout response uses `redirectUrl` instead of `url`, missing `sessionId`, default 200 instead of 201 | WWR: `{ url: session.url, sessionId: session.id }, status: :created` (board_wwr_listings_controller.rb:120); WhatJobs: same format (board_what_jobs_listings_controller.rb:261) | `{ redirectUrl: session.url }` (organization_ai_credit_purchases_controller.rb:143) | R1, R2 | No |
| 33 | Checkout `line_items` uses `price: price.id` instead of inline `price_data` | WWR: `price_data:` with `currency`, `product_data`, `unit_amount` (board_wwr_listings_controller.rb:84-91); WhatJobs: same | `price: price.id` (organization_ai_credit_purchases_controller.rb:116) | R1, R2 | No |
| 34 | Checkout includes `payment_method_types: ['card']` | Neither analog passes `payment_method_types` | `payment_method_types: ['card']` (organization_ai_credit_purchases_controller.rb:115) | R2 | No |
| 35 | Checkout missing `payment_intent_data.metadata` | WWR: `payment_intent_data: { metadata: { board_wwr_listing_id:, ... } }` (board_wwr_listings_controller.rb:94-100); WhatJobs: similar | No `payment_intent_data` (organization_ai_credit_purchases_controller.rb:112-135) | R1, R2 | No |
| 36 | Checkout metadata in 2 locations instead of 3 | WWR/WhatJobs: `payment_intent_data.metadata`, `invoice_creation.invoice_data.metadata`, top-level `metadata` | Only `invoice_creation.invoice_data.metadata` and top-level `metadata` (organization_ai_credit_purchases_controller.rb:118-134) | R1 | No |

### 1.6 Webhook: invoice.paid one-off branch

| # | Deviation | Analog | Ours | Round(s) | Sanctioned |
|---|-----------|--------|------|----------|------------|
| 37 | Extra `Stripe::Checkout::Session.list` API call in webhook | WWR/WhatJobs: zero extra Stripe API calls (stripe_webhook_handler_job.rb:233-237 / 246-261) | `Stripe::Checkout::Session.list(payment_intent: ...)` (stripe_webhook_handler_job.rb:216-218) | R1, R2 | No |
| 38 | 3-way fallback record lookup instead of direct `.find()` | WWR: `BoardWwrListing.find(listing_id)` (stripe_webhook_handler_job.rb:237); WhatJobs: `BoardWhatJobsListing.find(listing_id)` (stripe_webhook_handler_job.rb:250) | `find_by(id:)`, then `find_by(stripe_checkout_session_id:)`, then `find_by(stripe_invoice_id:)` (apply_ai_credit_purchase.rb:46-51) | R1, R2 | No |
| 39 | Uses interactor instead of direct model calls | WWR: `listing.finalize_stripe_payment` then `listing.create_on_wwr` inline (stripe_webhook_handler_job.rb:239-242); WhatJobs: similar (stripe_webhook_handler_job.rb:253-259) | Delegates to `ApplyAiCreditPurchase.call(...)` (stripe_webhook_handler_job.rb:221-229) | R1, R2 | No |
| 40 | Nil guard uses `context.fail!` instead of `&.present?` | WWR: `if listing&.present?` (stripe_webhook_handler_job.rb:239); WhatJobs: `if listing&.present?` (stripe_webhook_handler_job.rb:252) | `context.fail!(error: :missing_purchase)` (apply_ai_credit_purchase.rb:53-58) | R1, R2 | No |
| 41 | No websocket broadcast after fulfillment | WWR: `broadcast_event('wwr_listing_published')` + `broadcast_show_growl(...)` (board_wwr_listing.rb:193-194); WhatJobs: `broadcast_event('what_jobs_listing_payment_received')` (stripe_webhook_handler_job.rb:257) | No broadcast (apply_ai_credit_purchase.rb:38-89) | R1, R2 | No |
| 42 | No Slack notification after fulfillment | WWR: `Notification::PaidWwrListingCreatedJob.perform_later(...)` (board_wwr_listing.rb:196) | No notification job (apply_ai_credit_purchase.rb:38-89) | R1, R2 | No |
| 43 | No `rescue StandardError` in fulfillment | WWR: `rescue StandardError => e` with logging (board_wwr_listing.rb:197-200) | Uses `context.fail!` for expected errors, unexpected errors propagate (apply_ai_credit_purchase.rb:38-89) | R1, R2 | No |
| 44 | Zero logging in webhook branch | WWR: `Rails.logger.info` + `ap` (stripe_webhook_handler_job.rb:234-235); WhatJobs: `Rails.logger.info` + `ap` (stripe_webhook_handler_job.rb:247-248,255) | Zero logging (stripe_webhook_handler_job.rb:212-231) | R1, R2 | No |
| 45 | `stripe_invoice_id` not stamped on purchase for checkout-session one-offs | Both analogs are consistent (no stamp) -- but `apply_one_off` receives `context.invoice_id` and uses it only as fallback lookup (apply_ai_credit_purchase.rb:49-50), never writes it to the record | `stripe_invoice_id` stays nil permanently for checkout-session one-offs | R2 | No |
| 46 | `handle_charge_refunded` cannot find direct-charge one-off purchases | N/A (WWR has no refund handler) | For direct-charge one-offs, `payment_intent.invoice` branch retrieves invoice, gets `invoice.subscription` (nil), then queries `find_by(stripe_subscription_id: nil, kind: :subscription)` which will not match a one-off purchase (stripe_webhook_handler_job.rb:429-455) | R2 | No |

### 1.7 Interactor existence

| # | Deviation | Analog | Ours | Round(s) | Sanctioned |
|---|-----------|--------|------|----------|------------|
| 47 | Interactor exists where analog has none | WWR/WhatJobs: no interactors in `app/interactors/` for these models | `ApplyAiCreditPurchase` interactor (apply_ai_credit_purchase.rb) handles lookup, idempotency, stripe_amount update, finalize, ledger creation, notification flag reset | R1 | No |
| 48 | Credit granting lives in interactor instead of on model | WWR: `create_on_wwr` on model (board_wwr_listing.rb:173-200) | `ApplyAiCreditPurchase#apply_one_off` in interactor (apply_ai_credit_purchase.rb:38-89) | R1 | No |

---

## 2. SUBSCRIPTION RENEWAL FLOW (invoice.paid)

| # | Deviation | Analog | Ours | Round(s) | Sanctioned |
|---|-----------|--------|------|----------|------------|
| 49 | Guard for missing subscription: silent return instead of raising error | Raises `CustomStripeSubscriptionMissingError` if `organization.stripe_subscription_id.nil?` (stripe_webhook_handler_job.rb:271) | `return unless existing` silently (stripe_webhook_handler_job.rb:462); interactor uses `context.fail!` (apply_ai_credit_purchase.rb:53-58) | R1, R2 | No |
| 50 | Period end source: invoice line item instead of Stripe Subscription object | Retrieves `Stripe::Subscription` and reads `current_period_end` (stripe_webhook_handler_job.rb:264,273) | Reads `invoice.lines.data.first&.period.end` (apply_ai_credit_purchase.rb:108,112) | R1, R2 | No |
| 51 | Period end update in interactor instead of webhook handler | Inline in webhook handler: `organization.update(stripe_current_period_end_at: ...)` (stripe_webhook_handler_job.rb:273) | Inside `ApplyAiCreditPurchase` interactor: `existing.update(subscription_current_period_end: ...)` (apply_ai_credit_purchase.rb:109-114) | R1 | No |
| 52 | Period start stored (extra column not in analog) | Only stores `stripe_current_period_end_at` -- no period_start column on organizations (stripe_webhook_handler_job.rb:273) | Stores both `subscription_current_period_start` and `subscription_current_period_end` (apply_ai_credit_purchase.rb:111-112) | R1, R2 | No |
| 53 | Update error handling: `context.fail!` aborts vs analog continues processing | Checks `updated` return, logs error, then CONTINUES processing (stripe_webhook_handler_job.rb:274-279) | `context.fail!` ABORTS the interactor (apply_ai_credit_purchase.rb:115) | R1 | No |
| 54 | No `stripe_update_default_payment_method` call on renewal | `organization.stripe_update_default_payment_method` (stripe_webhook_handler_job.rb:278; organization.rb:612-633) | No payment method update anywhere (stripe_webhook_handler_job.rb:457-473; apply_ai_credit_purchase.rb:91-133) | R1, R2 | No |
| 55 | Credit reset: single additive ledger row vs zero-and-grant | `ResetAiCredits`: transaction-wrapped, debit row to zero previous bucket, credit row for new allocation (reset_ai_credits.rb:34-77) | Single additive `subscription_credit_pack_purchase_credit` ledger row, no transaction, no zeroing (apply_ai_credit_purchase.rb:119-127) | R1, R2 | No |
| 56 | No `last_reset_at` update | `ResetAiCredits` sets `balance.last_reset_at` to `Time.current` (reset_ai_credits.rb:66) | Does not update `last_reset_at` (apply_ai_credit_purchase.rb:129-132) | R1, R2 | No |
| 57 | Notification flag clearing: 2 columns vs 4-5 | `ResetAiCredits` clears `last_reset_at`, `low_credit_notification_sent_at`, `zero_credit_notification_sent_at`, `sent_low_notification_since_increase`, `sent_zero_notification_since_increase` (reset_ai_credits.rb:65-71) | Clears only `sent_low_notification_since_increase`, `sent_zero_notification_since_increase` (apply_ai_credit_purchase.rb:129-132) | R1, R2 | No |
| 58 | Notification flag clearing uses `update_columns` instead of `update` | `ResetAiCredits` uses `balance.update(...)` (runs validations/callbacks) (reset_ai_credits.rb:65) | Uses `balance.update_columns(...)` (skips validations/callbacks) (apply_ai_credit_purchase.rb:129) | R2 | No |
| 59 | No DB transaction wrapping renewal operations | `ResetAiCredits` wraps in `ApplicationRecord.transaction` (reset_ai_credits.rb:34,77) | No transaction -- partial state possible if ledger save fails after purchase update and `finalize_stripe_payment` (apply_ai_credit_purchase.rb:109-132) | R1, R2 | No |
| 60 | `subscription_status` hardcoded to `:active` on every `invoice.paid` | Analog does NOT update `stripe_subscription_status` in invoice.paid else branch (stripe_webhook_handler_job.rb:264-280) | Sets `subscription_status: :active` on every renewal (apply_ai_credit_purchase.rb:110) | R1, R2 | No |
| 61 | `finalize_stripe_payment` called on subscription renewal (analog only calls it for one-offs) | Only called by one-off analogs (WWR line 240, WhatJobs line 253). The org row has no `stripe_invoice_paid`. | Called on every renewal (apply_ai_credit_purchase.rb:117) | R1 | No |
| 62 | Ledger description hardcodes "first invoice" for all renewals | `ResetAiCredits`: `"Monthly credit grant for #{organization.plan}"` (reset_ai_credits.rb:58) | `'Credit pack subscription first invoice'` on every renewal (apply_ai_credit_purchase.rb:125) | R1, R2 | No |
| 63 | `handle_subscription_credit_pack_invoice_paid` update has no error check | Analog captures return value and logs errors (stripe_webhook_handler_job.rb:273-277) | `existing.update(stripe_amount:, currency:, stripe_invoice_item_id:)` discards return value (stripe_webhook_handler_job.rb:466-470) | R1, R2 | No |
| 64 | `price` parameter accepted but unused in `apply_subscription` | N/A | `apply_subscription(invoice, price)` accepts `price` but never references it (apply_ai_credit_purchase.rb:91) | R1, R2 | No |
| 65 | Idempotency mechanism differs: ours is not re-entrant, analog is | Analog has NO idempotency guard -- repeat deliveries re-process (stripe_webhook_handler_job.rb:264-280) | Explicit guard: `return if existing.stripe_invoice_id == invoice.id` (apply_ai_credit_purchase.rb:103) | R1 | No |
| 66 | Interactor failure silently swallowed -- caller never checks `.success?` | Errors propagate to structured 3-clause rescue chain (stripe_webhook_handler_job.rb:281-291) | `context.fail!` does not raise; `ApplyAiCreditPurchase.call` result never checked (stripe_webhook_handler_job.rb:472; apply_ai_credit_purchase.rb:94,98,106,115,127,137) | R2 | No |
| 67 | Subscription status column type: integer enum vs raw string | `stripe_subscription_status` is a `string` column on organizations (db/schema.rb:1061) | `subscription_status` is an `integer` with enum mapping -- unrecognized Stripe status raises `ArgumentError` (db/schema.rb:978; organization_ai_credit_purchase.rb:82-84) | R2 | No |
| 68 | Organization nil guard: different failure mode (silent swallow vs NoMethodError caught by rescue) | If org is nil, `organization.stripe_subscription_id.nil?` raises `NoMethodError`, caught by `StandardError` rescue with logging (stripe_webhook_handler_job.rb:209,271,287-290) | `handle_subscription_credit_pack_invoice_paid` bypasses org variable; `ApplyAiCreditPurchase` does own lookup, fails via `context.fail!` which is silently swallowed (apply_ai_credit_purchase.rb:93-94; stripe_webhook_handler_job.rb:472) | R2 | No |

---

## 3. SUBSCRIPTION CHANGE FLOW (portal session + frontend)

| # | Deviation | Analog | Ours | Round(s) | Sanctioned |
|---|-----------|--------|------|----------|------------|
| 69 | No `ValidateSubscriptionChange` in `change_subscription_portal_session` | `ValidateSubscriptionChange.call(...)` (billing_controller.rb:277-285) | Not called (organization_ai_credit_purchases_controller.rb:154-202) | R1, R2 | **Yes (#3)** |
| 70 | No `ValidateSubscriptionChange` in `continue_change_subscription_portal_session` | `ValidateSubscriptionChange.call(...)` (billing_controller.rb:418-429) | Not called (organization_ai_credit_purchases_controller.rb:261-335) | R1, R2 | **Yes (#3)** |
| 71 | Frontend `handleSelectTier` has no plan-limits gate | `handleChangeSubscriptionWithGate` calls `checkPlanLimitsGate(plan.lookupKey)` (AccountBillingPlans.tsx:322-350) | Goes directly to portal session with no gate (AiCreditSubscription.tsx:143-155) | R1, R2 | **Yes (#3)** |
| 72 | Subscription existence guard: record query instead of direct column check | `current_organization.stripe_subscription_id.present?` (billing_controller.rb:273,336,395) | Queries `organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])` then checks `purchase.nil? \|\| purchase.stripe_subscription_id.blank?` (organization_ai_credit_purchases_controller.rb:159-160,211-213,271-273) | R1, R2 | **Yes (#1, #2)** |
| 73 | `flow_data.subscription` source: purchase row instead of org column | `current_organization.stripe_subscription_id` (billing_controller.rb:296,439) | `purchase.stripe_subscription_id` (organization_ai_credit_purchases_controller.rb:172,305) | R1, R2 | **Yes (#1)** |
| 74 | `customer_subscription` uses purchase record lookup | `current_organization.stripe_subscription_id.nil?` / `current_organization.stripe_subscription` (billing_controller.rb:609,614) | Queries active/past_due purchase, checks `purchase&.stripe_subscription_id.nil?`, calls `purchase.stripe_subscription` (organization_ai_credit_purchases_controller.rb:362-369) | R1, R2 | **Yes (#1, #2, #4)** |
| 75 | `determine_price_id` uses AI credit lookup key matcher instead of single constant | `price.lookup_key == DEFAULT_PRICE_LOOKUP_KEY` (`'plan_simple_ats_per_job_tiered'`) (billing_controller.rb:637) | `OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?(price.lookup_key)` (organization_ai_credit_purchases_controller.rb:399) | R1, R2 | **Yes (#5)** |
| 76 | `determine_price_id` fallback is non-deterministic | Analog: deterministic, always returns single matching price (billing_controller.rb:637) | Matches ANY subscription lookup key (small/medium/large); `.find` returns whichever Stripe returns first (organization_ai_credit_purchases_controller.rb:399) | R2 | No |
| 77 | `continue_change_subscription_portal_session` continue_url path segment | `/api/v1/billing/continue_change_subscription_portal_session` (billing_controller.rb:346) | `/api/v1/ai_credit_purchases/continue_change_subscription_portal_session` (organization_ai_credit_purchases_controller.rb:222) | R1, R2 | **Yes (#5)** |
| 78 | Frontend: `useAiCreditCustomerSubscription` query key | `["stripeCustomerSubscription"]` (useBilling.ts:261) | `["aiCreditCustomerSubscription"]` (useOrganizationAiCreditPurchase.ts:170) | R1, R2 | **Yes (#5)** |
| 79 | Frontend: no `trackEvent("plan_selected")` on tier card click | PlanCard.tsx calls `trackEvent("plan_selected", {...})` (PlanCard.tsx:99) | No `trackEvent` call (AiSubscriptionTierCard.tsx:62; AiCreditSubscription.tsx:143-155) | R1, R2 | No |
| 80 | Frontend: `handleSelectTier` does not branch between new-subscription checkout and change-subscription portal; `subscribe` mutate is destructured but never called | PlanCard.tsx checks `hasActiveSubscription` and routes to portal flow or checkout flow (PlanCard.tsx:100-104) | Always calls portal-session change flow regardless of `isSubscribed`; `subscribe` from `useCheckoutAiCreditPack` destructured (line 36) but never invoked; clicking Subscribe when not subscribed will fail (AiCreditSubscription.tsx:143-155) | R1, R2 | No |
| 81 | Frontend: `returnUrl` path differs | `/hire/settings/billing` (AccountBillingPlans.tsx:254,293) | `/hire/settings/plato-ai/billing` (AiCreditSubscription.tsx:78,119) | R1 | No |
| 82 | Frontend: `useChangeAiCreditSubscriptionViaStripePortal` onSuccess invalidates extra query | Invalidates only `["currentOrganization"]` (useBilling.ts:189) | Invalidates `["currentOrganization"]` AND `["organizationAiCreditPurchase"]` (useOrganizationAiCreditPurchase.ts:58-59) | R1, R2 | No |
| 83 | Frontend: `useUpdateAiCreditSubscriptionWithPaymentMethod` onSuccess invalidates extra query | Invalidates only `["currentOrganization"]` (useBilling.ts:202) | Invalidates `["currentOrganization"]` AND `["organizationAiCreditPurchase"]` (useOrganizationAiCreditPurchase.ts:87-88) | R1, R2 | No |
| 84 | Frontend: `AiSubscriptionTierCard` button has no `loading` prop | PlanCard.tsx button receives `loading={isLoadingButton}` AND `disabled={isLoading}` (PlanCard.tsx:209-210) | Only `disabled={isLoading}`, no `loading` prop (AiSubscriptionTierCard.tsx:63-64) | R1, R2 | No |

---

## 4. customer.subscription.updated WEBHOOK HANDLER

| # | Deviation | Analog | Ours | Round(s) | Sanctioned |
|---|-----------|--------|------|----------|------------|
| 85 | Missing `stripe_cancel_at_period_end` column update | Updates `stripe_cancel_at_period_end: object.cancel_at_period_end` (stripe_webhook_handler_job.rb:156) | Column exists on purchase table (schema.rb:980) but is never set (stripe_webhook_handler_job.rb:135-141) | R1, R2 | No |
| 86 | Missing `stripe_update_default_payment_method` call | `organization.stripe_update_default_payment_method(object.default_payment_method)` (stripe_webhook_handler_job.rb:158) | No payment method update (stripe_webhook_handler_job.rb:125-148) | R1, R2 | No |
| 87 | Missing `sync_with_stripe` call or equivalent | `organization.sync_with_stripe` (stripe_webhook_handler_job.rb:159) | No sync/reconciliation step (stripe_webhook_handler_job.rb:125-148) | R1, R2 | No |
| 88 | Extra columns updated that analog does not update inline | Analog does not update `stripe_price_lookup_key` or `subscription_credits_per_period` -- plan assignment happens inside `sync_with_stripe` (stripe_webhook_handler_job.rb:153-157; organization.rb:573) | Updates `stripe_price_lookup_key` and `subscription_credits_per_period` directly inline (stripe_webhook_handler_job.rb:136-137) | R1 | No |
| 89 | Extra column: `subscription_current_period_start` updated | Analog only updates `stripe_current_period_end_at` (stripe_webhook_handler_job.rb:154) | Updates both `subscription_current_period_start` and `subscription_current_period_end` (stripe_webhook_handler_job.rb:139-140) | R1 | No |
| 90 | Different error handling: ours checks update result and logs (analog does not) | No check on `organization.update` return value (stripe_webhook_handler_job.rb:153-157) | Checks `updated`, logs `Rails.logger.error` + `ap purchase.errors` on failure (stripe_webhook_handler_job.rb:142-145) | R1, R2 | No |
| 91 | Different error handling: explicit `else` branch for record not found | No guard for nil organization before `.update` (stripe_webhook_handler_job.rb:149) | `else` branch with `Rails.logger.error` when purchase not found (stripe_webhook_handler_job.rb:147-148) | R1 | No |
| 92 | Different guard structure: category match vs identity match | Guards on `object.id == organization&.stripe_subscription_id` (identity check) (stripe_webhook_handler_job.rb:149) | Guards on `OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?(plan_lookup_key)` (category check) (stripe_webhook_handler_job.rb:125) | R1 | No |
| 93 | No change-detection before writing (analog compares via `sync_with_stripe`) | `sync_with_stripe` compares each attribute and only updates if changed (organization.rb:583-609) | Writes all 5 fields unconditionally on every event (stripe_webhook_handler_job.rb:135-141) | R2 | No |
| 94 | No model callbacks on `subscription_status` change (past_due email, paid notification, trial notifications, automations disable) | `after_commit` -> `handle_subscription_status_change_after_commit` fires mailers, notification jobs, Discord jobs, automation disabling (organization.rb:1067-1117) | Zero `after_commit`/`after_update` callbacks on `OrganizationAiCreditPurchase` (organization_ai_credit_purchase.rb) | R2 | No |
| 95 | No cancellation-scheduled notification chain from `stripe_cancel_at_period_end` | When `stripe_cancel_at_period_end` changes false->true, `after_commit` fires `CancellationScheduledJob`, `Discord::NotifyCancellationScheduledJob`, `EngagementReport::GeneratorJob` (organization.rb:1009-1021) | `stripe_cancel_at_period_end` not written at all (stripe_webhook_handler_job.rb:135-141), so no notifications fire | R2 | No |
| 96 | `stripe_default_payment_method_on_file` not updated | `sync_with_stripe` sets `stripe_default_payment_method_on_file` from Stripe customer data (organization.rb:580) | Not touched (stripe_webhook_handler_job.rb:135-141) -- org-level column, purchase model does not have one | R2 | No |
| 97 | No Stripe API reconciliation call to verify webhook data | `sync_with_stripe` makes live `Stripe::Customer.retrieve` call to reconcile (organization.rb:538) | Trusts webhook event object entirely (stripe_webhook_handler_job.rb:135-141) | R2 | No |
| 98 | Plan-change credit allocation: deferred to invoice.paid instead of immediate | `sync_with_stripe` grants credits immediately via `update_columns(monthly_credits_remaining: new_allocation)` (organization.rb:602-606) | `subscription_credits_per_period` updated but no balance change; credits granted later via `invoice.paid` (stripe_webhook_handler_job.rb:137) | R2 | No |

---

## 5. customer.subscription.deleted WEBHOOK HANDLER

| # | Deviation | Analog | Ours | Round(s) | Sanctioned |
|---|-----------|--------|------|----------|------------|
| 99 | No AI credit subscription branch -- org-level side effects fire incorrectly for AI credit subscription deletions | `sync_with_stripe` guarded by subscription ID match (stripe_webhook_handler_job.rb:179), but lines 182-184 unconditionally run: (a) `organization.update_column(:subscription_canceled_at, ...)` clobbers org timestamp with AI credit sub end date, (b) `Notification::PaidSubscriptionDeletedJob` fires for wrong sub type, (c) `EngagementReport::GeneratorJob` fires with `subscription_canceled` trigger | No credit-pack branching to prevent these side effects (stripe_webhook_handler_job.rb:167-188) | R1 (noted missing), R2 (traced wrong side effects) | No |
