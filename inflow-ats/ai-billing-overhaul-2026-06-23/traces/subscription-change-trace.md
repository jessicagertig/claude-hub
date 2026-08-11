# Flow 5 — AI-Credit Subscription-Change / Upgrade-Downgrade Stripe Billing Portal — Structural Trace

Worktree (all paths relative to): `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`

## Files traced

- ANALOG controller: `app/controllers/api/v1/billing_controller.rb`
  - `change_subscription_portal_session` (:268)
  - `update_payment_method_and_subscription_portal_session` (:331)
  - `continue_change_subscription_portal_session` (:385)
  - `customer_subscription` (:606)
  - private `determine_price_id` (:630)
  - `billing_params` (:670) — permits `:price_id`, `:subscription_item_id`, `:return_url` is read raw from `params`
- OURS controller (target): `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` — actions MISSING, must be re-implemented
- Routes: `config/routes.rb` :190–202 — all 4 actions already routed (POST `change_subscription_portal_session`, POST `update_payment_method_and_subscription_portal_session`, GET `customer_subscription`, GET `continue_change_subscription_portal_session`)
- Model: `app/models/organization_ai_credit_purchase.rb` — `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` (:4), `ai_credit_subscription_plan_lookup_key?` (:63), `ai_credit_allocation_for_lookup_key` (:71), `stripe_subscription` instance method (:260), `subscription` scope + `subscription_status` enum (:83)
- Frontend hooks: `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts`
- Frontend view: `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`
- API layer: `app/javascript/shared/queryHooks/api.ts` — `apiPost` applies `allKeysToSnake(variables)` by default (:52)
- Base: `app/controllers/api/v1/base_controller.rb` — `current_organization` (:23), `current_organization_user` (:27)
- `config/initializers/01_variables.rb` — `Variables::AtsRootUrl` (:19)

Chain: `routes.rb` → `organization_ai_credit_purchases_controller.rb` (target) ← mirror of `billing_controller.rb` → `organization_ai_credit_purchase.rb`; driven by `AiCreditSubscription.tsx` → `useOrganizationAiCreditPurchase.ts` → `api.ts (apiPost/allKeysToSnake)`.

---

## CRITICAL — Frontend payload is NOT what the prompt described

The prompt states the frontend "sends only `{ stripePriceLookupKey, returnUrl }`" and that the action must reconstruct `subscription_item_id` server-side. **The CURRENT code contradicts this.** The actual payload is `{ priceId, subscriptionItemId, returnUrl }`:

- `useChangeAiCreditSubscriptionViaStripePortal` posts `variables: { priceId, subscriptionItemId, returnUrl }` (`useOrganizationAiCreditPurchase.ts` :44–47).
- `useUpdateAiCreditSubscriptionWithPaymentMethod` posts the same shape (:73–76).
- `apiPost` runs `allKeysToSnake` (`api.ts` :52), so the server receives `params[:price_id]`, `params[:subscription_item_id]`, `params[:return_url]` — **exactly the analog's keys.**
- `subscriptionItemId` is sourced in the view: `currentSubscriptionItemId = currentSubscription && currentSubscription.items.data[0].id` (`AiCreditSubscription.tsx` :58), where `currentSubscription = aiCreditCustomerSubscriptionData.subscription` (:55–57) — i.e. it comes from the **`customer_subscription` GET endpoint** (`useAiCreditCustomerSubscription`).

Implication for the mirror: the OURS actions can read `params[:subscription_item_id]` directly (analog-faithful). Server-side reconstruction via `Stripe::Subscription.retrieve(...).items.data[0].id` is the **fallback for when `params[:subscription_item_id]` is blank** (sanctioned dev #1/#4 still applies because the live subscription is keyed off `purchase.stripe_subscription_id`, not `organization.stripe_subscription_id`). `customer_subscription` is what populates the item id, and it MUST scope to the purchase row's subscription (sanctioned dev #4).

---

## (a) ANALOG SKELETON — BillingController, verbatim flow_data / render shapes

### A1. `change_subscription_portal_session` (POST) — :268

```
authorize :billing, :change_subscription?
raise unless current_organization.stripe_customer_id.present?      # 'No Stripe customer found.'
raise unless current_organization.stripe_subscription_id.present?  # 'No active subscription found.'
raise unless params[:subscription_item_id].present?                # 'Subscription item ID is missing.'

result = ValidateSubscriptionChange.call(
  organization: current_organization,
  target_price_id: determine_price_id,
  action_type: 'change'
)
unless result.success?
  render_general_errors([result.message]); return
end

subscription_item_id = params[:subscription_item_id]

options = {
  customer: current_organization.stripe_customer_id,
  return_url: "#{Variables::AtsRootUrl}#{params[:return_url] || '/account'}",
  flow_data: {
    type: 'subscription_update_confirm',
    subscription_update_confirm: {
      subscription: current_organization.stripe_subscription_id,
      items: [{
        id: subscription_item_id,    # current subscription item id
        price: determine_price_id,
        quantity: 1
      }]
    }
  }
}

session = Stripe::BillingPortal::Session.create(options)
PosthogTrackJob.perform_later(current_user.id, 'change_subscription_stripe_portal_opened', { price_id: determine_price_id })
render json: { redirectUrl: session.url }

rescue Pundit::NotAuthorizedError => render_general_errors(['Only admins can change subscription settings.'])  # + Sentry + log
rescue Stripe::InvalidRequestError => render_general_errors([e.message])                                        # + Sentry + log
rescue StandardError       => render_general_errors([e.message])                                                # + log
```

### A2. `update_payment_method_and_subscription_portal_session` (POST) — :331

```
authorize :billing, :change_subscription?
raise unless current_organization.stripe_customer_id.present?
raise unless current_organization.stripe_subscription_id.present?
raise unless params[:subscription_item_id].present?

subscription_item_id = params[:subscription_item_id]
final_return_path = params[:return_url].presence || '/account'
final_return_url  = "#{Variables::AtsRootUrl}#{final_return_path}"
target_price_id   = determine_price_id

continue_url = "#{Variables::AtsRootUrl}/api/v1/billing/continue_change_subscription_portal_session" \
               "?subscription_item_id=#{CGI.escape(subscription_item_id)}" \
               "&target_price_id=#{CGI.escape(target_price_id)}" \
               "&return_url=#{CGI.escape(final_return_url)}"

options = {
  customer: current_organization.stripe_customer_id,
  flow_data: {
    type: 'payment_method_update',
    after_completion: {
      type: 'redirect',
      redirect: { return_url: continue_url }
    }
  },
  return_url: final_return_url
}

session = Stripe::BillingPortal::Session.create(options)
render json: { redirectUrl: session.url }

rescue Pundit::NotAuthorizedError => render_general_errors(['Only admins can change subscription settings.'])  # + Sentry + log
rescue Stripe::InvalidRequestError => render_general_errors([e.message])                                        # + Sentry + log
rescue StandardError       => render_general_errors(['Unable to start payment method update flow'])             # + Sentry + log
```

### A3. `continue_change_subscription_portal_session` (GET — browser redirect target, NOT JSON) — :385

```
# No authorize (it's a redirect target hit by the browser after Stripe redirect).
# Guards LOG + REDIRECT (do not raise):
if current_organization.stripe_customer_id.blank?
  log; return redirect_to "#{params[:return_url]}?error=subscription_update_failed"
if current_organization.stripe_subscription_id.blank?
  log; return redirect_to "#{params[:return_url]}?error=subscription_update_failed"

subscription_item_id = params[:subscription_item_id]
target_price_id      = params[:target_price_id]

return_url = if params[:return_url].present?
               params[:return_url].start_with?('http') ? params[:return_url] : "#{Variables::AtsRootUrl}#{params[:return_url]}"
             else
               "#{Variables::AtsRootUrl}/hire/settings/billing"
             end

if subscription_item_id.blank? || target_price_id.blank?
  log; return redirect_to "#{return_url}?error=subscription_update_failed"

result = ValidateSubscriptionChange.call(organization: current_organization, target_price_id: target_price_id, action_type: 'change')
unless result.success?
  redirect_to "#{return_url}?error=#{CGI.escape(result.message)}"; return
end

options = {
  customer: current_organization.stripe_customer_id,
  return_url: return_url,
  flow_data: {
    type: 'subscription_update_confirm',
    subscription_update_confirm: {
      subscription: current_organization.stripe_subscription_id,
      items: [{ id: subscription_item_id, price: target_price_id, quantity: 1 }]
    }
  }
}

session = Stripe::BillingPortal::Session.create(options)
redirect_to session.url            # NOTE: redirect, not render json

rescue Stripe::InvalidRequestError => redirect_to "#{return_url}?error=subscription_update_failed"  # + Sentry + log
rescue StandardError       => redirect_to "#{return_url}?error=subscription_update_failed"          # + Sentry + log
```

### A4. `customer_subscription` (GET) — :606

```
# No authorize in the analog.
if current_organization.stripe_subscription_id.nil?
  render json: { subscription: nil }
else
  begin
    render json: { subscription: current_organization.stripe_subscription }
  rescue StandardError => render json: { errors: ['Unable to load subscription'] }  # + Sentry + log
  end
end
```

### Helper: `determine_price_id` — :630

```
if params.key?(:price_id)
  params[:price_id]
else
  prices = Stripe::Price.list({ active: true, limit: 10, expand: ['data.tiers'] })
  prices.data.find { |price| price.lookup_key == DEFAULT_PRICE_LOOKUP_KEY }
end
```

### Helper: `ValidateSubscriptionChange`

Analog interactor gating downstream-change on plan/job limits (downgrade gated on published-job count). **NOT mirrored in OURS — sanctioned dev #3** (no `ValidateSubscriptionChange` / `PlanFeatureGate` / job-limit gate; AI-credit plans have no job-limit constraint).

---

## (b) OURS TARGET — the 4 re-implemented AI-credit actions (mirror, adapted per sanctioned deviations)

Add to `Api::V1::OrganizationAiCreditPurchasesController`. The subscription record they operate on:

```ruby
organization_ai_credit_purchase =
  current_organization.organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])
```

(Same lookup already used by `#show` :7 and `#cancel` :196.) Its `stripe_subscription_id` and its `stripe_subscription` model method (:260, `Stripe::Subscription.retrieve(id, expand: ['items.data.price.tiers'])`) are the live-subscription source — sanctioned dev #1/#4.

### O1. `change_subscription_portal_session` (POST) — mirror of A1

```
authorize :billing, :change_subscription?

organization_ai_credit_purchase = <active/past_due subscription lookup above>
raise unless current_organization.stripe_customer_id.present?                    # 'No Stripe customer found.'
raise unless organization_ai_credit_purchase&.stripe_subscription_id.present?    # 'No active subscription found.'  (dev #1/#2: purchase row, not org)

# Item id: prefer the param the frontend sends (analog-faithful); reconstruct only when blank (dev #1/#4).
subscription_item_id =
  params[:subscription_item_id].presence ||
  Stripe::Subscription.retrieve(organization_ai_credit_purchase.stripe_subscription_id).items.data.first.id
raise unless subscription_item_id.present?                                       # 'Subscription item ID is missing.'

# NO ValidateSubscriptionChange (sanctioned dev #3)

options = {
  customer: current_organization.stripe_customer_id,
  return_url: "#{Variables::AtsRootUrl}#{params[:return_url] || '/account'}",
  flow_data: {
    type: 'subscription_update_confirm',
    subscription_update_confirm: {
      subscription: organization_ai_credit_purchase.stripe_subscription_id,   # dev #1: purchase row's sub id
      items: [{ id: subscription_item_id, price: determine_price_id, quantity: 1 }]
    }
  }
}

session = Stripe::BillingPortal::Session.create(options)
PosthogTrackJob.perform_later(current_user.id, 'change_subscription_stripe_portal_opened', { price_id: determine_price_id })
render json: { redirectUrl: session.url }

rescue Pundit::NotAuthorizedError => render_general_errors(['Only admins can change subscription settings.'])  # + Sentry + log
rescue Stripe::InvalidRequestError => render_general_errors([e.message])                                        # + Sentry + log
rescue StandardError       => render_general_errors([e.message])                                                # + log
```

### O2. `update_payment_method_and_subscription_portal_session` (POST) — mirror of A2

```
authorize :billing, :change_subscription?

organization_ai_credit_purchase = <active/past_due subscription lookup>
raise unless current_organization.stripe_customer_id.present?
raise unless organization_ai_credit_purchase&.stripe_subscription_id.present?

subscription_item_id =
  params[:subscription_item_id].presence ||
  Stripe::Subscription.retrieve(organization_ai_credit_purchase.stripe_subscription_id).items.data.first.id
raise unless subscription_item_id.present?

final_return_path = params[:return_url].presence || '/account'
final_return_url  = "#{Variables::AtsRootUrl}#{final_return_path}"
target_price_id   = determine_price_id

continue_url = "#{Variables::AtsRootUrl}/api/v1/ai_credit_purchases/continue_change_subscription_portal_session" \
               "?subscription_item_id=#{CGI.escape(subscription_item_id)}" \
               "&target_price_id=#{CGI.escape(target_price_id)}" \
               "&return_url=#{CGI.escape(final_return_url)}"

options = {
  customer: current_organization.stripe_customer_id,
  flow_data: {
    type: 'payment_method_update',
    after_completion: { type: 'redirect', redirect: { return_url: continue_url } }
  },
  return_url: final_return_url
}

session = Stripe::BillingPortal::Session.create(options)
render json: { redirectUrl: session.url }

rescue Pundit::NotAuthorizedError => render_general_errors(['Only admins can change subscription settings.'])  # + Sentry + log
rescue Stripe::InvalidRequestError => render_general_errors([e.message])                                        # + Sentry + log
rescue StandardError       => render_general_errors(['Unable to start payment method update flow'])             # + Sentry + log
```

NOTE on `continue_url` path: analog uses `/api/v1/billing/continue_change_subscription_portal_session`; OURS must use the AI-credit route `/api/v1/ai_credit_purchases/continue_change_subscription_portal_session` (the `:resource :ai_credit_purchases` collection GET at `routes.rb` :200). The singular resource means the path segment is `ai_credit_purchases` — verify the generated path against the route helper before hardcoding.

### O3. `continue_change_subscription_portal_session` (GET — redirect target) — mirror of A3

```
organization_ai_credit_purchase = <active/past_due subscription lookup>

if current_organization.stripe_customer_id.blank?
  log; return redirect_to "#{params[:return_url]}?error=subscription_update_failed"
if organization_ai_credit_purchase&.stripe_subscription_id.blank?
  log; return redirect_to "#{params[:return_url]}?error=subscription_update_failed"

subscription_item_id = params[:subscription_item_id]
target_price_id      = params[:target_price_id]

return_url = if params[:return_url].present?
               params[:return_url].start_with?('http') ? params[:return_url] : "#{Variables::AtsRootUrl}#{params[:return_url]}"
             else
               "#{Variables::AtsRootUrl}/hire/settings/billing"
             end

if subscription_item_id.blank? || target_price_id.blank?
  log; return redirect_to "#{return_url}?error=subscription_update_failed"

# NO ValidateSubscriptionChange (sanctioned dev #3)

options = {
  customer: current_organization.stripe_customer_id,
  return_url: return_url,
  flow_data: {
    type: 'subscription_update_confirm',
    subscription_update_confirm: {
      subscription: organization_ai_credit_purchase.stripe_subscription_id,   # dev #1
      items: [{ id: subscription_item_id, price: target_price_id, quantity: 1 }]
    }
  }
}

session = Stripe::BillingPortal::Session.create(options)
redirect_to session.url            # redirect, not render json

rescue Stripe::InvalidRequestError => redirect_to "#{return_url}?error=subscription_update_failed"  # + Sentry + log
rescue StandardError       => redirect_to "#{return_url}?error=subscription_update_failed"          # + Sentry + log
```

### O4. `customer_subscription` (GET) — mirror of A4

```
organization_ai_credit_purchase = <active/past_due subscription lookup>   # dev #4: scope to purchase row

if organization_ai_credit_purchase.nil? || organization_ai_credit_purchase.stripe_subscription_id.nil?
  render json: { subscription: nil }
else
  begin
    render json: { subscription: organization_ai_credit_purchase.stripe_subscription }   # model method :260, expands items.data.price.tiers
  rescue StandardError => render json: { errors: ['Unable to load subscription'] }  # + Sentry + log
  end
end
```

This is the endpoint the view depends on to populate `currentSubscriptionItemId` (`AiCreditSubscription.tsx` :55–58). The `subscription.items.data[0].id` returned here is what gets posted back as `subscriptionItemId` to O1/O2.

### Helper reuse: `determine_price_id`

OURS reads `params[:price_id]` directly (frontend posts `priceId` → snake-cased to `price_id`). The `else` branch of the analog's `determine_price_id` falls back to a `DEFAULT_PRICE_LOOKUP_KEY` global that is a main-plan concept; in OURS the frontend always sends `price_id`, so the simplest faithful mirror is `params[:price_id]` (no AI-credit default-price fallback exists — there is no single default AI-credit plan). If a private helper is added, keep it minimal: `params[:price_id]`.

### Param permitting

`change_subscription_portal_session` / `update_payment_method_and_subscription_portal_session` read `params[:price_id]`, `params[:subscription_item_id]`, `params[:return_url]` raw (the analog reads them raw from `params`, NOT via a `require`-wrapped permit). Mirror that — read raw; no new strong-params wrapper needed for these top-level scalar params. (`customer_subscription` and `continue_...` take only query params / no body.)

---

## (c) FORCED-DEVIATION LIST (from SANCTIONED-subscription-change.md — do NOT flag/fix)

1. **`flow_data...subscription` uses `organization_ai_credit_purchase.stripe_subscription_id`**, not `current_organization.stripe_subscription_id` — forced by the separate Stripe subscription tracked on the purchase row.
2. **All actions operate on the `OrganizationAiCreditPurchase` record** (active/past_due subscription lookup), not on org columns — forced by the data model.
3. **No `ValidateSubscriptionChange` / `PlanFeatureGate` / job-limit gate** — AI-credit plans have no job-limit constraint (analog gates downgrades on published-job count). Both A1 and A3's `ValidateSubscriptionChange.call(...)` blocks are dropped in O1 and O3.
4. **`customer_subscription` retrieves by `organization_ai_credit_purchase.stripe_subscription_id`** (scoped to the org's active/past_due subscription-kind purchase), not `current_organization.stripe_subscription` — same forced cause as #1.
5. **`ai_credit_*` descriptor naming** — `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` / `ai_credit_subscription_plan_lookup_key?` / `ai_credit_allocation_for_lookup_key` (verified current names in the model :4/:63/:71).

Additional forced item (covered by #1/#4, called out because the prompt singled it out): when `params[:subscription_item_id]` is blank, the item id is reconstructed server-side via `Stripe::Subscription.retrieve(organization_ai_credit_purchase.stripe_subscription_id).items.data.first.id`. In the CURRENT code path the frontend already supplies `subscription_item_id` (sourced from `customer_subscription`), so reconstruction is the blank-fallback, not the primary path.

AGENT-WHITELIST-subscription-change.md is empty at start — no agent-discovered deviations yet.
