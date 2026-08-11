# Round 1 — routes-controller — adversarial findings

Segment: `config/routes.rb` ai_credit_purchases collection + `OrganizationAiCreditPurchasesController` actions (show, customer_subscription, change_subscription_portal_session, update_payment_method_and_subscription_portal_session, continue_change_subscription_portal_session).

Files traced:
- `config/routes.rb:188-202` (ai_credit_purchases) vs `:163-186` (billing)
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` vs `app/controllers/api/v1/billing_controller.rb` (analog trace)
- `app/models/organization_ai_credit_purchase.rb:260-263` (`#stripe_subscription`) vs analog `app/models/organization.rb:474-477`
- `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts:36-46,65-75,165` (param/route consumers)
- `app/policies/billing_policy.rb` (`change_subscription?` `:24`)

Sanctioned/whitelist deviations read fresh and EXCLUDED: SANCTIONED #1–#5 (purchase-row scoping, `stripe_subscription_id` on the purchase, no ValidateSubscriptionChange/job-limit gate, live-sub by `purchase.stripe_subscription_id`, `ai_credit_*` naming) and AGENT-WHITELIST W1 (`determine_price_id` else-branch raises) and W2 (`continue_url` base path `/api/v1/ai_credit_purchases/...`). Findings below are deviations NOT covered by those.

---

## F1 — `change_subscription_portal_session`: subscription_item_id guard reordered + extra Stripe retrieve fallback (NOT sanctioned)

- ANALOG (trace items 22, 26): all THREE entry guards are at the TOP, before any assignment — `billing_controller.rb:272-274`: `raise ... unless stripe_customer_id`, `raise ... unless stripe_subscription_id`, **`raise StandardError, 'Subscription item ID is missing.' unless params[:subscription_item_id].present?` (`:274`)**. Then `subscription_item_id = params[:subscription_item_id]` (`:288`) — a PLAIN param read. The analog NEVER calls Stripe to reconstruct the item id; an absent param raises immediately at the top.
- OURS (`organization_ai_credit_purchases_controller.rb:239-247`): only TWO top guards (customer `:239`, subscription `:240`). The subscription-item-id guard is MOVED DOWN below an added fallback: `subscription_item_id = params[:subscription_item_id].presence || Stripe::Subscription.retrieve(organization_ai_credit_purchase.stripe_subscription_id).items.data.first.id` (`:244-246`), THEN `raise ... unless subscription_item_id.present?` (`:247`). This adds a third live Stripe read (`Stripe::Subscription.retrieve`, a STRIPE terminal the analog does not have on this path), changes the guard from a param-presence check to a post-resolution check, and reorders the guard sequence. The frontend hook DOES send `subscriptionItemId` (`useOrganizationAiCreditPurchase.ts:46`), so the analog's plain-param contract is satisfiable; the fallback is an unrequested structural addition. Not covered by SANCTIONED #1/#4 (those scope WHICH subscription is read, not the addition of a per-request item-id Stripe round-trip and guard reordering).
- file:line: `organization_ai_credit_purchases_controller.rb:244-247`

## F2 — `update_payment_method_and_subscription_portal_session`: same item-id guard reordered + extra Stripe retrieve fallback (NOT sanctioned)

- ANALOG (trace item 18b, `billing_controller.rb:335-339`): THREE top guards including `raise StandardError, 'Subscription item ID is missing.' unless params[:subscription_item_id].present?` (`:337`), then `subscription_item_id = params[:subscription_item_id]` (`:339`) — plain param read, no Stripe call.
- OURS (`organization_ai_credit_purchases_controller.rb:296-302`): two top guards, then `subscription_item_id = params[:subscription_item_id].presence || Stripe::Subscription.retrieve(organization_ai_credit_purchase.stripe_subscription_id).items.data.first.id` (`:299-301`), then `raise ... unless subscription_item_id.present?` (`:302`). Same deviation as F1 in the payment-method fork: added Stripe retrieve fallback + guard reordering. Not sanctioned.
- file:line: `organization_ai_credit_purchases_controller.rb:299-302`

## F3 — `update_payment_method_and_subscription_portal_session`: StandardError rescue renders a generic message instead of the analog's literal — and the analog's distinct error-shape note

- ANALOG (trace item 18b, `billing_controller.rb:376-379`): the `rescue StandardError => e` calls `Sentry.capture_exception(e)` + `Rails.logger.error e` + `render_general_errors(['Unable to start payment method update flow'])`.
- OURS (`organization_ai_credit_purchases_controller.rb:340-343`): `rescue StandardError => e` → `Sentry.capture_exception(e)` + `Rails.logger.error e` + `render_general_errors(['Unable to start payment method update flow'])`. MATCH — no deviation. (Recorded as verified, not a finding.)

## F4 — `customer_subscription`: nil-branch debug line uses safe-navigation (forced) — but verify it is the ONLY divergence

- ANALOG (trace item 6, `billing_controller.rb:607-608`): first stmt `ap 'GETTING THE CUSTOMER SUBSCRIPTION'`; second stmt `ap current_organization.stripe_subscription` — UNCONDITIONAL invocation of `stripe_subscription` (hits Stripe when `stripe_subscription_id` present) BEFORE the nil-check; happy path therefore calls `stripe_subscription` TWICE (`:608` then `:614`).
- OURS (`organization_ai_credit_purchases_controller.rb:427-436`): first stmt `ap 'GETTING THE AI CREDIT CUSTOMER SUBSCRIPTION'`; finds `organization_ai_credit_purchase` (`:429`); second debug stmt `ap organization_ai_credit_purchase&.stripe_subscription` (`:430`) — safe-nav `&.` so when the purchase row is nil it does NOT hit Stripe. The nil-branch test is `organization_ai_credit_purchase.nil? || organization_ai_credit_purchase.stripe_subscription_id.nil?` (`:432`). The purchase-row scoping and the `purchase.nil? ||` addition are SANCTIONED #4 (the analog's `current_organization` is never nil, ours' purchase row can be). The `&.` on the debug line is forced by the same nilable-row cause. The happy path still calls `stripe_subscription` twice (`:430` then `:436`), matching the analog's double-call structure. No NEW deviation beyond the sanctioned scoping.
- file:line: `organization_ai_credit_purchases_controller.rb:430` (verified-forced, not a fix target)

## F5 — `show` action has NO analog counterpart in BillingController (extra action) — but is it a structural EXTRA?

- ANALOG: `BillingController` has NO `show` action. The trace's subscription-display derivation is entirely via `customer_subscription` (live Stripe). There is no `GET /billing` resource member.
- OURS: `routes.rb:190` mounts `resource :ai_credit_purchases, only: [:show]`, and `OrganizationAiCreditPurchasesController#show` (`:4-13`) is the `GET /ai_credit_purchases` endpoint the frontend hook fetches at `useOrganizationAiCreditPurchase.ts:6` (`apiGet({ path: "/ai_credit_purchases" })`). `#show` authorizes `:organization_ai_credit_purchase, :show?`, finds the active/past_due subscription purchase row, and renders it through `Api::V1::OrganizationAiCreditPurchaseSerializer` (or `render json: nil`). This is an EXTRA action with no analog — it returns the persisted purchase ROW (DB), distinct from `customer_subscription` which returns the live Stripe subscription. The known symptom (active subscription not displaying when gated on a local `subscription_status` column) lives HERE: `#show` is the row-backed endpoint, and any frontend display that gates on `#show`'s `subscription_status` rather than the live `customer_subscription` Stripe object is the analog divergence. This action / its existence and the frontend's choice of which endpoint drives the display is the structural EXTRA the analog does not have. Flagging for the orchestrator: confirm whether `#show` is in-scope for this flow or belongs to a sibling flow (subscribe/cancel). If the credit-subscription tier DISPLAY is meant to follow the analog, it must derive from `customer_subscription` (live Stripe), not from `#show`'s row `subscription_status`.
- file:line: `routes.rb:190`, `organization_ai_credit_purchases_controller.rb:4-13`

## F6 — Route resource is singular `resource` (no member structure) vs analog plural `resources :billing` — path-shape note

- ANALOG: `resources :billing, only: [...]` (`routes.rb:163`) — plural, with the five flow endpoints declared in a `collection do ... end` block (`:164-185`): `post :change_subscription_portal_session` (`:169`), `post :update_payment_method_and_subscription_portal_session` (`:170`), `get :customer_subscription` (`:177`), `get :continue_change_subscription_portal_session` (`:178`).
- OURS: `resource :ai_credit_purchases, only: [:show], controller: 'organization_ai_credit_purchases'` (`routes.rb:190`) — SINGULAR `resource`, with the same five endpoints in a `collection do ... end` block (`:191-201`): `post :change_subscription_portal_session` (`:195`), `post :update_payment_method_and_subscription_portal_session` (`:196`), `get :customer_subscription` (`:199`), `get :continue_change_subscription_portal_session` (`:200`). The singular `resource` yields the `/api/v1/ai_credit_purchases` (no `:id`) path the `#show` hook uses (`useOrganizationAiCreditPurchase.ts:6`); the collection members all resolve to `/api/v1/ai_credit_purchases/<action>`, the path family W2 sanctions. The singular-vs-plural choice and the `only: [:show]` member differ from the analog's plural/no-`:id`-show shape, but the four flow endpoints' route VERBS and names match the analog exactly. The singular form is forced by the single-per-org purchase resource (one active subscription row per org); flagged as forced, not a fix target.
- file:line: `routes.rb:190-202`

---

## Summary

Real (non-sanctioned) deviations requiring a fix: **F1, F2** — both actions add a `Stripe::Subscription.retrieve(...).items.data.first.id` fallback for `subscription_item_id` and reorder the item-id guard below it, whereas the analog requires `params[:subscription_item_id]` via a top-level raise guard and reads it plainly (no Stripe round-trip). To match the analog: restore the top-level `raise StandardError, 'Subscription item ID is missing.' unless params[:subscription_item_id].present?` guard alongside the customer/subscription guards, and set `subscription_item_id = params[:subscription_item_id]` (plain read, no fallback Stripe retrieve).

Verified-forced / flagged-for-orchestrator (not fix targets): F4 (safe-nav debug line — forced by nilable purchase row, SANCTIONED #4), F5 (extra `#show` action with no analog — the likely home of the display symptom; needs scope confirmation), F6 (singular `resource` — forced by one-subscription-per-org).
