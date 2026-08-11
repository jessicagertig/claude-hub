# Round 4 — Audit Results

Now let me check whether the WWR webhook handler uses `find` (raises) vs the AI credit one using `find_by` (returns nil).

I have all the data I need. Let me now compile the full deviation report.

---

Here is the complete deviation audit for the AI credit one-off purchase flow vs the WWR analog.

---

## MODEL: `board_wwr_listing.rb` vs `organization_ai_credit_purchase.rb`

### charge method: `charge_for_listing` vs `charge_for_purchase`

DEVIATION: [charge method - logging "Attempt to charge"] | ANALOG: board_wwr_listing.rb:114 `Rails.logger.info 'Attempt to charge for WWR Listing'` | OURS: organization_ai_credit_purchase.rb:192 `ap 'Attempt to charge for AI Credit One-Off Purchase'` | SANCTIONED: no
Analog uses `Rails.logger.info`, ours uses `ap`.

DEVIATION: [charge method - already-charged guard log] | ANALOG: board_wwr_listing.rb:116 `ap 'Hmm, if trying to charge for an update because of expiration we run into a small issue'` | OURS: organization_ai_credit_purchase.rb:195 `ap 'Already charged for this AI credit one-off purchase'` | SANCTIONED: no
REVERT: The analog's message is weird/legacy ("Hmm, if trying to charge..."), our cleaner message is better. Keep ours.

DEVIATION: [charge method - org lookup] | ANALOG: board_wwr_listing.rb:121 `organization = job.organization` then checks `organization.stripe_customer_id.blank?` | OURS: organization_ai_credit_purchase.rb:200 `organization.stripe_customer_id.blank?` (uses `belongs_to :organization` directly) | SANCTIONED: yes (Sub change #2 -- operates on OrganizationAiCreditPurchase record, not org via job)

DEVIATION: [charge method - "Charging..." log] | ANALOG: board_wwr_listing.rb:128 `Rails.logger.info 'Charging...'` | OURS: organization_ai_credit_purchase.rb:205 `ap 'Charging...'` | SANCTIONED: no
Analog uses `Rails.logger.info`, ours uses `ap`.

DEVIATION: [charge method - "Invoice Has Been Finalized" log] | ANALOG: board_wwr_listing.rb:160-161 `Rails.logger.info 'Invoice Has Been Finalized'` + `Rails.logger.info [invoice_item, paid_invoice]` | OURS: organization_ai_credit_purchase.rb:230 `ap 'Invoice Has Been Finalized'` (no second log line with objects) | SANCTIONED: no
Analog uses `Rails.logger.info` and logs the objects; ours uses `ap` and omits the objects log line.

DEVIATION: [charge method - invoice description constant] | ANALOG: board_wwr_listing.rb:147 invoice `description: 'We Work Remotely Listing'` (hardcoded constant) | OURS: organization_ai_credit_purchase.rb:220 invoice `description: 'AI Credit Top-Up'` (hardcoded constant) | SANCTIONED: yes (Sub change #5 -- ai_credit_* descriptor naming)

DEVIATION: [charge method - metadata key] | ANALOG: board_wwr_listing.rb:136,149 metadata key `board_wwr_listing_id: id` | OURS: organization_ai_credit_purchase.rb:213,222 metadata key `organization_ai_credit_purchase_id: id` | SANCTIONED: yes (Sub change #2)

### post-payment webhook callback: `create_on_wwr` vs `grant_one_off_credits`

DEVIATION: [post-payment - broadcast_show_growl call] | ANALOG: board_wwr_listing.rb:194 calls `broadcast_show_growl('Created WWR Listing')` inside `create_on_wwr` | OURS: organization_ai_credit_purchase.rb `grant_one_off_credits` does NOT call `broadcast_show_growl` | SANCTIONED: no
The analog broadcasts a toast to the user after the post-payment action completes. Ours does not. The webhook handler (line 252) calls `broadcast_event` but never `broadcast_show_growl`.

DEVIATION: [post-payment - broadcast_event call location] | ANALOG: board_wwr_listing.rb:193 calls `broadcast_event('wwr_listing_published')` inside the model's `create_on_wwr` method | OURS: stripe_webhook_handler_job.rb:252 calls `purchase.broadcast_event('ai_credit_top_up_payment_received')` in the webhook handler, NOT inside `grant_one_off_credits` | SANCTIONED: no
The analog calls broadcast_event inside the model method. Ours calls it from the webhook handler instead. This means if `grant_one_off_credits` is ever called from another code path, no broadcast fires.

DEVIATION: [post-payment - broadcast_event channel] | ANALOG: board_wwr_listing.rb:268 broadcasts to `JobChannel.broadcast_to(job, ...)` | OURS: organization_ai_credit_purchase.rb:169 broadcasts to `GlobalChannel.broadcast_to(organization.owner, ...)` | SANCTIONED: yes (Sub change #2 -- AI credit purchases belong to org, not a job, so GlobalChannel is correct)

DEVIATION: [post-payment - broadcast_event payload shape] | ANALOG: board_wwr_listing.rb:268 payload `{ jobId: job.id, boardWwrListingId: id, wwrSlug: wwr_slug, publishedAt: published_at }` | OURS: organization_ai_credit_purchase.rb:169 payload `{ organizationId: organization.id, organizationAiCreditPurchaseId: id }` | SANCTIONED: yes (Sub change #2 -- different entity, different payload fields)

DEVIATION: [post-payment - notification job arguments] | ANALOG: board_wwr_listing.rb:196 `Notification::PaidWwrListingCreatedJob.perform_later(job.organization.id, job.id)` (passes org_id, job_id) | OURS: organization_ai_credit_purchase.rb:162 `Notification::AiCreditTopUpPurchasedJob.perform_later(organization.id, id)` (passes org_id, purchase_id) | SANCTIONED: yes (Sub change #2)

### broadcast_show_growl target

DEVIATION: [broadcast_show_growl - target user] | ANALOG: board_wwr_listing.rb:272 `last_updated_by_organization_user_id.nil? ? job.organization.owner : last_updated_by_organization_user.user` (falls back from acting user to owner) | OURS: organization_ai_credit_purchase.rb:173 `organization.owner` (always owner, no acting-user fallback) | SANCTIONED: no
The analog targets the user who initiated the action (with owner fallback). Ours always targets the owner, even if a non-owner admin initiated the purchase.

### is_active? method

DEVIATION: [is_active? complexity] | ANALOG: board_wwr_listing.rb:54-56 `expires_at.present? && expires_at > DateTime.now && approved?` | OURS: organization_ai_credit_purchase.rb:122-128 has if/else for subscription vs one_off | SANCTIONED: yes (Sub change #2 -- AI credit purchase has two kinds)

### finalize_stripe_payment

MATCH: Both models have identical `finalize_stripe_payment` that calls `update_columns(stripe_invoice_paid: true)`.

---

## CONTROLLER: `board_wwr_listings_controller.rb#create` vs `organization_ai_credit_purchases_controller.rb#create_top_up`

DEVIATION: [controller action - authorize call] | ANALOG: board_wwr_listings_controller.rb:19 `authorize @listing` (model-level Pundit policy) | OURS: organization_ai_credit_purchases_controller.rb:69 `authorize :billing, :checkout?` (headless billing policy) | SANCTIONED: no
The analog authorizes the listing model. Ours uses a headless billing policy. This means the authorization check is at a different granularity. The WhatJobs analog `create_paid_listing` (line 133) also uses `authorize :billing, :checkout?`, so this matches the WhatJobs pattern but deviates from WWR.
WHITELIST: The WWR `create` action uses model-level authorization because it is a RESTful resource `create`. The AI credit `create_top_up` is a collection action on a `resource` (singular), so model-level authorize on a new unsaved record would be awkward. Using the billing policy matches the checkout_session patterns across all three domains.

DEVIATION: [controller action - exists() wrapper] | ANALOG: board_wwr_listings_controller.rb:6 wraps entire action in `exists(current_organization.jobs.where(id: params[:job_id]), 'no job found') do |job|` | OURS: organization_ai_credit_purchases_controller.rb:68-94 has no `exists()` wrapper | SANCTIONED: yes (Sub change #2 -- AI credit purchases are not job-scoped, so there is no job to look up)

DEVIATION: [controller action - description blank guard] | ANALOG: board_wwr_listings_controller.rb:8 `render_general_errors(['Job description cannot be blank']) if job.description.blank?` | OURS: (absent) | SANCTIONED: yes (Sub change #2 -- AI credit purchases have no job description)

DEVIATION: [controller action - last_updated_by_organization_user merge] | ANALOG: board_wwr_listings_controller.rb:11 `temp_params = listing_params.merge({ last_updated_by_organization_user: current_organization_user })` | OURS: (absent) | SANCTIONED: yes (Sub change #2 -- OrganizationAiCreditPurchase has no last_updated_by_organization_user field)

DEVIATION: [controller action - error rescue] | ANALOG: board_wwr_listings_controller.rb:28-31 `rescue StandardError => e` with `render_general_errors(["Unable to process payment: #{e.message}"])` | OURS: organization_ai_credit_purchases_controller.rb:88-93 has TWO rescue blocks: `rescue Stripe::StripeError` then `rescue StandardError` | SANCTIONED: no
Ours adds a separate `Stripe::StripeError` rescue with "Payment failed:" message before the `StandardError` rescue with "Unable to process payment:" message. The analog catches everything as `StandardError`. The WhatJobs `create_paid_listing` (lines 171-178) has this same two-rescue pattern, so this matches WhatJobs but not WWR.
WHITELIST: Having a more specific Stripe error message is a strictly better pattern than the analog. It differentiates payment failures from other errors.

DEVIATION: [controller action - error log message] | ANALOG: board_wwr_listings_controller.rb:29 `Rails.logger.error "Failed to charge for WWR listing: #{e.message}"` | OURS: organization_ai_credit_purchases_controller.rb:89,92 `Rails.logger.error "Failed to charge for AI credit one-off purchase: #{e.message}"` | SANCTIONED: yes (Sub change #5)

---

## CONTROLLER: `board_wwr_listings_controller.rb#create_checkout_session` vs `organization_ai_credit_purchases_controller.rb#create_top_up_checkout_session`

DEVIATION: [checkout session - record creation timing] | ANALOG: board_wwr_listings_controller.rb:58-76 creates listing, saves it, THEN creates Stripe session | OURS: organization_ai_credit_purchases_controller.rb:99-110 creates purchase, saves it, THEN creates Stripe session | SANCTIONED: no
MATCH: Both follow the same pattern (create record first, then Stripe session).

DEVIATION: [checkout session - stripe_checkout_session_id update] | ANALOG: board_wwr_listings_controller.rb (does NOT save stripe_checkout_session_id on the listing) | OURS: organization_ai_credit_purchases_controller.rb:154 `@purchase.update_columns(stripe_checkout_session_id: session.id)` | SANCTIONED: no
The analog WWR listing does not store the checkout session ID on the record. Our code does. The WWR webhook handler finds the listing via invoice metadata, not via checkout session ID. However, this is needed for our subscription flow (where checkout.session.completed links the subscription), and being consistent across one-off and subscription flows is reasonable.
WHITELIST: The AI credit one-off purchase needs `stripe_checkout_session_id` stored for consistency with the subscription purchase flow and for potential refund lookups via `handle_charge_refunded` (which uses `find_by(stripe_checkout_session_id: session.id, kind: :one_off)`).

DEVIATION: [checkout session - checkout session metadata keys] | ANALOG: board_wwr_listings_controller.rb:94-99 `payment_intent_data.metadata` has `board_wwr_listing_id`, `organization_id`, `job_id` | OURS: organization_ai_credit_purchases_controller.rb:131-134 `payment_intent_data.metadata` has `organization_ai_credit_purchase_id`, `organization_id` (no `job_id`) | SANCTIONED: yes (Sub change #2 -- no job association)

DEVIATION: [checkout session - invoice_data.metadata keys] | ANALOG: board_wwr_listings_controller.rb:105-107 `invoice_data.metadata` has `board_wwr_listing_id`, `job_id` | OURS: organization_ai_credit_purchases_controller.rb:141-143 `invoice_data.metadata` has `organization_ai_credit_purchase_id`, `organization_id` | SANCTIONED: no
The analog puts `job_id` in invoice metadata (alongside listing ID). Ours puts `organization_id` in invoice metadata (alongside purchase ID). Different secondary key. The analog does NOT put `organization_id` in invoice metadata; ours does NOT put any job-scoped key. This is structurally equivalent but adds `organization_id` where the analog had `job_id`.
WHITELIST: Since AI credit purchases are org-scoped not job-scoped, substituting `organization_id` for `job_id` as the secondary metadata key is the correct adaptation.

DEVIATION: [checkout session - top-level session metadata keys] | ANALOG: board_wwr_listings_controller.rb:111-115 session metadata has `board_wwr_listing_id`, `organization_id`, `job_id` | OURS: organization_ai_credit_purchases_controller.rb:146-149 session metadata has `organization_ai_credit_purchase_id`, `organization_id` (no `job_id`) | SANCTIONED: yes (Sub change #2)

DEVIATION: [checkout session - product_data.name format] | ANALOG: board_wwr_listings_controller.rb:87-88 `name: "#{job.title} - We Work Remotely Job Listing"` (includes job title) | OURS: organization_ai_credit_purchases_controller.rb:123 `name: @description` (pack name from lookup table) | SANCTIONED: yes (Sub change #5 -- AI credits have no job title to reference)

DEVIATION: [checkout session - product_data.description] | ANALOG: board_wwr_listings_controller.rb:88 `description: @final_description` (includes discount info if applicable) | OURS: organization_ai_credit_purchases_controller.rb:124 `description: @description` (same as name, no additional detail) | SANCTIONED: no
The analog computes a separate, more detailed description that includes discount info. Ours just repeats the name. There is no discount concept for AI credit top-ups, so the "final_description" transformation has nothing to add, but structurally the analog has `@description` for name and `@final_description` for description (two distinct values), while ours uses the same variable for both.
REVERT: Cosmetic. The description field echoing the name is fine since there's no discount to add for AI credit top-ups.

DEVIATION: [checkout session - success_url] | ANALOG: board_wwr_listings_controller.rb:116 `success_url: "#{Variables::AtsRootUrl}/jobs/#{job.id}/distribution/weworkremotely?checkout=success&session_id={CHECKOUT_SESSION_ID}"` | OURS: organization_ai_credit_purchases_controller.rb:150 `success_url: "#{Variables::AtsRootUrl}/hire/settings/billing?ai_credit_top_up_success=1&session_id={CHECKOUT_SESSION_ID}"` | SANCTIONED: yes (Sub change #5 -- different page in the app)

DEVIATION: [checkout session - cancel_url] | ANALOG: board_wwr_listings_controller.rb:117 `cancel_url: "#{Variables::AtsRootUrl}/jobs/#{job.id}/distribution/weworkremotely?checkout=cancel&session_id={CHECKOUT_SESSION_ID}"` | OURS: organization_ai_credit_purchases_controller.rb:151 `cancel_url: "#{Variables::AtsRootUrl}/hire/settings/billing?ai_credit_top_up_cancel=1&session_id={CHECKOUT_SESSION_ID}"` | SANCTIONED: yes (Sub change #5)

---

## WEBHOOK HANDLER: `stripe_webhook_handler_job.rb` - `invoice.paid` branch

### WWR branch (lines 210-221) vs AI credit one-off purchase branch (lines 241-257)

DEVIATION: [webhook - record lookup method] | ANALOG: stripe_webhook_handler_job.rb:214 `BoardWwrListing.find(listing_id)` (raises RecordNotFound) | OURS: stripe_webhook_handler_job.rb:245 `OrganizationAiCreditPurchase.find_by(id: purchase_id)` (returns nil) | SANCTIONED: no
The analog uses `find` which raises `ActiveRecord::RecordNotFound` if the record doesn't exist. Ours uses `find_by(id:)` which returns nil. The WhatJobs branch (line 227) also uses `find`. This is a behavioral difference: if the record is missing, the analog raises into the `rescue StandardError`, while ours silently no-ops. The `if purchase&.present?` guard on line 247 makes it safe but the error is swallowed.

DEVIATION: [webhook - guard pattern] | ANALOG: stripe_webhook_handler_job.rb:216 `if listing&.present?` | OURS: stripe_webhook_handler_job.rb:247 `if purchase&.present?` | SANCTIONED: no
MATCH structurally, but the `&.present?` guard is redundant with `find` (which always returns a non-nil record or raises) in the analog. With `find_by` in ours, the guard is actually meaningful. This is a consequence of the `find` vs `find_by` deviation above.

DEVIATION: [webhook - broadcast_event in handler] | ANALOG: stripe_webhook_handler_job.rb:210-221 WWR branch does NOT call `broadcast_event` in the handler (it's inside `create_on_wwr`) | OURS: stripe_webhook_handler_job.rb:252 calls `purchase.broadcast_event('ai_credit_top_up_payment_received')` in the handler | SANCTIONED: no
This is the inverse of the model-level deviation noted above. The analog encapsulates broadcast inside the model callback; ours splits it between handler (broadcast_event) and model (notification job in grant_one_off_credits). The WhatJobs branch (line 234) also calls `broadcast_event` in the handler, so our pattern matches WhatJobs but not WWR.
WHITELIST: The WhatJobs branch was written more recently and the pattern of calling broadcast_event in the handler is a deliberate evolution. AI credits follows the WhatJobs pattern. Breaking it apart to match WWR would be regressive.

DEVIATION: [webhook - broadcast_show_growl missing from entire one-off flow] | ANALOG: board_wwr_listing.rb:194 `broadcast_show_growl('Created WWR Listing')` is called inside `create_on_wwr` | OURS: Neither `grant_one_off_credits` nor the webhook handler calls `broadcast_show_growl` | SANCTIONED: no
The user never sees a toast notification when their AI credit one-off purchase completes. The analog shows "Created WWR Listing" toast. The WhatJobs analog also shows a toast (via `what_jobs_listing.rb` service calling `broadcast_show_growl`). This is a missing user feedback signal.

DEVIATION: [webhook - Rails.logger.info confirmation line] | ANALOG: (WWR branch has no extra confirmation log between finalize and create_on_wwr) | OURS: stripe_webhook_handler_job.rb:250 `Rails.logger.info "AI credit one-off purchase #{purchase_id} payment confirmed"` | SANCTIONED: no
The WWR branch does not have this line. The WhatJobs branch (line 232) does: `Rails.logger.info "WhatJobs listing #{listing_id} payment confirmed"`. So this matches WhatJobs but is extra vs WWR.
WHITELIST: Matches the more recent WhatJobs pattern. Additional logging is strictly better.

---

## MODEL: `charge_for_listing` vs `charge_for_purchase` - calculate_charge_amount

DEVIATION: [calculate_charge_amount - implementation] | ANALOG: board_wwr_listing.rb:84-110 hardcoded pricing with plan-based calculation and discount logic | OURS: organization_ai_credit_purchase.rb:182-188 fetches price from Stripe API by lookup_key | SANCTIONED: no
The analog computes the price locally from hardcoded values plus a discount. Ours makes a Stripe API call to fetch the price. This is a fundamentally different approach. However, the comment at line 176-181 explicitly documents this as an intentional structural difference.
WHITELIST: AI credit prices are set in Stripe by lookup_key and are dynamic. Hardcoding them would create a sync problem. The Stripe API lookup is the correct approach for this domain.

---

## MODEL: `broadcast_show_growl` definition

DEVIATION: [broadcast_show_growl - target user resolution] | ANALOG: board_wwr_listing.rb:272 `last_updated_by_organization_user_id.nil? ? job.organization.owner : last_updated_by_organization_user.user` | OURS: organization_ai_credit_purchase.rb:173 `organization.owner` | SANCTIONED: no
The analog resolves the target user to the person who initiated the action (with owner fallback). Ours always targets the organization owner. If a non-owner admin purchases credits, they won't see the toast; the owner will. Note: `OrganizationAiCreditPurchase` has no `last_updated_by_organization_user` association, so this would require adding the association to match the analog.

---

## CONTROLLER: `create_top_up` action - record build pattern

DEVIATION: [create_top_up - currency set at build time] | ANALOG: board_wwr_listing.rb charge_for_listing does NOT set currency (hardcoded to 'usd' in the InvoiceItem.create call only) | OURS: organization_ai_credit_purchases_controller.rb:77 sets `currency: 'usd'` on the record at build time | SANCTIONED: no
The analog never stores currency on the record. Our model has a `currency` column and sets it at build time. This is structurally different but the `OrganizationAiCreditPurchase` model has explicit validations requiring currency when stripe_invoice_id is present, so setting it early is correct for our model.
WHITELIST: The AI credit purchase model has currency validations that the listing models don't have. Setting it at build time satisfies the validation contract.

---

## SUMMARY OF NON-SANCTIONED DEVIATIONS

1. **`charge_for_purchase` uses `ap` instead of `Rails.logger.info` for "Attempt to charge" log** (line 192)
2. **`charge_for_purchase` uses `ap` instead of `Rails.logger.info` for "Charging..." log** (line 205)
3. **`charge_for_purchase` uses `ap` instead of `Rails.logger.info` for "Invoice Has Been Finalized" log** (line 230)
4. **`charge_for_purchase` omits second log line logging the objects** `[invoice_item, paid_invoice]` (analog line 161)
5. **`grant_one_off_credits` does not call `broadcast_show_growl`** -- user gets no toast when purchase completes
6. **`broadcast_event` is called from webhook handler, not from model method** -- inconsistent with WWR (matches WhatJobs)
7. **`broadcast_show_growl` always targets `organization.owner`** instead of acting-user-with-owner-fallback
8. **Webhook handler uses `find_by(id:)` instead of `find`** -- silently swallows missing records instead of raising
9. **`create_top_up` has separate `Stripe::StripeError` rescue** (analog only has `StandardError`) -- matches WhatJobs
10. **`create_top_up_checkout_session` stores `stripe_checkout_session_id` on record** -- analog does not store session ID on listing
11. **`calculate_charge_amount` fetches price from Stripe API** instead of local computation
12. **`currency: 'usd'` set at record build time** in controller -- analog never stores currency on record

## WHITELISTED (non-sanctioned but should NOT be changed)

- #6: broadcast_event in handler matches WhatJobs (newer, better pattern)
- #9: Separate Stripe error rescue is strictly better error differentiation
- #10: stripe_checkout_session_id needed for refund flow and subscription consistency
- #11: Dynamic Stripe pricing is correct for lookup-key-based pricing
- #12: Currency at build time satisfies model validation contract

## REVERT (match exists but current version is acceptable/better)

- "Already charged" ap message: Analog's message is legacy/confusing, ours is clearer
- product_data.description echoing name: Cosmetic, no discount concept to differentiate

## ACTION ITEMS (deviations that should be fixed to match analog)

1. **Lines 192, 205, 230 in `organization_ai_credit_purchase.rb`**: Change `ap` calls to `Rails.logger.info` to match analog's logging approach in `charge_for_listing`
2. **Line 230 in `organization_ai_credit_purchase.rb`**: Add second log line `Rails.logger.info [invoice_item, paid_invoice]` after "Invoice Has Been Finalized" to match analog line 161
3. **`grant_one_off_credits` in `organization_ai_credit_purchase.rb`**: Add `broadcast_show_growl('Purchased AI Credit Top-Up')` call (or similar) after the notification job dispatch, matching how `create_on_wwr` calls `broadcast_show_growl('Created WWR Listing')` at line 194
4. **`broadcast_show_growl` in `organization_ai_credit_purchase.rb` line 173**: Consider adding a `last_updated_by_organization_user` association and using the analog's acting-user-with-owner-fallback pattern. If adding the association is too invasive, at minimum document the deviation.
5. **Webhook handler line 245**: Change `OrganizationAiCreditPurchase.find_by(id: purchase_id)` to `OrganizationAiCreditPurchase.find(purchase_id)` to match analog's `BoardWwrListing.find(listing_id)` behavior (raises on missing record instead of silently no-oping)

---NEXT DIMENSION---

PostHog only in the subscription change portal, not in one-off purchase. Neither WhatJobs nor AI credit one-off have PostHog. Match.

Let me check one more structural point -- the `checkout_session_id` tracking for refund lookups. WhatJobs does NOT store a `stripe_checkout_session_id` on the listing; AI credit one-off does (set in `create_top_up_checkout_session`). This is needed for `handle_charge_refunded`. Let me verify the refund handler is only for AI credits:

Looking at `handle_charge_refunded` (lines 431-457) -- entirely AI credit specific. There's no listing refund handler. The `stripe_checkout_session_id` on the purchase record is used by this refund handler to find one-off purchases.

Let me now check if the WhatJobs `create_checkout_session` action stores ANYTHING back to the listing after creating the session:

WhatJobs `create_checkout_session` (lines 180-266): After creating the Stripe session, it just renders `{ url: session.url, sessionId: session.id }`. Does NOT update the listing.

But the listing was already saved before creating the session (via `CreateOrUpdateWhatJobsListingWithIntegration`), and the listing's ID is in the Stripe metadata. The webhook will find it via metadata.

AI credit `create_top_up_checkout_session` (lines 96-163): After creating the session, it calls `@purchase.update_columns(stripe_checkout_session_id: session.id)`. This is extra.

Now I have all the information I need. Let me compile the deviations.

---

DEVIATION: webhook find pattern | ANALOG: stripe_webhook_handler_job.rb:227 `BoardWhatJobsListing.find(listing_id)` uses `find` which raises ActiveRecord::RecordNotFound on missing record | OURS: stripe_webhook_handler_job.rb:245 `OrganizationAiCreditPurchase.find_by(id: purchase_id)` uses `find_by` which returns nil on missing record | SANCTIONED: no

DEVIATION: broadcast_show_growl never called | ANALOG: WhatJobsListing service (what_jobs_listing.rb:53) calls `broadcast_show_growl('Created WhatJobs Listing')` after successful publishing; BoardWwrListing (board_wwr_listing.rb:194) calls `broadcast_show_growl('Created WWR Listing')` after successful creation | OURS: organization_ai_credit_purchase.rb:172 defines `broadcast_show_growl` but it is never called anywhere -- `grant_one_off_credits` does not call it after successfully granting credits | SANCTIONED: no

DEVIATION: broadcast_error_growl absent | ANALOG: board_what_jobs_listing.rb:296 defines `broadcast_error_growl(message)` used by WhatJobsListing service (what_jobs_listing.rb:145,151) to notify user of API failures | OURS: organization_ai_credit_purchase.rb has no `broadcast_error_growl` method at all | SANCTIONED: no

DEVIATION: calculate_charge_amount makes Stripe API call | ANALOG: board_what_jobs_listing.rb:151-154 returns hardcoded `17_500` with no external calls | OURS: organization_ai_credit_purchase.rb:182-188 calls `Stripe::Price.list` to fetch price dynamically. Comment on lines 176-181 documents this as intentional | SANCTIONED: no

DEVIATION: "defensive check" comment from WWR not WhatJobs | ANALOG: board_what_jobs_listing.rb has no "defensive check" comment in `charge_for_listing` | OURS: organization_ai_credit_purchase.rb:198 has comment `# defensive check shouldn't be necessary since we only call this after_create but worth it anyway` copied from board_wwr_listing.rb:119, not from the WhatJobs analog | SANCTIONED: no
REVERT: cosmetic comment; harmless but sourced from wrong analog

DEVIATION: idempotency guard uses is_active? not live? | ANALOG: board_what_jobs_listing.rb:160 uses `live?` (checks `what_jobs_expires_at.present? && what_jobs_expires_at > DateTime.now && active?`) | OURS: organization_ai_credit_purchase.rb:194 uses `is_active?` which for one_off returns `stripe_invoice_paid?` | SANCTIONED: yes (Sub change #2 -- operates on OrganizationAiCreditPurchase record not org, different lifecycle)

DEVIATION: no intermediate organization local variable | ANALOG: board_what_jobs_listing.rb:165 `organization = job.organization` then references local var | OURS: organization_ai_credit_purchase.rb:200 references `organization` directly via belongs_to association, no intermediate local variable | SANCTIONED: yes (Sub change #2)

DEVIATION: charge_for_purchase description uses org name not job title | ANALOG: board_what_jobs_listing.rb:168 `@description = "WhatJobs Job listing - #{job.title}"` | OURS: organization_ai_credit_purchase.rb:202-203 `@description = "#{pack_name} - #{organization.name}"` uses pack name and org name | SANCTIONED: yes (Sub change #5 -- ai_credit_* descriptor naming)

DEVIATION: checkout session stores session ID back on record | ANALOG: board_what_jobs_listings_controller.rb:180-266 `create_checkout_session` does NOT update the listing with the checkout session ID after creating the Stripe session | OURS: organization_ai_credit_purchases_controller.rb:154 `@purchase.update_columns(stripe_checkout_session_id: session.id)` saves checkout session ID back to the purchase record | SANCTIONED: no
WHITELIST: needed by `handle_charge_refunded` (stripe_webhook_handler_job.rb:448-451) which finds one-off purchases by `stripe_checkout_session_id`. Removing would break refund handling.

DEVIATION: charge.refunded handler exists with no listing analog | ANALOG: WhatJobs has no refund handling at all -- no `charge.refunded` webhook branch exists for listing payments | OURS: stripe_webhook_handler_job.rb:294-298 + 431-457 `handle_charge_refunded` handles refunds for AI credit purchases (both one-off and subscription) | SANCTIONED: no
WHITELIST: removing would break subscription refund handling which also uses this method. The method handles both one-off and subscription refunds.

DEVIATION: broadcast_event uses GlobalChannel not JobChannel | ANALOG: board_what_jobs_listing.rb:288-289 `broadcast_event` uses `JobChannel.broadcast_to(job, ...)` | OURS: organization_ai_credit_purchase.rb:168-169 `broadcast_event` uses `GlobalChannel.broadcast_to(organization.owner, ...)` | SANCTIONED: yes (Sub change #2 -- AI credit purchases are org-level, not job-level; no job to broadcast to)

DEVIATION: broadcast_event payload shape differs | ANALOG: board_what_jobs_listing.rb:289 payload is `{ jobId:, boardWhatJobsListingId:, whatJobsJobUrl:, publishedAt: }` | OURS: organization_ai_credit_purchase.rb:169 payload is `{ organizationId:, organizationAiCreditPurchaseId: }` | SANCTIONED: yes (Sub change #2 + #5)

DEVIATION: broadcast_show_growl recipient always org owner | ANALOG: board_what_jobs_listing.rb:292-293 routes growl to `last_updated_by_organization_user.user` if present, else `job.organization.owner` | OURS: organization_ai_credit_purchase.rb:172-173 always routes to `organization.owner` with no fallback to the acting user | SANCTIONED: no

DEVIATION: no last_updated_by_organization_user association | ANALOG: board_what_jobs_listing.rb:5 `belongs_to :last_updated_by_organization_user, class_name: 'OrganizationUser', optional: true` tracks who initiated the action | OURS: organization_ai_credit_purchase.rb has no equivalent association tracking who initiated the purchase | SANCTIONED: no

DEVIATION: grant_one_off_credits rescue logs at info level | ANALOG: WhatJobsListing service (what_jobs_listing.rb:62-65) rescues API errors with `handle_api_error` which fires Discord + Slack notifications + error growl to user | OURS: organization_ai_credit_purchase.rb:163-165 rescues with `Rails.logger.info` only, no external notifications on grant failure | SANCTIONED: no
WHITELIST: `grant_one_off_credits` failure is an internal ledger write, not an external API call. Sending Discord/Slack notifications for a DB write failure would be a different pattern than the analog's API-failure notifications. However, `broadcast_error_growl` to the user would be appropriate -- that is covered by the "broadcast_error_growl absent" deviation above.

DEVIATION: controller create_top_up has no interactor | ANALOG: board_what_jobs_listings_controller.rb:132-178 `create_paid_listing` uses `CreateOrUpdateWhatJobsListingWithIntegration` interactor to create/update the record, then calls `ValidateWhatJobsListing` for validation | OURS: organization_ai_credit_purchases_controller.rb:68-94 `create_top_up` creates `OrganizationAiCreditPurchase.new(...)` directly in the controller, no interactor | SANCTIONED: no

DEVIATION: controller create_top_up has no separate validation step | ANALOG: board_what_jobs_listings_controller.rb:155-160 calls `ValidateWhatJobsListing.call(listing: @listing, job: job)` before charging | OURS: organization_ai_credit_purchases_controller.rb:68-94 relies only on ActiveRecord model validations in `@purchase.save`, no separate validation interactor | SANCTIONED: no

DEVIATION: controller create_top_up missing WhatJobsApi::ValidationError rescue | ANALOG: board_what_jobs_listings_controller.rb:167-168 has `rescue WhatJobsApi::ValidationError => e` | OURS: organization_ai_credit_purchases_controller.rb:88-93 has no equivalent domain-specific error rescue (only Stripe::StripeError and StandardError) | SANCTIONED: yes (no external API call to produce a domain-specific validation error)

DEVIATION: controller create_top_up_checkout_session stores checkout_session_id after creation | ANALOG: board_what_jobs_listings_controller.rb:180-266 does NOT update the listing after creating the Stripe checkout session | OURS: organization_ai_credit_purchases_controller.rb:154 `@purchase.update_columns(stripe_checkout_session_id: session.id)` | SANCTIONED: no
WHITELIST: (same as earlier) needed by `handle_charge_refunded` for one-off refund lookup

DEVIATION: checkout session metadata has no job_id | ANALOG: board_what_jobs_listings_controller.rb:237-239 `payment_intent_data.metadata` includes `job_id` | OURS: organization_ai_credit_purchases_controller.rb:131-134 `payment_intent_data.metadata` has no `job_id` | SANCTIONED: yes (Sub change #2 -- AI credit purchases are not job-scoped)

DEVIATION: checkout session invoice_data.metadata has no job_id | ANALOG: board_what_jobs_listings_controller.rb:246-249 `invoice_data.metadata` includes `job_id` | OURS: organization_ai_credit_purchases_controller.rb:140-143 `invoice_data.metadata` has no `job_id` | SANCTIONED: yes (Sub change #2)

DEVIATION: checkout session top-level metadata has no job_id | ANALOG: board_what_jobs_listings_controller.rb:252-256 top-level `metadata` includes `job_id` | OURS: organization_ai_credit_purchases_controller.rb:146-149 top-level `metadata` has no `job_id` | SANCTIONED: yes (Sub change #2)

DEVIATION: checkout session success/cancel URLs point to billing page | ANALOG: board_what_jobs_listings_controller.rb:257-258 success/cancel URLs point to `/jobs/#{job.id}/distribution/whatjobs` | OURS: organization_ai_credit_purchases_controller.rb:150-151 success/cancel URLs point to `/hire/settings/billing` | SANCTIONED: yes (Sub change #2 -- different UI context)

DEVIATION: checkout session line_items product_data.name format | ANALOG: board_what_jobs_listings_controller.rb:228 `name: "#{job.title} - WhatJobs Job Listing"` | OURS: organization_ai_credit_purchases_controller.rb:122-123 `name: @description` (the pack name) | SANCTIONED: yes (Sub change #5)

DEVIATION: Notification job gets (organization_id, purchase_id) not (organization_id, job_id) | ANALOG: board_wwr_listing.rb:196 `Notification::PaidWwrListingCreatedJob.perform_later(job.organization.id, job.id)` passes org_id and job_id; WhatJobs has no notification job | OURS: organization_ai_credit_purchase.rb:162 `Notification::AiCreditTopUpPurchasedJob.perform_later(organization.id, id)` passes org_id and purchase_id | SANCTIONED: yes (Sub change #2)

DEVIATION: AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY contains dev keys | ANALOG: board_what_jobs_listing.rb has no equivalent lookup table; board_wwr_listing.rb has no environment-specific pricing variants | OURS: organization_ai_credit_purchase.rb:37-56 has `# Development keys -- kept so local dev keeps working; remove before production` with 4 dev-only lookup keys | SANCTIONED: no

DEVIATION: model has subscription-related code interleaved with one-off code | ANALOG: board_what_jobs_listing.rb is purely a one-off purchase model with no subscription concept | OURS: organization_ai_credit_purchase.rb mixes subscription validations (lines 90-107), subscription enum (lines 82-84), subscription methods (is_active? subscription branch, stripe_subscription) with one-off purchase code | SANCTIONED: yes (Sub change #2 -- single model handles both purchase kinds)

DEVIATION: stripe_subscription method on model | ANALOG: board_what_jobs_listing.rb has no Stripe subscription retrieval method | OURS: organization_ai_credit_purchase.rb:235-239 `stripe_subscription` method retrieves subscription with expanded tiers | SANCTIONED: yes (Sub change #4 -- live-subscription endpoint retrieves by purchase.stripe_subscription_id)

---NEXT DIMENSION---

The Organization model does NOT have a `broadcast_event` method. This method on `OrganizationAiCreditPurchase` (line 168) mirrors the pattern used by `BoardWhatJobsListing#broadcast_event` (used at webhook handler line 234). This is relevant to the one-off purchase flow, not the subscription renewal flow. For subscription renewal (invoice.paid), there's no `broadcast_event` call — the analog doesn't broadcast and ours doesn't either.

Wait, let me re-check. For the subscription renewal path (lines 268-279), there's no `broadcast_event` call. For the one-off top-up path (lines 247-255), there IS `purchase.broadcast_event('ai_credit_top_up_payment_received')`. The one-off top-up is modeled after `BoardWhatJobsListing` (lines 229-237). Let me check whether the analog for one-off (BoardWhatJobsListing) has a broadcast. Yes, line 234: `listing.broadcast_event('what_jobs_listing_payment_received')`. Match.

For the subscription renewal, the analog (main-plan else branch lines 280-286) does NOT broadcast any event. Ours also does NOT broadcast. Match.

Now let me compile the final complete report.

---

**SCOPE: invoice.paid — AI credit subscription renewal vs main-plan subscription renewal**

DEVIATION: Guard on missing record | ANALOG: stripe_webhook_handler_job.rb:281 `raise CustomStripeSubscriptionMissingError if organization.stripe_subscription_id.nil?` — raises exception | OURS: stripe_webhook_handler_job.rb:278 `Rails.logger.error "invoice.paid: no OrganizationAiCreditPurchase..."` — logs only, does not raise | SANCTIONED: no

DEVIATION: Error propagation channels on missing record | ANALOG: stripe_webhook_handler_job.rb:281+287-292 raise propagates to rescue which logs via `Rails.logger.error` + `ap` + `puts` (3 channels) | OURS: stripe_webhook_handler_job.rb:278 logs via `Rails.logger.error` only (1 channel) | SANCTIONED: no

DEVIATION: Period start stored | ANALOG: stripe_webhook_handler_job.rb:283 stores ONLY `stripe_current_period_end_at` | OURS: stripe_webhook_handler_job.rb:272 stores `subscription_current_period_start` in addition to end | SANCTIONED: no | WHITELIST: removing the write would fail the purchase model's `validates :subscription_current_period_start, presence: true, if: -> { subscription? && stripe_subscription_id.present? }` validation at line 97-100 of organization_ai_credit_purchase.rb. The validation is shared infrastructure that other code paths rely on.

DEVIATION: Amount/currency stored on renewal | ANALOG: stripe_webhook_handler_job.rb:283 does NOT store payment amount or currency | OURS: stripe_webhook_handler_job.rb:270-271 stores `stripe_amount: object.amount_paid` and `currency: object.currency` | SANCTIONED: no | WHITELIST: removing these writes would fail the purchase model's `validates :stripe_amount, presence: true` (line 101-104) and `validates :currency, presence: true` (line 105-107) validations when `subscription? && stripe_subscription_id.present?`. These validations are shared infrastructure.

DEVIATION: stripe_update_default_payment_method call signature | ANALOG: stripe_webhook_handler_job.rb:284 `organization.stripe_update_default_payment_method` — no argument, resolves payment method from org's main subscription via `stripe_payment_method` | OURS: stripe_webhook_handler_job.rb:275 `organization.stripe_update_default_payment_method(stripe_subscription.default_payment_method)` — explicit argument from the AI credit subscription | SANCTIONED: yes (Sub change #4 — the AI credit subscription is a different Stripe subscription; without the explicit argument the method would resolve from the org's main subscription, which is wrong)

DEVIATION: Credit reset interactor — allocation resolution | ANALOG: reset_ai_credits.rb:94-99 `resolve_allocation` checks `balance.monthly_ai_credits_override` first, falls back to `PlanFeatureGate` | OURS: apply_ai_credit_purchase.rb:63 uses `purchase.subscription_credits_per_period` directly, no override mechanism | SANCTIONED: yes (Sub change #3 — no PlanFeatureGate; allocation is fixed by purchased tier, not plan-based)

DEVIATION: Credit reset interactor — bucket and entry types | ANALOG: reset_ai_credits.rb uses `monthly` bucket, `plan_monthly_reset_debit` / `plan_monthly_allocation_credit` entry types | OURS: apply_ai_credit_purchase.rb uses `addon_subscription` bucket, `subscription_credit_pack_reset_debit` / `subscription_credit_pack_purchase_credit` entry types | SANCTIONED: yes (Sub change #5 — ai_credit_* descriptor naming / different bucket)

DEVIATION: Credit reset interactor — grant description | ANALOG: reset_ai_credits.rb:58 `"Monthly credit grant for #{organization.plan}"` | OURS: apply_ai_credit_purchase.rb:70 `"Credit pack subscription grant for #{purchase.stripe_price_lookup_key}"` | SANCTIONED: yes (Sub change #5 — ai_credit_* descriptor naming)

DEVIATION: Credit reset interactor — reset description | ANALOG: reset_ai_credits.rb:45 `'Anniversary reset — clear previous monthly bucket'` | OURS: apply_ai_credit_purchase.rb:57 `'Subscription renewal reset — clear previous addon_subscription bucket'` | SANCTIONED: yes (Sub change #5 — ai_credit_* descriptor naming)

DEVIATION: Credit reset interactor — extra purchase nil guard | ANALOG: reset_ai_credits.rb — no purchase parameter, no purchase nil check | OURS: apply_ai_credit_purchase.rb:38-45 checks `unless purchase` and calls `context.fail!` | SANCTIONED: yes (Sub change #2 — operates on purchase record; nil guard structurally required)

DEVIATION: Credit reset interactor — grant row includes purchase association | ANALOG: reset_ai_credits.rb:53-54 grant `AiCreditBalanceTransaction` has no `organization_ai_credit_purchase` association | OURS: apply_ai_credit_purchase.rb:64-65 grant includes `organization_ai_credit_purchase: purchase` | SANCTIONED: yes (Sub change #2 — associates the ledger entry with the purchase record for audit trail)

DEVIATION: Credit reset interactor — zero-out row missing purchase association | ANALOG: reset_ai_credits.rb:40-41 zero-out `AiCreditBalanceTransaction` has no `organization_ai_credit_purchase` | OURS: apply_ai_credit_purchase.rb:51-52 zero-out row also has no `organization_ai_credit_purchase` | Match — no deviation.

DEVIATION: Call-site safe navigation | ANALOG: stripe_webhook_handler_job.rb:285 `organization.organization_ai_credit_balance&.reset_ai_credits` — `&.` means nil balance prevents interactor from being called | OURS: stripe_webhook_handler_job.rb:276 `ApplyAiCreditPurchase.call(organization: organization, purchase: purchase)` — no safe navigation at call site; nil balance handled inside interactor via `context.fail!` | SANCTIONED: no — the analog has two layers of nil-balance defense (call-site `&.` + interactor internal check). Ours has one (interactor internal check only). The analog pattern's `&.` on `organization_ai_credit_balance` before calling `reset_ai_credits` is a different calling convention than interactor dispatch, so it's not directly replicable, but the defense layer difference exists.

**SCOPE: customer.subscription.updated — AI credit subscription vs main-plan**

DEVIATION: Missing payment method update | ANALOG: stripe_webhook_handler_job.rb:141 `organization.stripe_update_default_payment_method(object.default_payment_method) if object.default_payment_method` | OURS: stripe_webhook_handler_job.rb:130-134 no payment method update | SANCTIONED: no

DEVIATION: Missing sync_with_stripe | ANALOG: stripe_webhook_handler_job.rb:142 `organization.sync_with_stripe` | OURS: stripe_webhook_handler_job.rb:130-134 no sync_with_stripe | SANCTIONED: yes (Sub change #3 — sync_with_stripe is main-plan infrastructure)

**SCOPE: customer.subscription.deleted — AI credit subscription vs main-plan**

DEVIATION: update vs update_column | ANALOG: stripe_webhook_handler_job.rb:179 `organization&.update_column(:subscription_canceled_at, ...)` — skips validations/callbacks | OURS: stripe_webhook_handler_job.rb:171 `purchase&.update(subscription_status:, subscription_canceled_at:)` — runs validations/callbacks | SANCTIONED: no

DEVIATION: subscription_status stored on deletion | ANALOG: stripe_webhook_handler_job.rb:179 stores ONLY `subscription_canceled_at`, does NOT explicitly store status | OURS: stripe_webhook_handler_job.rb:171-173 stores BOTH `subscription_status` and `subscription_canceled_at` | SANCTIONED: no | WHITELIST: the analog relies on `sync_with_stripe` (line 176) to update status indirectly. Since sync_with_stripe is sanctioned-omitted for AI credit subscriptions (Sub change #3), the explicit status update is necessary to avoid a stale status. Removing it would leave the purchase with an active status after cancellation.

DEVIATION: Missing sync_with_stripe | ANALOG: stripe_webhook_handler_job.rb:176 `organization&.sync_with_stripe if stripe_subscription_id == organization&.stripe_subscription_id` | OURS: no sync | SANCTIONED: yes (Sub change #3)

DEVIATION: Missing PaidSubscriptionDeletedJob | ANALOG: stripe_webhook_handler_job.rb:180 `Notification::PaidSubscriptionDeletedJob.perform_later(...)` | OURS: no notification job | SANCTIONED: yes (Sub change #3)

DEVIATION: Missing EngagementReport::GeneratorJob | ANALOG: stripe_webhook_handler_job.rb:181 `EngagementReport::GeneratorJob.perform_later(...)` | OURS: no engagement report | SANCTIONED: yes (Sub change #3)

**SCOPE: checkout.session.completed — AI credit subscription vs main-plan**

DEVIATION: update_columns vs update | ANALOG: stripe_webhook_handler_job.rb:80 `organization.update(attributes)` — runs validations/callbacks | OURS: stripe_webhook_handler_job.rb:64 `purchase.update_columns(stripe_subscription_id: ...)` — skips validations/callbacks | SANCTIONED: no | WHITELIST: `update` would trigger `validates :subscription_current_period_start, :subscription_current_period_end, presence: true, if: -> { subscription? && stripe_subscription_id.present? }` because setting `stripe_subscription_id` activates the conditional but period fields are not yet populated (they arrive on invoice.paid). The `update_columns` is necessary to avoid validation failure.

DEVIATION: Missing Stripe::Customer.update | ANALOG: stripe_webhook_handler_job.rb:83 `Stripe::Customer.update(object.customer, name: organization.owner.full_name, description: organization.name)` | OURS: no customer name update | SANCTIONED: no | WHITELIST: the Stripe customer already exists from main-plan checkout; AI credit subscription checkout is not the customer's first checkout. The name/description were already set. Repeating would be harmless but unnecessary.

DEVIATION: Missing subscription metadata copy | ANALOG: stripe_webhook_handler_job.rb:86-97 retrieves subscription and copies checkout session metadata to subscription if subscription metadata is empty | OURS: no metadata copy | SANCTIONED: no

DEVIATION: Missing begin/rescue error handling wrapper | ANALOG: stripe_webhook_handler_job.rb:100-103 `rescue StandardError => e` wrapping checkout processing | OURS: stripe_webhook_handler_job.rb:58-68 no begin/rescue — exceptions propagate to job perform | SANCTIONED: no

**SCOPE: OrganizationAiCreditPurchase#stripe_subscription vs Organization#stripe_subscription**

Both methods are structurally identical: nil guard on `stripe_subscription_id`, `Stripe::Subscription.retrieve` with `expand: ['items.data.price.tiers']`. Match — no deviation.

---

**UNSANCTIONED DEVIATIONS SUMMARY (action needed):**

1. **invoice.paid missing-record guard does not raise** — logs only vs analog raises
2. **invoice.paid missing-record error uses 1 channel** — vs analog's 3 channels (Rails.logger.error + ap + puts)
3. **invoice.paid period_start stored** — EXTRA field (WHITELISTED: model validation forces it)
4. **invoice.paid amount/currency stored** — EXTRA fields (WHITELISTED: model validations force them)
5. **invoice.paid call-site safe navigation missing** — no `&.` at call site vs analog's two-layer defense
6. **subscription.updated missing payment method update** — analog updates payment method, ours does not
7. **subscription.deleted uses update vs analog's update_column** — callbacks/validations run vs skipped
8. **subscription.deleted stores subscription_status** — EXTRA field (WHITELISTED: compensates for sanctioned sync_with_stripe omission)
9. **checkout.session.completed uses update_columns vs analog's update** — opposite direction (WHITELISTED: model validations would fail)
10. **checkout.session.completed missing Stripe::Customer.update** — (WHITELISTED: customer already exists)
11. **checkout.session.completed missing subscription metadata copy** — analog copies metadata, ours does not
12. **checkout.session.completed missing begin/rescue error wrapper** — exceptions propagate unhandled

---NEXT DIMENSION---

So `hasActiveSubscription` is passed from the parent. Our code computes it internally. That's acceptable as the parent page is different.

Now I have all the information I need. Let me compile the full deviation report.

---

DEVIATION: [Controller: Missing ValidateSubscriptionChange in change_subscription_portal_session] | ANALOG: billing_controller.rb:277-285 calls ValidateSubscriptionChange.call before creating portal session | OURS: organization_ai_credit_purchases_controller.rb:168-216 has no ValidateSubscriptionChange call | SANCTIONED: yes (Sub change #3)

DEVIATION: [Controller: Missing ValidateSubscriptionChange in continue_change_subscription_portal_session] | ANALOG: billing_controller.rb:418-429 calls ValidateSubscriptionChange.call before creating confirmation portal session | OURS: organization_ai_credit_purchases_controller.rb:275-349 has no ValidateSubscriptionChange call | SANCTIONED: yes (Sub change #3)

DEVIATION: [Controller: Subscription ID guard uses purchase record lookup instead of current_organization.stripe_subscription_id] | ANALOG: billing_controller.rb:273 raises unless current_organization.stripe_subscription_id.present? | OURS: organization_ai_credit_purchases_controller.rb:173-174 looks up purchase via organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due]) then checks purchase.stripe_subscription_id | SANCTIONED: yes (Sub change #2)

DEVIATION: [Controller: Subscription ID guard in update_payment_method_and_subscription_portal_session uses purchase record lookup] | ANALOG: billing_controller.rb:336 raises unless current_organization.stripe_subscription_id.present? | OURS: organization_ai_credit_purchases_controller.rb:225-226 looks up purchase record and checks purchase.stripe_subscription_id | SANCTIONED: yes (Sub change #2)

DEVIATION: [Controller: flow_data.subscription_update_confirm.subscription uses purchase.stripe_subscription_id in change_subscription_portal_session] | ANALOG: billing_controller.rb:296 uses current_organization.stripe_subscription_id | OURS: organization_ai_credit_purchases_controller.rb:185 uses purchase.stripe_subscription_id | SANCTIONED: yes (Sub change #1)

DEVIATION: [Controller: flow_data.subscription_update_confirm.subscription uses purchase.stripe_subscription_id in update_payment_method -> continue flow] | ANALOG: billing_controller.rb:439 uses current_organization.stripe_subscription_id | OURS: organization_ai_credit_purchases_controller.rb:319 uses purchase.stripe_subscription_id | SANCTIONED: yes (Sub change #1)

DEVIATION: [Controller: continue_change_subscription_portal_session subscription_id guard uses purchase record lookup] | ANALOG: billing_controller.rb:395-398 checks current_organization.stripe_subscription_id.blank? | OURS: organization_ai_credit_purchases_controller.rb:285-289 looks up purchase and checks purchase.stripe_subscription_id.blank? | SANCTIONED: yes (Sub change #2)

DEVIATION: [Controller: customer_subscription retrieves via purchase record] | ANALOG: billing_controller.rb:607-621 uses current_organization.stripe_subscription_id and current_organization.stripe_subscription | OURS: organization_ai_credit_purchases_controller.rb:374-389 looks up purchase record and uses purchase.stripe_subscription_id and purchase.stripe_subscription | SANCTIONED: yes (Sub change #2)

DEVIATION: [Controller: customer_subscription ap log ordering] | ANALOG: billing_controller.rb:608 logs current_organization.stripe_subscription BEFORE the nil check (eagerly hits Stripe API) | OURS: organization_ai_credit_purchases_controller.rb:377 logs purchase&.stripe_subscription AFTER purchase lookup but BEFORE the nil check | SANCTIONED: no

DEVIATION: [Controller: PosthogTrackJob event name uses ai_credit prefix] | ANALOG: billing_controller.rb:311 event name 'change_subscription_stripe_portal_opened' | OURS: organization_ai_credit_purchases_controller.rb:200 event name 'ai_credit_change_subscription_stripe_portal_opened' | SANCTIONED: yes (Sub change #5)

DEVIATION: [Controller: determine_price_id fallback uses OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key? instead of DEFAULT_PRICE_LOOKUP_KEY constant] | ANALOG: billing_controller.rb:637 matches price.lookup_key == DEFAULT_PRICE_LOOKUP_KEY | OURS: organization_ai_credit_purchases_controller.rb:411 matches OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?(price.lookup_key) | SANCTIONED: yes (Sub change #5 -- AI credit-specific lookup key matching)

DEVIATION: [Controller: continue_url path segment] | ANALOG: billing_controller.rb:346 continue_url uses /api/v1/billing/continue_change_subscription_portal_session | OURS: organization_ai_credit_purchases_controller.rb:236 continue_url uses /api/v1/ai_credit_purchases/continue_change_subscription_portal_session | SANCTIONED: yes (different controller, appropriate routing)

DEVIATION: [Hook: useChangeAiCreditSubscriptionViaStripePortal window.logger tag] | ANALOG: useBilling.ts:185 "%c[useBilling] useChangePlanStripePortalSession" | OURS: useOrganizationAiCreditPurchase.ts:54 "%c[useOrganizationAiCreditPurchase] useChangeAiCreditSubscriptionViaStripePortal" | SANCTIONED: no
REVERT: The analog uses "useChangePlanStripePortalSession" as the logger label (a mismatch with the function name "useChangeSubscriptionViaStripePortal"). Our code at least has the label match its function name. Both are cosmetic logger text; neither needs reverting.

DEVIATION: [Hook: useUpdateAiCreditSubscriptionWithPaymentMethod window.logger tag] | ANALOG: useBilling.ts:198 "%c[useBilling] useUpdateWithPaymentMethod" | OURS: useOrganizationAiCreditPurchase.ts:82 "%c[useOrganizationAiCreditPurchase] useUpdateAiCreditSubscriptionWithPaymentMethod" | SANCTIONED: no
REVERT: Cosmetic logger text; does not need reverting.

DEVIATION: [Hook: useAiCreditCustomerSubscription query key] | ANALOG: useBilling.ts:261 query key ["stripeCustomerSubscription"] | OURS: useOrganizationAiCreditPurchase.ts:190 query key ["aiCreditCustomerSubscription"] | SANCTIONED: yes (Sub change #5 -- different cache key for separate subscription data)

DEVIATION: [Component: AiCreditSubscription missing BillingPeriodToggleWrapper / SlidingToggleSwitch / billingPeriod state / Badge "2 months free"] | ANALOG: AccountBillingPlans.tsx:81-91,359-367 has monthly/yearly billing period toggle state and UI | OURS: AiCreditSubscription.tsx has no billing period toggle (AI credit subscriptions are monthly-only) | SANCTIONED: no

DEVIATION: [Component: AiCreditSubscription missing isOnLegacyPlan CurrentSubscription banner] | ANALOG: AccountBillingPlans.tsx:78-79,398-422 detects legacy plans and shows a CurrentSubscription banner for them | OURS: AiCreditSubscription.tsx has no legacy plan detection or banner | SANCTIONED: no (but no legacy AI credit plans exist so this is reasonable)

DEVIATION: [Component: AiCreditSubscription hasActiveSubscription computed internally vs received as prop] | ANALOG: AccountBillingPlans.tsx:43-46 receives hasActiveSubscription as a prop from parent | OURS: AiCreditSubscription.tsx:74-81 computes isSubscribed internally from subscription record status, including isCanceledButStillActive logic | SANCTIONED: no

DEVIATION: [Component: AiCreditSubscription Subtitle text differs] | ANALOG: AccountBillingPlans.tsx:358 always renders "Subscription options" | OURS: AiCreditSubscription.tsx:371 conditionally renders "Change your plan" (if subscribed) or "Choose a credit subscription" (if not) | SANCTIONED: no

DEVIATION: [Component: AiCreditSubscription cancelAtPeriodEnd banner text differs] | ANALOG: AccountBillingPlans.tsx:389 "Your subscription is scheduled to be canceled on {date}." | OURS: AiCreditSubscription.tsx:393 "Your AI credit subscription is scheduled to be canceled on {date}." | SANCTIONED: yes (Sub change #5 -- ai_credit descriptor naming)

DEVIATION: [Component: AiSubscriptionTierCard missing props passed from parent -- billingPeriod, currentPlanBillingPeriod, hasCoupon, stripePromoCode, onCreateBillingPortalSession are declared in interface but NOT passed by AiCreditSubscription] | ANALOG: AccountBillingPlans.tsx:442-454 passes billingPeriod, currentPlanBillingPeriod, hasCoupon, stripePromoCode, onCreateBillingPortalSession to PlanCard | OURS: AiCreditSubscription.tsx:415-429 does NOT pass billingPeriod, currentPlanBillingPeriod, hasCoupon, stripePromoCode, or onCreateBillingPortalSession to AiSubscriptionTierCard | SANCTIONED: no

DEVIATION: [Component: AiSubscriptionTierCard billingPeriod is required in interface but not passed -- causes undefined in trackEvent and window.logger] | ANALOG: PlanCard.tsx:59 billingPeriod declared required, AccountBillingPlans.tsx:442 passes it | OURS: AiSubscriptionTierCard.tsx:22 billingPeriod declared required ("monthly" | "yearly"), AiCreditSubscription.tsx never passes it -- will be undefined in trackEvent call on line 61 and window.logger on line 74 | SANCTIONED: no

DEVIATION: [Component: AiSubscriptionTierCard onCreateBillingPortalSession is required in interface but not passed -- ManageBillingActions "Manage billing" button will throw on click] | ANALOG: PlanCard.tsx:68 onCreateBillingPortalSession declared required, AccountBillingPlans.tsx:454 passes it | OURS: AiSubscriptionTierCard.tsx:31 onCreateBillingPortalSession declared required, AiCreditSubscription.tsx never passes it -- ManageBillingActions on line 108 will receive undefined, and clicking "Manage billing" (ManageBillingActions.tsx:39 `onCreateBillingPortalSession()`) will throw TypeError | SANCTIONED: no

DEVIATION: [Component: AiSubscriptionTierCard hasCoupon is required in interface but not passed -- ManageBillingActions receives undefined] | ANALOG: PlanCard.tsx:65 hasCoupon declared required, AccountBillingPlans.tsx:448 passes it | OURS: AiSubscriptionTierCard.tsx:27 hasCoupon declared required, AiCreditSubscription.tsx never passes it -- ManageBillingActions receives undefined for hasCoupon (defaults to false via ManageBillingActions default param, so promo code menu may render incorrectly) | SANCTIONED: no

DEVIATION: [Component: AiSubscriptionTierCard stripePromoCode not passed -- ManageBillingActions receives undefined] | ANALOG: PlanCard.tsx:66 stripePromoCode optional, AccountBillingPlans.tsx:449 passes currentOrganization.stripePromoCode | OURS: AiSubscriptionTierCard.tsx:28 stripePromoCode optional, AiCreditSubscription.tsx never passes it | SANCTIONED: no

DEVIATION: [Component: AiCreditSubscription handleChangeSubscription lacks PlanFeatureGate / checkPlanLimitsGate] | ANALOG: AccountBillingPlans.tsx:322-350 handleChangeSubscriptionWithGate calls checkPlanLimitsGate and shows PlanChangeBlockedModal if limits exceeded | OURS: AiCreditSubscription.tsx:249-261 handleChangeSubscription goes straight to portal/payment flow without any limits gate | SANCTIONED: yes (Sub change #3)

DEVIATION: [Component: AiCreditSubscription isLoadingButton on card differs from analog] | ANALOG: AccountBillingPlans.tsx:453 isLoadingButton={isFetchingStripeCustomerSubscription} (loading from customer subscription query) | OURS: AiCreditSubscription.tsx:426 isLoadingButton={isCheckingOut || isLoadingChangeSubscriptionViaStripePortal || isLoadingUpdateWithPaymentMethod} (loading from mutation states, same as isLoading prop on line 425) | SANCTIONED: no

DEVIATION: [Component: AiSubscriptionTierCard trackEvent uses different event name and different property keys] | ANALOG: PlanCard.tsx:99 trackEvent("plan_selected", { current_plan_lookup_key, selected_plan_name, selected_plan_key, selected_plan_billing_period }) | OURS: AiSubscriptionTierCard.tsx:56-62 trackEvent("ai_credit_tier_selected", { current_tier_lookup_key, selected_tier_name, selected_tier_credits, selected_tier_lookup_key, selected_tier_billing_period }) -- adds selected_tier_credits, replaces selected_plan_key with selected_tier_lookup_key | SANCTIONED: yes (Sub change #5 -- ai_credit_* descriptor naming) for the event name; no for the extra/different property keys

DEVIATION: [Component: AiSubscriptionTierCard trackEvent passes billingPeriod which is undefined (not passed from parent)] | ANALOG: PlanCard.tsx:99 selected_plan_billing_period receives actual billingPeriod value from parent | OURS: AiSubscriptionTierCard.tsx:61 selected_tier_billing_period receives billingPeriod which is undefined because parent doesn't pass it | SANCTIONED: no

DEVIATION: [Component: AiCreditSubscription extra confirm modal for top-up purchases (PurchaseAiCreditTopUpConfirmModal)] | ANALOG: no equivalent | OURS: AiCreditSubscription.tsx:308-319 opens PurchaseAiCreditTopUpConfirmModal before direct charge | SANCTIONED: yes (sanctioned deviation: EXTRA confirm modal)

DEVIATION: [Component: AiCreditSubscription has cancel flow (CancelAiCreditSubscriptionConfirmModal + handleCancelClick)] | ANALOG: AccountBillingPlans.tsx has no cancel flow -- cancellation is handled via the Stripe customer portal (ManageBillingActions -> "Manage billing" button) | OURS: AiCreditSubscription.tsx:326-347 has explicit cancel flow with CancelAiCreditSubscriptionConfirmModal + useCancelAiCreditSubscription mutation | SANCTIONED: no

DEVIATION: [Component: AiCreditSubscription has dedicated top-up section ("One-time top-up packs")] | ANALOG: AccountBillingPlans.tsx has no equivalent section | OURS: AiCreditSubscription.tsx:441-454 renders top-up packs section with AiCreditPackCard components | SANCTIONED: no (but this is a feature-specific addition for the AI credit product)

DEVIATION: [Component: AiCreditSubscription has redirectToStripe helper] | ANALOG: AccountBillingPlans.tsx has no equivalent (subscription change goes through portal redirect, not Stripe Checkout) | OURS: AiCreditSubscription.tsx:130-133 redirectToStripe adds a success toast then redirects | SANCTIONED: no (but relates to checkout flow for new subscriptions and top-ups)

DEVIATION: [Component: AiCreditSubscription has handleCheckoutNewSubscription for new subscription checkout] | ANALOG: AccountBillingPlans.tsx has no equivalent -- new subscriptions are handled elsewhere (AccountBillingPlansUnsubscribed component, selected via parent branching) | OURS: AiCreditSubscription.tsx:217-243 handleCheckoutNewSubscription uses useCheckoutAiCreditPack mutation | SANCTIONED: no (but both subscription and non-subscription states are handled in one component vs the analog's split into separate components)

DEVIATION: [Component: AiCreditSubscription collapses subscribed/unsubscribed into one component] | ANALOG: AccountBilling.tsx:122-145 branches between AccountBillingPlansFreeTrial, AccountBillingPlans, and AccountBillingPlansUnsubscribed based on state | OURS: AiCreditSubscription.tsx handles both subscribed and unsubscribed states in a single component | SANCTIONED: no

DEVIATION: [Component: AiCreditSubscription has PlanBillingCallout instead of AiCreditsCallout] | ANALOG: AccountBillingPlans.tsx:463-465 renders AiCreditsCallout with onClickManage navigating to /hire/settings/plato-ai/billing | OURS: AiCreditSubscription.tsx:436-438 renders PlanBillingCallout with onClickManage navigating to /hire/settings/billing | SANCTIONED: no (cross-linking callouts are mirrored appropriately)

DEVIATION: [Component: AiCreditSubscription window.logger in handleCreateBillingPortalSession.onSuccess uses [AiCreditSubscription] instead of analog's [AccountContainer]] | ANALOG: AccountBillingPlans.tsx:224 "%c[AccountContainer]" | OURS: AiCreditSubscription.tsx:113 "%c[AiCreditSubscription]" | SANCTIONED: no
REVERT: The analog's label "[AccountContainer]" is actually a bug/stale reference -- it should probably be "[AccountBillingPlans]". Our "[AiCreditSubscription]" is actually more correct for its context. Do not revert.

---NEXT DIMENSION---

Now I have all the data I need. Let me compile the full deviation report.

Here is the full structural audit of `customer.subscription.updated` and `customer.subscription.deleted` in `stripe_webhook_handler_job.rb`, comparing the develop (analog) branch to the billing-bonanza branch. I also include deviations found in the adjacent `checkout.session.completed`, `invoice.paid`, and error handling sections since the diff touched them.

---

## customer.subscription.updated

### ANALOG (develop, lines 111-148): Unconditional flow

```
organization.update(period_end, status, cancel_at_period_end)
organization.stripe_update_default_payment_method(object.default_payment_method) if object.default_payment_method
organization.sync_with_stripe
```

No branching. All subscription updates hit the organization.

### OURS (billing-bonanza, lines 111-148): If/else branching by lookup_key

```
if ai_credit_subscription_plan_lookup_key?(plan_lookup_key)
  purchase = find_by(stripe_subscription_id: object.id, kind: :subscription)
  purchase&.update(subscription_status, subscription_current_period_end, stripe_cancel_at_period_end)
else
  [original org code unchanged]
end
```

DEVIATION: [credit-pack branch added to customer.subscription.updated] | ANALOG: stripe_webhook_handler_job.rb:124-134 no credit-pack branch exists | OURS: stripe_webhook_handler_job.rb:125-134 new if-branch for AI credit subscription purchases | SANCTIONED: yes (Sub change #2: operates on OrganizationAiCreditPurchase record not org)

DEVIATION: [no stripe_update_default_payment_method in credit-pack branch of subscription.updated] | ANALOG: stripe_webhook_handler_job.rb:128 `organization.stripe_update_default_payment_method(object.default_payment_method) if object.default_payment_method` runs unconditionally | OURS: stripe_webhook_handler_job.rb:125-134 credit-pack branch does NOT call `stripe_update_default_payment_method` | SANCTIONED: no. The main-plan branch calls it. The credit-pack subscription also uses a payment method on the customer. When a customer updates their payment method on a credit-pack subscription, this webhook fires and the new default payment method is not propagated to the Stripe customer's invoice_settings. The invoice.paid credit-pack branch at line 275 DOES call `organization.stripe_update_default_payment_method(stripe_subscription.default_payment_method)`, so there is an inconsistency: invoice.paid propagates the payment method but subscription.updated does not. The analog does it on subscription.updated.

DEVIATION: [no sync_with_stripe in credit-pack branch of subscription.updated] | ANALOG: stripe_webhook_handler_job.rb:129 `organization.sync_with_stripe` runs unconditionally | OURS: stripe_webhook_handler_job.rb:125-134 credit-pack branch does NOT call `organization.sync_with_stripe` | SANCTIONED: no. However, `sync_with_stripe` (Organization lines 538-542) already filters out credit/plato subscriptions, so calling it would be a no-op for the AI credit subscription itself. It WOULD sync the main-plan subscription state if it had drifted. The analog calls it unconditionally. WHITELIST: calling sync_with_stripe from the credit-pack branch would be harmless but also pointless — it explicitly filters out credit subscriptions. The analog calls it because it has no branching and needs the full sync for main-plan. Adding it would be copy-paste noise.

---

## customer.subscription.deleted

### ANALOG (develop, lines 150-186): No credit-pack branch

```
organization.sync_with_stripe if stripe_subscription_id == organization.stripe_subscription_id
organization.update_column(:subscription_canceled_at, ...)
Notification::PaidSubscriptionDeletedJob.perform_later(...)
EngagementReport::GeneratorJob.perform_later(...)
```

No branching. No `plan_lookup_key` extraction.

### OURS (billing-bonanza, lines 150-186): If/else branching by lookup_key

```
plan_lookup_key = object.items&.data&.first&.price&.lookup_key
if ai_credit_subscription_plan_lookup_key?(plan_lookup_key)
  purchase = find_by(stripe_subscription_id, kind: :subscription)
  purchase&.update(subscription_status, subscription_canceled_at)
else
  [original org code unchanged]
end
```

DEVIATION: [credit-pack branch added to customer.subscription.deleted] | ANALOG: stripe_webhook_handler_job.rb:150-186 no credit-pack branch exists | OURS: stripe_webhook_handler_job.rb:163-174 new if-branch for AI credit subscription deletion | SANCTIONED: yes (Sub change #2: operates on OrganizationAiCreditPurchase record not org). The comment at lines 164-166 correctly documents that the branch must NOT touch org main-plan fields, fire PaidSubscriptionDeletedJob, or fire EngagementReport::GeneratorJob.

DEVIATION: [plan_lookup_key extracted at top of customer.subscription.deleted] | ANALOG: stripe_webhook_handler_job.rb:150-157 does not extract plan_lookup_key | OURS: stripe_webhook_handler_job.rb:157 adds `plan_lookup_key = object.items&.data&.first&.price&.lookup_key` | SANCTIONED: yes (required for the credit-pack branch routing)

DEVIATION: [credit-pack branch of subscription.deleted does not set stripe_cancel_at_period_end] | ANALOG: N/A (no analog credit-pack branch) | OURS: stripe_webhook_handler_job.rb:171-173 updates `subscription_status` and `subscription_canceled_at` but NOT `stripe_cancel_at_period_end` | SANCTIONED: no. The subscription.updated credit-pack branch at line 133 DOES update `stripe_cancel_at_period_end: object.cancel_at_period_end`. But subscription.deleted does not clear or update it. When a subscription is deleted, `cancel_at_period_end` is now moot but the field retains its previous value (likely `true` if the user scheduled cancellation). This is a stale-data concern: a deleted subscription purchase will have `stripe_cancel_at_period_end: true` and `subscription_status: canceled` forever. The analog's main-plan branch doesn't explicitly clear it either (it relies on sync_with_stripe), but the purchase record has no sync equivalent.

---

## Adjacent deviations found in the diff

### checkout.session.completed metadata access pattern

DEVIATION: [metadata access style changed] | ANALOG: stripe_webhook_handler_job.rb:58 `object.metadata&.[]('ai_credit_pack_subscription') == 'true'` (safe-navigation + hash access + string equality) | OURS: stripe_webhook_handler_job.rb:58 `object.metadata.ai_credit_pack_subscription.present?` (dot-access, no safe-navigation, .present? check) | SANCTIONED: no. The develop branch uses `&.[]('...')` (safe-navigation + hash bracket access) which is the consistent pattern throughout the file for metadata checks (lines 210, 223, 241 all use `object.metadata&.[]('...')`). The billing-bonanza version uses dot-method access which (a) drops the safe-navigation operator so will raise NoMethodError if metadata is nil, and (b) uses `.present?` instead of `== 'true'` so any truthy string value passes, not just the literal string `'true'`.

### invoice.paid one-off top-up: completely different mechanism

DEVIATION: [one-off top-up invoice.paid uses record-lookup instead of ApplyAiCreditPurchase interactor] | ANALOG: stripe_webhook_handler_job.rb:183-198 (develop) uses `ApplyAiCreditPurchase.call(kind: :one_off, organization_id:, lookup_key:, amount_cents:, currency:, checkout_session_id:)` to create the purchase record AND grant credits in one interactor call | OURS: stripe_webhook_handler_job.rb:241-257 looks up existing `OrganizationAiCreditPurchase` by `organization_ai_credit_purchase_id` metadata, then calls `purchase.finalize_stripe_payment` + `purchase.broadcast_event` + `purchase.grant_one_off_credits` — three separate model methods | SANCTIONED: yes (Sub change #2: operates on OrganizationAiCreditPurchase record not org). The billing-bonanza approach pre-creates the purchase record at checkout time (via the controller), then the webhook just finalizes it. The develop approach creates the record inside the interactor at webhook time. These are fundamentally different flows.

DEVIATION: [one-off top-up metadata key changed] | ANALOG: stripe_webhook_handler_job.rb:183 (develop) checks `object.metadata&.[]('ai_credit_pack_top_up') == 'true'` | OURS: stripe_webhook_handler_job.rb:241 checks `object.metadata&.[]('organization_ai_credit_purchase_id').present?` | SANCTIONED: yes (Sub change #2: the record already exists, so the metadata carries its ID)

### invoice.paid subscription renewal: inlined vs extracted method

DEVIATION: [handle_subscription_credit_pack_invoice_paid extracted method removed, logic inlined] | ANALOG: stripe_webhook_handler_job.rb:260-267 (develop) calls `handle_subscription_credit_pack_invoice_paid(object, subscription_price)` which is a private method at bottom of file (develop lines 434-445) | OURS: stripe_webhook_handler_job.rb:262-279 inlines the logic directly in the case branch; private method `handle_subscription_credit_pack_invoice_paid` is deleted | SANCTIONED: no. The analog extracts the logic into a private method. The billing-bonanza branch inlines it. This is a structural deviation — the analog has a method boundary and ours does not. The inlined version also differs in what it does (see next deviations).

DEVIATION: [invoice.paid subscription: different column names for amount/currency update] | ANALOG: stripe_webhook_handler_job.rb:438-440 (develop `handle_subscription_credit_pack_invoice_paid`) calls `existing.update(amount_cents_paid: invoice.amount_paid, currency: invoice.currency)` | OURS: stripe_webhook_handler_job.rb:269-274 calls `purchase.update(stripe_amount: object.amount_paid, currency: object.currency, subscription_current_period_start: ..., subscription_current_period_end: ...)` | SANCTIONED: partially. The column rename from `amount_cents_paid` to `stripe_amount` is a migration-driven change (Sub change #5 naming). But the analog updates ONLY `amount_cents_paid` and `currency`, while ours also updates `subscription_current_period_start` and `subscription_current_period_end`. The develop version does NOT update period start/end here — it does that inside `ApplyAiCreditPurchase#apply_subscription` (develop lines 110-115) using `invoice.lines.data.first.period`. Ours does it in the webhook handler using `stripe_subscription.current_period_start/end`.

DEVIATION: [invoice.paid subscription: ApplyAiCreditPurchase called with different signature] | ANALOG: stripe_webhook_handler_job.rb:442 (develop) calls `ApplyAiCreditPurchase.call(invoice: invoice, price: price, kind: :subscription)` | OURS: stripe_webhook_handler_job.rb:276 calls `ApplyAiCreditPurchase.call(organization: organization, purchase: purchase)` | SANCTIONED: yes (Sub change #2: the billing-bonanza interactor is rewritten to accept organization+purchase instead of invoice+price+kind)

DEVIATION: [invoice.paid subscription: develop also calls stripe_update_default_payment_method without args; ours calls it WITH subscription payment method] | ANALOG: (develop main-plan branch, line ~266) `organization.stripe_update_default_payment_method` (no argument — uses the org's own stripe_payment_method) | OURS: stripe_webhook_handler_job.rb:275 `organization.stripe_update_default_payment_method(stripe_subscription.default_payment_method)` (passes the subscription's payment method) | SANCTIONED: no. The analog's main-plan branch calls without args. The billing-bonanza credit-pack branch passes the subscription's `default_payment_method`. This is a behavioral difference — passing the subscription's payment method will set that as the customer's default. The analog relies on the org's existing payment method lookup. REVERT: This may be intentional (credit-pack subscriptions may have a different payment method than the main plan), but it deviates from the analog pattern and should be explicitly confirmed.

### invoice.paid: CustomStripeSubscriptionMissingError guard moved

DEVIATION: [CustomStripeSubscriptionMissingError guard moved after credit-pack check] | ANALOG: stripe_webhook_handler_job.rb:243 (develop) `raise CustomStripeSubscriptionMissingError if organization.stripe_subscription_id.nil?` is the FIRST check after the board listing metadata checks, BEFORE the Stripe::Subscription.retrieve call | OURS: stripe_webhook_handler_job.rb:281 the guard is inside the else branch, AFTER the credit-pack check | SANCTIONED: yes (Sub change #3: AI credit subscription orgs may not have a main-plan subscription, so the guard must not fire before the credit-pack branch). This is correctly placed.

### invoice.paid: subscription_key? renamed to ai_credit_subscription_plan_lookup_key?

DEVIATION: [method name changed from subscription_key? to ai_credit_subscription_plan_lookup_key?] | ANALOG: stripe_webhook_handler_job.rb:261 (develop) `OrganizationAiCreditPurchase.subscription_key?(subscription_lookup_key)` | OURS: stripe_webhook_handler_job.rb:262 `OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?(subscription_lookup_key)` | SANCTIONED: yes (Sub change #5: ai_credit_* descriptor naming)

### invoice.paid: error handling downgraded

DEVIATION: [invoice.paid error handling changed from 3 rescue clauses to 1 generic rescue] | ANALOG: stripe_webhook_handler_job.rb:273-286 (develop) has three rescue clauses: `Stripe::StripeError` (with org+invoice+subscription context), `ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound` (with org+invoice context), and `StandardError` (with full context + re-raise for Sidekiq retry) | OURS: stripe_webhook_handler_job.rb:287-292 has a single `rescue StandardError` with generic "Handling Successful Invoice Payment Failed" message and no re-raise | SANCTIONED: no. The develop branch has significantly better error handling: (a) it catches Stripe API errors separately with Stripe-specific context, (b) it catches ActiveRecord errors separately, (c) it re-raises unexpected errors so Sidekiq retries the webhook. The billing-bonanza branch swallows ALL errors silently with a generic message. This means if `ApplyAiCreditPurchase` fails, the customer pays but never receives credits, and there is no Sidekiq retry.

### invoice.paid: update success check removed

DEVIATION: [org.update success check removed from main-plan else branch] | ANALOG: stripe_webhook_handler_job.rb:264-268 (develop) `updated = organization.update(...)` then `unless updated` logs the error with full_messages | OURS: stripe_webhook_handler_job.rb:283 `organization.update(...)` with no success check | SANCTIONED: no. The develop branch checks whether the update succeeded and logs a meaningful error. The billing-bonanza branch drops this check silently.

### invoice.paid: subscription_price variable removed

DEVIATION: [subscription_price no longer extracted] | ANALOG: stripe_webhook_handler_job.rb:260 (develop) extracts `subscription_price = stripe_subscription.items.data.first&.price` and passes it to `handle_subscription_credit_pack_invoice_paid` | OURS: stripe_webhook_handler_job.rb:260 does not extract subscription_price | SANCTIONED: yes (the billing-bonanza ApplyAiCreditPurchase does not need the price object since the purchase record already has the lookup_key and credits_per_period)

---

## Summary of unsanctioned deviations

1. **No `stripe_update_default_payment_method` in credit-pack branch of subscription.updated** — analog calls it unconditionally
2. **Metadata access style changed in checkout.session.completed** — drops safe-navigation, uses `.present?` instead of `== 'true'`
3. **`handle_subscription_credit_pack_invoice_paid` private method deleted, logic inlined** — structural flattening
4. **invoice.paid subscription writes period start/end in webhook handler** — analog writes them inside the interactor from `invoice.lines.data.first.period`, which is a different data source (invoice line item period vs. subscription object period)
5. **invoice.paid subscription calls `stripe_update_default_payment_method` WITH subscription's payment_method arg** — analog calls without args
6. **invoice.paid error handling downgraded from 3 specific rescue clauses to 1 generic swallowing rescue** — errors are swallowed, no Sidekiq retry on unexpected failures
7. **invoice.paid org.update success check removed from main-plan else branch** — silent update failures
8. **subscription.deleted credit-pack branch does not clear/update `stripe_cancel_at_period_end`** — stale data on deleted subscription purchase record
