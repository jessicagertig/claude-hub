# Implementation Angle: Test Coverage -- Round 2

## Checks

### Check 1: New mailer spec
PASS -- Covers `admin_recipients`, `low_credits`, `zero_credits` with template and variable assertions.

### Check 2: Bulk job spec
PASS -- TDD ordering test, on_complete success/failure paths, mailer delivery verification with `instance_double`.

### Check 3: Stripe webhook spec
PASS -- Tests updated for invoice-based top-up (not checkout.session.completed), subscription linking via checkout.session.completed, pack key updates. Idempotency test updated.

### Check 4: `apply_ai_credit_purchase_spec.rb`
PASS -- New `one_off via invoice` describe block with creation, ledger, balance, and idempotency assertions. Subscription section updated with `existing_purchase` fixture and `missing_purchase` failure test.

### Check 5: Renamed/updated specs
PASS -- All renamed files (`create_ai_credit_balance_transaction_spec.rb`, `organization_ai_credit_balance_policy_spec.rb`) reference correct classes. `credit_consumption_with_notifications_spec.rb` updated (3 call sites + comment).

### Check 6: Missing spec update -- `organization_ai_credits_lifecycle_spec.rb`
**HIGH** -- This spec file references the renamed settings key and will fail. See angle-4 F3.

### Check 7: Deleted specs
PASS -- `ai_credit_packs_spec.rb` deleted. Coverage migrated to `organization_ai_credit_purchase_spec.rb`. `consume_ai_credits_spec.rb` deleted (file was renamed, not duplicated). `ai_credit_policy_spec.rb` deleted (renamed to `organization_ai_credit_balance_policy_spec.rb`).

## Verdict: 1 HIGH (stale spec). FAIL.
