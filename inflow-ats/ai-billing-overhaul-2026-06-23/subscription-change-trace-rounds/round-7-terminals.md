# Round 7 — TERMINALS segment audit (SCREEN / STRIPE / DATABASE)

Audited segment: every point data reaches the SCREEN (AccountBillingPlans/PlanCard render), goes to STRIPE (each `Stripe::` call + exact args), or touches the DATABASE (each column read/written, e.g. in `sync_with_stripe`).

Worktree audited: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`

## Files traced

- `AccountBilling.tsx` → `AccountBillingPlans.tsx` → `PlanCard.tsx` → `planLookups.js` (SCREEN terminals)
- `useBilling.ts` (mutation/query hooks, screen-redirect + DEBUG terminals)
- `config/routes.rb` (route lines)
- `billing_controller.rb` (`customer_subscription`, `prices`, `change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `continue_change_subscription_portal_session`, `determine_price_id`) — STRIPE + SCREEN terminals
- `organization.rb` (`stripe_subscription`, `stripe_customer`, `stripe_customer_subscriptions`, `sync_with_stripe`, `assign_plan_name_from_lookup_key`) — STRIPE + DATABASE terminals
- `validate_subscription_change.rb` — STRIPE read + DATABASE read (`jobs.where(status:'published').count`)
- `posthog_track_job.rb` — DATABASE read (`User.find_by`)
- `plan_feature_gate.rb` (`monthly_ai_credit_allocation`) — feeds DATABASE write
- `subscription_status_checker.rb` (`assign_plan_from_lookup_key`)
- `db/schema.rb` (`plan`, `stripe_subscription_id`, `stripe_subscription_status`, `stripe_current_period_end_at`, `stripe_default_payment_method_on_file` columns)

## Terminal claims verified — all SAME

SCREEN terminals:
- Trialing block `AccountBillingPlans.tsx:370-382`; cancelAtPeriodEnd `:384-396`; legacy interval render `:408`/`:413`; `Free for ${trialEndDays}` `:415`; coupon `{coupon.percentOff}% off until {prettyDate(discount.end)}` `:429` (block `:424-432`) — SAME.
- `isCurrentPlan` `:436`; `<PlanCard>` element `:439-456`; props `isCurrentPlan` `:443`, `subscriptionItemId` `:449` (dead prop), `isLoading` `:450-452`, `isLoadingButton` `:453`, `onChangeSubscription` `:455` — SAME.
- Early-return `<LoadingIndicator label="Loading..." />` `:352-354` — SAME.
- `PlanChangeBlockedModal` assigned to `const modal` `:340-347` then `openModal(modal)` `:348` — SAME.
- onSuccess `window.location.href = data.redirectUrl` portal `:303` / payment-method `:263`; onError `addToast` portal `:305-314` / payment-method `:265-274` — SAME.
- PlanCard: `showCurrentPlanBadge` `:160`; `<SavingsBadge>Current plan</SavingsBadge>` `:167`; savings Tooltip `You are saving ${savings} per year` `:168-176` (`:170`); `Save ${savings}/year` `:177-179` (`:178`); `${displayPrice}` `:183`; button branch `:199`; `ManageBillingActions` `:200-205`; change `Styled.Button` `:207-214` with `onClick` `:208`, `loading={isLoadingButton}` `:209`, `disabled={isLoading}` `:210`, `styleType` `:211`, `{plan.buttonText}` `:213` — SAME. `subscriptionItemId?` declared `PlanCard.tsx:71`, absent from destructure `:75-89` (dead prop) — SAME.
- planLookups SCREEN feeders: `price: priceData ? priceData.unitAmount/100 : 0` `:564`; `getPlanButtonType` def `:578`; `getPlanButtonText` def `:594` — SAME.
- `render json: { redirectUrl: session.url }` (portal `:313`, payment-method `:367`); `redirect_to session.url` (continue `:457`); `render json: { subscription: ... }` (`customer_subscription` `:611`/`:614`/`:618`) — SAME.
- prices `render json: price_list` `:540`; `AccountBilling.tsx` unwrap `billingPricesData.data` with `[]` fallback `:54`; 3-way ternary `:122-134`, AccountBillingPlans `:128-134` — SAME.

STRIPE terminals (call + exact args):
- `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })` `organization.rb:477` — SAME.
- `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })` `billing_controller.rb:537` — SAME.
- `Stripe::Price.list({ active: true, limit: 10, expand: ['data.tiers'] })` `billing_controller.rb:634` — SAME.
- `Stripe::BillingPortal::Session.create(options)` `:306` (portal), `:363` (payment-method), `:452` (continue) — SAME.
- `Stripe::Subscription.list({ customer: stripe_customer_id, limit: 3, status: 'all' })` `organization.rb:482` — SAME.
- `Stripe::Customer.retrieve({ id: stripe_customer_id, expand: ['subscriptions'] })` `organization.rb:471` — SAME.
- `Stripe::Price.retrieve(target_price_id)` `validate_subscription_change.rb:15` — SAME.

DATABASE terminals:
- READ `organization.jobs.where(status: 'published').count` `validate_subscription_change.rb:42` (jobs table, status column) — SAME.
- READ `User.find_by(id: user_id)` `posthog_track_job.rb:7` (users table) — SAME.
- WRITE `update(changes_to_make)` `organization.rb:600` (organizations row); column superset `plan` `:573`, conditional trio `stripe_subscription_id`/`stripe_subscription_status`/`stripe_current_period_end_at` `:567-571`, `stripe_default_payment_method_on_file` `:580`; diff-build `:585-595` — SAME.
- WRITE `organization_ai_credit_balance.update_columns(monthly_credits_remaining: new_allocation)` `organization.rb:605`, gated `:603`, allocation via `PlanFeatureGate#monthly_ai_credit_allocation` `plan_feature_gate.rb:134` — SAME.
- Schema: `plan` integer default 101 `db/schema.rb:1052`; `stripe_subscription_id` `:1056`; `stripe_subscription_status` `:1065`; `stripe_current_period_end_at` `:1058`; `stripe_default_payment_method_on_file` default false `:1066` — SAME.

## Result

No discrepancies found for the TERMINALS segment. Every SCREEN-render point, every `Stripe::` call with its exact args, and every DATABASE column read/written named in the trace matches the actual analog code in the audited worktree, identifier by identifier, line by line, to terminal.
