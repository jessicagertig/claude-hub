# Subscription.updated — Owner-Sanctioned Deviations (flow 3)

Analog: main-plan `customer.subscription.updated` handler (`stripe_webhook_handler_job.rb:149-160` + `Organization#sync_with_stripe` / `#stripe_update_default_payment_method`). OURS: the credit-pack branch (`stripe_webhook_handler_job.rb:125-148`).

Owner-approved deviations carried from the main `SANCTIONED-DEVIATIONS.md`. **Only Jessica adds here.** Agent-discovered forced deviations go in `AGENT-WHITELIST-subscription-updated.md` (which the audit also reads).

1. **Operates on `organization_ai_credit_purchases` columns, not `organizations` columns** — the credit-pack subscription is tracked on the purchase row; `subscription.updated` updates the purchase's status / period / lookup_key, not org columns. Forced by the data model. (Carried from the main list's "AI Credit Subscription Change" #2; `ai_credit_*` descriptor naming carried from #5.)
