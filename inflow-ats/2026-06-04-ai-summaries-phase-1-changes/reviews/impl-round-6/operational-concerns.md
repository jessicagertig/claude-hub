# Operational Concerns — Round 6

## Review

### Error handling and observability

- Controllers: method-level `rescue Stripe::StripeError` with `Sentry.capture_exception` and structured log messages. Good.
- Webhook handler: structured error logging with org_id, invoice_id, subscription_id context. Good.
- Interactors: `fail_with_record_invalid` pattern with `Rails.logger.error`. Good.

### Rescue block behavior change

**File:** `app/jobs/stripe_webhook_handler_job.rb:241-255`

The `invoice.paid` handler's rescue block was restructured from a single `rescue StandardError => e` (which swallowed all errors) to three tiers. The final `StandardError` catch now re-raises, causing Sidekiq to retry the webhook. This is a behavior change:

- Before: all errors silently swallowed. Invoice processing failures went unnoticed.
- After: `Stripe::StripeError` and `ActiveRecord::RecordInvalid/RecordNotFound` swallowed (these are expected errors). Other `StandardError` exceptions re-raised for Sidekiq retry.

The re-raise is safe because `ApplyAiCreditPurchase` is idempotent (duplicate webhook deliveries find existing records). However, the behavior change is beyond what the spec explicitly requested.

### Migration safety

No new migrations. All migration edits are in-place (dev-only). Verified: migration `20260605035312` (the out-of-spec migration from Round 5) is deleted.

### Feature flipper gating

Plato AI tab behind `aiApplicantSummaryEnabled` flipper. Daily credits behind `AI_DAILY_CREDITS` flipper. Both are reasonable operational controls.

## Findings

### MED F1 -- Rescue re-raise changes retry behavior

**File:** `app/jobs/stripe_webhook_handler_job.rb:247-255`

Same as angle-1 F3. The `StandardError` catch now re-raises, changing from silent failure to Sidekiq retry. While this is better behavior (silent swallowing masks bugs), it's a change beyond spec scope and could cause unexpected Sidekiq queue buildup if there's a persistent error.

## Verdict: PASS (0 HIGH, 1 MED)
