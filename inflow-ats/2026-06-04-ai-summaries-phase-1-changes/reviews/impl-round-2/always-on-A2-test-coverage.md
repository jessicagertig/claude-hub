# Always-On A2: Test Coverage -- Round 2

## Checks

### Check 1: Mailer spec covers all assertion groups
PASS -- `spec/mailers/ai_credit_notification_mailer_spec.rb`: `admin_recipients` (includes owner+admin, excludes member+interviewer), `low_credits` (template name, variables including `credits_remaining`), `zero_credits` (template name), `send` invocation count.

### Check 2: Bulk job spec covers all assertion groups with TDD evidence
PASS -- `spec/jobs/bulk_generate_ai_summaries_job_spec.rb`: retry/discard ordering test (checks `rescue_handlers` index order), `on_complete` success path (mailer `.deliver_later`), `on_complete` all-failed path (failure broadcast + mailer).

### Check 3: Mailer stubs use `instance_double(ActionMailer::MessageDelivery)`
PASS -- Line 71 in bulk job spec: `let(:mailer_double) { instance_double(ActionMailer::MessageDelivery, deliver_later: true) }`. Used for both `complete` and `failed` mailer stubs.

### Check 4: Renamed spec files reflect new class names
PASS -- `create_ai_credit_balance_transaction_spec.rb` describes `CreateAiCreditBalanceTransaction`. `organization_ai_credit_balance_policy_spec.rb` describes `OrganizationAiCreditBalancePolicy`.

### Check 5: `organization_ai_credit_purchase_spec.rb` has pack coverage
PASS -- `describe 'CREDIT_PACKS_BY_LOOKUP_KEY'` block tests count (4), kind distribution (2+2), `registered_keys`, `subscription_key?`, `one_off_key?`, `credit_amount_for_key`.

### Check 6: Stale spec file not caught -- `organization_ai_credits_lifecycle_spec.rb`
**HIGH** -- see angle-4 F3. This file was missed in both the plan and the implementation. It references `default_auto_generate_ai_summaries_enabled` which was renamed.

## Verdict: 1 HIGH. FAIL.
