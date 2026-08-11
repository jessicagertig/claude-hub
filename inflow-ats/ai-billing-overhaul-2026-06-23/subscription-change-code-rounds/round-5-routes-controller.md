# Round 5 — ROUTES + CONTROLLER segment

Reviewer: `routes-controller`. Segment: `config/routes.rb` ai_credit_purchases collection + `OrganizationAiCreditPurchasesController` actions in the subscription-change flow (`#show`, `#customer_subscription`, `#change_subscription_portal_session`, `#update_payment_method_and_subscription_portal_session`, `#continue_change_subscription_portal_session`, plus private `determine_price_id`).

Chain traced:
- `config/routes.rb:190-202` (ai_credit_purchases collection) → `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` → `app/models/organization_ai_credit_purchase.rb:260` (`stripe_subscription`) → `app/policies/billing_policy.rb` / `app/policies/organization_ai_credit_purchase_policy.rb` → `app/policies/application_policy.rb` (`is_org_user?` / `is_org_admin?`).
- Analog: `app/controllers/api/v1/billing_controller.rb:268-470, 535-541, 606-640`; trace `traces/subscription-change-analog-trace.md` items 6, 18b, 19-30.

## Result: 0 un-sanctioned deviations

Every structural element of OUR segment matches the analog modulo SANCTIONED / WHITELIST entries (matched by substance):

### Routes (`config/routes.rb:190-202`)
- `post :change_subscription_portal_session` (`:195`), `post :update_payment_method_and_subscription_portal_session` (`:196`), `get :customer_subscription` (`:199`), `get :continue_change_subscription_portal_session` (`:200`) — verbs match analog (`billing_controller` collection `routes.rb:169/170/177/178`). The collection is mounted on `resource :ai_credit_purchases` (singular, `only: [:show]`) vs analog `resources :billing` — the `#show` route is W3; the singular/plural resource shape is forced by the persisted-purchase-row data model (SANCTIONED #2 / W3).

### `#customer_subscription` (`:420-437`)
- NO `authorize` — matches analog `customer_subscription` (`billing_controller.rb:606`, no authorize) (trace item 6).
- `ap organization_ai_credit_purchase&.stripe_subscription` (`:424`) UNCONDITIONALLY (pre-nil-check) calls `stripe_subscription`, then `:430` calls it again on the happy path — TWICE, matching the analog's `:608` + `:614` double-call. The `&.` and the scoped `find_by(subscription_status: [:active, :past_due])` lookup (`:423`) plus the added `organization_ai_credit_purchase.nil? ||` in the nil-check (`:426`) are forced because the purchase row can be absent where the analog's `current_organization` is always present (SANCTIONED #4).
- Render shapes `{ subscription: nil }` (`:427`) / `{ subscription: <live Stripe obj> }` (`:430`, no serializer) / rescue `{ errors: ['Unable to load subscription'] }` (`:434`) match analog `:611/:614/:618` exactly. `Sentry.capture_exception` + `Rails.logger.error` in rescue match `:616-617`.

### `#change_subscription_portal_session` (`:233-281`)
- `authorize :billing, :change_subscription?` (`:234`) → `is_org_admin?` — matches analog `:269` (org-ADMIN). `ap` literal adapted (SANCTIONED #5 naming).
- Three guards (`:239-241`) match analog `:272-274`, adapted to `organization_ai_credit_purchase&.stripe_subscription_id` (SANCTIONED #2/#4).
- NO `ValidateSubscriptionChange` call — correctly omitted (SANCTIONED #3); the analog's `:277-286` block is absent by design.
- options block: `subscription: organization_ai_credit_purchase.stripe_subscription_id` (`:251`, SANCTIONED #1), `id: subscription_item_id` (`:253`), `price: determine_price_id` (`:254`), `quantity: 1` (`:255`), `return_url: "...#{params[:return_url] || '/account'}"` (`:247`) — match analog `:290-304`.
- `Stripe::BillingPortal::Session.create` + two `ap` debug (`:261-263`), `PosthogTrackJob.perform_later(... 'change_subscription_stripe_portal_opened', { price_id: determine_price_id })` (`:265`), `render json: { redirectUrl: session.url }` (`:267`) — match analog `:306-313`.
- Rescues (`:268-280`): Pundit (Sentry + `ap` x2 + logger + render), `Stripe::InvalidRequestError` (Sentry + logger + render), `StandardError` (logger + render, NO Sentry) — match analog `:314-326` exactly, including the analog's distinctive no-Sentry-on-StandardError.

### `#update_payment_method_and_subscription_portal_session` (`:286-338`)
- `authorize :billing, :change_subscription?` (`:287`) org-ADMIN, `ap` adapted — matches analog `:332-333`.
- Statement order matches analog `:335-367`: guards (`:292-294`, adapted SANCTIONED #4), `subscription_item_id` (`:296`), `final_return_path = params[:return_url].presence || '/account'` (`:298`), `final_return_url` (`:299`), `target_price_id = determine_price_id` (`:301`), `continue_url` (`:304-307`), options `payment_method_update` with `after_completion.redirect.return_url: continue_url` and top-level `return_url: final_return_url` (`:309-319`), session create + ap (`:321-323`), `render json: { redirectUrl: session.url }` (`:325`).
- `continue_url` base path `/api/v1/ai_credit_purchases/...` (`:304`) instead of `/api/v1/billing/...` — W2.
- Rescues (`:326-337`): Pundit (Sentry + logger + render, NO `ap`), `Stripe::InvalidRequestError`, `StandardError` (Sentry + logger + render) — match analog `:368-379`.

### `#continue_change_subscription_portal_session` (`:345-415`)
- NO `authorize` — matches analog `:385`. First `ap` debug (`:346`) before guards — matches analog `:386`.
- Guards are `redirect_to ...?error=` (never raise): customer-blank (`:351-354`, RAW `params[:return_url]`), subscription-blank (`:356-359`, `organization_ai_credit_purchase&.stripe_subscription_id`, SANCTIONED #4) — match analog `:390-398`.
- `subscription_item_id = params[:subscription_item_id]` (`:361`), `target_price_id = params[:target_price_id]` (`:362`, NOT `determine_price_id`) — match analog `:400-401`.
- `return_url` computed (`:364-368`) AFTER the two early guards (same nil-relative caveat for pre-`:364` raises as the analog's `:403`) — matches analog `:403-407`.
- combined blank guard (`:370-373`) matches analog `:409-411`.
- NO `ValidateSubscriptionChange` block — correctly omitted (SANCTIONED #3); analog's `:418-429` absent by design.
- confirmation options `subscription_update_confirm` with `subscription: organization_ai_credit_purchase.stripe_subscription_id` (`:387`, SANCTIONED #1), `price: target_price_id` (`:390`); happy terminal `redirect_to session.url` (`:402`, NOT `render json`) — match analog `:433-457`.
- Rescues (`:403-414`): `Stripe::InvalidRequestError` + Sentry → `redirect_to "#{return_url}?error=subscription_update_failed"`; `StandardError` + Sentry → same — match analog `:458-469`.

### `determine_price_id` (`:448-454`)
- Preserves analog's `if params.key?(:price_id)` guard (`:449`) returning `params[:price_id]` (`:450`); else-branch raises instead of resolving a `DEFAULT_PRICE_LOOKUP_KEY` fallback — W1.

### Gating asymmetry (cross-action, observed — NOT a deviation)
The analog's three-way gating asymmetry is preserved at the GATE LEVEL: `customer_subscription` + `continue_change_subscription_portal_session` NO authorize; the two change actions org-ADMIN (`change_subscription?`); `prices` org-USER. OUR `#prices` (`:217`) authorizes `:organization_ai_credit_purchase, :show?` → `OrganizationAiCreditPurchasePolicy#show?` → `is_org_user?` — a differently-named policy/symbol than the analog's `:billing, :prices?`, but the SAME org-USER gate level. Within the `ai_credit_*` naming family (SANCTIONED #5); not a gate-level deviation. (`#prices` is adjacent to, not strictly within, the five audited actions.)

No EXTRA un-sanctioned files, columns, params, render/redirect shapes, or guards found in this segment.
