# AI Credit Billing — Manual QA Guide

Branch: `billing-bonanza` (stash from `ai-feature-work-v5` applied).
Source: code-only analysis (8 investigation agents + 3 scratchpad manifests + open items).
Specs deliberately excluded — Jessica audits those separately.

---

## Prerequisites

- Stripe test-mode keys configured
- At least one org with `stripe_customer_id` set
- At least one org WITHOUT `stripe_customer_id` (for error paths)
- Stripe Price objects created for the lookup keys in `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` (both `plato_ai_credit_*` production keys and `ai_credit_pack_*` dev keys)
- Access to Stripe dashboard to observe invoices/subscriptions/portal sessions

---

## Flow 1: New Subscription Checkout

**Route:** `POST /api/v1/ai_credit_purchases/checkout`
**UI entry:** Tier card click when NOT subscribed (but see caveat below)

### Steps
1. Navigate to `/hire/settings/plato-ai/billing`
2. Confirm no active AI credit subscription exists
3. Click a subscription tier card (e.g. "Plus — 1000/mo")

### Expected behavior
- `handleSelectTier` fires → goes through portal change hooks (NOT the `checkout` endpoint)
- **CAVEAT:** `useCheckoutAiCreditPack` is imported as `subscribe` but has NO visible call site in `AiCreditSubscription.tsx`. The initial subscribe path routes through `handleChangeSubscriptionViaStripePortal` or `handleUpdateWithPaymentMethod`, both of which require an existing subscription with a `stripe_subscription_id`. For a brand-new subscriber, this will fail because there's no purchase record to look up.
- **Test what actually happens:** does the portal session creation error out? Does it silently fail? Does it redirect somewhere?

### What to verify
- [ ] Can a brand-new org (never subscribed) actually subscribe from this UI?
- [ ] If not, is there a separate entry point (e.g. `AccountBillingAiCredits.tsx` which DOES use the `checkout` endpoint)?
- [ ] Check `AccountBillingAiCredits.tsx` at `/hire/settings/billing` — this simpler UI uses `useCheckoutAiCreditPack` and may be the intended entry for first-time subscribers

### Expected Stripe behavior (if checkout works)
- Stripe Checkout session created in `subscription` mode
- `OrganizationAiCreditPurchase` record pre-created with `kind: :subscription`, `amount_cents_paid: 0`
- On successful payment: `checkout.session.completed` webhook stamps `stripe_subscription_id` on the purchase record
- First `invoice.paid` → `handle_subscription_credit_pack_invoice_paid` → `ApplyAiCreditPurchase(kind: :subscription)` → credits granted to `addon_subscription_credits_remaining`

---

## Flow 2: Subscription Tier Change (Card on File)

**Route:** `POST /api/v1/ai_credit_purchases/change_subscription_portal_session`
**UI entry:** Tier card click when subscribed + card on file

### Steps
1. Start with an active AI credit subscription
2. Confirm org has `stripeDefaultPaymentMethodOnFile: true`
3. Click a different tier card (e.g. upgrade from Small to Plus)

### Expected behavior
1. `handleSelectTier` → `handleChangeSubscriptionViaStripePortal`
2. Frontend POSTs `{ priceId, subscriptionItemId, returnUrl: "/hire/settings/plato-ai/billing" }`
3. Controller: authorize → find active/past_due purchase → validate `stripe_subscription_id` present → validate lookup key → `Stripe::BillingPortal::Session.create` with `flow_data.type: 'subscription_update_confirm'`
4. `PosthogTrackJob` fires `'change_subscription_stripe_portal_opened'`
5. Frontend receives `{ redirectUrl }` → `window.location.href` full-page redirect to Stripe Portal
6. User confirms in Stripe Portal → redirected back to `/hire/settings/plato-ai/billing`

### What to verify
- [ ] Portal opens with correct current plan and target plan shown
- [ ] After confirming, `customer.subscription.updated` webhook fires
- [ ] Webhook updates purchase: `stripe_price_lookup_key`, `subscription_credits_per_period`, `subscription_status`, `subscription_current_period_end`
- [ ] UI shows the new tier as "Current plan" after page refresh
- [ ] Current plan detection works (compares `subscription.plan.id` with `tier.priceId`)
- [ ] All tier card buttons disabled during loading (`isLoading` state)

### Known issue: toast text
- `redirectToStripe` fires "Redirecting to Stripe checkout..." before the Billing Portal redirect — "checkout" is wrong for this path (open item D in `ai-credit-open-items.md`)

---

## Flow 3: Subscription Tier Change (No Card on File)

**Route:** `POST /api/v1/ai_credit_purchases/update_payment_method_and_subscription_portal_session` → `GET /api/v1/ai_credit_purchases/continue_change_subscription_portal_session`
**UI entry:** Tier card click when subscribed + NO card on file

### Steps
1. Active AI credit subscription, org with `stripeDefaultPaymentMethodOnFile: false`
2. Click a different tier card

### Expected behavior (two-step portal chain)
1. `handleSelectTier` → no-card branch → `handleUpdateWithPaymentMethod`
2. Frontend POSTs `{ priceId, subscriptionItemId, returnUrl }`
3. Controller creates portal session with `flow_data.type: 'payment_method_update'`, `after_completion.redirect` → `continue_change_subscription_portal_session` GET endpoint with query params
4. User adds payment method in Stripe Portal
5. Stripe redirects to `GET /ai_credit_purchases/continue_change_subscription_portal_session?subscription_item_id=X&target_price_id=Y&return_url=Z`
6. Continue endpoint creates a SECOND portal session for `subscription_update_confirm` and does `redirect_to session.url` (HTTP 302, not JSON)
7. User confirms plan change in second portal
8. Stripe redirects back to `return_url`

### What to verify
- [ ] Two-step flow works end-to-end
- [ ] Payment method gets saved on the Stripe customer
- [ ] Plan change takes effect after the second portal step
- [ ] Error cases: if continue endpoint can't find purchase → redirects to `return_url?error=subscription_update_failed`
- [ ] `continue_change_subscription_portal_session` has NO Pundit authorization — confirm this is acceptable (relies on BaseController auth only)

### Known deviations from analog (from no-card audit)
- Extra `ai_credit_subscription_plan_lookup_key?` validation in `update_payment_method_and_subscription_portal_session` that the analog doesn't have (MED)
- Error toast uses `kind: "warning"` with 10s delay; analog uses `kind: "error"` with no delay
- No `window.logger` calls (analog has three)

---

## Flow 4: One-Off Top-Up (Card on File — Direct Charge)

**Route:** `POST /api/v1/ai_credit_purchases/purchase_top_up`
**UI entry:** "Buy pack" button when card on file

### Steps
1. Org has `stripeDefaultPaymentMethodOnFile: true`
2. Click "Buy pack" on any top-up card

### Expected behavior
1. `PurchaseAiCreditTopUpConfirmModal` opens: "You're paying $X for Y credits. Your card on file will be charged $X today."
2. User clicks "Confirm purchase"
3. Modal closes immediately (before mutation fires — no loading state on confirm button)
4. Controller: pre-creates `OrganizationAiCreditPurchase` (kind: one_off, amount_cents_paid: 0) → calls `purchase.charge_default_payment_method`
5. Model method: double-charge guard (`stripe_invoice_id.present?` → early return) → creates `Stripe::InvoiceItem` with price + metadata → creates `Stripe::Invoice` with metadata → `Stripe::Invoice.pay` → stamps `stripe_invoice_id`, `amount_cents_paid`, `currency` via `update_columns`
6. Controller returns `{ charged: true }` (no `redirectUrl`)
7. Frontend shows toast: "Payment received — your credits will appear shortly."
8. Meanwhile, `invoice.paid` webhook fires → metadata `ai_credit_pack_top_up: 'true'` → `ApplyAiCreditPurchase(kind: :one_off)`
9. Interactor: finds purchase by `organization_ai_credit_purchase_id` from metadata → grant-once guard (ledger row exists?) → creates `AiCreditBalanceTransaction` (entry_type: `one_off_credit_pack_purchase_credit`, bucket: `addon`, amount: `one_off_credits_granted`) → resets low/zero notification flags
10. `counter_culture` auto-increments `addon_credits_remaining` on balance

### What to verify
- [ ] Confirm modal appears with correct dollar amount and credit count
- [ ] Stripe invoice created and paid in test dashboard
- [ ] Credits appear in `addon_credits_remaining` (not other buckets)
- [ ] Balance UI updates — **NOTE:** there's an async timing gap. The mutation resolves BEFORE the webhook grants credits. React Query invalidation of `organizationAiCreditBalance` fires on mutation success, but the balance hasn't been updated yet. May need a manual refresh to see credits.
- [ ] Double-click protection: all pack buttons share `isPurchasing` loading state
- [ ] Buying a second pack: second purchase gets its own record, own ledger entry
- [ ] Double-delivery: if `invoice.paid` fires twice, grant-once guard prevents double credit

### Known gaps vs WWR analog
- **MISSING intermediate marker:** WWR has `stripe_invoice_paid` (three-state: charged → payment-confirmed → fulfilled). Ours has two states only (charged via `stripe_invoice_id`, granted via ledger row existence). If webhook never arrives, the row can't distinguish "charge initiated" from "payment confirmed by Stripe."
- **MISSING post-grant notification:** WWR fires `Notification::PaidWwrListingCreatedJob`. No equivalent notification here.
- **No real-time broadcast:** WWR broadcasts via `JobChannel`. Ours relies on React Query invalidation, which fires before the webhook has granted credits.

---

## Flow 5: One-Off Top-Up (No Card — Stripe Checkout)

**Route:** `POST /api/v1/ai_credit_purchases/purchase_top_up`
**UI entry:** "Buy pack" button when NO card on file

### Steps
1. Org with `stripeDefaultPaymentMethodOnFile: false`
2. Click "Buy pack" on any top-up card

### Expected behavior
1. NO confirm modal (modal only shows when card on file)
2. `purchaseTopUp` fires immediately
3. Controller: pre-creates purchase → creates `Stripe::Checkout::Session` (mode: payment, invoice_creation: enabled, metadata with `organization_ai_credit_purchase_id` + `ai_credit_pack_top_up: 'true'`) → updates purchase with `stripe_checkout_session_id` → returns `{ redirectUrl }`
4. Frontend receives `redirectUrl` → `window.location.href` redirect to Stripe Checkout
5. Customer pays on Stripe → `invoice.paid` webhook → same grant path as Flow 4

### What to verify
- [ ] No confirm modal appears (skipped when no card)
- [ ] Redirect to Stripe Checkout works
- [ ] After payment, credits granted to `addon_credits_remaining`
- [ ] The pre-created purchase record has `stripe_checkout_session_id` stamped
- [ ] The `invoice.paid` handler finds the purchase via metadata `organization_ai_credit_purchase_id` (primary), with fallbacks to `checkout_session_id` and `invoice_id`

### Known bug: `checkout.session.completed`
- The `checkout.session.completed` handler has no `ai_credit_pack_top_up` early-return guard. A top-up checkout completion falls through to the main-plan branch and silently swallows a `NoMethodError`. This is a pre-existing bug (open item 3). Credits still get granted via `invoice.paid`, but the `checkout.session.completed` handler errors silently.

---

## Flow 6: Cancel Subscription

**Route:** `PUT /api/v1/ai_credit_purchases/cancel`
**UI entry:** Cancel button in subscription status banner

### Steps
1. Active AI credit subscription
2. Click "Cancel subscription" in the status banner
3. `CancelAiCreditSubscriptionConfirmModal` opens with period end date
4. Confirm

### Expected behavior (CURRENT — known incomplete)
- `CancelAiCreditSubscription.call(purchase:)` runs
- Purchase row flipped to `subscription_status: :canceled`, `subscription_canceled_at` set
- `#show` filter `[:active, :past_due]` drops the purchase → UI shows "No active subscription"

### What to verify
- [ ] Cancellation works and UI updates
- [ ] Stripe subscription actually cancelled via API

### Known issue: cancel-at-period-end NOT built
- The `stripe_cancel_at_period_end` column exists but the behavior is not implemented
- Current behavior: eagerly flips to `:canceled` immediately, even though the Stripe subscription is active until period end
- Customer loses their subscription display immediately even though they've paid through the period
- Full remediation plan in `ai-credit-cancel-at-period-end-migration-plan.md`

---

## Flow 7: Subscription Renewal (Webhook-Only)

**Trigger:** Stripe fires `invoice.paid` at period end for the subscription
**No UI entry — automated**

### Expected behavior
1. `invoice.paid` webhook → retrieve subscription → lookup key check → `handle_subscription_credit_pack_invoice_paid`
2. Find purchase by `stripe_subscription_id` + `kind: :subscription`
3. Stamp `amount_cents_paid` and `currency` from invoice
4. `ApplyAiCreditPurchase(kind: :subscription, invoice:, price:)`
5. Invoice dedup guard: `existing.stripe_invoice_id == invoice.id` → skip if same
6. Update purchase: `subscription_status: :active`, period start/end, stamp `stripe_invoice_id`
7. Create ledger entry: `subscription_credit_pack_purchase_credit`, bucket: `addon_subscription`, amount: `subscription_credits_per_period`
8. Reset notification flags

### What to verify
- [ ] Fresh credits granted each period in `addon_subscription_credits_remaining`
- [ ] Old period's remaining addon_subscription credits: NOT reset by renewal (counter_culture only adds)
- [ ] Duplicate invoice delivery: second delivery silently returns (dedup guard)

### Silent failure risk
- `handle_subscription_credit_pack_invoice_paid` does `return unless existing` with **NO logging**. If the purchase can't be found (race with `checkout.session.completed`), credits are silently never granted and no error is recorded anywhere.
- `ApplyAiCreditPurchase.call` return value is not checked by the webhook handler. If the interactor fails (e.g. missing balance), the purchase gets `amount_cents_paid`/`currency` stamped but credits are never granted — no error surfaced.

---

## Flow 8: `customer.subscription.updated` (Webhook-Only)

**Trigger:** Stripe fires after plan change confirmation in portal

### Expected behavior
1. Read `plan_lookup_key = object.items.data.first.price.lookup_key`
2. If `ai_credit_subscription_plan_lookup_key?(plan_lookup_key)` → credit-pack branch
3. Find purchase by `stripe_subscription_id` + `kind: :subscription`
4. Update: `stripe_price_lookup_key`, `subscription_credits_per_period` (from `ai_credit_allocation_for_lookup_key`), `subscription_status`, `subscription_current_period_start`, `subscription_current_period_end`
5. Does NOT call `sync_with_stripe` (which rejects credit subscriptions)
6. Does NOT touch org main-plan fields

### What to verify
- [ ] After plan change, purchase row reflects new tier
- [ ] `subscription_credits_per_period` matches the new tier's allocation
- [ ] Org's main subscription fields untouched
- [ ] An org with ONLY a credit subscription (no main plan) doesn't hit `CustomStripeSubscriptionMissingError` (guard is below the credit-pack branch)

---

## Flow 9: Prices and Customer Subscription Queries

### Prices (`GET /ai_credit_purchases/prices`)
- Returns raw Stripe Price list for all lookup keys in `ai_credit_lookup_keys`
- Any org user can access (not admin-only)
- `refetchOnWindowFocus: false`

### Customer Subscription (`GET /ai_credit_purchases/customer_subscription`)
- Returns raw Stripe Subscription object with expanded items/prices/tiers
- Used for `currentSubscriptionItemId` extraction and current-plan detection
- **No Pundit authorization** — any authenticated user
- Returns `{ subscription: nil }` if no active purchase or no `stripe_subscription_id`

### What to verify
- [ ] Prices endpoint returns all configured prices (dev + production keys)
- [ ] Customer subscription returns the live Stripe subscription with `items.data[0].id` populated
- [ ] Plan detection: `subscription.plan.id === tier.priceId` correctly identifies current plan

---

## Cross-Cutting Concerns

### Authorization gaps
Two endpoints have NO Pundit authorization (BaseController auth only):
- `customer_subscription` — reads Stripe data, no mutations
- `continue_change_subscription_portal_session` — creates a portal session and redirects

Both are likely acceptable (read-only / Stripe-gated), but worth noting.

### Race conditions
- **TOCTOU on grant-once guard:** Application-level check (`ai_credit_balance_transactions.exists?`) with no DB-level unique constraint. Concurrent webhook deliveries could theoretically double-grant.
- **TOCTOU on double-charge guard:** `charge_default_payment_method` checks `stripe_invoice_id.present?` then stamps via `update_columns`. No DB-level uniqueness on `stripe_invoice_id`.
- **Checkout → first invoice race:** If `invoice.paid` fires before `checkout.session.completed` stamps `stripe_subscription_id`, `handle_subscription_credit_pack_invoice_paid` silently returns with no logging.

### Error swallowing
- All webhook event handlers rescue `StandardError` and swallow (log only, no re-raise)
- `ApplyAiCreditPurchase` failures (`context.fail!`) are not checked by the webhook handler
- `charge.refunded` → `ApplyAiCreditRefund` failures similarly unchecked

### DB constraint vs model validation mismatch
- `amount_cents_paid` is `NOT NULL` at DB level
- Model validation conditionally skips for pre-checkout subscriptions (`unless subscription? && stripe_subscription_id.blank?`)
- Controller passes `amount_cents_paid: 0` to satisfy the DB constraint

### Frontend credits mismatch (VERIFY)
- Frontend `planHelpers.ts`: medium subscription = 1250 credits
- Backend production keys: `plato_ai_credit_subscription_medium` = 1000 credits
- The credit count displayed in the UI may not match what's actually granted

### Two billing UIs
- `AiCreditSubscription.tsx` at `/hire/settings/plato-ai/billing` — full-featured, card-on-file branching, portal-based changes
- `AccountBillingAiCredits.tsx` at `/hire/settings/billing` — simpler, all purchases redirect to Stripe Checkout, uses `useCheckoutAiCreditPack` for initial subscribe
- These may serve different entry points intentionally, but verify they don't conflict

---

## Known Open Items (from `ai-credit-open-items.md`)

1. **Cancel-at-period-end** — column exists, behavior not built
2. **Finalization marker** — one-off grant guard relies on ledger row but `organization_ai_credit_purchase` association is `optional: true`
3. **`checkout.session.completed` bug** — missing top-up early-return guard (pre-existing)
4. **Cleanup** — `charged?: boolean` unused in response type; fallback lookups unreachable in interactor
5. **Cancellation modal** — deferred, do not discuss
