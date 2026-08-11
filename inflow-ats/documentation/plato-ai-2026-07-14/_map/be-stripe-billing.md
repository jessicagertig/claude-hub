# Slice: BE Stripe integration / credit-purchase sync / plan feature gate

Files:
- `app/services/plan_feature_gate.rb` (modified)
- `app/services/stripe/cancel_credit_pack_subscription.rb` (new)
- `app/services/sync_ai_credit_purchases_with_stripe.rb` (new)
- `spec/services/plan_feature_gate_ai_credits_spec.rb` (new)
- `spec/services/stripe/cancel_credit_pack_subscription_spec.rb` (new)

Out of this slice (scoring pipeline specs, mapped elsewhere): `spec/services/ai_job_application_action/*`, `spec/services/submit_resume_to_textract_spec.rb`.

## What changed

### `PlanFeatureGate`
- New feature constant `AI_APPLICANT_SUMMARY = 'ai_applicant_summary'` added to `universal_features` — so the AI applicant summary feature is now UNLOCKED for every tier-1/tier-2 paid plan (all plans listed in `universal_features`). Free/no-plan tiers still gate it via their denied-feature lists.
- New per-plan monthly + daily AI-credit allocation. Two new public methods: `monthly_ai_credit_allocation` and `daily_ai_credit_allocation`, each reading `plan_rules[@plan]` and falling back to `MINIMUM_AI_CREDIT_ALLOCATION` / `DAILY_AI_CREDIT_ALLOCATION` for unknown plans.
- Monthly allocation per plan (from spec, resolving the `Variables::*` constants): no_plan/simple_free = 0 credits; free/free_v2/simple_ats_paid/simple_ats_per_job/apollo = 25 (MINIMUM); starter/starter_v2 = 50; growth/growth_v2 = 100; scale/scale_v2 = 250; enterprise = 500 (hardcoded literal, not a `Variables::` constant). Daily allocation = `DAILY_AI_CREDIT_ALLOCATION` for all configured plans except no_plan/simple_free which are 0.
- Note: `plan_no_plan` and `plan_simple_ats_free` get `monthly_ai_credit_allocation: 0` explicitly, but the fallback for an *unknown* plan string is MINIMUM (25), not 0.

### `Stripe::CancelCreditPackSubscription` (new)
- Thin class-method service `.cancel(stripe_subscription_id)` → calls `Stripe::Subscription.update(id, cancel_at_period_end: true)`, returns the `Stripe::Subscription`. Raises `Stripe::StripeError` to caller (the `CancelAiCreditSubscription` interactor rescues). Extracted from that interactor so the raw Stripe call lives in a service.

### `SyncAiCreditPurchasesWithStripe` (new)
- Reconciliation service `sync_ai_credits_with_stripe`. Guards: returns early unless org exists AND `stripe_customer_id.present?` AND `organization_ai_credit_balance` exists.
- Subscriptions: pulls last 10 Stripe subscriptions for the customer (`status: 'all'`), filters to those whose first line-item price `lookup_key` contains `'credit'` or `'plato'`. For each, finds the local `OrganizationAiCreditPurchase` by `stripe_subscription_id` + `kind: :subscription`, else falls back to matching via the subscription's Stripe Checkout Session id (`get_organization_ai_credit_purchase`). Diffs and updates local fields: `stripe_price_lookup_key` (+ derived `subscription_credits_per_period` via `OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key`), `subscription_status`, `subscription_current_period_start/_end`, `stripe_cancel_at_period_end`. Then lists all paid invoices for the sub (limit 100) and calls `organization_ai_credit_purchase.sync_subscription_invoice_grant(invoice:)` per invoice to backfill any credit grants a downed webhook missed.
- One-offs: for each local `OrganizationAiCreditPurchase` with `kind: :one_off`, calls `sync_one_off_with_stripe` on the record.
- Errors: `sync_subscription` rescues `Stripe::StripeError` per-subscription (logs + `ap`, continues to next sub); the outer method does not rescue.
- Emits many `ap` (awesome_print) debug lines to stdout/console.

## User-visible / UI behavior enabled
- AI applicant summary feature becomes available on all paid plans (feature-gate unlock).
- Credit allocations drive how many AI summary credits an org gets monthly/daily by plan — directly affects when a user hits the "out of credits" wall and whether upgrade increases their allowance.
- Cancel service backs the "cancel AI credit subscription" UI action: subscription is set to cancel at period end (not immediate) — user keeps credits/access until the current period ends.
- Sync service is a reconciliation/backfill path (likely rake/console/admin, not user-triggered UI). Its effect is user-visible indirectly: after a missed webhook, running sync grants the credits and corrects subscription status/period/cancel-flag shown on the billing page.

## Gating conditions / edge cases
- Sync no-ops silently if org has no `stripe_customer_id` or no `organization_ai_credit_balance`.
- Subscription filter depends on price `lookup_key` containing `credit`/`plato` — a mislabeled Stripe price would be skipped.
- Unknown/legacy plan strings fall back to MINIMUM monthly (25) and DAILY daily — NOT zero. Only explicitly-listed no_plan/simple_free are 0.
- Local purchase match can fall through to checkout-session lookup; if neither matches, that subscription is skipped (`return unless @organization_ai_credit_purchase`).
- Invoice backfill relies on `sync_subscription_invoice_grant` being idempotent (not verified in this slice — owned by `OrganizationAiCreditPurchase` model).

## SHARED / non-AI surfaces touched (regression risk)
- `PlanFeatureGate` is a CROSS-FEATURE service used for ALL plan gating (job limits, user limits, every `denied_features` feature). Changes here:
  - Added `AI_APPLICANT_SUMMARY` into `universal_features` array — reorders/extends the shared list. Low risk but verify no non-AI feature gate reads positional/length assumptions.
  - `plan_rules` hash gained new keys on every plan entry and the three legacy `.merge(...)` plans changed from single-line merges to multi-key merges — verify job_limit/user_limit/denied_features/legacy_plan values are UNCHANGED for every plan (diff shows they are preserved; the only additions are the two allocation keys). Any consumer iterating `plan_rules` values must tolerate the new keys.
  - Removed the `# Universal features...` comment — cosmetic only.

## For manifest (models/inputs used)
- `Stripe::Subscription.update`, `Stripe::Subscription.list`, `Stripe::Checkout::Session.list`, `Stripe::Invoice.list` are the external calls in this slice. No LLM/scoring model calls in these files.
- `OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key(lookup_key)` and instance methods `sync_one_off_with_stripe`, `sync_subscription_invoice_grant(invoice:)` are called but defined on the model (out of slice).
