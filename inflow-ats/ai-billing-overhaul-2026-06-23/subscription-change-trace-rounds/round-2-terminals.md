# Round 2 — TERMINALS segment audit (SCREEN / STRIPE / DATABASE)

Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`
Trace under audit: `traces/subscription-change-analog-trace.md`
Segment: every point data reaches the SCREEN, goes to STRIPE, or touches the DATABASE.

Chains traced (terminal verification):
- `AccountBillingPlans.tsx` → `useBilling.ts` → `api.ts` → `routes.rb` → `billing_controller.rb` → `organization.rb` → `Stripe::Subscription.retrieve` (STRIPE)
- `billing_controller.rb#change_subscription_portal_session` → `Stripe::BillingPortal::Session.create` (STRIPE) / `ValidateSubscriptionChange` → `organization.jobs.where(status:'published').count` (DATABASE)
- `billing_controller.rb#prices` → `Stripe::Price.list` (STRIPE) → `render json` → `planLookups.js#getPlansForPeriod` (SCREEN)
- `PlanCard.tsx` Styled.Button (SCREEN) → handlers → `window.location.href` redirect (SCREEN)

Overall: the trace's TERMINALS are largely accurate. Line numbers and Stripe-call argument hashes match the code almost everywhere. The discrepancies below are real but mostly omissions of a STRIPE call and of guard expressions, plus a few location quibbles.

---

## D1 — STRIPE terminal OMITTED in `customer_subscription` (extra Stripe::Subscription.retrieve at :608)

TRACE SAYS (item 6): `customer_subscription` (`:606`) "Branches on `stripe_subscription_id.nil?`" — first reads `stripe_subscription_id.nil?` at `:609`, else renders `current_organization.stripe_subscription` at `:614` (the only Stripe retrieve). The trace lists exactly one STRIPE terminal for this action (`Organization#stripe_subscription` → `Stripe::Subscription.retrieve`, reached via `:614`).

ACTUAL CODE: line `608` is `ap current_organization.stripe_subscription` — this UNCONDITIONALLY calls `Organization#stripe_subscription` (and therefore `Stripe::Subscription.retrieve`) BEFORE the `stripe_subscription_id.nil?` branch at `:609`. `ap` (awesome_print) evaluates its argument, so this is a live Stripe API call on every request (it returns `nil` only when the id is nil, via the `:475` guard). The happy path therefore makes the Stripe retrieve TWICE (`:608` then `:614`). The trace omits the `:608` STRIPE terminal entirely.

file:line — `app/controllers/api/v1/billing_controller.rb:608`

---

## D2 — SCREEN-feeding variable: `currentPriceObject` guard omitted

TRACE SAYS (item 9): `currentPriceObject = currentSubscription.items.data[0].price` — `AccountBillingPlans.tsx:67`.

ACTUAL CODE: `const currentPriceObject = currentSubscription && currentSubscription.items.data[0].price;` — the trace drops the `currentSubscription &&` short-circuit guard. Without the guard the value would throw when `currentSubscription` is null; the guard is what makes `currentPriceObject` resolve to a falsy value (feeding the `currentProductPrice = ... : null` and `price ? ... : 0` SCREEN fallbacks).

file:line — `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:67`

---

## D3 — SCREEN-feeding variable: `currentSubscriptionItemId` guard omitted

TRACE SAYS (item 9): `currentSubscriptionItemId = currentSubscription.items.data[0].id` — `AccountBillingPlans.tsx:136`.

ACTUAL CODE: `const currentSubscriptionItemId = currentSubscription && currentSubscription.items.data[0].id;` — the `currentSubscription &&` guard is dropped from the trace. This variable is the one passed as `subscriptionItemId={currentSubscriptionItemId}` to `<PlanCard>` (`:449`) and into both change handlers; the guard makes it `null`/falsy when no subscription exists rather than throwing.

file:line — `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:136`

---

## D4 — `<PlanCard>` render line range slightly off

TRACE SAYS (item 16): "`plansWithButtonText.map` renders `<PlanCard ... onChangeSubscription={handleChangeSubscriptionWithGate} subscriptionItemId={currentSubscriptionItemId} />` (`AccountBillingPlans.tsx:435-457`)".

ACTUAL CODE: the `.map` opens at `:435`, but the `<PlanCard ...>` element spans `:439-457` and the JSX prop `subscriptionItemId={currentSubscriptionItemId}` is at `:449`, `onChangeSubscription={handleChangeSubscriptionWithGate}` at `:455`. The `:435-457` range is the map callback, not the element; the cited props are real but at `:449`/`:455`, not implied across `:435-457`. Minor location imprecision (props correct).

file:line — `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:439-457` (props `:449`, `:455`)

---

## D5 — PlanCard `onClick` binding cited at the handler-definition line, not the binding line

TRACE SAYS (item 16): "the change button is `Styled.Button` (`PlanCard.tsx:207-214`...), `onClick={handleOnClickSubscriptionAction}` (`PlanCard.tsx:98`)".

ACTUAL CODE: `:98` is the DEFINITION of `handleOnClickSubscriptionAction` (`const handleOnClickSubscriptionAction = () => {`). The actual `onClick={handleOnClickSubscriptionAction}` PROP BINDING on `Styled.Button` is at `:208`. The trace points the `onClick=` binding at the wrong line. (Inside the handler: `if (hasActiveSubscription) handleChangeSubscription()` is at `:100-101`, `onChangeSubscription(plan)` at `:95` — both correct.)

file:line — `app/javascript/ats/src/views/accountAdmin/accountBilling/PlanCard.tsx:208` (binding); `:98` is the definition

---

## D6 — `customer_subscription` rescue/error-render line vs. render line

TRACE SAYS (item 6): "`rescue StandardError` → `Sentry.capture_exception(e)` + `render json: { errors: ['Unable to load subscription'] }` (`:618`, SCREEN error terminal)".

ACTUAL CODE: the `rescue StandardError => e` is at `:615`, `Sentry.capture_exception(e)` at `:616`, and `render json: { errors: ['Unable to load subscription'] }` at `:618`. The trace attributes the whole rescue block (including the rescue keyword and Sentry) to `:618`; only the error render is at `:618`. Minor — the SCREEN error terminal line (`:618`) is correct; the rescue keyword line is `:615`.

file:line — `app/controllers/api/v1/billing_controller.rb:615` (rescue) / `:618` (render error)

---

## Verified correct (no discrepancy) — terminal spot checks

- STRIPE: `Organization#stripe_subscription` guard `:475`, `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })` `:477` — EXACT.
- STRIPE: `prices` → `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })` `:537`, `render json: price_list` `:540` — EXACT (SCREEN `billingPrices`).
- STRIPE: `determine_price_id` else-branch `Stripe::Price.list({ active: true, limit: 10, expand: ['data.tiers'] })` `:634`, `find { |price| price.lookup_key == DEFAULT_PRICE_LOOKUP_KEY }` `:637`; `DEFAULT_PRICE_LOOKUP_KEY` `:7`; invoked 3× at `:279`, `:299`, `:311` — EXACT.
- STRIPE: `Stripe::BillingPortal::Session.create(options)` `:306`; `flow_data` hash `:290-304` verbatim (customer `:291`, return_url `:292`, type `subscription_update_confirm` `:294`, subscription `:296`, items id `:298`/price `:299`/quantity `:300`) — EXACT.
- STRIPE: `ValidateSubscriptionChange` `Stripe::Price.retrieve(target_price_id)` `:15`, `target_lookup_key = target_price.lookup_key` `:16` — EXACT.
- DATABASE: `current_published_count = organization.jobs.where(status: 'published').count` `:42` (jobs table, status column) vs `target_job_limit` (`:43`); `context.fail!` `:72` / `context.success!` `:76` — EXACT. NOTE the comparison `if current_published_count > target_job_limit` is at `:53` (trace doesn't cite `:53` but its `:72`/`:76` terminals are correct).
- DATABASE: `PosthogTrackJob#perform` `User.find_by(id: user_id)` `:7` (users table read) — EXACT; `PosthogTrackJob.perform_later(...)` enqueue `:311` — EXACT.
- DATABASE/schema: `organizations.plan` integer default 101 `db/schema.rb:1052`; `organizations.stripe_subscription_id` string `:1056` — EXACT.
- SCREEN: loading early-return `<LoadingIndicator label="Loading..." />` `:352-354` — EXACT.
- SCREEN: portal-path `onSuccess` `window.location.href = data.redirectUrl` `:303`; `onError` `error?.data?.errors?.general?.[0]` + `addToast({ title, kind:'error' })` `:305-314` — EXACT.
- SCREEN: payment-method-path `onSuccess` redirect `:263`; `onError` addToast `:265-274` — EXACT.
- SCREEN: backend `render json: { redirectUrl: session.url }` `:313` (portal); `redirect_to session.url` `:457` (continue) — EXACT.
- STRIPE: continue action `Stripe::BillingPortal::Session.create(options)` `:452` with target_price_id `:442` (reads `params[:target_price_id]` `:401`, NOT determine_price_id) — EXACT; NO authorize — EXACT.
- STRIPE: payment-method action `Stripe::BillingPortal::Session.create(options)` `:363`, `payment_method_update` flow with `after_completion.redirect.return_url = continue_url` `:355-357` (continue_url built `:346-349` carrying subscription_item_id + target_price_id + return_url) — EXACT.
- routes: `change_subscription` `:168`, `change_subscription_portal_session` `:169`, `update_payment_method_and_subscription_portal_session` `:170`, `prices` `:174`, `customer_subscription` `:177`, `continue_change_subscription_portal_session` `:178` — EXACT.
- transport: `apiGet` `:5`/`allKeysToCamel` `:22`; `apiPost` `:25-28` → `apiMutate` `:40-68`, CSRF `Rails.csrfToken()` `:50`, `allKeysToSnake(variables)` `:52`, error `allKeysToCamel` `:56`, response `allKeysToCamel` `:67` — EXACT.
- planLookups: `getPlansForPeriod` `:553`, `price: ... : 0` `:564`, `priceId: priceData?.id || null` `:568`, `lookupKey: planConfig.value` `:569`, `key: planConfig.key` `:571` — EXACT.
- `assign_plan_from_lookup_key` `:113-118` (`'plan_simple_ats_free'` if subscription_nil `:114`; `@organization.plan` if lookup_key nil `:115`; `PLAN_LOOKUP_MAPPING.keys.find` `:117`; fallback `@organization.plan` `:118`) — EXACT.
- `PlanFeatureGate.all_plan_rules` `:72`, `new(OpenStruct.new(...)).send(:plan_rules)` `:73`, `initialize` `:25-28` — EXACT.
