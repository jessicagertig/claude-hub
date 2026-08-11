# Round 5 — routes-controller segment audit

Segment: `config/routes.rb` billing collection + every `BillingController` action in the flow
(`customer_subscription`, `prices`, `change_subscription_portal_session`,
`update_payment_method_and_subscription_portal_session`,
`continue_change_subscription_portal_session`) + `determine_price_id`.

Worktree audited: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`

Files traced:
- `config/routes.rb` (billing collection, lines 163-186)
- `app/controllers/api/v1/billing_controller.rb` (all in-flow actions + `determine_price_id` and the price-model helpers `determine_product_info`/`get_product_from_price_id`/`determine_lookup_key`)
- `app/policies/billing_policy.rb` (`change_subscription?`, `prices?`)
- `app/policies/application_policy.rb` (`is_org_admin?` :50, `is_org_owner?` :46)
- `app/models/organization.rb` (`stripe_subscription` :474-478 — terminal Stripe call the controller invokes)

## Verification result

Every line, guard, variable, param, render/redirect shape, and call site claimed by the
trace for this segment was checked identifier-by-identifier against the actual code.
All matched. Specifically confirmed:

ROUTES (`config/routes.rb`):
- `change_subscription` POST :168, `change_subscription_portal_session` POST :169,
  `update_payment_method_and_subscription_portal_session` POST :170,
  `prices` GET :174, `customer_subscription` GET :177,
  `continue_change_subscription_portal_session` GET :178 — ALL correct.

`customer_subscription` (def :606): NO authorize (confirmed); `ap` :607;
`ap current_organization.stripe_subscription` :608 (unconditional, before nil-check; calls
`stripe_subscription` which hits `Stripe::Subscription.retrieve` at organization.rb:477 when
id present → "TWICE" claim correct); nil-check :609; render `{ subscription: nil }` :611;
render happy `current_organization.stripe_subscription` :614; rescue :615; Sentry :616;
logger :617; render `{ errors: ['Unable to load subscription'] }` :618. ALL correct.

`prices` (def :535): authorize :billing, :prices? :536;
`Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })` :537;
`render json: price_list` :540. ALL correct.

`change_subscription_portal_session` (def :268): authorize :269; ap :270; guards :272-274;
ValidateSubscriptionChange.call with target_price_id: determine_price_id :277-281 (:279);
`unless result.success?` :283 / render_general_errors :284 / return :285;
`subscription_item_id = params[:subscription_item_id]` :288; options :290-304;
inline comments at :298 (`# Current subscription item id`) and :300; Session.create :306;
ap :307 / ap session :308; PosthogTrackJob :311; render `{ redirectUrl: session.url }` :313;
rescues Pundit :314 (Sentry), Stripe::InvalidRequestError :320 (Sentry),
StandardError :324 (NO Sentry — confirmed). ALL correct.

`update_payment_method_and_subscription_portal_session` (def :331): authorize :332; ap :333;
guards :335-337; subscription_item_id :339; final_return_path :340; final_return_url :341;
target_price_id = determine_price_id :343; continue_url :346-349 (all three params CGI.escaped,
return_url = CGI.escape(final_return_url)); options :351-361; redirect return_url: continue_url
:357; top-level return_url: final_return_url :360; Session.create :363; ap :364-365;
render :367; rescues Pundit :368, Stripe::InvalidRequestError :372,
StandardError :376 (Sentry.capture_exception :377 — present, UNLIKE the change action's :324).
ALL correct.

`continue_change_subscription_portal_session` (def :385): NO authorize; ap :386;
customer-blank guard :390 → redirect RAW params[:return_url] :392; subscription-blank guard :395
→ redirect :397; subscription_item_id :400; target_price_id = params[:target_price_id] :401
(NOT determine_price_id — confirmed); return_url build :403-407; blank-param guard :409 →
redirect :411; ValidateSubscriptionChange action_type 'change' :418; `unless result.success?`
:424 → redirect :427 + return :428; options/Session.create :452; `redirect_to session.url` :457;
rescue Stripe::InvalidRequestError :458 (Sentry) → redirect :463; rescue StandardError :464
(Sentry) → redirect :469. ALL correct. All guards use redirect_to (never raise) — confirmed.

`determine_price_id` (def :630, private below :628): `params.key?(:price_id)` :631 → returns
`params[:price_id]` (String) :632; else `Stripe::Price.list({ active: true, limit: 10,
expand: ['data.tiers'] })` :634 → `prices.data.find { |price| price.lookup_key ==
DEFAULT_PRICE_LOOKUP_KEY }` :637 (Stripe::Price object). Return-type divergence (String vs
object) correct. `DEFAULT_PRICE_LOOKUP_KEY = 'plan_simple_ats_per_job_tiered'` :7 correct.
8 call sites (:50, :198, :252, :279, :299, :311, :343, :643) — grep confirms exactly these 8.

Price-model helper chain :630 / :642 / :649 / :663 (determine_price_id /
determine_product_info / get_product_from_price_id / determine_lookup_key) — all correct.

Policy chain: change_subscription? → billing_policy.rb:24 → is_org_admin? application_policy.rb:50
→ is_org_owner? :46-48 — all correct.

## Discrepancies

NONE. The trace is accurate for the routes + controller-actions + determine_price_id segment.
