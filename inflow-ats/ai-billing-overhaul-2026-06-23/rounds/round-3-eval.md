# Round 3 — Evaluation

Unsanctioned deviation count: 65
Previous round count: 49
Consecutive same count: 0
Stuck: false

## Deviations by file

{
  "organization_ai_credit_purchase.rb": [
    "model charge_for_listing is dead code — defined at line 185 but never called from any controller, webhook, or callback",
    "model method naming: charge_for_listing — misleading name, this is not a listing",
    "model calculate_charge_amount makes Stripe API call instead of local calculation (analog computes locally)",
    "model grant_one_off_credits missing rescue StandardError block",
    "model charge_for_listing missing comment '# defensive check...'",
    "model charge_for_listing logging style uses Rails.logger.info instead of ap for 'Attempt to charge'",
    "model charge_for_listing logging style uses Rails.logger.info instead of ap for 'Charging...'",
    "model charge_for_listing logging style uses Rails.logger.info instead of ap for 'Invoice Has Been Finalized'",
    "model charge_for_listing extra log line — adds Rails.logger.info [invoice_item, paid_invoice] not in WhatJobs analog",
    "model charge_for_listing guard condition uses is_active? with different semantics than analog's live? (WHITELIST)",
    "model charge_for_listing guard message uses different text than analog",
    "model missing paid? convenience method (analog has def paid?; stripe_invoice_paid?; end)",
    "model missing broadcast_error_growl method (WHITELIST — no callsite exists)",
    "model grant_one_off_credits double-broadcast — calls broadcast_event AND broadcast_show_growl inside method, plus webhook also calls broadcast_event",
    "model grant_one_off_credits fires notification job (WHITELIST — follows WWR pattern)",
    "model grant_one_off_credits notification-resets — resets low/zero credit notification flags (WHITELIST — AI credit specific)",
    "model extra method: stripe_subscription (WHITELIST — supports subscription management flow)",
    "model extra class methods for lookup keys: ai_credit_lookup_keys, ai_credit_subscription_plan_lookup_key?, ai_credit_top_up_lookup_key?, ai_credit_allocation_for_lookup_key (WHITELIST)",
    "model extra constant AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY (WHITELIST — multi-product pricing)",
    "model extra validations on stripe_price_lookup_key, kind, stripe_subscription_id, etc. (WHITELIST — complex lifecycle)",
    "model extra enum: kind { one_off: 0, subscription: 1 } (WHITELIST — architectural routing)",
    "model extra enum: subscription_status with Stripe statuses (WHITELIST — subscription infrastructure)",
    "model extra association: has_many :ai_credit_balance_transactions (WHITELIST — ledger)",
    "model is_active? method semantics differ from analog's live? (WHITELIST — different domain)",
    "model missing before_create/after_update callbacks (WHITELIST — no external API sync needed)"
  ],
  "organization_ai_credit_purchases_controller.rb": [
    "create_top_up calls nonexistent method charge_default_payment_method (model defines charge_for_listing) — WWR analog comparison",
    "create_top_up calls nonexistent method charge_default_payment_method — WhatJobs analog comparison",
    "create_top_up authorize pattern uses authorize @purchase (record-based) instead of authorize :billing, :checkout? (headless policy)",
    "create_top_up missing interactor for record creation — creates record directly with .new instead of using interactor (WHITELIST — simple creation)",
    "create_top_up missing Stripe::StripeError rescue — only rescues StandardError",
    "create_top_up_checkout_session stores checkout_session_id on purchase — analog does not save session ID back (WHITELIST — needed for refund handling)",
    "create_top_up_checkout_session uses update instead of update_columns for Stripe field",
    "create_top_up_checkout_session product_data.name format results in redundant text",
    "create_top_up_checkout_session saves record before session creation then updates with session ID — extra DB write not in analog (WHITELIST — same as checkout_session_id storage)",
    "create_top_up_checkout_session saves stripe_checkout_session_id on record — WhatJobs analog comparison (WHITELIST — needed for refund handling)",
    "determine_price_id retains dead commented-out code from analog: nickname.include? 'Per'"
  ],
  "stripe_webhook_handler_job.rb": [
    "webhook handler calls broadcast_event in webhook body AND inside grant_one_off_credits — double broadcast (WWR analog)",
    "webhook handler has extra Rails.logger.info between finalize and action (WWR analog)",
    "webhook handler missing log line between finalize and broadcast (WhatJobs analog)",
    "webhook handler double broadcast — 2 broadcast_event calls + 1 broadcast_show_growl for single payment (WhatJobs analog)",
    "invoice.paid guard at line 257 blocks AI credit-only orgs — raises CustomStripeSubscriptionMissingError if org has no main-plan subscription",
    "invoice.paid purchase lookup uses explicit raise on missing purchase vs analog's implicit failure",
    "invoice.paid credit application has double nil-guard on balance (if guard + interactor context.fail!)",
    "invoice.paid pending migration 20260611120002 will rename amount_cents_paid to stripe_amount, breaking line 270",
    "customer.subscription.updated sync_with_stripe order swapped — now runs before stripe_update_default_payment_method in main-plan branch",
    "customer.subscription.updated sync_with_stripe omitted from credit-pack branch (WHITELIST — filters out credit subscriptions anyway)",
    "customer.subscription.deleted subscription_status hardcoded to :canceled instead of using object.status",
    "customer.subscription.deleted PaidSubscriptionDeletedJob not fired for credit-pack (WHITELIST — job is main-plan specific)",
    "customer.subscription.deleted EngagementReport::GeneratorJob not fired for credit-pack (WHITELIST — job is main-plan specific)",
    "customer.subscription.deleted sync_with_stripe not called for credit-pack (WHITELIST — filters out credit subscriptions)"
  ],
  "ai_credit_top_up_purchased_job.rb": [
    "notification job finds record via global OrganizationAiCreditPurchase.find(purchase_id) instead of scoping through organization association"
  ],
  "organization_ai_credit_purchase_serializer.rb": [
    "stripe_invoice_paid not exposed in serializer (analog exposes paid via object.paid?)"
  ],
  "organization_ai_credit_purchase_policy.rb": [
    "policy pattern mismatch — create_top_up uses OrganizationAiCreditPurchasePolicy#create_top_up? instead of BillingPolicy#checkout?"
  ],
  "AiCreditSubscription.tsx": [
    "No billing period toggle — analog has monthly/yearly SlidingToggleSwitch",
    "No trialing state banner — analog shows trial info with end date",
    "No legacy plan banner — analog handles legacy plans with type-specific messaging",
    "cancelAtPeriodEnd banner calls handleCancelClick instead of handleCreateBillingPortalSession — shows cancel modal instead of Stripe portal for reactivation",
    "EXTRA isCanceledButStillActive banner with no analog equivalent",
    "Missing handleCreateBillingPortalSession — no Stripe portal access from AI credit subscription page",
    "No AiCreditsCallout equivalent cross-link back to main billing"
  ],
  "AiSubscriptionTierCard.tsx": [
    "Current plan card shows static tag instead of ManageBillingActions — no manage billing or promo code actions",
    "No promo code support — hasCoupon/stripePromoCode props absent",
    "onCreateNewSubscription callback takes tier argument — analog takes no arguments",
    "No billingPeriod prop — correlates with missing billing period toggle",
    "No currentPlanBillingPeriod prop — correlates with missing billing period toggle"
  ]
}
