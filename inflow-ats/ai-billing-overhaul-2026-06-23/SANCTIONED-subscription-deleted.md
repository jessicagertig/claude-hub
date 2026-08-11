# Subscription.deleted — Owner-Sanctioned Deviations (flow 4)

Analog: main-plan `customer.subscription.deleted` handler (`stripe_webhook_handler_job.rb:167-187` + `sync_with_stripe` + `Notification::PaidSubscriptionDeletedJob` + `EngagementReport::GeneratorJob`). OURS: a credit-pack branch that does **not** yet exist and must be ADDED, mirroring the `subscription.updated` credit-pack branch.

Owner-approved deviations carried from the main `SANCTIONED-DEVIATIONS.md`. **Only Jessica adds here.** Agent-discovered forced deviations go in `AGENT-WHITELIST-subscription-deleted.md` (which the audit also reads).

1. **Operates on `organization_ai_credit_purchases` columns, not `organizations` columns** — the credit-pack branch sets `purchase.subscription_status` and `purchase.subscription_canceled_at`, not org columns. Forced by the data model. (Carried from the main list's "AI Credit Subscription Change" #2; `ai_credit_*` naming from #5.)
