# Round 2 — Audit Results

The purchase record is created with `stripe_amount: 0` and then `charge_default_payment_method` overwrites it via `update_columns(stripe_invoice_id: invoice.id, stripe_invoice_item_id: invoice_item.id, stripe_amount: amount)`. This is different from the WWR analog where:
- `create` action: `@listing.save` first (no stripe_amount set), then `charge_for_listing` sets it via `update_columns`
- `create_checkout_session` action: no stripe_amount is set at all until `invoice.paid` webhook fires

Now I have enough data for a thorough comparison. Let me compile the full deviation report.

DEVIATION: [Model method name: charge method] | ANALOG: board_wwr_listing.rb:112 `charge_for_listing` | OURS: organization_ai_credit_purchase.rb:192 `charge_default_payment_method` | SANCTIONED: no

DEVIATION: [Model charge method: logging style for "Attempt to charge" line] | ANALOG: board_wwr_listing.rb:114 `Rails.logger.info 'Attempt to charge for WWR Listing'` | OURS: organization_ai_credit_purchase.rb:194 `ap 'Attempt to charge for AI Credit Top-Up'` (uses `ap` instead of `Rails.logger.info`) | SANCTIONED: no

DEVIATION: [Model charge method: logging style for "Charging..." line] | ANALOG: board_wwr_listing.rb:128 `Rails.logger.info 'Charging...'` | OURS: organization_ai_credit_purchase.rb:207 `ap 'Charging...'` (uses `ap` instead of `Rails.logger.info`) | SANCTIONED: no

DEVIATION: [Model charge method: logging style for "Invoice Has Been Finalized" line] | ANALOG: board_wwr_listing.rb:160-161 `Rails.logger.info 'Invoice Has Been Finalized'` / `Rails.logger.info [invoice_item, paid_invoice]` | OURS: organization_ai_credit_purchase.rb:233-234 `ap 'Invoice Has Been Finalized'` / `ap [invoice_item, paid_invoice]` (uses `ap` instead of `Rails.logger.info`) | SANCTIONED: no

DEVIATION: [Model charge method: organization access pattern] | ANALOG: board_wwr_listing.rb:121 `organization = job.organization` (local variable, consistent with other methods in the model) | OURS: organization_ai_credit_purchase.rb:200 `organization.stripe_customer_id` (direct association access without local variable) | SANCTIONED: no — This is a forced structural difference because `OrganizationAiCreditPurchase` has `belongs_to :organization` directly while `BoardWwrListing` traverses `job.organization`. The analog pattern of assigning a local variable is cosmetic here but the deviation from assigning a local `organization` variable is a stylistic departure. WHITELIST: organization_ai_credit_purchase has `belongs_to :organization` directly, so `organization` is already an association method on `self` -- assigning a local variable would be redundant.

DEVIATION: [Model charge method: @final_description is unconditional alias] | ANALOG: board_wwr_listing.rb:126 `@final_description = wwr_percent_off.positive? ? "#{@description} (#{wwr_percent_off}% WWR discount included)" : @description` (conditional formatting) | OURS: organization_ai_credit_purchase.rb:205 `@final_description = @description` (unconditional assignment, no conditional needed since AI credit one-off purchases have no discount concept) | SANCTIONED: no — The `@final_description` variable serves no purpose and should either be removed (use `@description` directly) or the pattern should be preserved with a comment explaining no discount applies. REVERT: Remove the `@final_description` variable entirely and pass `@description` directly to the Stripe API call. The unconditional alias adds noise.

DEVIATION: [Model calculate_charge_amount: implementation strategy] | ANALOG: board_wwr_listing.rb:84-110 hardcoded price calculation from plan tier plus discount logic, no Stripe API call | OURS: organization_ai_credit_purchase.rb:184-190 calls `Stripe::Price.list` to look up price from Stripe API at charge time | SANCTIONED: no — The comment at line 179-183 says it "mirrors BoardWwrListing#calculate_charge_amount structurally" but it does not -- the analog is a pure local calculation, ours makes a network call. WHITELIST: AI credit pricing is defined in Stripe by lookup_key, not hardcoded. Making a local calculation would require duplicating Stripe-defined prices into the codebase. The Stripe API lookup is the correct approach for this product design.

DEVIATION: [Model is_active? semantics] | ANALOG: board_wwr_listing.rb:54-56 `expires_at.present? && expires_at > DateTime.now && approved?` (time-bounded + status check) | OURS: organization_ai_credit_purchase.rb:118-120 `stripe_invoice_paid?` (boolean flag check only) | SANCTIONED: no — WHITELIST: AI credit one-off purchases have no expiration or approval status. `stripe_invoice_paid?` is the correct equivalent for a non-expiring one-off purchase.

DEVIATION: [Model has extra paid? method] | ANALOG: board_wwr_listing.rb has no `paid?` method | OURS: organization_ai_credit_purchase.rb:122-124 `paid?` method that aliases `stripe_invoice_paid?` | SANCTIONED: no — The WhatJobs analog (board_what_jobs_listing.rb:88-90) does have a `paid?` method though.

DEVIATION: [Model broadcast_event: channel type] | ANALOG: board_wwr_listing.rb:267-269 `JobChannel.broadcast_to(job, event: event, payload: {...})` | OURS: organization_ai_credit_purchase.rb:167-169 `GlobalChannel.broadcast_to(organization.owner, action: event, payload: {...})` | SANCTIONED: no — WHITELIST: AI credit one-off purchases are org-level, not job-level. `JobChannel` is inappropriate. `GlobalChannel` with `action:` key is the standard pattern for GlobalChannel broadcasts (verified across codebase).

DEVIATION: [Model broadcast_show_growl: recipient resolution] | ANALOG: board_wwr_listing.rb:271-273 `GlobalChannel.broadcast_to(last_updated_by_organization_user_id.nil? ? job.organization.owner : last_updated_by_organization_user.user, ...)` (broadcasts to the user who performed the action, or falls back to org owner) | OURS: organization_ai_credit_purchase.rb:171-173 `GlobalChannel.broadcast_to(organization.owner, ...)` (always broadcasts to org owner) | SANCTIONED: no — The AI credit purchase model has no `last_updated_by_organization_user` association. WHITELIST: The model has no `last_updated_by_organization_user` column/association, so the fallback pattern cannot be replicated. The WhatJobs model (board_what_jobs_listing.rb:292-294) uses the same `last_updated_by_organization_user_id` pattern. If the AI credit purchase model should track who initiated the purchase, a column would need to be added.

DEVIATION: [Model broadcast_error_growl: extra method vs analog] | ANALOG: board_wwr_listing.rb has no `broadcast_error_growl` method | OURS: organization_ai_credit_purchase.rb:175-177 has `broadcast_error_growl` method | SANCTIONED: no — The WhatJobs model (board_what_jobs_listing.rb:296-298) does have `broadcast_error_growl`. This is copied from the newer WhatJobs analog rather than the WWR analog.

DEVIATION: [Model grant_one_off_credits: idempotency guard mechanism] | ANALOG: board_wwr_listing.rb:174-177 `unless wwr_listing_id.blank?` / `Rails.logger.warn "Already Published..."` (guards by checking if the external listing ID already exists) | OURS: organization_ai_credit_purchase.rb:132-135 `if ai_credit_balance_transactions.exists?(entry_type: :one_off_credit_pack_purchase_credit)` (guards by checking if a ledger row exists) | SANCTIONED: no — WHITELIST: The WWR idempotency check is "has the external effect already happened?" (wwr_listing_id populated). The AI credit equivalent is "has the credit ledger entry already been created?" which is the correct domain-specific check. There is no external listing ID concept for AI credits.

DEVIATION: [Model grant_one_off_credits: extra logic not in analog] | ANALOG: board_wwr_listing.rb:173-200 `create_on_wwr` does: idempotency check, API call, update_columns, broadcast_event, broadcast_show_growl, Notification job | OURS: organization_ai_credit_purchase.rb:129-165 `grant_one_off_credits` does: idempotency check, ledger creation, balance notification reset, broadcast_event, broadcast_show_growl, Notification job | SANCTIONED: no — The balance notification reset (`balance.update(low_credit_notification_sent_at: nil, ...)` at lines 149-154) has no analog in WWR. WHITELIST: This is domain-specific logic required for the AI credit balance system. When credits are added, the low/zero notification flags must be cleared so new notifications can be sent when credits run low again.

DEVIATION: [Controller purchase_top_up: combined two actions into one] | ANALOG: board_wwr_listings_controller.rb has `create` (direct charge, lines 5-31) and `create_checkout_session` (checkout session, lines 51-128) as SEPARATE controller actions | OURS: organization_ai_credit_purchases_controller.rb:69-154 `purchase_top_up` combines both paths in one action, branching on `current_organization.stripe_default_payment_method_on_file` | SANCTIONED: no

DEVIATION: [Controller purchase_top_up: no exists() wrapper] | ANALOG: board_wwr_listings_controller.rb:6 `exists(current_organization.jobs.where(id: params[:job_id]), 'no job found') do |job|` | OURS: organization_ai_credit_purchases_controller.rb:69 no `exists()` wrapper | SANCTIONED: no — WHITELIST: The `exists()` helper looks up a job by `job_id`. AI credit one-off purchases have no job association; there is nothing to look up with `exists()`.

DEVIATION: [Controller purchase_top_up direct-charge path: no `authorize @listing`] | ANALOG: board_wwr_listings_controller.rb:19 `authorize @listing` (authorizes the listing record with BoardWwrListingPolicy) | OURS: organization_ai_credit_purchases_controller.rb:70 `authorize :billing, :checkout?` (authorizes via BillingPolicy) | SANCTIONED: no — The WWR `create` action uses record-level authorization while the AI credit `purchase_top_up` uses policy-class-level authorization. The WWR `create_checkout_session` also uses `authorize :billing, :checkout?`, so this matches the checkout pattern rather than the create pattern.

DEVIATION: [Controller purchase_top_up: pre-validates lookup_key before building record] | ANALOG: board_wwr_listings_controller.rb:5-31 `create` action builds the listing with params, then `save` validates via model validations | OURS: organization_ai_credit_purchases_controller.rb:72-76 pre-validates `lookup_key` with `OrganizationAiCreditPurchase.ai_credit_top_up_lookup_key?` and returns early error before building the record | SANCTIONED: no

DEVIATION: [Controller purchase_top_up: record creation with pre-populated fields] | ANALOG: board_wwr_listings_controller.rb:11-14 `temp_params = listing_params.merge({last_updated_by_organization_user: current_organization_user})` then `job.board_wwr_listings.build(temp_params)` (builds through association with user-supplied params) | OURS: organization_ai_credit_purchases_controller.rb:78-85 `OrganizationAiCreditPurchase.new(organization: current_organization, kind: :one_off, stripe_price_lookup_key: lookup_key, one_off_credits_granted: ..., stripe_amount: 0, currency: 'usd')` (builds with explicit programmatic params, no user params beyond lookup_key) | SANCTIONED: no — WHITELIST: AI credit one-off purchases derive all fields from the `lookup_key` and the organization. There are no user-supplied params beyond the lookup_key. The WWR model accepts user params like `wwr_category`, `wwr_job_listing_type`, `wwr_region`, `plan`.

DEVIATION: [Controller purchase_top_up: stripe_amount initialized to 0] | ANALOG: board_wwr_listings_controller.rb does not set `stripe_amount` at record creation time; `charge_for_listing` sets it via `update_columns` after charge | OURS: organization_ai_credit_purchases_controller.rb:83 sets `stripe_amount: 0` at record creation, then `charge_default_payment_method` overwrites via `update_columns` | SANCTIONED: no

DEVIATION: [Controller purchase_top_up: no render_general_errors for description.blank?] | ANALOG: board_wwr_listings_controller.rb:8-9 `render_general_errors(['Job description cannot be blank']) if job.description.blank?` / `return if performed?` | OURS: organization_ai_credit_purchases_controller.rb has no equivalent pre-save validation error render | SANCTIONED: no — WHITELIST: The "job description cannot be blank" check is WWR-domain-specific. AI credit one-off purchases have no job description. The lookup_key pre-validation at line 73 serves an analogous purpose.

DEVIATION: [Controller purchase_top_up: rescue clause pattern] | ANALOG: board_wwr_listings_controller.rb:28-30 `rescue StandardError => e` (single rescue in `create`), board_wwr_listings_controller.rb:125-128 `rescue Stripe::StripeError => e` (single Stripe rescue in `create_checkout_session`) | OURS: organization_ai_credit_purchases_controller.rb:148-153 has BOTH `rescue Stripe::StripeError => e` AND `rescue StandardError => e` | SANCTIONED: no — REVERT: The dual rescue in `purchase_top_up` is arguably better error handling (Stripe-specific errors get Stripe-specific messaging). However, it does not match the analog pattern. The combined action has both rescue types because it combines two actions that each had one rescue type.

DEVIATION: [Controller purchase_top_up: Stripe::StripeError rescue response shape] | ANALOG: board_wwr_listings_controller.rb:126-127 `render json: { error: e.message }, status: :unprocessable_entity` | OURS: organization_ai_credit_purchases_controller.rb:149-150 `render json: { error: e.message }, status: :unprocessable_entity` | SANCTIONED: n/a (MATCH)

DEVIATION: [Controller purchase_top_up: StandardError rescue response shape] | ANALOG: board_wwr_listings_controller.rb:29-30 `Rails.logger.error "Failed to charge for WWR listing: #{e.message}"` / `render_general_errors(["Unable to process payment: #{e.message}"])` | OURS: organization_ai_credit_purchases_controller.rb:152-153 `Rails.logger.error "Failed to process AI credit one-off purchase top-up: #{e.message}"` / `render_general_errors(["Unable to process payment: #{e.message}"])` | SANCTIONED: n/a (MATCH — response shape matches, only log message text differs as expected)

DEVIATION: [Controller purchase_top_up: stores stripe_checkout_session_id after session creation] | ANALOG: board_wwr_listings_controller.rb:120 does NOT store checkout session ID on the listing record after `Stripe::Checkout::Session.create` | OURS: organization_ai_credit_purchases_controller.rb:141 `purchase.update(stripe_checkout_session_id: session.id)` stores it | SANCTIONED: no — The AI credit model uses `stripe_checkout_session_id` for the `checkout.session.completed` webhook handler (stripe_webhook_handler_job.rb:59). The WWR listing doesn't need it because the webhook looks up the listing by invoice metadata. However the AI credit invoice.paid handler ALSO looks up by metadata (line 258), not by checkout_session_id. The stored checkout_session_id is used for the subscription flow (`checkout.session.completed` at line 59), not the one-off flow. WHITELIST: The `stripe_checkout_session_id` column exists on the model for the subscription flow. Storing it for one-off purchases is defensive but consistent with the model's schema.

DEVIATION: [Controller purchase_top_up checkout path: no job_id in payment_intent_data.metadata] | ANALOG: board_wwr_listings_controller.rb:96-98 `payment_intent_data.metadata` includes `board_wwr_listing_id`, `organization_id`, `job_id` | OURS: organization_ai_credit_purchases_controller.rb:119-121 `payment_intent_data.metadata` includes `organization_ai_credit_purchase_id`, `organization_id` (no job_id) | SANCTIONED: no — WHITELIST: AI credit one-off purchases have no job association.

DEVIATION: [Controller purchase_top_up checkout path: no job_id in invoice_creation.invoice_data.metadata] | ANALOG: board_wwr_listings_controller.rb:105-107 `invoice_data.metadata` includes `board_wwr_listing_id`, `job_id` | OURS: organization_ai_credit_purchases_controller.rb:128-129 `invoice_data.metadata` includes only `organization_ai_credit_purchase_id` (no job_id, no organization_id) | SANCTIONED: no — Note: WWR includes `job_id` in invoice_data.metadata. AI credit drops `organization_id` from invoice_data.metadata even though the WWR analog includes `job_id` (a second entity ID). This is a minor deviation -- the invoice_data.metadata has ONE fewer key than the analog pattern.

DEVIATION: [Controller purchase_top_up checkout path: product_data name/description fields] | ANALOG: board_wwr_listings_controller.rb:87-89 `name: "#{job.title} - We Work Remotely Job Listing", description: @final_description` (name includes job title, description is line-item description) | OURS: organization_ai_credit_purchases_controller.rb:111-112 `name: @description, description: @invoice_description` (name is the pack name, description is generic "Plato AI Credit Top-Up") | SANCTIONED: yes (ai_credit_* descriptor naming)

DEVIATION: [Webhook handler: AI credit one-off purchase branch follows WhatJobs pattern, not WWR pattern] | ANALOG: stripe_webhook_handler_job.rb:222-233 WWR branch calls `listing.finalize_stripe_payment` then `listing.create_on_wwr` (two calls) | OURS: stripe_webhook_handler_job.rb:253-269 AI credit branch calls `purchase.finalize_stripe_payment` then `purchase.grant_one_off_credits` (two calls) | SANCTIONED: n/a (MATCH — same two-call pattern as WWR)

DEVIATION: [Webhook handler: AI credit one-off purchase branch has extra Rails.logger.info between finalize and grant] | ANALOG: stripe_webhook_handler_job.rb:228-231 WWR branch: `finalize_stripe_payment` immediately followed by `create_on_wwr` (no intermediate logging) | OURS: stripe_webhook_handler_job.rb:261-266 AI credit branch: `finalize_stripe_payment`, then `Rails.logger.info "AI credit one-off purchase #{purchase_id} payment confirmed"`, then `grant_one_off_credits` | SANCTIONED: no — The WhatJobs branch (lines 241-248) also has this intermediate `Rails.logger.info` + a `broadcast_event` call between `finalize_stripe_payment` and `create_on_what_jobs`. The AI credit branch copies the WhatJobs pattern (intermediate logging) but not the WhatJobs broadcast_event call. REVERT: The extra `Rails.logger.info` between finalize and grant is harmless but deviates from the WWR analog. However, it matches the WhatJobs analog pattern. Keep it since it aids debugging.

DEVIATION: [Webhook handler: AI credit one-off purchase branch has comment] | ANALOG: stripe_webhook_handler_job.rb:222 WWR branch has no preceding comment | OURS: stripe_webhook_handler_job.rb:254-255 has comment `# One-off AI credit top-up invoice -- look up the purchase by metadata ID, finalize payment, then grant credits (mirrors WWR finalize + create_on_wwr).` | SANCTIONED: no — This is a cosmetic addition but matches the style of other comments in the file. The WWR branch is the first metadata branch and doesn't need explaining; the AI credit branch is newer.

DEVIATION: [Notification job: parameter shape] | ANALOG: notification/paid_wwr_listing_created_job.rb:6 `perform(organization_id, job_id)` | OURS: notification/ai_credit_top_up_purchased_job.rb:6 `perform(organization_id, purchase_id)` | SANCTIONED: no — WHITELIST: AI credit one-off purchases have no job; they have a purchase record. The second parameter being `purchase_id` instead of `job_id` is domain-forced.

DEVIATION: [Notification job: RecordNotFound rescue references undefined variable `e`] | ANALOG: notification/paid_wwr_listing_created_job.rb:13-14 `rescue ActiveRecord::RecordNotFound` / `ap e` (references `e` but the rescue doesn't capture it -- this is a BUG in the analog) | OURS: notification/ai_credit_top_up_purchased_job.rb:13-14 `rescue ActiveRecord::RecordNotFound` / `ap e` (same bug copied from analog) | SANCTIONED: n/a (MATCH -- both have the same bug: `rescue ActiveRecord::RecordNotFound` without `=> e` means `e` is undefined in the rescue block)

DEVIATION: [Notification job: Slack message content] | ANALOG: notification/paid_wwr_listing_created_job.rb:19 Slack message includes company name, org ID, job title, and WWR listing URL | OURS: notification/ai_credit_top_up_purchased_job.rb:19 Slack message includes company name, org ID, pack lookup_key, and credits granted | SANCTIONED: yes (ai_credit_* descriptor naming)

DEVIATION: [Frontend hook: usePurchaseAiCreditTopUp has no window.logger call] | ANALOG: useJob.ts:92-94 `createBoardWwrListing` has `window.logger("%c[useJob] createBoardWwrListing\n\n\n\n", "background-color: #FF76D2", { boardWwrListing })` | OURS: useOrganizationAiCreditPurchase.ts:95-99 `purchaseAiCreditTopUp` has no `window.logger` call | SANCTIONED: no — REVERT: The `window.logger` call is a development debugging aid used consistently in the WWR hooks. Adding one for `purchaseAiCreditTopUp` would match the pattern, but it's cosmetic and should be addressed separately.

DEVIATION: [Frontend hook: useCreateWwrCheckoutSession has no window.logger either] | ANALOG: useWwrListing.ts:7-24 `createWwrCheckoutSession` has no `window.logger` call | OURS: n/a | SANCTIONED: n/a — NOTE: The checkout session hook (`useWwrListing.ts`) also lacks `window.logger`, so the absence in `purchaseAiCreditTopUp` is consistent with the checkout analog, even though `createBoardWwrListing` in `useJob.ts` has it.

DEVIATION: [Frontend hook: usePurchaseAiCreditTopUp invalidates different query key] | ANALOG: useJob.ts does not have a corresponding `useCreateBoardWwrListing` hook exported (it defines `createBoardWwrListing` but the mutation hook for it is not shown in the searched results) | OURS: useOrganizationAiCreditPurchase.ts:102-109 `usePurchaseAiCreditTopUp` invalidates `["organizationAiCreditBalance"]` on success | SANCTIONED: no — WHITELIST: AI credit balance queries must be invalidated after a purchase to refresh the credit count. WWR listings don't affect a balance.

DEVIATION: [Serializer: different attributes] | ANALOG: board_wwr_listing_serializer.rb serializes `id, job_id, created_at, published_at, wwr_listing_id, status, wwr_category, wwr_region, wwr_job_listing_type, listing_url, is_active?, expires_at, plan` | OURS: organization_ai_credit_purchase_serializer.rb serializes `id, kind, stripe_checkout_session_id, stripe_price_lookup_key, stripe_amount, currency, one_off_credits_granted, subscription_credits_per_period, subscription_status, subscription_current_period_start, subscription_current_period_end, subscription_canceled_at, refunded_at, created_at, is_active?` | SANCTIONED: no — WHITELIST: Completely different domain models with different columns. The shared attributes are `id`, `created_at`, and `is_active?`. The serializer correctly exposes the AI credit purchase's own columns.

---NEXT DIMENSION---

WhatJobs does not have a `stripe_subscription` method. AI credit has it for the subscription side. This is subscription-specific, not relevant to the one-off purchase comparison.

Now let me compile the full deviation report.

DEVIATION: [Model-level charge method name] | ANALOG: board_what_jobs_listing.rb:156 `charge_for_listing` | OURS: organization_ai_credit_purchase.rb:192 `charge_default_payment_method` | SANCTIONED: no

DEVIATION: [Model charge method — guard condition] | ANALOG: board_what_jobs_listing.rb:160 guard uses `live?` (checks expiry + active status) | OURS: organization_ai_credit_purchase.rb:195 guard uses `is_active?` (checks `stripe_invoice_paid?`) — follows WWR pattern instead | SANCTIONED: no

DEVIATION: [Model charge method — guard message] | ANALOG: board_what_jobs_listing.rb:161 `ap 'Already charged for this listing'` | OURS: organization_ai_credit_purchase.rb:196 `ap 'Hmm, if trying to charge for an update because of expiration we run into a small issue'` — copies WWR message instead of WhatJobs | SANCTIONED: no

DEVIATION: [Model charge method — organization access pattern] | ANALOG: board_what_jobs_listing.rb:165 `organization = job.organization` (navigates through `job` association) | OURS: organization_ai_credit_purchase.rb:200 `return if organization.stripe_customer_id.blank?` (direct `organization` belongs_to) | SANCTIONED: yes (Sub change #2: Operates on OrganizationAiCreditPurchase record not org — no `job` association)

DEVIATION: [Model charge method — description format] | ANALOG: board_what_jobs_listing.rb:168 `@description = "WhatJobs Job listing - #{job.title}"` | OURS: organization_ai_credit_purchase.rb:202-203 `pack_name = AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY.dig(...); @description = "#{pack_name} - #{organization.name}"` | SANCTIONED: yes (Sub change #5: ai_credit_* descriptor naming)

DEVIATION: [Model charge method — @final_description dead code] | ANALOG: board_what_jobs_listing.rb has no `@final_description` | OURS: organization_ai_credit_purchase.rb:205 `@final_description = @description` — dead scaffolding copied from WWR discount pattern; `@final_description` always equals `@description` | SANCTIONED: no
REVERT: This is vestigial from the WWR analog which uses `@final_description` for discount text. Should be replaced with just `@description`.

DEVIATION: [Model charge method — extra ap logging] | ANALOG: board_what_jobs_listing.rb:195 only `ap 'Invoice Has Been Finalized'` | OURS: organization_ai_credit_purchase.rb:233-234 `ap 'Invoice Has Been Finalized'` PLUS `ap [invoice_item, paid_invoice]` — extra object logging not in WhatJobs analog | SANCTIONED: no
REVERT: The extra `ap [invoice_item, paid_invoice]` is copied from WWR (board_wwr_listing.rb:160-161 `Rails.logger.info [invoice_item, paid_invoice]`). However WWR uses `Rails.logger.info` while AI credit uses `ap`. Should remove or match WWR's logging style.

DEVIATION: [Model charge method — commented auto_advance] | ANALOG: board_what_jobs_listing.rb has NO `# auto_advance: false` comment in Stripe::Invoice.create | OURS: organization_ai_credit_purchase.rb:221 `# auto_advance: false,` — copied from WWR analog instead of WhatJobs | SANCTIONED: no
REVERT: Cosmetic — vestigial comment from WWR. Does not affect behavior.

DEVIATION: [Model calculate_charge_amount — implementation strategy] | ANALOG: board_what_jobs_listing.rb:151-154 returns hardcoded `17_500` | OURS: organization_ai_credit_purchase.rb:184-190 makes Stripe API call via `Stripe::Price.list` to look up price dynamically | SANCTIONED: no

DEVIATION: [Model — associations] | ANALOG: board_what_jobs_listing.rb:4-6 `belongs_to :job`, `belongs_to :last_updated_by_organization_user`, `belongs_to :job_board_integration` | OURS: organization_ai_credit_purchase.rb:78-79 `belongs_to :organization`, `has_many :ai_credit_balance_transactions` | SANCTIONED: yes (Sub change #2: Operates on OrganizationAiCreditPurchase record not org)

DEVIATION: [Model — enums] | ANALOG: board_what_jobs_listing.rb:18-78 has `status`, `what_jobs_work_from`, `what_jobs_employment_type`, `employment_sub_type`, `schedule_type`, `start_type`, `salary_display_type`, `contract_period` enums | OURS: organization_ai_credit_purchase.rb:81-84 has `kind` and `subscription_status` enums | SANCTIONED: yes (Sub change #2: different domain model)

DEVIATION: [Model — validations] | ANALOG: board_what_jobs_listing.rb:16 only `validate :cannot_update_inactive_listing, on: :update` | OURS: organization_ai_credit_purchase.rb:86-112 extensive validations on `stripe_price_lookup_key`, `kind`, `stripe_subscription_id`, `subscription_credits_per_period`, etc. | SANCTIONED: yes (Sub change #2: different domain model with different validation needs)

DEVIATION: [Model — callbacks] | ANALOG: board_what_jobs_listing.rb:12-13 `before_create :set_internal_id`, `after_update_commit :queue_sync_if_active` | OURS: organization_ai_credit_purchase.rb has no callbacks | SANCTIONED: yes (Sub change #2: no external API sync needed)

DEVIATION: [Model — broadcast_event channel] | ANALOG: board_what_jobs_listing.rb:289 `JobChannel.broadcast_to(job, event: event, ...)` | OURS: organization_ai_credit_purchase.rb:168 `GlobalChannel.broadcast_to(organization.owner, action: event, ...)` | SANCTIONED: yes (Sub change #2: org-level, not job-scoped)

DEVIATION: [Model — broadcast_event key name] | ANALOG: board_what_jobs_listing.rb:289 uses `event:` key | OURS: organization_ai_credit_purchase.rb:168 uses `action:` key | SANCTIONED: no

DEVIATION: [Model — broadcast_show_growl target] | ANALOG: board_what_jobs_listing.rb:293 targets `last_updated_by_organization_user.user` (with fallback to `job.organization.owner`) | OURS: organization_ai_credit_purchase.rb:172 always targets `organization.owner` (no last_updated_by concept) | SANCTIONED: yes (Sub change #2: no job/last_updated_by association)

DEVIATION: [Model — broadcast_error_growl target] | ANALOG: board_what_jobs_listing.rb:297 same conditional targeting as broadcast_show_growl | OURS: organization_ai_credit_purchase.rb:176 always targets `organization.owner` | SANCTIONED: yes (Sub change #2)

DEVIATION: [Model — post-payment method name and behavior] | ANALOG: board_what_jobs_listing.rb:204-209 `create_on_what_jobs` — publishes to external WhatJobs API | OURS: organization_ai_credit_purchase.rb:129-165 `grant_one_off_credits` — grants credits to ledger, resets notifications, broadcasts, fires notification job | SANCTIONED: yes (fundamentally different post-payment action)

DEVIATION: [Model — post-payment idempotency guard] | ANALOG: board_what_jobs_listing.rb:205-206 `return unless draft?` (uses enum status) | OURS: organization_ai_credit_purchase.rb:132-135 `if ai_credit_balance_transactions.exists?(entry_type: :one_off_credit_pack_purchase_credit)` (checks for existing ledger row) | SANCTIONED: yes (different domain — credit granting needs ledger-based idempotency)

DEVIATION: [Model — grant_one_off_credits rescue clause] | ANALOG: board_what_jobs_listing.rb `create_on_what_jobs` has NO rescue | OURS: organization_ai_credit_purchase.rb:162-164 `rescue StandardError => e` with `Rails.logger.info` — follows WWR pattern | SANCTIONED: no

DEVIATION: [Webhook handler — extra broadcast in between finalize and post-payment action] | ANALOG: stripe_webhook_handler_job.rb:245 WhatJobs branch has `listing.broadcast_event('what_jobs_listing_payment_received')` between `finalize_stripe_payment` and `create_on_what_jobs` | OURS: stripe_webhook_handler_job.rb:262-266 AI credit branch has NO intermediate broadcast — broadcast is inside `grant_one_off_credits` instead (follows WWR pattern) | SANCTIONED: no

DEVIATION: [Controller — merged payment paths] | ANALOG: board_what_jobs_listings_controller.rb has TWO separate actions: `create_paid_listing` (line 132) for direct charge + `create_checkout_session` (line 180) for Stripe checkout | OURS: organization_ai_credit_purchases_controller.rb:69 single `purchase_top_up` action with `if/else` branching for default payment method vs checkout | SANCTIONED: no

DEVIATION: [Controller — record creation via interactor vs direct build] | ANALOG: board_what_jobs_listings_controller.rb:141 uses `CreateOrUpdateWhatJobsListingWithIntegration.call(...)` interactor | OURS: organization_ai_credit_purchases_controller.rb:78-85 builds `OrganizationAiCreditPurchase.new(...)` directly in controller | SANCTIONED: yes (no integration/draft workflow needed for AI credit one-off purchase)

DEVIATION: [Controller — pre-charge validation] | ANALOG: board_what_jobs_listings_controller.rb:156 calls `ValidateWhatJobsListing.call(listing: @listing, job: job)` before charging | OURS: organization_ai_credit_purchases_controller.rb relies only on ActiveModel validations via `purchase.save` | SANCTIONED: yes (Sub change #3: No ValidateSubscriptionChange / PlanFeatureGate / job-limit gate)

DEVIATION: [Controller — lookup key validation in purchase_top_up] | ANALOG: board_what_jobs_listings_controller.rb `create_paid_listing` has NO lookup key validation | OURS: organization_ai_credit_purchases_controller.rb:72-76 validates `lookup_key` via `OrganizationAiCreditPurchase.ai_credit_top_up_lookup_key?` | SANCTIONED: yes (AI credit one-off purchase has multiple price tiers, WhatJobs has a single price)

DEVIATION: [Controller — checkout session saves stripe_checkout_session_id on record] | ANALOG: board_what_jobs_listings_controller.rb `create_checkout_session` does NOT save `stripe_checkout_session_id` on the listing | OURS: organization_ai_credit_purchases_controller.rb:141 `purchase.update(stripe_checkout_session_id: session.id)` | SANCTIONED: no

DEVIATION: [Controller — error handling in purchase_top_up] | ANALOG: board_what_jobs_listings_controller.rb `create_paid_listing` has `rescue WhatJobsApi::ValidationError`, `rescue Stripe::StripeError`, `rescue StandardError` (3 rescue clauses) | OURS: organization_ai_credit_purchases_controller.rb `purchase_top_up` has `rescue Stripe::StripeError`, `rescue StandardError` (2 rescue clauses — missing domain-specific error) | SANCTIONED: yes (no WhatJobs API validation equivalent for AI credit one-off purchase)

DEVIATION: [Controller — checkout session product_data.name format] | ANALOG: board_what_jobs_listings_controller.rb:228 `name: "#{job.title} - WhatJobs Job Listing"` | OURS: organization_ai_credit_purchases_controller.rb:111 `name: @description` (which is the pack name from `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY`) | SANCTIONED: yes (Sub change #5: ai_credit_* descriptor naming)

DEVIATION: [Controller — checkout session description vs invoice_description] | ANALOG: board_what_jobs_listings_controller.rb:218,229 uses `@description` for both `description` in product_data and `invoice_data` | OURS: organization_ai_credit_purchases_controller.rb:101-102 creates separate `@description` and `@invoice_description` variables | SANCTIONED: no
REVERT: The separation into `@description` and `@invoice_description` is unnecessary for AI credit one-off purchase. Copied from WWR checkout which uses different strings. Should simplify.

DEVIATION: [Notification job — no Discord counterpart] | ANALOG: WhatJobs has no purchase notification job at all (only API failure notifications) | OURS: organization_ai_credit_purchase.rb:161 fires `Notification::AiCreditTopUpPurchasedJob` — follows WWR pattern which has `Notification::PaidWwrListingCreatedJob`. Neither analog has a Discord notification for purchases | SANCTIONED: no

DEVIATION: [Notification job — Slack-only, no Discord] | ANALOG: board_wwr_listing.rb:196 `Notification::PaidWwrListingCreatedJob` has Slack only, no Discord | OURS: ai_credit_top_up_purchased_job.rb has Slack only, no Discord | SANCTIONED: N/A (matches WWR — WhatJobs has no equivalent)

DEVIATION: [Notification job — e variable bug] | ANALOG: paid_wwr_listing_created_job.rb:14 `ap e` without defining `e` in `rescue ActiveRecord::RecordNotFound` | OURS: ai_credit_top_up_purchased_job.rb:14 `ap e` — same bug copied faithfully from WWR analog | SANCTIONED: N/A (faithful copy of a bug)

DEVIATION: [Model — is_active? semantics] | ANALOG: board_what_jobs_listing.rb has no `is_active?` — uses `live?` (checks `what_jobs_expires_at.present? && what_jobs_expires_at > DateTime.now && active?`) and `paid?` (checks `stripe_invoice_paid?`) separately | OURS: organization_ai_credit_purchase.rb:118-119 `is_active?` returns `stripe_invoice_paid?` — follows WWR pattern where `is_active?` checks `expires_at.present? && expires_at > DateTime.now && approved?` but AI credit simplifies to just payment check | SANCTIONED: no

DEVIATION: [Model — AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY constant] | ANALOG: board_what_jobs_listing.rb has no equivalent lookup table | OURS: organization_ai_credit_purchase.rb:4-57 large lookup constant for mapping price keys to credit amounts | SANCTIONED: yes (AI credit one-off purchase has multiple tiers requiring a lookup table)

DEVIATION: [Model — class methods for lookup key validation] | ANALOG: board_what_jobs_listing.rb has no equivalent | OURS: organization_ai_credit_purchase.rb:59-76 `ai_credit_lookup_keys`, `ai_credit_subscription_plan_lookup_key?`, `ai_credit_top_up_lookup_key?`, `ai_credit_allocation_for_lookup_key` | SANCTIONED: yes (AI credit one-off purchase has multiple tiers)

DEVIATION: [Model — stripe_subscription method] | ANALOG: board_what_jobs_listing.rb has no equivalent | OURS: organization_ai_credit_purchase.rb:239-243 `stripe_subscription` method for subscription side | SANCTIONED: yes (subscription-specific, part of Sub change #1/2)

DEVIATION: [Webhook handler — WhatJobs logs "WhatJobs listing #{listing_id} payment confirmed" before broadcast] | ANALOG: stripe_webhook_handler_job.rb:244 `Rails.logger.info "WhatJobs listing #{listing_id} payment confirmed"` appears before `broadcast_event` | OURS: stripe_webhook_handler_job.rb:264 `Rails.logger.info "AI credit one-off purchase #{purchase_id} payment confirmed"` appears before `grant_one_off_credits` | SANCTIONED: N/A (matches — both log before post-payment action)

Now I have all the deviations. Let me compile the final report.

DEVIATION: [Model charge method name] | ANALOG: board_what_jobs_listing.rb:156 `charge_for_listing` | OURS: organization_ai_credit_purchase.rb:192 `charge_default_payment_method` | SANCTIONED: no

DEVIATION: [Model charge method guard uses is_active? instead of live?] | ANALOG: board_what_jobs_listing.rb:160 `stripe_invoice_id.present? && live?` where `live?` checks expiry + active enum status | OURS: organization_ai_credit_purchase.rb:195 `stripe_invoice_id.present? && is_active?` where `is_active?` only checks `stripe_invoice_paid?` -- follows WWR pattern instead of WhatJobs | SANCTIONED: no

DEVIATION: [Model charge method guard ap message] | ANALOG: board_what_jobs_listing.rb:161 `ap 'Already charged for this listing'` | OURS: organization_ai_credit_purchase.rb:196 `ap 'Hmm, if trying to charge for an update because of expiration we run into a small issue'` -- copies WWR text instead of WhatJobs text | SANCTIONED: no
REVERT: The WWR message references "expiration" which does not apply to AI credit one-off purchases. The WhatJobs message is more appropriate.

DEVIATION: [Model charge method @final_description dead code] | ANALOG: board_what_jobs_listing.rb charge method has no @final_description | OURS: organization_ai_credit_purchase.rb:205 `@final_description = @description` -- dead scaffolding from WWR discount pattern, always equals @description | SANCTIONED: no
REVERT: Vestigial from WWR analog. Remove and use @description directly.

DEVIATION: [Model charge method extra ap logging of objects] | ANALOG: board_what_jobs_listing.rb:195 only `ap 'Invoice Has Been Finalized'` | OURS: organization_ai_credit_purchase.rb:234 adds `ap [invoice_item, paid_invoice]` -- not in WhatJobs analog, copied from WWR | SANCTIONED: no
REVERT: Cosmetic. WWR uses `Rails.logger.info` for this; AI credit uses `ap`. Either remove or match WWR style.

DEVIATION: [Model charge method commented auto_advance] | ANALOG: board_what_jobs_listing.rb Stripe::Invoice.create has no auto_advance comment | OURS: organization_ai_credit_purchase.rb:221 has `# auto_advance: false,` comment -- copied from WWR | SANCTIONED: no
REVERT: Cosmetic vestigial comment from WWR.

DEVIATION: [Model calculate_charge_amount -- Stripe API call vs hardcoded] | ANALOG: board_what_jobs_listing.rb:151-154 returns hardcoded `17_500` | OURS: organization_ai_credit_purchase.rb:184-190 calls `Stripe::Price.list` API to look up price dynamically | SANCTIONED: no

DEVIATION: [Model broadcast_event uses action: key instead of event: key] | ANALOG: board_what_jobs_listing.rb:289 `JobChannel.broadcast_to(job, event: event, ...)` uses `event:` key | OURS: organization_ai_credit_purchase.rb:168 `GlobalChannel.broadcast_to(organization.owner, action: event, ...)` uses `action:` key | SANCTIONED: no

DEVIATION: [Model grant_one_off_credits has rescue StandardError] | ANALOG: board_what_jobs_listing.rb:204-209 `create_on_what_jobs` has no rescue block | OURS: organization_ai_credit_purchase.rb:162-164 has `rescue StandardError => e` with `Rails.logger.info` -- follows WWR `create_on_wwr` pattern instead | SANCTIONED: no

DEVIATION: [Webhook handler -- missing intermediate broadcast_event between finalize and post-payment] | ANALOG: stripe_webhook_handler_job.rb:245 WhatJobs branch calls `listing.broadcast_event('what_jobs_listing_payment_received')` between `finalize_stripe_payment` and `create_on_what_jobs` | OURS: stripe_webhook_handler_job.rb:262-266 AI credit branch goes straight from `finalize_stripe_payment` to `grant_one_off_credits` with no intermediate broadcast -- follows WWR pattern | SANCTIONED: no

DEVIATION: [Controller -- two actions merged into one] | ANALOG: board_what_jobs_listings_controller.rb has separate `create_paid_listing` (line 132) and `create_checkout_session` (line 180) | OURS: organization_ai_credit_purchases_controller.rb:69 single `purchase_top_up` action with `if/else` branching on `stripe_default_payment_method_on_file` | SANCTIONED: no

DEVIATION: [Controller checkout path -- saves stripe_checkout_session_id on purchase record] | ANALOG: board_what_jobs_listings_controller.rb `create_checkout_session` does NOT save session ID to the listing record | OURS: organization_ai_credit_purchases_controller.rb:141 `purchase.update(stripe_checkout_session_id: session.id)` after creating checkout session | SANCTIONED: no

DEVIATION: [Controller checkout path -- separate @description and @invoice_description] | ANALOG: board_what_jobs_listings_controller.rb:218,229 uses single `@description` for both product_data.description and invoice_data.description | OURS: organization_ai_credit_purchases_controller.rb:101-102 creates separate `@description` and `@invoice_description` variables -- copied from WWR checkout pattern | SANCTIONED: no
REVERT: Unnecessary separation. WWR uses separate descriptions for different display text (listing name vs invoice line). AI credit uses the same text for both, making the separation dead scaffolding.

DEVIATION: [Model is_active? semantics simplified] | ANALOG: board_what_jobs_listing.rb uses `live?` which checks `what_jobs_expires_at.present? && what_jobs_expires_at > DateTime.now && active?` -- considers both expiry and status | OURS: organization_ai_credit_purchase.rb:118-119 `is_active?` only returns `stripe_invoice_paid?` -- no expiry or status check. Follows WWR `is_active?` pattern but simplifies away the expiry+status checks that WWR has | SANCTIONED: no

DEVIATION: [Notification job rescue bug faithfully copied] | ANALOG: paid_wwr_listing_created_job.rb:14 `ap e` references undefined `e` in `rescue ActiveRecord::RecordNotFound` block | OURS: ai_credit_top_up_purchased_job.rb:14 same bug: `ap e` without capturing exception variable | SANCTIONED: no

WHITELIST: [grant_one_off_credits includes Notification::AiCreditTopUpPurchasedJob.perform_later] -- WhatJobs `create_on_what_jobs` has NO notification job call. The AI credit code follows WWR's pattern of calling a Notification job inside the post-payment method. This is additive relative to WhatJobs but matches WWR. Removing it would lose purchase notifications.

WHITELIST: [broadcast_event and broadcast_show_growl inside grant_one_off_credits instead of in webhook handler] -- WhatJobs puts `broadcast_event` in the webhook handler and relies on the WhatJobsListing service for post-publish broadcasts. AI credit puts all broadcasts inside `grant_one_off_credits` following the WWR pattern where `create_on_wwr` contains all broadcasts. Restructuring to match WhatJobs would separate concerns differently but not improve correctness.

---NEXT DIMENSION---

One more thing to check — the analog updates `stripe_current_period_end_at` on the org using `organization.update(...)`. The AI credit path updates period fields on the purchase using `purchase.update(...)`. The org's `stripe_current_period_end_at` is NOT updated in the AI credit path. This is correct because the AI credit subscription's period has nothing to do with the org's main-plan period. Sanctioned (Sub change #2).

Let me also check: does the analog's `reset_ai_credits` have any effect that `ApplyAiCreditPurchase` doesn't?

`ResetAiCredits`:
1. Zero out monthly_credits_remaining (monthly bucket)
2. Grant new allocation to monthly bucket
3. Update last_reset_at, clear notification timestamps

`ApplyAiCreditPurchase`:
1. Zero out addon_subscription_credits_remaining (addon_subscription bucket)
2. Grant new allocation to addon_subscription bucket
3. Update last_reset_at, clear notification timestamps

These are structurally equivalent with different bucket names. Match.

Let me verify one final thing — the `raise` on line 462 is a raw string raise, not a custom error class:

Line 271: `raise CustomStripeSubscriptionMissingError` — custom error class
Line 456: `raise CustomStripeSubscriptionMissingError` — same custom error class
Line 462: `raise "invoice.paid: no OrganizationAiCreditPurchase..."` — raw RuntimeError string

The analog doesn't have an equivalent record-not-found raise because it uses `organization` directly (already found). But this is a forced deviation of Sub change #2.

Let me check one more structural thing — does `handle_subscription_credit_pack_invoice_paid` continue after a failed purchase update? Line 473: `unless updated` — it logs but does NOT return or raise. It proceeds to `stripe_update_default_payment_method` and `ApplyAiCreditPurchase.call` even if the purchase update failed. The analog (line 279) calls `organization.update(...)` but also doesn't check if it succeeded — it just moves on. So this is actually a deviation in the OTHER direction — ours logs the failure but the analog doesn't even check.

Wait, let me re-check — the analog's `organization.update(stripe_current_period_end_at: ...)` on line 279 — does it check the return value? No, it discards it. So the analog silently ignores update failures. Ours logs them but also continues. The LOGGING is the deviation; the continue-on-failure is a match.

Here is my complete report:

---

DEVIATION: [Extracted to private method vs inline] | ANALOG: stripe_webhook_handler_job.rb:279-281 — the else branch is three lines inline in handle_stripe_event | OURS: stripe_webhook_handler_job.rb:277+455-488 — extracted to private method handle_subscription_credit_pack_invoice_paid (34 lines) | SANCTIONED: no

DEVIATION: [Duplicate guard — CustomStripeSubscriptionMissingError] | ANALOG: stripe_webhook_handler_job.rb:271 — checked once before routing, gates both branches | OURS: stripe_webhook_handler_job.rb:456 — duplicated inside handle_subscription_credit_pack_invoice_paid; already guaranteed to have passed at line 271 before reaching this method | SANCTIONED: no

DEVIATION: [Guard checks org's main-plan subscription_id, not AI credit subscription] | ANALOG: stripe_webhook_handler_job.rb:271 — `organization.stripe_subscription_id.nil?` is correct because the else branch operates on the org's main-plan subscription | OURS: stripe_webhook_handler_job.rb:456 — same check `organization.stripe_subscription_id.nil?` but the relevant subscription is `purchase.stripe_subscription_id` (AI credit subscription); an org without a main plan but with an AI credit subscription would be blocked | WHITELIST: The guard at line 271 runs before routing to handle_subscription_credit_pack_invoice_paid. Removing the duplicate at 456 does not help — line 271 must also be fixed to not block AI-credit-only orgs. That requires changing the shared routing logic, which is beyond the scope of this comparison.

DEVIATION: [Duplicate Stripe::Subscription.retrieve API call] | ANALOG: stripe_webhook_handler_job.rb:273 — retrieves subscription once, used at line 279 for period_end | OURS: stripe_webhook_handler_job.rb:273+464 — retrieves the same subscription twice (line 273 for routing, line 464 again inside handle_subscription_credit_pack_invoice_paid); already-retrieved object not passed as parameter | SANCTIONED: no

DEVIATION: [subscription_status updated on invoice.paid — analog does not] | ANALOG: stripe_webhook_handler_job.rb:279 — only updates stripe_current_period_end_at; subscription status is updated by the subscription.updated webhook (line 148) | OURS: stripe_webhook_handler_job.rb:471 — updates subscription_status in invoice.paid handler; subscription.updated (line 137) also updates it, meaning status is updated twice per renewal cycle | SANCTIONED: no

DEVIATION: [Per-step error logging on purchase update] | ANALOG: stripe_webhook_handler_job.rb:279 — discards organization.update return value; no per-step logging | OURS: stripe_webhook_handler_job.rb:473-476 — checks purchase.update return, logs with ap + Rails.logger.error on failure | SANCTIONED: no

DEVIATION: [Per-step error logging on credit operation result] | ANALOG: stripe_webhook_handler_job.rb:281 — discards reset_ai_credits return value | OURS: stripe_webhook_handler_job.rb:480-487 — stores ApplyAiCreditPurchase.call result, checks result.success?, logs with ap + Rails.logger.error on failure | SANCTIONED: no

DEVIATION: [No safe navigation before credit operation] | ANALOG: stripe_webhook_handler_job.rb:281 — `organization.organization_ai_credit_balance&.reset_ai_credits` uses safe nav `&.` to skip if balance is nil | OURS: stripe_webhook_handler_job.rb:480 — calls ApplyAiCreditPurchase.call directly without safe nav; nil balance handled inside interactor via context.fail! (different error path than silently skipping) | SANCTIONED: no

DEVIATION: [stripe_update_default_payment_method no-arg resolves wrong subscription] | ANALOG: stripe_webhook_handler_job.rb:280 — no-arg call; Organization#stripe_payment_method (line 513) uses org.stripe_subscription_id to find PM — correct because the relevant subscription IS the org's subscription | OURS: stripe_webhook_handler_job.rb:478 — same no-arg call, but the relevant subscription is purchase.stripe_subscription_id (AI credit subscription); the no-arg form looks up the org's main-plan subscription's PM instead | SANCTIONED: no

DEVIATION: [Time.current inline vs stored in variable] | ANALOG: reset_ai_credits.rb:37 — `now = Time.current` stored in variable, used at line 66 | OURS: apply_ai_credit_purchase.rb:76 — `Time.current` used inline | SANCTIONED: no

DEVIATION: [Missing comment on context.balance assignment] | ANALOG: reset_ai_credits.rb:75 — `# Expose the refreshed balance to callers (#39).` comment above `context.balance = balance` | OURS: apply_ai_credit_purchase.rb:85 — bare `context.balance = balance` with no comment | SANCTIONED: no

DEVIATION: [Grant row includes organization_ai_credit_purchase association] | ANALOG: reset_ai_credits.rb:53-63 — grant AiCreditBalanceTransaction has no organization_ai_credit_purchase | OURS: apply_ai_credit_purchase.rb:64 — grant row includes `organization_ai_credit_purchase: purchase` | SANCTIONED: yes (Sub change #2 — operates on OrganizationAiCreditPurchase record)

DEVIATION: [Allocation source — purchase.subscription_credits_per_period vs resolve_allocation] | ANALOG: reset_ai_credits.rb:36+94-100 — resolve_allocation checks monthly_ai_credits_override then PlanFeatureGate | OURS: apply_ai_credit_purchase.rb:61 — uses purchase.subscription_credits_per_period directly | SANCTIONED: yes (Sub change #2 + Sub change #3 — no PlanFeatureGate/override for AI credit subscriptions)

DEVIATION: [Additional purchase nil guard in interactor] | ANALOG: reset_ai_credits.rb — takes only organization, no purchase concept | OURS: apply_ai_credit_purchase.rb:37-45 — additional `unless purchase` guard with context.fail! | SANCTIONED: yes (Sub change #2 — operates on OrganizationAiCreditPurchase record)

DEVIATION: [Period fields updated on purchase vs org] | ANALOG: stripe_webhook_handler_job.rb:279 — updates stripe_current_period_end_at on Organization | OURS: stripe_webhook_handler_job.rb:469-470 — updates subscription_current_period_start AND subscription_current_period_end on OrganizationAiCreditPurchase | SANCTIONED: yes (Sub change #2 — operates on OrganizationAiCreditPurchase record, which stores both start and end)

DEVIATION: [amount_cents_paid and currency updated — analog has no equivalent] | ANALOG: stripe_webhook_handler_job.rb:279 — no payment amount tracking on Organization for main-plan renewals | OURS: stripe_webhook_handler_job.rb:467-468 — updates amount_cents_paid and currency on purchase | SANCTIONED: yes (Sub change #2 — OrganizationAiCreditPurchase tracks payment amounts)

---NEXT DIMENSION---

Comparing to the locally defined versions in AiCreditSubscription.tsx:

- `Styled.Subtitle` (line 423-431): Uses `${[t.text.bold, t.mt(8)]}` and `font-size: 1rem;` -- matches the analog's `Subtitle` from AccountBillingComponents
- `Styled.OptionsContainer` (line 442-451): Uses `${[t.mt(4)]}` and `max-width: 755px;` -- differs from analog which uses `${[t.mt(9)]}` and responsive breakpoints for max-width
- `Styled.Options` (line 453-461): Uses `gap: ${t.spacing[3]};` -- matches analog but lacks the `flex-direction: column` default and `breakpoint.xs { flex-direction: row; }` responsive behavior

DEVIATION: [OptionsContainer margin-top] | ANALOG: AccountBillingComponents.tsx `PricingOptionsContainer` uses `t.mt(9)` | OURS: AiCreditSubscription.tsx:448 `Styled.OptionsContainer` uses `t.mt(4)` | SANCTIONED: no

DEVIATION: [OptionsContainer responsive max-width breakpoints] | ANALOG: AccountBillingComponents.tsx `PricingOptionsContainer` has responsive breakpoints (`max-width: 300px` default, `500px` at sm, `755px` at lg) | OURS: AiCreditSubscription.tsx:449 `Styled.OptionsContainer` uses flat `max-width: 755px` with no responsive breakpoints | SANCTIONED: no

DEVIATION: [Options flex-direction default] | ANALOG: AccountBillingComponents.tsx `PricingOptions` defaults to `flex-direction: column` with `flex-direction: row` at `breakpoint.xs` | OURS: AiCreditSubscription.tsx:455-460 `Styled.Options` has no `flex-direction` default (flexbox default is `row`) and no responsive breakpoint | SANCTIONED: no

DEVIATION: [Not importing shared components from AccountBillingComponents] | ANALOG: AccountBillingPlans.tsx:16-21 imports `Subtitle`, `PricingOptions`, `PricingOptionsContainer` and more from AccountBillingComponents | OURS: AiCreditSubscription.tsx:21-23 imports only `Promo` and `CurrentSubscription` from AccountBillingComponents, defining its own `Subtitle`, `OptionsContainer`, `Options` locally | SANCTIONED: no

DEVIATION: [Section wrapper] | ANALOG: AccountBillingPlans.tsx:356-468 renders directly with `<>...</>` (React fragment) | OURS: AiCreditSubscription.tsx:317 wraps everything in `<Styled.Section>` | SANCTIONED: no

DEVIATION: [currentProductPrice calculation] | ANALOG: AccountBillingPlans.tsx:137-142 calculates `currentProductPrice` from `currentPriceObject` with tiered/unit pricing logic | OURS: AiCreditSubscription.tsx does not calculate a `currentProductPrice` | SANCTIONED: no

WHITELIST: `currentProductPrice` is never used in the analog's JSX render output or passed to child components -- it is only logged. The AI credit version omits the dead calculation.

DEVIATION: [BillingPeriodToggleWrapper / Badge "2 months free"] | ANALOG: AccountBillingPlans.tsx:359-367 renders `BillingPeriodToggleWrapper` containing `SlidingToggleSwitch` and `<Badge>2 months free</Badge>` | OURS: AiCreditSubscription.tsx has no toggle or "2 months free" badge | SANCTIONED: no

WHITELIST: AI credit subscriptions are monthly-only. There is no yearly option, so the toggle and savings badge do not apply.

DEVIATION: [isCanceledButStillActive banner with cancel button] | ANALOG: AccountBillingPlans.tsx has NO equivalent banner -- the analog shows `cancelAtPeriodEnd` banner but not a "canceled but still active" state | OURS: AiCreditSubscription.tsx:318-330 shows an `isCanceledButStillActive` banner with "Cancel subscription" button | SANCTIONED: no

**Analysis**: The analog's cancellation goes through the Stripe portal (cancel_at_period_end is set by Stripe). It shows the `cancelAtPeriodEnd` banner but does not track a separate "canceled but credits remain usable" local state. The AI credit version uses `CancelAiCreditSubscription` interactor which sets local `subscription_status` to `canceled` immediately, creating a distinct `isCanceledButStillActive` state that needs its own banner.

WHITELIST: The AI credit subscription has a dedicated cancel mechanism that creates a local `canceled` status while Stripe keeps credits active until period end. This intermediate state has no analog in the billing flow, which delegates cancellation entirely to Stripe. The banner is necessary to inform users their credits remain usable until period end.

DEVIATION: [Active subscription banner with cancel button] | ANALOG: AccountBillingPlans.tsx has NO equivalent "active subscription" banner -- the analog shows the current plan via `PlanCard`'s `isCurrentPlan` badge and `ManageBillingActions` | OURS: AiCreditSubscription.tsx:343-355 shows an "Active AI credit subscription" banner with credits count, renewal date, and "Cancel subscription" button | SANCTIONED: no

DEVIATION: [cancel button in cancelAtPeriodEnd banner] | ANALOG: AccountBillingPlans.tsx:391-394 shows "Manage billing" button that opens Stripe portal | OURS: AiCreditSubscription.tsx:332-340 shows NO button in the `cancelAtPeriodEnd` banner | SANCTIONED: no

DEVIATION: [useCurrentSession import] | ANALOG: AccountBillingPlans.tsx receives `currentOrganization` as a prop | OURS: AiCreditSubscription.tsx:17,54 imports `useCurrentSession` and destructures `currentOrganization` from it | SANCTIONED: no

---

## SUMMARY OF UNSANCTIONED DEVIATIONS

1. **cancelAtPeriodEnd banner missing action button** -- AiCreditSubscription.tsx:332-340 shows the banner but no "Manage billing" or equivalent button. The analog has a button.

2. **Not reusing shared styled components** (`Subtitle`, `PricingOptionsContainer`, `PricingOptions`) from AccountBillingComponents -- instead creating local styled components with different styles (different margin-top, missing responsive breakpoints, different flex-direction default).

3. **OptionsContainer has `t.mt(4)` vs analog's `t.mt(9)`** -- different spacing.

4. **OptionsContainer missing responsive breakpoints** for max-width.

5. **Options missing `flex-direction: column` default and `breakpoint.xs` responsive behavior**.

6. **Section wrapper `<Styled.Section>`** -- analog uses bare React fragment.

7. **`currentOrganization` obtained via `useCurrentSession` hook** instead of received as prop like the analog.

8. **Active subscription banner** (lines 343-355) and **isCanceledButStillActive banner** (lines 318-330) have no analog equivalents -- but these are WHITELISTED because they serve the AI credit subscription's distinct cancel lifecycle.

9. **trackEvent payload differences** (`selected_tier_credits` vs `selected_plan_key`, missing `selected_plan_billing_period`) -- WHITELISTED because AI credits are credit-count-based and monthly-only.

10. **ContactUsCallout positioned between subscription tiers and top-up packs** instead of at the very bottom.

11. **`determine_price_id` fallback returns a Stripe::Price object from `.find`** -- structurally matches analog, but the unused private methods `determine_product_info`, `get_product_from_price_id`, `determine_lookup_key` are absent (correctly, since no action calls them).

---NEXT DIMENSION---

Now I have all the data. Let me compile the deviations:

---

DEVIATION: [error-handling-on-update-failure in subscription.updated] | ANALOG: [stripe_webhook_handler_job.rb:146-151 calls organization.update() with no return-value check, no failure logging] | OURS: [stripe_webhook_handler_job.rb:136-144 captures return value as `updated`, adds `unless updated` block with `ap` + `Rails.logger.error` failure logging] | SANCTIONED: no

DEVIATION: [raise-on-nil-record in subscription.updated] | ANALOG: [stripe_webhook_handler_job.rb:119 finds organization via find_by with no nil guard — proceeds to call methods on it, letting NoMethodError surface naturally] | OURS: [stripe_webhook_handler_job.rb:130-134 finds purchase via find_by then raises with explicit error string if nil] | SANCTIONED: no

DEVIATION: [nil-handling-inconsistency between subscription.updated and subscription.deleted] | ANALOG: [stripe_webhook_handler_job.rb:188-191 uses safe-navigation `organization&.sync_with_stripe`, `organization&.update_column` consistently throughout subscription.deleted main-plan branch] | OURS: [stripe_webhook_handler_job.rb:134 raises if purchase nil in subscription.updated, but stripe_webhook_handler_job.rb:181 uses `purchase&.update` (silent nil) in subscription.deleted — two different nil-handling strategies for the same record type across two handlers] | SANCTIONED: no

DEVIATION: [no-ap-logging in subscription.updated credit-pack branch] | ANALOG: [stripe_webhook_handler_job.rb:114-115 logs `ap 'SUBSCRIPTION UPDATED VIA WEBHOOK'` and `ap object` before the if/else — shared. But the analog main-plan branch itself has no branch-specific `ap` logging beyond the shared ones] | OURS: [stripe_webhook_handler_job.rb:142 adds `ap "Failed to update OrganizationAiCreditPurchase..."` failure logging that the analog branch does not have — extra logging in error path only] | SANCTIONED: no

DEVIATION: [subscription.deleted credit-pack branch — no failure logging if purchase nil] | ANALOG: [stripe_webhook_handler_job.rb:188-193 main-plan branch calls methods with safe-nav on organization, but organization was found on line 165 — if org is nil, `organization&.sync_with_stripe` silently no-ops, same as other safe-nav calls] | OURS: [stripe_webhook_handler_job.rb:177-181 if purchase is nil (find_by returns nil), `purchase&.update` silently no-ops — a credit-pack subscription deletion for a subscription with no matching purchase record is silently swallowed with no logging] | SANCTIONED: no

DEVIATION: [subscription.deleted credit-pack branch — sets stripe_cancel_at_period_end: false] | ANALOG: [stripe_webhook_handler_job.rb:187-193 main-plan subscription.deleted does NOT explicitly set stripe_cancel_at_period_end — it relies on sync_with_stripe to reconcile] | OURS: [stripe_webhook_handler_job.rb:185 explicitly sets `stripe_cancel_at_period_end: false`] | SANCTIONED: no

DEVIATION: [subscription.deleted credit-pack branch — sets subscription_current_period_end from object.current_period_end] | ANALOG: [stripe_webhook_handler_job.rb:187-193 main-plan subscription.deleted does NOT update stripe_current_period_end_at — it relies on sync_with_stripe. It only sets subscription_canceled_at via update_column] | OURS: [stripe_webhook_handler_job.rb:184 sets `subscription_current_period_end: Time.at(object.current_period_end).to_datetime` — extra field update beyond what the analog does directly] | SANCTIONED: no

WHITELIST: [subscription.deleted credit-pack branch omits sync_with_stripe] — The analog calls `organization&.sync_with_stripe` which syncs the main subscription plan features. The credit-pack branch correctly omits this because sync_with_stripe operates on the org's main subscription (stripe_subscription_id), not on the AI credit subscription. Calling it here would be incorrect — it would try to sync the wrong subscription. This is covered by sanctioned Sub change #3 (no ValidateSubscriptionChange / PlanFeatureGate / sync).

WHITELIST: [subscription.deleted credit-pack branch omits Notification::PaidSubscriptionDeletedJob and EngagementReport::GeneratorJob] — These jobs are main-plan-specific side effects (notification about paid plan cancellation, engagement report for churn). They are not applicable to AI credit subscription cancellation. Adding them would fire incorrect notifications referencing the wrong subscription type.

REVERT: [subscription.updated credit-pack branch error handling] — The `unless updated` block with `ap` + `Rails.logger.error` on lines 141-144 is strictly better error handling than the analog has. However, the analog does NOT do this. For structural faithfulness, it should be removed to match the analog pattern. If better error handling is desired, it should be added to BOTH branches in a separate change. Same applies to the `raise` on line 134 — the analog does not raise on nil org, it lets it fail naturally.
