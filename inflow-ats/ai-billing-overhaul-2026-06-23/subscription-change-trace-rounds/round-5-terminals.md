# Round 5 — TERMINALS segment audit (subscription-change analog trace)

Scope: every point data reaches the SCREEN, goes to STRIPE, or touches the DATABASE. Verified identifier-by-identifier against the real analog code in `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.

Chains traced to terminal:
- SCREEN/prices: `AccountBilling.tsx:50/54/122-134` → `AccountBillingPlans.tsx` → `useBillingPrices`/`useStripeCustomerSubscription` (`useBilling.ts:245/266`) → `getPrices`/`getStripeCustomerSubscription` (`useBilling.ts:98/102`) → `apiGet` (`api.ts:5/22`) → routes (`routes.rb:174/177`) → `BillingController#prices`/`#customer_subscription` (`billing_controller.rb:535/606`) → STRIPE `Stripe::Price.list` (`:537`) / `Organization#stripe_subscription` (`organization.rb:474/477` → `Stripe::Subscription.retrieve`).
- SCREEN render: `AccountBillingPlans.tsx:175/177-179/435-457` → `PlanCard.tsx:98/151/199/207-214` (`loading=:209`, `disabled=:210`).
- CHANGE→STRIPE: `handleChangeSubscriptionWithGate` (`:322/326`) → portal `:283-317` / payment-method `:243-278` → `apiPost`→`apiMutate` (`api.ts:25-68`) → routes (`routes.rb:169/170/178`) → `BillingController#change_subscription_portal_session` (`:268`, STRIPE `:306`) / `#update_payment_method_and_subscription_portal_session` (`:331`, STRIPE `:363`) / `#continue_change_subscription_portal_session` (`:385`, STRIPE `:452`).
- VALIDATION→DB/STRIPE: `ValidateSubscriptionChange` (`:6`) → STRIPE `Stripe::Price.retrieve` (`:15`) → `Organization#assign_plan_name_from_lookup_key` (`organization.rb:678`) → `Stripe::SubscriptionStatusChecker#assign_plan_from_lookup_key` (`:113`) → `PlanFeatureGate.all_plan_rules` (`:72`) → DB `organization.jobs.where(status: 'published').count` (`:42`).
- POSTHOG→DB: `PosthogTrackJob#perform` (`posthog_track_job.rb:6`) → DB `User.find_by(id: user_id)` (`:7`).
- SYNC→DB/STRIPE (return-path terminal): `Organization#sync_with_stripe` (`organization.rb:520`) → STRIPE `stripe_customer_subscriptions`/`stripe_customer` (`:482/471`) → DB `update(changes_to_make)` (`:600`) + `organization_ai_credit_balance.update_columns` (`:605`).

Verdict: the trace is essentially correct for the terminals segment. Every SCREEN, STRIPE, and DATABASE terminal is named with the correct file:line, identifier, and Stripe args. Only two minor terminal-PRECISION imprecisions found (both LOW); no false or omitted terminal, no wrong-terminal classification.

---

## Discrepancy 1 (LOW — terminal precision: DB write column set overstated as unconditional)

TRACE SAYS (item at trace line 119): "`:600` `update(changes_to_make)` (DATABASE write — `organizations` row: `plan`, `stripe_subscription_status`, `stripe_subscription_id`, `stripe_current_period_end_at`, `stripe_default_payment_method_on_file`)" — presenting all five columns as the write set without qualification.

ACTUAL CODE: in `sync_with_stripe`, only `plan` (`organization.rb:573`) and `stripe_default_payment_method_on_file` (`:580`) are added to `attributes` unconditionally. `stripe_subscription_id`, `stripe_subscription_status`, and `stripe_current_period_end_at` are added ONLY inside `if current_subscription.present?` (`:567-571`). Furthermore `update(changes_to_make)` (`:600`) writes only the keys that actually differ from the current value (the `attributes.each`/`changes_to_make` diff at `:585-595`), so the realized DB write is a subset, never guaranteed to include all five.

file:line — `organization.rb:567-571` (conditional trio) vs `:573/:580` (unconditional pair); diff-gating at `:583-600`.

Note: the trace's list is accurate as the SUPERSET of columns that CAN be written, so this is precision, not a false claim — flagged LOW because a replicator reading "writes these 5 columns" could wrongly assume all five are always written.

---

## Discrepancy 2 (LOW — terminal precision: continue-action rescue `return_url` may be nil at the StandardError/Stripe rescue when an early guard fired)

TRACE SAYS (trace lines 56-64, item 18b continue action): the method rescues "`rescue Stripe::InvalidRequestError => e` (`:458`) ... → `redirect_to \"#{return_url}?error=subscription_update_failed\"` (`:463`); `rescue StandardError => e` (`:464`) ... → `redirect_to \"#{return_url}?error=subscription_update_failed\"` (`:469`)" — presenting `return_url` as the SCREEN-redirect terminal value for both method rescues without noting it can be unassigned.

ACTUAL CODE: `return_url` is a local assigned at `continue_change_subscription_portal_session` `:403-407`, AFTER the two early customer/subscription blank guards (`:390-398`) which redirect using RAW `params[:return_url]` (the trace does capture those two correctly). The method-level `rescue` blocks at `:458/:464` reference the `return_url` local at `:463/:469`; if an exception were raised before `:403` executes, `return_url` would be `nil` in the rescue and the redirect terminal becomes `"?error=subscription_update_failed"` (host-relative). The trace presents `return_url` at `:463/:469` as always the computed value. file:line — `billing_controller.rb:403-407` (assignment) vs `:463/:469` (rescue use).

Note: in practice the guarded code between `:403` and `:457` is what can raise into these rescues, so `return_url` is typically assigned; flagged LOW as a completeness note on the redirect SCREEN terminal, not a wrong-terminal error.

---

## Items explicitly re-verified as CORRECT (no discrepancy)

- STRIPE args verbatim: `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })` (`:537`) vs determine_price_id's `limit: 10` (`:634`) — distinct, trace correct. `Stripe::Subscription.retrieve({ id:, expand: ['items.data.price.tiers'] })` (`organization.rb:477`). `Stripe::Subscription.list({ customer:, limit: 3, status: 'all' })` (`organization.rb:482`). `Stripe::Customer.retrieve({ id:, expand: ['subscriptions'] })` (`organization.rb:471`). `Stripe::Price.retrieve(target_price_id)` (interactor `:15`). All three `Stripe::BillingPortal::Session.create(options)` at `:306/:363/:452`.
- SCREEN terminals: `render json: { subscription: nil }` (`:611`) / `{ subscription: current_organization.stripe_subscription }` (`:614`) / `{ errors: [...] }` (`:618`); `render json: price_list` (`:540`); `render json: { redirectUrl: session.url }` (`:313/:367`); `redirect_to session.url` (`:457`); the nested-ternary `currentProductPrice` tiered vs unitAmount vs null (`AccountBillingPlans.tsx:139-142`); `loading={isLoadingButton}` / `disabled={isLoading}` (`PlanCard.tsx:209/210`); early-return `<LoadingIndicator>` (`:352-354`); `window.location.href = data.redirectUrl` (`:263/:303`); `addToast` error toasts (`:274/:313`); `openModal(modal)` (`:348`).
- DATABASE terminals: `organization.jobs.where(status: 'published').count` (interactor `:42`); `User.find_by(id: user_id)` (`posthog_track_job.rb:7`); `update(changes_to_make)` (`organization.rb:600`); `organization_ai_credit_balance.update_columns(monthly_credits_remaining: new_allocation)` (`:605`); `stripe_subscription_id` column `db/schema.rb:1056`, `plan` enum col `:1052` (default 101), `stripe_default_payment_method_on_file` `:1066`, `stripe_subscription_status` `:1065`, `stripe_current_period_end_at` `:1058`.
- The portal happy-path action itself writes NO DB record (trace correct) — confirmed only options-build + Stripe create + PosthogTrackJob + render.
- 8 `determine_price_id` call sites (`:50,:198,:252,:279,:299,:311,:343,:643`) — confirmed by grep; 3× within `change_subscription_portal_session`.
- `customer_subscription` invokes `stripe_subscription` TWICE on happy path (`:608` debug + `:614` render) — confirmed.
- StandardError rescue asymmetry: `change_subscription_portal_session` `:324` no Sentry vs `update_payment_method...` `:377` Sentry — confirmed.
