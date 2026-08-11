# Round 7 — Routes + Controller segment audit

Reviewer: routes-controller. Segment: `config/routes.rb` billing collection, and every `BillingController` action in the flow (`customer_subscription`, `prices`, `change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `continue_change_subscription_portal_session`) + `determine_price_id`.

Worktree audited: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`

## Verification chain traced

- `config/routes.rb:163-186` (billing collection block) — verified read.
- `app/controllers/api/v1/billing_controller.rb` — `:7` (DEFAULT_PRICE_LOOKUP_KEY), `:237-263` (change_subscription UNUSED), `:268-327` (change_subscription_portal_session), `:331-380` (update_payment_method_and_subscription_portal_session), `:385-470` (continue_change_subscription_portal_session), `:535-541` (prices), `:606-621` (customer_subscription), `:630-640` (determine_price_id) — verified read line by line.
- `app/policies/billing_policy.rb:4-6` (prices?), `:24-26` (change_subscription?) — verified.
- `app/policies/application_policy.rb:50` (is_org_admin?), `:54-56` (is_org_user?) — verified.
- `app/models/organization.rb:474-477` (stripe_subscription) — verified (reached by customer_subscription :608/:614).
- `determine_price_id` call sites grepped: `:50, :198, :252, :279, :299, :311, :343, :643` — exactly the 8 the trace claims.

## Structural verification

- Routes: all six route lines the trace cites match — `change_subscription` POST `:168`, `change_subscription_portal_session` POST `:169`, `update_payment_method_and_subscription_portal_session` POST `:170`, `prices` GET `:174`, `customer_subscription` GET `:177`, `continue_change_subscription_portal_session` GET `:178`. SAME.
- Three-way gating asymmetry (item 6/21): `customer_subscription` (`:606`) and `continue_change_subscription_portal_session` (`:385`) have NO authorize; `prices` authorizes `:prices?` → org-USER; the two change actions authorize `:change_subscription?` → org-ADMIN. Verified against actual code — SAME.
- `customer_subscription` body (`:606-621`): `ap` debug at `:607`, unconditional `ap current_organization.stripe_subscription` at `:608` (calls `Organization#stripe_subscription` before the nil-check; happy path calls it twice via `:608` then `:614`), `stripe_subscription_id.nil?` branch `:609`, render `subscription: nil` `:611`, happy render `:614`, rescue `:615`, Sentry `:616`, logger `:617`, error render `:618`. All SAME.
- `prices` body (`:535-541`): authorize `:536`, `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })` `:537`, render `:540`. SAME.
- `change_subscription_portal_session` (`:268-327`): authorize `:269`, `ap` `:270`, three guards `:272-274`, ValidateSubscriptionChange.call `:277-281`, `unless result.success?` `:283` / render_general_errors `:284` / return `:285`, `subscription_item_id = params[:subscription_item_id]` `:288`, options block `:290-304`, `Stripe::BillingPortal::Session.create` `:306`, `ap` `:307-308`, `PosthogTrackJob.perform_later` `:311`, render `:313`, rescues Pundit `:314` / Stripe::InvalidRequestError `:320` / StandardError `:324` (no Sentry on StandardError). All SAME.
- `update_payment_method_and_subscription_portal_session` (`:331-380`): authorize `:332`, `ap` `:333`, three guards `:335-337`, `subscription_item_id` `:339`, `final_return_path = params[:return_url].presence || '/account'` `:340`, `final_return_url` `:341`, `target_price_id = determine_price_id` `:343`, continue_url `:346-349`, options `:351-361` (after_completion.redirect.return_url `:357`, top-level return_url `:360`), create `:363`, render `:367`, StandardError rescue calls Sentry `:377` with 'Unable to start payment method update flow' `:379`. All SAME.
- `continue_change_subscription_portal_session` (`:385-470`): no authorize, `ap` first `:386`, customer-blank guard `:390-393` (RAW params[:return_url] `:392`), subscription-blank guard `:395-398` (RAW `:397`), reads `:400-401`, return_url build `:403-407`, missing-params guard `:409-412`, ValidateSubscriptionChange.call `:418-422`, `unless result.success?` redirect `:427` + return `:428`, options `:433-447`, create `:452`, redirect_to session.url `:457`, rescues Stripe::InvalidRequestError `:458` (redirect `:463`) / StandardError `:464` (redirect `:469`). All SAME.
- `determine_price_id` (`:630-640`): `params.key?(:price_id)` `:631` → returns `params[:price_id]` `:632` (String); else `Stripe::Price.list({ active: true, limit: 10, expand: ['data.tiers'] })` `:634`, `prices.data.find { |price| price.lookup_key == DEFAULT_PRICE_LOOKUP_KEY }` `:637` (Stripe::Price object). SAME.

## Discrepancies

None.

Every route line, controller action line, guard, param read, render/redirect shape, rescue class, Sentry presence/absence, awesome_print debug line, options-block field, and `determine_price_id` call-site for this segment matches the trace exactly. No wrong file:line, no renamed identifier, no omitted callpoint, no thread stopped short of terminal, no wrong terminal (SCREEN/STRIPE/DB), and no structural mismatch was found in the routes + controller segment.
