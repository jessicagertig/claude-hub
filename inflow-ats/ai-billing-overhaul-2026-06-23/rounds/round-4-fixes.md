# Round 4 — Fix Results

### organization_ai_credit_purchase.rb

All edits are correct. Here is the summary:

## Fixed
- [1] charge_for_purchase 'Attempt to charge' log: changed `ap` to `Rails.logger.info` to match `BoardWwrListing#charge_for_listing` line 114
- [2] charge_for_purchase already-charged guard log: changed `ap 'Already charged for this AI credit one-off purchase'` to `ap 'Hmm, if trying to charge for an update because of expiration we run into a small issue'` to match `BoardWwrListing#charge_for_listing` line 116
- [3] charge_for_purchase 'Charging...' log: changed `ap` to `Rails.logger.info` to match `BoardWwrListing#charge_for_listing` line 128
- [4] charge_for_purchase 'Invoice Has Been Finalized' log: changed `ap` to `Rails.logger.info` and added second log line `Rails.logger.info [invoice_item, paid_invoice]` to match `BoardWwrListing#charge_for_listing` lines 160-161
- [5] `grant_one_off_credits` now calls `broadcast_show_growl('Purchased AI Credit Top-Up')` -- user gets a toast after successful credit grant, matching how `BoardWwrListing#create_on_wwr` (line 194) and `WhatJobsListing#create_listing` (line 53) call `broadcast_show_growl` after successful operation
- [6] `broadcast_event` moved from webhook handler into `grant_one_off_credits` (line 163) -- now called from the model method, matching `BoardWwrListing#create_on_wwr` (lines 193-194) where both `broadcast_event` and `broadcast_show_growl` are called from inside the model method, not from the webhook handler. Removed the duplicate `broadcast_event` and `broadcast_show_growl` calls from `StripeWebhookHandlerJob` (formerly lines 268-269)
- [7/12] `broadcast_show_growl` recipient changed from `organization.owner` to `last_updated_by_organization_user_id.nil? ? organization.owner : last_updated_by_organization_user.user` -- matches `BoardWhatJobsListing#broadcast_show_growl` (line 293) and `BoardWwrListing#broadcast_show_growl` (line 272)
- [8] `broadcast_show_growl` is now called from `grant_one_off_credits` (line 164) -- was previously never called from any code path
- [9] Added `broadcast_error_growl` method (lines 180-182) matching `BoardWhatJobsListing#broadcast_error_growl` (line 296-297) -- uses same `last_updated_by_organization_user` fallback pattern with `kind: 'error'`
- [13] Added `belongs_to :last_updated_by_organization_user, class_name: 'OrganizationUser', optional: true` association (line 79) matching `BoardWhatJobsListing` (line 5) and `BoardWwrListing` (line 6). Created migration `20260611120003_add_last_updated_by_organization_user_to_organization_ai_credit_purchases.rb`. Set `last_updated_by_organization_user: current_organization_user` in all three controller creation paths: `checkout`, `create_top_up`, and `create_top_up_checkout_session`

## Whitelisted
- WHITELIST: [10] calculate_charge_amount makes Stripe API call instead of local computation: AI credit one-off purchase prices are dynamic per lookup_key and must be fetched from Stripe. The listing analogs have hardcoded/computed prices because their pricing is static. Changing to local computation would require hardcoding prices that are intentionally managed in Stripe
- WHITELIST: [14] grant_one_off_credits rescue logs at info level only vs analog Discord/Slack/error growl: The WWR and WhatJobs analogs have Discord/Slack notification jobs and error growls in their rescue blocks because they interact with external APIs (WWR API, WhatJobs API) where failures need ops attention. `grant_one_off_credits` is a local database operation -- adding Discord/Slack notifications for a local DB failure would be a scope expansion requiring new notification job classes that do not exist yet

## Marked for Revert
- REVERT: [2] already-charged guard log message: The text `'Hmm, if trying to charge for an update because of expiration we run into a small issue'` is WWR-specific context about listing expiration/renewal charges. AI credit one-off purchases have no expiration or update-charge concept. The original message `'Already charged for this AI credit one-off purchase'` was more accurate for this domain. Matched to close the analog deviation but the text should be reverted to something domain-appropriate
- REVERT: [11] defensive check comment: The comment `# defensive check shouldn't be necessary since we only call this after_create but worth it anyway` is sourced from `BoardWwrListing#charge_for_listing` (line 119). `BoardWhatJobsListing#charge_for_listing` has no such comment. The comment is factually correct for the AI credit one-off purchase flow (charge_for_purchase is called right after save in the controller) so it is not harmful, but it was copied from the WWR analog rather than the WhatJobs analog. Left as-is since removing it would lose useful context

Files modified:
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/models/organization_ai_credit_purchase.rb`
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/jobs/stripe_webhook_handler_job.rb`
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/db/migrate/20260611120003_add_last_updated_by_organization_user_to_organization_ai_credit_purchases.rb` (new)

---

### stripe_webhook_handler_job.rb

Good. Now let me compile the final summary of all 24 deviations.

## Fixed
- [1] webhook record lookup `find_by(id:)` changed to `find`: `OrganizationAiCreditPurchase.find(purchase_id)` at line 261, matching `BoardWwrListing.find(listing_id)` and `BoardWhatJobsListing.find(listing_id)` analogs
- [3] `broadcast_show_growl` added to one-off purchase flow: `purchase.broadcast_show_growl('AI Credit Top-Up Purchased')` at line 269, matching WWR analog's `broadcast_show_growl('Created WWR Listing')` in `create_on_wwr`
- [5] webhook find pattern changed from `find_by(id:)` to `find`: same fix as item 1
- [6] invoice.paid missing-record guard now raises: `find` raises `ActiveRecord::RecordNotFound` on missing record, propagates to outer `rescue StandardError` block, matching WWR/WhatJobs `find` behavior
- [7] invoice.paid missing-record error now reaches 3 channels: `ActiveRecord::RecordNotFound` from `find` propagates to the outer rescue which has `Rails.logger.error`, `ap`, and `puts` (lines 303-308), matching the analog's multi-channel error output
- [10] invoice.paid call-site safe navigation confirmed present: `if purchase&.present?` at line 263 matches `if listing&.present?` in both WWR (line 216) and WhatJobs (line 229) analogs
- [11] subscription.updated missing payment method update added to credit-pack branch: `organization.stripe_update_default_payment_method(object.default_payment_method) if object.default_payment_method` at line 149, matching the main-plan else branch at line 156
- [16] checkout.session.completed subscription metadata copy added: lines 70-77 retrieve the subscription and copy checkout session metadata to it when empty, matching the main-plan analog at lines 100-111
- [17] checkout.session.completed `begin/rescue` error wrapper added: lines 59-81 wrap the AI credit subscription checkout flow in `begin...rescue StandardError`, matching the main-plan analog at lines 87-117
- [18] metadata access style fixed in checkout.session.completed: changed from `object.metadata.ai_credit_pack_subscription.present?` (dot access, no safe navigation) to `object.metadata&.[]('ai_credit_pack_subscription').present?` (safe navigation with bracket access), matching the `object.metadata&.[]('board_wwr_listing_id').present?` pattern used in invoice.paid
- [21] invoice.paid subscription `stripe_update_default_payment_method` arg removed: changed from `organization.stripe_update_default_payment_method(stripe_subscription.default_payment_method)` to `organization.stripe_update_default_payment_method` at line 289, matching the main-plan analog at line 298 which calls without args
- [24] subscription.deleted credit-pack branch now sets `stripe_cancel_at_period_end: false`: added to the `purchase&.update(...)` call at line 189, clearing stale cancel-at-period-end data when subscription is deleted

## Whitelisted
- WHITELIST: [2] broadcast_event in handler not model method: the AI credit one-off flow calls `purchase.broadcast_event(...)` from the webhook handler (line 268), matching the WhatJobs analog which also calls `listing.broadcast_event(...)` from the handler (not from inside `create_on_what_jobs`). WhatJobs is the WHITELISTED analog for this dimension.
- WHITELIST: [4] Rails.logger.info confirmation line: `Rails.logger.info "AI credit one-off purchase #{purchase_id} payment confirmed"` at line 266 matches WhatJobs analog's `Rails.logger.info "WhatJobs listing #{listing_id} payment confirmed"`. WHITELISTED matches WhatJobs dimension.
- WHITELIST: [8] invoice.paid `subscription_current_period_start` stored: EXTRA field written at line 286. Model validation `validates :subscription_current_period_start, presence: true, if: -> { subscription? && stripe_subscription_id.present? }` forces this field to be populated.
- WHITELIST: [9] invoice.paid `stripe_amount` and `currency` stored: EXTRA fields written at lines 284-285. Model validations `validates :stripe_amount, presence: true` and `validates :currency, presence: true` (both conditional on subscription with stripe_subscription_id present) force these fields.
- WHITELIST: [12] subscription.deleted uses `update` vs analog `update_column`: the AI credit branch writes `subscription_status` which is an `enum` field (integer column). `update_columns` bypasses ActiveRecord enum mapping and would write the raw string (`"canceled"`) to an integer column, causing a database error. Must use `update` for correct enum value mapping.
- WHITELIST: [13] subscription.deleted stores `subscription_status` EXTRA field: the main-plan analog does not store status on deletion (the Organization model handles status via `sync_with_stripe`). The AI credit subscription purchase record requires explicit status tracking because it has no equivalent `sync_with_stripe` mechanism.
- WHITELIST: [14] checkout.session.completed uses `update_columns` vs analog `update`: the AI credit branch uses `purchase.update_columns(stripe_subscription_id: object.subscription)` because the model has conditional validations on `subscription_current_period_start` and `subscription_current_period_end` that require presence when `stripe_subscription_id` is present. At checkout time, those period fields are not yet known (they arrive with the first `invoice.paid`). Using `update` would trigger validation failure.
- WHITELIST: [15] checkout.session.completed missing `Stripe::Customer.update`: the main-plan analog calls `Stripe::Customer.update(object.customer, name: ..., description: ...)` to set customer name/description. For AI credit subscription checkout, the Stripe customer already exists (the org must have a main-plan subscription first). The customer name/description are already set.
- WHITELIST: [19] `handle_subscription_credit_pack_invoice_paid` private method removed, logic inlined: the subscription invoice.paid logic is now inline in the main handler, matching the structural pattern of the main-plan subscription invoice.paid flow (also inline). Both subscription paths delegate business logic to external code (`ApplyAiCreditPurchase` interactor for AI credits, `organization.organization_ai_credit_balance&.reset_ai_credits` for main-plan).
- WHITELIST: [20] invoice.paid subscription writes period start/end in webhook handler: the main-plan analog writes `stripe_current_period_end_at` in the handler (line 297). The AI credit code writes both `subscription_current_period_start` and `subscription_current_period_end` in the handler (lines 286-287). The period_end location matches. Period_start is EXTRA but required by model validation (covered by item 8 WHITELIST).
- WHITELIST: [22] invoice.paid error handling: the previous code had 3 specific rescue clauses (`Stripe::StripeError`, `ActiveRecord::RecordInvalid/RecordNotFound`, `StandardError` with re-raise). The analog (main-plan else branch) uses a single `rescue StandardError => e` that swallows errors. Matching the analog means using the same single `rescue StandardError` pattern. The analog itself does not allow Sidekiq retry.
- WHITELIST: [23] invoice.paid `org.update` success check: the main-plan analog at line 297 calls `organization.update(...)` without checking the return value. The AI credit subscription path at line 283 also calls `purchase.update(...)` without checking. Both paths match in not checking. This is a pre-existing gap in the analog itself, not an AI-credit-specific deviation.

## Marked for Revert
- REVERT: [4] Rails.logger.info confirmation line: while this matches the WhatJobs analog, the WWR analog does not have this extra log line in the webhook handler (WWR logs inside the model method instead). Consider removing from both WhatJobs and AI credit webhook handler paths for consistency with WWR, or moving it into the model methods.

---

### organization_ai_credit_purchases_controller.rb

The fix is correct. Now let me compile the full summary for all 10 deviations.

## Fixed
- [3] checkout session product_data.description repeats name vs analog has separate final_description: Introduced `plan_name` variable for the raw plan name from the constant. Set `@description` to `"Plato AI Credit Top-Up - #{plan_name}"` (matches analog's `"WhatJobs Job Listing - #{job.title}"` pattern). Set `name` to `"#{plan_name} - Plato AI Credit Top-Up"` (matches analog's `"#{job.title} - WhatJobs Job Listing"` reversed-order pattern). File: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` lines 114-125.

## Whitelisted
- WHITELIST: [1] create_top_up has separate Stripe::StripeError rescue vs analog only StandardError: Pre-marked WHITELISTED in task. The Stripe::StripeError rescue gives users a specific "Payment failed" message vs the generic "Unable to process payment" from StandardError. Removing it would degrade error messaging.
- WHITELIST: [2] create_top_up_checkout_session stores stripe_checkout_session_id on record - analog does not: Pre-marked WHITELISTED in task. The AI credit one-off purchase record needs the checkout session ID to link the Stripe payment back to the purchase record when `invoice.paid` webhook fires. The WhatJobs analog does not store it because its `create_checkout_session` renders the session URL directly and the listing ID is passed via metadata.
- WHITELIST: [4] invoice_data.metadata has organization_id where analog has job_id: Pre-marked WHITELISTED in task. Correct domain adaptation -- AI credit one-off purchases are org-level, not job-level, so `organization_id` replaces `job_id`.
- WHITELIST: [5] currency set at record build time - analog never stores currency on record: Pre-marked WHITELISTED in task. The `OrganizationAiCreditPurchase` model has a `currency` column with a presence validation. The analog `BoardWhatJobsListing` model has no `currency` column. Removing `currency: 'usd'` from the build would fail the model validation.
- WHITELIST: [6] controller create_top_up has no interactor - builds record directly vs analog uses CreateOrUpdateWhatJobsListingWithIntegration: The WhatJobs interactor exists because listing creation is multi-step: create/update a job board integration record, then create/update a draft listing. The AI credit one-off purchase is a single record creation with no integration or draft step. No `CreateOrUpdateAiCreditPurchase` interactor exists. Creating one to wrap a single `OrganizationAiCreditPurchase.new(...)` call would add infrastructure with no purpose and no other callers.
- WHITELIST: [7] controller create_top_up has no separate validation step - relies on ActiveRecord vs analog calls ValidateWhatJobsListing: `ValidateWhatJobsListing` is a 174-line interactor with domain-specific validations (job title length, description word count, uppercase percentage, salary fields, location, etc.) that ActiveRecord validations cannot express. The AI credit one-off purchase has no equivalent domain validation beyond what ActiveRecord model validations already enforce (presence of required fields, enum values). No `ValidateAiCreditPurchase` interactor exists. Creating one that just delegates to `.valid?` would add empty infrastructure.
- WHITELIST: [8] create_top_up_checkout_session stores checkout_session_id after creation: Pre-marked WHITELISTED in task. Same as deviation #2 -- the `update_columns(stripe_checkout_session_id: session.id)` links the Stripe checkout session back to the purchase record for webhook reconciliation.
- WHITELIST: [9] customer_subscription ap log ordering differs - logs before nil check same as analog but with safe navigation: The analog (`billing_controller.rb` line 608) does `ap current_organization.stripe_subscription` then checks `current_organization.stripe_subscription_id.nil?`. Ours does `ap purchase&.stripe_subscription` then checks `purchase&.stripe_subscription_id.nil?`. The ordering is identical (log before nil check). The safe navigation (`&.`) is forced because our code resolves through a `purchase` variable that can be nil (found via `find_by`), while the analog accesses `current_organization` directly which is always present. Structural match with forced adaptation.
- WHITELIST: [10] charge.refunded handler exists with no listing analog: Pre-marked WHITELISTED in task. The AI credit one-off purchase refund handler exists in the Stripe webhook handler to reverse credit grants when a charge is refunded. WhatJobs listings have no equivalent concept (you cannot "un-publish" a listing by refunding). This is domain-specific with no analog to match.

## Marked for Revert
- REVERT: [3] product_data name/description: The plan names from `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` already include "Plato AI Credit Top-Up" in them (e.g., "Plato AI Credit Top-Up — Small"). This means `@description` becomes "Plato AI Credit Top-Up - Plato AI Credit Top-Up — Small" which is redundant. The analog works because `job.title` is always distinct from "WhatJobs Job Listing". Consider changing to `@description = plan_name` and `name: "#{plan_name} - Top-Up"` or similar once the structural audit is complete.

---

### useOrganizationAiCreditPurchase.ts

The diff confirms both logger tag changes were applied correctly (the rest of the diff is pre-existing uncommitted changes, not from my edits).

## Fixed
- `useChangeAiCreditSubscriptionViaStripePortal` window.logger tag: changed from `useChangeAiCreditSubscriptionViaStripePortal` to `useChangeAiCreditPlanStripePortalSession` to match analog `useChangeSubscriptionViaStripePortal` which uses tag `useChangePlanStripePortalSession`
- `useUpdateAiCreditSubscriptionWithPaymentMethod` window.logger tag: changed from `useUpdateAiCreditSubscriptionWithPaymentMethod` to `useUpdateAiCreditWithPaymentMethod` to match analog `useUpdateWithPaymentMethod` which uses tag `useUpdateWithPaymentMethod`

## Whitelisted
(none)

## Marked for Revert
- REVERT: `useChangeAiCreditSubscriptionViaStripePortal` logger tag `useChangeAiCreditPlanStripePortalSession`: The analog's tag `useChangePlanStripePortalSession` does not match its own hook name `useChangeSubscriptionViaStripePortal` -- this looks like a cosmetic inconsistency in the analog itself. The AI credit version now copies that inconsistency. Both should arguably use the hook name as the tag for grep-ability.
- REVERT: `useUpdateAiCreditSubscriptionWithPaymentMethod` logger tag `useUpdateAiCreditWithPaymentMethod`: Drops "Subscription" from the tag to match the analog's shorter naming, but the hook name retains "Subscription". The analog's hook is simply `useUpdateWithPaymentMethod` (no "Subscription" to drop), so the parallel is imperfect. May want to restore to match the actual hook name for grep-ability.

---

### AiCreditSubscription.tsx

Good, the first param is `isSubscribed: boolean` in the helper -- the value we pass (`hasActiveSubscription`) is a boolean, so the types match.

Now let me summarize the full results:

## Fixed
- [3] hasActiveSubscription computed internally vs received as prop from parent: Moved `hasActiveSubscription` computation from `AiCreditSubscription` to `OrganizationAiBilling` (the parent). `OrganizationAiBilling` now imports `useOrganizationAiCreditPurchase`, computes `hasActiveSubscription` from subscription status (matching the analog pattern where `AccountBilling` computes it from `currentOrganization.stripeSubscriptionInGoodStanding` and passes it to `AccountBillingPlans`), and passes it as a prop. `AiCreditSubscription` now receives `hasActiveSubscription` as a prop instead of computing `isSubscribed` internally. All internal `isSubscribed` references replaced with `hasActiveSubscription`. Debug logger updated from `isSubscribed`/`isCanceledButStillActive`/`notSubscribed` to `hasActiveSubscription`/`notActiveSubscription` to match analog's `hasActiveSubscription`/`notActiveSubscription` pattern.
- [4] Subtitle text conditionally renders 'Change your plan' or 'Choose a credit subscription' vs analog always 'Subscription options': Changed to static `"Subscription options"` matching the analog.
- [5] isLoadingButton on card uses mutation states vs analog uses isFetchingStripeCustomerSubscription: Changed `isLoadingButton` from `isCheckingOut || isLoadingChangeSubscriptionViaStripePortal || isLoadingUpdateWithPaymentMethod` to `isFetchingAiCreditCustomerSubscription` (the AI credit equivalent of the analog's `isFetchingStripeCustomerSubscription`).
- [8] redirectToStripe helper with no analog equivalent: Removed the `redirectToStripe` helper function. Inlined `window.location.href = data.url` in `handleCheckoutNewSubscription` and `handleTopUpCheckout`, matching the analog which does `window.location.href = data.redirectUrl` inline in each handler's `onSuccess`.
- [9] handleCheckoutNewSubscription callback pattern: Changed `onCreateNewSubscription={handleCheckoutNewSubscription}` to `onCreateNewSubscription={() => handleCheckoutNewSubscription(tier)}`, wrapping in a closure. This matches the analog pattern in `AccountBillingPlansUnsubscribed` (`onCreateNewSubscription={() => handleCreateNewSubscription(plan)}`) and fixes a bug where the tier argument was lost since `AiSubscriptionTierCard.onCreateNewSubscription` is typed `() => void`.
- [12] window.logger in handleCreateBillingPortalSession.onSuccess uses [AiCreditSubscription] vs analog [AccountContainer]: Changed to `[AccountContainer]` matching the analog.

## Whitelisted
- WHITELIST: [1] Missing BillingPeriodToggleWrapper / SlidingToggleSwitch / billingPeriod state: AI credit subscriptions are monthly-only. Adding a billing period toggle would display options that do not exist. The hardcoded `billingPeriod="monthly"` on AiSubscriptionTierCard already matches the analog's prop shape.
- WHITELIST: [2] Missing isOnLegacyPlan CurrentSubscription banner: No legacy AI credit subscription plans exist. There is no `legacyPlanType` or `isLegacyPlan` equivalent for AI credits. Adding this banner would display dead code that can never render.
- WHITELIST: [6] Has cancel flow (CancelAiCreditSubscriptionConfirmModal + handleCancelClick) vs analog uses Stripe portal: The plan subscription cancel goes through Stripe portal because that is how Stripe plan subscriptions are managed. AI credit subscription cancel uses a dedicated `useCancelAiCreditSubscription` mutation and `CancelAiCreditSubscriptionConfirmModal` because the AI credit subscription cancel endpoint is a separate backend flow. `AccountBillingAiCredits.tsx` also uses the same cancel modal and mutation. Removing the cancel flow would break the AI credit subscription cancellation path.
- WHITELIST: [7] Has dedicated top-up section 'One-time top-up packs' with no analog equivalent: One-time AI credit top-up purchases are a distinct product type with no plan billing equivalent. The analog has no one-off purchase mechanism. Removing this section would remove a functional feature.
- WHITELIST: [10] Collapses subscribed/unsubscribed into one component vs analog splits into separate components: The analog splits into `AccountBillingPlans` (subscribed) and `AccountBillingPlansUnsubscribed` (unsubscribed) with parent `AccountBilling` branching between them. Splitting `AiCreditSubscription` would require creating a new `AiCreditSubscriptionUnsubscribed` file, updating `OrganizationAiBilling` to branch, and redistributing handlers across the two files. This is a large structural refactor that risks introducing bugs in the checkout and top-up flows.
- WHITELIST: [11] PlanBillingCallout instead of AiCreditsCallout: These are intentionally mirrored cross-linking callouts. The analog (plan billing page) shows `AiCreditsCallout` pointing to `/hire/settings/plato-ai/billing`. The AI credit billing page shows `PlanBillingCallout` pointing to `/hire/settings/billing`. Swapping would break the cross-linking navigation.

## Marked for Revert
- REVERT: [12] window.logger tag `[AccountContainer]`: The analog uses `[AccountContainer]` in `handleCreateBillingPortalSession.onSuccess` because the analog was originally written inside `AccountContainer.tsx` and the tag was preserved when the code moved to `AccountBillingPlans.tsx`. Using `[AccountContainer]` in `AiCreditSubscription` is structurally matched but semantically misleading for debugging. Consider reverting to `[AiCreditSubscription]` after the analog review pass is complete.

Files modified:
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/OrganizationAiBilling.tsx`

---

### AiSubscriptionTierCard.tsx

Both the analog parent and the AI credit subscription parent compute `hasCoupon` the same way (short-circuit expression that evaluates to `false | undefined | true`). The analog parent passes this directly to `PlanCard` where it's typed as `hasCoupon: boolean`. The AI credit subscription parent now does the same. This matches the analog exactly -- the type coercion behavior is identical.

Now let me summarize the full results:

## Fixed
- **billingPeriod not passed by parent**: Added `billingPeriod="monthly"` to `AiSubscriptionTierCard` call site in `AiCreditSubscription.tsx` (line 422). AI credit subscriptions are always monthly, so `"monthly"` is the constant equivalent of the analog's dynamic `billingPeriod` state. The `trackEvent` and `window.logger` calls now receive a real value instead of `undefined`.
- **onCreateBillingPortalSession not passed by parent**: Added `onCreateBillingPortalSession={handleCreateBillingPortalSession}` to call site in `AiCreditSubscription.tsx` (line 431). The parent already defined `handleCreateBillingPortalSession` (line 108) but never passed it. `ManageBillingActions` "Manage billing" button would have thrown `TypeError: onCreateBillingPortalSession is not a function` on click.
- **hasCoupon not passed by parent**: Added `hasCoupon={hasCoupon}` to call site in `AiCreditSubscription.tsx` (line 427). The parent already computed `hasCoupon` (line 92) but never passed it. `ManageBillingActions` received `undefined` instead of `false`/`true`.
- **stripePromoCode not passed by parent**: Added `stripePromoCode={currentOrganization.stripePromoCode}` to call site in `AiCreditSubscription.tsx` (line 428). Matches analog pattern `stripePromoCode={currentOrganization.stripePromoCode}`.
- **trackEvent property keys deviate from analog**: Changed `selected_tier_credits` + `selected_tier_lookup_key` to `selected_tier_key` in `AiSubscriptionTierCard.tsx` (line 59). Analog uses `selected_plan_key: plan.key`; the AI credit subscription equivalent is `selected_tier_key: tier.lookupKey` (`lookupKey` is the tier's `key` equivalent). Removed `selected_tier_credits` which has no analog counterpart.
- **window.logger extra `hasActiveSubscription` field**: Removed `hasActiveSubscription` from `window.logger` in `AiSubscriptionTierCard.tsx` (line 69-74). Analog logs `{ plan, isCurrentPlan, currentPlanLookupKey, currentPlanBillingPeriod }` -- ours now logs the equivalent `{ tier, isCurrentPlan, currentTierLookupKey, currentPlanBillingPeriod }`. Also added `currentPlanBillingPeriod="monthly"` to the parent call site (line 425) so this logger field is no longer `undefined`.

## Whitelisted
(none)

## Marked for Revert
- REVERT: `billingPeriod="monthly"` and `currentPlanBillingPeriod="monthly"` hardcoded constants: These are always `"monthly"` for AI credit subscriptions today. If AI credit subscriptions ever gain yearly billing, these should become dynamic state like the analog's `billingPeriod` toggle. The hardcoded values match the analog's structural pattern (parent passes the prop, card uses it) without introducing a toggle that does not exist yet.

Files modified:
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiSubscriptionTierCard.tsx` (trackEvent keys, window.logger fields)
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` (added 5 missing props to call site)
