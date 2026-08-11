# Angle 4: Downgrade Scheduling — Pass 1 Findings

## Verified claims

### `CancelAiCreditSubscription` analog (plan section A.6)
- **54 lines:** Confirmed (`wc -l` = 54). ✓
- **`include Interactor` at line 28:** Confirmed. ✓
- **`purchase = context.purchase` at line 31:** Confirmed. Plan correctly flags this as a naming violation NOT to copy. ✓
- **Stripe call at line 33:** `Stripe::CancelCreditPackSubscription.cancel(purchase.stripe_subscription_id)`. Confirmed. ✓
- **Local state update at lines 35-42:** `unless purchase.update(subscription_status: :canceled, ...)` through `context.fail!` block ending at line 42. Confirmed. ✓
- **Rescue at lines 45-52:** `rescue Stripe::StripeError => e` through `context.fail!` block. Confirmed. ✓

### `Stripe::CancelCreditPackSubscription` service
- **File path:** `app/services/stripe/cancel_credit_pack_subscription.rb`. Confirmed exists. ✓
- **25 lines:** Confirmed (`wc -l` = 25). ✓
- **Thin wrapper around `Stripe::Subscription.update`:** Confirmed — `self.cancel` method calls `Stripe::Subscription.update(stripe_subscription_id, cancel_at_period_end: true)`. ✓
- **Service wrapper deviation:** Cancel flow uses service wrapper, new downgrade interactor makes Stripe calls directly. Plan acknowledges this deviation and justifies it (multi-step SubscriptionSchedule API). Confirmed factually correct. ✓

### Schema columns
- **`subscription_current_period_start`:** Exists at `db/schema.rb` line 976. ✓
- **`subscription_current_period_end`:** Exists at `db/schema.rb` line 977. ✓

### `handle_subscription_schedule_downgrade` (webhook handler)
- **Lines 342-401:** Method starts at line 342, ends at line 401. Confirmed. ✓
- **Behavior:** Finds org by `stripe_customer_id`, extracts phase prices, compares them, fires Discord + engagement report jobs on detected downgrade. Does NOT modify any `OrganizationAiCreditPurchase` fields directly. Plan's claim that "the interactor does NOT update local purchase fields" and relies on webhook handlers is consistent. ✓

### `downgrade_detected?` method
- **Lines 403-413:** Method starts at line 403 (`def downgrade_detected?`), body ends at line 413 (`next_tier < current_tier`), `end` is at line 414. Plan says lines 403-413 — off by one for the closing `end`, but the body range is correct. ✓
- **Only recognizes ATS plan tiers:** Line 408: `plan_tiers = %w[free starter growth scale enterprise]`. AI credit lookup keys (e.g., `plato_ai_credit_subscription_small`) do not contain any of these tier names, so `find_index` returns `nil` for both, defaulting to `|| 0`, making `0 < 0` → `false`. Plan's claim is correct. ✓

### `subscription_schedule.updated/created` dispatch
- **Lines 326-328:** Confirmed. Line 326: `when 'subscription_schedule.updated', 'subscription_schedule.created'`, line 327: `ap 'SUBSCRIPTION SCHEDULE UPDATED/CREATED'`, line 328: `handle_subscription_schedule_downgrade(object)`. ✓

## Findings

**No BLOCKER or HIGH findings.**

### LOW-1: `downgrade_detected?` line range off by one

**Plan claim:** Lines 403-413.
**Actual:** Lines 403-414 (line 414 is the `end` keyword).
**Impact:** None — the plan's body range (403-413) captures all the logic; only the closing `end` is at 414.
**Severity:** LOW

### LOW-2: `CancelAiCreditSubscription` uses `purchase` not `organization_ai_credit_purchase`

**Plan claim:** Correctly identifies this at A.6 structural manifest ("Uses `purchase` (line 31) — violates rule") and says "Must use `organization_ai_credit_purchase`" for the new interactor. Also correctly shown in A.6.2 step 1: "Extract `organization_ai_credit_purchase = context.purchase`".
**Impact:** None — plan already handles this correctly.
**Severity:** LOW (noting for completeness, not a finding against the plan)

## Verdict

All factual claims verified. 0 BLOCKER, 0 HIGH, 0 MED, 2 LOW (trivial line count imprecisions).
