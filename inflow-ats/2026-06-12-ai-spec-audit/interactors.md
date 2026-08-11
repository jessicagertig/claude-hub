# Interactor Specs Audit — Round 2 (13 files)

**Branch:** `UI-polishes` | **Date:** 2026-06-18
**Totals:** 38 findings (3 BLOCKER, 10 HIGH, 25 MED), 2 convention issues, 0 clean specs

## Files

| # | File | Findings | Status |
|---|------|----------|--------|
| 1 | `apply_ai_credit_purchase_spec.rb` | 1B, 2H, 3M | BLOCKER |
| 2 | `apply_ai_credit_refund_spec.rb` | 2H, 2M, 1C | HIGH |
| 3 | `cancel_ai_credit_subscription_spec.rb` | 1H | HIGH |
| 4 | `create_ai_credit_balance_transaction_spec.rb` | 1H, 2M | HIGH |
| 5 | `credit_consumption_with_notifications_spec.rb` | 1M | MED |
| 6 | `grant_ai_credits_spec.rb` | 1H, 2M | HIGH |
| 7 | `notify_low_ai_credits_spec.rb` | 2M | MED |
| 8 | `notify_zero_ai_credits_spec.rb` | 1M | MED |
| 9 | `queue_bulk_ai_summary_jobs_spec.rb` | 1H, 1M | HIGH |
| 10 | `reset_ai_credits_spec.rb` | 3M | MED |
| 11 | `reset_daily_ai_credits_spec.rb` | 4M | MED |
| 12 | `create_bulk_ai_summary_generation_spec.rb` | 3M | MED |
| 13 | `find_or_create_ai_job_application_summary_status_spec.rb` | 2B, 2H, 1M, 1C | BLOCKER |

## Findings

### `apply_ai_credit_purchase_spec.rb`

**Code under test:** `app/interactors/apply_ai_credit_purchase.rb`
**File chain:** spec/interactors/apply_ai_credit_purchase_spec.rb -> app/interactors/apply_ai_credit_purchase.rb -> app/models/organization_ai_credit_purchase.rb (CREDIT_PACKS_BY_LOOKUP_KEY, credit_amount_for_key, validations) -> app/models/ai_credit_balance_transaction.rb (counter_culture on bucket columns) -> app/models/organization_ai_credit_balance.rb -> spec/support/ai_credits_test_helpers.rb (create_credit_test_organization)

**Summary:** The spec has one BLOCKER and two HIGH findings, all caused by drift. Commit a53045a2b added invoice.lines.data.first&.period access to apply_subscription without updating the spec's invoice double, which will crash the subscription happy-path test with an RSpec MockExpectationError. The subscription activation logic (setting subscription_status, period start/end) added in the same commit has zero test coverage. Additionally, the subscription path's :missing_organization and :missing_balance guards are untested (only :missing_purchase is covered), and multiple one_off failure paths (:missing_lookup_key, :unknown_lookup_key) and the :invalid_kind else branch lack coverage. The one_off path tests are solid and not ghosts -- they exercise real production code through to database assertions. The price parameter is dead code in both spec and production. No convention issues were found in the spec file itself.

**F1 [BLOCKER] [Prong 3: drift] Subscription invoice double missing lines.data.first.period -- test will crash**
- Location: `spec/interactors/apply_ai_credit_purchase_spec.rb:53-60 vs app/interactors/apply_ai_credit_purchase.rb:98`
- Commit a53045a2b added invoice.lines.data.first&.period access (line 98) to apply_subscription, but the spec's invoice double (lines 53-60) was never updated to mock 'lines'. Plain RSpec doubles raise MockExpectationError on unmocked method calls. The 'grants credits to existing purchase' test at line 78-80 exercises the full apply_subscription happy path, which now requires invoice.lines. The test will raise an error at line 98 of the production code. This makes the subscription happy-path test broken -- it cannot pass against the current production code.
- Evidence: Production code at app/interactors/apply_ai_credit_purchase.rb:98 does 'period = invoice.lines.data.first&.period'. The spec's invoice double at spec/interactors/apply_ai_credit_purchase_spec.rb:53-60 only mocks: id, customer, subscription, amount_paid, currency. Calling .lines on this double will raise RSpec::Mocks::MockExpectationError. This drift was introduced in commit a53045a2b ('AI billing UI polish + activate AI credit subscriptions on first invoice') which modified the production code but did not update the spec.

**F2 [HIGH] [Prong 3: drift] No test coverage for subscription activation (subscription_status, period start/end update)**
- Location: `spec/interactors/apply_ai_credit_purchase_spec.rb:78-80 vs app/interactors/apply_ai_credit_purchase.rb:99-104`
- The production code now updates the existing purchase's subscription_status to :active and sets subscription_current_period_start and subscription_current_period_end from the invoice line item period (lines 99-104). This is core business logic added in commit a53045a2b. Even if the invoice double were fixed with a lines mock, no test assertion verifies that the existing purchase's subscription_status or period dates are updated. The spec only checks that addon_subscription_credits_remaining changes.
- Evidence: Production code at app/interactors/apply_ai_credit_purchase.rb:99-103 calls existing.update(subscription_status: :active, subscription_current_period_start: ..., subscription_current_period_end: ...). No it block in the spec verifies these attributes. The spec at line 78-80 only asserts on balance.reload.addon_subscription_credits_remaining.

**F3 [HIGH] [Prong 3: drift] No coverage for subscription :missing_organization and :missing_balance failure paths**
- Location: `spec/interactors/apply_ai_credit_purchase_spec.rb:51-89 vs app/interactors/apply_ai_credit_purchase.rb:83-120`
- The subscription branch has three failure paths: :missing_organization (line 86), :missing_purchase (line 90), and :missing_balance (line 96). The spec only tests :missing_purchase (line 83-86). The :missing_organization failure (when no org matches the invoice's stripe customer ID) and the subscription-specific :missing_balance failure are untested. The :missing_balance test at line 92-106 only exercises the one_off path.
- Evidence: Production code at app/interactors/apply_ai_credit_purchase.rb:86 has 'return context.fail!(error: :missing_organization, ...)' and line 96 has 'return context.fail!(error: :missing_balance, ...)' in the subscription path. No it block in the spec exercises these subscription-specific failure paths. The validation failures describe block at line 91 tests :missing_balance only via the one_off path (kind: :one_off at line 96-97).

**F4 [MED] [Prong 3: drift] No test for invalid kind failure path**
- Location: `spec/interactors/apply_ai_credit_purchase_spec.rb:9-89 vs app/interactors/apply_ai_credit_purchase.rb:22`
- The production code's case statement has an else branch (line 22) that fails with :invalid_kind when kind is neither :one_off nor :subscription. The spec has no test for this branch.
- Evidence: Production code at app/interactors/apply_ai_credit_purchase.rb:22 does context.fail!(error: :invalid_kind, message: ...) for unrecognized kind values. No it block in the spec passes an invalid kind value.

**F5 [MED] [Prong 3: drift] No test for one_off :missing_lookup_key and :unknown_lookup_key failure paths**
- Location: `spec/interactors/apply_ai_credit_purchase_spec.rb:9-49 vs app/interactors/apply_ai_credit_purchase.rb:49,52`
- The one_off branch has guard clauses for missing lookup_key (line 49) and unknown lookup_key (line 52). Neither is tested. While the happy path exercises a valid lookup_key, there is no test confirming that the interactor correctly fails when lookup_key is nil or unrecognized.
- Evidence: Production code at app/interactors/apply_ai_credit_purchase.rb:49 has 'return context.fail!(error: :missing_lookup_key, ...)' and line 52 has 'return context.fail!(error: :unknown_lookup_key, ...)'. No it block provides a nil or unrecognized lookup_key.

**F6 [MED] [Prong 3: drift] Unused price parameter in production code not detected by spec**
- Location: `spec/interactors/apply_ai_credit_purchase_spec.rb:52 vs app/interactors/apply_ai_credit_purchase.rb:83`
- The production code accepts 'price' as a parameter to apply_subscription (line 83) but never uses it in the method body. The spec creates and passes a price double (line 52) that also goes unused. This is dead code on both sides -- the spec gives false confidence that price is being tested when in fact nothing reads it.
- Evidence: Production code at app/interactors/apply_ai_credit_purchase.rb:83 signature is 'def apply_subscription(invoice, price)'. The method body (lines 84-120) never references 'price'. The spec at line 52 creates let(:price) { double('price', id: 'price_test', lookup_key: '...') } and passes it at line 79 but no assertion involves it.

---

### `apply_ai_credit_refund_spec.rb`

**Code under test:** `app/interactors/apply_ai_credit_refund.rb`
**File chain:** spec/interactors/apply_ai_credit_refund_spec.rb -> app/interactors/apply_ai_credit_refund.rb -> app/models/organization_ai_credit_purchase.rb (enum kind, subscription?, has_many :ai_credit_balance_transactions) -> app/models/ai_credit_balance_transaction.rb (enum entry_type, enum bucket, counter_culture) -> app/models/organization_ai_credit_balance.rb (*_credits_remaining columns) -> spec/support/ai_credits_test_helpers.rb (create_credit_test_organization helper)

**Summary:** The spec file exercises the core happy paths well: full refund for one-off purchases, capped refund when credits are partially consumed, no-op when already refunded, no ledger row when fully consumed, and subscription cancellation with refund. The tests are not ghosts -- they create real database records, call the interactor, and verify side effects via reload. However, the spec has two HIGH-severity gaps: neither the missing_original_credit failure path (line 19 of production) nor the missing_balance failure path (line 22 of production) has any test coverage. These are real guard clauses that protect against data integrity issues. Additionally, the fail_with_record_invalid error-handling paths (lines 43, 58) are untested (MED). The subscription test has a minor issue where it manually overrides a counter_culture-managed column (line 114), masking whether counter_culture correctly updates addon_subscription_credits_remaining -- the one-off tests correctly rely on counter_culture without manual overrides.

**F1 [HIGH] [Prong 3: drift] No test coverage for missing_original_credit failure path**
- Location: `app/interactors/apply_ai_credit_refund.rb:19, spec/interactors/apply_ai_credit_refund_spec.rb (missing)`
- The production code at line 19 calls context.fail!(error: :missing_original_credit) when no original credit ledger row is found for the purchase. This is a real error path that fires when a purchase exists but has no associated AiCreditBalanceTransaction with a purchase_credit entry_type. The spec has zero coverage for this path.
- Evidence: Production code (apply_ai_credit_refund.rb:14-19): original_credit_row = purchase.ai_credit_balance_transactions.where(entry_type: purchase_credit_entry_types).order(:created_at).last; return context.fail!(error: :missing_original_credit, message: 'No original credit ledger row') unless original_credit_row. The spec never creates a purchase without an associated credit transaction to exercise this guard. Every test context includes a let!(:original_credit) that ensures this guard never fires.

**F2 [HIGH] [Prong 3: drift] No test coverage for missing_balance failure path**
- Location: `app/interactors/apply_ai_credit_refund.rb:22, spec/interactors/apply_ai_credit_refund_spec.rb (missing)`
- The production code at line 22 calls context.fail!(error: :missing_balance) when the organization has no OrganizationAiCreditBalance record. The spec has zero coverage for this path. The test helper create_credit_test_organization always creates a balance (with_balance: true by default), so this guard is never exercised.
- Evidence: Production code (apply_ai_credit_refund.rb:21-22): balance = purchase.organization.organization_ai_credit_balance; return context.fail!(error: :missing_balance, message: 'Organization has no credit balance') unless balance. The spec uses let(:organization) { create_credit_test_organization } which defaults to with_balance: true (ai_credits_test_helpers.rb:68-70), guaranteeing a balance always exists.

**F3 [MED] [Prong 3: drift] No test coverage for fail_with_record_invalid error paths**
- Location: `app/interactors/apply_ai_credit_refund.rb:43,58, spec/interactors/apply_ai_credit_refund_spec.rb (missing)`
- The production code has two calls to fail_with_record_invalid (lines 43 and 58) that handle ActiveRecord save/update failures within the transaction block. Neither path is tested. These fire when purchase.update fails (line 43) or when refund_row.save fails (line 58). While difficult to trigger with valid test data, these represent real error-handling paths that should have at least one test verifying the interactor fails gracefully when a save fails.
- Evidence: Production code (apply_ai_credit_refund.rb:43): fail_with_record_invalid('purchase refund update', purchase.errors) unless purchase.update(updates). Production code (apply_ai_credit_refund.rb:58): fail_with_record_invalid('refund ledger row', refund_row.errors) unless refund_row.save. The private method fail_with_record_invalid (line 67-69) logs the error and calls context.fail!. No spec exercises either path.

**F4 [MED] [Prong 2: tests what it claims] Subscription test manually overrides counter_culture-managed column**
- Location: `spec/interactors/apply_ai_credit_refund_spec.rb:114`
- The subscription test at line 114 calls balance.update!(addon_subscription_credits_remaining: 50) to set the balance. However, the let!(:original_credit) block (lines 102-110) already creates an AiCreditBalanceTransaction with bucket: :addon_subscription and amount: 50, which counter_culture should have already incremented addon_subscription_credits_remaining to 50. The manual update is redundant AND masks whether counter_culture is actually working for this bucket. By contrast, the one-off tests correctly rely on counter_culture (no manual balance.update!) and use balance.reload to get the updated value.
- Evidence: Subscription test line 114: balance.update!(addon_subscription_credits_remaining: 50). One-off test line 35 relies on counter_culture: .and change { balance.reload.addon_credits_remaining }.from(50).to(0) -- no manual update needed. If counter_culture failed for addon_subscription bucket, the subscription test would still pass because of the manual override, while the one-off test would correctly fail.

**C1 [Convention] RSpec naming convention (interactor_patterns_and_structure.md)**
- Location: `spec/interactors/apply_ai_credit_refund_spec.rb:9,87`
- The spec lacks a describe '.call' block wrapping the test contexts. The top-level contexts ('one-off credit pack refund', 'subscription credit pack refund') directly nest under RSpec.describe ApplyAiCreditRefund. Standard RSpec convention for interactors is to wrap tests in describe '.call' do ... end to match the public API entry point.

---

### `cancel_ai_credit_subscription_spec.rb`

**Code under test:** `app/interactors/cancel_ai_credit_subscription.rb`
**File chain:** cancel_ai_credit_subscription_spec.rb -> CancelAiCreditSubscription (app/interactors/cancel_ai_credit_subscription.rb) -> Stripe::CancelCreditPackSubscription (app/services/stripe/cancel_credit_pack_subscription.rb) -> OrganizationAiCreditPurchase (app/models/organization_ai_credit_purchase.rb) -> OrganizationAiCreditBalance (app/models/organization_ai_credit_balance.rb) -> AiCreditsTestHelpers (spec/support/ai_credits_test_helpers.rb)

**Summary:** The spec for CancelAiCreditSubscription is well-structured and non-ghost. Its stubs correctly match the real Stripe::CancelCreditPackSubscription.cancel signature (class method taking one string argument). The happy path and the Stripe error path are both tested with appropriate assertions. The single finding is a HIGH-severity coverage gap: the production code has an explicit :record_invalid failure branch (lines 35-42, triggered when purchase.update returns false after a successful Stripe cancellation) that has no corresponding test. This is one of only two explicitly coded failure paths in the interactor, and while difficult to trigger with current validations, it represents intentional defensive code that the spec does not exercise. No convention issues were found; the spec uses create! appropriately for test setup, follows proper describe/context/it naming, and uses described_class.call consistently.

**F1 [HIGH] [Prong 3: drift] Missing coverage for :record_invalid failure path**
- Location: `spec/interactors/cancel_ai_credit_subscription_spec.rb (entire file) vs app/interactors/cancel_ai_credit_subscription.rb:35-42`
- The production code has an explicit branch at lines 35-42 where if purchase.update returns false (after the Stripe call succeeds), the interactor logs an error and calls context.fail!(error: :record_invalid, ...). This is one of only two failure paths in the interactor (the other being :stripe_error, which IS tested). The spec has no context or it block exercising this branch.
- Evidence: Production code at cancel_ai_credit_subscription.rb:35-42 has: unless purchase.update(subscription_status: :canceled, subscription_canceled_at: Time.current) / Rails.logger.error ... / context.fail!(error: :record_invalid, message: ..., purchase_id: ...) / end. The spec tests only two contexts: 'when Stripe accepts the cancellation' (happy path) and 'when Stripe raises an error' (:stripe_error path). No test forces purchase.update to return false to exercise the :record_invalid branch. This is a defensive guard for edge cases (e.g., a future validation addition, or concurrent state changes between the Stripe call and the local update). It is a real, explicitly coded failure path with its own error key, logging, and context output fields, and it has zero test coverage.

---

### `create_ai_credit_balance_transaction_spec.rb`

**Code under test:** `app/interactors/create_ai_credit_balance_transaction.rb`
**File chain:** spec/interactors/create_ai_credit_balance_transaction_spec.rb -> app/interactors/create_ai_credit_balance_transaction.rb -> app/models/ai_credit_balance_transaction.rb (counter_culture, enums, validations, before_update/before_destroy guards) -> app/models/organization_ai_credit_balance.rb (balance model, total_credits_remaining, credits_available?) -> spec/support/ai_credits_test_helpers.rb (create_credit_test_organization, create_credit_test_summary)

**Summary:** The spec is a legitimate integration test (not ghosted) that correctly exercises 3 of the 5 code paths in CreateAiCreditBalanceTransaction: monthly deduction, addon deduction, insufficient credits, and missing balance. No stubs are used -- the spec relies on real database operations and counter_culture to verify behavior. However, the spec has drifted from the production code: the determine_bucket method has 4 bucket priorities (daily, monthly, addon_subscription, addon) but the spec only tests monthly and addon. The daily and addon_subscription buckets have zero coverage, which is HIGH severity given that bucket priority order is business-critical logic (daily credits expire soonest). The spec description at line 19 also misleadingly says monthly is deducted "first" when daily is actually first. The :record_invalid error path (txn.save failure) is also untested. No convention issues were found -- the spec uses bang methods appropriately for test setup, uses reload correctly for verifying database state, and follows proper describe/context/it naming patterns.

**F1 [HIGH] [Prong 3: drift] Spec only tests 2 of 4 bucket priority paths in determine_bucket**
- Location: `spec/interactors/create_ai_credit_balance_transaction_spec.rb:11-53 vs app/interactors/create_ai_credit_balance_transaction.rb:56-66`
- The production determine_bucket method implements a 4-step priority: daily -> monthly -> addon_subscription -> addon. The spec only tests the monthly and addon paths. There are zero tests for when daily_credits_remaining > 0 (should deduct from daily first) and zero tests for when addon_subscription_credits_remaining > 0 (should deduct from addon_subscription before addon). The bucket priority order is business-critical -- daily credits expire soonest, so consuming them first is the designed behavior. The missing coverage means a regression that swaps the priority order (e.g., consuming addon before addon_subscription) would not be caught.
- Evidence: Production determine_bucket (lines 56-66) checks daily first, then monthly, then addon_subscription, then addon. Spec line 12 sets monthly_credits_remaining: 5 and addon_credits_remaining: 10 but never sets daily_credits_remaining or addon_subscription_credits_remaining to non-zero values. Spec line 41 sets monthly=0 and addon=10, again leaving daily and addon_subscription at their default 0. No context block exists for daily or addon_subscription buckets.

**F2 [MED] [Prong 3: drift] Spec description claims monthly is deducted 'first' but daily is actually first**
- Location: `spec/interactors/create_ai_credit_balance_transaction_spec.rb:19`
- The it block at line 19 says 'deducts from monthly bucket first, leaving addon untouched'. The production code deducts from daily first, then monthly. The test only exercises the monthly path because daily_credits_remaining defaults to 0 in the test setup, making the description factually incorrect about the deduction priority. This could mislead future developers into thinking monthly is the highest-priority bucket.
- Evidence: Spec line 19: 'deducts from monthly bucket first, leaving addon untouched'. Production determine_bucket lines 57-58: 'if balance.daily_credits_remaining >= CREDIT_COST then :daily'. Daily is checked before monthly. The spec setup (line 12) sets monthly_credits_remaining: 5 but leaves daily_credits_remaining at its default 0, so the test correctly exercises the monthly path, but the description misrepresents the priority order.

**F3 [MED] [Prong 3: drift] No test for the :record_invalid error path (txn.save failure)**
- Location: `spec/interactors/create_ai_credit_balance_transaction_spec.rb (missing) vs app/interactors/create_ai_credit_balance_transaction.rb:43-47`
- The production code at lines 43-47 handles the case where txn.save returns false: it logs the error, prints via ap, and calls context.fail!(error: :record_invalid, ...). No spec exercises this code path. While triggering a save failure requires either invalid data (which the interactor constructs internally) or a database constraint violation, this is still an untested error branch.
- Evidence: Production lines 43-47: 'unless txn.save ... context.fail!(error: :record_invalid, message: txn.errors.full_messages.join(...))'. No it block in the spec contains :record_invalid or tests save failure. The spec covers :insufficient_credits (line 59) and :missing_balance (line 79) but not :record_invalid.

---

### `credit_consumption_with_notifications_spec.rb`

**Code under test:** `app/interactors/create_ai_credit_balance_transaction.rb, app/interactors/notify_zero_ai_credits.rb, app/interactors/notify_low_ai_credits.rb, app/interactors/reset_ai_credits.rb`
**File chain:** spec/interactors/credit_consumption_with_notifications_spec.rb -> app/interactors/create_ai_credit_balance_transaction.rb -> app/interactors/notify_zero_ai_credits.rb -> app/interactors/notify_low_ai_credits.rb -> app/interactors/reset_ai_credits.rb -> app/models/organization_ai_credit_balance.rb -> app/models/ai_credit_balance_transaction.rb (counter_culture gem) -> app/mailers/ai_credit_notification_mailer.rb -> app/services/plan_feature_gate.rb -> spec/support/ai_credits_test_helpers.rb

**Summary:** This is a well-structured integration spec that exercises the full chain of CreateAiCreditBalanceTransaction -> NotifyZeroAiCredits -> NotifyLowAiCredits -> ResetAiCredits with real database operations and no stubs. It tests five key scenarios: comfortable balance (no notifications), crossing the low threshold, reaching zero, deduplication of low-credit notifications, and reset clearing notification flags so they can re-fire. The spec uses the AiCreditsTestHelpers support module for setup and correctly relies on the counter_culture gem's synchronous balance updates. There are no ghost tests -- all assertions exercise real production code paths and would fail if the production code were removed. The only finding is a minor test-hygiene issue where the notification-absence test at line 53 calls consume_and_evaluate twice (once per assertion), consuming 2 credits instead of 1, though this does not affect correctness since both resulting balances are far above the notification threshold. No convention violations were found. No spec drift was detected -- the spec accurately reflects the current production code's branching logic, guard clauses, and callback behavior.

**F1 [MED] [Prong 2: tests what it claims] Double invocation of consume_and_evaluate in notification-absence test**
- Location: `spec/interactors/credit_consumption_with_notifications_spec.rb:53-56`
- The 'does not fire any notifications' test calls consume_and_evaluate twice -- once per expect block. Each call creates a separate AiCreditBalanceTransaction, consuming 2 credits total (50->49 then 49->48) instead of the 1 the test implicitly claims. Both assertions are not_to and both pass correctly (49 and 48 are both well above the threshold of 5), so this is not a ghost and does not mask a bug. However, the test does more work than described and could confuse a future reader who expects exactly one credit consumed.
- Evidence: Lines 53-56: two separate expect { consume_and_evaluate } blocks each invoke the full consume_and_evaluate method (lines 36-41). The summary let variable is memoized, so the same summary is used both times. CreateAiCreditBalanceTransaction creates a new AiCreditBalanceTransaction on each call with no uniqueness guard. The counter_culture callback decrements monthly_credits_remaining by 1 each time. First call: 50->49; second call: 49->48. Both are above threshold 5, so both not_to assertions pass for the right reason, but 2 credits are consumed rather than 1.

---

### `grant_ai_credits_spec.rb`

**Code under test:** `app/interactors/grant_ai_credits.rb`
**File chain:** spec/interactors/grant_ai_credits_spec.rb -> app/interactors/grant_ai_credits.rb -> app/models/ai_credit_balance_transaction.rb (enum, validations, counter_culture) -> app/models/organization_ai_credit_balance.rb (association, columns) -> spec/support/ai_credits_test_helpers.rb (create_credit_test_organization helper)

**Summary:** The GrantAiCredits spec is a solid, non-ghost test suite that correctly exercises the production interactor through real database operations without mocking the subject under test. All six `it` blocks call the production code directly and assert on real DB state or interactor result objects. The helper `create_credit_test_organization` properly sets up a real Organization with a real OrganizationAiCreditBalance row, and counter_culture correctly increments addon_credits_remaining when transactions are saved. Two coverage gaps exist: (1) HIGH -- no test for the :record_invalid failure path when AiCreditBalanceTransaction#save fails (production lines 65-69), which is a real error branch with logging and a distinct failure error code; (2) MED -- no test verifies the notification flag reset side effect (production lines 73-76), where update_columns resets sent_low_notification_since_increase and sent_zero_notification_since_increase after a successful grant. There is also a MED naming inconsistency where one test description mentions 'manual_grant' but the actual entry_type is 'admin_credit'. No convention violations were found -- the spec follows interactor testing patterns correctly, uses bang methods appropriately for test setup, and the test structure is clear.

**F1 [HIGH] [Prong 3: drift] No spec coverage for :record_invalid failure path (txn.save fails)**
- Location: `app/interactors/grant_ai_credits.rb:65-69`
- The production code at lines 65-69 handles the case where AiCreditBalanceTransaction#save returns false -- it logs the error, calls `ap txn.errors`, and calls `context.fail!(error: :record_invalid, ...)`. This is a real failure path (e.g., triggered if entry_type_and_amount_valid custom validation fails for some reason, or if another model validation rejects the record). No test exercises this branch. The spec only tests the happy path for valid transactions and the three guard-clause failure paths (invalid_amount, missing_reason, missing_balance).
- Evidence: Production code lines 65-69: `unless txn.save` -> `context.fail!(error: :record_invalid, message: txn.errors.full_messages.join(', '))`. Spec has zero tests with context blocks or `it` blocks that assert `result.error` equals `:record_invalid`. This is a missing error branch with no coverage.

**F2 [MED] [Prong 3: drift] No spec coverage for notification flag reset (update_columns side effect)**
- Location: `app/interactors/grant_ai_credits.rb:73-76`
- After a successful grant, the production code at lines 73-76 calls `balance.update_columns(sent_low_notification_since_increase: false, sent_zero_notification_since_increase: false)`. This is a deliberate side effect that resets low-credit notification flags so the organization will receive fresh notifications if credits go low again. No test verifies that these flags are reset after a grant. The spec's happy-path test at line 20 checks addon_credits_remaining and monthly_credits_remaining but does not check the notification flags.
- Evidence: Production code lines 73-76: `balance.update_columns(sent_low_notification_since_increase: false, sent_zero_notification_since_increase: false)`. Spec line 20-31: happy path test only asserts `balance.reload.addon_credits_remaining` and `balance.monthly_credits_remaining`. grep for 'sent_low_notification' and 'sent_zero_notification' in the spec returns no matches.

**F3 [MED] [Prong 2: tests what it claims] Test description says 'manual_grant' but entry_type is 'admin_credit'**
- Location: `spec/interactors/grant_ai_credits_spec.rb:33`
- The `it` block description reads 'inserts a manual_grant ledger row with reason and metadata' but the actual entry_type being asserted at line 42 is 'admin_credit'. There is no 'manual_grant' entry_type in the AiCreditBalanceTransaction enum. The assertion itself is correct (line 42: `expect(txn.entry_type).to eq 'admin_credit'`), but the test description is misleading. The production code's own comment (line 4) also says 'manual_grant' which is likely where this came from, but the test description should reflect the actual tested value.
- Evidence: Spec line 33: `it 'inserts a manual_grant ledger row with reason and metadata'`. Spec line 42: `expect(txn.entry_type).to eq 'admin_credit'`. AiCreditBalanceTransaction enum (line 25): `admin_credit: 40`. There is no 'manual_grant' entry_type in the enum. The description and assertion are misaligned.

---

### `notify_low_ai_credits_spec.rb`

**Code under test:** `app/interactors/notify_low_ai_credits.rb`
**File chain:** spec/interactors/notify_low_ai_credits_spec.rb -> app/interactors/notify_low_ai_credits.rb -> app/models/organization_ai_credit_balance.rb (total_credits_remaining, sent_low_notification_since_increase) -> app/models/organization.rb (settings, update_settings) -> app/mailers/ai_credit_notification_mailer.rb (low_credits) -> spec/support/ai_credits_test_helpers.rb (create_credit_test_organization)

**Summary:** This spec is well-structured and tests the core behavior of NotifyLowAiCredits with no stubs or mocks -- it is a genuine integration test. The positive test (lines 36-39) correctly verifies that a mailer is enqueued via deliver_later, and the side-effect test (lines 42-47) verifies the balance record is updated with the notification timestamp and flag. All four negative test contexts (zero balance, at/above threshold, already sent, notifications disabled) correctly verify their respective guard clauses. There are no ghost tests and no convention violations. The two MED findings are missing coverage for two of the seven guard clauses in the production code: the 'balance not present' guard (line 22) and the 'threshold not positive' guard (line 27). Neither is likely to mask a bug in its current form -- these are defensive guards for edge cases -- but they represent untested branches that could drift without detection.

**F1 [MED] [Prong 3: drift] No test for the 'balance not present' guard clause**
- Location: `spec/interactors/notify_low_ai_credits_spec.rb (missing context) vs app/interactors/notify_low_ai_credits.rb:22`
- The production code at line 22 has `return unless balance.present?` which handles the case where an organization has no OrganizationAiCreditBalance record. The spec has no context block testing this branch. The `create_credit_test_organization` helper always creates a balance record (via `with_balance: true` default), so the guard is never exercised.
- Evidence: Production code line 22: `return unless balance.present?`. The spec's `let(:organization)` uses `create_credit_test_organization(plan: 'plan_ats_tier_starter_v2')` which defaults `with_balance: true`, always creating the balance record. No test exercises calling the interactor with an organization that has no balance.

**F2 [MED] [Prong 3: drift] No test for the 'threshold not positive' guard clause**
- Location: `spec/interactors/notify_low_ai_credits_spec.rb (missing context) vs app/interactors/notify_low_ai_credits.rb:27`
- The production code at line 27 has `return unless threshold.positive?` which guards against a threshold of 0 or negative values. The default setting for `low_ai_credit_notification_threshold` is 0 (from Organization#default_settings line 1277). The spec always sets the threshold to 5 in its global `before` block and never tests the case where the threshold remains at its default of 0 or is explicitly set to 0.
- Evidence: Production code line 25-27: `threshold = organization.settings['low_ai_credit_notification_threshold'].to_i` followed by `return unless threshold.positive?`. The spec's `before` block at line 19-22 always sets `low_ai_credit_notification_threshold: 5`. No test verifies that a threshold of 0 prevents notification.

---

### `notify_zero_ai_credits_spec.rb`

**Code under test:** `app/interactors/notify_zero_ai_credits.rb`
**File chain:** spec/interactors/notify_zero_ai_credits_spec.rb -> app/interactors/notify_zero_ai_credits.rb -> app/models/organization_ai_credit_balance.rb (total_credits_remaining, sent_zero_notification_since_increase?) -> app/mailers/ai_credit_notification_mailer.rb (zero_credits) -> app/models/organization.rb (settings, update_settings) -> spec/support/ai_credits_test_helpers.rb (create_credit_test_organization)

**Summary:** The spec is well-written with no ghost tests, no stubs (all interactions use real objects and database state), and solid coverage of the main code paths. The spec correctly tests: (1) the happy path where zero-credit notification is sent and deduplication fields are updated, (2) the positive-balance guard, (3) the already-sent guard, and (4) the org-level notification setting guard. There are no convention violations. The only finding is a MED-severity coverage gap for the first guard clause (return unless balance.present?) at line 20 of the production code, which has no corresponding test context. The spec uses the ActiveJob test adapter correctly with have_enqueued_mail assertions, and the assertions target real behavior rather than stub return values. No drift detected between the spec and the current production code signatures or return types.

**F1 [MED] [Prong 3: drift] Missing coverage for guard clause: return unless balance.present?**
- Location: `spec/interactors/notify_zero_ai_credits_spec.rb (entire file) vs app/interactors/notify_zero_ai_credits.rb:20`
- The production code has 4 guard clauses (lines 20-23). The spec covers guards 2, 3, and 4 with dedicated contexts, but guard 1 (return unless balance.present?) on line 20 has no corresponding test context. This guard handles the case where an organization has no OrganizationAiCreditBalance record.
- Evidence: Production code line 20: 'return unless balance.present?' -- no spec context tests the case where organization.organization_ai_credit_balance is nil. The create_credit_test_organization helper always creates a balance by default (with_balance: true), so every spec context has a balance present. While this is a minor gap (organizations should always have a balance via the create_ai_credit_state_if_needed callback), it is an untested branch in the code under test.

---

### `queue_bulk_ai_summary_jobs_spec.rb`

**Code under test:** `app/interactors/queue_bulk_ai_summary_jobs.rb`
**File chain:** spec/interactors/queue_bulk_ai_summary_jobs_spec.rb -> app/interactors/queue_bulk_ai_summary_jobs.rb -> Organization (ai_credits_available?, job_applications), BulkAiSummaryJobApplication (model with enum status: processing/done/failed/deferred), BulkGenerateAiSummariesJob, SubmitResumeToTextractJob, Flipper, JobApplication (with_resume, with_textract_results scopes), OrganizationAiCreditBalance (total_credits_remaining), spec/support/ai_credits_test_helpers.rb

**Summary:** The spec is structurally sound -- both tests are legitimate (not ghosts), invoking the production interactor directly and asserting on its context outputs and job enqueueing side effects. No stubs are used, so there are no stub-signature mismatches. The main gap is coverage: the two context.fail! guard clauses at the top of the interactor (Flipper disabled, credits unavailable) have no corresponding test cases, which is a HIGH finding because these are real failure paths that protect against unauthorized usage. The ActiveRecord::RecordNotUnique race condition rescue (lines 60-65) is also untested, though this is a less critical edge case (MED). No convention violations were found.

**F1 [HIGH] [Prong 3: drift] Flipper-disabled and credits-unavailable failure paths have no test coverage**
- Location: `app/interactors/queue_bulk_ai_summary_jobs.rb:17-18`
- The production code has two context.fail! guard clauses at lines 17-18: one for Flipper feature flag disabled, one for ai_credits_available? returning false. Neither failure path is exercised by any test. The spec's before block always enables Flipper and sets 100 monthly credits, meaning these guards are never hit. If either guard were accidentally removed or its condition inverted, no test would catch it.
- Evidence: Production code line 17: context.fail!(error: 'AI summaries are not enabled...') unless Flipper.enabled?(:AI_APPLICANT_SUMMARY, organization). Production code line 18: context.fail!(error: 'Your organization is out of AI credits...') unless organization.ai_credits_available?. Spec before block (lines 20-22) always sets both to passing state: Flipper.enable(:AI_APPLICANT_SUMMARY, organization) and organization.organization_ai_credit_balance.update!(monthly_credits_remaining: 100). No test case disables Flipper or sets credits to 0.

**F2 [MED] [Prong 3: drift] ActiveRecord::RecordNotUnique race condition rescue path untested**
- Location: `app/interactors/queue_bulk_ai_summary_jobs.rb:60-65`
- The production code at lines 54-65 creates BulkAiSummaryJobApplication records in a loop and rescues ActiveRecord::RecordNotUnique for race conditions where another batch claims a candidate between the SELECT and INSERT. This rescue path logs the race and lets the candidate fall into the skipped count via the re-query on line 68. No test exercises this race condition path. The spec's second test (line 67) tests the pre-existing claim scenario (candidate already claimed before the interactor runs), but not the mid-execution race where the unique index raises during the create call.
- Evidence: Production code lines 54-65: working_set.each do |ja_id| BulkAiSummaryJobApplication.create(...) rescue ActiveRecord::RecordNotUnique ... end. No spec test triggers RecordNotUnique during the create loop. The second spec test (line 67-86) pre-creates the claim before calling the interactor, which tests the already_claimed_ids filtering at lines 33-37, not the rescue at line 60.

---

### `reset_ai_credits_spec.rb`

**Code under test:** `app/interactors/reset_ai_credits.rb`
**File chain:** spec/interactors/reset_ai_credits_spec.rb -> app/interactors/reset_ai_credits.rb -> app/models/organization_ai_credit_balance.rb -> app/models/ai_credit_balance_transaction.rb (counter_culture) -> app/services/plan_feature_gate.rb -> app/services/stripe/subscription_status_checker.rb -> spec/support/ai_credits_test_helpers.rb

**Summary:** The spec is well-written with no stubs, no ghost tests, and no convention violations. It exercises the real production code end-to-end using database operations, which is the ideal pattern for interactor specs. All main happy-path branches are covered: monthly reset with positive balance, monthly reset with zero balance, override allocation, missing balance failure, and double-fire safety. Three MED findings relate to drift/coverage gaps: (1) the dedup booleans sent_low_notification_since_increase and sent_zero_notification_since_increase are reset by production code but never set to true in the test setup and never asserted, making the test blind to regressions on those fields; (2) the new_allocation.positive? guard's false branch is never exercised; (3) the three fail_with_record_invalid error paths have no coverage. No BLOCKERs or HIGHs. The spec accurately reflects the production code's current shape for the paths it covers.

**F1 [MED] [Prong 3: drift] Dedup booleans sent_low/sent_zero_notification_since_increase not tested and not set up for meaningful assertion**
- Location: `spec/interactors/reset_ai_credits_spec.rb:9-14 vs app/interactors/reset_ai_credits.rb:65-70`
- The production code at lines 69-70 resets sent_low_notification_since_increase and sent_zero_notification_since_increase to false as part of the balance.update call. The spec never asserts these are cleared. Worse, the before block at lines 9-14 never sets these booleans to true, so they remain at their schema default of false. Even if someone added assertions for them, they would trivially pass without the production code doing anything. To properly test this, the before block would need to set both booleans to true, and then an assertion would verify they are false after the call.
- Evidence: Production code (reset_ai_credits.rb:65-70): balance.update(... sent_low_notification_since_increase: false, sent_zero_notification_since_increase: false). Spec before block (reset_ai_credits_spec.rb:9-14) sets only monthly_credits_remaining, addon_credits_remaining, low_credit_notification_sent_at, zero_credit_notification_sent_at. The booleans are never set to true in setup and never asserted after the call. Schema default is false (db/schema.rb:954-955). A regression removing these fields from the update would be invisible.

**F2 [MED] [Prong 3: drift] No coverage for new_allocation being zero (non-positive) branch**
- Location: `spec/interactors/reset_ai_credits_spec.rb (missing) vs app/interactors/reset_ai_credits.rb:52`
- The production code at line 52 has a guard: if new_allocation.positive? -- only creating the grant transaction if the allocation is positive. The spec never tests the false branch of this guard. All test cases use plan_ats_tier_starter_v2 (allocation=50) or monthly_ai_credits_override=77, both positive. A plan with zero allocation (which would currently not exist in plan_rules but could be added) or a monthly_ai_credits_override of 0 would skip the grant row creation entirely, and there is no test confirming this behavior.
- Evidence: Production code (reset_ai_credits.rb:52): if new_allocation.positive? -- skips grant row creation when allocation is 0 or negative. All spec test cases use allocations of 50 or 77, never testing the zero/negative path. While no current plan has a zero allocation, the override mechanism (monthly_ai_credits_override) could be set to 0, and this path would then be exercised in production without test coverage.

**F3 [MED] [Prong 3: drift] No coverage for fail_with_record_invalid error paths (transaction/grant/balance save failures)**
- Location: `spec/interactors/reset_ai_credits_spec.rb (missing) vs app/interactors/reset_ai_credits.rb:47-49, 60-62, 73`
- The production code has three fail_with_record_invalid calls: line 49 (reset debit row save fails), line 62 (grant row save fails), and line 73 (balance update fails). None of these error paths are exercised by the spec. These are defensive error handling paths that would fire on validation failures. While difficult to trigger in practice (the transaction rows are constructed with valid data), the absence of any coverage means regressions in error handling (logging, error message format, context.fail! payload) would be undetected.
- Evidence: Production code has three fail_with_record_invalid calls (lines 49, 62, 73) and the private method fail_with_record_invalid (lines 82-89) which logs via Rails.logger.error, calls ap, and context.fail! with error: :record_invalid. The spec has zero tests for any of these paths. The only failure path tested is the missing_balance guard (spec lines 81-89).

---

### `reset_daily_ai_credits_spec.rb`

**Code under test:** `app/interactors/reset_daily_ai_credits.rb`
**File chain:** spec/interactors/reset_daily_ai_credits_spec.rb -> app/interactors/reset_daily_ai_credits.rb -> app/services/plan_feature_gate.rb (stubbed) -> app/models/ai_credit_balance_transaction.rb (counter_culture updates OrganizationAiCreditBalance) -> app/models/organization_ai_credit_balance.rb -> config/initializers/01_variables.rb (AI_DAILY_CREDIT_ALLOCATION) -> spec/support/ai_credits_test_helpers.rb (create_credit_test_organization)

**Summary:** The spec is well-structured and exercises the core happy paths effectively: daily credit reset with leftover, daily credit reset without leftover, idempotency check, and no-op when allocation is nil. All stubs correctly match the production code's method signatures and return types (PlanFeatureGate.new takes one argument, daily_ai_credit_allocation returns an integer). The test helper create_credit_test_organization properly sets up the required models. The assertions verify real production behavior through counter_culture-driven balance updates and transaction ledger entries, not stub return values -- these are NOT ghost tests. The four MED findings are all coverage gaps for secondary guard and error paths: the missing-balance context.fail!, the Flipper-disabled early return, the zero-allocation branch (context name promises coverage it does not deliver), and the fail_with_record_invalid error path. None of these gaps mask bugs that would be caught only through test failure, but they represent production code branches the spec does not verify. No convention violations were found.

**F1 [MED] [Prong 3: drift] No coverage for missing-balance context.fail! guard**
- Location: `spec/interactors/reset_daily_ai_credits_spec.rb:5-66 vs app/interactors/reset_daily_ai_credits.rb:11`
- The production code's first guard (line 11) calls context.fail!(error: :missing_balance, ...) when organization.organization_ai_credit_balance is nil. This is a distinct error path that sets the interactor result to failure with a specific error symbol. No spec context exercises this branch.
- Evidence: Production line 11: `return context.fail!(error: :missing_balance, message: 'Organization has no credit balance') unless balance`. The spec's create_credit_test_organization helper always creates an OrganizationAiCreditBalance (with_balance defaults to true at ai_credits_test_helpers.rb:23). No test passes with_balance: false or otherwise creates an organization without a balance.

**F2 [MED] [Prong 3: drift] No coverage for Flipper-disabled guard**
- Location: `spec/interactors/reset_daily_ai_credits_spec.rb:5-66 vs app/interactors/reset_daily_ai_credits.rb:15`
- The production code at line 15 returns early when Flipper.enabled?(:AI_DAILY_CREDITS, organization) is false. Every test enables Flipper in the outer before block (spec line 11). No spec context exercises the Flipper-disabled path.
- Evidence: Production line 15: `return unless Flipper.enabled?(:AI_DAILY_CREDITS, organization)`. Spec line 11: `Flipper.enable(:AI_DAILY_CREDITS, organization)` runs in every test's before block. No context disables Flipper to verify the guard produces a no-op.

**F3 [MED] [Prong 2: tests what it claims] Context claims 'nil or zero' but only tests nil**
- Location: `spec/interactors/reset_daily_ai_credits_spec.rb:56-65`
- The context block is named 'when allocation is nil or zero' but the before block only stubs daily_ai_credit_allocation to return nil. The production guard at line 14 has two conditions: allocation.nil? || allocation.zero?. The zero? branch is not exercised.
- Evidence: Spec line 56: `context 'when allocation is nil or zero' do`. Spec line 58: `allow(plan_feature_gate).to receive(:daily_ai_credit_allocation).and_return(nil)`. Only nil is tested. Production line 14: `return if allocation.nil? || allocation.zero?` -- the zero path is uncovered. A separate test or shared example with .and_return(0) would cover both branches.

**F4 [MED] [Prong 3: drift] No coverage for fail_with_record_invalid error path**
- Location: `spec/interactors/reset_daily_ai_credits_spec.rb:5-66 vs app/interactors/reset_daily_ai_credits.rb:35-36,44-45,51-54`
- The production code has a private fail_with_record_invalid method (lines 51-54) that logs the error and calls context.fail! when an AiCreditBalanceTransaction save fails. This is called at lines 35-36 (reset row) and 44-45 (grant row). No spec exercises a save failure on AiCreditBalanceTransaction.
- Evidence: Production lines 35-36: `fail_with_record_invalid('daily reset row', reset_row.errors) unless reset_row.save`. Production lines 44-45: `fail_with_record_invalid('daily allocation row', grant_row.errors) unless grant_row.save`. Production lines 51-54: logs via Rails.logger.error and calls context.fail!(error: :record_invalid, ...). No spec stub or setup triggers a validation failure on AiCreditBalanceTransaction.

---

### `create_bulk_ai_summary_generation_spec.rb`

**Code under test:** `app/interactors/create_bulk_ai_summary_generation.rb`
**File chain:** spec/interactors/create_bulk_ai_summary_generation_spec.rb -> app/interactors/create_bulk_ai_summary_generation.rb -> app/models/ai_job_application_summary.rb (enum, validations, callbacks) -> app/models/job_application.rb (latest_textract_result, has_many :ai_job_application_summaries) -> app/interactors/validate_ai_summary_generation.rb (validation_result interface: .textract_result) -> spec/support/ai_credits_test_helpers.rb (create_credit_test_organization, credit_test_owner_organization_user, create_credit_test_job, create_credit_test_job_application)

**Summary:** The spec for CreateBulkAiSummaryGeneration is structurally sound and not a ghost. All three test cases exercise the production code directly (no stubs on the code under test), and the assertions target real outcomes from the interactor call. The test helper setup (AiCreditsTestHelpers) correctly creates the prerequisite database records. The three code paths tested -- textract-ready creation, reuse of existing non-stale summary, and stale-detection with fresh row creation -- align with the production code's branching logic. However, there are three MED-severity gaps: (1) no test for the context.fail! path when save fails (line 57 of production code), (2) the have_enqueued_job assertion is vacuously true since the production code never enqueues GenerateAiJobApplicationSummaryJob, and (3) no test for the failed-status exclusion in the active summary query. No convention violations were found. No BLOCKER or HIGH issues.

**F1 [MED] [Prong 3: drift] No test for context.fail! path when save fails**
- Location: `spec/interactors/create_bulk_ai_summary_generation_spec.rb (entire describe block)`
- The production code at line 57 calls context.fail! when ai_summary.save returns false. This is a real code path (e.g., model validation failure) that has no corresponding test case in the spec. All three existing tests exercise success paths or the reuse path -- none exercise the failure branch.
- Evidence: Production code (create_bulk_ai_summary_generation.rb:57): 'context.fail! unless ai_summary.save'. The spec has three context blocks: 'textract-ready path (no active summary)' which expects success, 'reuse path (active non-stale summary exists)' which expects reuse, and 'stale path' which expects a fresh row. None trigger a save failure. Missing a context block like 'when save fails, it fails the context'.

**F2 [MED] [Prong 2: tests what it claims] have_enqueued_job assertion is vacuously true -- production code never enqueues jobs**
- Location: `spec/interactors/create_bulk_ai_summary_generation_spec.rb:51`
- Test 1 (line 38-51) wraps its call in expect { ... }.not_to have_enqueued_job(GenerateAiJobApplicationSummaryJob). The production code CreateBulkAiSummaryGeneration never enqueues GenerateAiJobApplicationSummaryJob anywhere in any code path. This assertion is vacuously true and will pass regardless of what the production code does. The test is not a ghost (the inner assertions on result.ai_summary are meaningful), but this specific assertion tests nothing. It documents the design difference from the single-send analog (CreateAiSummaryGeneration, which does enqueue), but as a test assertion it adds no verification value.
- Evidence: Production code (create_bulk_ai_summary_generation.rb:25-58): no reference to GenerateAiJobApplicationSummaryJob anywhere. Compare with CreateAiSummaryGeneration (create_ai_summary_generation.rb:71-74) which does call GenerateAiJobApplicationSummaryJob.perform_later. The around block (lines 8-13) setting ActiveJob::Base.queue_adapter = :test and the include ActiveJob::TestHelper (line 6) are also only needed for this vacuous assertion.

**F3 [MED] [Prong 3: drift] No test for the failed-status exclusion in the active_ai_summary query**
- Location: `spec/interactors/create_bulk_ai_summary_generation_spec.rb (entire describe block)`
- The production code at lines 34-38 queries for active summaries with '.where.not(status: :failed)', explicitly filtering out failed summaries. The spec does not have a test case that creates a failed summary and verifies the interactor ignores it and creates a new one. This means the .where.not(status: :failed) clause is untested -- if it were removed, all existing tests would still pass.
- Evidence: Production code (create_bulk_ai_summary_generation.rb:35): '.where.not(status: :failed)'. The 'reuse path' test (line 55-71) creates an existing summary with status: :pending, not :failed. There is no test that creates a summary with status: :failed and verifies a new summary is created instead of reusing the failed one.

---

### `find_or_create_ai_job_application_summary_status_spec.rb`

**Code under test:** `app/interactors/find_or_create_ai_job_application_summary_status.rb`
**File chain:** find_or_create_ai_job_application_summary_status_spec.rb -> FindOrCreateAiJobApplicationSummaryStatus (app/interactors/find_or_create_ai_job_application_summary_status.rb) -> AiJobApplicationSummaryStatus (app/models/ai_job_application_summary_status.rb) -> AiJobApplicationSummary (app/models/ai_job_application_summary.rb) -> JobApplication (app/models/job_application.rb, lines 44, 159-170: after_commit -> enqueue_new_job_application -> find_or_create_ai_job_application_summary_status) -> JobChannel (broadcast) -> AiCreditsTestHelpers (spec/support/ai_credits_test_helpers.rb)

**Summary:** This spec has two BLOCKER findings and two HIGH findings. The most severe issue is at lines 90-116: the test 'clears the association, sets status to none, clears denormalized columns' expects clearing behavior that does not exist in the production code. When the status record exists and the summary is present but not succeeded, the production code falls through without modification, but the test expects all fields to be nil/none. This test would fail when run. The second BLOCKER is a ghost test at lines 49-58: the 'makes no changes' test passes because the status record was already created with status 'none' by the JobApplication after_commit callback during test setup, not because the interactor did anything meaningful. The two HIGH findings are untested production code paths: the JobChannel.broadcast_to side effect added in the 'regenerating' branch (lines 16-19 of production code) and the ActiveRecord::RecordNotUnique rescue (lines 43-44). The two 'record does not exist' tests (lines 13-46) are legitimate and exercise real creation behavior correctly.

**F1 [BLOCKER] [Prong 1: works] Ghost test: 'record exists, ai_job_application_summary is nil' asserts state created by callback, not by the subject call**
- Location: `spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb:49-58`
- The test at line 50-58 claims to verify that when the record exists and the summary is nil, the interactor 'makes no changes.' However, the assertion (status eq 'none') passes because the status record was already created with status 'none' by the JobApplication after_commit callback (line 44 of job_application.rb -> enqueue_new_job_application -> find_or_create_ai_job_application_summary_status) during create_credit_test_job_application. The test call at line 53 enters the 'if @status_record' branch, finds no summary, and does nothing (falls through). The assertion at line 57 checks status is 'none' which was already the state before the call. If the production code's call method were replaced with 'def call; context.ai_job_application_summary_status = context.job_application.ai_job_application_summary_status; end', this test would still pass.
- Evidence: Production code (lines 11-17): When @status_record exists and summary is nil, the code enters the 'if @status_record' branch, summary = nil, summary&.status_succeeded? = nil (falsy), no code executes. The test asserts result.success? and status eq 'none' -- both are true regardless of whether the interactor's logic ran, because the status was already 'none' from the after_commit-created record. The test does not verify ANY action taken by the subject call.

**F2 [BLOCKER] [Prong 2: tests what it claims] Test expects clearing behavior that does not exist in production code: 'record exists, ai_job_application_summary is present but not succeeded'**
- Location: `spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb:90-116`
- The test at lines 105-116 claims the interactor clears the association, sets status to 'none', and clears denormalized columns when the summary exists but is not succeeded. The production code has NO such branch. When @status_record exists and summary&.status_succeeded? is false, the code falls through without modification. The before block (lines 96-99) sets the status record to status 'current' with score_percentage 50.0, headline 'Old headline', and integrated_role_analysis 'Old analysis'. After the interactor runs, these values should remain unchanged. The test expects them all to be nil/none, which means this test FAILS when run.
- Evidence: Production code lines 11-17: 'if @status_record' enters the existing-record branch. 'summary = @status_record.ai_job_application_summary' returns the failed summary (created at line 92). 'if summary&.status_succeeded?' is false (summary has status :failed). No code executes. The test at lines 110-114 expects ai_job_application_summary_id to be nil, status to eq 'none', score_percentage to be nil, headline to be nil, integrated_role_analysis to be nil. All of these contradict the actual state after the interactor runs (which is unchanged from the before block: status 'current', score_percentage 50.0, etc.).

**F3 [HIGH] [Prong 3: drift] JobChannel.broadcast_to call added in production code but not tested in spec**
- Location: `spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb (entire file) vs app/interactors/find_or_create_ai_job_application_summary_status.rb:16-19`
- The production code at lines 16-19 broadcasts a 'ai_summary_status_change' event via JobChannel.broadcast_to when the existing record's summary is succeeded and status is set to 'regenerating'. The spec's 'sets status to regenerating' test (lines 81-87) verifies the status change but does not verify or stub the broadcast. This means the broadcast side effect is untested, and if it fails (e.g., due to ActionCable not being configured in test), it could cause the test to error for the wrong reason.
- Evidence: Production code lines 16-19: JobChannel.broadcast_to(job_application.job, event: 'ai_summary_status_change', payload: { jobApplicationId: job_application.id, aiJobApplicationSummaryId: summary.id }). Spec lines 81-87: only asserts result.success? and status eq 'regenerating'. No expect(...).to receive(:broadcast_to) or any verification of the broadcast.

**F4 [HIGH] [Prong 3: drift] ActiveRecord::RecordNotUnique rescue path not tested**
- Location: `spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb (entire file) vs app/interactors/find_or_create_ai_job_application_summary_status.rb:43-44`
- The production code at lines 43-44 rescues ActiveRecord::RecordNotUnique by reloading the job_application and returning the existing status record. This is a race-condition guard for concurrent creation attempts. The spec has no test for this path.
- Evidence: Production code lines 43-44: 'rescue ActiveRecord::RecordNotUnique; context.ai_job_application_summary_status = job_application.reload.ai_job_application_summary_status'. No test in the spec file exercises this rescue branch.

**F5 [MED] [Prong 3: drift] context.fail! on save failure path not tested**
- Location: `spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb (entire file) vs app/interactors/find_or_create_ai_job_application_summary_status.rb:37-39`
- The production code at lines 37-39 calls context.fail! when @status_record.save returns false (the 'create' path). The spec has no test that exercises the failure path of the save operation.
- Evidence: Production code lines 37-39: 'unless @status_record.save; context.fail!; end'. No test in the spec file exercises this branch (e.g., by causing a validation failure on the status record during creation).

**C1 [Convention] backend/_base.md rule 9 (Variable Names Must Match Model Names)**
- Location: `spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb:7`
- The let variable is named 'job_record' (line 7) to hold a Job model instance, presumably to avoid shadowing a method name. While understandable, the convention says variable names should match the model name. The codebase convention would be 'job' for a Job instance. If 'job' causes a conflict, this is an acceptable deviation, but it is worth noting as a minor convention inconsistency.

---
