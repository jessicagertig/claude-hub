# Round 7 — ROUTES + CONTROLLER segment audit

Reviewer: routes-controller. Segment: `config/routes.rb` ai_credit_purchases collection + `OrganizationAiCreditPurchasesController` actions in the subscription-change flow (`show`, `customer_subscription`, `change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `continue_change_subscription_portal_session`).

Chain traced: `config/routes.rb:190-202` → `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (all 5 in-scope actions + `determine_price_id`) → analog `app/controllers/api/v1/billing_controller.rb:268-327 / :331-380 / :385-470 / :606-621 / :630-640` → `app/models/organization_ai_credit_purchase.rb:260-264` (`#stripe_subscription`), `:82-83` (`kind` / `subscription_status` enums) → Stripe gem boundary.

## Result: 0 unsanctioned deviations

Every structural difference between OURS and the analog `BillingController` in this segment is already covered by `SANCTIONED-subscription-change.md` (#1–#5) or `AGENT-WHITELIST-subscription-change.md` (W1–W3). Verified line-by-line, action-by-action:

### `customer_subscription` (ours :420-437 vs analog :606-621)
- No `authorize` (matches analog item 6). SAME.
- `ap organization_ai_credit_purchase&.stripe_subscription` (:424) unconditionally invokes `#stripe_subscription` before the nil-check, same as analog `:608` → calls it twice on happy path. SAME structure; purchase-row scope is SANCTIONED #4.
- Branch `organization_ai_credit_purchase.nil? || ...stripe_subscription_id.nil?` (:426) vs analog `stripe_subscription_id.nil?` (:609) — extra `.nil?` purchase guard forced because the purchase row may be absent (analog org always present). SANCTIONED #4.
- Render shapes `{ subscription: nil }` / raw live Stripe object (no serializer) / `{ errors: ['Unable to load subscription'] }` all match analog. SAME.
- `OrganizationAiCreditPurchase#stripe_subscription` (:260-264) is a verbatim structural match of `Organization#stripe_subscription` (analog :474-477): guard `return if stripe_subscription_id.nil?` then `Stripe::Subscription.retrieve({ id:, expand: ['items.data.price.tiers'] })`. SAME terminal.

### `change_subscription_portal_session` (ours :233-281 vs analog :268-327)
- `authorize :billing, :change_subscription?` (:234) = analog :269. SAME.
- `ap` debug text differs only by `AI Credit` naming. SANCTIONED #5.
- Three guards (:239-241) match analog :272-274; subscription guard reads `organization_ai_credit_purchase&.stripe_subscription_id` (SANCTIONED #1/#4).
- Omits `ValidateSubscriptionChange.call` + `unless result.success?` gate (analog :277-286). SANCTIONED #3. Consequence: `determine_price_id` fires 2× here (:254, :265) vs analog's 3× (:279/:299/:311) — direct downstream of #3, not a separate deviation.
- Options `subscription: organization_ai_credit_purchase.stripe_subscription_id` (:251) vs analog `current_organization.stripe_subscription_id`. SANCTIONED #1. Rest of options block (`items`, `id: subscription_item_id`, `price: determine_price_id`, `quantity: 1`) SAME.
- `PosthogTrackJob.perform_later(...)` (:265), `render json: { redirectUrl: session.url }` (:267) SAME.
- Three rescues (:268-280): Pundit (Sentry + ap + log + admins-only msg), Stripe::InvalidRequestError (Sentry + log + e.message), StandardError (log + e.message, NO Sentry) — exact match of analog :314-326 including the deliberate no-Sentry on StandardError.

### `update_payment_method_and_subscription_portal_session` (ours :286-338 vs analog :331-380)
- authorize / ap / three guards (:287-294) match analog :332-337 (subscription guard SANCTIONED #1/#4).
- `subscription_item_id` / `final_return_path` (`.presence || '/account'`) / `final_return_url` / `target_price_id = determine_price_id` (:296-301) match analog :339-343.
- `continue_url` base path `/api/v1/ai_credit_purchases/...` (:304) vs analog `/api/v1/billing/...`. WHITELIST W2.
- Options (`payment_method_update`, `after_completion.redirect.return_url: continue_url`, top-level `return_url: final_return_url`) match analog :351-361. SAME.
- Three rescues (:326-337): Pundit (Sentry, no ap), Stripe::InvalidRequestError (Sentry + e.message), StandardError (Sentry + 'Unable to start...') — exact match of analog :368-379, including StandardError DOES Sentry here (contrast with change action). SAME.

### `continue_change_subscription_portal_session` (ours :345-415 vs analog :385-470)
- No `authorize` (matches analog). SAME.
- First statement `ap` (naming, SANCTIONED #5).
- Two blank-guards redirect with RAW `params[:return_url]` (:351-359) match analog :390-398.
- `subscription_item_id` / `target_price_id = params[:target_price_id]` (:361-362) match analog :400-401.
- `return_url` http-prefix ternary + `/hire/settings/billing` fallback (:364-368) match analog :403-407.
- `subscription_item_id.blank? || target_price_id.blank?` guard → redirect (:370-373) matches analog :409-411.
- Omits `ValidateSubscriptionChange.call` + `unless result.success?` redirect gate (analog :418-429). SANCTIONED #3.
- Options `subscription: organization_ai_credit_purchase.stripe_subscription_id` (:387) SANCTIONED #1; rest SAME; happy terminal `redirect_to session.url` (:402) matches analog :457.
- Two rescues (:403-414): Stripe::InvalidRequestError (Sentry + redirect ?error=...) and StandardError (Sentry + redirect ?error=...) match analog :458-469.

### `determine_price_id` (ours :448-454 vs analog :630-640)
- `if params.key?(:price_id)` guard SAME; else-branch raises instead of resolving `DEFAULT_PRICE_LOOKUP_KEY` price. WHITELIST W1.

### routes (ours :190-202 vs analog :163-186)
- `resource :ai_credit_purchases, only: [:show]` (singular, for the EXTRA `#show`) vs analog `resources :billing`. The `#show` action + singular `resource` are WHITELIST W3.
- In-scope collection verbs match: `post :change_subscription_portal_session` (:195), `post :update_payment_method_and_subscription_portal_session` (:196), `get :customer_subscription` (:199), `get :continue_change_subscription_portal_session` (:200) = analog :169/:170/:177/:178. SAME.

No EXTRA guard, param, render/redirect shape, or rescue branch was found in this segment that is not accounted for by the sanctioned list or whitelist.
