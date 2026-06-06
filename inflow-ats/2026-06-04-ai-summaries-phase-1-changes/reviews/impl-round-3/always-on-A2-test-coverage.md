# Always-On A2: Test Coverage -- Round 3

## Verified

### Mailer spec (`spec/mailers/ai_credit_notification_mailer_spec.rb`)
- Stubs `Emails::SendTemplateEmail` -- YES
- Tests `admin_recipients` includes owner and admin, excludes member and interviewer -- YES
- Tests `low_credits` template (`'user-ai-credit-balance-low'`) and variables including `credits_remaining` -- YES
- Tests `zero_credits` template (`'user-ai-credit-balance-zero'`) -- YES
- Tests `Emails::SendTemplateEmail#send` invoked once per recipient -- YES

### Bulk job spec (`spec/jobs/bulk_generate_ai_summaries_job_spec.rb`)
- TDD: retry/discard ordering assertion via `rescue_handlers` index comparison -- YES
- `on_complete` success path: broadcasts `AI_SUMMARY_BULK_COMPLETE` + complete mailer `.deliver_later` -- YES
- `on_complete` failure path (succeeded == 0 && failed > 0): broadcasts `AI_SUMMARY_BULK_FAILED` + failed mailer `.deliver_later` -- YES
- Mailer stubs use `instance_double(ActionMailer::MessageDelivery)` with `.deliver_later` verification -- YES

### Renamed spec files
- `create_ai_credit_balance_transaction_spec.rb`: references `CreateAiCreditBalanceTransaction` -- CONFIRMED
- `organization_ai_credit_balance_policy_spec.rb`: references `OrganizationAiCreditBalancePolicy` -- CONFIRMED
- `credit_consumption_with_notifications_spec.rb`: 3 call sites + comment updated to `CreateAiCreditBalanceTransaction` -- CONFIRMED

### Pack coverage
- `spec/models/organization_ai_credit_purchase_spec.rb` has `describe 'CREDIT_PACKS_BY_LOOKUP_KEY'` block -- YES
- Covers count (4 packs), kind split (2 one-off, 2 subscription), `registered_keys`, `subscription_key?`, `one_off_key?`, `credit_amount_for_key` -- YES

### Webhook spec
- Lookup keys updated to four real packs -- YES
- `checkout.session.completed` with `ai_credit_pack_subscription` metadata links purchase -- YES
- No test for `checkout.session.completed` with `mode: 'payment'` (old path removed) -- CONFIRMED
- `invoice.paid` with `ai_credit_pack_top_up` metadata grants one-off credits -- YES
- Invoice-based one-off spec tests separate `apply_one_off_from_invoice` path -- YES

### Apply purchase spec
- Lookup keys updated -- YES
- Subscription creation tests removed -- YES
- Existing purchase found grants credits -- YES
- No existing purchase fails with `:missing_purchase` -- YES

## Findings

**No findings.**
