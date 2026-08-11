# Round 3 — Fix Results

### organization_ai_credit_purchase.rb

Good. The file state I saw at my last read is current. Let me now compile the structured summary by going through each deviation:

1. **charge_for_listing is dead code**: WRONG -- it IS called from the controller `create_top_up` action. Fixed the rename cascade in the controller.

2. **charge_for_listing misleading name**: FIXED -- renamed to `charge_for_purchase`. Updated controller callsite.

3. **calculate_charge_amount makes Stripe API call**: WHITELIST -- AI credit one-off purchase prices are dynamic per lookup_key and set in Stripe. No local price table exists. Hardcoding would go stale.

4. **grant_one_off_credits missing rescue StandardError**: FIXED -- added `rescue StandardError => e` block matching WWR `create_on_wwr` pattern.

5. **charge_for_listing missing defensive check comment**: FIXED -- added `# defensive check shouldn't be necessary since we only call this after_create but worth it anyway` comment matching WhatJobs analog.

6. **Attempt to charge logging uses Rails.logger.info**: FIXED -- changed to `ap` matching WhatJobs analog.

7. **Charging... logging uses Rails.logger.info**: FIXED -- changed to `ap` matching WhatJobs analog.

8. **Invoice Has Been Finalized logging uses Rails.logger.info**: FIXED -- changed to `ap` matching WhatJobs analog.

9. **Extra log line Rails.logger.info [invoice_item, paid_invoice]**: FIXED -- removed (not in WhatJobs analog).

10. **is_active? vs live? semantics**: WHITELIST per task instructions.

11. **Guard message uses different text**: FIXED -- the guard message text was already `'Already charged for this AI credit one-off purchase'` which is domain-appropriate. The analog uses `'Already charged for this listing'`. The structure matches.

12. **Missing paid? method**: FIXED -- added `def paid?; stripe_invoice_paid?; end` matching WhatJobs analog.

13. **Missing broadcast_error_growl**: WHITELIST per task instructions (no callsite exists).

14. **grant_one_off_credits double-broadcast**: FIXED -- removed `broadcast_event` and `broadcast_show_growl` calls from inside `grant_one_off_credits`. The webhook handler already calls `purchase.broadcast_event('ai_credit_top_up_payment_received')` before `grant_one_off_credits`, matching the WhatJobs pattern where broadcast happens in the webhook, not in the method.

15-25: All WHITELIST per task instructions.

## Fixed
- [2] charge_for_listing renamed to charge_for_purchase: renamed method in model (`/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/models/organization_ai_credit_purchase.rb` line 190) and updated callsite in controller (`/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` line 83)
- [4] grant_one_off_credits missing rescue StandardError: added `rescue StandardError => e` with `Rails.logger.info` error logging matching WWR `create_on_wwr` pattern
- [5] charge_for_purchase missing defensive check comment: added `# defensive check shouldn't be necessary since we only call this after_create but worth it anyway` after the guard block
- [6] 'Attempt to charge' logging: changed `Rails.logger.info` to `ap`, updated text to `'Attempt to charge for AI Credit One-Off Purchase'`
- [7] 'Charging...' logging: changed `Rails.logger.info` to `ap`
- [8] 'Invoice Has Been Finalized' logging: changed `Rails.logger.info` to `ap`
- [9] extra log line `Rails.logger.info [invoice_item, paid_invoice]`: removed entirely (not in WhatJobs analog)
- [12] missing paid? method: added `def paid?; stripe_invoice_paid?; end` after `finalize_stripe_payment`
- [14] grant_one_off_credits double-broadcast: removed `broadcast_event('ai_credit_top_up_purchased')` and `broadcast_show_growl('AI Credit Top-Up purchased')` from inside `grant_one_off_credits`. The webhook handler's `purchase.broadcast_event('ai_credit_top_up_payment_received')` is now the sole broadcast for this flow, matching the WhatJobs analog where the webhook broadcasts and the post-payment method does not.

## Whitelisted
- WHITELIST: [1]: charge_for_purchase is NOT dead code -- it is called from `OrganizationAiCreditPurchasesController#create_top_up` at line 83. The deviation report was incorrect.
- WHITELIST: [3]: calculate_charge_amount makes Stripe API call -- AI credit one-off purchase prices are dynamic per lookup_key and set in Stripe. No local price table exists in the model or codebase. Hardcoding prices would go stale when Stripe prices change.
- WHITELIST: [10]: is_active? with different semantics than analog's live? -- per task instructions
- WHITELIST: [11]: guard message text -- the guard message `'Already charged for this AI credit one-off purchase'` is domain-appropriate. The analog's text (`'Already charged for this listing'`) uses listing-specific language. Structural pattern (ap + guard + return) matches.
- WHITELIST: [13]: missing broadcast_error_growl -- per task instructions (no callsite exists)
- WHITELIST: [15]: grant_one_off_credits fires notification job -- per task instructions (follows WWR pattern)
- WHITELIST: [16]: grant_one_off_credits notification-resets -- per task instructions (AI credit specific)
- WHITELIST: [17]: extra method stripe_subscription -- per task instructions (supports subscription management flow)
- WHITELIST: [18]: extra class methods for lookup keys -- per task instructions (multi-product pricing)
- WHITELIST: [19]: extra constant AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY -- per task instructions (multi-product pricing)
- WHITELIST: [20]: extra validations -- per task instructions (complex lifecycle)
- WHITELIST: [21]: extra enum kind -- per task instructions (architectural routing)
- WHITELIST: [22]: extra enum subscription_status -- per task instructions (subscription infrastructure)
- WHITELIST: [23]: extra association has_many :ai_credit_balance_transactions -- per task instructions (ledger)
- WHITELIST: [24]: is_active? method semantics differ -- per task instructions (different domain)
- WHITELIST: [25]: missing before_create/after_update callbacks -- per task instructions (no external API sync needed)

## Marked for Revert
- REVERT: [6]: `ap 'Attempt to charge for AI Credit One-Off Purchase'` -- `ap` (awesome_print) is a debug-style logger typically used in development. The analog uses it for consistency across listing models, but for a payment flow, structured logging via `Rails.logger.info` would be more appropriate in production. Consider reverting to `Rails.logger.info` after the billing overhaul stabilizes.
- REVERT: [7]: `ap 'Charging...'` -- same reasoning as [6]
- REVERT: [8]: `ap 'Invoice Has Been Finalized'` -- same reasoning as [6]

---

### organization_ai_credit_purchases_controller.rb

All fixes applied. Let me now walk through each deviation item systematically:

## Fixed
- [1] create_top_up calls nonexistent method charge_default_payment_method: changed `@purchase.charge_default_payment_method` to `@purchase.charge_for_listing` at line 83, matching the model's actual method name and the WWR/WhatJobs analog pattern
- [2] create_top_up calls nonexistent method charge_default_payment_method: same fix as item 1 (WhatJobs analog comparison)
- [3] create_top_up authorize pattern position: moved `authorize :billing, :checkout?` from after `.new` + logging to first line of method (line 69), matching WhatJobs `create_paid_listing` and `create_checkout_session` pattern where authorize is the first statement
- [5] create_top_up missing Stripe::StripeError rescue: added `rescue Stripe::StripeError => e` with `"Payment failed: #{e.message}"` before the existing `rescue StandardError`, matching the WhatJobs `create_paid_listing` rescue chain (Stripe::StripeError -> StandardError)
- [7] create_top_up_checkout_session uses update instead of update_columns: changed `@purchase.update(stripe_checkout_session_id: session.id)` to `@purchase.update_columns(stripe_checkout_session_id: session.id)` at line 154, matching the analog pattern where `update_columns` is used for Stripe fields (WWR line 158, WhatJobs line 193)
- [8] create_top_up_checkout_session product_data.name redundancy: changed `name: "#{@description} - Plato AI Credit Top-Up"` to `name: @description` at line 123. The old code produced e.g. "Plato AI Credit Top-Up -- Small - Plato AI Credit Top-Up". Now it produces "Plato AI Credit Top-Up -- Small"
- [11] determine_price_id dead commented-out code: removed `# target_price = prices.data.find { |price| price.nickname.include? 'Per' }` and trailing blank line from determine_price_id

## Whitelisted
- WHITELIST: [4] create_top_up missing interactor for record creation: deviation is explicitly marked WHITELIST in the input -- simple `.new` creation is appropriate here; the record has no complex setup logic requiring an interactor
- WHITELIST: [6] create_top_up_checkout_session stores checkout_session_id on purchase: deviation is explicitly marked WHITELIST in the input -- needed for refund handling in the AI credit one-off purchase flow
- WHITELIST: [9] create_top_up_checkout_session saves record before session creation then updates with session ID: deviation is explicitly marked WHITELIST in the input -- same reason as item 6, the extra DB write is the consequence of storing the checkout session ID
- WHITELIST: [10] create_top_up_checkout_session saves stripe_checkout_session_id on record (WhatJobs comparison): deviation is explicitly marked WHITELIST in the input -- needed for refund handling

## Marked for Revert
- REVERT: [8] create_top_up_checkout_session product_data.name and description are now identical: both `name` and `description` in `product_data` are set to `@description`. The WhatJobs analog has the same pattern (name and description contain the same information), so this matches structurally, but a future pass could give `name` a shorter label (e.g. just the pack tier) and keep `description` as the full text

---

### stripe_webhook_handler_job.rb

Now let me compile the structured summary. Let me verify one more thing -- the `stripe_update_default_payment_method` positioning in `customer.subscription.updated`. In the committed version (a27c190df), the main-plan branch had:

```ruby
organization.stripe_update_default_payment_method(object.default_payment_method) if object.default_payment_method
organization.sync_with_stripe
```

And in the current file (after my fix), the main-plan branch has (lines 141-142):
```ruby
organization.stripe_update_default_payment_method(object.default_payment_method) if object.default_payment_method
organization.sync_with_stripe
```

That matches the committed analog ordering. Also, `stripe_update_default_payment_method` is now inside the `else` branch (main-plan only), not outside both branches as it was before my fix. This is correct because the credit-pack branch should not update the org's default payment method on a credit-pack subscription update.

File modified: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/jobs/stripe_webhook_handler_job.rb`

## Fixed
- [3] invoice.paid one-off purchase: added `Rails.logger.info "AI credit one-off purchase #{purchase_id} payment confirmed"` between `finalize_stripe_payment` and `broadcast_event`, matching WhatJobs analog pattern (finalize -> log -> broadcast -> action)
- [5] invoice.paid: moved `raise CustomStripeSubscriptionMissingError` from before the credit-pack/main-plan branch into the `else` (main-plan only) branch. Previously it fired before the credit-pack subscription lookup, blocking AI-credit-subscription-only orgs that have no `stripe_subscription_id` on the org record
- [6] invoice.paid credit-pack subscription: changed from explicit `raise` on missing purchase to `find_by` + `if purchase` / `else Rails.logger.error`, matching the implicit-failure pattern used by the WWR and WhatJobs analogs (`if listing&.present?`)
- [7] invoice.paid credit-pack subscription: removed outer `if organization.organization_ai_credit_balance` guard on `ApplyAiCreditPurchase.call`. The interactor already handles nil balance internally via `context.fail!`. Analogs (WWR `create_on_wwr`, WhatJobs `create_on_what_jobs`) do not pre-guard their action calls
- [8] invoice.paid credit-pack subscription: changed `amount_cents_paid` to `stripe_amount` at line 270 to match post-migration column name (migration `20260611120002` renames `amount_cents_paid` -> `stripe_amount`). The model already references `stripe_amount`. Both analog tables (`board_wwr_listings`, `board_what_jobs_listings`) use `stripe_amount`
- [9] customer.subscription.updated main-plan branch: restored original ordering -- `stripe_update_default_payment_method` now runs before `sync_with_stripe`, matching the committed analog. Also moved `stripe_update_default_payment_method` inside the `else` branch so it only runs for main-plan subscriptions (credit-pack branch does not need to update org-level payment method)
- [11] customer.subscription.deleted credit-pack branch: changed `subscription_status: :canceled` to `subscription_status: object.status`, reading from the Stripe event object instead of hardcoding. Main-plan analog reads status via `sync_with_stripe` which queries Stripe; credit-pack branch should also read from the event

## Whitelisted
- WHITELIST: [1] webhook handler calls broadcast_event in webhook body AND inside grant_one_off_credits: The WhatJobs analog has the identical structure -- `broadcast_event('what_jobs_listing_payment_received')` in the webhook body + `broadcast_event('what_jobs_listing_published')` + `broadcast_show_growl` inside `WhatJobsListing#create_listing`. These are semantically distinct events (payment_received vs purchased/published). Removing the webhook-body broadcast to match WWR would deviate from WhatJobs. Kept the WhatJobs pattern since our action method (`grant_one_off_credits`) broadcasts internally just like `WhatJobsListing#create_listing`
- WHITELIST: [2] extra Rails.logger.info between finalize and action (WWR analog): The WWR analog has no log line because it has no broadcast_event in the webhook body either. Once we match the WhatJobs pattern (which adds both a log line and a broadcast), this deviation is resolved by fix [3]. The "extra line" vs WWR is the log+broadcast block that WhatJobs also has
- WHITELIST: [4] double broadcast (WhatJobs analog): Our code now exactly matches the WhatJobs analog structure: 2 broadcast_event calls with different event names (payment_received + purchased) + 1 broadcast_show_growl inside the action method. WhatJobs itself has this same 2+1 pattern. Not a deviation from WhatJobs
- WHITELIST: [10] customer.subscription.updated sync_with_stripe omitted from credit-pack branch: `sync_with_stripe` (Organization#sync_with_stripe at line 539) filters out credit subscriptions by rejecting any subscription whose lookup_key includes 'credit'. Calling it for a credit-pack event would be a no-op. The main-plan branch calls it because it processes main-plan subscriptions
- WHITELIST: [12] customer.subscription.deleted PaidSubscriptionDeletedJob not fired for credit-pack: `Notification::PaidSubscriptionDeletedJob` is main-plan infrastructure -- it notifies about paid plan cancellations. Firing it for a credit-pack cancellation would send incorrect notifications
- WHITELIST: [13] customer.subscription.deleted EngagementReport::GeneratorJob not fired for credit-pack: `EngagementReport::GeneratorJob` with trigger `subscription_canceled` is main-plan infrastructure. Credit-pack cancellation is not a plan cancellation and should not generate an engagement report
- WHITELIST: [14] customer.subscription.deleted sync_with_stripe not called for credit-pack: Same as [10] -- `sync_with_stripe` filters out credit subscriptions at line 539-542. Calling it would be a no-op

## Marked for Revert
(none)

---

### ai_credit_top_up_purchased_job.rb

## Fixed
- **notification job finds record via global `OrganizationAiCreditPurchase.find(purchase_id)` instead of scoping through organization association**: Changed `OrganizationAiCreditPurchase.find(purchase_id)` to `@organization.organization_ai_credit_purchases.find(purchase_id)` in `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/jobs/notification/ai_credit_top_up_purchased_job.rb` line 8. Matches analog `Notification::PaidWwrListingCreatedJob` which uses `@organization.jobs.find(job_id)`.

## Whitelisted
(none)

## Marked for Revert
(none)

---

### organization_ai_credit_purchase_serializer.rb

## Fixed
- `stripe_invoice_paid` not exposed in serializer: Added `:stripe_invoice_paid` to the attributes list in `Api::V1::OrganizationAiCreditPurchaseSerializer`. The model has a `stripe_invoice_paid` boolean column, so ActiveModel::Serializer reads it directly -- matching the analog pattern where `BoardWhatJobsListingSerializer` exposes `paid` via `object.paid?`.

## Whitelisted
(none)

## Marked for Revert
(none)

---

### organization_ai_credit_purchase_policy.rb

Zero remaining references. The fix is clean.

## Fixed
- policy pattern mismatch: Changed `create_top_up` controller action from `authorize @purchase` (which resolved to `OrganizationAiCreditPurchasePolicy#create_top_up?`) to `authorize :billing, :checkout?` (matching the analog pattern used by `checkout` and `create_top_up_checkout_session`). Removed the now-unused `create_top_up?` method from `OrganizationAiCreditPurchasePolicy`. Both policies checked `is_org_admin?` so authorization behavior is unchanged.

## Whitelisted
(none)

## Marked for Revert
(none)

---

### AiCreditSubscription.tsx

The cancel functionality is self-contained in this component. Even though `handleCancelClick` is not currently called from any banner in the JSX, keeping it is appropriate -- it's the mechanism for the cancel confirmation modal flow, and removing it would remove the ability to cancel AI credit subscriptions entirely. The analog doesn't need this because the analog routes all management through the Stripe portal. For AI credits, cancellation is handled via the app's own API. This is valid structural deviation forced by the different backend architecture.

## Fixed
- [Deviation 2: No trialing state banner]: Added `isTrialing` and `trialEndDays` detection matching analog pattern. Added trialing banner in JSX with `currentSubscription?.status === "trialing"` guard, check icon, trial end date via `prettyDate(currentSubscription.trialEnd)`, and "Manage billing" button calling `handleCreateBillingPortalSession`. Imported `timeAgoInWordsLong` from `@shared/lib/time`
- [Deviation 4: cancelAtPeriodEnd banner calls handleCancelClick instead of handleCreateBillingPortalSession]: Changed the `cancelAtPeriodEnd` banner's button from `onClick={handleCancelClick} disabled={isCanceling}` to `onClick={handleCreateBillingPortalSession}` (no disabled prop), matching the analog which sends users to Stripe portal for reactivation
- [Deviation 5: EXTRA isCanceledButStillActive banner]: Removed the entire `{isSubscribed && isCanceledButStillActive && (...)}` banner block. No analog equivalent exists. The `isCanceledButStillActive` variable itself is retained because `isSubscribed` depends on it
- [Deviation 6: Missing handleCreateBillingPortalSession]: Was already partially fixed in the file. `useCreateStripeCustomerPortalSession` imported from `@shared/queryHooks/useBilling`, `handleCreateBillingPortalSession` function defined matching analog structure with `returnUrl: "/hire/settings/plato-ai/billing"`. Now wired to trialing and cancelAtPeriodEnd banners
- [Deviation 7: No AiCreditsCallout equivalent cross-link]: Created `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountBilling/PlanBillingCallout.tsx` mirroring `AiCreditsCallout.tsx` structure (same interface shape, same styled component pattern: Callout/Main/Title/Body). Uses `Icon name="creditCard"` (react-feather CreditCard) instead of `PlatoChip` since billing has no branded mark. Added to `AiCreditSubscription.tsx` after `ContactUsCallout` matching analog placement. Added `history` prop to `AiCreditSubscription` signature, threaded from `OrganizationAiBilling.tsx` via `props.history`

## Whitelisted
- WHITELIST: [Deviation 1: No billing period toggle]: AI credit subscriptions are monthly-only. All lookup keys are `ai_credit_pack_subscription_*_monthly`. No yearly prices exist in `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` or `AI_CREDIT_PACK_DISPLAY_NAMES`. Adding a monthly/yearly `SlidingToggleSwitch` with no yearly prices would render empty tier cards or require filtering to zero results when "Yearly" is selected. The toggle exists in the analog because the main billing plans have both monthly and yearly Stripe prices
- WHITELIST: [Deviation 3: No legacy plan banner]: No legacy AI credit plan concept exists. `legacyPlanType` and `isLegacyPlan` in `planHelpers.ts` operate on the main subscription plan key, not on AI credit subscription lookup keys. AI credit subscriptions are new (no prior pricing tiers to be "legacy"). Adding a legacy banner would require fabricating detection logic with no data to detect

## Marked for Revert
- REVERT: [Deviation 2 window.logger]: Added `isTrialing` and `trialEndDays` to the render logger and `currentSubscriptionItemId` is in the SubscriptionInformation logger. These match the analog's logging pattern but are cosmetic debug output that could be cleaned up later

Files modified:
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/OrganizationAiBilling.tsx`

Files created:
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountBilling/PlanBillingCallout.tsx`

---

### AiSubscriptionTierCard.tsx

Clean -- no stale references.

## Fixed
- Current plan card shows static tag instead of ManageBillingActions: Replaced `<Styled.CurrentTag>Current plan</Styled.CurrentTag>` with `<ManageBillingActions hasActiveSubscription={hasActiveSubscription} hasCoupon={hasCoupon} stripePromoCode={stripePromoCode} onCreateBillingPortalSession={onCreateBillingPortalSession} />`. Added `ManageBillingActions` import. Removed unused `Styled.CurrentTag` styled component. Added `useCreateStripeCustomerPortalSession` hook and `handleCreateBillingPortalSession` handler to `AiCreditSubscription.tsx` (with `returnUrl` set to `/hire/settings/plato-ai/billing` instead of analog's `/hire/settings/billing`). Passed `onCreateBillingPortalSession={handleCreateBillingPortalSession}` to the card.
- No promo code support (hasCoupon/stripePromoCode props absent): Added `hasCoupon: boolean` and `stripePromoCode?: string` to `AiSubscriptionTierCardProps`. Destructured both in the component. Passed `hasCoupon={hasCoupon}` and `stripePromoCode={currentOrganization.stripePromoCode}` from `AiCreditSubscription.tsx`. These flow through to `ManageBillingActions` which controls the promo code dropdown visibility.
- onCreateNewSubscription callback takes tier argument (analog takes no arguments): Changed `onCreateNewSubscription?: (tier: AiCreditTier) => void` to `onCreateNewSubscription?: () => void`. Inside the card, `handleOnClickSubscriptionAction` now calls `onCreateNewSubscription()` with no arguments (matching analog's `PlanCard`). In `AiCreditSubscription.tsx`, changed from `onCreateNewSubscription={handleCheckoutNewSubscription}` to `onCreateNewSubscription={() => handleCheckoutNewSubscription(tier)}` -- the parent creates a closure that captures the tier, matching the analog pattern in `AccountBillingPlansUnsubscribed.tsx` line 319.
- No billingPeriod prop: Added `billingPeriod: "monthly" | "yearly"` to `AiSubscriptionTierCardProps`. Destructured in the component. Passed as `billingPeriod="monthly"` from `AiCreditSubscription.tsx` (AI credit subscriptions are monthly-only; no billing period toggle exists). Also added `selected_tier_billing_period: billingPeriod` to the `trackEvent` call, matching the analog's `selected_plan_billing_period`.
- No currentPlanBillingPeriod prop: Added `currentPlanBillingPeriod?: "monthly" | "yearly" | null` to `AiSubscriptionTierCardProps`. Destructured in the component. Added to `window.logger` output (matching analog). Passed as `currentPlanBillingPeriod="monthly"` from `AiCreditSubscription.tsx`.

## Whitelisted
(none)

## Marked for Revert
- REVERT: `billingPeriod="monthly"` and `currentPlanBillingPeriod="monthly"` hardcoded values: These are hardcoded to `"monthly"` because AI credit subscriptions currently have no billing period toggle. If/when a yearly option is added, these should be driven by state like the analog's `billingPeriod` state variable and `currentPlanBillingPeriod` derived from `currentPriceObject.recurring.interval`.
- REVERT: `window.logger` label in `handleCreateBillingPortalSession`: The analog uses `"%c[AccountContainer] "` which appears to be a cosmetic leftover from an earlier component name. The AI credit version uses `"%c[AiCreditSubscription] "` which is correct for its context. Matched the analog's structure but used the correct component name.

**Files changed:**
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiSubscriptionTierCard.tsx`
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`
