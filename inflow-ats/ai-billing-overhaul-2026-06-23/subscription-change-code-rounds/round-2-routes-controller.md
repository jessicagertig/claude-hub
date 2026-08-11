# Round 2 — Routes + Controller segment (routes-controller)

Adversarial audit of OUR routes (`config/routes.rb` ai_credit_purchases collection) and `OrganizationAiCreditPurchasesController` actions in the subscription-change flow (`show`, `customer_subscription`, `change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `continue_change_subscription_portal_session`) against the verified analog trace (`BillingController`).

Chain traced:
- `config/routes.rb:190-202` (ours) vs `config/routes.rb:163-186` (analog billing block)
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` vs `app/controllers/api/v1/billing_controller.rb`
- `app/models/organization_ai_credit_purchase.rb:260-264` (`#stripe_subscription`) vs `app/models/organization.rb:474-477` (`Organization#stripe_subscription`) — terminal `Stripe::Subscription.retrieve` STRIPE boundary, identical args except column source (sanctioned).

## Structural comparison result

Every guard, variable, param, render/redirect shape, and rescue ladder in the five actions matches the analog structurally. All divergences map to a SANCTIONED or WHITELISTED entry (matched by substance):

- Subscription source is `current_organization.organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])` instead of `current_organization` columns — SANCTIONED #1/#2/#4.
- `flow_data.subscription` / continue-options `subscription:` use `organization_ai_credit_purchase.stripe_subscription_id` — SANCTIONED #1.
- `change_subscription_portal_session` and `continue_change_subscription_portal_session` omit the `ValidateSubscriptionChange.call(...)` block (analog `billing_controller.rb:277-286` and `:418-429`) — SANCTIONED #3.
- `ai_credit`-flavored `ap` debug strings — SANCTIONED #5.
- `customer_subscription` nil-guard is `organization_ai_credit_purchase.nil? || organization_ai_credit_purchase.stripe_subscription_id.nil?` rather than the analog's bare `current_organization.stripe_subscription_id.nil?` (`billing_controller.rb:609`) — forced extra `.nil?` term because the purchase row itself may be absent; same forced cause as SANCTIONED #4 (scoped to the purchase row, which can be missing).
- `determine_price_id` else-branch raises instead of resolving `DEFAULT_PRICE_LOOKUP_KEY` — WHITELIST W1.
- `continue_url` base path `/api/v1/ai_credit_purchases/...` — WHITELIST W2.
- `resource :ai_credit_purchases` (singular) vs `resources :billing` (plural); the collection verbs (`post :change_subscription_portal_session`, `post :update_payment_method_and_subscription_portal_session`, `get :customer_subscription`, `get :continue_change_subscription_portal_session`) are identical shapes — singular resource is forced by the one-subscription-per-org data model, SANCTIONED #2 family.

Action-by-action confirmation that the analog structure is preserved:

- `customer_subscription` (ours `:420-437` vs analog `:606-621`): NO `authorize` (matches analog's three-way gating asymmetry — `customer_subscription` is the no-authorize leg); unconditional pre-nil-check `ap ...stripe_subscription` debug invoke preserved (ours `:424`); `render json: { subscription: nil }` null branch; `begin/rescue StandardError` happy branch rendering the raw live Stripe object via `organization_ai_credit_purchase.stripe_subscription` (model `:260-263` → `Stripe::Subscription.retrieve` STRIPE terminal) with no serializer; `Sentry.capture_exception` + `Rails.logger.error` + `render json: { errors: [...] }` error branch. SCREEN terminal derives current subscription from LIVE Stripe, NOT a local `subscription_status` column — the analog-matching fix is in place.
- `change_subscription_portal_session` (ours `:233-281` vs analog `:268-327`): `authorize :billing, :change_subscription?`; three `raise StandardError` entry guards; `subscription_item_id = params[:subscription_item_id]`; `subscription_update_confirm` options; `Stripe::BillingPortal::Session.create` + two `ap`; `PosthogTrackJob.perform_later(current_user.id, 'change_subscription_stripe_portal_opened', { price_id: determine_price_id })`; `render json: { redirectUrl: session.url }`; rescue ladder Pundit (with `ap` pair) / `Stripe::InvalidRequestError` / `StandardError`-no-Sentry — all match.
- `update_payment_method_and_subscription_portal_session` (ours `:286-338` vs analog `:331-380`): authorize; `ap` (2nd statement); three guards; `final_return_path`/`final_return_url` (`/account` fallback); `target_price_id = determine_price_id`; `continue_url` with `CGI.escape` of item/price/return_url; `payment_method_update` options with `after_completion.redirect.return_url: continue_url` and top-level `return_url: final_return_url`; `Stripe::BillingPortal::Session.create`; render; rescue ladder including `StandardError`+`Sentry.capture_exception` (the structural distinction from the change action's no-Sentry StandardError rescue) — all match.
- `continue_change_subscription_portal_session` (ours `:345-415` vs analog `:385-470`): NO authorize; first-statement `ap`; two blank-guard `redirect_to` using RAW `params[:return_url]`; `subscription_item_id`/`target_price_id` from params (NOT `determine_price_id`); `return_url` assignment block with `start_with?('http')` and `/hire/settings/billing` fallback; combined param-blank guard `redirect_to`; `subscription_update_confirm` options; `redirect_to session.url` happy terminal; both method rescues `redirect_to "#{return_url}?error=subscription_update_failed"` with Sentry. ValidateSubscriptionChange block omitted (SANCTIONED #3). All other structure matches.

## Deviations (non-sanctioned)

NONE. Zero unforced deviations found in this segment. Every divergence is covered by SANCTIONED-subscription-change.md (#1–#5) or AGENT-WHITELIST-subscription-change.md (W1, W2), matched by substance.
