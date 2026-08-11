# Round 2 — Evaluation

Unsanctioned deviation count: 49
Previous round count: 68
Consecutive same count: 0
Stuck: false

## Deviations by file

```json
{
  "organization_ai_credit_purchase.rb": [
    "charge method named charge_default_payment_method instead of charge_for_listing (analog pattern)",
    "ap used instead of Rails.logger.info for 'Attempt to charge' log line",
    "ap used instead of Rails.logger.info for 'Charging...' log line",
    "ap used instead of Rails.logger.info for 'Invoice Has Been Finalized' log line, plus extra ap [invoice_item, paid_invoice] object logging",
    "@final_description = @description unconditional alias is dead scaffolding from WWR discount pattern — REVERT: remove and use @description directly",
    "extra paid? method that aliases stripe_invoice_paid? — analog has no paid? method",
    "broadcast_error_growl method exists but WWR analog has none (copied from WhatJobs analog)",
    "charge method guard ap message 'Hmm, if trying to charge for an update because of expiration...' references expiration which does not apply — REVERT to appropriate message",
    "commented-out # auto_advance: false in Stripe::Invoice.create — vestigial from WWR — REVERT: remove comment",
    "broadcast_event uses action: key instead of event: key (analog uses event:)",
    "grant_one_off_credits has rescue StandardError => e block — WhatJobs create_on_what_jobs has no rescue",
    "is_active? returns only stripe_invoice_paid? without expiry/status checks that both analogs have"
  ],
  "organization_ai_credit_purchases_controller.rb": [
    "purchase_top_up combines create/direct-charge and create_checkout_session into single action with if/else branching (both analogs have separate actions)",
    "authorize :billing, :checkout? (policy-class-level) instead of authorize @listing (record-level)",
    "pre-validates lookup_key via ai_credit_top_up_lookup_key? before building record — analog builds then validates via model",
    "stripe_amount: 0 set at record creation time — analog does not set stripe_amount until charge",
    "dual rescue (Stripe::StripeError + StandardError) instead of single rescue per action — REVERT",
    "invoice_creation.invoice_data.metadata missing organization_id — analog includes a second entity ID (job_id)",
    "separate @description and @invoice_description variables — unnecessary separation — REVERT: use single @description like analog"
  ],
  "stripe_webhook_handler_job.rb": [
    "one-off branch: extra Rails.logger.info between finalize_stripe_payment and grant_one_off_credits (not in WWR analog)",
    "one-off branch: preceding comment not present in WWR analog",
    "one-off branch: missing intermediate broadcast_event between finalize_stripe_payment and grant_one_off_credits (WhatJobs analog has one)",
    "subscription invoice.paid: extracted to private method handle_subscription_credit_pack_invoice_paid instead of inline (analog is 3 lines inline)",
    "subscription invoice.paid: duplicate CustomStripeSubscriptionMissingError guard inside private method — already checked before routing",
    "subscription invoice.paid: duplicate Stripe::Subscription.retrieve call — already retrieved at line 273, not passed as parameter",
    "subscription invoice.paid: updates subscription_status — analog does not (subscription.updated webhook handles it), causing double-update per cycle",
    "subscription invoice.paid: per-step error logging on purchase.update failure — analog discards return value",
    "subscription invoice.paid: per-step error logging on ApplyAiCreditPurchase.call result — analog discards return value",
    "subscription invoice.paid: no safe navigation before ApplyAiCreditPurchase.call — analog uses &. to skip if balance nil",
    "subscription invoice.paid: stripe_update_default_payment_method no-arg resolves org's main-plan subscription PM instead of AI credit subscription PM",
    "subscription.updated credit-pack branch: captures update return value and logs on failure — analog does not check return value",
    "subscription.updated credit-pack branch: raises explicit error if purchase nil — analog lets NoMethodError surface naturally",
    "nil-handling inconsistency: subscription.updated raises if purchase nil, subscription.deleted uses &. safe-nav — two different strategies for same record type",
    "subscription.updated credit-pack branch: adds ap failure logging that analog branch does not have",
    "subscription.deleted credit-pack branch: silently swallows nil purchase with no logging",
    "subscription.deleted credit-pack branch: explicitly sets stripe_cancel_at_period_end: false — analog relies on sync_with_stripe",
    "subscription.deleted credit-pack branch: sets subscription_current_period_end from object.current_period_end — analog does not update period end directly"
  ],
  "ai_credit_top_up_purchased_job.rb": [
    "rescue ActiveRecord::RecordNotFound block references undefined variable e (ap e without => e) — bug copied from analog"
  ],
  "useOrganizationAiCreditPurchase.ts": [
    "purchaseAiCreditTopUp has no window.logger call — analog createBoardWwrListing has one — REVERT"
  ],
  "apply_ai_credit_purchase.rb": [
    "Time.current used inline instead of stored in now variable like analog reset_ai_credits.rb",
    "context.balance = balance has no comment — analog has '# Expose the refreshed balance to callers (#39).'"
  ],
  "AiCreditSubscription.tsx": [
    "Styled.OptionsContainer uses t.mt(4) instead of analog's t.mt(9)",
    "Styled.OptionsContainer uses flat max-width: 755px — missing responsive breakpoints from analog",
    "Styled.Options missing flex-direction: column default and breakpoint.xs responsive behavior from analog",
    "Defines Subtitle, OptionsContainer, Options locally instead of importing shared components from AccountBillingComponents",
    "Wraps content in Styled.Section — analog uses bare React fragment",
    "cancelAtPeriodEnd banner has no action button — analog has 'Manage billing' button",
    "Active subscription banner (lines 343-355) is custom — analog shows current plan via PlanCard isCurrentPlan badge",
    "currentOrganization obtained via useCurrentSession hook instead of received as prop like analog"
  ]
}
```
