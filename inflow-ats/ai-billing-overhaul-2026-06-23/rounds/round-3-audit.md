# Round 3 — Audit Results

`amount_cents_paid` doesn't appear in the model at all (it's used in the webhook handler for subscription renewals). The model validates `stripe_amount` not `amount_cents_paid`. This is an inconsistency between the subscription and one-off payment recording patterns, but it's outside the one-off comparison scope.

Let me also check if the `calculate_charge_amount` is called from both the model's `charge_for_listing` and the controller's checkout session.

In the model's `charge_for_listing` (line 186): `amount = calculate_charge_amount` -- this makes a Stripe API call.
In the controller's `create_top_up_checkout_session` (line 108): `amount = @purchase.calculate_charge_amount` -- also makes a Stripe API call.

So `calculate_charge_amount` is called TWICE in the checkout flow -- once in the controller and... wait, is `charge_for_listing` even called in the checkout flow? No, it's not. The checkout flow creates a Stripe Checkout Session and payment is handled by the webhook. So `calculate_charge_amount` is called only once in the checkout path (in the controller). And in the direct charge path (`create_top_up`), the controller calls `charge_default_payment_method` (which doesn't exist, so `calculate_charge_amount` is never reached).

Now I have enough information for the full report.

---

DEVIATION: [controller create_top_up calls nonexistent method] | ANALOG: board_wwr_listings_controller.rb:22 calls `@listing.charge_for_listing` (method exists on BoardWwrListing at line 112) | OURS: organization_ai_credit_purchases_controller.rb:83 calls `@purchase.charge_default_payment_method` (method does not exist anywhere in the codebase; OrganizationAiCreditPurchase defines `charge_for_listing` at line 185) | SANCTIONED: no

DEVIATION: [model charge_for_listing is dead code] | ANALOG: board_wwr_listing.rb:112 `charge_for_listing` is called from controller create action (line 22) and from after_update callback (line 69) | OURS: organization_ai_credit_purchase.rb:185 `charge_for_listing` is defined but never called from any controller, webhook, or callback -- the controller calls the nonexistent `charge_default_payment_method` instead, and the checkout/webhook path never invokes it | SANCTIONED: no

DEVIATION: [model method naming: charge_for_listing] | ANALOG: board_wwr_listing.rb:112 `charge_for_listing` -- named for what it does (charges for a listing) | OURS: organization_ai_credit_purchase.rb:185 `charge_for_listing` -- misleading name, this is not a listing, it charges for an AI credit one-off purchase | SANCTIONED: no

DEVIATION: [model calculate_charge_amount makes Stripe API call instead of local calculation] | ANALOG: board_wwr_listing.rb:84 `calculate_charge_amount` computes price locally from plan enum and discount percentage, zero external calls | OURS: organization_ai_credit_purchase.rb:177 `calculate_charge_amount` calls `Stripe::Price.list(...)` -- a network call to Stripe on every invocation; raises on missing price | SANCTIONED: no

DEVIATION: [model grant_one_off_credits missing rescue StandardError block] | ANALOG: board_wwr_listing.rb:197-200 `create_on_wwr` has `rescue StandardError => e` with logging | OURS: organization_ai_credit_purchase.rb:129-162 `grant_one_off_credits` has NO rescue block -- exceptions propagate unhandled to the webhook job | SANCTIONED: no

DEVIATION: [model broadcast_event uses GlobalChannel instead of JobChannel] | ANALOG: board_wwr_listing.rb:267-268 `broadcast_event` uses `JobChannel.broadcast_to(job, ...)` with payload `{ jobId: job.id, boardWwrListingId: id, wwrSlug: wwr_slug, publishedAt: published_at }` | OURS: organization_ai_credit_purchase.rb:164-165 `broadcast_event` uses `GlobalChannel.broadcast_to(organization.owner, ...)` with payload `{ organizationId: organization.id, organizationAiCreditPurchaseId: id }` | SANCTIONED: yes (Sub change #2 -- operates on org, not job; no JobChannel target available)

DEVIATION: [model broadcast_show_growl always targets organization.owner] | ANALOG: board_wwr_listing.rb:272-273 `broadcast_show_growl` targets `last_updated_by_organization_user_id.nil? ? job.organization.owner : last_updated_by_organization_user.user` (conditional recipient) | OURS: organization_ai_credit_purchase.rb:168-169 `broadcast_show_growl` always targets `organization.owner` (no conditional) | SANCTIONED: yes (Sub change #2 -- model has no `last_updated_by_organization_user` association)

DEVIATION: [webhook handler calls broadcast_event in webhook body, not inside post-payment method] | ANALOG: stripe_webhook_handler_job.rb:217-218 WWR branch calls `listing.finalize_stripe_payment` then `listing.create_on_wwr` (broadcast happens INSIDE create_on_wwr at line 193) | OURS: stripe_webhook_handler_job.rb:248-252 AI credit branch calls `purchase.finalize_stripe_payment`, then `purchase.broadcast_event('ai_credit_top_up_payment_received')` in the webhook body, then `purchase.grant_one_off_credits` (which ALSO broadcasts 'ai_credit_top_up_purchased' at line 158) -- result is TWO broadcasts instead of one | SANCTIONED: no

DEVIATION: [webhook handler has extra Rails.logger.info between finalize and action] | ANALOG: stripe_webhook_handler_job.rb:217-218 WWR branch calls `listing.finalize_stripe_payment` then immediately `listing.create_on_wwr` with no log line between | OURS: stripe_webhook_handler_job.rb:248-252 follows WhatJobs pattern (broadcast between finalize and action) rather than WWR pattern | SANCTIONED: no

DEVIATION: [model no after_update callback] | ANALOG: board_wwr_listing.rb:9 has `after_update :handle_after_update` which calls `charge_for_listing unless stripe_invoice_paid` (line 69) | OURS: organization_ai_credit_purchase.rb has no after_update callback -- no automatic re-charge mechanism | SANCTIONED: yes (Sub change #2 -- AI credit one-off purchases do not need re-charge on update; they are single-use)

DEVIATION: [model charge_for_listing uses @description instead of @final_description for InvoiceItem] | ANALOG: board_wwr_listing.rb:134 InvoiceItem `description: @final_description` (includes discount info via `@final_description` computed on line 126) | OURS: organization_ai_credit_purchase.rb:204 InvoiceItem `description: @description` (no discount concept) | SANCTIONED: yes (Sub change #5 -- AI credit one-off purchases have no discount mechanism)

DEVIATION: [model charge_for_listing missing comment "# defensive check..."] | ANALOG: board_wwr_listing.rb:119 has comment `# defensive check shouldn't be necessary since we only call this after_create but worth it anyway` | OURS: organization_ai_credit_purchase.rb charge_for_listing has no corresponding comment | SANCTIONED: no

DEVIATION: [controller create_top_up_checkout_session stores checkout_session_id on purchase] | ANALOG: board_wwr_listings_controller.rb:51-128 create_checkout_session does NOT store the Stripe checkout session ID on the listing record | OURS: organization_ai_credit_purchases_controller.rb:151 calls `@purchase.update(stripe_checkout_session_id: session.id)` after creating session -- extra database write not present in analog | SANCTIONED: no

DEVIATION: [controller create_top_up_checkout_session uses update instead of update_columns] | ANALOG: (no equivalent storage in WWR) | OURS: organization_ai_credit_purchases_controller.rb:151 uses `@purchase.update(stripe_checkout_session_id: session.id)` which fires validations and callbacks, unlike the analog pattern of using `update_columns` for Stripe field updates (e.g., board_wwr_listing.rb:158, board_wwr_listing.rb:167) | SANCTIONED: no

DEVIATION: [notification job captures exception variable] | ANALOG: paid_wwr_listing_created_job.rb:12 has `rescue ActiveRecord::RecordNotFound` (no `=> e`) but references `e` on line 14 -- this is a bug in the analog, `e` is undefined | OURS: ai_credit_top_up_purchased_job.rb:12 has `rescue ActiveRecord::RecordNotFound => e` (captures exception) -- fixes the analog's bug | REVERT: no -- the analog has a bug (undefined `e`); the AI credit version correctly captures `=> e`

DEVIATION: [notification job perform arguments differ] | ANALOG: paid_wwr_listing_created_job.rb:6 `perform(organization_id, job_id)` -- second arg is job_id, finds job via org association | OURS: ai_credit_top_up_purchased_job.rb:6 `perform(organization_id, purchase_id)` -- second arg is purchase_id, finds purchase directly | SANCTIONED: yes (Sub change #2 -- operates on purchase record not job)

DEVIATION: [notification job finds record via class method not association] | ANALOG: paid_wwr_listing_created_job.rb:8 `@job = @organization.jobs.find(job_id)` -- scoped through org association | OURS: ai_credit_top_up_purchased_job.rb:8 `@purchase = OrganizationAiCreditPurchase.find(purchase_id)` -- global find, not scoped through organization | SANCTIONED: no

DEVIATION: [model is_active? for one-off uses stripe_invoice_paid? instead of expires_at + status check] | ANALOG: board_wwr_listing.rb:54-56 `is_active?` checks `expires_at.present? && expires_at > DateTime.now && approved?` | OURS: organization_ai_credit_purchase.rb:122 one-off branch returns `stripe_invoice_paid?` -- no expiration or status check | SANCTIONED: yes (one-off AI credit purchases have no expiration and no approval status)

DEVIATION: [model charge_for_listing guard condition uses is_active? with different semantics] | ANALOG: board_wwr_listing.rb:115 `if stripe_invoice_id.present? && is_active?` guards against charging an active listing (checks expiry + approved status) | OURS: organization_ai_credit_purchase.rb:188 `if stripe_invoice_id.present? && is_active?` -- for one-off, `is_active?` returns `stripe_invoice_paid?`, so the guard is `stripe_invoice_id.present? && stripe_invoice_paid?` which is semantically different (checks paid status, not expiry) | SANCTIONED: yes (one-off purchases don't expire)

DEVIATION: [controller create_top_up_checkout_session product_data.name format differs] | ANALOG: board_wwr_listings_controller.rb:87 product_data name is `"#{job.title} - We Work Remotely Job Listing"` (entity name first) | OURS: organization_ai_credit_purchases_controller.rb:120 product_data name is `"#{@description} - Plato AI Credit Top-Up"` where @description already contains the pack name -- results in redundant text like "Plato AI Credit Top-Up - Small - Plato AI Credit Top-Up" | SANCTIONED: no

DEVIATION: [controller create_top_up_checkout_session invoice_data.metadata omits equivalent of job_id] | ANALOG: board_wwr_listings_controller.rb:106-108 invoice_data.metadata includes `board_wwr_listing_id` AND `job_id` (two keys) | OURS: organization_ai_credit_purchases_controller.rb:137-139 invoice_data.metadata includes `organization_ai_credit_purchase_id` AND `organization_id` (two keys, but organization_id replaces job_id) | SANCTIONED: yes (Sub change #2 -- org-level, no job)

DEVIATION: [controller create_top_up_checkout_session missing job_id equivalent in payment_intent_data.metadata] | ANALOG: board_wwr_listings_controller.rb:95-99 payment_intent_data.metadata has 3 keys: listing_id, organization_id, job_id | OURS: organization_ai_credit_purchases_controller.rb:129-131 payment_intent_data.metadata has 2 keys: purchase_id, organization_id | SANCTIONED: yes (Sub change #2 -- no job)

DEVIATION: [controller create_top_up_checkout_session missing job_id equivalent in session-level metadata] | ANALOG: board_wwr_listings_controller.rb:112-115 session-level metadata has 3 keys: listing_id, organization_id, job_id | OURS: organization_ai_credit_purchases_controller.rb:143-145 session-level metadata has 2 keys: purchase_id, organization_id | SANCTIONED: yes (Sub change #2 -- no job)

---NEXT DIMENSION---

The WhatJobs handler has `Rails.logger.info "WhatJobs listing #{listing_id} payment confirmed"` between `finalize_stripe_payment` and `broadcast_event`. The AI credit handler does NOT have this logging line.

Now I have all the data I need. Let me compile the full deviation report.

DEVIATION: [Model charge_for_listing logging style - "Attempt to charge"] | ANALOG: board_what_jobs_listing.rb:158 uses `ap 'Attempt to charge for WhatJobs Listing'` | OURS: organization_ai_credit_purchase.rb:187 uses `Rails.logger.info 'Attempt to charge for AI Credit Top-Up'` | SANCTIONED: no

DEVIATION: [Model charge_for_listing logging style - "Charging..."] | ANALOG: board_what_jobs_listing.rb:170 uses `ap 'Charging...'` | OURS: organization_ai_credit_purchase.rb:198 uses `Rails.logger.info 'Charging...'` | SANCTIONED: no

DEVIATION: [Model charge_for_listing logging style - "Invoice Has Been Finalized"] | ANALOG: board_what_jobs_listing.rb:195 uses `ap 'Invoice Has Been Finalized'` | OURS: organization_ai_credit_purchase.rb:223 uses `Rails.logger.info 'Invoice Has Been Finalized'` | SANCTIONED: no

DEVIATION: [Model charge_for_listing extra log line] | ANALOG: board_what_jobs_listing.rb:195-197 does NOT log `[invoice_item, paid_invoice]` after "Invoice Has Been Finalized" | OURS: organization_ai_credit_purchase.rb:224 adds `Rails.logger.info [invoice_item, paid_invoice]` | SANCTIONED: no
REVERT: This follows the WWR pattern (board_wwr_listing.rb:161) rather than the WhatJobs pattern. Since we're comparing against WhatJobs, it's a deviation, but it matches the other analog and is cosmetic logging.

DEVIATION: [Model charge_for_listing guard condition] | ANALOG: board_what_jobs_listing.rb:160 uses `live?` (checks expiration + active status enum) | OURS: organization_ai_credit_purchase.rb:188 uses `is_active?` (checks `stripe_invoice_paid?` for one-off) | SANCTIONED: no
WHITELIST: AI credit one-off purchases have no expiration date concept. `is_active?` for one_off returns `stripe_invoice_paid?` which is the correct semantic equivalent. Matching `live?` literally would require fabricating expiration logic that doesn't exist.

DEVIATION: [Model charge_for_listing guard message] | ANALOG: board_what_jobs_listing.rb:161 uses `ap 'Already charged for this listing'` | OURS: organization_ai_credit_purchase.rb:189 uses `ap 'Already charged for this AI credit one-off purchase'` | SANCTIONED: no

DEVIATION: [Model charge_for_listing organization resolution] | ANALOG: board_what_jobs_listing.rb:165 resolves `organization = job.organization` (listing belongs to job) | OURS: organization_ai_credit_purchase.rb:193 accesses `organization` directly (purchase belongs_to organization) | SANCTIONED: yes (Sub change #2)

DEVIATION: [Model charge_for_listing description format] | ANALOG: board_what_jobs_listing.rb:168 uses `"WhatJobs Job listing - #{job.title}"` | OURS: organization_ai_credit_purchase.rb:195-196 uses `"#{pack_name} - #{organization.name}"` (pack name + org name instead of product + job title) | SANCTIONED: yes (Sub change #5 + Sub change #2, no job context)

DEVIATION: [Model charge_for_listing Stripe Invoice description] | ANALOG: board_what_jobs_listing.rb:185 uses `'WhatJobs Listing'` | OURS: organization_ai_credit_purchase.rb:213 uses `'AI Credit Top-Up'` | SANCTIONED: yes (Sub change #5)

DEVIATION: [Model charge_for_listing Stripe metadata key] | ANALOG: board_what_jobs_listing.rb:178-179/187-188 uses `board_what_jobs_listing_id: id` | OURS: organization_ai_credit_purchase.rb:206-207/215-216 uses `organization_ai_credit_purchase_id: id` | SANCTIONED: yes (Sub change #2)

DEVIATION: [Model calculate_charge_amount implementation] | ANALOG: board_what_jobs_listing.rb:151-153 hardcodes `17_500` ($175 flat rate) | OURS: organization_ai_credit_purchase.rb:177-183 calls `Stripe::Price.list` to fetch price from Stripe API at runtime | SANCTIONED: no
WHITELIST: AI credit purchases have multiple price tiers determined by `stripe_price_lookup_key`. Hardcoding all possible prices would be fragile and inconsistent with the Stripe-as-source-of-truth design. The Stripe API call is necessary because there are multiple products with prices set in Stripe.

DEVIATION: [Model finalize_stripe_payment] | ANALOG: board_what_jobs_listing.rb:200-202 identical `update_columns(stripe_invoice_paid: true)` | OURS: organization_ai_credit_purchase.rb:114-116 identical | SANCTIONED: n/a (exact match)

DEVIATION: [Model broadcast_event channel] | ANALOG: board_what_jobs_listing.rb:288-289 broadcasts to `JobChannel.broadcast_to(job, ...)` with `jobId:` and `boardWhatJobsListingId:` keys | OURS: organization_ai_credit_purchase.rb:164-165 broadcasts to `GlobalChannel.broadcast_to(organization.owner, ...)` with `organizationId:` and `organizationAiCreditPurchaseId:` keys | SANCTIONED: yes (Sub change #2, no job association)

DEVIATION: [Model broadcast_show_growl user resolution] | ANALOG: board_what_jobs_listing.rb:292-293 resolves target user via `last_updated_by_organization_user_id.nil? ? job.organization.owner : last_updated_by_organization_user.user` | OURS: organization_ai_credit_purchase.rb:168-169 always broadcasts to `organization.owner` | SANCTIONED: yes (Sub change #2, no last_updated_by_organization_user column)

DEVIATION: [Model missing broadcast_error_growl] | ANALOG: board_what_jobs_listing.rb:296-298 has `broadcast_error_growl` method | OURS: organization_ai_credit_purchase.rb has no `broadcast_error_growl` | SANCTIONED: no
WHITELIST: `broadcast_error_growl` is only used in `sync_with_what_jobs` for WhatJobs API sync validation failures. AI credit one-off purchases have no API sync step, so there is no callsite for this method. Adding it would be dead code.

DEVIATION: [Model grant_one_off_credits double-broadcast] | ANALOG: board_what_jobs_listing.rb `create_on_what_jobs` (lines 204-209) does NOT call `broadcast_event` or `broadcast_show_growl` (those are called from the webhook handler) | OURS: organization_ai_credit_purchase.rb `grant_one_off_credits` (lines 158-159) calls BOTH `broadcast_event('ai_credit_top_up_purchased')` AND `broadcast_show_growl('AI Credit Top-Up purchased')` | SANCTIONED: no

DEVIATION: [Model grant_one_off_credits fires notification job] | ANALOG: board_what_jobs_listing.rb `create_on_what_jobs` does NOT fire a notification job (WhatJobs has no paid-listing notification job) | OURS: organization_ai_credit_purchase.rb:161 fires `Notification::AiCreditTopUpPurchasedJob.perform_later(organization.id, id)` | SANCTIONED: no
WHITELIST: The WWR analog (`create_on_wwr`, board_wwr_listing.rb:196) fires `Notification::PaidWwrListingCreatedJob.perform_later`. WhatJobs simply lacks this notification. Removing the notification job would remove operational visibility for a new purchase type. The deviation follows WWR's pattern, which is the more complete analog.

DEVIATION: [Model grant_one_off_credits notification-resets] | ANALOG: board_what_jobs_listing.rb `create_on_what_jobs` does not touch notification timestamps | OURS: organization_ai_credit_purchase.rb:149-154 `grant_one_off_credits` resets `low_credit_notification_sent_at`, `zero_credit_notification_sent_at`, `sent_low_notification_since_increase`, `sent_zero_notification_since_increase` on the balance | SANCTIONED: no
WHITELIST: This is AI credit billing-specific behavior with no analog in job-board listings. When credits are purchased, notification dedup flags must be cleared so low-balance notifications can re-fire. Job-board listings have no credit balance concept.

DEVIATION: [Model extra method: stripe_subscription] | ANALOG: board_what_jobs_listing.rb has no `stripe_subscription` method | OURS: organization_ai_credit_purchase.rb:229-233 has `stripe_subscription` method that retrieves subscription from Stripe | SANCTIONED: no
WHITELIST: This method supports the subscription management flow (controller `customer_subscription` action). It's subscription-specific infrastructure that has no analog in one-off listing payments.

DEVIATION: [Model extra class methods for lookup keys] | ANALOG: board_what_jobs_listing.rb has no class methods for price/lookup_key management | OURS: organization_ai_credit_purchase.rb:59-76 has `ai_credit_lookup_keys`, `ai_credit_subscription_plan_lookup_key?`, `ai_credit_top_up_lookup_key?`, `ai_credit_allocation_for_lookup_key` | SANCTIONED: no
WHITELIST: These class methods serve the multi-product pricing model (multiple pack sizes and subscription tiers). WhatJobs has a single flat price. Removing these would break the controller and webhook handler routing logic.

DEVIATION: [Model extra constant AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY] | ANALOG: board_what_jobs_listing.rb has no equivalent pricing constant | OURS: organization_ai_credit_purchase.rb:4-57 has `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` hash | SANCTIONED: no
WHITELIST: Same as above -- multi-product pricing requires a registry of known products. No analog exists because WhatJobs has one price.

DEVIATION: [Model extra validations] | ANALOG: board_what_jobs_listing.rb:16 has one custom validation (`cannot_update_inactive_listing`) and no presence validations on Stripe fields | OURS: organization_ai_credit_purchase.rb:86-112 has extensive validations on `stripe_price_lookup_key`, `kind`, `stripe_subscription_id`, `subscription_credits_per_period`, `stripe_amount`, `currency`, `one_off_credits_granted` | SANCTIONED: no
WHITELIST: WhatJobs listing is a simpler domain object. AI credit purchases handle both one-off and subscription kinds with lifecycle-conditional validations. These validations enforce data integrity for a financial record with a more complex lifecycle than a job listing.

DEVIATION: [Model extra enum: kind] | ANALOG: board_what_jobs_listing.rb has domain-specific enums (status, work_from, etc.) but no kind/type enum | OURS: organization_ai_credit_purchase.rb:81 has `enum kind: { one_off: 0, subscription: 1 }` | SANCTIONED: no
WHITELIST: The purchase record handles both one-off and subscription purchases in one table. This is architectural -- the kind enum routes behavior. No analog in single-purpose listing models.

DEVIATION: [Model extra enum: subscription_status] | ANALOG: board_what_jobs_listing.rb:18-23 has `status` enum (draft/active/paused/inactive) | OURS: organization_ai_credit_purchase.rb:82-84 has `subscription_status` enum with Stripe subscription statuses | SANCTIONED: no
WHITELIST: Subscription status tracking is subscription-specific infrastructure. WhatJobs listings don't have subscriptions.

DEVIATION: [Model extra association: ai_credit_balance_transactions] | ANALOG: board_what_jobs_listing.rb has no ledger association | OURS: organization_ai_credit_purchase.rb:79 has `has_many :ai_credit_balance_transactions` | SANCTIONED: no
WHITELIST: AI credit purchases create ledger entries for credit grants/refunds. Job-board listings have no ledger.

DEVIATION: [Model is_active? method semantics] | ANALOG: board_what_jobs_listing.rb:80-82 `live?` checks expiration + active status | OURS: organization_ai_credit_purchase.rb:118-124 `is_active?` has branch logic for subscription (period_end + status) and one-off (stripe_invoice_paid?) | SANCTIONED: no
WHITELIST: Different domain semantics. One-off purchases are "active" when paid; subscriptions are "active" when within the current period and status is active.

DEVIATION: [Webhook handler missing log line] | ANALOG: stripe_webhook_handler_job.rb:232 has `Rails.logger.info "WhatJobs listing #{listing_id} payment confirmed"` between finalize_stripe_payment and broadcast_event | OURS: stripe_webhook_handler_job.rb:247-251 has NO such log line between finalize and broadcast | SANCTIONED: no

DEVIATION: [Webhook handler double broadcast] | ANALOG: stripe_webhook_handler_job.rb:234 calls `listing.broadcast_event('what_jobs_listing_payment_received')` and `listing.create_on_what_jobs` which does NOT broadcast again | OURS: stripe_webhook_handler_job.rb:250 calls `purchase.broadcast_event('ai_credit_top_up_payment_received')` AND then `purchase.grant_one_off_credits` which calls `broadcast_event('ai_credit_top_up_purchased')` and `broadcast_show_growl(...)` again, resulting in 2 broadcast_event calls and 1 broadcast_show_growl for a single payment | SANCTIONED: no

DEVIATION: [Controller create_top_up calls nonexistent method] | ANALOG: board_what_jobs_listings_controller.rb:163 calls `@listing.charge_for_listing` (method exists at board_what_jobs_listing.rb:156) | OURS: organization_ai_credit_purchases_controller.rb:83 calls `@purchase.charge_default_payment_method` which DOES NOT EXIST on OrganizationAiCreditPurchase (model only has `charge_for_listing`) | SANCTIONED: no

DEVIATION: [Controller create_top_up authorize pattern] | ANALOG: board_what_jobs_listings_controller.rb:133 uses `authorize :billing, :checkout?` (headless policy, first line) | OURS: organization_ai_credit_purchases_controller.rb:80 uses `authorize @purchase` (record-based, after building record) | SANCTIONED: no

DEVIATION: [Controller create_top_up missing validation step] | ANALOG: board_what_jobs_listings_controller.rb:156-160 calls `ValidateWhatJobsListing.call(listing: @listing, job: job)` before charging | OURS: organization_ai_credit_purchases_controller.rb:68-91 does NOT call any validation interactor before charging | SANCTIONED: yes (Sub change #3, no ValidateSubscriptionChange / PlanFeatureGate / job-limit gate)

DEVIATION: [Controller create_top_up missing interactor for record creation] | ANALOG: board_what_jobs_listings_controller.rb:141-153 uses `CreateOrUpdateWhatJobsListingWithIntegration` interactor to create/update the listing | OURS: organization_ai_credit_purchases_controller.rb:69-74 creates `OrganizationAiCreditPurchase.new(...)` directly, no interactor | SANCTIONED: no
WHITELIST: WhatJobs requires a multi-step interactor because it handles both create and update with an associated `JobBoardIntegration` record, company description extraction, etc. AI credit one-off purchases are a simple record creation with no associated records or integration steps. Adding an interactor for a 4-field `new()` call would be unnecessary indirection.

DEVIATION: [Controller create_top_up missing Stripe::StripeError rescue] | ANALOG: board_what_jobs_listings_controller.rb:171-174 rescues `Stripe::StripeError` with message "Payment failed: #{e.message}" | OURS: organization_ai_credit_purchases_controller.rb:88-91 rescues only `StandardError` | SANCTIONED: no

DEVIATION: [Controller create_top_up_checkout_session saves record before session creation] | ANALOG: board_what_jobs_listings_controller.rb:180-261 in `create_checkout_session` -- saves listing FIRST with `stripe_invoice_paid: false`, then creates Stripe session, does NOT save session ID back to listing | OURS: organization_ai_credit_purchases_controller.rb:93-160 saves purchase FIRST (no checkout_session_id), creates Stripe session, then calls `@purchase.update(stripe_checkout_session_id: session.id)` to save session ID back | SANCTIONED: no

DEVIATION: [Controller create_top_up_checkout_session saves stripe_checkout_session_id on record] | ANALOG: board_what_jobs_listings_controller.rb `create_checkout_session` does NOT save `stripe_checkout_session_id` on the listing record (listing is found via invoice metadata `board_what_jobs_listing_id` in webhook) | OURS: organization_ai_credit_purchases_controller.rb:151 calls `@purchase.update(stripe_checkout_session_id: session.id)` to save session ID on the purchase record | SANCTIONED: no
WHITELIST: The AI credit purchase webhook `charge.refunded` handler (stripe_webhook_handler_job.rb:443-446) uses `stripe_checkout_session_id` to find the purchase for refund processing. WhatJobs refunds are not handled in the webhook. Removing `stripe_checkout_session_id` storage would break refund handling.

DEVIATION: [Controller create_top_up_checkout_session missing authorize] | ANALOG: board_what_jobs_listings_controller.rb:181 has `authorize :billing, :checkout?` at the top of `create_checkout_session` | OURS: organization_ai_credit_purchases_controller.rb:94 has `authorize :billing, :checkout?` | SANCTIONED: n/a (exact match)

DEVIATION: [Controller create_top_up_checkout_session description construction] | ANALOG: board_what_jobs_listings_controller.rb:218 uses `"WhatJobs Job Listing - #{job.title}"` | OURS: organization_ai_credit_purchases_controller.rb:111 uses `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY.dig(lookup_key, :name)` with fallback `"Plato AI Credit Top-Up"` | SANCTIONED: yes (Sub change #5 + Sub change #2)

DEVIATION: [Controller create_top_up_checkout_session product_data.name format] | ANALOG: board_what_jobs_listings_controller.rb:228 uses `"#{job.title} - WhatJobs Job Listing"` | OURS: organization_ai_credit_purchases_controller.rb:120 uses `"#{@description} - Plato AI Credit Top-Up"` | SANCTIONED: yes (Sub change #5)

DEVIATION: [Controller create_top_up_checkout_session metadata keys] | ANALOG: board_what_jobs_listings_controller.rb:237-239,247-248 includes `board_what_jobs_listing_id`, `organization_id`, `job_id` | OURS: organization_ai_credit_purchases_controller.rb:129-131,140-141 includes `organization_ai_credit_purchase_id`, `organization_id` (no `job_id`) | SANCTIONED: yes (Sub change #2, no job association)

DEVIATION: [Controller create_top_up_checkout_session success/cancel URLs] | ANALOG: board_what_jobs_listings_controller.rb:257-258 uses `/jobs/#{job.id}/distribution/whatjobs?checkout=success` | OURS: organization_ai_credit_purchases_controller.rb:147-148 uses `/hire/settings/billing?ai_credit_top_up_success=1` | SANCTIONED: yes (Sub change #2 + Sub change #5, different UI location)

DEVIATION: [Notification job arguments] | ANALOG: notification/paid_wwr_listing_created_job.rb:7 takes `(organization_id, job_id)` | OURS: notification/ai_credit_top_up_purchased_job.rb:7 takes `(organization_id, purchase_id)` | SANCTIONED: yes (Sub change #2)

DEVIATION: [Notification job Slack message format] | ANALOG: notification/paid_wwr_listing_created_job.rb:19 includes job title and WWR listing URL | OURS: notification/ai_credit_top_up_purchased_job.rb:19 includes pack lookup key and credits granted | SANCTIONED: yes (Sub change #2 + Sub change #5)

DEVIATION: [Serializer stripe_invoice_paid not exposed] | ANALOG: board_what_jobs_listing_serializer.rb exposes `paid` (which calls `object.paid?` -> `stripe_invoice_paid?`) | OURS: organization_ai_credit_purchase_serializer.rb does NOT expose `stripe_invoice_paid` | SANCTIONED: no

DEVIATION: [Serializer stripe_invoice_id not exposed] | ANALOG: board_what_jobs_listing_serializer.rb does not expose `stripe_invoice_id` either (both omit it) | OURS: same | SANCTIONED: n/a (match)

DEVIATION: [Model missing paid? convenience method] | ANALOG: board_what_jobs_listing.rb:88-90 has `def paid?; stripe_invoice_paid?; end` | OURS: organization_ai_credit_purchase.rb has no `paid?` method (uses `stripe_invoice_paid?` directly where needed) | SANCTIONED: no

DEVIATION: [Policy pattern mismatch for one-off creation] | ANALOG: WhatJobs `create_paid_listing` uses `BillingPolicy#checkout?` | OURS: `create_top_up` uses `OrganizationAiCreditPurchasePolicy#create_top_up?` | SANCTIONED: no

DEVIATION: [Model charge_for_listing hash syntax] | ANALOG: board_what_jobs_listing.rb:172-189 uses consistent `{` on same line as `.create(` for InvoiceItem and Invoice | OURS: organization_ai_credit_purchase.rb:200-217 uses same style | SANCTIONED: n/a (match)
Note: WWR uses a different formatting style with multi-line indented hashes, but our code matches WhatJobs here.

DEVIATION: [Model belongs_to associations] | ANALOG: board_what_jobs_listing.rb:4-6 has `belongs_to :job`, `belongs_to :last_updated_by_organization_user`, `belongs_to :job_board_integration` | OURS: organization_ai_credit_purchase.rb:78 has `belongs_to :organization` only | SANCTIONED: yes (Sub change #2)

DEVIATION: [Model before_create/after_update callbacks] | ANALOG: board_what_jobs_listing.rb:12-13 has `before_create :set_internal_id` and `after_update_commit :queue_sync_if_active` | OURS: organization_ai_credit_purchase.rb has no lifecycle callbacks | SANCTIONED: no
WHITELIST: WhatJobs callbacks serve WhatJobs-specific needs (generating an internal ID for the WhatJobs API, syncing on update). AI credit purchases have no external API to sync with and no internal ID requirement.

---NEXT DIMENSION---

OK the `subscription.deleted` handler is not in scope (it's not `invoice.paid`), but it shows the same structural pattern: AI credit path touches the purchase record; analog touches the org.

Now I have everything I need. Let me compile the full deviation report for the `invoice.paid` subscription renewal comparison.

Here is the complete structural comparison:

---

## INVOICE.PAID: AI Credit Subscription Renewal vs Main-Plan Subscription Renewal

### Shared Infrastructure (lines 257-260)

Both paths share the same guard and subscription retrieval:
1. `raise CustomStripeSubscriptionMissingError if organization.stripe_subscription_id.nil?` (line 257)
2. `stripe_subscription = Stripe::Subscription.retrieve(object.subscription)` (line 259)
3. `subscription_lookup_key = stripe_subscription.items.data.first&.price&.lookup_key` (line 260)

### Deviations

DEVIATION: Guard uses organization.stripe_subscription_id for AI credit subscription | ANALOG: stripe_webhook_handler_job.rb:257 — raises if org has no main-plan stripe_subscription_id | OURS: stripe_webhook_handler_job.rb:257 — the AI credit subscription renewal path (line 262-276) is gated behind the same `organization.stripe_subscription_id.nil?` check at line 257, meaning an org that has an AI credit subscription but NO main-plan subscription will raise `CustomStripeSubscriptionMissingError` and never reach the AI credit branch | SANCTIONED: no

DEVIATION: Purchase lookup error handling uses raise vs analog uses no explicit raise | ANALOG: stripe_webhook_handler_job.rb:278 — the else branch has no explicit raise if organization or subscription is invalid; it relies on the shared rescue at line 282 | OURS: stripe_webhook_handler_job.rb:267 — raises a string exception `"invoice.paid: no OrganizationAiCreditPurchase for credit-pack subscription #{object.subscription}"` if purchase not found | SANCTIONED: no

DEVIATION: AI credit path updates amount_cents_paid and currency on purchase | ANALOG: stripe_webhook_handler_job.rb:278 — does NOT store amount_paid or currency from the invoice object (Organization has no such columns) | OURS: stripe_webhook_handler_job.rb:270-271 — updates `amount_cents_paid: object.amount_paid` and `currency: object.currency` on the purchase record | SANCTIONED: yes (Sub change #2: Operates on OrganizationAiCreditPurchase record not org)

DEVIATION: AI credit path stores subscription_current_period_start | ANALOG: stripe_webhook_handler_job.rb:278 — Organization has no `stripe_current_period_start_at` column; only updates `stripe_current_period_end_at` | OURS: stripe_webhook_handler_job.rb:272 — updates `subscription_current_period_start: Time.at(stripe_subscription.current_period_start).to_datetime` on the purchase record | SANCTIONED: yes (Sub change #2: Operates on OrganizationAiCreditPurchase record not org — purchase table has this column, org table does not)

DEVIATION: AI credit path stores period end on purchase record not org | ANALOG: stripe_webhook_handler_job.rb:278 — `organization.update(stripe_current_period_end_at: ...)` | OURS: stripe_webhook_handler_job.rb:273 — updates `subscription_current_period_end` on the purchase record inside the `purchase.update(...)` call, does NOT update org | SANCTIONED: yes (Sub change #2: Operates on OrganizationAiCreditPurchase record not org)

DEVIATION: Payment method update passes explicit argument vs analog passes no argument | ANALOG: stripe_webhook_handler_job.rb:279 — `organization.stripe_update_default_payment_method` (no argument; method internally fetches from `organization.stripe_subscription_id`) | OURS: stripe_webhook_handler_job.rb:275 — `organization.stripe_update_default_payment_method(stripe_subscription.default_payment_method)` (passes the AI credit subscription's default_payment_method) | SANCTIONED: yes (Sub change #1: flow_data.subscription uses purchase.stripe_subscription_id — the AI credit subscription is a different Stripe subscription, so the payment method must be passed explicitly)

DEVIATION: Credit application has conditional guard vs analog calls unconditionally | ANALOG: stripe_webhook_handler_job.rb:280 — `organization.organization_ai_credit_balance&.reset_ai_credits` uses safe navigation `&.` which handles nil balance gracefully (returns nil, no error) | OURS: stripe_webhook_handler_job.rb:276 — `ApplyAiCreditPurchase.call(organization: organization, purchase: purchase) if organization.organization_ai_credit_balance` uses an `if` guard that skips the call entirely when balance is nil, PLUS inside ApplyAiCreditPurchase (line 28-35) there is ANOTHER nil check on balance that calls `context.fail!` | SANCTIONED: no

DEVIATION: ApplyAiCreditPurchase has purchase-nil guard with context.fail! that ResetAiCredits lacks | ANALOG: reset_ai_credits.rb — only has balance-nil guard (lines 25-32); no equivalent "purchase is missing" guard since it doesn't accept a purchase | OURS: apply_ai_credit_purchase.rb:37-45 — has an additional `unless purchase` guard with `context.fail!(error: :missing_purchase, ...)` | SANCTIONED: yes (Sub change #2: Operates on OrganizationAiCreditPurchase record not org — the interactor needs a purchase parameter that the analog does not)

DEVIATION: ApplyAiCreditPurchase grant transaction links to purchase record | ANALOG: reset_ai_credits.rb:53-62 — grant `AiCreditBalanceTransaction` does NOT set `organization_ai_credit_purchase:` (no purchase record exists for main plan credits) | OURS: apply_ai_credit_purchase.rb:65 — grant `AiCreditBalanceTransaction` sets `organization_ai_credit_purchase: purchase` | SANCTIONED: yes (Sub change #2: Operates on OrganizationAiCreditPurchase record)

DEVIATION: Credit allocation source — purchase.subscription_credits_per_period vs resolve_allocation | ANALOG: reset_ai_credits.rb:36,52 — allocation determined by `resolve_allocation(organization, balance)` which checks `balance.monthly_ai_credits_override` then falls back to `PlanFeatureGate.new(organization).monthly_ai_credit_allocation` | OURS: apply_ai_credit_purchase.rb:63,69 — allocation is `purchase.subscription_credits_per_period` (fixed on the purchase record at creation time) | SANCTIONED: yes (Sub change #3: No ValidateSubscriptionChange / PlanFeatureGate / job-limit gate — the AI credit subscription has a fixed allocation per plan tier, not a dynamic one from PlanFeatureGate)

DEVIATION: ApplyAiCreditPurchase has no resolve_allocation helper method | ANALOG: reset_ai_credits.rb:94-100 — has `resolve_allocation` private method | OURS: apply_ai_credit_purchase.rb — no equivalent method; allocation comes directly from `purchase.subscription_credits_per_period` | SANCTIONED: yes (Sub change #3: No PlanFeatureGate)

DEVIATION: Bucket name addon_subscription vs monthly | ANALOG: reset_ai_credits.rb:43,55 — uses bucket `:monthly` | OURS: apply_ai_credit_purchase.rb:55,68 — uses bucket `:addon_subscription` | SANCTIONED: yes (Sub change #5: ai_credit_* descriptor naming — these are different credit buckets by design)

DEVIATION: Entry type names differ | ANALOG: reset_ai_credits.rb:42,56 — uses `:plan_monthly_reset_debit` and `:plan_monthly_allocation_credit` | OURS: apply_ai_credit_purchase.rb:53,67 — uses `:subscription_credit_pack_reset_debit` and `:subscription_credit_pack_purchase_credit` | SANCTIONED: yes (Sub change #5: ai_credit_* descriptor naming)

DEVIATION: Description strings differ | ANALOG: reset_ai_credits.rb:45 — `'Anniversary reset — clear previous monthly bucket'`; line 58 — `"Monthly credit grant for #{organization.plan}"` | OURS: apply_ai_credit_purchase.rb:56 — `'Subscription renewal reset — clear previous addon_subscription bucket'`; line 70 — `"Credit pack subscription grant for #{purchase.stripe_price_lookup_key}"` | SANCTIONED: yes (Sub change #5: ai_credit_* descriptor naming)

DEVIATION: Error message prefix in fail_with_record_invalid | ANALOG: reset_ai_credits.rb:83 — `"ResetAiCredits #{label} failed for org ..."` | OURS: apply_ai_credit_purchase.rb:95 — `"ApplyAiCreditPurchase #{label} failed for org ..."` | SANCTIONED: yes (Sub change #5: ai_credit_* descriptor naming)

DEVIATION: Error log message prefix differs | ANALOG: reset_ai_credits.rb:25 — `"ResetAiCredits: org #{organization.id} has no ai_credit_balance"` | OURS: apply_ai_credit_purchase.rb:29 — `"ApplyAiCreditPurchase: org #{organization.id} has no ai_credit_balance"` | SANCTIONED: yes (Sub change #5: ai_credit_* descriptor naming)

DEVIATION: Pending migration 20260611120002 will rename amount_cents_paid to stripe_amount, breaking webhook handler line 270 | ANALOG: n/a — Organization has no per-invoice amount column | OURS: stripe_webhook_handler_job.rb:270 — uses `amount_cents_paid:` but migration `20260611120002` renames it to `stripe_amount` — after migration runs, this line will raise `ActiveRecord::UnknownAttributeError` | SANCTIONED: no

DEVIATION: subscription.updated AI credit path does not call sync_with_stripe | ANALOG: stripe_webhook_handler_job.rb:141 — calls `organization.sync_with_stripe` after updating org fields | OURS: stripe_webhook_handler_job.rb:130-134 — only updates purchase fields, no `sync_with_stripe` call | SANCTIONED: yes (Sub change #2: Operates on OrganizationAiCreditPurchase record not org — `sync_with_stripe` explicitly filters out credit subscriptions and only syncs main-plan state)

DEVIATION: subscription.deleted AI credit path does not call sync_with_stripe, PaidSubscriptionDeletedJob, or EngagementReport::GeneratorJob | ANALOG: stripe_webhook_handler_job.rb:176-181 — calls all three | OURS: stripe_webhook_handler_job.rb:167-174 — only updates purchase record with canceled status and canceled_at | SANCTIONED: yes (Sub change #2 + Sub change #3: AI credit subscription is not a plan subscription; these are plan-lifecycle side effects)

### Summary of Unsanctioned Deviations

**1. Guard at line 257 blocks AI credit-only orgs.** The `raise CustomStripeSubscriptionMissingError if organization.stripe_subscription_id.nil?` guard fires BEFORE the code reaches the AI credit subscription branch. An organization that has purchased an AI credit subscription but does not have a main-plan subscription (e.g., a free-tier org) will never have their AI credit subscription renewal processed. This is a bug.

**2. Explicit raise on missing purchase vs analog's silent handling.** The AI credit path raises a string exception at line 267 if the purchase record is not found. The analog's else branch has no equivalent explicit raise — it would just fail on a nil method call, caught by the shared rescue. This is a structural mismatch in error handling style, though arguably defensive. Not necessarily a bug but a deviation.

**3. Double nil-guard on balance.** The webhook handler at line 276 guards with `if organization.organization_ai_credit_balance`, AND the interactor at lines 28-35 guards again with a `context.fail!`. The analog at line 280 uses only `&.` safe navigation (one level of nil protection), and `ResetAiCredits` has only the interactor-level guard. The AI credit path has redundant protection.

**4. Pending migration will break webhook handler.** Migration `20260611120002` renames `amount_cents_paid` to `stripe_amount`. After this migration runs, line 270 (`amount_cents_paid: object.amount_paid`) will raise `ActiveRecord::UnknownAttributeError`. The code and the migration are inconsistent.

---NEXT DIMENSION---

Now I have a comprehensive picture. Let me compile the full deviation report.

---

DEVIATION REPORT: AI Credit Subscription Change (Portal) vs BillingController Analog

## CONTROLLER: change_subscription_portal_session

DEVIATION: [Sentry.capture_exception in StandardError rescue] | ANALOG: billing_controller.rb:326 StandardError rescue does NOT call Sentry.capture_exception — only logs and renders | OURS: organization_ai_credit_purchases_controller.rb:210 StandardError rescue does NOT call Sentry.capture_exception — only logs and renders | SANCTIONED: n/a (MATCH)

DEVIATION: [ValidateSubscriptionChange gate in change_subscription_portal_session] | ANALOG: billing_controller.rb:277-286 calls ValidateSubscriptionChange.call before building the portal session options | OURS: organization_ai_credit_purchases_controller.rb:165-198 does NOT call ValidateSubscriptionChange.call | SANCTIONED: yes (Sub change #3: No ValidateSubscriptionChange / PlanFeatureGate / job-limit gate)

DEVIATION: [Subscription ID source in flow_data] | ANALOG: billing_controller.rb:296 uses `current_organization.stripe_subscription_id` | OURS: organization_ai_credit_purchases_controller.rb:182 uses `purchase.stripe_subscription_id` | SANCTIONED: yes (Sub change #1: flow_data.subscription uses purchase.stripe_subscription_id)

DEVIATION: [Active subscription guard shape] | ANALOG: billing_controller.rb:273 `raise StandardError, 'No active subscription found.' unless current_organization.stripe_subscription_id.present?` — single guard on org | OURS: organization_ai_credit_purchases_controller.rb:170-171 `purchase = current_organization.organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])` then `raise StandardError, 'No active subscription found.' if purchase.nil? || purchase.stripe_subscription_id.blank?` — two-step guard on purchase record | SANCTIONED: yes (Sub change #2: Operates on OrganizationAiCreditPurchase record not org)

DEVIATION: [PosthogTrackJob event name] | ANALOG: billing_controller.rb:311 `'change_subscription_stripe_portal_opened'` | OURS: organization_ai_credit_purchases_controller.rb:197 `'ai_credit_change_subscription_stripe_portal_opened'` | SANCTIONED: yes (Sub change #5: ai_credit_* descriptor naming)

## CONTROLLER: update_payment_method_and_subscription_portal_session

DEVIATION: [Active subscription guard shape] | ANALOG: billing_controller.rb:335-337 three separate raises: stripe_customer_id, stripe_subscription_id, subscription_item_id — all against `current_organization` | OURS: organization_ai_credit_purchases_controller.rb:221-224 stripe_customer_id against current_organization, then purchase lookup + two-condition raise for purchase, then subscription_item_id | SANCTIONED: yes (Sub change #2)

DEVIATION: [continue_url path segment] | ANALOG: billing_controller.rb:346 `/api/v1/billing/continue_change_subscription_portal_session` | OURS: organization_ai_credit_purchases_controller.rb:233 `/api/v1/ai_credit_purchases/continue_change_subscription_portal_session` | SANCTIONED: yes (Sub change #5: ai_credit_* descriptor naming — different controller path)

## CONTROLLER: continue_change_subscription_portal_session

DEVIATION: [Subscription ID source — blank check] | ANALOG: billing_controller.rb:395-398 checks `current_organization.stripe_subscription_id.blank?` | OURS: organization_ai_credit_purchases_controller.rb:282-287 looks up purchase record, checks `purchase.nil? || purchase.stripe_subscription_id.blank?` | SANCTIONED: yes (Sub change #2)

DEVIATION: [Subscription ID source in flow_data] | ANALOG: billing_controller.rb:439 `current_organization.stripe_subscription_id` | OURS: organization_ai_credit_purchases_controller.rb:315 `purchase.stripe_subscription_id` | SANCTIONED: yes (Sub change #1)

DEVIATION: [ValidateSubscriptionChange gate in continue_change_subscription_portal_session] | ANALOG: billing_controller.rb:418-429 calls `ValidateSubscriptionChange.call` with `target_price_id` and `action_type: 'change'`, redirects with error on failure | OURS: organization_ai_credit_purchases_controller.rb:272-346 does NOT call ValidateSubscriptionChange.call | SANCTIONED: yes (Sub change #3)

## CONTROLLER: customer_subscription

DEVIATION: [Subscription source] | ANALOG: billing_controller.rb:607-621 uses `current_organization.stripe_subscription_id` and `current_organization.stripe_subscription` | OURS: organization_ai_credit_purchases_controller.rb:371-386 looks up purchase record, uses `purchase.stripe_subscription_id` and `purchase.stripe_subscription` | SANCTIONED: yes (Sub change #4: Live-subscription endpoint retrieves by purchase.stripe_subscription_id)

DEVIATION: [Debug logging] | ANALOG: billing_controller.rb:607-608 `ap 'GETTING THE CUSTOMER SUBSCRIPTION'` then `ap current_organization.stripe_subscription` | OURS: organization_ai_credit_purchases_controller.rb:372-374 `ap 'GETTING THE CUSTOMER SUBSCRIPTION'` then `ap purchase&.stripe_subscription` — slightly different (safe navigation on purchase) | SANCTIONED: yes (Sub change #2 — purchase can be nil, safe nav necessary)

## CONTROLLER: determine_price_id (private method)

DEVIATION: [Fallback price lookup filter] | ANALOG: billing_controller.rb:630-639 `params[:price_id]` or list all active prices, find by `price.lookup_key == DEFAULT_PRICE_LOOKUP_KEY` | OURS: organization_ai_credit_purchases_controller.rb:402-411 `params[:price_id]` or list all active prices, find by `OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?(price.lookup_key)` | SANCTIONED: yes (Sub change #5: uses AI credit-specific lookup key validation instead of DEFAULT_PRICE_LOOKUP_KEY constant)

DEVIATION: [Fallback price lookup retains analog expand param] | ANALOG: billing_controller.rb:634 `Stripe::Price.list({ active: true, limit: 10, expand: ['data.tiers'] })` | OURS: organization_ai_credit_purchases_controller.rb:406 `Stripe::Price.list({ active: true, limit: 10, expand: ['data.tiers'] })` — identical expand param | SANCTIONED: n/a (MATCH — but see REVERT below)
REVERT: [determine_price_id expand param] The AI credit subscription prices likely do not use tiered pricing, so `expand: ['data.tiers']` is unnecessary overhead copied verbatim from the analog. Consider removing the tiers expand if AI credit plans are flat-rate.

DEVIATION: [Fallback price lookup retains analog commented-out code] | ANALOG: billing_controller.rb:637 `# target_price = prices.data.find { |price| price.nickname.include? 'Per' }` | OURS: organization_ai_credit_purchases_controller.rb:408 `# target_price = prices.data.find { |price| price.nickname.include? 'Per' }` — dead comment copied verbatim | SANCTIONED: no
REVERT: [determine_price_id dead comment] The commented-out `nickname.include? 'Per'` line is analog-specific dead code that has no relevance to AI credit subscriptions. Should be removed.

## CONTROLLER: strong params

DEVIATION: [Param key namespace] | ANALOG: billing_controller.rb:671 `params.require(:billing).permit(...)` with keys `[:price_id, :subscription_id, :success_url, :cancel_url, :job_id, :location_pathname, :checkout_mode, :session_id, :promo_code, :plan_type, :subscription_item_id, :plan_period]` | OURS: organization_ai_credit_purchases_controller.rb:414-415 `params.require(:organization_ai_credit_purchase).permit(:stripe_price_lookup_key, :price_id, :subscription_item_id, :return_url)` — different namespace and much smaller permit list | SANCTIONED: yes (Sub change #2 + #5 — different resource namespace, only AI credit relevant params)

## HOOKS: useChangeSubscriptionViaStripePortal (useBilling.ts vs useOrganizationAiCreditPurchase.ts)

DEVIATION: [API function name] | ANALOG: useBilling.ts:46 `changeSubscriptionViaStripePortal` | OURS: useOrganizationAiCreditPurchase.ts:35 `changeAiCreditSubscriptionViaStripePortal` | SANCTIONED: yes (Sub change #5)

DEVIATION: [API path] | ANALOG: useBilling.ts:56 `/billing/change_subscription_portal_session` | OURS: useOrganizationAiCreditPurchase.ts:45 `/ai_credit_purchases/change_subscription_portal_session` | SANCTIONED: yes (Sub change #5)

DEVIATION: [Hook name] | ANALOG: useBilling.ts:181 `useChangeSubscriptionViaStripePortal` | OURS: useOrganizationAiCreditPurchase.ts:50 `useChangeAiCreditSubscriptionViaStripePortal` | SANCTIONED: yes (Sub change #5)

DEVIATION: [window.logger tag in change portal hook] | ANALOG: useBilling.ts:185 `"%c[useBilling] useChangePlanStripePortalSession"` | OURS: useOrganizationAiCreditPurchase.ts:54 `"%c[useOrganizationAiCreditPurchase] useChangeAiCreditSubscriptionViaStripePortal"` | SANCTIONED: yes (Sub change #5)

## HOOKS: useUpdateWithPaymentMethod (useBilling.ts vs useOrganizationAiCreditPurchase.ts)

DEVIATION: [API function name] | ANALOG: useBilling.ts:61 `updateWithPaymentMethod` | OURS: useOrganizationAiCreditPurchase.ts:63 `updateAiCreditSubscriptionWithPaymentMethod` | SANCTIONED: yes (Sub change #5)

DEVIATION: [API path] | ANALOG: useBilling.ts:71 `/billing/update_payment_method_and_subscription_portal_session` | OURS: useOrganizationAiCreditPurchase.ts:73 `/ai_credit_purchases/update_payment_method_and_subscription_portal_session` | SANCTIONED: yes (Sub change #5)

DEVIATION: [Hook name] | ANALOG: useBilling.ts:194 `useUpdateWithPaymentMethod` | OURS: useOrganizationAiCreditPurchase.ts:78 `useUpdateAiCreditSubscriptionWithPaymentMethod` | SANCTIONED: yes (Sub change #5)

DEVIATION: [window.logger tag in update payment method hook] | ANALOG: useBilling.ts:198 `"%c[useBilling] useUpdateWithPaymentMethod"` | OURS: useOrganizationAiCreditPurchase.ts:82 `"%c[useOrganizationAiCreditPurchase] useUpdateAiCreditSubscriptionWithPaymentMethod"` | SANCTIONED: yes (Sub change #5)

## HOOKS: useStripeCustomerSubscription vs useAiCreditCustomerSubscription

DEVIATION: [API function name] | ANALOG: useBilling.ts:98 `getStripeCustomerSubscription` | OURS: useOrganizationAiCreditPurchase.ts:170 `getAiCreditCustomerSubscription` | SANCTIONED: yes (Sub change #5)

DEVIATION: [API path] | ANALOG: useBilling.ts:99 `/billing/customer_subscription` | OURS: useOrganizationAiCreditPurchase.ts:171 `/ai_credit_purchases/customer_subscription` | SANCTIONED: yes (Sub change #5)

DEVIATION: [Hook name] | ANALOG: useBilling.ts:245 `useStripeCustomerSubscription` | OURS: useOrganizationAiCreditPurchase.ts:174 `useAiCreditCustomerSubscription` | SANCTIONED: yes (Sub change #5)

DEVIATION: [Query key] | ANALOG: useBilling.ts:261 `["stripeCustomerSubscription"]` | OURS: useOrganizationAiCreditPurchase.ts:190 `["aiCreditCustomerSubscription"]` | SANCTIONED: yes (Sub change #5)

DEVIATION: [window.logger tag] | ANALOG: useBilling.ts:258 `"%c[useBilling] useStripeCustomerSubscription"` | OURS: useOrganizationAiCreditPurchase.ts:187 `"%c[useOrganizationAiCreditPurchase] useAiCreditCustomerSubscription"` | SANCTIONED: yes (Sub change #5)

## COMPONENT: handleChangeSubscriptionViaStripePortal (AccountBillingPlans.tsx vs AiCreditSubscription.tsx)

DEVIATION: [returnUrl value] | ANALOG: AccountBillingPlans.tsx:293 `"/hire/settings/billing"` | OURS: AiCreditSubscription.tsx:155 `"/hire/settings/plato-ai/billing"` | SANCTIONED: yes (Sub change #5 — AI credits lives on a different page)

DEVIATION: [window.logger component name in onSuccess] | ANALOG: AccountBillingPlans.tsx:299 `"%c[AccountBilling] created session for updating Subscription"` | OURS: AiCreditSubscription.tsx:161 `"%c[AiCreditSubscription] created session for updating Subscription"` | SANCTIONED: yes (Sub change #5)

DEVIATION: [window.logger component name in onError] | ANALOG: AccountBillingPlans.tsx:308 `"%c[AccountBilling] ERROR creating Custom Stripe Billing Portal session"` | OURS: AiCreditSubscription.tsx:170 `"%c[AiCreditSubscription] ERROR creating Custom Stripe Billing Portal session"` | SANCTIONED: yes (Sub change #5)

## COMPONENT: handleUpdateWithPaymentMethod (AccountBillingPlans.tsx vs AiCreditSubscription.tsx)

DEVIATION: [returnUrl value] | ANALOG: AccountBillingPlans.tsx:254 `"/hire/settings/billing"` | OURS: AiCreditSubscription.tsx:118 `"/hire/settings/plato-ai/billing"` | SANCTIONED: yes (Sub change #5)

DEVIATION: [window.logger component name in onSuccess] | ANALOG: AccountBillingPlans.tsx:259 `"%c[AccountBilling] completed update payment method and change subscription"` | OURS: AiCreditSubscription.tsx:124 `"%c[AiCreditSubscription] completed update payment method and change subscription"` | SANCTIONED: yes (Sub change #5)

DEVIATION: [window.logger component name in onError] | ANALOG: AccountBillingPlans.tsx:268 `"%c[AccountBilling] ERROR updating payment method and changing subscription"` | OURS: AiCreditSubscription.tsx:133 `"%c[AiCreditSubscription] ERROR updating payment method and changing subscription"` | SANCTIONED: yes (Sub change #5)

## COMPONENT: handleChangeSubscriptionWithGate vs handleChangeSubscription

DEVIATION: [No PlanFeatureGate / checkPlanLimitsGate call] | ANALOG: AccountBillingPlans.tsx:322-350 `handleChangeSubscriptionWithGate` calls `checkPlanLimitsGate(plan.lookupKey)`, conditionally shows `PlanChangeBlockedModal`, tracks `plan_change_blocked_modal_shown` event | OURS: AiCreditSubscription.tsx:217-229 `handleChangeSubscription` goes straight to portal/payment-method check with no gate | SANCTIONED: yes (Sub change #3: No ValidateSubscriptionChange / PlanFeatureGate / job-limit gate)

DEVIATION: [Gate function takes plan vs tier] | ANALOG: AccountBillingPlans.tsx:322 `handleChangeSubscriptionWithGate = (plan) => { ... onChangeSubscription handler in PlanCard receives plan }` | OURS: AiCreditSubscription.tsx:217 `handleChangeSubscription = (tier: AiCreditTier) => { ... }` | SANCTIONED: yes (Sub change #2 — different data shape for AI credit tiers)

## COMPONENT: Billing period toggle

DEVIATION: [No billing period toggle] | ANALOG: AccountBillingPlans.tsx:81-115 has `SlidingToggleSwitch` for monthly/yearly billing period, `billingPeriod` state, `useEffect` to sync initial period from subscription data, `Badge` showing "2 months free" | OURS: AiCreditSubscription.tsx — no billing period toggle at all | SANCTIONED: no

This is a potentially intentional design difference (AI credit subscriptions may only be monthly), but it was not listed in the sanctioned deviations. If AI credit subscriptions are monthly-only, this is fine but should be explicitly sanctioned. If yearly AI credit subscriptions are planned, this is a gap.

## COMPONENT: Trialing state display

DEVIATION: [No trialing state banner] | ANALOG: AccountBillingPlans.tsx:370-382 renders `CurrentSubscription` banner when `currentSubscription?.status === "trialing"` with trial end date and "Manage billing" button | OURS: AiCreditSubscription.tsx — no trialing state check or banner | SANCTIONED: no

If AI credit subscriptions do not offer trials, this deviation is intentional. But it is not sanctioned and represents a missing UI state. If a trial is ever configured on the Stripe subscription, the user will see no indication.

## COMPONENT: Legacy plan display

DEVIATION: [No legacy plan banner] | ANALOG: AccountBillingPlans.tsx:398-422 renders `CurrentSubscription` banner for legacy plans with plan-type-specific messaging | OURS: AiCreditSubscription.tsx — no legacy plan concept | SANCTIONED: no

This is likely intentional (AI credit subscriptions are new, no legacy plans exist), but is not listed as sanctioned.

## COMPONENT: cancelAtPeriodEnd banner

DEVIATION: [Cancel banner button action] | ANALOG: AccountBillingPlans.tsx:384-396 `cancelAtPeriodEnd` banner uses `handleCreateBillingPortalSession` ("Manage billing" button) to open Stripe portal | OURS: AiCreditSubscription.tsx:354-366 `cancelAtPeriodEnd` banner uses `handleCancelClick` ("Manage billing" button) which opens `CancelAiCreditSubscriptionConfirmModal` instead of Stripe portal | SANCTIONED: no

The analog opens the Stripe billing portal for managing a pending cancellation (which lets the user reactivate). Our code opens a cancel confirmation modal instead, which would attempt to cancel again. This is a behavioral mismatch — a user whose subscription is already `cancelAtPeriodEnd` clicking "Manage billing" should be taken to the Stripe portal to potentially reactivate, not shown another cancel confirmation.

## COMPONENT: isCanceledButStillActive banner (EXTRA)

DEVIATION: [Extra canceled-but-active banner] | ANALOG: AccountBillingPlans.tsx — no equivalent UI state | OURS: AiCreditSubscription.tsx:340-353 renders a banner for `isCanceledButStillActive` state showing period end date and cancel button | SANCTIONED: no

This is EXTRA UI with no analog equivalent. The analog handles pending cancellation via `cancelAtPeriodEnd` from Stripe. Our code has a separate concept where the local `subscription_status` is `canceled` but the period hasn't ended. This is a structural addition.

## COMPONENT: handleCreateBillingPortalSession

DEVIATION: [Missing handleCreateBillingPortalSession] | ANALOG: AccountBillingPlans.tsx:218-238 has `handleCreateBillingPortalSession` using `useCreateStripeCustomerPortalSession` for general billing portal access | OURS: AiCreditSubscription.tsx — no equivalent function, no import of `useCreateStripeCustomerPortalSession` | SANCTIONED: no

The analog uses this for the "Manage billing" button on the trialing, cancelAtPeriodEnd, and legacy plan banners, and also passes it to `PlanCard` for current-plan actions via `ManageBillingActions`. Our code has no equivalent — the "Manage billing" button on the cancelAtPeriodEnd banner calls `handleCancelClick` instead.

## COMPONENT: PlanCard vs AiSubscriptionTierCard (card-level)

DEVIATION: [Current plan action] | ANALOG: PlanCard.tsx:199-205 renders `ManageBillingActions` for current plan (includes "Manage billing" portal access and promo code actions) | OURS: AiSubscriptionTierCard.tsx:86-88 renders `Styled.CurrentTag` (a static "Current plan" label, no actions) | SANCTIONED: no

The analog gives users actions on their current plan card (manage billing, promo codes). Our code shows only a static tag. This means subscribed users cannot manage their billing or apply promo codes from the current tier card.

DEVIATION: [No promo code support] | ANALOG: PlanCard.tsx:64-66 accepts `hasCoupon`, `stripePromoCode` props, passes to `ManageBillingActions` | OURS: AiSubscriptionTierCard.tsx — no `hasCoupon` or promo props, no promo code application | SANCTIONED: no

DEVIATION: [onCreateNewSubscription callback signature] | ANALOG: PlanCard.tsx:70 `onCreateNewSubscription?: () => void` — takes no arguments | OURS: AiSubscriptionTierCard.tsx:27 `onCreateNewSubscription?: (tier: AiCreditTier) => void` — takes the tier as argument | SANCTIONED: no

The analog's `onCreateNewSubscription` is a parameterless callback because `AccountBillingPlans` handles checkout through a different flow (the parent determines the checkout params). Our code passes the tier to the callback, which is arguably cleaner but structurally different.

DEVIATION: [onChangeSubscription callback signature] | ANALOG: PlanCard.tsx:69 `onChangeSubscription?: (plan: Plan) => void` — takes Plan type | OURS: AiSubscriptionTierCard.tsx:26 `onChangeSubscription?: (tier: AiCreditTier) => void` — takes AiCreditTier type | SANCTIONED: yes (Sub change #2 — different data type)

DEVIATION: [trackEvent event name and payload] | ANALOG: PlanCard.tsx:99 `trackEvent("plan_selected", { current_plan_lookup_key, selected_plan_name, selected_plan_key, selected_plan_billing_period })` | OURS: AiSubscriptionTierCard.tsx:41 `trackEvent("ai_credit_tier_selected", { current_tier_lookup_key, selected_tier_name, selected_tier_credits, selected_tier_lookup_key })` | SANCTIONED: yes (Sub change #5)

DEVIATION: [No billingPeriod prop] | ANALOG: PlanCard.tsx:59 accepts `billingPeriod` prop, uses for display price calculation and savings | OURS: AiSubscriptionTierCard.tsx — no billingPeriod prop | SANCTIONED: no (correlates with missing billing period toggle above)

DEVIATION: [No currentPlanBillingPeriod prop] | ANALOG: PlanCard.tsx:61 accepts `currentPlanBillingPeriod` prop | OURS: AiSubscriptionTierCard.tsx — no equivalent prop | SANCTIONED: no (correlates with missing billing period toggle)

## COMPONENT: PurchaseAiCreditTopUpConfirmModal (EXTRA)

DEVIATION: [Extra confirm modal for top-ups] | ANALOG: no equivalent — billing checkout flow has no confirm modal before charge | OURS: AiCreditSubscription.tsx:277-288 opens `PurchaseAiCreditTopUpConfirmModal` before direct top-up charge | SANCTIONED: yes (EXTRA confirm modal sanctioned deviation)

## COMPONENT: ContactUsCallout

DEVIATION: [ContactUsCallout present in AI credit subscription section] | ANALOG: AccountBillingPlans.tsx:461 renders `ContactUsCallout` | OURS: AiCreditSubscription.tsx:400 renders `ContactUsCallout` | SANCTIONED: n/a (MATCH)

## COMPONENT: AiCreditsCallout

DEVIATION: [No AiCreditsCallout equivalent pointing back to billing] | ANALOG: AccountBillingPlans.tsx:463-465 renders `AiCreditsCallout` with link to plato-ai/billing | OURS: AiCreditSubscription.tsx — no cross-link callout back to main billing | SANCTIONED: no

This is a minor UX asymmetry. The main billing page links to AI credit billing, but AI credit billing doesn't link back. Not a structural bug, but a deviation from the pattern of cross-linking.

## COMPONENT: render-level window.logger

DEVIATION: [Render logger content] | ANALOG: AccountBillingPlans.tsx:195-209 logs `isLoadingChangeSubscriptionViaStripePortal`, `isOnLegacyPlan`, and various billing-specific fields | OURS: AiCreditSubscription.tsx:317-329 logs `isCheckingOut`, `isLoadingChangeSubscriptionViaStripePortal`, `isLoadingUpdateWithPaymentMethod`, `isSubscribed`, `currentCredits` — different but domain-appropriate fields | SANCTIONED: yes (Sub change #5 — different data)

DEVIATION: [window.logger prefix in top-level info log] | ANALOG: AccountBillingPlans.tsx:144 `"%c[AccountBillingPlans] PlanInformation"` | OURS: AiCreditSubscription.tsx:89 `"%c[AiCreditSubscription] SubscriptionInformation"` | SANCTIONED: yes (Sub change #5)

---

SUMMARY OF UNSANCTIONED DEVIATIONS:

1. **No billing period toggle** — analog has monthly/yearly toggle; ours has none
2. **No trialing state banner** — analog shows trial info; ours does not handle trialing
3. **No legacy plan banner** — analog handles legacy plans; ours does not
4. **cancelAtPeriodEnd banner calls handleCancelClick instead of handleCreateBillingPortalSession** — behavioral mismatch; user clicking "Manage billing" on a pending-cancel subscription gets a cancel modal instead of the Stripe portal to potentially reactivate
5. **EXTRA isCanceledButStillActive banner** — no analog equivalent
6. **Missing handleCreateBillingPortalSession** — no Stripe portal access from AI credit subscription page
7. **Current plan card shows static tag instead of ManageBillingActions** — no "Manage billing" or promo code actions for current plan
8. **No promo code support on tier card** — hasCoupon/stripePromoCode props absent
9. **onCreateNewSubscription takes tier argument** — analog takes no arguments
10. **No billingPeriod / currentPlanBillingPeriod props on tier card** — correlates with #1
11. **No AiCreditsCallout equivalent cross-link** — minor UX asymmetry
12. **determine_price_id retains dead comment from analog** — `# target_price = prices.data.find { |price| price.nickname.include? 'Per' }`

REVERT ITEMS:
1. `determine_price_id` has unnecessary `expand: ['data.tiers']` copied from analog (AI credit prices are likely flat-rate)
2. `determine_price_id` has dead commented-out `nickname.include? 'Per'` line from analog

WHITELIST ITEMS: (none needed — no matching would break other code paths)

---NEXT DIMENSION---

Now I have the complete picture. Let me compile the structural comparison.

---

## customer.subscription.updated — Structural Comparison

### ANALOG (develop branch, lines 111-148):

```
1. Extract stripe_current_period_end_at
2. Find organization
3. Extract plan_lookup_key
4. begin
5.   organization.update(period_end, status, cancel_at_period_end)
6.   organization.stripe_update_default_payment_method (conditional)
7.   organization.sync_with_stripe
8. rescue → log
```

### OURS (billing-bonanza branch, lines 111-148):

```
1. Extract stripe_current_period_end_at
2. Find organization
3. Extract plan_lookup_key
4. begin
5.   IF credit-pack branch:
5a.    find purchase by stripe_subscription_id + kind
5b.    purchase.update(status, period_end, cancel_at_period_end)
6.   ELSE (main-plan branch):
6a.    organization.update(period_end, status, cancel_at_period_end)
6b.    organization.sync_with_stripe
7.   organization.stripe_update_default_payment_method (conditional)
8. rescue → log
```

DEVIATION: [sync_with_stripe placement] | ANALOG: [stripe_webhook_handler_job.rb:141 sync_with_stripe called AFTER stripe_update_default_payment_method on line 140] | OURS: [stripe_webhook_handler_job.rb:141 sync_with_stripe called BEFORE stripe_update_default_payment_method on line 143, inside the else branch] | SANCTIONED: no

Explanation: In the analog (develop), the order is: (1) `organization.update`, (2) `stripe_update_default_payment_method`, (3) `sync_with_stripe`. In billing-bonanza, the main-plan else branch does: (1) `organization.update`, (2) `sync_with_stripe`, then (3) `stripe_update_default_payment_method` runs outside the if/else. The order of `sync_with_stripe` and `stripe_update_default_payment_method` is swapped compared to the analog.

DEVIATION: [sync_with_stripe omitted from credit-pack branch] | ANALOG: [stripe_webhook_handler_job.rb:141 sync_with_stripe always called] | OURS: [stripe_webhook_handler_job.rb:125-134 credit-pack branch does NOT call sync_with_stripe] | SANCTIONED: no

Explanation: The analog always calls `sync_with_stripe`. The credit-pack branch skips it entirely. While `sync_with_stripe` filters out credit subscriptions (lines 539-541 of organization.rb), it also updates `stripe_default_payment_method_on_file` (line 580) and the main plan fields based on what Stripe currently has. Skipping it means no `sync_with_stripe` call happens when a credit subscription updates. This may be intentional (the purchase record is not an org-level concern), but structurally it is a deviation. WHITELIST: `sync_with_stripe` operates on organization-level plan/subscription fields and filters out credit subscriptions anyway (lines 539-541). Calling it from the credit-pack branch would be a no-op for subscription fields but would still sync `stripe_default_payment_method_on_file`. The omission is likely intentional but should be verified.

DEVIATION: [stripe_update_default_payment_method scope] | ANALOG: [stripe_webhook_handler_job.rb:140 stripe_update_default_payment_method called unconditionally (not inside if/else)] | OURS: [stripe_webhook_handler_job.rb:143 stripe_update_default_payment_method called outside if/else — runs for BOTH branches] | SANCTIONED: yes (Sub change #2 — the call runs for both branches, which matches the analog's unconditional behavior, but the placement relative to sync_with_stripe changed)

---

## customer.subscription.deleted — Structural Comparison

### ANALOG (develop branch, lines 138-155):

```
1. Extract stripe_customer_id, stripe_subscription_id, organization, subscription_ended_at
2. begin
3.   ap object, timestamps, subscription ID
4.   organization.sync_with_stripe (conditional on ID match)
5.   organization.update_column(:subscription_canceled_at, ...)
6.   Notification::PaidSubscriptionDeletedJob.perform_later
7.   EngagementReport::GeneratorJob.perform_later
8. rescue → log
```

### OURS (billing-bonanza branch, lines 150-186):

```
1. Extract stripe_customer_id, stripe_subscription_id, organization, subscription_ended_at
1a. Extract plan_lookup_key  ← NEW
2. begin
3.   ap object, timestamps, subscription ID
4.   IF credit-pack branch:
4a.    find purchase by stripe_subscription_id + kind
4b.    purchase.update(status: :canceled, subscription_canceled_at: ...)
5.   ELSE (main-plan branch):
5a.    organization.sync_with_stripe (conditional on ID match)
5b.    organization.update_column(:subscription_canceled_at, ...)
5c.    Notification::PaidSubscriptionDeletedJob.perform_later
5d.    EngagementReport::GeneratorJob.perform_later
6. rescue → log
```

DEVIATION: [plan_lookup_key extraction added to deleted handler] | ANALOG: [stripe_webhook_handler_job.rb:138-155 no plan_lookup_key extraction] | OURS: [stripe_webhook_handler_job.rb:157 extracts plan_lookup_key to route the if/else branch] | SANCTIONED: yes (Sub change #2 — needed to distinguish credit-pack vs main-plan subscriptions)

DEVIATION: [subscription_status set to symbol :canceled vs object.status] | ANALOG: [N/A — analog has no credit-pack branch in deleted handler] | OURS: [stripe_webhook_handler_job.rb:172 uses hardcoded `subscription_status: :canceled` instead of `object.status`] | SANCTIONED: no

Explanation: In the `customer.subscription.updated` credit-pack branch (line 131), `subscription_status` is set to `object.status` (dynamic from Stripe). In the `customer.subscription.deleted` credit-pack branch (line 172), `subscription_status` is hardcoded to `:canceled`. While `customer.subscription.deleted` always means the subscription is canceled, the analog pattern in the `updated` handler uses `object.status` consistently. Within the `deleted` handler's main-plan else branch, the analog does not explicitly set `stripe_subscription_status` — it relies on `sync_with_stripe` to pick it up. So hardcoding `:canceled` is a reasonable choice, but it is structurally inconsistent with the `updated` handler's approach. REVERT: Consider using `object.status` for consistency with the `updated` handler, though `:canceled` is technically correct for the `deleted` event.

DEVIATION: [subscription_canceled_at field name difference] | ANALOG: [stripe_webhook_handler_job.rb (develop):149 uses `organization.update_column(:subscription_canceled_at, ...)`] | OURS: [stripe_webhook_handler_job.rb:173 uses `purchase.update(subscription_canceled_at: ...)` via regular update, not update_column] | SANCTIONED: yes (Sub change #2 — operates on OrganizationAiCreditPurchase not Organization; using `update` instead of `update_column` is actually safer as it runs validations/callbacks)

DEVIATION: [Notification::PaidSubscriptionDeletedJob not fired for credit-pack] | ANALOG: [stripe_webhook_handler_job.rb (develop):150 always fires PaidSubscriptionDeletedJob] | OURS: [stripe_webhook_handler_job.rb:163-174 credit-pack branch skips PaidSubscriptionDeletedJob entirely] | SANCTIONED: no

Explanation: The analog fires `Notification::PaidSubscriptionDeletedJob.perform_later` for every subscription deletion. The credit-pack branch skips it entirely. This is likely intentional — a credit subscription cancellation is not the same as a paid plan cancellation — but there is no equivalent notification for credit subscription cancellation. WHITELIST: `PaidSubscriptionDeletedJob` sends a Slack notification about the org losing their paid plan. Firing it for AI credit subscription cancellation would be misleading — the org still has their main plan. If an AI credit subscription cancellation notification is needed, it should be a separate job, not this one.

DEVIATION: [EngagementReport::GeneratorJob not fired for credit-pack] | ANALOG: [stripe_webhook_handler_job.rb (develop):151 always fires EngagementReport::GeneratorJob with trigger 'subscription_canceled'] | OURS: [stripe_webhook_handler_job.rb:163-174 credit-pack branch skips EngagementReport::GeneratorJob entirely] | SANCTIONED: no

Explanation: The analog fires `EngagementReport::GeneratorJob` with trigger `'subscription_canceled'` for every deletion. The credit-pack branch skips it. WHITELIST: `EngagementReport::GeneratorJob` generates a report about the org's main subscription lifecycle event. Firing it for AI credit subscription cancellation would generate a misleading report — the trigger `'subscription_canceled'` implies the main plan, not a credit add-on.

DEVIATION: [sync_with_stripe not called for credit-pack in deleted handler] | ANALOG: [stripe_webhook_handler_job.rb (develop):146 calls sync_with_stripe conditionally] | OURS: [stripe_webhook_handler_job.rb:163-174 credit-pack branch does not call sync_with_stripe] | SANCTIONED: no

WHITELIST: Same reasoning as the `updated` handler — `sync_with_stripe` operates on org-level main-plan fields and filters out credit subscriptions anyway. Calling it would be a near-no-op. The credit-pack branch correctly updates only the purchase record.

DEVIATION: [subscription_ended_at guard absent on credit-pack branch] | ANALOG: [stripe_webhook_handler_job.rb (develop):146 guards sync_with_stripe with `stripe_subscription_id == organization&.stripe_subscription_id`] | OURS: [stripe_webhook_handler_job.rb:167-174 credit-pack branch has no equivalent guard — finds purchase by stripe_subscription_id which is itself an implicit guard via the query] | SANCTIONED: yes (Sub change #2 — the find_by query serves as the guard; if no matching purchase exists, `purchase&.update` is a safe no-op)

---

## Summary of All Deviations

| # | Aspect | Sanctioned? | Disposition |
|---|--------|-------------|-------------|
| 1 | sync_with_stripe order swapped in updated handler (now before stripe_update_default_payment_method in main-plan branch) | No | **FIX**: Restore analog order — `stripe_update_default_payment_method` then `sync_with_stripe` |
| 2 | sync_with_stripe omitted from credit-pack branch in updated handler | No | WHITELIST: sync_with_stripe filters out credit subscriptions; would be near-no-op |
| 3 | plan_lookup_key extraction added to deleted handler | Yes | Needed for branch routing |
| 4 | subscription_status hardcoded to :canceled in deleted credit-pack branch vs object.status in updated | No | REVERT: Consider using object.status for consistency, though :canceled is correct for deleted events |
| 5 | update vs update_column for subscription_canceled_at | Yes (Sub change #2) | Using update is safer |
| 6 | PaidSubscriptionDeletedJob not fired for credit-pack deletion | No | WHITELIST: Job is main-plan-specific; firing for credit subscription would be misleading |
| 7 | EngagementReport::GeneratorJob not fired for credit-pack deletion | No | WHITELIST: Job is main-plan-specific; firing for credit subscription would generate misleading report |
| 8 | sync_with_stripe not called for credit-pack in deleted handler | No | WHITELIST: Same as #2 |
| 9 | stripe_update_default_payment_method runs for both branches (outside if/else) in updated handler | Yes | Matches analog's unconditional behavior |
| 10 | No subscription_ended_at ID guard on credit-pack deleted branch | Yes (Sub change #2) | find_by query is the implicit guard |

**Critical finding (#1):** The `sync_with_stripe` / `stripe_update_default_payment_method` order is swapped in the main-plan else branch compared to the analog. In the analog: `update` → `stripe_update_default_payment_method` → `sync_with_stripe`. In ours: `update` → `sync_with_stripe` → `stripe_update_default_payment_method`. This is a behavioral change to the main-plan path that has nothing to do with AI credit subscriptions — it is collateral damage from restructuring the code into if/else branches. The `sync_with_stripe` method itself calls `stripe_update_default_payment_method` conditionally (line 578), so the reordering could cause the payment method to be updated twice or with different values depending on timing.
