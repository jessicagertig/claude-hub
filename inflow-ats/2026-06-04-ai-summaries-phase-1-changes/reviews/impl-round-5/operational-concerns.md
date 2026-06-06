# operational-concerns — Round 5

## Findings

- F1 [MED] `app/jobs/stripe_webhook_handler_job.rb:276-284` / `StandardError` rescue re-raises, changing webhook retry behavior / The original `invoice.paid` handler swallowed all errors (`rescue StandardError => e` with log + return). The fix agent changed the final rescue to re-raise: "re-raise so Sidekiq retries the webhook." This changes behavior: previously, any error in invoice processing was logged and silently dropped. Now, unexpected errors cause Sidekiq retries. The comment argues this is safe because `ApplyAiCreditPurchase` is idempotent, but the `handle_credit_pack_invoice_paid` method does an `already_processed` check that may not account for all retry scenarios (e.g., if the ledger row was created but the purchase update failed, the retry would skip because `already_processed` would be true).

No other operational concerns. Logging is adequate throughout the new code. Error handling in controllers includes Sentry capture. The Flipper guard on daily credits is correctly placed.
