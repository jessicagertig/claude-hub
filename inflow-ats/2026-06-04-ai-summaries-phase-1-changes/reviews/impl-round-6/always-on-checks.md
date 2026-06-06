# Always-On Checks — Round 6

## A1 — Source Accuracy

- `OrganizationUser#is_admin` exists (not `is_admin?`): mailer uses `select(&:is_admin)`. PASS.
- Four real Stripe lookup keys replace all six fabricated keys: `CREDIT_PACKS_BY_LOOKUP_KEY` has exactly four keys (`ai_credit_pack_top_up_small`, `ai_credit_pack_top_up_large`, `ai_credit_pack_subscription_small_monthly`, `ai_credit_pack_subscription_large_monthly`). Same keys in `planHelpers.ts`. PASS.
- `Variables::AI_DAILY_CREDIT_ALLOCATION` referenced correctly: `PlanFeatureGate` line 132 uses it. PASS.
- `handle_credit_pack_invoice_paid` `else` branch fully removed: the method is 13 lines, no `else` branch. PASS.

## A2 — Test Coverage

- Mailer spec covers all assertion groups: `admin_recipients`, `low_credits` template + variables, `zero_credits` template, `send` invocation count. PASS.
- Bulk job spec covers all assertion groups: retry/discard ordering, `on_complete` with success, `on_complete` with all-failed, mailer `.deliver_later` verification. PASS.
- Mailer stubs use `instance_double(ActionMailer::MessageDelivery)` with `.deliver_later` verification: bulk job spec line 91, used in all notification tests. PASS.
- Renamed spec files reflect new class names internally: `create_ai_credit_balance_transaction_spec.rb` references `CreateAiCreditBalanceTransaction`, `organization_ai_credit_balance_policy_spec.rb` references `OrganizationAiCreditBalancePolicy`. PASS.
- `spec/models/organization_ai_credit_purchase_spec.rb` has pack coverage: `describe 'CREDIT_PACKS_BY_LOOKUP_KEY'` block present. PASS.

## A3 — Ripple-site Completeness for Renames

- `auto_generate_ai_summaries_setting` -> `auto_generate_ai_summaries`: zero stale references across all `.rb`, `.ts`, `.tsx` files. PASS.
- `AiCreditPacks.*` -> `OrganizationAiCreditPurchase.*`: zero stale `AiCreditPacks` references across `app/`. PASS.
- `ConsumeAiCredits` -> `CreateAiCreditBalanceTransaction`: zero stale references across `app/` and `spec/`. PASS.
- `defaultAutoGenerateAiSummariesEnabled` -> `autoGenerateAiSummariesEnabled`: zero stale references. PASS.
- `AI_CREDITS_EXHAUSTED` -> `AI_SUMMARY_FAILED`: zero stale references. PASS.
- `process_overdue_ai_credit_resets` -> `process_ai_credit_resets`: zero stale references. PASS.

## A4 — Full-stack Analog Completeness

- `BulkJobApplicationAiSummaryResultMailer`: args by ID, `Emails::SendTemplateEmail`, `from: EMAIL_NOTIFICATIONS_ADDRESS`, correct templates and variables. PASS.
- `AccountPlatoAiContainer`: styled component dimensions match `AccountIntegrationsContainer` exactly. `Redirect` to relative path via `${match.url}/settings`. PASS.
- New controllers: method-level rescue (Stripe errors caught at action level). Single params method. `render_one` for show. PASS.

## Findings

No findings. All always-on checks pass.

## Verdict: PASS
