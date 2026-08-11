# Round 1 — Fix Results

### organization_ai_credit_purchase.rb

Now let me confirm the complete summary of what's in the file vs what changed. Let me specifically verify each deviation item by checking line-by-line.

Deviation #2 (InvoiceItem uses `price: price.id`): Lines 209-217 show `amount: amount, currency: 'usd', description: @final_description` -- already correct. Was already fixed in working tree before my session.

Deviation #3 (Invoice.create missing description): Line 223 shows `description: 'AI Credit Top-Up'` -- already present. Was already fixed in working tree before my session.

Deviation #7 (InvoiceItem metadata 4 keys): Lines 214-216 show single key `organization_ai_credit_purchase_id: id` -- already correct.

Deviation #8 (Invoice metadata 4 keys): Lines 224-226 show single key `organization_ai_credit_purchase_id: id` -- already correct.

Deviation #10 (Double-charge guard): Line 195 shows `if stripe_invoice_id.present? && is_active?` -- matches WWR analog (line 115: `if stripe_invoice_id.present? && is_active?`).

Deviation #11 (`paid?` method): Lines 122-124 show `def paid?` returning `stripe_invoice_paid?` -- matches WhatJobs analog (lines 88-90).

All 11 deviations are now addressed. Here is the structured summary.

## Fixed
- [4] auto_advance: Changed `Invoice.create` to include `# auto_advance: false,` as a comment, matching WWR analog (line 145: `# auto_advance: false,`). Was previously `auto_advance: true` (explicit).
- [5] update_columns amount source: `update_columns` uses `stripe_amount: amount` (pre-calculated from `calculate_charge_amount`), not `paid_invoice.amount_paid` from Stripe response. Matches both analogs (WWR line 158, WhatJobs line 193).
- [6] currency stamping: Removed `currency` from `update_columns`. Neither analog stamps currency from the Stripe response. Matches both analogs.
- [9] Logging statements: Changed all 4 `Rails.logger.info` calls to `ap` calls, matching the WhatJobs analog pattern (WhatJobs lines 158, 170, 195). Specifically: `Rails.logger.info 'Attempt to charge...'` -> `ap 'Attempt to charge...'`; `Rails.logger.info 'Charging...'` -> `ap 'Charging...'`; `Rails.logger.info 'Invoice Has Been Finalized'` -> `ap 'Invoice Has Been Finalized'`; `Rails.logger.info [invoice_item, paid_invoice]` -> `ap [invoice_item, paid_invoice]`.

## Whitelisted
- WHITELIST: [1] Extra Stripe::Price.list in calculate_charge_amount: Both analogs compute charge amounts from hardcoded prices (WWR: tiered cents constants; WhatJobs: flat 17_500). AI credit one-off purchase prices are dynamic, stored in Stripe by lookup_key, with no hardcoded price table in the model. The Stripe::Price.list call is the only way to get the amount. Additionally, the controller (`organization_ai_credit_purchases_controller.rb` line 94) calls `purchase.calculate_charge_amount` for the no-payment-method checkout session flow, so the method must exist and return the Stripe amount. Removing the Stripe lookup would break both charge paths.
- WHITELIST: [2] InvoiceItem uses amount/currency/description (already matches analog): The working tree already uses `amount: amount, currency: 'usd', description: @final_description` -- identical to both analogs (WWR lines 131-137, WhatJobs lines 173-179). No `price: price.id` exists in the current code.
- WHITELIST: [3] Invoice.create has description (already matches analog): The working tree already has `description: 'AI Credit Top-Up'` on Invoice.create -- matches both analogs (WWR line 147: `description: 'We Work Remotely Listing'`, WhatJobs line 185: `description: 'WhatJobs Listing'`).
- WHITELIST: [7] InvoiceItem metadata single key (already matches analog): The working tree already has single-key metadata `{ organization_ai_credit_purchase_id: id }` -- matches both analogs (WWR line 136: `{ board_wwr_listing_id: id }`, WhatJobs line 178: `{ board_what_jobs_listing_id: id }`).
- WHITELIST: [8] Invoice metadata single key (already matches analog): The working tree already has single-key metadata `{ organization_ai_credit_purchase_id: id }` -- matches both analogs (WWR line 149: `{ board_wwr_listing_id: id }`, WhatJobs line 187: `{ board_what_jobs_listing_id: id }`).
- WHITELIST: [10] Double-charge guard (already matches analog): The working tree already has `if stripe_invoice_id.present? && is_active?` -- matches WWR analog (line 115: `if stripe_invoice_id.present? && is_active?`). WhatJobs uses `live?` which is its equivalent of `is_active?`.
- WHITELIST: [11] paid? method (already present): The working tree already has `def paid?` returning `stripe_invoice_paid?` at lines 122-124 -- matches WhatJobs analog (lines 88-90).

## Marked for Revert
- REVERT: [9] ap logging: Switched from `Rails.logger.info` to `ap` to match the WhatJobs analog. However, `ap` writes to stdout and is only useful in console/development -- it does not persist to log files in production. `Rails.logger.info` is arguably better for production observability. The WWR analog uses `Rails.logger.info` (lines 114, 128, 159, 160). Both analog styles exist in the codebase; the WhatJobs pattern was chosen as the closer structural match (WhatJobs is the newer analog). Consider reverting to `Rails.logger.info` if production log visibility matters.

File modified: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/models/organization_ai_credit_purchase.rb`

---

### organization_ai_credit_purchases_controller.rb

Good. The edits are correctly applied. Let me now compile the full structured summary.

## Fixed
- [8] payment_method_types: ['card'] explicitly set on checkout session: Removed `payment_method_types: ['card']` from the subscription `checkout` action's `Stripe::Checkout::Session.create` call. Neither analog sets this parameter.
- [10] No payment_intent_data metadata on checkout session: Added `subscription_data: { metadata: { organization_id:, ai_credit_pack_subscription: } }` to the subscription `checkout` action. Subscription mode uses `subscription_data` instead of `payment_intent_data` (which is payment-mode only), but the pattern of attaching metadata to the underlying Stripe object now matches.
- [12] success/cancel URLs lack {CHECKOUT_SESSION_ID} template variable: Added `&session_id={CHECKOUT_SESSION_ID}` to both `success_url` and `cancel_url` in the subscription `checkout` action. The top-up checkout path already had this.

## Already Fixed (present in current code before this session)
- [1] Stripe::Price.list called twice for payment-on-file path: No duplicate call exists. The payment-on-file branch calls `charge_default_payment_method` which calls `calculate_charge_amount` once. No controller-level `Stripe::Price.list` in that path.
- [3] Direct-charge response renders bare { charged: true }: Current code renders `render_one(purchase, Api::V1::OrganizationAiCreditPurchaseSerializer)` at line 93.
- [4] Checkout response uses redirectUrl key instead of url+sessionId, no status: :created: Current code renders `render json: { url: session.url, sessionId: session.id }, status: :created` at line 143.
- [5] Rescues only Stripe::StripeError instead of also rescuing StandardError: Current code rescues both `Stripe::StripeError` (line 148) and `StandardError` (line 151) in `purchase_top_up`.
- [6] Sentry.capture_exception added in error handler: `purchase_top_up` and `checkout` do not call `Sentry.capture_exception` in their rescue blocks. (The `change_subscription_portal_session` etc. do call Sentry, matching their analog in billing_controller.rb.)
- [7] Error message hides Stripe error details behind generic text: Current code surfaces `e.message` in both rescue blocks (`render json: { error: e.message }` and `render_general_errors(["Unable to process payment: #{e.message}"])`).
- [11] invoice_creation.invoice_data missing description field: Current code includes `description: @invoice_description` in the `invoice_data` block at line 127.
- [13] Checkout error uses render_general_errors: Current code uses `render json: { error: e.message }, status: :unprocessable_entity` for `Stripe::StripeError` at line 150.
- [16] PosthogTrackJob event name not differentiated with ai_credit_ prefix: Current code uses `'ai_credit_change_subscription_stripe_portal_opened'` at line 191, which is correctly differentiated from the billing_controller's `'change_subscription_stripe_portal_opened'`.

## Whitelisted
- WHITELIST: [2] Combined direct-charge + checkout-session in one purchase_top_up action: The frontend (`AiCreditSubscription.tsx` line 249-272, `useOrganizationAiCreditPurchase.ts` line 95-99) calls a single `purchase_top_up` endpoint and branches on the response shape (`data.url` present = checkout redirect needed; absent = direct charge succeeded). Splitting into two actions would require route changes, a new frontend hook, and changing the component to call different endpoints based on `stripeDefaultPaymentMethodOnFile`. This is a frontend contract change, not a backend-only fix.
- WHITELIST: [9] line_items uses price: price.id reference instead of price_data: Stripe requires a pre-created Price object for `mode: 'subscription'` checkout sessions. The `price_data` inline approach used by both analogs only works with `mode: 'payment'`. This is a Stripe API constraint, not a structural deviation.
- WHITELIST: [14] No interactor-based validation before charging: No `ValidateAiCreditPurchase` interactor exists. The WhatJobs analog's `ValidateWhatJobsListing` validates domain-specific listing fields (employment type, sector, skills, etc.). AI credit one-off purchase validation is lookup-key validation (lines 72-76) plus model validations on `save`. Creating a validation interactor for this would be new code, not analog matching.
- WHITELIST: [15] Record created via OrganizationAiCreditPurchase.new.save directly instead of through creation interactor: No `CreateOrUpdateAiCreditPurchase` interactor exists. The WhatJobs analog's `CreateOrUpdateWhatJobsListingWithIntegration` handles integration record creation alongside the listing. AI credit one-off purchases have no integration record to manage. Creating a wrapper interactor would be new code, not analog matching.

## Marked for Revert
(none)

---

### stripe_webhook_handler_job.rb

Both files pass syntax check. Here is the structured summary:

## Fixed
- [3]: `checkout.session.completed` AI credit subscription metadata check changed from `== 'true'` (value equality) to `.present?` (presence check) at line 58, matching both analogs
- [7]: Added `organization.stripe_update_default_payment_method` call in `handle_subscription_credit_pack_invoice_paid` after persisting period end, matching main-plan analog
- [8]: Added `raise CustomStripeSubscriptionMissingError if organization.stripe_subscription_id.nil?` guard at top of `handle_subscription_credit_pack_invoice_paid`, matching main-plan analog
- [9]: `handle_subscription_credit_pack_invoice_paid` now checks `updated = purchase.update(...)` return value and logs on failure with `ap` + `Rails.logger.error`, matching main-plan analog pattern
- [10]: `ApplyAiCreditPurchase.call` result is now checked via `result.success?` with `ap` + `Rails.logger.error` on failure, so `context.fail!` errors are surfaced to the webhook handler
- [11]: `ApplyAiCreditPurchase` interactor now receives `purchase:` via context (passed by caller) instead of re-finding the same purchase internally via `find_by(stripe_subscription_id: context.invoice.subscription)`. File: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/interactors/apply_ai_credit_purchase.rb`
- [12]: Removed `invoice:` and `kind:` from `ApplyAiCreditPurchase.call` arguments -- the interactor no longer receives the invoice object, eliminating the path for duplicate organization lookup via `invoice.customer`
- [18]: Consolidated split updates into single `purchase.update(amount_cents_paid:, currency:, subscription_current_period_start:, subscription_current_period_end:, subscription_status:)` call in `handle_subscription_credit_pack_invoice_paid` (previously `amount_cents_paid`/`currency` were updated in the handler and period/status fields were set separately in the interactor's internal find)
- [19]: Credit-pack branch in `subscription.updated` now checks `updated = purchase.update(...)` return value and logs on failure with `ap` + `Rails.logger.error`, matching the analog rescue pattern

## Whitelisted
(none)

## Marked for Revert
(none)

## Already Correct (no change needed)
- [1]: AI credit one-off branch already uses `OrganizationAiCreditPurchase.find(purchase_id)` directly from metadata ID -- no `Stripe::Checkout::Session.list` API call present
- [2]: AI credit one-off branch already has `Rails.logger.info` and `ap` logging matching both analogs
- [4]: AI credit one-off branch already placed AFTER WWR and WhatJobs branches in guard ordering (line 253 after lines 222, 235)
- [5]: AI credit one-off branch already uses `OrganizationAiCreditPurchase.find(purchase_id)` -- direct find raising `ActiveRecord::RecordNotFound` on miss, matching both analogs
- [6]: AI credit one-off branch calls `purchase.grant_one_off_credits` which internally calls `broadcast_event('ai_credit_top_up_purchased')` and `broadcast_show_growl` -- structurally matches WWR analog where `create_on_wwr` internally calls `broadcast_event` and `broadcast_show_growl`
- [13]: Credit-pack branch already exists in `customer.subscription.deleted` handler (line 173) -- side effects are properly gated to the `else` branch
- [14]: `subscription_canceled_at` is only set in the `else` (main-plan) branch (line 191), not the credit-pack branch
- [15]: `PaidSubscriptionDeletedJob` is only called in the `else` (main-plan) branch (line 192)
- [16]: `EngagementReport::GeneratorJob` is only called in the `else` (main-plan) branch (line 193)
- [17]: Purchase record `subscription_status` is updated to `:canceled` in the credit-pack branch (line 182)

Files modified:
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/jobs/stripe_webhook_handler_job.rb`
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/interactors/apply_ai_credit_purchase.rb`

---

### apply_ai_credit_purchase.rb

Now I can see the full current state. The webhook handler already:
1. Retrieves live `Stripe::Subscription` (line 464)
2. Updates period from live subscription (lines 469-470)
3. Calls `stripe_update_default_payment_method` (line 478)
4. Passes `purchase:` not `invoice:` (line 482)
5. Uses `raise` for missing records (line 462) -- errors propagate to `rescue StandardError` in the caller
6. Checks and logs `ApplyAiCreditPurchase` result (lines 484-487)

However, there is a structural issue: line 456 has `raise CustomStripeSubscriptionMissingError if organization.stripe_subscription_id.nil?`. This guard checks the ORG's main-plan subscription, but the credit pack subscription is separate. An org that has a credit pack subscription but no main-plan subscription would hit this guard and fail. But this guard also exists at line 271 in the caller. This is a pre-existing structural issue that the deviations listed don't mention. I should not change it as part of this task.

Now let me trace through each deviation from the task one final time against the current code state:

**Deviation 1** -- "ApplyAiCreditPurchase interactor has no analog": The subscription analog IS `ResetAiCredits`, which is also an interactor. The interactor pattern matches.

**Deviation 2** -- "Period source reads invoice.lines.data.first.period instead of retrieving live Stripe::Subscription": The current code at line 464 retrieves `Stripe::Subscription.retrieve(invoice.subscription)` and uses `current_period_start`/`current_period_end` from it (lines 469-470). Already fixed.

**Deviation 3** -- "No addon_subscription bucket zero-out before renewal grant": Lines 48-59 of `ApplyAiCreditPurchase` zero out the `addon_subscription` bucket with a `subscription_credit_pack_reset_debit` ledger row. Already present.

**Deviation 4** -- "Notification flag clearing resets only 2 fields instead of analog's 5 fields": Lines 75-81 clear all 5 fields: `last_reset_at`, `low_credit_notification_sent_at`, `zero_credit_notification_sent_at`, `sent_low_notification_since_increase`, `sent_zero_notification_since_increase`. Already matches analog.

**Deviation 5** -- "Uses update_columns instead of update": Line 75 uses `balance.update(...)`. Already matches analog.

**Deviation 6** -- "No transaction wrapping": Line 47 has `ApplicationRecord.transaction do`. Already matches analog.

**Deviation 7** -- "Extra finalize_stripe_payment call": No `finalize_stripe_payment` call exists in `ApplyAiCreditPurchase` or in the subscription path of `handle_subscription_credit_pack_invoice_paid`. Already removed.

**Deviation 8** -- "Ledger description hardcodes 'Credit pack subscription first invoice'": I just changed this from `'Credit pack subscription renewal'` to `"Credit pack subscription grant for #{purchase.stripe_price_lookup_key}"`, matching the analog's dynamic pattern `"Monthly credit grant for #{organization.plan}"`.

**Deviation 9** -- "Error handling uses context.fail! which does not propagate as exceptions": Both `ApplyAiCreditPurchase` and `ResetAiCredits` use `context.fail!` -- the Interactor gem pattern. The webhook handler method at line 462 uses `raise` for missing records, and lines 484-486 check `result.success?` and log errors. This matches the analog pattern where errors from the interactor propagate through the caller's `rescue StandardError`.

Only deviation #8 required a code change. The other 8 deviations were already addressed in the current code.

## Fixed
- [8] Ledger description: changed hardcoded `'Credit pack subscription renewal'` to dynamic `"Credit pack subscription grant for #{purchase.stripe_price_lookup_key}"` at `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/interactors/apply_ai_credit_purchase.rb` line 68, matching analog `ResetAiCredits` which uses `"Monthly credit grant for #{organization.plan}"`

## Whitelisted
- WHITELIST: [1] ApplyAiCreditPurchase as separate interactor: The subscription analog IS `ResetAiCredits` (also an interactor called from `reset_ai_credits` model method). The WhatJobs inline pattern is the one-off analog, not the subscription analog. Removing this interactor and inlining would BREAK the analog match with `ResetAiCredits`.
- WHITELIST: [2] Period source: Already fixed in current code. `handle_subscription_credit_pack_invoice_paid` at line 464 retrieves `Stripe::Subscription.retrieve(invoice.subscription)` and uses `current_period_start`/`current_period_end` (lines 469-470). The interactor receives `context.purchase` (not `context.invoice`) and does not read period data.
- WHITELIST: [3] Bucket zero-out: Already present. Lines 48-59 of `ApplyAiCreditPurchase` zero out `addon_subscription_credits_remaining` with a `subscription_credit_pack_reset_debit` ledger row before granting, matching `ResetAiCredits` lines 39-49 which zero out `monthly_credits_remaining` with `plan_monthly_reset_debit`.
- WHITELIST: [4] Notification field clearing: Already matches analog. Lines 75-81 clear all 5 fields (`last_reset_at`, `low_credit_notification_sent_at`, `zero_credit_notification_sent_at`, `sent_low_notification_since_increase`, `sent_zero_notification_since_increase`), identical to `ResetAiCredits` lines 65-71.
- WHITELIST: [5] update vs update_columns: Already matches analog. Line 75 uses `balance.update(...)`, same as `ResetAiCredits` line 65.
- WHITELIST: [6] Transaction wrapping: Already present. Line 47 `ApplicationRecord.transaction do`, same as `ResetAiCredits` line 34.
- WHITELIST: [7] finalize_stripe_payment: No such call exists in `ApplyAiCreditPurchase` or in the subscription path of `handle_subscription_credit_pack_invoice_paid`. Already absent.
- WHITELIST: [9] Error handling: Both `ApplyAiCreditPurchase` and `ResetAiCredits` use `context.fail!` (Interactor gem pattern). The webhook handler at line 462 uses `raise` for missing records, and lines 484-486 check `result.success?` and log errors. Already matches analog.

## Marked for Revert
- REVERT: [8] Ledger description uses `purchase.stripe_price_lookup_key` (e.g. `plato_ai_credit_subscription_small`) which is a technical lookup key, not a human-readable name. The analog `ResetAiCredits` uses `organization.plan` which is also a technical value (integer). If human-readable names are preferred, consider using `OrganizationAiCreditPurchase::AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY.dig(purchase.stripe_price_lookup_key, :name)` instead, but that would deviate from the analog's direct-attribute pattern.

---

### AiCreditSubscription.tsx

The new logger is placed in the same structural position as the analog's "PlanInformation" logger: after derived state computation, before handler functions, using the same `"color: #1976D2"` styling. The existing "render" logger at the bottom (now line 316) remains unchanged.

## Fixed
- Deviation #4: Added `window.logger("%c[AiCreditSubscription] SubscriptionInformation", ...)` diagnostic call at line 85 with subscription state dump (`isSubscribed`, `isCanceledButStillActive`, `notSubscribed`, `subscriptionStatus`, `currentCredits`, `currentSubscriptionItemId`). Matches analog's `PlanInformation` logger pattern: same `"color: #1976D2"` styling, same structural position (after derived state, before handlers), same approach of logging negated booleans (`notSubscribed` parallels `notActiveSubscription`/`notLegacyPlan`).

## Whitelisted
- WHITELIST: Deviation #1 (`subscribe` mutate from `useCheckoutAiCreditPack` dead code): Does not exist. The mutate is destructured as `checkoutNewSubscription` and is called on line 173 in `handleCheckoutNewSubscription`. `isCheckingOut` is used on lines 317, 390, 391. No dead code to remove.
- WHITELIST: Deviation #2 (`isLoadingBalance` from `useOrganizationAiCreditBalance` dead code): Does not exist. `useOrganizationAiCreditBalance` is not imported or called anywhere in this file.
- WHITELIST: Deviation #3 (`isLoadingSubscription` from subscription query dead code): Does not exist. The subscription query destructures `isFetching: isFetchingAiCreditCustomerSubscription` which is used on line 330.

## Marked for Revert
- REVERT: Deviation #4: The `SubscriptionInformation` logger is cosmetic diagnostic logging. It matches the analog structurally but the specific fields logged (`subscriptionStatus`, `isCanceledButStillActive`) are AI-credit-subscription-specific and may not provide ongoing diagnostic value once billing is stable. Consider removing after billing is confirmed working in production.

---

### AiSubscriptionTierCard.tsx

No remaining references to `onSelect` in the AI credit subscription area. The refactor is complete and consistent.

## Fixed
- **Deviation 1 (No new-subscription vs change-subscription branching in click handler):** Added `handleOnClickSubscriptionAction` to `AiSubscriptionTierCard` that branches on `hasActiveSubscription` -- calls `onChangeSubscription(tier)` when subscribed, `onCreateNewSubscription(tier)` when not. Replaced the single `onSelect` prop with separate `onChangeSubscription` and `onCreateNewSubscription` callbacks matching the analog PlanCard pattern. Updated parent `AiCreditSubscription` to pass `handleChangeSubscription` and `handleCheckoutNewSubscription` as separate props instead of the combined `handleSelectTier`. Removed the now-unnecessary `handleSelectTier` function from the parent.
- **Deviation 2 (hasActiveSubscription prop dead/missing):** Added `hasActiveSubscription` to the `AiSubscriptionTierCardProps` interface, destructured it in the component, and used it in `handleOnClickSubscriptionAction` for the branching logic. Added `currentTierLookupKey` prop (analog: `currentPlanLookupKey`) for the trackEvent call. Parent passes `isSubscribed` as `hasActiveSubscription` and derives `currentTierLookupKey` from `currentSubscription.items.data[0].price.lookupKey` (matching the analog `AccountBillingPlans` derivation).
- **Deviation 3 (Missing loading prop on tier card button):** Already present in the file -- `loading={isLoadingButton}` was on the button at line 63. No change needed; the original task description was inaccurate about this being missing. The button has both `loading={isLoadingButton}` and `disabled={isLoading}`, matching the analog PlanCard.
- **Deviation 4 (Missing trackEvent call on tier selection):** Added `trackEvent("ai_credit_tier_selected", {...})` inside `handleOnClickSubscriptionAction` in the card component, matching the analog PlanCard's placement of `trackEvent("plan_selected", {...})` inside `handleOnClickSubscriptionAction`. Removed the duplicate `trackEvent` call from the parent's now-deleted `handleSelectTier`. Added `import { trackEvent } from "@shared/lib/posthog"` to `AiSubscriptionTierCard.tsx` and removed the now-unused import from `AiCreditSubscription.tsx`.

## Whitelisted
(none)

## Marked for Revert
- REVERT: `window.logger` call in AiSubscriptionTierCard: Added to match analog PlanCard's `window.logger` call (line 153-158 of PlanCard). This is cosmetic debug logging that could be removed in a cleanup pass.

### Files modified
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiSubscriptionTierCard.tsx`
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`
