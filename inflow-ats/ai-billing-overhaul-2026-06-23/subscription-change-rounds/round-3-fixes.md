# Round 3 — Subscription-Change Flow (Flow 5) Fix Log

Audit input: `round-3-audit.md` (DEVIATION COUNT: 2).
Target: `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (worktree `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`).
Analog: `app/controllers/api/v1/billing_controller.rb`.

All four Flow-5 actions (`change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `continue_change_subscription_portal_session`, `customer_subscription`) plus `determine_price_id` were already present and well-formed on the branch. No re-implementation needed; only the two audit deviations addressed.

---

## Deviation 1 — `customer_subscription` missing the analog's second debug `ap` line — FIXED

- **Audit:** OURS `customer_subscription` had only the leading `ap 'GETTING THE AI CREDIT CUSTOMER SUBSCRIPTION'` and no equivalent of the analog's `ap current_organization.stripe_subscription` (a live `Stripe::Subscription.retrieve` used only for debug printing). Analog `billing_controller.rb:608`; OURS `organization_ai_credit_purchases_controller.rb:427-429`.
- **Fix:** Added `ap organization_ai_credit_purchase&.stripe_subscription` immediately after the `organization_ai_credit_purchase = ...find_by(...)` line, before the nil-guard — the AI-credit-row analog of the main-plan `ap current_organization.stripe_subscription`. Used the safe-navigation `&.` because OURS' subscription lives on the (possibly-nil) purchase row rather than on `current_organization`; `stripe_subscription` is a model method on `OrganizationAiCreditPurchase` (model line 260) that returns nil when `stripe_subscription_id` is nil, so the debug line is side-effect-equivalent to the analog (live retrieve when present, nil otherwise). This is sanctioned-deviation-#4-shaped (purchase row instead of org column) but the change here is purely the debug-line parity the audit asked for.

## Deviation 2 — `continue_url` base path `/api/v1/ai_credit_purchases/...` vs analog `/api/v1/billing/...` — WHITELISTED

- **Audit:** `continue_url` in `update_payment_method_and_subscription_portal_session` targets `#{Variables::AtsRootUrl}/api/v1/ai_credit_purchases/continue_change_subscription_portal_session` rather than the analog's `/api/v1/billing/...`. Analog `billing_controller.rb:346`; OURS `organization_ai_credit_purchases_controller.rb:310`.
- **Resolution:** WHITELISTED (no code change). Forced by the AI-credit domain route — the continue endpoint is OUR own `continue_change_subscription_portal_session` action mounted under `resource :ai_credit_purchases` in `config/routes.rb`, so it lives at `/api/v1/ai_credit_purchases/...`. Pointing the continue redirect at the analog's `/api/v1/billing/...` literal would bounce the Stripe payment-method-update flow into the MAIN-PLAN billing controller (operating on `current_organization.stripe_subscription_id`, the wrong subscription) and break the AI-credit handshake. Same forced cause as the domain-path/naming family in `SANCTIONED-subscription-change.md` #5; appended as `W2` to `AGENT-WHITELIST-subscription-change.md` because it is a specific path literal not explicitly enumerated there. High bar met: there is no way to match the analog literal without redirecting to the wrong controller.

---

## Summary

- FIXED: 1 (Deviation 1 — debug-line parity).
- WHITELISTED: 1 (Deviation 2 — domain continue_url path; appended as W2).
- CANNOT-MATCH: 0.

No other deviations introduced. Scope limited strictly to the four Flow-5 subscription-change actions and the two audit findings; the `checkout` action's pre-existing `subscription_key?` / `credit_amount_for_key` usages are outside this round's flow and were not touched.
