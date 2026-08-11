# Round 1 — Audit Results

I see: the controller calls `Stripe::Price.list` at line 77 to validate the price exists, then the model method `charge_default_payment_method` calls `Stripe::Price.list` AGAIN at line 132 of the model. The WWR analog does NOT do this — the WWR `create` controller doesn't look up Stripe prices at all (it calculates the amount in `calculate_charge_amount`), and the WWR `charge_for_listing` model method uses the `amount` parameter directly.

Let me also check whether the WWR controller's `create` flow renders the record AFTER charging. The AI credit flow just renders `{ charged: true }` — it does NOT render the purchase record.

Now let me compile the full deviation report. Let me verify one more thing about the `create` vs `purchase_top_up` flow structure.

WWR `create`:
1. Find job (exists block)
2. Validate description
3. Merge params
4. Build listing
5. Authorize instance
6. Save
7. charge_for_listing (model method)
8. render_one with serializer
9. rescue StandardError

AI credit `purchase_top_up`:
1. authorize :billing, :checkout?
2. Validate lookup_key
3. Stripe::Price.list to validate price exists
4. Build purchase
5. Save
6. Branch: payment method on file?
   - Yes: charge_default_payment_method (model method), render { charged: true }
   - No: create Stripe checkout session, update purchase with session ID, render { redirectUrl: }
7. rescue Stripe::StripeError

The WWR `create` has NO branching — it always charges via the model method. The AI credit `purchase_top_up` branches on payment method availability. The checkout-session path is more akin to WWR's separate `create_checkout_session` action.

Let me verify the WWR `create_checkout_session` response structure.

WWR `create_checkout_session` (line 120): `render json: { url: session.url, sessionId: session.id }, status: :created`
AI credit `purchase_top_up` checkout path (line 143): `render json: { redirectUrl: session.url }` — no sessionId, no status code.

The AI credit subscription `checkout` (line 60): `render json: { redirectUrl: session.url }` — same as top-up.

So the AI credit checkout response uses `redirectUrl` instead of `url`, omits `sessionId`, and omits `status: :created`.

Now I have enough information to produce the full deviation report.

---

DEVIATION: [Model charge method — extra Stripe::Price.list call] | ANALOG: board_wwr_listing.rb:112-164 charge_for_listing uses amount calculated locally, no Price lookup | OURS: organization_ai_credit_purchase.rb:132-133 charge_default_payment_method calls Stripe::Price.list to look up the price ID before creating InvoiceItem | SANCTIONED: no

DEVIATION: [Model charge method — InvoiceItem uses price: instead of amount:+currency:+description:] | ANALOG: board_wwr_listing.rb:130-138 InvoiceItem.create passes amount:, currency: 'usd', description: @final_description | OURS: organization_ai_credit_purchase.rb:136-145 InvoiceItem.create passes price: price.id, no currency:, no description: | SANCTIONED: no

DEVIATION: [Model charge method — Invoice missing description:] | ANALOG: board_wwr_listing.rb:147 Invoice.create includes description: 'We Work Remotely Listing' | OURS: organization_ai_credit_purchase.rb:147-157 Invoice.create has no description: | SANCTIONED: no

DEVIATION: [Model charge method — Invoice has explicit auto_advance: true] | ANALOG: board_wwr_listing.rb:145 Invoice.create has auto_advance: false commented out (Stripe default is true) | OURS: organization_ai_credit_purchase.rb:150 Invoice.create has auto_advance: true explicitly set | SANCTIONED: no
REVERT: [Net behavior is the same since Stripe defaults auto_advance to true. The explicit setting is cosmetically different but functionally identical. Could revert to match the analog by removing the line.]

DEVIATION: [Model charge method — update_columns stamps paid_invoice.amount_paid instead of pre-calculated amount] | ANALOG: board_wwr_listing.rb:158 update_columns(stripe_amount: amount) uses pre-calculated charge amount | OURS: organization_ai_credit_purchase.rb:163 update_columns(stripe_amount: paid_invoice.amount_paid) uses amount from Stripe response | SANCTIONED: no

DEVIATION: [Model charge method — update_columns stamps currency from Stripe response] | ANALOG: board_wwr_listing.rb:158 update_columns does NOT stamp currency | OURS: organization_ai_credit_purchase.rb:164 update_columns includes currency: paid_invoice.currency | SANCTIONED: no

DEVIATION: [Model charge method — metadata expanded with 4 keys instead of 1] | ANALOG: board_wwr_listing.rb:135-137 InvoiceItem metadata has 1 key: board_wwr_listing_id: id. board_wwr_listing.rb:148-150 Invoice metadata has 1 key: board_wwr_listing_id: id | OURS: organization_ai_credit_purchase.rb:139-143 InvoiceItem metadata has 4 keys (organization_id, organization_ai_credit_purchase_id, stripe_price_lookup_key, ai_credit_pack_top_up). Lines 152-156 Invoice metadata same 4 keys | SANCTIONED: no

DEVIATION: [Model charge method — no logging] | ANALOG: board_wwr_listing.rb:114,128,160-161 charge_for_listing has 4 Rails.logger.info statements | OURS: organization_ai_credit_purchase.rb:127-169 charge_default_payment_method has zero logging statements | SANCTIONED: no

DEVIATION: [Model charge method — double-charge guard checks only stripe_invoice_id, not also is_active?] | ANALOG: board_wwr_listing.rb:115 guard is stripe_invoice_id.present? && is_active? | OURS: organization_ai_credit_purchase.rb:129 guard is stripe_invoice_id.present? only | SANCTIONED: no

DEVIATION: [Controller purchase_top_up — Stripe::Price.list is called twice for payment-on-file path] | ANALOG: board_wwr_listings_controller.rb:6-27 create does not call Stripe::Price.list at all | OURS: organization_ai_credit_purchases_controller.rb:77 calls Stripe::Price.list, then model charge_default_payment_method at organization_ai_credit_purchase.rb:132 calls Stripe::Price.list again — duplicate API call | SANCTIONED: no

DEVIATION: [Controller purchase_top_up — combined direct-charge + checkout-session in one action] | ANALOG: board_wwr_listings_controller.rb has separate actions: create (lines 6-31, direct charge) and create_checkout_session (lines 51-128, checkout redirect) | OURS: organization_ai_credit_purchases_controller.rb:68-149 purchase_top_up combines both paths in one action with if/else branching on stripe_default_payment_method_on_file | SANCTIONED: no

DEVIATION: [Controller purchase_top_up direct-charge response — bare hash instead of serialized record] | ANALOG: board_wwr_listings_controller.rb:23 render_one(@listing, Api::V1::BoardWwrListingSerializer) returns full serialized record | OURS: organization_ai_credit_purchases_controller.rb:108 render json: { charged: true } returns bare boolean | SANCTIONED: no

DEVIATION: [Controller purchase_top_up checkout response — redirectUrl key instead of url+sessionId, no status: :created] | ANALOG: board_wwr_listings_controller.rb:120 render json: { url: session.url, sessionId: session.id }, status: :created | OURS: organization_ai_credit_purchases_controller.rb:143 render json: { redirectUrl: session.url } — different key name, no sessionId, no explicit 201 status | SANCTIONED: no

DEVIATION: [Controller purchase_top_up — rescue Stripe::StripeError instead of StandardError] | ANALOG: board_wwr_listings_controller.rb:28-31 create rescues StandardError => e | OURS: organization_ai_credit_purchases_controller.rb:144-148 purchase_top_up rescues Stripe::StripeError => e (narrower, non-Stripe errors propagate unhandled) | SANCTIONED: no

DEVIATION: [Controller purchase_top_up — Sentry.capture_exception in error handler] | ANALOG: board_wwr_listings_controller.rb:29-30 create error handler does Rails.logger.error + render_general_errors only, no Sentry | OURS: organization_ai_credit_purchases_controller.rb:146-147 purchase_top_up error handler adds ap e + Sentry.capture_exception (extra calls not in analog) | SANCTIONED: no

DEVIATION: [Controller purchase_top_up — error message hides Stripe error details from user] | ANALOG: board_wwr_listings_controller.rb:30 render_general_errors(["Unable to process payment: #{e.message}"]) includes e.message | OURS: organization_ai_credit_purchases_controller.rb:148 render_general_errors(['Something went wrong with the payment processor...']) hides e.message behind generic text | SANCTIONED: no

DEVIATION: [Controller purchase_top_up checkout path — payment_method_types: ['card'] is explicit] | ANALOG: board_wwr_listings_controller.rb:80-118 create_checkout_session does NOT set payment_method_types | OURS: organization_ai_credit_purchases_controller.rb:115 sets payment_method_types: ['card'] explicitly | SANCTIONED: no

DEVIATION: [Controller purchase_top_up checkout path — line_items uses price: price.id instead of price_data:] | ANALOG: board_wwr_listings_controller.rb:83-93 uses price_data: { currency:, product_data: { name:, description: }, unit_amount: } inline | OURS: organization_ai_credit_purchases_controller.rb:116 uses price: price.id (Stripe Price object reference) | SANCTIONED: no

DEVIATION: [Controller purchase_top_up checkout path — no payment_intent_data metadata] | ANALOG: board_wwr_listings_controller.rb:94-100 create_checkout_session includes payment_intent_data: { metadata: { ... } } | OURS: organization_ai_credit_purchases_controller.rb:112-135 purchase_top_up checkout session has no payment_intent_data | SANCTIONED: no

DEVIATION: [Controller purchase_top_up checkout path — invoice_creation.invoice_data missing description] | ANALOG: board_wwr_listings_controller.rb:103-104 invoice_data includes description: @final_invoice_description | OURS: organization_ai_credit_purchases_controller.rb:119-126 invoice_data has metadata only, no description | SANCTIONED: no

DEVIATION: [Controller purchase_top_up checkout path — success/cancel URLs lack {CHECKOUT_SESSION_ID}] | ANALOG: board_wwr_listings_controller.rb:116-117 success_url and cancel_url include session_id={CHECKOUT_SESSION_ID} template variable | OURS: organization_ai_credit_purchases_controller.rb:128-129 success_url and cancel_url use static query params, no {CHECKOUT_SESSION_ID} | SANCTIONED: no

DEVIATION: [Controller purchase_top_up checkout path — stores stripe_checkout_session_id on record after session creation] | ANALOG: board_wwr_listings_controller.rb:76-120 create_checkout_session does NOT store the checkout session ID on the listing record | OURS: organization_ai_credit_purchases_controller.rb:137 purchase.update(stripe_checkout_session_id: session.id) stores it on the purchase record | SANCTIONED: no
WHITELIST: [The checkout_session_id is needed for the webhook handler to find the purchase record on checkout.session.completed for the subscription flow, and for the refund handler to find one-off purchases. The WWR analog has no equivalent lookup need — it uses invoice metadata board_wwr_listing_id. Removing this would break the AI credit refund and subscription checkout flows.]

DEVIATION: [Controller purchase_top_up checkout error — render_general_errors instead of render json: { error: }] | ANALOG: board_wwr_listings_controller.rb:127 rescue renders render json: { error: e.message }, status: :unprocessable_entity | OURS: organization_ai_credit_purchases_controller.rb:148 rescue renders render_general_errors([generic message]) — different response shape and hides the error | SANCTIONED: no

DEVIATION: [Webhook handler invoice.paid — extra Stripe::Checkout::Session.list API call] | ANALOG: stripe_webhook_handler_job.rb:233-244 WWR invoice.paid branch does direct record lookup by metadata ID (BoardWwrListing.find), no extra Stripe calls | OURS: stripe_webhook_handler_job.rb:215-219 AI credit one-off invoice.paid branch makes Stripe::Checkout::Session.list(payment_intent:) call to resolve checkout_session_id for fallback lookup | SANCTIONED: no

DEVIATION: [Webhook handler invoice.paid — delegates to interactor instead of calling model methods directly] | ANALOG: stripe_webhook_handler_job.rb:237-241 calls listing.finalize_stripe_payment and listing.create_on_wwr directly on the record | OURS: stripe_webhook_handler_job.rb:221-229 calls ApplyAiCreditPurchase.call(...) interactor which internally does finalize_stripe_payment and credit granting | SANCTIONED: no
WHITELIST: [ApplyAiCreditPurchase interactor handles both one-off and subscription credit granting with idempotency guards. Inlining the logic into the webhook handler would duplicate the subscription path's logic. The interactor is shared infrastructure; removing it would break subscription credit granting.]

DEVIATION: [Webhook handler invoice.paid — no ap/Rails.logger logging in AI credit one-off branch] | ANALOG: stripe_webhook_handler_job.rb:234-235 WWR branch has Rails.logger.info + ap logging | OURS: stripe_webhook_handler_job.rb:212-231 AI credit one-off branch has no logging (comment only) | SANCTIONED: no

DEVIATION: [Webhook handler invoice.paid — metadata routing uses value comparison instead of presence check] | ANALOG: stripe_webhook_handler_job.rb:233 WWR branch checks object.metadata&.[]('board_wwr_listing_id').present? (presence check) | OURS: stripe_webhook_handler_job.rb:212 AI credit one-off branch checks object.metadata&.[]('ai_credit_pack_top_up') == 'true' (value equality) | SANCTIONED: no

DEVIATION: [Webhook handler invoice.paid — AI credit one-off branch placed BEFORE WWR branch in guard ordering] | ANALOG: stripe_webhook_handler_job.rb:233 WWR branch is second one-off check | OURS: stripe_webhook_handler_job.rb:212 AI credit one-off branch is first one-off check (before WWR) | SANCTIONED: no
WHITELIST: [The branches are mutually exclusive by metadata key. The ordering is cosmetic — each returns early. Reordering to put WWR first would not change behavior but would be a cosmetic churn to existing code.]

---NEXT DIMENSION---

Neither the AI credit model nor the interactor have any Discord/Slack/Notification jobs. The WhatJobs model itself doesn't have Discord/Slack either, but `create_on_what_jobs` does trigger `broadcast_event` and `broadcast_show_growl`. The WWR model has `Notification::PaidWwrListingCreatedJob.perform_later` in `create_on_wwr`. The AI credit flow has no equivalent notification.

Now let me check if the WhatJobs checkout session error rescue pattern matches.

WhatJobs `create_checkout_session` rescues:
- `Stripe::StripeError` -> `render json: { error: e.message }, status: :unprocessable_entity`

AI credit `purchase_top_up` rescues:
- `Stripe::StripeError` -> `render_general_errors(['Something went wrong...'])` + Sentry

Different error formats. WhatJobs returns `{ error: e.message }` with `unprocessable_entity` status. AI credit returns `render_general_errors` (which uses the app's standard error format) with the default 422 status.

Let me now finalize my report. I have all the deviations identified. Here is the complete structured report:

---

DEVIATION: InvoiceItem amount specification method | ANALOG: board_what_jobs_listing.rb:172-180 passes `amount: amount, currency: 'usd'` (hardcoded dollar amount) | OURS: organization_ai_credit_purchase.rb:137-145 passes `price: price.id` (Stripe Price object lookup) | SANCTIONED: no

DEVIATION: InvoiceItem description field | ANALOG: board_what_jobs_listing.rb:176 passes `description: @description` ("WhatJobs Job listing - {title}") | OURS: organization_ai_credit_purchase.rb:136-145 has no `description` field on InvoiceItem | SANCTIONED: no

DEVIATION: Invoice description field | ANALOG: board_what_jobs_listing.rb:185 passes `description: 'WhatJobs Listing'` on Invoice.create | OURS: organization_ai_credit_purchase.rb:147-157 has no `description` field on Invoice.create | SANCTIONED: no

DEVIATION: Invoice auto_advance field | ANALOG: board_what_jobs_listing.rb:182-189 does NOT pass `auto_advance` on Invoice.create | OURS: organization_ai_credit_purchase.rb:150 passes `auto_advance: true` | SANCTIONED: no

DEVIATION: InvoiceItem metadata richness | ANALOG: board_what_jobs_listing.rb:177-179 passes only `{ board_what_jobs_listing_id: id }` | OURS: organization_ai_credit_purchase.rb:139-144 passes `{ organization_id:, organization_ai_credit_purchase_id:, stripe_price_lookup_key:, ai_credit_pack_top_up: 'true' }` | SANCTIONED: yes (ai_credit_* descriptor naming)

DEVIATION: Invoice metadata richness | ANALOG: board_what_jobs_listing.rb:186-188 passes only `{ board_what_jobs_listing_id: id }` | OURS: organization_ai_credit_purchase.rb:151-156 passes `{ organization_id:, organization_ai_credit_purchase_id:, stripe_price_lookup_key:, ai_credit_pack_top_up: 'true' }` | SANCTIONED: yes (ai_credit_* descriptor naming)

DEVIATION: update_columns stripe_amount source | ANALOG: board_what_jobs_listing.rb:193 stamps `stripe_amount: amount` (locally computed value) | OURS: organization_ai_credit_purchase.rb:164 stamps `stripe_amount: paid_invoice.amount_paid` (from Stripe response) | SANCTIONED: no

DEVIATION: update_columns currency | ANALOG: board_what_jobs_listing.rb:193 does NOT stamp `currency` in update_columns | OURS: organization_ai_credit_purchase.rb:165 stamps `currency: paid_invoice.currency` | SANCTIONED: no

DEVIATION: Double-charge guard condition | ANALOG: board_what_jobs_listing.rb:160-162 checks `stripe_invoice_id.present? && live?` | OURS: organization_ai_credit_purchase.rb:129 checks only `stripe_invoice_id.present?` (no second condition) | SANCTIONED: no

DEVIATION: Logging in charge method | ANALOG: board_what_jobs_listing.rb:158,161,170,195 has 4 `ap` statements ('Attempt to charge...', 'Already charged...', 'Charging...', 'Invoice Has Been Finalized') | OURS: organization_ai_credit_purchase.rb:127-169 has zero `ap` or `Rails.logger` statements | SANCTIONED: no

DEVIATION: Stripe Price.list call in charge method | ANALOG: board_what_jobs_listing.rb:151-153 has no Stripe::Price.list call (uses hardcoded amount) | OURS: organization_ai_credit_purchase.rb:132-134 calls `Stripe::Price.list` to look up the price, returning early if not found | SANCTIONED: no

DEVIATION: Webhook invoice.paid branch pattern — interactor vs inline | ANALOG: stripe_webhook_handler_job.rb:246-262 WhatJobs branch finds record inline, calls `finalize_stripe_payment`, `broadcast_event`, `create_on_what_jobs` directly | OURS: stripe_webhook_handler_job.rb:212-231 AI credit one-off branch delegates to `ApplyAiCreditPurchase.call` interactor | SANCTIONED: no

DEVIATION: Webhook invoice.paid branch — extra Stripe API call | ANALOG: stripe_webhook_handler_job.rb:246-262 WhatJobs branch makes zero extra Stripe API calls; finds record by metadata ID | OURS: stripe_webhook_handler_job.rb:216-218 AI credit branch calls `Stripe::Checkout::Session.list(payment_intent:)` to look up checkout session ID | SANCTIONED: no

DEVIATION: Webhook invoice.paid branch — record lookup strategy | ANALOG: stripe_webhook_handler_job.rb:249-250 uses `BoardWhatJobsListing.find(listing_id)` (raises on miss) | OURS: apply_ai_credit_purchase.rb:46-51 uses cascading `find_by` with 3 fallback keys (purchase_id, checkout_session_id, invoice_id), returns nil on miss | SANCTIONED: no

DEVIATION: Webhook invoice.paid branch — broadcast/notification | ANALOG: stripe_webhook_handler_job.rb:257 calls `listing.broadcast_event('what_jobs_listing_payment_received')` | OURS: No broadcast or notification in AI credit one-off webhook path | SANCTIONED: no

DEVIATION: Webhook invoice.paid branch ordering | ANALOG: stripe_webhook_handler_job.rb WWR at line 233, WhatJobs at line 246 (board listings checked in order) | OURS: stripe_webhook_handler_job.rb AI credit one-off at line 212 (checked BEFORE both board listing branches) | SANCTIONED: no

DEVIATION: Controller direct-charge response format | ANALOG: board_what_jobs_listings_controller.rb:165 renders `render_one(@listing, Serializer)` (returns the record) | OURS: organization_ai_credit_purchases_controller.rb:108 renders `render json: { charged: true }` (returns a flag, not the record) | SANCTIONED: no

DEVIATION: Controller checkout response format | ANALOG: board_what_jobs_listings_controller.rb:261 renders `{ url: session.url, sessionId: session.id }, status: :created` | OURS: organization_ai_credit_purchases_controller.rb:143 renders `{ redirectUrl: session.url }` (different key name, no sessionId, no :created status) | SANCTIONED: no

DEVIATION: Controller checkout session — payment_method_types | ANALOG: board_what_jobs_listings_controller.rb:221-259 does NOT pass `payment_method_types` | OURS: organization_ai_credit_purchases_controller.rb:115 passes `payment_method_types: ['card']` | SANCTIONED: no

DEVIATION: Controller checkout session — line_items structure | ANALOG: board_what_jobs_listings_controller.rb:224-233 uses `price_data` with inline `unit_amount` and `product_data` | OURS: organization_ai_credit_purchases_controller.rb:116 uses `{ price: price.id, quantity: 1 }` (Stripe Price ID reference) | SANCTIONED: no

DEVIATION: Controller checkout session — payment_intent_data | ANALOG: board_what_jobs_listings_controller.rb:235-241 passes `payment_intent_data: { metadata: {...} }` | OURS: organization_ai_credit_purchases_controller.rb:112-135 does NOT pass `payment_intent_data` | SANCTIONED: no

DEVIATION: Controller checkout session — invoice_data description | ANALOG: board_what_jobs_listings_controller.rb:245 passes `description: @description` in `invoice_data` | OURS: organization_ai_credit_purchases_controller.rb:119-125 has no `description` in `invoice_data` | SANCTIONED: no

DEVIATION: Controller combined direct-charge + checkout in single action | ANALOG: board_what_jobs_listings_controller.rb has separate actions `create_paid_listing` (direct charge) and `create_checkout_session` (no payment on file) | OURS: organization_ai_credit_purchases_controller.rb:68-149 `purchase_top_up` combines both paths in a single action with `if stripe_default_payment_method_on_file` branch | SANCTIONED: no

DEVIATION: Controller error handling — Sentry.capture_exception | ANALOG: board_what_jobs_listings_controller.rb never calls Sentry | OURS: organization_ai_credit_purchases_controller.rb:147 calls `Sentry.capture_exception` in rescue | SANCTIONED: no

DEVIATION: Controller error handling — user-facing error message | ANALOG: board_what_jobs_listings_controller.rb:173 surfaces Stripe message: `"Payment failed: #{e.message}"` | OURS: organization_ai_credit_purchases_controller.rb:148 uses generic message: `'Something went wrong with the payment processor...'` | SANCTIONED: no

DEVIATION: Controller error handling — missing StandardError rescue | ANALOG: board_what_jobs_listings_controller.rb:175-177 rescues `StandardError` after `Stripe::StripeError` in `create_paid_listing` | OURS: organization_ai_credit_purchases_controller.rb:144-148 `purchase_top_up` rescues only `Stripe::StripeError`, no `StandardError` rescue | SANCTIONED: no

DEVIATION: Controller checkout error response format | ANALOG: board_what_jobs_listings_controller.rb:264-265 renders `render json: { error: e.message }, status: :unprocessable_entity` | OURS: organization_ai_credit_purchases_controller.rb:148 renders `render_general_errors(...)` (app standard format) | SANCTIONED: no

DEVIATION: Controller pre-charge validation | ANALOG: board_what_jobs_listings_controller.rb:156-160 calls `ValidateWhatJobsListing.call` before charging | OURS: organization_ai_credit_purchases_controller.rb:68-110 has no interactor-based validation before charging (only model validations on save) | SANCTIONED: yes (No ValidateSubscriptionChange / PlanFeatureGate / job-limit gate)

DEVIATION: Controller record pre-creation via interactor | ANALOG: board_what_jobs_listings_controller.rb:141-147 uses `CreateOrUpdateWhatJobsListingWithIntegration.call` interactor to create/update record | OURS: organization_ai_credit_purchases_controller.rb:89-101 uses `OrganizationAiCreditPurchase.new(...).save` directly (no creation interactor) | SANCTIONED: no

DEVIATION: ApplyAiCreditPurchase interactor — no analog exists | ANALOG: WhatJobs has no interactor for the post-payment webhook flow; logic is inline in webhook handler | OURS: apply_ai_credit_purchase.rb:1-139 is a full Interactor class handling credit granting | SANCTIONED: no

DEVIATION: Model — no `paid?` convenience method | ANALOG: board_what_jobs_listing.rb:88-90 has `def paid?` returning `stripe_invoice_paid?` | OURS: organization_ai_credit_purchase.rb has no `paid?` method | SANCTIONED: no

---NEXT DIMENSION---

Main-plan path logs errors with `Rails.logger.error` + `ap` on update failure.
`handle_subscription_credit_pack_invoice_paid` does NOT check `existing.update` return value -- no logging on update failure.

Now I have everything needed. Here is the complete deviation report.

---

DEVIATION: [Missing payment method update] | ANALOG: stripe_webhook_handler_job.rb:278 `organization.stripe_update_default_payment_method` — after persisting period end, updates the Stripe customer's default payment method | OURS: handle_subscription_credit_pack_invoice_paid (lines 457-473) + ApplyAiCreditPurchase#apply_subscription (lines 91-133) — no call to `stripe_update_default_payment_method` anywhere in the AI credit subscription renewal path | SANCTIONED: no

DEVIATION: [No subscription-missing guard] | ANALOG: stripe_webhook_handler_job.rb:271 `raise CustomStripeSubscriptionMissingError if organization.stripe_subscription_id.nil?` — guards against missing subscription before proceeding | OURS: handle_subscription_credit_pack_invoice_paid:458-462 uses `return unless existing` (silent return, no error raised/logged) and ApplyAiCreditPurchase:97-99 uses `context.fail!` (swallowed by caller) — different guard mechanism, no exception raised | SANCTIONED: no

DEVIATION: [Period source: live Stripe subscription vs invoice line item] | ANALOG: stripe_webhook_handler_job.rb:264,273 retrieves LIVE `Stripe::Subscription` object via `Stripe::Subscription.retrieve(object.subscription)` then reads `stripe_subscription.current_period_end` | OURS: ApplyAiCreditPurchase:108 reads `invoice.lines.data.first&.period` — gets period from invoice line item, not from a live subscription retrieve call | SANCTIONED: no

DEVIATION: [Update return value not checked in handle_subscription_credit_pack_invoice_paid] | ANALOG: stripe_webhook_handler_job.rb:273-277 `updated = organization.update(...)` then `unless updated` logs error + `ap` | OURS: handle_subscription_credit_pack_invoice_paid:466-470 `existing.update(stripe_amount:, currency:, stripe_invoice_item_id:)` — return value not captured or checked; silent failure if update fails | SANCTIONED: no

DEVIATION: [Interactor result not checked by webhook handler] | ANALOG: stripe_webhook_handler_job.rb:271-280 main-plan path uses inline `raise`/`update` that propagate errors to the surrounding `rescue` blocks | OURS: stripe_webhook_handler_job.rb:472 `ApplyAiCreditPurchase.call(...)` — return value (Interactor::Context) not checked; if `context.fail!` fires inside the interactor, the webhook handler is unaware; errors do NOT propagate to the `rescue Stripe::StripeError` / `rescue StandardError` blocks | SANCTIONED: no

DEVIATION: [Duplicate purchase lookup] | ANALOG: stripe_webhook_handler_job.rb:271-280 main-plan path looks up `organization` once (line 209) and uses it throughout | OURS: handle_subscription_credit_pack_invoice_paid:458-461 finds purchase by `stripe_subscription_id`, then ApplyAiCreditPurchase#apply_subscription:96 finds the SAME purchase again by the same `stripe_subscription_id` — redundant DB query | SANCTIONED: no

DEVIATION: [Duplicate organization lookup] | ANALOG: stripe_webhook_handler_job.rb:209 `organization = Organization.find_by(stripe_customer_id: stripe_customer_id)` — looked up once, used in else branch | OURS: organization already found at webhook handler line 209, but ApplyAiCreditPurchase#apply_subscription:93 looks up organization AGAIN via `Organization.find_by(stripe_customer_id: invoice.customer)` — not passed through from the handler | SANCTIONED: no

DEVIATION: [No addon_subscription bucket zero-out before renewal grant] | ANALOG: ResetAiCredits:39-50 zeros out remaining monthly balance with a `plan_monthly_reset_debit` ledger row BEFORE granting the new allocation | OURS: ApplyAiCreditPurchase#apply_subscription:119-127 grants `subscription_credit_pack_purchase_credit` into `addon_subscription` bucket WITHOUT first zeroing out whatever remains — credits accumulate indefinitely across renewals | SANCTIONED: no

DEVIATION: [Notification flag clearing: 2 fields vs 4 fields] | ANALOG: ResetAiCredits:65-71 clears 5 fields via `balance.update`: `last_reset_at`, `low_credit_notification_sent_at`, `zero_credit_notification_sent_at`, `sent_low_notification_since_increase`, `sent_zero_notification_since_increase` | OURS: ApplyAiCreditPurchase#apply_subscription:129-132 clears only 2 fields via `balance.update_columns`: `sent_low_notification_since_increase`, `sent_zero_notification_since_increase` — does not clear `low_credit_notification_sent_at`, `zero_credit_notification_sent_at`, does not set `last_reset_at` | SANCTIONED: no

DEVIATION: [update_columns vs update for notification flags] | ANALOG: ResetAiCredits:65 uses `balance.update(...)` (runs validations and callbacks) | OURS: ApplyAiCreditPurchase#apply_subscription:129 uses `balance.update_columns(...)` (skips validations and callbacks) | SANCTIONED: no

DEVIATION: [No transaction wrapping] | ANALOG: ResetAiCredits:34 wraps all operations in `ApplicationRecord.transaction do` — update + ledger rows are atomic | OURS: ApplyAiCreditPurchase#apply_subscription:109-132 performs update, finalize_stripe_payment, ledger save, and notification clear as separate non-atomic operations — partial failure leaves inconsistent state | SANCTIONED: no

DEVIATION: [Extra finalize_stripe_payment call] | ANALOG: stripe_webhook_handler_job.rb:271-280 main-plan path has no `finalize_stripe_payment` call and Organization has no such method — payment finalization is implicit from the invoice.paid event | OURS: ApplyAiCreditPurchase#apply_subscription:117 calls `existing.finalize_stripe_payment` which sets `stripe_invoice_paid = true` via `update_columns` — extra step with no analog | SANCTIONED: no

DEVIATION: [Ledger description says "first invoice" for all renewals] | ANALOG: ResetAiCredits:58 uses dynamic description `"Monthly credit grant for #{organization.plan}"` | OURS: ApplyAiCreditPurchase#apply_subscription:125 hardcodes `'Credit pack subscription first invoice'` — this same code handles renewal invoices too (idempotency guard on line 103 only prevents processing the SAME invoice twice, not subsequent invoices), so the description is misleading for renewals | SANCTIONED: no

DEVIATION: [Error handling mechanism: raise+rescue vs context.fail!] | ANALOG: stripe_webhook_handler_job.rb:271 uses `raise CustomStripeSubscriptionMissingError` which propagates to `rescue StandardError` on line 287 — errors are logged with full context | OURS: ApplyAiCreditPurchase uses `context.fail!` throughout (lines 94, 98, 106, 137) — failures do not propagate as exceptions, are not caught by the webhook handler's rescue blocks, and produce no `ap` output in the job log | SANCTIONED: no

DEVIATION: [handle_subscription_credit_pack_invoice_paid updates stripe_amount/currency/stripe_invoice_item_id separately from ApplyAiCreditPurchase] | ANALOG: stripe_webhook_handler_job.rb:273-280 main-plan path performs ONE update on organization then calls stripe_update_default_payment_method then calls reset_ai_credits — all operations on the same record in sequence | OURS: handle_subscription_credit_pack_invoice_paid:466-470 updates purchase (stripe_amount, currency, stripe_invoice_item_id), then ApplyAiCreditPurchase#apply_subscription:109-114 updates the SAME purchase again (subscription_status, period_start, period_end, stripe_invoice_id) — two separate updates to the same record split across two call sites | SANCTIONED: no

---NEXT DIMENSION---

`SmallButton` wraps `Button` with `size="small"`. The analog PlanCard passes `loading` to the `Styled.Button` which extends `SmallButton`. The AI credit version doesn't pass `loading`. Since `SmallButton` wraps `Button` (which likely supports `loading`), this is a missing behavioral prop.

Now I have all the information I need to compile the full deviation report.

---

DEVIATION REPORT: AI Credit Subscription Change (Portal) vs BillingController Analog

---

DEVIATION: PosthogTrackJob event name not differentiated | ANALOG: billing_controller.rb:311 uses `'change_subscription_stripe_portal_opened'` | OURS: organization_ai_credit_purchases_controller.rb:186 uses identical `'change_subscription_stripe_portal_opened'` | SANCTIONED: no
Per Sub change #5 (ai_credit_* descriptor naming), the event should be differentiated, e.g. `'ai_credit_change_subscription_stripe_portal_opened'`.

DEVIATION: No new-subscription vs change-subscription branching in component click handler | ANALOG: PlanCard.tsx:98-105 `handleOnClickSubscriptionAction` branches on `hasActiveSubscription` -- calls `handleChangeSubscription()` if true, `onCreateNewSubscription()` if false | OURS: AiSubscriptionTierCard.tsx:62 always calls `onSelect(tier)` which maps to `handleSelectTier` which always calls portal change/update flow (requires existing subscription); no branch for new subscription checkout | SANCTIONED: no
Result: non-subscribed users clicking a tier card will hit `raise StandardError, 'Subscription item ID is missing.'` on the backend because `currentSubscriptionItemId` is null.

DEVIATION: `subscribe` mutate function from `useCheckoutAiCreditPack` destructured but never called | ANALOG: n/a (analog uses separate checkout page) | OURS: AiCreditSubscription.tsx:36 destructures `{ mutate: subscribe, isLoading: isSubscribing }` but `subscribe` is never invoked anywhere in the component | SANCTIONED: no
Dead code. `isSubscribing` is used in the `isLoading` prop (line 254) but can never be true since `subscribe` is never called.

DEVIATION: `isLoadingBalance` destructured but never used | ANALOG: n/a | OURS: AiCreditSubscription.tsx:28 `const { isLoading: isLoadingBalance } = useOrganizationAiCreditBalance()` -- never referenced | SANCTIONED: no
Dead code.

DEVIATION: `isLoadingSubscription` destructured but never used | ANALOG: n/a | OURS: AiCreditSubscription.tsx:29 `const { data: subscription, isLoading: isLoadingSubscription }` -- `isLoadingSubscription` never referenced | SANCTIONED: no
Dead code.

DEVIATION: `hasActiveSubscription` prop accepted but never used in AiSubscriptionTierCard | ANALOG: PlanCard.tsx:81 `hasActiveSubscription` is used in `handleOnClickSubscriptionAction` (line 100) and in JSX (line 200 for ManageBillingActions) | OURS: AiSubscriptionTierCard.tsx:21,29 `hasActiveSubscription` is declared in interface and destructured but never referenced in component body or JSX | SANCTIONED: no
Dead prop.

DEVIATION: Missing `loading` prop on tier card button | ANALOG: PlanCard.tsx:209 passes `loading={isLoadingButton}` to the SmallButton (shows spinner while subscription data fetches) | OURS: AiSubscriptionTierCard.tsx:63 passes only `disabled={isLoading}` -- no `loading` prop on the SmallButton | SANCTIONED: no
Analog button has both `loading` (spinner) and `disabled` (click prevention). AI credit button has only `disabled`.

DEVIATION: Missing `trackEvent` call on tier selection | ANALOG: PlanCard.tsx:99 calls `trackEvent("plan_selected", { current_plan_lookup_key, selected_plan_name, selected_plan_key, selected_plan_billing_period })` in `handleOnClickSubscriptionAction` | OURS: AiSubscriptionTierCard.tsx:62 `onClick={() => onSelect(tier)}` -- no trackEvent call; AiCreditSubscription.tsx `handleSelectTier` also has no trackEvent | SANCTIONED: no

DEVIATION: Missing render-level `window.logger` diagnostic calls in component | ANALOG: AccountBillingPlans.tsx:144-152 has `window.logger("%c[AccountBillingPlans] PlanInformation", ...)` with diagnostic data, and line 195-209 has `window.logger("%c[AccountBillingPlans] render", ...)` with full state dump | OURS: AiCreditSubscription.tsx has no render-level or PlanInformation-level window.logger calls | SANCTIONED: no
REVERT: These are diagnostic logging calls. The analog has them for debugging. The AI credit version should have equivalent diagnostic logging for consistency, but they are cosmetic and could be added later.

DEVIATION: Extra query invalidation in hooks | ANALOG: useBilling.ts `useChangeSubscriptionViaStripePortal` invalidates only `["currentOrganization"]`; `useUpdateWithPaymentMethod` invalidates only `["currentOrganization"]` | OURS: useOrganizationAiCreditPurchase.ts `useChangeAiCreditSubscriptionViaStripePortal` invalidates `["currentOrganization"]` AND `["organizationAiCreditPurchase"]`; `useUpdateAiCreditSubscriptionWithPaymentMethod` invalidates `["currentOrganization"]` AND `["organizationAiCreditPurchase"]` | SANCTIONED: no
WHITELIST: The extra `["organizationAiCreditPurchase"]` invalidation is necessary because AI credit subscription state is stored in a separate query cache from the organization. Without it, the subscription status shown in `AiSubscriptionStatus` would be stale after a plan change.

DEVIATION: window.logger label string matches function name (AI credit) vs mismatches (analog) | ANALOG: useBilling.ts:185 logger says `useChangePlanStripePortalSession` but function is `useChangeSubscriptionViaStripePortal` | OURS: useOrganizationAiCreditPurchase.ts:54 logger says `useChangeAiCreditSubscriptionViaStripePortal` which matches the function name | SANCTIONED: no
REVERT: The analog has a stale logger label. The AI credit version is actually more correct. No action needed -- this is a case where the AI credit code improved on the analog's mistake.

DEVIATION: `returnUrl` in component handlers points to different path | ANALOG: AccountBillingPlans.tsx:254,294 uses `returnUrl: "/hire/settings/billing"` | OURS: AiCreditSubscription.tsx:78,118 uses `returnUrl: "/hire/settings/plato-ai/billing"` | SANCTIONED: yes
This is the correct return URL for the AI credit subscription page.

DEVIATION: `determine_price_id` fallback uses different predicate | ANALOG: billing_controller.rb:637 falls back to `price.lookup_key == DEFAULT_PRICE_LOOKUP_KEY` (exact match against `'plan_simple_ats_per_job_tiered'`) | OURS: organization_ai_credit_purchases_controller.rb:399 falls back to `OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?(price.lookup_key)` (method call, matches potentially multiple keys) | SANCTIONED: yes
Per Sub change #5 (ai_credit_* descriptor naming), the fallback must use AI credit lookup keys.

---NEXT DIMENSION---

Good. Now I have the full picture. Let me compile the findings.

---

## customer.subscription.updated — Deviations

**ANALOG** (develop branch, lines 111-137): Unconditionally runs `organization.update(...)` + `stripe_update_default_payment_method` + `sync_with_stripe` inside `begin/rescue`.

**OURS** (billing-bonanza, lines 111-165): Adds an `if/elsif` branch. The `if` branch handles credit-pack subscriptions; the `elsif` branch wraps the original analog code with a guard `object.id == organization&.stripe_subscription_id`.

DEVIATION: main-plan guard added | ANALOG: stripe_webhook_handler_job.rb:125-131 unconditionally runs organization.update + sync_with_stripe for any subscription.updated event | OURS: stripe_webhook_handler_job.rb:149 wraps main-plan path in `elsif object.id == organization&.stripe_subscription_id`, which means a subscription.updated event for an unknown subscription (neither credit-pack nor main-plan) silently drops instead of running the analog's unconditional path | SANCTIONED: yes — this is a necessary consequence of Sub change #2. Without this guard, credit-pack subscription.updated events would clobber org plan fields. The analog had no concept of multiple subscriptions per customer, so it ran unconditionally. The elsif guard correctly partitions events.

DEVIATION: credit-pack branch existence | ANALOG: stripe_webhook_handler_job.rb:125 no credit-pack branch exists | OURS: stripe_webhook_handler_job.rb:125-148 adds 24-line if-branch for `OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?` | SANCTIONED: yes — Sub change #2, operates on OrganizationAiCreditPurchase record.

DEVIATION: credit-pack branch updates purchase period fields | ANALOG: (none) | OURS: stripe_webhook_handler_job.rb:139-140 updates `subscription_current_period_start` and `subscription_current_period_end` on the purchase | SANCTIONED: yes — Sub change #2, these are OrganizationAiCreditPurchase-specific fields that have no analog on Organization.

DEVIATION: credit-pack branch error logging pattern | ANALOG: stripe_webhook_handler_job.rb:132-136 uses `rescue StandardError => e` with `ap` + `Rails.logger.error` | OURS: stripe_webhook_handler_job.rb:142-148 uses inline `unless updated` + `Rails.logger.error` + `else` branch logging instead of rescue. The credit-pack branch has its own error handling INSIDE the begin/rescue that wraps both branches, so validation failures are logged differently than the analog's rescue pattern | SANCTIONED: no — the analog's error handling for the main-plan branch is `rescue StandardError => e` with `ap` + `Rails.logger.error`. The credit-pack branch uses a different pattern: inline `unless updated` check + explicit `else` for missing purchase. This is a minor structural deviation but not sanctioned by any of the listed changes.

---

## customer.subscription.deleted — Deviations

**ANALOG** (develop branch, lines 138-160): No credit-pack branch at all. Fires these side effects unconditionally:
1. `sync_with_stripe` — guarded by `stripe_subscription_id == organization&.stripe_subscription_id` (line 179)
2. `organization&.update_column(:subscription_canceled_at, ...)` — **UNCONDITIONAL** (line 182)
3. `Notification::PaidSubscriptionDeletedJob.perform_later(...)` — **UNCONDITIONAL** (line 183)
4. `EngagementReport::GeneratorJob.perform_later(...)` — **UNCONDITIONAL** (line 184)

**OURS** (billing-bonanza, lines 167-188): **IDENTICAL** to the analog. No credit-pack branch was added.

DEVIATION: no credit-pack branch in customer.subscription.deleted | ANALOG: stripe_webhook_handler_job.rb:138-160 fires sync_with_stripe (guarded), update_column(:subscription_canceled_at), PaidSubscriptionDeletedJob, and EngagementReport::GeneratorJob unconditionally for any subscription deletion | OURS: stripe_webhook_handler_job.rb:167-188 identical — no if/elsif to distinguish credit-pack subscriptions from main-plan subscriptions | SANCTIONED: no

This is a **functional bug**. When a credit-pack subscription is canceled/deleted by Stripe:

1. **`sync_with_stripe` is correctly skipped** (line 179 guard: `stripe_subscription_id == organization&.stripe_subscription_id` will be false for a credit-pack subscription ID). Note: even if it DID fire, `sync_with_stripe` itself already filters out credit subscriptions at line 539-541 of organization.rb.

2. **`update_column(:subscription_canceled_at, ...)` fires UNCONDITIONALLY** (line 182). This sets `subscription_canceled_at` on the organization to the credit-pack subscription's end time. This is WRONG — it records a main-plan cancellation timestamp when only a credit-pack subscription was canceled. This could cause downstream code that checks `subscription_canceled_at` to believe the org's main plan was canceled.

3. **`Notification::PaidSubscriptionDeletedJob` fires UNCONDITIONALLY** (line 183). This sends a "your paid subscription was deleted" notification when only a credit-pack subscription was canceled. The user gets a misleading notification.

4. **`EngagementReport::GeneratorJob` fires UNCONDITIONALLY** (line 184) with `trigger: 'subscription_canceled'`. This generates an engagement report as if the main plan was canceled.

The fix should mirror the pattern from `customer.subscription.updated`: add an `if/elsif` structure that routes credit-pack subscription deletions to update the `OrganizationAiCreditPurchase` record (set `subscription_status: :canceled`) and skips the main-plan side effects. The main-plan path should be guarded with `stripe_subscription_id == organization&.stripe_subscription_id` (which the `sync_with_stripe` call already has, but lines 182-184 do not).

Additionally, the credit-pack branch in `subscription.deleted` should update the purchase record's `subscription_status` to `canceled` — without that, the purchase record's status will remain `active` even after Stripe has deleted the subscription.

DEVIATION: no purchase status update on credit-pack subscription deletion | ANALOG: (N/A, no credit-pack concept in analog) | OURS: stripe_webhook_handler_job.rb:167-188 does not update OrganizationAiCreditPurchase.subscription_status when the credit-pack subscription is deleted by Stripe | SANCTIONED: no — the subscription.updated handler (line 138) correctly updates `subscription_status: object.status` on the purchase record, but the deletion handler has no equivalent code path. After a Stripe `customer.subscription.deleted` event for a credit-pack subscription, the purchase record will still show `subscription_status: :active`.

---

## Summary of all deviations

DEVIATION: main-plan guard added to subscription.updated | ANALOG: stripe_webhook_handler_job.rb:125 unconditional org update | OURS: stripe_webhook_handler_job.rb:149 `elsif object.id == organization&.stripe_subscription_id` | SANCTIONED: yes (Sub change #2)

DEVIATION: credit-pack branch added to subscription.updated | ANALOG: (none) | OURS: stripe_webhook_handler_job.rb:125-148 | SANCTIONED: yes (Sub change #2)

DEVIATION: credit-pack branch updates period start/end fields | ANALOG: (none) | OURS: stripe_webhook_handler_job.rb:139-140 | SANCTIONED: yes (Sub change #2)

DEVIATION: credit-pack branch error handling pattern differs from analog rescue pattern | ANALOG: stripe_webhook_handler_job.rb:132-136 uses rescue with ap + Rails.logger.error | OURS: stripe_webhook_handler_job.rb:142-148 uses inline `unless updated` + else-branch logging inside the shared rescue | SANCTIONED: no

DEVIATION: no credit-pack branch in customer.subscription.deleted | ANALOG: stripe_webhook_handler_job.rb:138-160 fires all side effects unconditionally | OURS: stripe_webhook_handler_job.rb:167-188 identical to analog — no routing for credit-pack subscriptions | SANCTIONED: no

DEVIATION: subscription_canceled_at set on org when credit-pack subscription is deleted | ANALOG: stripe_webhook_handler_job.rb:153 `update_column(:subscription_canceled_at, ...)` unconditional (no credit-pack concept existed) | OURS: stripe_webhook_handler_job.rb:182 same unconditional call fires for credit-pack subscription deletions, incorrectly recording a main-plan cancellation timestamp | SANCTIONED: no

DEVIATION: PaidSubscriptionDeletedJob fires for credit-pack subscription deletion | ANALOG: stripe_webhook_handler_job.rb:154 unconditional (no credit-pack concept existed) | OURS: stripe_webhook_handler_job.rb:183 same unconditional call sends misleading "paid subscription deleted" notification for credit-pack cancellation | SANCTIONED: no

DEVIATION: EngagementReport::GeneratorJob fires for credit-pack subscription deletion | ANALOG: stripe_webhook_handler_job.rb:155 unconditional (no credit-pack concept existed) | OURS: stripe_webhook_handler_job.rb:184 same unconditional call generates engagement report with trigger 'subscription_canceled' for credit-pack cancellation | SANCTIONED: no

DEVIATION: no purchase record status update on credit-pack subscription deletion | ANALOG: (N/A) | OURS: stripe_webhook_handler_job.rb:167-188 OrganizationAiCreditPurchase.subscription_status remains 'active' after Stripe deletes the credit-pack subscription | SANCTIONED: no
