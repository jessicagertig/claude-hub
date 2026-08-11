# Implementation Review Round 3 -- Verdict

**Feature:** Custom AI Credit Subscription Upgrade/Downgrade
**Branch:** `billing-bonanza` (worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/`)
**Review date:** 2026-06-25
**Reviewer:** Adversarial impl review agent (Round 3)

## Verdict: FAIL

0 BLOCKER, 0 HIGH, 1 MED, 0 LOW.

---

## MED-1: Out-of-scope rewrite of `customer_subscription` action

**File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:360-375`

**What happened:**
The `customer_subscription` action was completely rewritten. The spec says the controller modifications are: add `preview_subscription_change` and `commit_subscription_change`; remove `change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `continue_change_subscription_portal_session`. The `customer_subscription` action is not listed as modified.

The old implementation:
```ruby
def customer_subscription
  organization_ai_credit_purchase = current_organization.organization_ai_credit_purchases
    .subscription.find_by(subscription_status: [:active, :past_due])
  if organization_ai_credit_purchase.nil? || organization_ai_credit_purchase.stripe_subscription_id.nil?
    render json: { subscription: nil }
  else
    begin
      render json: { subscription: organization_ai_credit_purchase.stripe_subscription }
    rescue StandardError => e
      ...
    end
  end
end
```

The new implementation:
```ruby
def customer_subscription
  subscriptions = current_organization.stripe_customer_subscriptions&.data || []
  credit_subscriptions = subscriptions.select do |subscription|
    lookup_key = subscription.items&.data&.[](0)&.price&.lookup_key.to_s
    lookup_key.include?('credit') || lookup_key.include?('plato')
  end
  current_subscription = credit_subscriptions.find { |s| s.status == 'trialing' } ||
                         credit_subscriptions.find { |s| s.status == 'active' } ||
                         credit_subscriptions[0]
  render json: { subscription: current_subscription }
rescue StandardError => e
  ...
end
```

Three behavioral differences:

1. **Data source changed.** Old: finds the local `OrganizationAiCreditPurchase` record (filtered by `kind: :subscription, subscription_status: [:active, :past_due]`), then calls `organization_ai_credit_purchase.stripe_subscription` which uses `Stripe::Subscription.retrieve`. New: calls `current_organization.stripe_customer_subscriptions` which uses `Stripe::Subscription.list`, then filters by lookup key string matching.

2. **Stripe expand param dropped.** Old: `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })` -- expands tier pricing data in the response. New: `Stripe::Subscription.list(...)` -- no `expand` parameter. If the frontend depends on `price.tiers` being present (e.g., for tiered pricing display), this will break.

3. **Fabricated fallback.** Line 361: `current_organization.stripe_customer_subscriptions&.data || []` -- fabricates an empty array for absent data (known failure pattern #13). When `stripe_customer_id` is nil, `stripe_customer_subscriptions` returns nil, `&.data` returns nil, `|| []` converts to empty array. The old version would have explicitly rendered `{ subscription: nil }` through the nil guard.

**Why MED (not LOW):**
- Unspec'd behavioral change to a production read endpoint that the frontend depends on (`useAiCreditCustomerSubscription` hook). Different response shape or missing tiers expansion could break subscription display.
- No test coverage for the changed behavior.
- Per Known Failure Pattern #10: code beyond defect/feature scope.
- The begin-block removal to method-level rescue is a welcome convention improvement -- but it does not require changing the data source or filtering logic.

**Fix:** Revert `customer_subscription` to its committed version. If the begin-block cleanup is desired, apply ONLY that change (replace the `begin...rescue...end` inside the `else` with method-level rescue, keeping the same data source and logic):
```ruby
def customer_subscription
  organization_ai_credit_purchase = current_organization.organization_ai_credit_purchases
    .subscription.find_by(subscription_status: [:active, :past_due])
  if organization_ai_credit_purchase.nil? || organization_ai_credit_purchase.stripe_subscription_id.nil?
    render json: { subscription: nil }
  else
    render json: { subscription: organization_ai_credit_purchase.stripe_subscription }
  end
rescue StandardError => e
  Sentry.capture_exception(e)
  Rails.logger.error(e)
  render json: { errors: ['Unable to load subscription'] }
end
```

If the full rewrite (different data source, different filtering) is desired, it needs its own spec entry with explicit frontend impact analysis and test coverage.

---

## Round 2 BLOCKER Restoration Verification

| Check | Status |
|-------|--------|
| `organization_ai_credit_purchase.rb` validations intact | VERIFIED -- no uncommitted changes to model file |
| `AccountBillingAiCredits.tsx` exists | VERIFIED -- file exists, no uncommitted changes |
| Pre-existing toast delays unchanged | VERIFIED -- only new feature code has `delay: 30000`; pre-existing `delay: 10000` at line 260 is unchanged |
| No other out-of-scope files | VERIFIED -- all 8 modified files match spec's list (EXCEPT `customer_subscription` within the controller file) |

---

## Round 1 Fix Verification

| Fix | Status |
|-----|--------|
| H1 (stale-closure isLoading) | VERIFIED -- `removeModal()` called before `commitSubscriptionChange`, matching cancel modal pattern |
| M1 (nil guard on credit lookups) | VERIFIED -- `unless current_credits && new_credits` guard with `render_general_errors` + bare `return` at lines 315-318 |
| M2 (lookup key fallback) | VERIFIED -- falls back to `currentPlanLookupKeyFromPreview` (raw key), not `""` |
| L1 (dead variable) | VERIFIED -- `currentSubscriptionItemId` removed |

---

## Angle-by-Angle Summary

| # | Angle | Status | Notes |
|---|-------|--------|-------|
| 1 | Stripe API contract | PASS | Preview and commit params identical; `subscription_details` wrapper vs flat params correct per Stripe API |
| 2 | Webhook billing_reason routing | PASS | Branch placed correctly after payment-info stamp; guard ordering safe |
| 3 | Credit granting correctness | PASS | `ApplyAiCreditUpgrade` extracts lookup keys from line items, computes difference, idempotent via `stripe_invoice_id` |
| 4 | Downgrade scheduling | PASS | `ScheduleAiCreditSubscriptionDowngrade` follows Stripe-first pattern; no local state updates |
| 5 | Frontend data flow | PASS | Preview response mapped correctly to modal props; amounts formatted correctly; `prettyDate` accepts unix seconds |
| 6 | Portal flow removal | PASS | All old hooks, functions, exports, imports removed; `redirectToStripe` kept (still used by top-up) |
| 7 | Analog structural matching | PASS | Both interactors match analogs; modal matches CenterModal pattern; `loading={isLoading}` on confirm Button |
| 8 | Authorization and error surface | PASS | `authorize :billing, :change_subscription?` on both actions; guards + method-level rescue + Sentry |
| A1 | Variable naming | PASS | Full model names throughout (`organization_ai_credit_purchase`, `ai_credit_balance_transaction`) |
| A2 | No begin blocks | PASS* | New actions use method-level rescue. *The `customer_subscription` rewrite removes a begin block but also changes behavior (MED-1). |
| A3 | Single quotes | PASS | All Ruby strings use single quotes except interpolation |
| A4 | No bang methods | PASS | Bang methods only in specs |
| A5 | Check save/update return | PASS | All `.update`/`.save` calls checked in interactors |
| A6 | No fabricated fallbacks | PASS* | *`|| []` in `customer_subscription` rewrite (MED-1). New feature code clean. |
| A7 | Never set undefined | PASS | No deliberate `undefined` assignments |
| A8 | Theme colors | PASS | Standard palette colors verified against theme.ts |
| A9 | Emotion utilities standalone | PASS | All `t.text.*`, `t.mt()` used standalone |
| A10 | Separate styled variants | PASS | No conditional props on styled elements |
| A11 | snake_case/camelCase | PASS | Backend `snake_case`, frontend `camelCase` |
| A12 | No hasUnsavedChanges | PASS | Modal omits `hasUnsavedChanges` |
| A13 | Handoff visual reference | PASS | All identifiers from codebase; handoff used for visual design only |
| A14 | Test requirements | PASS | All spec-listed test cases present; no ghost tests |
| A15 | Guard clause bare returns | PASS | All guards use bare `return` |

---

## Committed vs. Working Tree (Known Failure Pattern #15)

`git diff HEAD --stat` run at review start. 8 files with uncommitted changes, 6 untracked new files. All match the spec's file lists. The MED-1 finding is for an out-of-scope change within the controller file (same file that has in-scope changes).
