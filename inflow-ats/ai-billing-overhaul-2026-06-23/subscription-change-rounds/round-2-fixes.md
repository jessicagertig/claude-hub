# Round 2 Fixes — AI-credit subscription-change flow (flow 5)

Audit input: `round-2-audit.md` → DEVIATION COUNT: 0.

Independently re-verified the four re-implemented actions plus `determine_price_id` on
`app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` against the analog
`app/controllers/api/v1/billing_controller.rb` and against the current frontend hook. No
fixable deviations found; nothing newly whitelisted.

## Verification trace

`organization_ai_credit_purchases_controller.rb` → `billing_controller.rb` →
`organization_ai_credit_purchase.rb` → `useOrganizationAiCreditPurchase.ts` →
`AiCreditSubscription.tsx` (filenames) → `config/routes.rb`.

## Per-action result

- **change_subscription_portal_session** (:233) — FIXED-N/A (already correct). Mirrors analog
  `:268`. Sanctioned deviations present and correct: purchase-row scoping via
  `organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])`
  (#1/#2/#4), `flow_data...subscription` uses `organization_ai_credit_purchase.stripe_subscription_id`
  (#1), and the `ValidateSubscriptionChange` / job-limit gate is correctly absent (#3). The
  `subscription_item_id` reconstruction via `Stripe::Subscription.retrieve(...).items.data.first.id`
  is the sanctioned forced fallback (#1/#4) and is reached only when `params[:subscription_item_id]`
  is blank. `determine_price_id`, `PosthogTrackJob`, render shape, and the three-clause rescue
  chain all match the analog.

- **update_payment_method_and_subscription_portal_session** (:290) — FIXED-N/A (already correct).
  Mirrors analog `:331`. Same sanctioned scoping/fallback as above. `continue_url` points at
  `/api/v1/ai_credit_purchases/continue_change_subscription_portal_session` (correct AI-credit
  route), `flow_data` `payment_method_update` + `after_completion` redirect, `return_url`, and the
  rescue chain all match.

- **continue_change_subscription_portal_session** (:351) — FIXED-N/A (already correct). Mirrors
  analog `:385`. Non-raising log-and-redirect guards for missing customer/subscription, the
  `subscription_update_confirm` portal session, and the error redirects all match the analog,
  adapted to the purchase-row subscription id (#1).

- **customer_subscription** (:426) — FIXED-N/A (already correct). Mirrors analog `:606`, scoped to
  the active/past_due subscription-kind purchase row (#4). Returns `{ subscription: nil }` when no
  row or no `stripe_subscription_id`, otherwise `{ subscription: organization_ai_credit_purchase.stripe_subscription }`
  with the analog's `Unable to load subscription` rescue.

- **determine_price_id** (:453, private) — FIXED-N/A (already correct). Keeps the analog's
  `params.key?(:price_id)` guard; else-branch raises instead of resolving the main-plan
  `DEFAULT_PRICE_LOOKUP_KEY`. Already covered by `AGENT-WHITELIST-subscription-change.md` W1.

## Supporting facts confirmed

- Model identifiers exist and current: `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` (:4),
  `ai_credit_subscription_plan_lookup_key?` (:63), `ai_credit_allocation_for_lookup_key` (:71),
  `enum kind: { one_off: 0, subscription: 1 }` (:82) → auto-generates the `.subscription` scope,
  `enum subscription_status` with `active`/`past_due` (:83), and `stripe_subscription` (:260) which
  calls `Stripe::Subscription.retrieve` (matching the analog's pattern).

- Routes register all four actions on the `ai_credit_purchases` collection
  (`config/routes.rb` :169-178 and a second mount :195-200).

- Frontend payload: `useOrganizationAiCreditPurchase.ts` sends
  `{ priceId, subscriptionItemId, returnUrl }` to both `change_subscription_portal_session` and
  `update_payment_method_and_subscription_portal_session`. Rails snake-cases these to
  `params[:price_id]`, `params[:subscription_item_id]`, `params[:return_url]`, which the controller
  reads correctly. NOTE: the round-2 task prompt's claim that the frontend sends only
  `{ stripePriceLookupKey, returnUrl }` is stale — the current hook sends `priceId` and
  `subscriptionItemId` directly, so the `subscription_item_id` is normally supplied by the client
  and the Stripe reconstruction is a fallback, not the primary path. No action needed.

## Net result

FIXED: 0 (none required) · WHITELISTED (new): 0 · CANNOT-MATCH: 0 · Convergence: clean.
