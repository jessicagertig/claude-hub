# Round 8 — ROUTES + CONTROLLER segment audit

Segment: `config/routes.rb` `ai_credit_purchases` collection + every `OrganizationAiCreditPurchasesController` action in the subscription-change flow (`show`, `customer_subscription`, `change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `continue_change_subscription_portal_session`), compared identifier-by-identifier to the analog `BillingController` in the trace.

Chain traced:
`config/routes.rb:190-202`
→ `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (5 flow actions + `determine_price_id`)
→ `app/models/organization_ai_credit_purchase.rb:260` (`stripe_subscription` → `Stripe::Subscription.retrieve` boundary)
→ `app/policies/billing_policy.rb:24` (`change_subscription?` → `is_org_admin?`), `app/policies/organization_ai_credit_purchase_policy.rb` (`prices?`/`show?` → `is_org_user?`)
Compared against `app/controllers/api/v1/billing_controller.rb:268-470` / `:606-621` / `:630-640` and the analog trace.

---

## Result: 0 unsanctioned deviations

Every structural divergence between OURS and the analog in this segment is already covered by `SANCTIONED-subscription-change.md` (#1–#5) or `AGENT-WHITELIST-subscription-change.md` (W1–W3). Detail of what was verified and which sanction covers each divergence:

### Routes (`config/routes.rb:190-202`) — MATCH
- HTTP verbs/action names mirror the analog billing collection (`config/routes.rb:163-186`): `post :change_subscription_portal_session`, `post :update_payment_method_and_subscription_portal_session`, `get :customer_subscription`, `get :continue_change_subscription_portal_session` — all present with the same verbs as the analog.
- Mounted under `resource :ai_credit_purchases, controller: 'organization_ai_credit_purchases'` instead of `resources :billing` — domain-path/naming (SANCTIONED #2/#5; the continue-endpoint path consequence is W2).
- The analog's `post :change_subscription` (UNUSED action) has no OURS counterpart — that action is not on the audited flow (analog trace item: "marked `# UNUSED`"), so its absence is not a flow deviation.

### `customer_subscription` (`:420-437`) — MATCH (symptom fix confirmed)
- No `authorize` — matches analog `:606` (no authorize).
- 1st stmt `ap 'GETTING THE AI CREDIT CUSTOMER SUBSCRIPTION'`; 2nd stmt `ap organization_ai_credit_purchase&.stripe_subscription` unconditionally invokes the live-Stripe `stripe_subscription` before the nil-check — preserves the analog's "invoke twice on happy path" structure (`:607-608`/`:614`).
- Display derives from the LIVE Stripe object (`organization_ai_credit_purchase.stripe_subscription`, model `:260-264` → `Stripe::Subscription.retrieve`, same `expand: ['items.data.price.tiers']` as analog `organization.rb:477`), NOT a local `subscription_status` column — the original symptom is fixed.
- Scoping to `organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])` + the extra `organization_ai_credit_purchase.nil? ||` clause in the nil-branch: SANCTIONED #4.

### `change_subscription_portal_session` (`:233-281`) — MATCH
- `authorize :billing, :change_subscription?` → `is_org_admin?` — same org-ADMIN level as analog `:269` (naming via BillingPolicy, SANCTIONED #5).
- `ap` debug, three `raise StandardError` guards (customer / subscription / subscription_item_id) mirror analog `:270`/`:272-274`; subscription guard reads `organization_ai_credit_purchase&.stripe_subscription_id` (SANCTIONED #1/#2/#4) instead of `current_organization.stripe_subscription_id`.
- No `ValidateSubscriptionChange` block (and the consequent drop of `determine_price_id` from 3 calls to 2): SANCTIONED #3.
- `options` block byte-identical to analog `:290-304` except `subscription: organization_ai_credit_purchase.stripe_subscription_id` (SANCTIONED #1).
- `Stripe::BillingPortal::Session.create`, `PosthogTrackJob.perform_later(current_user.id, 'change_subscription_stripe_portal_opened', { price_id: determine_price_id })`, `render json: { redirectUrl: session.url }`: identical to analog `:306`/`:311`/`:313`.
- Three method rescues (`Pundit::NotAuthorizedError`, `Stripe::InvalidRequestError`, `StandardError`); the `StandardError` rescue does NOT call Sentry — correctly preserves the analog asymmetry (`:324-326`, no Sentry).

### `update_payment_method_and_subscription_portal_session` (`:286-338`) — MATCH
- `authorize :billing, :change_subscription?` + `ap` debug + three guards mirror analog `:332-337` (subscription guard on the purchase row, SANCTIONED #1/#4).
- `subscription_item_id`, `final_return_path = params[:return_url].presence || '/account'`, `final_return_url`, `target_price_id = determine_price_id`: identical to analog `:339-343`.
- `continue_url` points at `/api/v1/ai_credit_purchases/continue_change_subscription_portal_session` (not `/api/v1/billing/...`): W2. Query-string assembly (`CGI.escape` on `subscription_item_id` / `target_price_id` / `final_return_url`) identical to analog `:346-349`.
- `payment_method_update` options block with `after_completion.redirect.return_url: continue_url` + top-level `return_url: final_return_url`: identical to analog `:351-361`.
- `StandardError` rescue DOES call `Sentry.capture_exception` — correctly preserves the analog asymmetry vs. the change action (analog `:376-379`).

### `continue_change_subscription_portal_session` (`:345-415`) — MATCH
- No `authorize`; first stmt `ap`; two early customer/subscription-blank guards `redirect_to "#{params[:return_url]}?error=subscription_update_failed"` using RAW `params[:return_url]` (analog `:390-398`); the subscription guard reads the purchase row (SANCTIONED #1/#4).
- `subscription_item_id`/`target_price_id` from params (not `determine_price_id`), `return_url` http/relative ternary with `/hire/settings/billing` fallback, param-blank guard: identical to analog `:400-412`.
- No `ValidateSubscriptionChange` block: SANCTIONED #3.
- `subscription_update_confirm` options block with `subscription: organization_ai_credit_purchase.stripe_subscription_id` (SANCTIONED #1) + `price: target_price_id`; happy terminal `redirect_to session.url`; both rescues `Sentry.capture_exception` + log + `redirect_to "#{return_url}?error=subscription_update_failed"`: identical structure to analog `:431-470` (including the pre-`return_url`-assignment nil-relative-redirect caveat).

### `determine_price_id` (`:448-454`) — MATCH
- Preserves the analog's `if params.key?(:price_id)` guard (`:631`); else-branch raises `StandardError, 'Price ID is missing.'` instead of resolving the main-plan `DEFAULT_PRICE_LOOKUP_KEY`: W1.

---

deviation_count: 0
