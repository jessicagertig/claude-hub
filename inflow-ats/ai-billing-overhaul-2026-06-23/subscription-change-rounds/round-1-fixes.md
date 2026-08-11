# Round 1 — Subscription-Change Flow (flow 5) — Fix Log

Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`
Target: `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`
Analog: `app/controllers/api/v1/billing_controller.rb`

The four missing actions (`change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `customer_subscription`, `continue_change_subscription_portal_session`) plus `determine_price_id` were ALREADY present in the current controller (lines 228-452). The audit found exactly 1 deviation; addressed below.

---

## D1. `determine_price_id` else-branch dropped — FIXED (partial) + WHITELISTED (forced part)

**Audit finding:** Analog guards on `params.key?(:price_id)` and falls back to a `Stripe::Price.list` lookup matching `DEFAULT_PRICE_LOOKUP_KEY` when `price_id` is absent; OURS returned `params[:price_id]` unconditionally with NO key-presence guard and NO fallback — yielding `nil` for the Stripe `items.price` if `price_id` were ever missing.

- ANALOG: `app/controllers/api/v1/billing_controller.rb:630-640`
- OURS (before): `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:450-452`

**Resolution — two parts:**

1. **FIXED — guard structure restored.** The missing `if params.key?(:price_id)` guard was a fixable structural mismatch. Restored so OURS now mirrors the analog's branch shape:
   ```ruby
   def determine_price_id
     if params.key?(:price_id)
       params[:price_id]
     else
       raise StandardError, 'Price ID is missing.'
     end
   end
   ```
   The raise is caught by the existing `rescue StandardError` blocks in `change_subscription_portal_session` / `update_payment_method_and_subscription_portal_session`, surfacing a clear error instead of a silent `nil` price.

2. **WHITELISTED — default-plan fallback target.** The else-branch's *target* (resolve `DEFAULT_PRICE_LOOKUP_KEY = 'plan_simple_ats_per_job_tiered'`) cannot be matched: that is a main-plan ATS price with NO AI-credit equivalent. The AI-credit domain has multiple credit tiers and no single canonical/default plan, so there is no constant to substitute and resolving the main-plan price would target the wrong product. The frontend (`AiCreditSubscription.tsx` `handleSelectTier`) always posts `priceId: tier.priceId`, making the else-branch unreachable in practice; the raise makes the absence loud rather than silently producing a `nil` Stripe `items.price`.
   Appended as **W1** to `AGENT-WHITELIST-subscription-change.md` (deviation + analog + why-no-match).

Verification: `DEFAULT_PRICE_LOOKUP_KEY` confirmed main-plan (`billing_controller.rb:7`). No AI-credit default-plan constant exists in `app/models/organization_ai_credit_purchase.rb`. Current AI-credit identifiers verified present in model (`AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY`, `ai_credit_subscription_plan_lookup_key?`, `ai_credit_allocation_for_lookup_key`).

---

**Result:** 1 deviation processed → FIXED (guard) + WHITELISTED (fallback target). No CANNOT-MATCH items.
