# Implementation Angle: Test Coverage -- Round 3

## Reviewed for

- Missing test coverage for new code paths
- Test correctness
- Test isolation

## Observations

### New code paths covered
- `apply_one_off_from_invoice`: tested in `apply_ai_credit_purchase_spec.rb` (creates purchase, creates ledger, increments balance, idempotent)
- `checkout.session.completed` subscription linking: tested in `stripe_webhook_handler_ai_credits_spec.rb`
- `invoice.paid` top-up via metadata: tested in `stripe_webhook_handler_ai_credits_spec.rb`
- `notify_failure` and `notify_complete`: tested in `bulk_generate_ai_summaries_job_spec.rb`
- Pre-checkout subscription validation: tested in `organization_ai_credit_purchase_spec.rb`
- Credit pack constants: tested in `organization_ai_credit_purchase_spec.rb`
- Mailer admin_recipients, low_credits, zero_credits: tested in `ai_credit_notification_mailer_spec.rb`
- Retry/discard ordering: tested via `rescue_handlers` index check

### Test correctness
- Mailer stubs use `instance_double(ActionMailer::MessageDelivery)` -- prevents false passes from missing `.deliver_later`
- Invoice-based specs do NOT stub `Stripe::Checkout::Session.list_line_items` (fixes Round 1 defect)
- Subscription spec creates existing purchase first, then calls interactor -- matches production flow

### Coverage gap (informational)
- `notify_failure` is tested through `on_complete` but not directly through `discard_on`/`retry_on` exhaustion paths. The class-level blocks are hard to test in isolation with ActiveJob. The `on_complete` test verifies the method works; the declaration-level test verifies ordering. Together they provide reasonable coverage.

## Findings

**No findings.**
