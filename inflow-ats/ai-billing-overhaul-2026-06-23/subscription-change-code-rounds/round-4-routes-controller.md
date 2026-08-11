# Round 4 — Routes + Controller (routes-controller agent)

Segment: `config/routes.rb` ai_credit_purchases collection + every `OrganizationAiCreditPurchasesController` action in the subscription-change flow (`show`, `customer_subscription`, `change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `continue_change_subscription_portal_session`), compared identifier-by-identifier to the analog `BillingController` per `traces/subscription-change-analog-trace.md`.

Files traced (chain):
`config/routes.rb:190-202` (OURS) vs `:163-186` (analog `resources :billing`)
→ `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (OURS) vs `app/controllers/api/v1/billing_controller.rb:268-470, 606-621, 630-640` (analog)
→ `app/models/organization_ai_credit_purchase.rb:82` (`enum kind` → `.subscription` scope) + `:260-264` (`#stripe_subscription`) vs `app/models/organization.rb:474-477` (`Organization#stripe_subscription`)

---

## Result of the structural comparison

For all five in-scope actions, OURS matches the analog structurally — same guards, same guard ordering, same param reads (`params[:subscription_item_id]`, `params[:return_url]`, `params[:target_price_id]`, `params[:price_id]`), same `options`/`flow_data` shapes (`subscription_update_confirm` and `payment_method_update`), same `continue_url` construction with `CGI.escape`, same `PosthogTrackJob.perform_later(... price_id: determine_price_id)` call, same terminals (`render json: { redirectUrl: session.url }` / `redirect_to session.url` / `render json: { subscription: ... }`), and identical rescue ladders including every asymmetry the trace calls out:
- `change_subscription_portal_session` `StandardError` rescue has NO Sentry (`:278-280`) while `update_payment_method_and_subscription_portal_session` `StandardError` rescue DOES (`:334-337`) — matches analog `:324-326` (no Sentry) vs `:376-379` (Sentry).
- `continue_change_subscription_portal_session` uses `redirect_to ...?error=` for every guard/rescue (`:351-414`) rather than `raise` — matches analog `:385-470`.
- `customer_subscription` has NO `authorize` (`:420-437`) — matches analog `:606-621`.

Routes: HTTP verbs match for every shared action — `post :change_subscription_portal_session` (`:195` vs `:169`), `post :update_payment_method_and_subscription_portal_session` (`:196` vs `:170`), `get :customer_subscription` (`:199` vs `:177`), `get :continue_change_subscription_portal_session` (`:200` vs `:178`). The `resource :ai_credit_purchases` (singular) vs analog `resources :billing` (plural) plus the `/api/v1/ai_credit_purchases/...` mount point is the sanctioned AI-credit domain-path family (SANCTIONED #5 / WHITELIST W2/W3).

The known user-facing symptom is NOT present: `customer_subscription` (`:420-437`) derives the display from the LIVE Stripe subscription via `organization_ai_credit_purchase.stripe_subscription` (`:430` → model `:260-264` → `Stripe::Subscription.retrieve`), exactly as the analog renders `current_organization.stripe_subscription` (`:614` → `organization.rb:474-477`). The `ap organization_ai_credit_purchase&.stripe_subscription` (`:424`) mirrors the analog's unconditional pre-nil-check `ap current_organization.stripe_subscription` (`:608`) — same double-call structure on the happy path, with safe-nav forced by the purchase row possibly being nil. The `.find_by(subscription_status: [:active, :past_due])` local-column read is used ONLY to LOCATE the purchase row whose `stripe_subscription_id` is then retrieved live (SANCTIONED #4), not to gate the display.

The model's `OrganizationAiCreditPurchase#stripe_subscription` (`:260-264`) is byte-for-byte structurally identical to the analog `Organization#stripe_subscription` (`:474-477`): `return if stripe_subscription_id.nil?` then `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })`.

All data-model divergences found (operate on `OrganizationAiCreditPurchase` row + `purchase.stripe_subscription_id`; no `ValidateSubscriptionChange` / `PlanFeatureGate` / job-limit gate in `change_subscription_portal_session` and `continue_change_subscription_portal_session`; `customer_subscription` scoped to the purchase row with extra `organization_ai_credit_purchase.nil?` nil-guard at `:426`; safe-nav `organization_ai_credit_purchase&.stripe_subscription_id` in the guards; `ai_credit_*` naming; `continue_url` pointing at `/api/v1/ai_credit_purchases/...`; `determine_price_id` else-branch raising instead of resolving a default-plan price; the EXTRA `#show` action) are covered by SANCTIONED-subscription-change.md #1-#5 and AGENT-WHITELIST-subscription-change.md W1-W4 (W3 now covers the `#show` action that was Round 3's sole finding). These are NOT flagged.

---

## Deviations (not covered by SANCTIONED / WHITELIST)

None. Every structural divergence between OUR routes + controller and the analog `BillingController` is accounted for by SANCTIONED #1-#5 or WHITELIST W1-W4. The Round 3 finding (D1, the EXTRA `#show` action) is now whitelisted as W3.

---

deviation_count: 0
