# Test Coverage — Round 6

## Review

### New specs

**`spec/mailers/ai_credit_notification_mailer_spec.rb`:**
- Tests `admin_recipients` filtering (owner+admin included, member+interviewer excluded). PASS.
- Tests `low_credits` template, variables (including `credits_remaining`). PASS.
- Tests `zero_credits` template. PASS.
- Tests `send` called per admin recipient. PASS.
- Stubs `Emails::SendTemplateEmail` correctly. PASS.

**`spec/jobs/bulk_generate_ai_summaries_job_spec.rb`:**
- Tests `retry_on`/`discard_on` ordering via `rescue_handlers` inspection. PASS.
- Tests `each_iteration` pipeline execution. PASS.
- Tests `each_iteration` short-circuit for already-processed summaries. PASS.
- Tests `on_complete` broadcasts `AI_SUMMARY_BULK_COMPLETE` with counts. PASS.
- Tests `on_complete` sends `complete` mailer via `.deliver_later`. PASS.
- Tests `on_complete` with all-failed -> `AI_SUMMARY_BULK_FAILED` + `failed` mailer. PASS.
- Uses `instance_double(ActionMailer::MessageDelivery)` with `.deliver_later` verification per failure pattern #4. PASS.

### Updated specs

**`spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`:**
- Tests `checkout.session.completed` AI subscription linking. PASS.
- Tests `invoice.paid` top-up via checkout session lookup. PASS.
- Tests `invoice.paid` subscription renewal. PASS.
- Tests idempotency for duplicate invoice.paid events. PASS.
- No test for removed `mode == 'payment'` branch. PASS.

**`spec/interactors/apply_ai_credit_purchase_spec.rb`:**
- Four real pack keys. PASS.
- Tests existing purchase found -> grants credits. PASS.
- Tests missing purchase -> fails with `:missing_purchase`. PASS.
- No subscription creation tests (removed branch). PASS.

### Renamed specs

- `create_ai_credit_balance_transaction_spec.rb`: class reference updated. PASS.
- `organization_ai_credit_balance_policy_spec.rb`: class reference updated. PASS.
- `credit_consumption_with_notifications_spec.rb`: 3 call sites + comment updated from `ConsumeAiCredits` to `CreateAiCreditBalanceTransaction`. PASS.

### Deleted specs

- `spec/initializers/ai_credit_packs_spec.rb`: deleted. Coverage migrated to `spec/models/organization_ai_credit_purchase_spec.rb`. PASS.

## Findings

No findings.

## Verdict: PASS (0 HIGH, 0 MED)
