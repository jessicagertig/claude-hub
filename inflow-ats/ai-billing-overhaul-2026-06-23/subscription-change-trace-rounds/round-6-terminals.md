# Round 6 — TERMINALS segment audit

Segment: every SCREEN render terminal, every STRIPE call (+ exact args), and every DATABASE read/write in the analog subscription-change flow. Audited against the actual code in `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.

## Verification summary (chains traced to terminal)

SCREEN terminals — all verified correct:
- `AccountBillingPlans.tsx` → trialing block `:370-382`, cancelAtPeriodEnd `:384-396`, legacy-plan raw interval `:408`/`:413`, `Free for ${trialEndDays}` `:415`, hasCoupon `{coupon.percentOff}% off until {prettyDate(discount.end)}` `:429` (block `:424-431`), early-return `<LoadingIndicator>` `:352-354`, PlanChangeBlockedModal `openModal(modal)` `:348`, onSuccess redirects `:263`/`:303`, onError addToast `:265-274`/`:305-314`.
- `PlanCard.tsx` → branch `:199`, ManageBillingActions `:200-205`, change `Styled.Button` `:207-214` with `loading={isLoadingButton}` `:209`, `disabled={isLoading}` `:210`, `styleType={plan.buttonType || "secondary"}` `:211`, `{plan.buttonText}` `:213`.
- `planLookups.js` getPlansForPeriod `: 0` fallback `:564`, `priceId` `:568`, `lookupKey` `:569`, `key` `:571`.
- `AccountBilling.tsx` 3-way ternary `:122-134`, billingPrices `[]` fallback `:54`.
- Controller renders: `prices` `:540`, `customer_subscription` nil `:611` / happy `:614` / error `:618`, change `render json: { redirectUrl: session.url }` `:313`, payment-method `:367`, continue `redirect_to session.url` `:457` and `?error=` redirects `:392`/`:397`/`:411`/`:427`/`:463`/`:469`.

STRIPE terminals — all verified correct (file:line + args):
- `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })` `organization.rb:477`.
- `Stripe::Subscription.list({ customer: stripe_customer_id, limit: 3, status: 'all' })` `organization.rb:482`.
- `Stripe::Customer.retrieve({ id: stripe_customer_id, expand: ['subscriptions'] })` `organization.rb:471`.
- `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })` `billing_controller.rb:537`.
- `Stripe::Price.list({ active: true, limit: 10, expand: ['data.tiers'] })` `billing_controller.rb:634` (find `:637`).
- `Stripe::Price.retrieve(target_price_id)` `validate_subscription_change.rb:15`.
- `Stripe::BillingPortal::Session.create(options)` `billing_controller.rb:306` (change), `:363` (payment-method), `:452` (continue).

DATABASE terminals — all verified correct:
- READ: `organization.jobs.where(status: 'published').count` `validate_subscription_change.rb:42` (jobs/status); `organization.stripe_subscription_status.present?` `validate_subscription_change.rb:58`; `User.find_by(id: user_id)` `posthog_track_job.rb:7` (users).
- WRITE: `update(changes_to_make)` `organization.rb:600` (organizations row; superset cols `plan` `:573` unconditional, `stripe_default_payment_method_on_file` `:580` unconditional, `stripe_subscription_id`/`stripe_subscription_status`/`stripe_current_period_end_at` conditional `:567-571`); `organization_ai_credit_balance.update_columns(monthly_credits_remaining: ...)` `organization.rb:605` (organization_ai_credit_balances). Schema: `organizations.plan` default 101 `db/schema.rb:1052`, `stripe_subscription_id` `db/schema.rb:1056`, `stripe_default_payment_method_on_file` default false `:1066`, `stripe_subscription_status` `:1065`, `stripe_current_period_end_at` `:1058`.

The trace's terminal mapping is essentially exact. Only one minor line-precision imprecision found, and it is NOT on the live change-flow path (it lives in the price-model reference table).

---

## Discrepancy 1 (MINOR — line precision, off-path)

TRACE SAYS: price-model table row "backend priceId → lookup_key (round-trip Stripe)" cites `determine_lookup_key` as `(price[:lookup_key])` at `billing_controller.rb:663`.

ACTUAL CODE: `billing_controller.rb:663` is only the `def determine_lookup_key` line. The actual `lookup_key` read is `product_info[:price][:lookup_key]` at `billing_controller.rb:667` (not `price[:lookup_key]` — the value is read off `product_info[:price]`, the hash built by `get_product_from_price_id` at `:657-660`, not a bare `price` local). The Stripe read in this chain is `Stripe::Price.retrieve({ id: price_id, expand: ['product'] })` at `billing_controller.rb:652` (inside `get_product_from_price_id` `:649`), which the trace folds into the `:649` citation.

file:line: `app/controllers/api/v1/billing_controller.rb:663` (def) vs `:667` (actual lookup_key read) / `:652` (actual Stripe retrieve).

Note on severity: this entire `determine_product_info → get_product_from_price_id → determine_lookup_key` chain is part of the price-model REFERENCE table, not a terminal on the `change_subscription_portal_session` happy path (none of these three methods is invoked by the change action). The expression shorthand (`price[:lookup_key]`) and the def-line citation are imprecise but do not misidentify any live terminal.
