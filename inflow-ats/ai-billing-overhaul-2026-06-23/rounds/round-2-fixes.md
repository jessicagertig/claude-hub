# Round 2 — Fix Results

### organization_ai_credit_purchase.rb

Good. `paid?` is only used on `BoardWhatJobsListing`, not on `OrganizationAiCreditPurchase`. Safe to remove.

Files changed:
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/models/organization_ai_credit_purchase.rb` (all 12 deviations)
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (method rename callsite)

## Fixed
- [1] charge_default_payment_method renamed to charge_for_listing (analog pattern). Updated caller in organization_ai_credit_purchases_controller.rb line 92
- [2] ap changed to Rails.logger.info for 'Attempt to charge' log line in charge_for_listing
- [3] ap changed to Rails.logger.info for 'Charging...' log line in charge_for_listing
- [4] ap changed to Rails.logger.info for 'Invoice Has Been Finalized' log line; extra `ap [invoice_item, paid_invoice]` replaced with `Rails.logger.info [invoice_item, paid_invoice]` (matches WWR analog which logs both objects via Rails.logger.info)
- [5] Removed `@final_description = @description` unconditional alias. charge_for_listing now uses `@description` directly in the InvoiceItem create call. WWR has the alias because it conditionally appends discount text; AI credit one-off purchases have no discount concept
- [6] Removed `paid?` method. No callers on OrganizationAiCreditPurchase (only BoardWhatJobsListingSerializer calls `paid?` on its own model)
- [7] Removed `broadcast_error_growl` method. No callers on OrganizationAiCreditPurchase. WWR analog has no such method
- [8] Guard message changed from 'Hmm, if trying to charge for an update because of expiration we run into a small issue' to 'Already charged for this AI credit one-off purchase' -- expiration does not apply to AI credit one-off purchases
- [9] Removed commented-out `# auto_advance: false` from Stripe::Invoice.create call
- [10] broadcast_event changed from `action: event` to `event: event` to match WWR analog (`broadcast_show_growl` correctly uses `action: 'showGrowl'` -- that is a different pattern for the growl action, not the event broadcast)
- [11] Removed `rescue StandardError => e` block from grant_one_off_credits. Also changed the `ap` log line inside grant_one_off_credits to `Rails.logger.info`
- [12] is_active? now checks expiry and status for subscriptions: `subscription_current_period_end.present? && subscription_current_period_end > DateTime.now && subscription_status_active?`. For one-off purchases, retains `stripe_invoice_paid?` (one-off purchases have no expiry or status enum -- `stripe_invoice_paid?` is the complete analog of `approved?`)

## Whitelisted
(none)

## Marked for Revert
(none)

---

### organization_ai_credit_purchases_controller.rb

All files are updated. Let me compile the summary of all changes made across each deviation.

## Fixed
- **Deviation #1 (split purchase_top_up into separate actions)**: Split the combined `purchase_top_up` action into `create_top_up` (direct charge when card on file, matching WWR `create` analog) and `create_top_up_checkout_session` (Stripe Checkout redirect when no card on file, matching WWR/WhatJobs `create_checkout_session` analog). Updated routes (`config/routes.rb`), frontend query hooks (`useOrganizationAiCreditPurchase.ts` -- split `usePurchaseAiCreditTopUp` into `useCreateAiCreditTopUp` + `useCreateAiCreditTopUpCheckoutSession`), frontend component `AiCreditSubscription.tsx` (split `purchaseTopUp` into `handleDirectTopUp` + `handleTopUpCheckout`, branching on `stripeDefaultPaymentMethodOnFile` in `handleBuyPack`), and unused component `AccountBillingAiCredits.tsx` (updated to `useCreateAiCreditTopUpCheckoutSession`).
- **Deviation #2 (record-level authorize)**: `create_top_up` now does `authorize @purchase` (record-level, matching WWR `create`'s `authorize @listing`). Added `create_top_up?` method to `OrganizationAiCreditPurchasePolicy` with `is_org_admin?` matching `BoardWwrListingPolicy#create?`. `create_top_up_checkout_session` keeps `authorize :billing, :checkout?` matching both analogs' checkout session actions.
- **Deviation #3 (pre-validates lookup_key)**: Removed the `unless OrganizationAiCreditPurchase.ai_credit_top_up_lookup_key?(lookup_key)` guard from both new actions. Invalid keys are now caught by the model's `validates :stripe_price_lookup_key, inclusion: { in: ... }` and surfaced via `render_errors(@purchase)`, matching how both analogs let model validations handle it.
- **Deviation #4 (stripe_amount: 0 at creation)**: Removed `stripe_amount: 0` from `checkout` and both top-up actions. `stripe_amount` is now set only when the charge completes (via `update_columns` in `charge_default_payment_method` or by the webhook handler), matching the analog where `charge_for_listing` sets it. Updated model validations to gate `stripe_amount` and `currency` on `stripe_invoice_id.present? || (subscription? && stripe_subscription_id.present?)` so records can be saved before being charged, matching the analog pattern where listings save without `stripe_amount` then charge.
- **Deviation #5 (dual rescue -- REVERT)**: `create_top_up` now has single `rescue StandardError => e` (matching WWR `create` analog). `create_top_up_checkout_session` has single `rescue Stripe::StripeError => e` (matching both analogs' `create_checkout_session`).
- **Deviation #6 (organization_id missing from invoice_data.metadata)**: Added `organization_id: @purchase.id` to `invoice_creation.invoice_data.metadata` in `create_top_up_checkout_session`, matching the analog pattern where `invoice_data.metadata` includes both the entity ID and a second entity ID (`job_id` in analogs, `organization_id` here).
- **Deviation #7 (separate @description and @invoice_description -- REVERT)**: Reverted to single `@description` variable in `create_top_up_checkout_session`. Both `product_data.description` and `invoice_data.description` now use `@description`, matching how WhatJobs `create_checkout_session` uses a single `@description` for both.

## Whitelisted
(none)

## Marked for Revert
(none)

### Files changed
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` -- split `purchase_top_up` into `create_top_up` + `create_top_up_checkout_session`; removed `stripe_amount: 0`; removed pre-validation guard; single rescue per action; single `@description`; added `organization_id` to `invoice_data.metadata`
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/policies/organization_ai_credit_purchase_policy.rb` -- added `create_top_up?` method
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/config/routes.rb` -- replaced `post :purchase_top_up` with `post :create_top_up` + `post :create_top_up_checkout_session`
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/models/organization_ai_credit_purchase.rb` -- changed `stripe_amount` and `currency` validations to only require when charged (matching analog pattern)
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` -- split `usePurchaseAiCreditTopUp` into `useCreateAiCreditTopUp` + `useCreateAiCreditTopUpCheckoutSession`
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` -- updated imports and split `purchaseTopUp` into `handleDirectTopUp` + `handleTopUpCheckout`
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingAiCredits.tsx` -- updated import from `usePurchaseAiCreditTopUp` to `useCreateAiCreditTopUpCheckoutSession` (component is unused/orphaned but must compile)

---

### stripe_webhook_handler_job.rb

No references remain. All 18 deviations have been addressed.

## Fixed
- [1] one-off branch extra Rails.logger.info: removed `Rails.logger.info "AI credit one-off purchase #{purchase_id} payment confirmed"` between `finalize_stripe_payment` and `grant_one_off_credits` -- matches WWR analog which has no log line between `finalize_stripe_payment` and `create_on_wwr`
- [2] one-off branch preceding comment: removed the comment `# One-off AI credit top-up invoice -- look up the purchase by metadata ID, finalize payment, then grant credits (mirrors WWR finalize + create_on_wwr).` -- WWR analog has no preceding comment
- [3] one-off branch missing broadcast_event: added `purchase.broadcast_event('ai_credit_top_up_payment_received')` between `finalize_stripe_payment` and `grant_one_off_credits` -- matches WhatJobs analog which has `listing.broadcast_event('what_jobs_listing_payment_received')` between `finalize_stripe_payment` and `create_on_what_jobs`
- [4] subscription invoice.paid extracted to private method: inlined the logic directly in the `invoice.paid` branch -- matches main-plan analog which is 3 lines inline (update, stripe_update_default_payment_method, reset_ai_credits)
- [5] subscription invoice.paid duplicate CustomStripeSubscriptionMissingError guard: removed by inlining -- the guard at line 257 (now) already checks before routing
- [6] subscription invoice.paid duplicate Stripe::Subscription.retrieve: removed by inlining -- reuses `stripe_subscription` already retrieved at line 259 (now)
- [7] subscription invoice.paid updates subscription_status: removed `subscription_status: stripe_subscription.status` from the purchase.update call -- analog does not update subscription status here (subscription.updated webhook handles it)
- [8] subscription invoice.paid per-step error logging on purchase.update failure: removed the `unless updated` block with ap/Rails.logger.error -- analog discards the return value of `organization.update(...)`
- [9] subscription invoice.paid per-step error logging on ApplyAiCreditPurchase.call result: removed the `unless result.success?` block -- analog discards the return value of `organization.organization_ai_credit_balance&.reset_ai_credits`
- [10] subscription invoice.paid no safe navigation before ApplyAiCreditPurchase.call: changed to `ApplyAiCreditPurchase.call(...) if organization.organization_ai_credit_balance` -- matches analog's `organization.organization_ai_credit_balance&.reset_ai_credits` which skips if balance nil
- [11] subscription invoice.paid stripe_update_default_payment_method no-arg: changed to `organization.stripe_update_default_payment_method(stripe_subscription.default_payment_method)` passing the AI credit subscription's PM explicitly -- no-arg resolves the org's main-plan subscription PM via `stripe_payment_method`, which is the wrong subscription
- [12] subscription.updated captures update return value and logs on failure: changed `updated = purchase.update(...)` + `unless updated` block to `purchase&.update(...)` discarding return value -- matches main-plan analog which calls `organization.update(...)` without capturing the return value
- [13] subscription.updated raises explicit error if purchase nil: changed from `raise ... unless purchase` to `purchase&.update(...)` using safe-nav -- matches main-plan analog which uses `organization&.sync_with_stripe` safe-nav pattern
- [14] nil-handling inconsistency: both subscription.updated and subscription.deleted now use `&.` safe-nav consistently -- matches main-plan analog which uses `&.` throughout
- [15] subscription.updated adds failure logging that analog does not have: removed the `unless updated` ap/Rails.logger.error block -- main-plan analog has no per-step failure logging
- [17] subscription.deleted explicitly sets stripe_cancel_at_period_end false: removed `stripe_cancel_at_period_end: false` from the update call -- main-plan analog relies on `sync_with_stripe`, does not explicitly set this field in the deleted handler
- [18] subscription.deleted sets subscription_current_period_end: removed `subscription_current_period_end: Time.at(object.current_period_end).to_datetime` from the update call -- main-plan analog does not update period end directly in the deleted handler

## Whitelisted
(none)

## Marked for Revert
- REVERT: [3] broadcast_event('ai_credit_top_up_payment_received'): the event name is fabricated to match the WhatJobs analog pattern (`what_jobs_listing_payment_received`). `OrganizationAiCreditPurchase#broadcast_event` has a default event of `ai_credit_top_up_purchased`. Confirm whether `ai_credit_top_up_payment_received` is the correct event name or whether the default should be used instead.
- REVERT: [16] subscription.deleted silently swallows nil purchase: this was already matching the analog (`&.` safe-nav, same as main-plan analog). No code change was needed or made. Listing for completeness -- the analog match is correct but the silent swallow means a missing purchase record on cancellation produces no diagnostic output at all.

File modified: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/jobs/stripe_webhook_handler_job.rb`

---

### ai_credit_top_up_purchased_job.rb

## Fixed
- `rescue ActiveRecord::RecordNotFound` missing `=> e`: Added `=> e` to the rescue clause so `ap e` on line 14 references the captured exception instead of an undefined variable. The analog (`paid_wwr_listing_created_job.rb`) has the same bug at line 12-14.

## Whitelisted
(none)

## Marked for Revert
- REVERT: analog bug in `paid_wwr_listing_created_job.rb`: The analog (`Notification::PaidWwrListingCreatedJob`) has the identical bug at line 12 (`rescue ActiveRecord::RecordNotFound` without `=> e`, then `ap e` on line 14). Should be fixed there too.

---

### useOrganizationAiCreditPurchase.ts

## Fixed
- `purchaseAiCreditTopUp` missing `window.logger` call: Added `window.logger("%c[useOrganizationAiCreditPurchase] purchaseAiCreditTopUp\n\n\n\n", "background-color: #FF76D2", { params })` before the `apiPost` call, matching the analog `createBoardWwrListing` pattern (logger in async function body, same background-color style, logs the function's input params).

## Whitelisted
(none)

## Marked for Revert
- REVERT: `purchaseAiCreditTopUp` `window.logger`: The analog's `window.logger` uses a debug background-color style meant for development tracing. This is structurally correct to match, but the `\n\n\n\n` newlines and pink background are cosmetic debug artifacts that could be cleaned up across the codebase later.

---

### apply_ai_credit_purchase.rb

## Fixed
- `Time.current` used inline instead of stored in `now` variable: Added `now = Time.current` at the top of the transaction block (matching analog line 37) and changed `last_reset_at: Time.current` to `last_reset_at: now` (matching analog line 65)
- `context.balance = balance` missing comment: Added `# Expose the refreshed balance to callers (#39).` above the assignment (matching analog line 75)

## Whitelisted
(none)

## Marked for Revert
(none)

---

### AiCreditSubscription.tsx

Only one call site (`OrganizationAiBilling.tsx`), and it is already updated. All changes are complete.

## Fixed
- [1] `Styled.OptionsContainer` uses `t.mt(4)` instead of analog's `t.mt(9)`: Removed local `Styled.OptionsContainer`; now uses shared `PricingOptionsContainer` from `AccountBillingComponents` which has `t.mt(9)`
- [2] `Styled.OptionsContainer` uses flat `max-width: 755px` missing responsive breakpoints: Removed local `Styled.OptionsContainer`; now uses shared `PricingOptionsContainer` which has `max-width: 300px` with `breakpoint.sm` (500px) and `breakpoint.lg` (755px) responsive steps
- [3] `Styled.Options` missing `flex-direction: column` default and `breakpoint.xs` responsive behavior: Removed local `Styled.Options`; now uses shared `PricingOptions` which has `flex-direction: column` default and `flex-direction: row` at `breakpoint.xs`
- [4] Defines `Subtitle`, `OptionsContainer`, `Options` locally instead of importing from `AccountBillingComponents`: Removed all three local styled components; now imports `Subtitle`, `PricingOptionsContainer`, `PricingOptions` from `AccountBillingComponents`
- [5] Wraps content in `Styled.Section` -- analog uses bare React fragment: Removed `Styled.Section` wrapper; now uses bare `<>...</>` fragment matching the analog
- [6] `cancelAtPeriodEnd` banner has no action button -- analog has 'Manage billing' button: Added `<Button styleType="text" onClick={handleCancelClick} disabled={isCanceling}>Manage billing</Button>` to the `cancelAtPeriodEnd` banner
- [7] Active subscription banner (lines 343-355) is custom -- analog shows current plan via PlanCard `isCurrentPlan` badge: Removed the custom `CurrentSubscription` banner for active (non-canceled) subscriptions. `AiSubscriptionTierCard` already renders a "Current plan" badge via `isCurrentPlan` prop (lines 66, 86-87 of `AiSubscriptionTierCard.tsx`), matching how the analog's `PlanCard` handles active subscription display
- [8] `currentOrganization` obtained via `useCurrentSession` hook instead of received as prop like analog: Changed `AiCreditSubscription` signature from `{ pricesData }` to `{ currentOrganization, pricesData }`. Removed `useCurrentSession` import. Updated parent `OrganizationAiBilling.tsx` to call `useCurrentSession()` and pass `currentOrganization` as a prop, matching how `AccountBilling.tsx` passes it to `AccountBillingPlans`

## Whitelisted
(none)

## Marked for Revert
- REVERT: [6] cancelAtPeriodEnd button text "Manage billing": The analog's "Manage billing" button calls `handleCreateBillingPortalSession` which opens the Stripe customer portal. The AI credit subscription page does not have a Stripe customer portal session -- it uses `handleCancelClick` which opens `CancelAiCreditSubscriptionConfirmModal`. The button text "Manage billing" was matched to the analog but the action behind it is cancel-specific (`handleCancelClick`), so the label may be misleading. Consider changing to "Cancel subscription" or adding a real billing portal handler.

Files modified:
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/OrganizationAiBilling.tsx`
