# No-Card Subscription-Change Chain Audit vs Analog

## Verdict
6 unsanctioned deviations.

## Unsanctioned deviations

| aspect | ours file:line | analog file:line | problem | severity |
| --- | --- | --- | --- | --- |
| Subscription-existence guard restructured from a single raise into a record lookup plus two render_general_errors early-returns | app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:222-231 | app/controllers/api/v1/billing_controller.rb:336 | Analog gates subscription existence with ONE line: `raise StandardError, 'No active subscription found.' unless current_organization.stripe_subscription_id.present?` caught by the method-level StandardError rescue. Ours replaces it with (a) a `purchase = current_organization.organization_ai_credit_purchases.subscription.find_by(...)` lookup, (b) `unless purchase ... render_general_errors(['No active credit subscription']); return`, and (c) `if purchase.stripe_subscription_id.blank? ... render_general_errors(['Subscription is not yet active in Stripe...']); return`. Allowlist #1 only sanctions WHICH subscription id is used, not converting one raise-guard into a lookup plus two render_general_errors branches. Error-surfacing mechanism (render_general_errors early-return vs raise->rescue) and guard count (2 vs 1) both diverge. A lookup is unavoidable to obtain purchase.stripe_subscription_id, but the analog expresses the not-yet-active condition as one raise, not two render_general_errors returns. | low |
| Extra lookup_key resolution + ai_credit_subscription_plan_lookup_key? validation block injected into update_payment_method_and_subscription_portal_session | app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:239-243 | app/controllers/api/v1/billing_controller.rb:343 | Analog's update_payment_method_and_subscription_portal_session performs NO price/lookup validation — it assigns `target_price_id = determine_price_id` and proceeds straight to building continue_url. Ours adds `lookup_key = Stripe::Price.retrieve(target_price_id).lookup_key` plus `unless OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?(lookup_key) ... render_general_errors(['Invalid subscription price']); return`. Allowlist #2/#3 cover lookup_key resolution and the absence of ValidateSubscriptionChange, but the analog's THIS method has no validation gate of any kind (gating lives only in sibling change_subscription_portal_session and continue_change_subscription_portal_session). Injecting a validation block here is EXTRA structure not in the analog and not covered by the allowlist for this method, and incurs an extra synchronous Stripe::Price.retrieve round-trip. | medium |
| return_url default fallback literal | app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:309 | app/controllers/api/v1/billing_controller.rb:406 | OURS falls back to `"#{Variables::AtsRootUrl}/account"` when params[:return_url] is absent; the matched analog method continue_change_subscription_portal_session falls back to `"#{Variables::AtsRootUrl}/hire/settings/billing"`. Allowlist #6 sanctions /account as "matches the analog," but that is false for THIS analog method specifically — every OTHER billing method (lines 21, 292, 340) uses /account, yet continue_change_subscription_portal_session (line 406) is the single exception using /hire/settings/billing. Since return_url is also the redirect target in both rescue blocks (OURS 358 and 364, analog 463 and 469), this changes both the success-no-param landing page AND the error-redirect destination: ours lands on /account, analog lands on /hire/settings/billing. | low |
| onError toast kind/delay | app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:98-105 | app/javascript/.../AccountBillingPlans.tsx:265-274 | Analog surfaces the update-payment-method failure as `kind: "error"` with no delay; ours uses `kind: "warning"` with `delay: 10000`. The no-card payment-method-update failure is an error condition (payment method update + subscription change failed) and the analog classifies it as such. Ours downgrades it to a warning and adds an auto-dismiss delay the analog does not have. Not in allowlist; changes severity classification of the same failure. | low |
| Dedicated handler structure collapsed inline | app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:87-109 | app/javascript/.../AccountBillingPlans.tsx:243-278 (handleUpdateWithPaymentMethod) called from 332-335 | Analog isolates the update-payment-method flow in a named handler handleUpdateWithPaymentMethod that the gate-wrapper delegates to; ours inlines the entire updateWithPaymentMethod(...) call (variables + onSuccess + onError) directly inside the no-card else branch of handleSelectTier. This is a WHERE-the-logic-lives divergence. Allowlist item 3 removes only the checkPlanLimitsGate/ValidateSubscriptionChange/PlanChangeBlockedModal gating, not the existence of the separate handler function. Borderline given the gate wrapper is gone (no second caller to justify a shared handler), but still a structural deviation from the analog's skeleton. | low |
| window.logger calls dropped | app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:95-96 (onSuccess), :98-106 (onError); app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts:80-84 (hook onSuccess) | app/javascript/.../AccountBillingPlans.tsx:257-262 / :269-273; app/javascript/.../useBilling.ts:197-201 | Analog emits window.logger lines at three points: component-level onSuccess ("completed update payment method and change subscription"), component-level onError ("ERROR updating payment method and changing subscription"), and hook-level onSuccess ("useUpdateWithPaymentMethod"). Ours has none. window.logger is an established, encouraged pattern (CLAUDE.md 2a) applied consistently by the analog across the flow; dropping all three is a partial implementation that silently skips a behavior the analog code path has. | low |

## Matched aspects

Update-payment-method method (controller):
- authorize :billing, :change_subscription? (ours:219 / analog:332)
- Opening ap debug string (ours:220 / analog:333)
- Stripe customer guard: raise StandardError 'No Stripe customer found.' unless stripe_customer_id.present? (ours:233 / analog:335)
- Subscription item ID guard: raise StandardError 'Subscription item ID is missing.' (ours:234 / analog:337)
- subscription_item_id param read (ours:237 / analog:339)
- final_return_path return_url.presence || '/account' + final_return_url assignment (ours:245-246 / analog:340-341) — allowlist #6
- continue_url built with CGI.escape on subscription_item_id, target_price_id, return_url (ours:249-252 / analog:346-349); /ai_credit_purchases vs /billing namespace is correct route-matched delta
- options hash: customer, flow_data type payment_method_update, after_completion redirect to continue_url, return_url final_return_url (ours:254-264 / analog:351-361)
- Stripe::BillingPortal::Session.create(options) + two ap lines (ours:266-268 / analog:363-365)
- render json: { redirectUrl: session.url } (ours:270 / analog:367)
- rescue Pundit::NotAuthorizedError -> Sentry + Rails.logger.error + render_general_errors 'Only admins...' (ours:271-274 / analog:368-371)
- rescue Stripe::InvalidRequestError -> Sentry + log + render_general_errors([e.message]) (ours:275-278 / analog:372-375)
- rescue StandardError -> Sentry + log + render_general_errors 'Unable to start payment method update flow' (ours:279-282 / analog:376-379)
- No PostHog call in this method on either side
- Route: post :update_payment_method_and_subscription_portal_session on collection (routes.rb:195 ours / :170 analog)
- Method-level rescue with no inner begin block — allowlist #5
- target_price_id direct-param read matches the established pattern in sibling change_subscription_portal_session — not a defect

Continuation-action method (controller):
- Opening ap log string identical (OURS:289 / analog:386)
- stripe_customer_id.blank? guard with identical Rails.logger.error + redirect_to "#{params[:return_url]}?error=subscription_update_failed" (OURS:293-296 / analog:390-393)
- Subscription-missing guard structurally equivalent — OURS purchase.nil? || purchase.stripe_subscription_id.blank? vs analog current_organization.stripe_subscription_id.blank? (allowlist #1), identical log + redirect (OURS:298-301 / analog:395-398)
- Reads subscription_item_id and target_price_id from params (OURS:303-304 / analog:400-401)
- return_url computation branch: present? ? (start_with?('http') ? raw : AtsRootUrl+param) : default — identical control structure, differs only in the default literal (OURS:306-310 / analog:403-407)
- Blank-params guard: subscription_item_id.blank? || target_price_id.blank? with identical log + redirect (OURS:312-315 / analog:409-412)
- Three diagnostic ap logs after the guard (OURS:317-319 / analog:414-416)
- Validation gate placement and on-failure redirect_to "#{return_url}?error=#{CGI.escape(...)}" + return — OURS substitutes lookup_key resolution for analog's ValidateSubscriptionChange.call (allowlist #2/#3), same shape (OURS:321-327 / analog:418-429)
- flow_data options hash: customer, return_url, flow_data.type 'subscription_update_confirm', subscription_update_confirm.subscription, items:[{id, price, quantity:1}] — identical shape; subscription source purchase.stripe_subscription_id vs current_organization.stripe_subscription_id (allowlist #1), price target_price_id on both (OURS:331-345 / analog:433-447)
- Stripe::BillingPortal::Session.create(options), ap session, redirect_to session.url (OURS:347-352 / analog:452-457)
- rescue Stripe::InvalidRequestError: Sentry.capture_exception, Rails.logger.error, ap, redirect_to with error param (OURS:353-358 / analog:458-463)
- rescue StandardError: Sentry.capture_exception, Rails.logger.error, ap, redirect_to with error param (OURS:359-364 / analog:464-469)
- No inner begin/rescue; method-level rescue (allowlist #5)
- Route: get on collection, same verb/placement (OURS routes.rb:199 / analog routes.rb:178)

Frontend no-card branch:
- card-on-file predicate stripeDefaultPaymentMethodOnFile identical (AiCreditSubscription.tsx:67 / AccountBillingPlans.tsx:326)
- no-card branch routes to the update-payment-method mutation (AiCreditSubscription.tsx:88 / AccountBillingPlans.tsx:332)
- POSTed variable shape {priceId, subscriptionItemId, returnUrl} identical (AiCreditSubscription.tsx:89-92 / AccountBillingPlans.tsx:251-254)
- apiPost path suffix update_payment_method_and_subscription_portal_session identical (useOrganizationAiCreditPurchase.ts:73 / useBilling.ts:71)
- onSuccess redirects via window.location.href = data.redirectUrl (AiCreditSubscription.tsx:96 / AccountBillingPlans.tsx:263)
- onError fallback string "Unable to update payment method and change subscription." identical (AiCreditSubscription.tsx:101-102 / AccountBillingPlans.tsx:267-268)
- hook onSuccess invalidates the subscription-source query for its own subsystem (useOrganizationAiCreditPurchase.ts:82 organizationAiCreditPurchase / useBilling.ts:202 currentOrganization)
- default return_url page-appropriate literal /hire/settings/... matches analog convention
- Variables wrapping under organizationAiCreditPurchase matches the AI-credit controller param convention used by every sibling AI-credit POST in the same hook file
