# Round 8 — Routes + Controller segment audit

Reviewer: routes-controller. Segment: `config/routes.rb` billing collection + every `BillingController` action in the flow (`customer_subscription`, `prices`, `change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `continue_change_subscription_portal_session`) + `determine_price_id`.

Worktree audited: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`

Chain traced for this segment:
`config/routes.rb` (billing collection) → `app/controllers/api/v1/billing_controller.rb` (all 5 actions + `determine_price_id` + `determine_product_info`/`get_product_from_price_id`/`determine_lookup_key`) → `app/policies/billing_policy.rb` → `app/policies/application_policy.rb` → `app/models/organization.rb` (`stripe_subscription`, `stripe_customer`, `stripe_customer_subscriptions`) → `app/controllers/application_controller.rb` (`render_general_errors`) → `app/jobs/posthog_track_job.rb` → `db/schema.rb` (column lines) → STRIPE / SCREEN / DATABASE terminals.

## Verification result

Every routes/controller claim in the trace was checked identifier-by-identifier and line-by-line against the actual code. ALL verified correct:

ROUTES (`config/routes.rb`):
- `change_subscription` collection POST `:168` — VERIFIED
- `change_subscription_portal_session` POST `:169` — VERIFIED
- `update_payment_method_and_subscription_portal_session` POST `:170` — VERIFIED
- `prices` GET `:174` — VERIFIED
- `customer_subscription` GET `:177` — VERIFIED
- `continue_change_subscription_portal_session` GET `:178` — VERIFIED

CONTROLLER (`app/controllers/api/v1/billing_controller.rb`):
- `customer_subscription` def `:606`; no `authorize`; `ap 'GETTING THE CUSTOMER SUBSCRIPTION'` `:607`; `ap current_organization.stripe_subscription` `:608` (unconditional, calls `stripe_subscription` before nil-check; happy path calls it twice — `:608` + `:614`); nil branch `:609` → `render json: { subscription: nil }` `:611`; else → `render json: { subscription: current_organization.stripe_subscription }` `:614`; rescue `:615` / Sentry `:616` / Rails.logger.error `:617` / render errors `:618` — ALL VERIFIED
- `prices` def `:535`; `authorize :billing, :prices?` `:536`; `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })` `:537`; `render json: price_list` `:540` — VERIFIED
- `change_subscription_portal_session` def `:268`; `authorize :billing, :change_subscription?` `:269`; `ap` `:270`; guards `:272-274`; `ValidateSubscriptionChange.call(... target_price_id: determine_price_id ... action_type: 'change')` `:277-281` (`determine_price_id` at `:279`); `unless result.success?` `:283` → `render_general_errors([result.message])` `:284` → `return` `:285`; `subscription_item_id = params[:subscription_item_id]` `:288`; options block `:290-304` (`price: determine_price_id` at `:299`); `Stripe::BillingPortal::Session.create(options)` `:306`; `ap` `:307`/`:308`; comment `:309`; `PosthogTrackJob.perform_later(..., { price_id: determine_price_id })` `:311`; `render json: { redirectUrl: session.url }` `:313`; rescues Pundit `:314`, Stripe::InvalidRequestError `:320`, StandardError `:324` (`:325` logger, `:326` render — NO Sentry) — ALL VERIFIED
- `update_payment_method_and_subscription_portal_session` def `:331`; authorize `:332`; `ap` `:333`; guards `:335-337`; `subscription_item_id` `:339`; `final_return_path = params[:return_url].presence || '/account'` `:340`; `final_return_url` `:341`; `target_price_id = determine_price_id` `:343`; `continue_url` `:346-349`; options `:351-361` (`type: 'payment_method_update'`, `after_completion.redirect.return_url: continue_url` `:357`, top-level `return_url: final_return_url` `:360`); `Stripe::BillingPortal::Session.create` `:363`; `ap` `:364-365`; `render json: { redirectUrl: session.url }` `:367`; rescues Pundit `:368`, Stripe::InvalidRequestError `:372`, StandardError `:376` WITH Sentry `:377` — ALL VERIFIED
- `continue_change_subscription_portal_session` def `:385`; no authorize; `ap` `:386`; customer-blank guard `:390-393` (raw `params[:return_url]` redirect `:392`); subscription-blank guard `:395-398` (raw redirect `:397`); `subscription_item_id = params[:subscription_item_id]` `:400`; `target_price_id = params[:target_price_id]` `:401` (NOT `determine_price_id`); `return_url` `:403-407`; missing-params guard `:409-412`; `ValidateSubscriptionChange.call(... target_price_id: target_price_id ... action_type: 'change')` `:418-422`; `unless result.success?` `:424` → redirect `:427` + return `:428`; options `:433-447`; `Stripe::BillingPortal::Session.create` `:452`; `redirect_to session.url` `:457`; rescues Stripe::InvalidRequestError `:458` (Sentry `:459`, redirect `:463`), StandardError `:464` (Sentry `:465`, redirect `:469`) — ALL VERIFIED
- `determine_price_id` def `:630`; `if params.key?(:price_id)` `:631` → `params[:price_id]` `:632`; else `Stripe::Price.list({ active: true, limit: 10, expand: ['data.tiers'] })` `:634` → `prices.data.find { |price| price.lookup_key == DEFAULT_PRICE_LOOKUP_KEY }` `:637`; `DEFAULT_PRICE_LOOKUP_KEY` `:7` — VERIFIED
- 8 `determine_price_id` call sites `:50, :198, :252, :279, :299, :311, :343, :643` — VERIFIED via grep (3× inside change action at `:279/:299/:311`, 1× in payment-method fork at `:343`)
- `determine_product_info` `:642`, `get_product_from_price_id` `:649` (`Stripe::Price.retrieve({id:, expand:['product']})` `:652`, returns `{product:, price:}` `:657-660`), `determine_lookup_key` `:663` (`product_info[:price][:lookup_key]` `:667`) — VERIFIED
- `change_subscription` `# UNUSED` `:237-263` (`Stripe::Subscription.cancel` `:241`, `Stripe::Subscription.create` `:258`, `sync_with_stripe` `:260`) — VERIFIED

POLICIES / MODEL / SUPPORT:
- `BillingPolicy#prices?` `billing_policy.rb:4-6` → `is_org_user?`; `#change_subscription?` `:24` → `is_org_admin?` — VERIFIED
- `is_org_admin?` `application_policy.rb:50`, `is_org_user?` `:54-56`, `is_org_owner?` `:46-48` — VERIFIED
- `Organization#stripe_subscription` `organization.rb:474`, guard `:475`, `Stripe::Subscription.retrieve({ id:, expand: ['items.data.price.tiers'] })` `:477` — VERIFIED
- `render_general_errors` `application_controller.rb:40` — VERIFIED
- `PosthogTrackJob#perform` `posthog_track_job.rb:6`, `User.find_by(id: user_id)` `:7`, `Posthog::Track...track` `:10` — VERIFIED
- `organizations.stripe_subscription_id` `db/schema.rb:1056`, `organizations.plan` integer default 101 `db/schema.rb:1052` — VERIFIED

## Discrepancies

NONE. The routes + controller segment of the trace is accurate at every line, identifier, guard, param, render/redirect shape, and call site checked. Every claimed file:line matches the actual code in `inflow-ats.billing-bonanza`.
