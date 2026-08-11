# Round 3 — Routes + Controller (routes-controller agent)

Segment: `config/routes.rb` ai_credit_purchases collection + `OrganizationAiCreditPurchasesController` actions in the subscription-change flow (`show`, `customer_subscription`, `change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `continue_change_subscription_portal_session`), compared identifier-by-identifier to the analog `BillingController` per `traces/subscription-change-analog-trace.md`.

Files traced:
`config/routes.rb:190-202` (OURS) vs `:163-186` (analog `resources :billing`)
`app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (OURS) vs `app/controllers/api/v1/billing_controller.rb:268-470, 606-621, 630-640` (analog)
Frontend consumers checked: `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:30-73, 273` and `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts:5-13, 165` (to determine which controller action feeds the active-subscription SCREEN gate).

---

## Result of the structural comparison

For all five in-scope actions, OURS matches the analog structurally — same guards, same guard ordering, same param reads (`params[:subscription_item_id]`, `params[:return_url]`, `params[:target_price_id]`, `params[:price_id]`), same `options`/`flow_data` shapes (`subscription_update_confirm` and `payment_method_update`), same `continue_url` construction with `CGI.escape`, same `PosthogTrackJob.perform_later(... price_id: determine_price_id)` call, same `render json: { redirectUrl: session.url }` / `redirect_to session.url` / `render json: { subscription: ... }` terminals, and identical rescue ladders (including the asymmetries the trace calls out: change-action `StandardError` rescue has NO Sentry while update-action does; continue-action uses `redirect_to ...?error=` for every guard rather than `raise`; `customer_subscription` has no `authorize`).

The known user-facing symptom is NOT present in OUR controller: `customer_subscription` (`:420-437`) derives the display from the LIVE Stripe subscription via `organization_ai_credit_purchase.stripe_subscription` (`:430`), exactly as the analog renders `current_organization.stripe_subscription` (`:614`); and the frontend `AiCreditSubscription.tsx:53-60` derives `currentSubscription` / `isSubscribed` from that live `customer_subscription` payload (`status === "active" || "past_due"`), not from a local `subscription_status` column. The local `subscription_status` scoping that DOES appear (`.find_by(subscription_status: [:active, :past_due])`) is the sanctioned purchase-row scoping (SANCTIONED #4), used only to LOCATE the purchase row whose `stripe_subscription_id` is then retrieved live from Stripe.

All data-model divergences found (operate on `OrganizationAiCreditPurchase` row + `purchase.stripe_subscription_id`; no `ValidateSubscriptionChange`/job-limit gate; `customer_subscription` scoped to the purchase row; safe-nav `organization_ai_credit_purchase&.stripe_subscription` / extra `organization_ai_credit_purchase.nil?` nil-guard at `:424`/`:426` forced because a purchase row may not exist; `ai_credit_*` naming; `continue_url` pointing at `/api/v1/ai_credit_purchases/...`; `determine_price_id` else-branch raising) are covered by SANCTIONED-subscription-change.md #1-#5 and AGENT-WHITELIST-subscription-change.md W1-W2. These are NOT flagged.

---

## Deviations (not covered by SANCTIONED / WHITELIST)

### D1. OURS has an EXTRA `show` action with no analog counterpart

- **ANALOG (trace):** `BillingController` has NO `show` action. The current-subscription display is served exclusively by `customer_subscription` (`billing_controller.rb:606`, item 6), which renders the LIVE Stripe object. There is no route/action that renders a persisted subscription record for the change flow.
- **OURS:** `OrganizationAiCreditPurchasesController#show` (`organization_ai_credit_purchases_controller.rb:4-13`) authorizes `:organization_ai_credit_purchase, :show?`, runs `current_organization.organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])` and renders the serialized DB record via `Api::V1::OrganizationAiCreditPurchaseSerializer` (`:9`) or `render json: nil` (`:11`). Mounted at `resource :ai_credit_purchases, only: [:show]` → `GET /api/v1/ai_credit_purchases` (`config/routes.rb:190`) and consumed by `useOrganizationAiCreditPurchase` (`useOrganizationAiCreditPurchase.ts:5-13`).
- **Assessment:** EXTRA action relative to the analog. It is NOT on the symptom path — `AiCreditSubscription.tsx` gates the active-subscription display on the live-Stripe `customer_subscription` payload (`:53-60`), not on this `show` record — so it does not reintroduce the local-column-gating defect. But it is a structural EXTRA the analog does not have, and it renders the persisted record gated on the local `subscription_status` column. Surfacing for owner decision: confirm `show` is an intentional addition for the AI-credit domain (not analog-mirrored) and that nothing in the subscription-change SCREEN gate depends on it. If it is purely an artifact and unused by the change flow, it is dead relative to the analog.
- **file:line:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:4-13`; route `config/routes.rb:190`

---

deviation_count: 1
