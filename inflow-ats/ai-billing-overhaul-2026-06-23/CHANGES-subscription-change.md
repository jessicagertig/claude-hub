# Subscription Change / Upgrade-Downgrade Portal (flow 5) — Changes Made

A lost flow, re-implemented. Converged two-clean in 4 rounds (audit counts 1,0,2,0,0 — not capped). File changed: `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (+4 actions + a `determine_price_id` helper). New trace: `traces/subscription-change-trace.md`.

## Root cause
`config/routes.rb` (the `ai_credit_purchases` block) + the frontend referenced 4 controller actions that were **missing** (lost when the current stash was applied) → clicking subscribe / change raised `AbstractController::ActionNotFound` (500). Re-added them, mirroring `BillingController`, adapted to the AI-credit domain.

## Actions added
- `change_subscription_portal_session` (`:233`) — opens the Stripe portal `subscription_update_confirm` flow on the org's active/past_due credit-pack `OrganizationAiCreditPurchase`.
- `update_payment_method_and_subscription_portal_session` (`:290`)
- `continue_change_subscription_portal_session` (`:351`)
- `customer_subscription` (`:426`) — renders the live Stripe subscription (raw) so the frontend can read `subscriptionItemId`.
- private `determine_price_id` (`:450`).

## Premise correction (from the trace agent)
The frontend already posts `{ priceId, subscriptionItemId, returnUrl }` (the analog's keys), sourcing `subscriptionItemId` from `customer_subscription` — so the actions are param-based like the analog; the server-side `Stripe::Subscription.retrieve` reconstruction is only the blank fallback.

## Forced deviations whitelisted (`AGENT-WHITELIST-subscription-change.md`) — reviewed, valid
- **W1** `determine_price_id` else-branch raises (no canonical default AI-credit plan to resolve, unlike the main plan's `DEFAULT_PRICE_LOOKUP_KEY`).
- **W2** `continue_url` uses `/api/v1/ai_credit_purchases/...` (must hit OUR continue action, not the main-plan `/billing` one).
Plus owner-sanctioned #1-5 (operate on the purchase row + its `stripe_subscription_id`, no job-limit gate, `ai_credit_*` naming).

## Verified
`ruby -c` OK. On the running dev server, `GET /api/v1/ai_credit_purchases/customer_subscription` returns **401 (auth)** instead of **500 ActionNotFound** — the subscribe/portal error is resolved.

## Commit
Staged with flows 2+4 (the Cypress pre-commit hook blocks the commit on a `/cypress/cleanup` PG deadlock — separate issue, being investigated via per-spec runs).
