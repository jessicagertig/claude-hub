# Subscription Renewal — Owner-Sanctioned Deviations (flow 2)

Analog: main-plan subscription renewal (the `else` branch of `invoice.paid` in `stripe_webhook_handler_job.rb`). OURS: `handle_subscription_credit_pack_invoice_paid` + `ApplyAiCreditPurchase#apply_subscription`.

Owner-approved deviations carried over from the main `SANCTIONED-DEVIATIONS.md`. **Only Jessica adds here.** Agent-discovered forced deviations go in `AGENT-WHITELIST-subscription-renewal.md` (which the audit also reads).

1. **Operates on `organization_ai_credit_purchases` columns, not `organizations` columns** — the AI-credit subscription is tracked on the purchase row (its own `stripe_subscription_id`, period, status), not on `organizations` columns like the main plan. Forced by the data model. (Carried from the main list's "AI Credit Subscription Renewal" section.)

2. **Balance notification-suppression flag reset** — `apply_subscription` clears `sent_low_notification_since_increase` / `sent_zero_notification_since_increase` on the credit balance after granting (`apply_ai_credit_purchase.rb:62-65`). Same as one-off sanctioned #9; forced by the `OrganizationAiCreditBalance` companion record (the main-plan analog resets the same flags inside `ResetAiCredits`, so this is structurally parallel).
