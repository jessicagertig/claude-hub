# Subscription Change / Upgrade-Downgrade Portal — Owner-Sanctioned Deviations (flow 5)

Analog: main-plan Stripe Billing Portal subscription-change flow — `BillingController#change_subscription_portal_session` (`:268`), `#update_payment_method_and_subscription_portal_session` (`:331`), `#continue_change_subscription_portal_session` (`:385`), `#customer_subscription` (`:606`). OURS: the credit-pack equivalents on `OrganizationAiCreditPurchasesController` (currently MISSING — routes + frontend reference them; the actions were lost when the current stash was applied and must be re-implemented).

Reference mapping: `_in-progress/ai-credit-subscription-change-analog-trace.md` (gold-standard, but predates the `CREDIT_PACKS_BY_LOOKUP_KEY → AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` / `subscription_key? → ai_credit_subscription_plan_lookup_key?` / `credit_amount_for_key → ai_credit_allocation_for_lookup_key` renames — use CURRENT names) and `_in-progress/ai-credit-subscription-change-mirror-spec.md`.

Owner-approved deviations (carried from the main `SANCTIONED-DEVIATIONS.md` "AI Credit Subscription Change" section). **Only Jessica adds here.** Agent-discovered forced deviations go in `AGENT-WHITELIST-subscription-change.md`.

1. **`flow_data.subscription` uses `purchase.stripe_subscription_id`** (not `organization.stripe_subscription_id`) — forced by the separate Stripe subscription tracked on the purchase row.
2. **Operates on the `OrganizationAiCreditPurchase` record**, not org columns — forced by the data model.
3. **No `ValidateSubscriptionChange` / `PlanFeatureGate` / job-limit gate** — AI credit plans have no job-limit constraints (the analog gates downgrades on published-job count; credit packs have no such limit).
4. **Live-subscription endpoint retrieves by `purchase.stripe_subscription_id`** (scoped to the org's active/past_due subscription-kind purchase), not `current_organization.stripe_subscription` — same forced cause as #1.
5. **`ai_credit_*` descriptor naming** with `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` / `ai_credit_subscription_plan_lookup_key?` / `ai_credit_allocation_for_lookup_key` — naming convention for the AI credit domain.
