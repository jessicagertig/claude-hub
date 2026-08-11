# Round 3 — TERMINALS segment audit (SCREEN / STRIPE / DATABASE)

Worktree audited: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`
Trace audited: `/Users/jessica/claude-hub/inflow-ats/ai-billing-overhaul-2026-06-23/traces/subscription-change-analog-trace.md`

Chains traced to terminal:
- SCREEN(subscription): `AccountBilling.tsx` → `useBilling.ts:useStripeCustomerSubscription:245` → `getStripeCustomerSubscription:98` → `api.ts:apiGet:5/:22` → `routes.rb:177` → `billing_controller.rb#customer_subscription:606` → `organization.rb#stripe_subscription:474` → `Stripe::Subscription.retrieve` (:477, STRIPE)
- SCREEN(prices): `AccountBilling.tsx:50/:54/:132` → `useBilling.ts:useBillingPrices:266` → `getPrices:102` → `api.ts:apiGet:5` → `routes.rb:174` → `billing_controller.rb#prices:535` → `Stripe::Price.list` (:537, STRIPE) → `render json:540` → `planLookups.js:getPlansForPeriod:553` → `AccountBillingPlans.tsx:175` → `PlanCard.tsx:199-214` (SCREEN)
- STRIPE(change): `billing_controller.rb#change_subscription_portal_session:268` → `Stripe::BillingPortal::Session.create:306` → `render json { redirectUrl }:313` → `AccountBillingPlans.tsx:303 window.location.href` (SCREEN)
- DB: `validate_subscription_change.rb:42` (jobs/status read), `:58` (stripe_subscription_status read); `posthog_track_job.rb:7` (users read); `organization.rb#sync_with_stripe:600/:605` (organizations + organization_ai_credit_balances writes); `schema.rb:1052/:1056`

Overall: the SCREEN, STRIPE, and DATABASE terminals are named correctly and the line numbers are almost entirely exact. Findings below are the only deviations; all are minor.

---

## Finding 1 (LOW) — "FIRST executable statement" mislabeled in `customer_subscription`

TRACE SAYS (item 6): "The FIRST executable statement is `ap current_organization.stripe_subscription` (`:608`), an awesome_print debug line that UNCONDITIONALLY invokes `Organization#stripe_subscription` … BEFORE the nil-check".

ACTUAL CODE: the FIRST executable statement in `customer_subscription` is `ap 'GETTING THE CUSTOMER SUBSCRIPTION'` at line **607** (a literal-string awesome_print). The `ap current_organization.stripe_subscription` is the SECOND statement, at line 608. The structural CLAIM that matters — `:608` unconditionally invokes `stripe_subscription` (and thus `Stripe::Subscription.retrieve`) before the nil-check, so the happy path calls it twice (:608 then :614) — is CORRECT. Only the "FIRST executable statement" wording is wrong; :607 precedes it.

file:line — `app/controllers/api/v1/billing_controller.rb:607-608`

---

## Finding 2 (LOW) — payment-method-fork STRIPE terminal line not cited

TRACE SAYS (item 18b): describes `update_payment_method_and_subscription_portal_session` as building a `payment_method_update` portal session with `after_completion.redirect.return_url` (`continue_url`, `:346-349`) but never cites the actual `Stripe::BillingPortal::Session.create` STRIPE terminal line for THIS action. (It cites `:452` only for the later `continue_*` action.)

ACTUAL CODE: the STRIPE terminal for the payment-method fork is `session = Stripe::BillingPortal::Session.create(options)` at line **363**, with `render json: { redirectUrl: session.url }` at line 367. `continue_url` is indeed built at :346-349 and `determine_price_id` at :343 (both correct). The `Session.create:363` / `render:367` STRIPE+SCREEN terminals for this fork are simply omitted.

file:line — `app/controllers/api/v1/billing_controller.rb:363` (Session.create), `:367` (render redirectUrl)

---

## Finding 3 (INFO / not a defect) — `subscription_nil:` keyword not passed at the ValidateSubscriptionChange call site

TRACE SAYS (item 24): "`organization.assign_plan_name_from_lookup_key(lookup_key:, subscription_nil: false)` (`:26`; the method signature takes a second keyword `subscription_nil: false`…)".

ACTUAL CODE: line 26 is `organization_alias_for_target_plan = organization.assign_plan_name_from_lookup_key(lookup_key: target_lookup_key)` — the call passes ONLY `lookup_key:`; `subscription_nil:` is NOT passed (it defaults to `false` in the signature). The trace's parenthetical correctly attributes `subscription_nil: false` to the method SIGNATURE/default, not the call, so this is not strictly a defect — but a reader could mis-read item 26 as the call passing the keyword. Not a SCREEN/STRIPE/DB terminal issue; noted for completeness. The DB terminal in this interactor (`organization.jobs.where(status: 'published').count`, :42) is correctly named.

file:line — `app/interactors/validate_subscription_change.rb:26`

---

## Terminals verified CORRECT (no discrepancy)

- STRIPE `Organization#stripe_subscription` → `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })` — `organization.rb:474/:477` ✓ (guard :475 ✓)
- STRIPE `prices` → `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })` :537, render :540 ✓
- STRIPE `determine_price_id` else-branch → `Stripe::Price.list({ active: true, limit: 10, expand: ['data.tiers'] })` :634, `.find { lookup_key == DEFAULT_PRICE_LOOKUP_KEY }` :637; constant :7 = `'plan_simple_ats_per_job_tiered'` ✓
- STRIPE change action → `Stripe::BillingPortal::Session.create(options)` :306; options block :290-304 verbatim ✓ (`type: 'subscription_update_confirm'` ✓)
- STRIPE continue action → `Stripe::BillingPortal::Session.create(options)` :452, `redirect_to session.url` :457 ✓
- SCREEN change happy → `render json: { redirectUrl: session.url }` :313 → `window.location.href = data.redirectUrl` `AccountBillingPlans.tsx:303` ✓
- SCREEN change error → `addToast` :305-313 ✓; payment-method redirect :263 / error :265-274 ✓
- SCREEN subscription null branch → `render json: { subscription: nil }` :611 ✓; happy → `render json: { subscription: current_organization.stripe_subscription }` :614 ✓; error → `render json: { errors: ['Unable to load subscription'] }` :618 ✓
- SCREEN loading → `if (isFetchingStripeCustomerSubscription) return <LoadingIndicator label="Loading..." />` `AccountBillingPlans.tsx:352-354` ✓
- SCREEN PlanCard branch → `:199 {isCurrentPlan || isFreePlan ? ManageBillingActions(:200-205) : Styled.Button(:207-214)}`; onClick :208, loading :209, disabled :210; isFreePlan :151; handleOnClickSubscriptionAction :98 (trackEvent :99, branch :100, true:101, false:103); onChangeSubscription(plan) :95 ✓
- SCREEN prices render fallbacks → `planLookups.js`: `price: priceData ? priceData.unitAmount / 100 : 0` :564, `priceId: priceData?.id || null` :568, `lookupKey: planConfig.value` :569, `key: planConfig.key` :571 ✓
- SCREEN prices unwrap → `AccountBilling.tsx:50/:54` (`[]` fallback), prop passed `:132` ✓
- DATABASE write (sync_with_stripe) → `update(changes_to_make)` :600 over {plan, stripe_subscription_status, stripe_subscription_id, stripe_current_period_end_at, stripe_default_payment_method_on_file}; plan assign :573; AI-credit allocation :603-605 `organization_ai_credit_balance.update_columns(monthly_credits_remaining: new_allocation)` ✓
- DATABASE read → `validate_subscription_change.rb:42` (jobs/status), `:58` (stripe_subscription_status); `posthog_track_job.rb:7` (users) ✓
- Schema → `organizations.plan` :1052 (default 101), `stripe_subscription_id` :1056 ✓
- Transport → `api.ts` apiGet :5/:22, apiPost :25-28, apiMutate :40-68, CSRF :50, allKeysToSnake :52, allKeysToCamel :67, error :56 ✓
- Routes → :168-178 all exact ✓
