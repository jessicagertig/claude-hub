# test-coverage — Round 5

## Findings

- F1 [MED] `spec/interactors/apply_ai_credit_purchase_spec.rb` / No test for `apply_one_off_from_invoice` failure paths / The spec tests `one_off via invoice (top-up)` for happy path and idempotency, but does not test the failure paths: missing org, missing balance, missing lookup_key, unknown lookup_key. The session-based `apply_one_off` path also lacks failure path tests (only `missing_balance` is tested, in a separate describe block at line 147).

- F2 [MED] `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` / No test for `charge.refunded` handler / The `handle_charge_refunded` method has 31 lines of Stripe API interaction with no test coverage. However, since `charge.refunded` is out of spec (angle-1 F3), this is expected.

- F3 [MED] `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` / No test for `customer.subscription.updated` AI credit branch / Same -- out of spec, no test.

- F4 [MED] `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` / No test for `customer.subscription.deleted` + credit pack combination beyond happy path / The test creates a subscription, sends the event, and checks status/canceled_at. But it doesn't test: missing purchase, failed update, or non-credit-pack subscription (which should fall through to the existing handler).

All spec-required tests are present and correctly structured:
- Mailer spec: admin_recipients, low_credits template/variables, zero_credits template, send count
- Bulk job spec: TDD ordering test, on_complete broadcast + mailer with .deliver_later, failure path with .deliver_later
- Webhook spec: checkout.session.completed linking, invoice.paid top-up, invoice.paid subscription renewal, idempotency for both
- Apply purchase spec: one_off, one_off via invoice, subscription, missing_purchase
- Mailer stubs correctly use `instance_double(ActionMailer::MessageDelivery)` per failure pattern #4
