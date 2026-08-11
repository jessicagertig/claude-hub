# Round 4 — Evaluation

Unsanctioned deviation count: 68
Previous round count: 65
Consecutive same count: 0
Stuck: false

## Deviations by file

{
  "organization_ai_credit_purchase.rb": [
    "charge method - logging 'Attempt to charge': ap instead of Rails.logger.info",
    "charge method - already-charged guard log: ap message differs from analog",
    "charge method - 'Charging...' log: ap instead of Rails.logger.info",
    "charge method - 'Invoice Has Been Finalized' log: ap instead of Rails.logger.info and omits second log line with objects",
    "grant_one_off_credits does not call broadcast_show_growl - user gets no toast",
    "broadcast_event called from webhook handler not from model method (inconsistent with WWR)",
    "broadcast_show_growl always targets organization.owner instead of acting-user-with-owner-fallback",
    "broadcast_show_growl never called anywhere (WhatJobs dimension confirms both analogs call it)",
    "broadcast_error_growl method absent entirely (WhatJobs analog has it)",
    "calculate_charge_amount makes Stripe API call instead of local computation (WHITELISTED)",
    "defensive check comment sourced from WWR analog not WhatJobs analog",
    "broadcast_show_growl recipient always org owner - no last_updated_by_organization_user fallback (WhatJobs dimension)",
    "no last_updated_by_organization_user association to track who initiated purchase",
    "grant_one_off_credits rescue logs at info level only vs analog Discord/Slack/error growl (WHITELISTED)"
  ],
  "stripe_webhook_handler_job.rb": [
    "webhook record lookup uses find_by(id:) instead of find - silently swallows missing records",
    "broadcast_event in handler not model method - inconsistent with WWR (WHITELISTED matches WhatJobs)",
    "broadcast_show_growl missing from entire one-off flow - no user toast on purchase complete",
    "Rails.logger.info confirmation line extra vs WWR (WHITELISTED matches WhatJobs)",
    "webhook find pattern find_by vs find (WhatJobs dimension confirms both analogs use find)",
    "invoice.paid missing-record guard does not raise - logs only vs analog raises",
    "invoice.paid missing-record error uses 1 channel vs analog 3 channels",
    "invoice.paid period_start stored - EXTRA field (WHITELISTED model validation forces it)",
    "invoice.paid amount/currency stored - EXTRA fields (WHITELISTED model validations force them)",
    "invoice.paid call-site safe navigation missing - no &. at call site vs analog two-layer defense",
    "subscription.updated missing payment method update in credit-pack branch",
    "subscription.deleted uses update vs analog update_column - callbacks/validations run vs skipped",
    "subscription.deleted stores subscription_status EXTRA field (WHITELISTED compensates for sanctioned omission)",
    "checkout.session.completed uses update_columns vs analog update (WHITELISTED validation would fail)",
    "checkout.session.completed missing Stripe::Customer.update (WHITELISTED customer already exists)",
    "checkout.session.completed missing subscription metadata copy",
    "checkout.session.completed missing begin/rescue error wrapper",
    "metadata access style changed in checkout.session.completed - drops safe-navigation uses .present? instead of == 'true'",
    "handle_subscription_credit_pack_invoice_paid private method deleted logic inlined - structural flattening",
    "invoice.paid subscription writes period start/end in webhook handler vs analog writes inside interactor from different data source",
    "invoice.paid subscription calls stripe_update_default_payment_method WITH subscription payment_method arg vs analog calls without args",
    "invoice.paid error handling downgraded from 3 specific rescue clauses to 1 generic swallowing rescue - no Sidekiq retry",
    "invoice.paid org.update success check removed from main-plan else branch - silent update failures",
    "subscription.deleted credit-pack branch does not clear/update stripe_cancel_at_period_end - stale data"
  ],
  "organization_ai_credit_purchases_controller.rb": [
    "create_top_up has separate Stripe::StripeError rescue vs analog only StandardError (WHITELISTED)",
    "create_top_up_checkout_session stores stripe_checkout_session_id on record - analog does not (WHITELISTED)",
    "checkout session product_data.description repeats name vs analog has separate final_description",
    "invoice_data.metadata has organization_id where analog has job_id (WHITELISTED correct adaptation)",
    "currency set at record build time - analog never stores currency on record (WHITELISTED model validation)",
    "controller create_top_up has no interactor - builds record directly vs analog uses CreateOrUpdate interactor",
    "controller create_top_up has no separate validation step - relies on ActiveRecord vs analog calls ValidateWhatJobsListing",
    "create_top_up_checkout_session stores checkout_session_id after creation (WhatJobs dimension WHITELISTED)",
    "customer_subscription ap log ordering differs - logs before nil check same as analog but with safe navigation",
    "charge.refunded handler exists with no listing analog (WHITELISTED)"
  ],
  "useOrganizationAiCreditPurchase.ts": [
    "useChangeAiCreditSubscriptionViaStripePortal window.logger tag format differs",
    "useUpdateAiCreditSubscriptionWithPaymentMethod window.logger tag format differs"
  ],
  "AiCreditSubscription.tsx": [
    "Missing BillingPeriodToggleWrapper / SlidingToggleSwitch / billingPeriod state (AI credit subscriptions monthly-only)",
    "Missing isOnLegacyPlan CurrentSubscription banner (no legacy AI credit plans exist)",
    "hasActiveSubscription computed internally vs received as prop from parent",
    "Subtitle text conditionally renders 'Change your plan' or 'Choose a credit subscription' vs analog always 'Subscription options'",
    "isLoadingButton on card uses mutation states vs analog uses isFetchingStripeCustomerSubscription",
    "Has cancel flow (CancelAiCreditSubscriptionConfirmModal + handleCancelClick) vs analog uses Stripe portal",
    "Has dedicated top-up section 'One-time top-up packs' with no analog equivalent",
    "Has redirectToStripe helper with no analog equivalent",
    "Has handleCheckoutNewSubscription for new subscription checkout vs analog handles in separate component",
    "Collapses subscribed/unsubscribed into one component vs analog splits into separate components",
    "PlanBillingCallout instead of AiCreditsCallout (cross-linking callouts mirrored)",
    "window.logger in handleCreateBillingPortalSession.onSuccess uses [AiCreditSubscription] vs analog [AccountContainer]"
  ],
  "AiSubscriptionTierCard.tsx": [
    "billingPeriod required in interface but not passed by parent - undefined in trackEvent and window.logger",
    "onCreateBillingPortalSession required in interface but not passed - ManageBillingActions Manage billing button will throw TypeError on click",
    "hasCoupon required in interface but not passed - ManageBillingActions receives undefined",
    "stripePromoCode not passed by parent - ManageBillingActions receives undefined",
    "trackEvent passes billingPeriod which is undefined because parent does not pass it",
    "trackEvent has extra selected_tier_credits and replaces selected_plan_key with selected_tier_lookup_key - different property keys"
  ]
}
