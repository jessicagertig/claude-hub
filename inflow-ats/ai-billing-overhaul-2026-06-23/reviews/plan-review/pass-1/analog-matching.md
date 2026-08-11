# Angle 7: Analog Structural Matching — Pass 1

## Findings

### M1 (MED): Plan misrepresents `cancel` action variable name in Pattern Precedents

**Location:** Plan section "Pattern precedents", cancel action analog, bullet point for line 196

**Claim:** "Line 196: organization_ai_credit_purchase = current_organization.organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])"

**Actual:** Line 196 of the controller is:
```ruby
subscription = current_organization.organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])
```
The variable is `subscription`, not `organization_ai_credit_purchase`.

**Impact:** Low. The plan's instructions for the NEW actions (A.2.2 step 2, A.3.1 step 2) correctly use `organization_ai_credit_purchase`, matching the naming rule. The analog description is factually wrong but won't mislead the implementation agent into using the wrong variable name.

**Fix:** Correct the analog description to say `subscription = ...` and add a note that the new actions should NOT copy this name, same as the note about `CancelAiCreditSubscription` using `purchase`.

---

### No further findings

All other structural claims verified correct:

**`ApplyAiCreditPurchase` manifest (A.5.1):**
- Line 10: `include Interactor` — CORRECT
- Line 12: `def call` — CORRECT (dispatches to `apply_subscription` via `case kind`)
- Line 31-32: purchase lookup with fallback — CORRECT
- Line 39: idempotency check — CORRECT
- Line 41: balance lookup — CORRECT
- Lines 42-49: missing balance guard — CORRECT (plan says "42-45" which is approximate; the `context.fail!` block extends to line 49, but the semantic claim is accurate)
- Line 53: `ApplicationRecord.transaction` — CORRECT
- Lines 54-59: update fields are `subscription_status`, `subscription_current_period_start`, `subscription_current_period_end`, `stripe_invoice_id` — CORRECT
- Line 60: `fail_with_record_invalid` — CORRECT
- Line 62: `finalize_stripe_payment` — CORRECT
- Lines 64-71: `AiCreditBalanceTransaction.new(...)` — CORRECT (the `.save` is part of the condition on line 72, not inside lines 64-71, but the plan's manifest table handles this correctly as separate rows)
- Line 69: amount from `subscription_credits_per_period` — CORRECT (plan says line 70, actual is line 69; off by 1)
- Lines 74-78: notification flag reset — CORRECT
- Lines 82-90: `fail_with_record_invalid` private method — CORRECT

**`CancelAiCreditSubscription` manifest (A.6.1):**
- Line 28: `include Interactor` — CORRECT
- Line 31: `purchase = context.purchase` — CORRECT (plan correctly flags naming violation)
- Line 33: Stripe call — CORRECT
- Lines 35-42: local state update with return value check — CORRECT
- Lines 45-52: rescue pattern — CORRECT

**Styled component patterns:**
- `CancelAiCreditSubscriptionConfirmModal.tsx` line 50: `const Styled: any = {};` — CORRECT
- `PurchaseAiCreditTopUpConfirmModal.tsx` line 38: `const Styled: any = {};` — CORRECT
- Both analogs use `const`, plan correctly identifies this

**Cancel modal Button disabled prop:** Line 39: `<Button onClick={onConfirm} disabled={isLoading} dangerous>` — CORRECT

**Top-up modal no loading state:** Line 29: `<Button onClick={onConfirm}>Confirm purchase</Button>` — no `isLoading`, no `disabled`. CORRECT

**Button component props:** `index.js` lines 17-18: `disabled` and `loading` both exist as props — CORRECT

**Plan's Styled pattern choice:** Plan uses `let Styled: any; Styled = {};` per spec directive. The spec does mandate this pattern (spec section "Styled component pattern"). The analogs use `const Styled: any = {};`. This is a **noted spec-vs-analog deviation**, not a plan error. The implementation agent should follow the spec (and therefore the plan).

**Portal action line ranges (A.4):**
- A.4.1: "lines 229-281" for `change_subscription_portal_session` — comment block starts 229, def at 233, ends 281. Correct (includes comment).
- A.4.2: "lines 284-338" for `update_payment_method_and_subscription_portal_session` — comment at 283, def at 286, ends 338. Close (misses the first comment line at 283, but the def starts at 286).
- A.4.3: "lines 342-415" for `continue_change_subscription_portal_session` — comment at 340, def at 345, ends 415. Close (misses comment start at 340).

These line range approximations are acceptable — they identify the right code blocks.

## Summary

| Severity | Count |
|----------|-------|
| BLOCKER | 0 |
| HIGH | 0 |
| MED | 1 |
| LOW | 0 |
