# Round 1 — Evaluation

Unsanctioned deviation count: 68
Previous round count: -1
Consecutive same count: 0
Stuck: false

## Deviations by file

{
  "organization_ai_credit_purchase.rb": [
    "Extra Stripe::Price.list call in charge_default_payment_method (no analog does Price lookup in model charge method)",
    "InvoiceItem uses price: price.id instead of amount:+currency:+description: (both WWR and WhatJobs analogs use amount/currency/description)",
    "Invoice.create missing description: field (both analogs include description)",
    "Invoice.create has explicit auto_advance: true (both analogs omit it or comment it out)",
    "update_columns stamps paid_invoice.amount_paid from Stripe response instead of pre-calculated amount (both analogs use locally computed amount)",
    "update_columns stamps currency from Stripe response (neither analog stamps currency)",
    "InvoiceItem metadata expanded with 4 keys instead of 1 (both analogs use single ID key)",
    "Invoice metadata expanded with 4 keys instead of 1 (both analogs use single ID key)",
    "No logging statements in charge_default_payment_method (WWR has 4 Rails.logger.info, WhatJobs has 4 ap statements)",
    "Double-charge guard checks only stripe_invoice_id.present? without second condition (WWR checks && is_active?, WhatJobs checks && live?)",
    "No paid? convenience method (WhatJobs analog has def paid? returning stripe_invoice_paid?)"
  ],
  "organization_ai_credit_purchases_controller.rb": [
    "Stripe::Price.list called twice for payment-on-file path (once in controller line 77, again in model charge method line 132)",
    "Combined direct-charge + checkout-session in one purchase_top_up action (both analogs use separate actions: create vs create_checkout_session)",
    "Direct-charge response renders bare { charged: true } instead of serialized record (both analogs render_one with serializer)",
    "Checkout response uses redirectUrl key instead of url+sessionId, no status: :created (both analogs use url+sessionId with :created)",
    "Rescues only Stripe::StripeError instead of also rescuing StandardError (WWR rescues StandardError, WhatJobs rescues both)",
    "Sentry.capture_exception added in error handler (neither analog calls Sentry)",
    "Error message hides Stripe error details behind generic text instead of surfacing e.message (both analogs include e.message)",
    "payment_method_types: ['card'] explicitly set on checkout session (neither analog sets payment_method_types)",
    "line_items uses price: price.id reference instead of price_data: with inline unit_amount and product_data (both analogs use price_data)",
    "No payment_intent_data metadata on checkout session (both analogs include payment_intent_data with metadata)",
    "invoice_creation.invoice_data missing description field (both analogs include description in invoice_data)",
    "success/cancel URLs lack {CHECKOUT_SESSION_ID} template variable (WWR analog includes session_id={CHECKOUT_SESSION_ID})",
    "Checkout error uses render_general_errors instead of render json: { error: e.message }, status: :unprocessable_entity (both analogs use json error format)",
    "No interactor-based validation before charging (WhatJobs analog calls ValidateWhatJobsListing.call)",
    "Record created via OrganizationAiCreditPurchase.new.save directly instead of through creation interactor (WhatJobs analog uses CreateOrUpdateWhatJobsListingWithIntegration.call)",
    "PosthogTrackJob event name 'change_subscription_stripe_portal_opened' not differentiated with ai_credit_ prefix"
  ],
  "stripe_webhook_handler_job.rb": [
    "invoice.paid AI credit one-off branch makes extra Stripe::Checkout::Session.list API call to resolve checkout_session_id (both analogs find record by metadata ID directly)",
    "invoice.paid AI credit one-off branch has no ap/Rails.logger logging (both analog branches have logging)",
    "invoice.paid AI credit metadata routing uses value equality ('true') instead of presence check (.present?) used by both analogs",
    "invoice.paid AI credit one-off branch placed BEFORE WWR/WhatJobs branches in guard ordering",
    "invoice.paid AI credit branch record lookup uses cascading find_by with 3 fallback keys returning nil (both analogs use direct find raising on miss)",
    "invoice.paid AI credit branch has no broadcast/notification (WhatJobs analog calls broadcast_event)",
    "Missing stripe_update_default_payment_method call in AI credit subscription renewal path (main-plan analog calls it after persisting period end)",
    "No subscription-missing guard raising exception in subscription renewal path (main-plan analog raises CustomStripeSubscriptionMissingError)",
    "handle_subscription_credit_pack_invoice_paid does not check update return value (main-plan analog checks updated = organization.update and logs on failure)",
    "ApplyAiCreditPurchase.call interactor result not checked by webhook handler (errors from context.fail! do not propagate to rescue blocks)",
    "Duplicate purchase lookup: handle_subscription_credit_pack_invoice_paid finds purchase, then ApplyAiCreditPurchase finds same purchase again",
    "Duplicate organization lookup: webhook handler finds org at line 209, then ApplyAiCreditPurchase looks up org again via invoice.customer",
    "No credit-pack branch in customer.subscription.deleted handler (all side effects fire unconditionally for any subscription deletion)",
    "subscription_canceled_at unconditionally set on org when credit-pack subscription is deleted (incorrectly records main-plan cancellation timestamp)",
    "PaidSubscriptionDeletedJob fires unconditionally for credit-pack subscription deletion (sends misleading notification)",
    "EngagementReport::GeneratorJob fires unconditionally for credit-pack subscription deletion with trigger subscription_canceled",
    "No purchase record status update on credit-pack subscription deletion (subscription_status remains active after Stripe deletes it)",
    "handle_subscription_credit_pack_invoice_paid updates stripe_amount/currency/stripe_invoice_item_id separately from ApplyAiCreditPurchase updating same purchase record (two separate updates split across two call sites)",
    "credit-pack branch in subscription.updated uses inline unless-updated + else-branch logging instead of analog rescue pattern with ap + Rails.logger.error"
  ],
  "apply_ai_credit_purchase.rb": [
    "ApplyAiCreditPurchase interactor has no analog (WhatJobs webhook handler logic is inline, not in a separate interactor)",
    "Period source reads invoice.lines.data.first.period instead of retrieving live Stripe::Subscription and reading current_period_end",
    "No addon_subscription bucket zero-out before renewal grant (ResetAiCredits analog zeros remaining balance with plan_monthly_reset_debit ledger row before granting new allocation)",
    "Notification flag clearing resets only 2 fields (sent_low/zero_notification_since_increase) instead of analog's 5 fields (also low/zero_credit_notification_sent_at and last_reset_at)",
    "Uses update_columns to clear notification flags (skips validations/callbacks) instead of update used by analog ResetAiCredits",
    "No transaction wrapping around update + finalize_stripe_payment + ledger save + notification clear (analog ResetAiCredits wraps in ApplicationRecord.transaction)",
    "Extra finalize_stripe_payment call setting stripe_invoice_paid via update_columns (main-plan analog has no such method, payment finalization is implicit)",
    "Ledger description hardcodes 'Credit pack subscription first invoice' for all renewals (analog ResetAiCredits uses dynamic description per organization plan)",
    "Error handling uses context.fail! which does not propagate as exceptions (analog uses raise which propagates to rescue StandardError with full logging)"
  ],
  "AiCreditSubscription.tsx": [
    "subscribe mutate function from useCheckoutAiCreditPack destructured but never called (dead code)",
    "isLoadingBalance destructured from useOrganizationAiCreditBalance but never used (dead code)",
    "isLoadingSubscription destructured from subscription query but never used (dead code)",
    "Missing render-level window.logger diagnostic calls (analog AccountBillingPlans has diagnostic logging with full state dump)"
  ],
  "AiSubscriptionTierCard.tsx": [
    "No new-subscription vs change-subscription branching in click handler (analog PlanCard branches on hasActiveSubscription; non-subscribed users will hit raise StandardError 'Subscription item ID is missing')",
    "hasActiveSubscription prop accepted in interface and destructured but never used in component body or JSX (dead prop)",
    "Missing loading prop on tier card button (analog PlanCard passes loading={isLoadingButton} for spinner; AI credit button has only disabled)",
    "Missing trackEvent call on tier selection (analog PlanCard calls trackEvent with plan_selected and plan details)"
  ]
}
