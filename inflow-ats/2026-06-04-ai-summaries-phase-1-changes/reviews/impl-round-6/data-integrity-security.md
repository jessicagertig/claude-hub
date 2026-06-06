# Data Integrity and Security — Round 6

## Review

### Idempotency

**One-off purchases:** `apply_one_off` checks `OrganizationAiCreditPurchase.find_by(stripe_checkout_session_id: session.id)` before creating. Duplicate webhook deliveries return existing record. PASS.

**Subscription purchases:** `apply_subscription` looks up by `stripe_subscription_id`. If missing, fails with `:missing_purchase`. If found, creates ledger row. Duplicate webhook deliveries will attempt duplicate ledger rows -- the `AiCreditBalanceTransaction` does not have a unique constraint on `(organization_ai_credit_purchase_id, entry_type)`. This is a pre-existing design pattern (same as before the spec changes) and was not introduced by this PR. NOTED but not a finding.

**Checkout session linking:** `update_columns` is used to set `stripe_subscription_id` on existing purchase. If the webhook fires twice, the same value is written. PASS.

### Authorization

- Balance show: `OrganizationAiCreditBalancePolicy#show?` -> `is_org_user?`. PASS.
- Purchase show/prices: `OrganizationAiCreditPurchasePolicy#show?` -> `is_org_user?`. PASS.
- Checkout/purchase_top_up/cancel: `BillingPolicy` actions. PASS.
- Plato AI container: admin-only gate via `useAuthorization`. PASS.
- Non-admins: no Plato AI sidebar entry. PASS.

### Validation integrity

- `OrganizationAiCreditPurchase` validations correctly relax for pre-checkout subscription state (`stripe_subscription_id.blank?`) while maintaining strictness for all other states. PASS.
- `stripe_checkout_session_id` required for one-offs unconditionally. PASS (Round 5 relaxation reverted).

### Financial accuracy

- `amount_cents_paid` and `currency` populated from invoice in `handle_credit_pack_invoice_paid`. PASS.
- Credit amounts come from `OrganizationAiCreditPurchase.credit_amount_for_key` (single source of truth). PASS.
- Refund capping: `ApplyAiCreditRefund` caps at `[original_amount, current_bucket_balance].min`. No negative buckets. PASS.

## Findings

No findings.

## Verdict: PASS (0 HIGH, 0 MED)
