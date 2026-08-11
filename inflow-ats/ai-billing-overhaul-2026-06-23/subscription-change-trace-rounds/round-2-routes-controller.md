# Round 2 — routes + controller segment audit

Segment: `config/routes.rb` billing collection + every `BillingController` action in the flow
(`customer_subscription`, `prices`, `change_subscription_portal_session`,
`update_payment_method_and_subscription_portal_session`,
`continue_change_subscription_portal_session`) + `determine_price_id`.

Worktree audited: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`

Files traced:
`config/routes.rb` -> `app/controllers/api/v1/billing_controller.rb` -> `app/models/organization.rb` -> `app/policies/billing_policy.rb` -> `app/policies/application_policy.rb` -> `app/controllers/application_controller.rb`

Overall: the trace's line numbers for my segment are remarkably accurate (routes 168-178, every controller action line, every rescue, the options block, `determine_price_id`, the policy chain all verified to terminal). The discrepancies below are OMISSIONS of callpoints / guards / terminals and one imprecise structural count — not wrong line numbers.

---

## D1 — Omitted unconditional STRIPE callpoint inside `customer_subscription` (line 608)

TRACE SAYS (item 6, lines 20-23): `customer_subscription` "Branches on `stripe_subscription_id.nil?`" with the FIRST executable being the nil-check DB read at `:609`. The mapped flow is: `:609` nil-check -> `:611` render null / `:614` render `stripe_subscription` / `:618` rescue. No mention of any code between the method entry (`:606`) and the nil-check (`:609`).

ACTUAL CODE: lines 607-608 execute BEFORE the nil-check:
```
607  ap 'GETTING THE CUSTOMER SUBSCRIPTION'
608  ap current_organization.stripe_subscription
```
Line 608 invokes `Organization#stripe_subscription` (`organization.rb:474`) UNCONDITIONALLY on every request — which hits `Stripe::Subscription.retrieve(...)` (`organization.rb:477`, STRIPE terminal) whenever `stripe_subscription_id` is present, even though the action's "happy path" render at `:614` calls it AGAIN. On the null branch the inner `return if stripe_subscription_id.nil?` (`organization.rb:475`) makes line 608 a no-op, but the call still happens. The trace omits this callpoint entirely, so it (a) misses a STRIPE round-trip terminal that fires before the branch, and (b) misses that the happy path calls `stripe_subscription` TWICE (608 + 614).

file:line — `billing_controller.rb:607-608`

---

## D2 — `determine_price_id` invocation count is understated / unscoped ("Invoked 3×")

TRACE SAYS (item 23, line 64): "`determine_price_id` ... Invoked 3× (lines 279, 299, 311)."

ACTUAL CODE: `determine_price_id` is invoked at EIGHT call sites in the controller: lines 50, 198, 252, 279, 299, 311, 343, 643. Within my segment's actions specifically it is invoked at 279, 299, 311 (`change_subscription_portal_session`) AND at 343 (`update_payment_method_and_subscription_portal_session`) — i.e. 4× across the flow's actions, not 3×. The "Invoked 3×" claim is also internally inconsistent with the trace's OWN item 18b (line 53), which says the payment-method path reads "`target_price_id` (from `determine_price_id` at `:343`)". The "3×" is only correct if scoped to `change_subscription_portal_session` alone, which the trace does not state.

file:line — `billing_controller.rb` invocations at 50, 198, 252, 279, 299, 311, 343 (def `:630`)

---

## D3 — Omitted redirect terminals + guards in `continue_change_subscription_portal_session`

TRACE SAYS (item 18b, line 54): the continue action "NO `authorize`; reads `params[:target_price_id]` ... and `params[:subscription_item_id]`; runs `ValidateSubscriptionChange` (`:418`); builds a `subscription_update_confirm` portal session; terminal is `redirect_to session.url` (`:457`, NOT `render json`)." It enumerates exactly ONE terminal.

ACTUAL CODE: the action has FOUR additional redirect terminals (the segment brief requires "every guard ... and every render/redirect shape"):
- `:392` `redirect_to "#{params[:return_url]}?error=subscription_update_failed"` — guard when `stripe_customer_id.blank?` (`:390`)
- `:397` `redirect_to "#{params[:return_url]}?error=subscription_update_failed"` — guard when `stripe_subscription_id.blank?` (`:395`)
- `:411` `redirect_to "#{return_url}?error=subscription_update_failed"` — guard when `subscription_item_id.blank? || target_price_id.blank?` (`:409`)
- `:427` `redirect_to "#{return_url}?error=#{CGI.escape(result.message)}"` — on `ValidateSubscriptionChange` failure (`:424`)
- `:463` / `:469` — `rescue Stripe::InvalidRequestError` (`:458`) and `rescue StandardError` (`:464`), both `redirect_to "#{return_url}?error=subscription_update_failed"` with `Sentry.capture_exception`.

The trace's guard-failure and rescue redirect terminals (all SCREEN redirect terminals) are entirely omitted. Note these guards use `redirect_to ...?error=` returns (NOT `raise`), unlike `change_subscription_portal_session`'s `raise`-style guards — a structural difference the trace does not surface.

file:line — `billing_controller.rb:390-412`, `:424-429`, `:458-470`

---

## D4 — Omitted `return_url` construction in `continue_change_subscription_portal_session`

TRACE SAYS: item 18b describes the continue action's params and terminal but does not mention how `return_url` is derived (it is used in 4 of the redirect terminals above).

ACTUAL CODE (`:403-407`): `return_url` is computed with an http-prefix check:
```
403  return_url = if params[:return_url].present?
404                 params[:return_url].start_with?('http') ? params[:return_url] : "#{Variables::AtsRootUrl}#{params[:return_url]}"
405               else
406                 "#{Variables::AtsRootUrl}/hire/settings/billing"
407               end
```
The trace omits this variable and its fallback default `"#{Variables::AtsRootUrl}/hire/settings/billing"`. (Note: the two earliest guards at `:392`/`:397` use the RAW `params[:return_url]` — computed BEFORE `return_url` is assigned — while the later terminals use the computed `return_url`; the trace captures neither nuance.)

file:line — `billing_controller.rb:403-407`

---

## D5 — Omitted debug callpoints in `change_subscription_portal_session` guard region

TRACE SAYS (item 21-22): authorize at `:269`, then "Guards (`:272-274`)". Nothing between authorize and guards.

ACTUAL CODE: line 270 `ap 'Change Subscription via Stripe Portal Session'` sits between authorize (`:269`) and the guards (`:272`). Likewise the action contains `ap` debug calls at `:307`-`:308` (`ap 'Session Created...'` / `ap session`) between the Stripe create (`:306`) and the Posthog call (`:311`). The trace omits all `ap` callpoints in this action. (Low impact — `ap` is awesome_print debug output, not a SCREEN/STRIPE/DB terminal — but per the "every line" segment mandate they are uninventoried statements.)

file:line — `billing_controller.rb:270`, `:307-308`

---

## D6 — `change_subscription_portal_session` controller call-site of `ValidateSubscriptionChange` not cited

TRACE SAYS (item 24, line 65): cites `ValidateSubscriptionChange.call(organization:, target_price_id:, action_type: 'change')` at `app/interactors/validate_subscription_change.rb:6` — i.e. it jumps to the interactor's `call` definition.

ACTUAL CODE: the controller's call SITE in my segment is `billing_controller.rb:277-281`:
```
277  result = ValidateSubscriptionChange.call(
278    organization: current_organization,
279    target_price_id: determine_price_id,
280    action_type: 'change'
281  )
```
followed by `unless result.success?` (`:283`) -> `render_general_errors([result.message])` (`:284`) -> `return` (`:285`). The trace never anchors the controller-side call site / `target_price_id: determine_price_id` argument (one of the 3 in-action `determine_price_id` invocations) to lines 277-281; it only references the interactor file. The arguments and line are correct in spirit, but the controller-segment line citation is missing.

file:line — `billing_controller.rb:277-281` (and `:283-285`)

---

## Verified-correct (no discrepancy) for this segment

- Routes: `change_subscription` POST `:168`, `change_subscription_portal_session` POST `:169`, `update_payment_method_and_subscription_portal_session` POST `:170`, `prices` GET `:174`, `customer_subscription` GET `:177`, `continue_change_subscription_portal_session` GET `:178` — all exact.
- `DEFAULT_PRICE_LOOKUP_KEY = 'plan_simple_ats_per_job_tiered'` at `billing_controller.rb:7`; duplicate at `organization.rb:176` — both confirmed.
- `change_subscription_portal_session`: def `:268`, `authorize :billing, :change_subscription?` `:269`, guards `:272-274`, `subscription_item_id = params[:subscription_item_id]` `:288`, options block `:290-304` (comments at `:298`/`:300`), `Stripe::BillingPortal::Session.create` `:306`, `PosthogTrackJob.perform_later(... price_id: determine_price_id)` `:311`, `render json: { redirectUrl: session.url }` `:313`, rescues `:314` (Pundit, Sentry), `:320` (Stripe::InvalidRequestError, Sentry), `:324` (StandardError, NO Sentry) — all exact, including the no-Sentry detail on the StandardError rescue.
- `prices`: def `:535`, `authorize :billing, :prices?` `:536`, `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })` `:537`, `render json: price_list` `:540` — exact.
- `customer_subscription`: def `:606`, nil-check `:609`, render null `:611`, render `stripe_subscription` `:614`, rescue `:618` — all exact; NO `authorize` — confirmed.
- `update_payment_method_and_subscription_portal_session`: def `:331`, `determine_price_id` `:343`, `continue_url` build `:346-349`, `render json: { redirectUrl: session.url }` `:367` — exact.
- `determine_price_id`: def `:630`, `params.key?(:price_id)` `:631`, returns `params[:price_id]` `:632`, else `Stripe::Price.list({ active: true, limit: 10, ... })` `:634`, returns `prices.data.find { |price| price.lookup_key == DEFAULT_PRICE_LOOKUP_KEY }` `:637` — exact; `limit: 10` vs `prices`' `limit: 20` distinction correct.
- `Organization#stripe_subscription` `:474`, guard `:475`, `Stripe::Subscription.retrieve({ id:, expand: ['items.data.price.tiers'] })` `:477` — exact.
- `BillingPolicy#change_subscription?` `:24` -> `is_org_admin?`; `prices?` -> `is_org_user?`; `is_org_admin?` at `application_policy.rb:50` — exact.
- `render_general_errors` at `application_controller.rb:40` — exact.
- Sibling `change_subscription` action (`# UNUSED`): cancel `:241`, create `:258`, `sync_with_stripe` `:260` — exact.
