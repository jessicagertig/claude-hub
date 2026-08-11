# AI Credit Billing Overhaul

## Summary

Complete overhaul of the Plato AI credit billing system. Replaces portal-based subscription changes with a custom in-app upgrade/downgrade flow. Adds a Stripe sync service for reconciliation. Redesigns all confirmation modals. Adds cancel/revert cancellation, scheduled downgrade management, and one-off purchase previews. Refactors ManageBillingActions to be self-contained.

This branch introduces several capabilities that do not exist in the regular Plan & Billing flow:

- **Stripe sync service** — reconciles local purchase records and credit grants against Stripe's actual state on every page load, catching missed webhooks
- **Scheduled downgrade management** — uses `Stripe::SubscriptionSchedule` to defer downgrades to period end, with a visible callout and "Don't downgrade plan" reversal
- **Invoice-based credit granting** — uses `billing_reason` on `invoice.paid` to distinguish renewals, upgrades, and first invoices, granting the correct credit amount for each
- **Grant idempotency via metadata** — stores `stripe_invoice_id`, `stripe_subscription_id`, and `billing_reason` on every `AiCreditBalanceTransaction` for exact deduplication
- **One-off purchase preview** — fetches payment method (brand + last4) before showing the confirmation modal, even though one-off charges don't use `Invoice.upcoming`

## What changed

### Custom upgrade/downgrade flow
- **Upgrade:** `preview_subscription_change` calls `Stripe::Invoice.upcoming` with `subscription_items` to preview proration. User sees new plan price, credit for current plan, amount due today, and card on file. On confirm, `update_ai_credit_subscription` calls `Stripe::Subscription.update`. Upgrade vs downgrade determined by comparing `unit_amount` on the Stripe prices.
- **Downgrade:** creates a `Stripe::SubscriptionSchedule` (current plan until period end, then new plan). If a schedule already exists with 1 phase (orphan from a prior failed attempt), releases it first. If 2+ phases exist, returns "A change is already scheduled for this subscription."
- **Scheduled change callout:** when a schedule exists with 2+ phases, a gray callout appears below the subscription banner: "Your plan will be downgraded from [current] to [target] on [date]." with a "Don't downgrade plan" button that releases the schedule.
- Replaces three portal-based controller actions with `preview_subscription_change` and `update_ai_credit_subscription`

### Credit granting
- **`ApplyAiCreditSubscription`** (renamed from `ApplyAiCreditPurchase`) — handles `subscription_create` and `subscription_cycle` invoices
- **`ApplyAiCreditUpgrade`** — handles `subscription_update` invoices. Extracts old/new lookup keys from invoice line items, grants the difference
- **`billing_reason` routing** in `handle_subscription_credit_pack_invoice_paid` — `subscription_update` routes to `ApplyAiCreditUpgrade`, everything else to `ApplyAiCreditSubscription`
- All grant transactions now store `{ stripe_invoice_id, stripe_subscription_id, billing_reason }` in the `metadata` jsonb column
- Credits only granted on `invoice.paid`, never on `customer.subscription.updated`

### Stripe sync service
- `SyncAiCreditPurchasesWithStripe` — service class with `sync_ai_credits_with_stripe` entry point
- **Subscriptions:** fetches all Stripe subscriptions for the customer (own call, `limit: 10`, not using `stripe_customer_subscriptions`), filters to credit/plato, matches each to local purchase. Orphan matching uses `Stripe::Checkout::Session.list(subscription:)` to find the checkout session ID, not `created_at` ordering. Reconciles status, lookup key, period dates, `cancel_at_period_end`. Checks paid invoices for missing grants using `metadata->>'stripe_invoice_id'` for deduplication.
- **One-offs:** checks local purchase records for missing grants (entry type exists with `amount > 0`)
- Runs on `customer_subscription` page load (via job, skipped in test mode), and directly from `customer.subscription.updated` and `customer.subscription.deleted` webhook handlers
- Organization instance method `sync_ai_credits_with_stripe` as the entry point, delegating to the service

### Cancel / revert cancellation
- **Cancel:** `CancelAiCreditSubscription` interactor now sets `stripe_cancel_at_period_end: true` only — no longer sets `subscription_status: :canceled` or `subscription_canceled_at` (those come from the `customer.subscription.deleted` webhook when Stripe actually cancels)
- **Revert cancellation:** `revert_cancellation` endpoint sets `cancel_at_period_end: false` on Stripe and locally
- **Webhook handler:** `customer.subscription.updated` now includes `stripe_cancel_at_period_end: object.cancel_at_period_end` in the credit subscription branch (was missing)
- **UI:** cancel button moved to current plan tier card. "Manage billing" in the subscription banner. "Don't cancel subscription" button when cancellation is scheduled. All state-dependent.

### Confirmation modals (redesigned)
- **`UpdateAiCreditSubscriptionConfirmModal`** — upgrade shows plan price, credit for current, total, amount due today, card info with tooltip. Downgrade shows scheduled message, new price, card info.
- **`PurchaseAiCreditTopUpConfirmModal`** — credits, amount due, payment method with tooltip, terms of service
- **`CancelAiCreditSubscriptionConfirmModal`** — plan name, calendar callout with non-renewal date, primary confirm button
- All modals: card display as "Visa •••• 4242", info icon with tooltip "To add a new payment method, go to Manage Billing.", terms link to `https://polymer.co/terms` and `https://polymer.co/privacy`

### ManageBillingActions refactor
- Owns `useCreateStripeCustomerPortalSession` internally — takes `returnUrl` prop instead of `onCreateBillingPortalSession` callback
- Parent components no longer thread the callback through
- Used in both Plan & Billing and AI Billing sections

### One-off purchase preview
- `preview_top_up` endpoint — retrieves the `Stripe::Price` for the amount and the customer's default payment method for card info. Does NOT use `Invoice.upcoming` (which merges with the subscription's upcoming invoice). Returns `amount_due`, `currency`, `credits`, `default_payment_method`.
- Frontend calls preview before showing the top-up confirm modal

### Checkout session fix
- Checkout now matches the billing controller's structure: `default_options` + `subscription_options` merged, `customer_email` when no Stripe customer exists, `subscription_data` with metadata
- All callback URLs point to `/hire/settings/plato-ai/billing`
- `OrganizationAiBilling` handles success URL params (`ai_credit_subscribe_success`, `ai_credit_top_up_success`) with query invalidation on return from Stripe

### Renames
- `ApplyAiCreditPurchase` → `ApplyAiCreditSubscription`
- `AiCreditPackCard` → `AiCreditOneOffCard`, prop `pack` → `purchase`
- `useCheckoutAiCreditPack` → `useCheckoutAiCreditTopUp`
- `commit_subscription_change` → `update_ai_credit_subscription`
- Entry type enums: `one_off_credit_pack_*` → `ai_credit_one_off_*`, `subscription_credit_pack_*` → `ai_credit_subscription_*`
- `handleBuyPack` → `handleBuyAiCreditTopUp`
- Subtitle: "One-time top-up packs" → "One-time AI credit purchases"
- Button: "Buy pack" → "Buy credits"

### Other changes
- `AccountBillingAiCredits.tsx` deleted
- `finalize_stripe_payment` changed from `update_columns` to `update` (participates in transactions)
- `ActiveRecord::Base.transaction` used instead of `ApplicationRecord.transaction`
- All `AiCreditBalanceTransaction` creation uses `.build` through the association
- Read-only `before_update`/`before_destroy` callbacks removed from `AiCreditBalanceTransaction`
- `formatCents` moved to `aiSubscriptionHelpers.ts`
- `deriveTierButtonText` and `isDowngrade` compare by price, not credits
- All toasts at `delay: 30000`
- Subscription banner `max-width: 755px`
- Failure pattern #25 added to CLAUDE.md: do not use `update_columns` inside transactions
- Sync job skipped in test mode to avoid blocking Cypress
- Cypress test updated for new UI text

## Files (52 changed, +3644 / -603)

### New files
- `app/interactors/apply_ai_credit_upgrade.rb`
- `app/services/sync_ai_credit_purchases_with_stripe.rb`
- `app/jobs/sync_ai_credit_purchases_with_stripe_job.rb`
- `app/javascript/.../UpdateAiCreditSubscriptionConfirmModal.tsx`
- `app/javascript/.../AiCreditOneOffCard.tsx`
- `spec/interactors/apply_ai_credit_upgrade_spec.rb`
- `spec/controllers/.../organization_ai_credit_purchases_subscription_change_spec.rb`
- `cypress/e2e/plans-and-billing/ai-credit-subscription-display.cy.js`

### Deleted files
- `app/javascript/.../AccountBillingAiCredits.tsx`
- `app/javascript/.../AiCreditPackCard.tsx` (renamed to AiCreditOneOffCard)
- `app/interactors/apply_ai_credit_purchase.rb` (renamed to ApplyAiCreditSubscription)

## Test plan
- [x] Upgrade flow: preview shows correct amounts, confirm charges the difference
- [x] Downgrade flow: schedules change at period end, callout appears, "Don't downgrade plan" reverses it
- [x] Cancel subscription: sets `cancel_at_period_end`, doesn't set status to canceled
- [x] Revert cancellation: clears `cancel_at_period_end`, subscription stays active
- [x] One-off purchase: preview shows correct price and card info, purchase charges correctly
- [x] Stripe sync: detects and grants missing credits, handles orphan purchases via checkout session matching
- [x] ManageBillingActions: works in Plan & Billing and AI Billing sections
- [x] Cypress test passes
- [ ] Webhook: verify `billing_reason` routing with real upgrade (subscription_update → ApplyAiCreditUpgrade)
- [ ] Webhook: verify renewal grants correct credits (subscription_cycle → ApplyAiCreditSubscription)
- [ ] Edge case: existing schedule with 2 phases blocks new downgrade
- [ ] Edge case: orphan schedule (1 phase) gets released before new downgrade
