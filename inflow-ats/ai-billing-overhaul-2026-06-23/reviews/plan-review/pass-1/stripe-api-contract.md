# Angle 1: Stripe API Contract — Pass 1 Findings

## Verified claims

1. **`cancel` action location:** lines 193-214 ✅
2. **`change_subscription_portal_session` location:** lines 233-281 ✅
3. **`update_payment_method_and_subscription_portal_session` location:** lines 286-338 (def), comments start at 283 ✅
4. **`continue_change_subscription_portal_session` location:** lines 345-415 (def), comments start at 340 ✅
5. **`determine_price_id` location:** lines 448-454, reads `params[:price_id]` via `params.key?(:price_id)` ✅
6. **`change_subscription?` in `BillingPolicy`:** line 24, requires `is_org_admin?` ✅
7. **Purchase lookup query:** matches exactly across portal actions ✅
8. **Guard pattern:** portal actions use `raise StandardError` with descriptive messages ✅
9. **Multi-rescue pattern:** `Pundit::NotAuthorizedError`, `Stripe::InvalidRequestError`, `StandardError` — confirmed in `change_subscription_portal_session` (lines 268-281) and `update_payment_method_and_subscription_portal_session` (lines 326-338) ✅
10. **`customer_subscription` action:** lines 422-437 ✅
11. **Preview and commit param matching:** inner params (`items`, `proration_behavior`, `proration_date`) are identical between preview (A.2.2 step 5) and commit (A.3.1 step 5). Only the `subscription_details:` wrapper differs, which is the expected Stripe API difference between `Invoice.create_preview` and `Subscription.update` ✅

## Findings

### M1 (MED): Pattern precedents section claims `cancel` action uses `organization_ai_credit_purchase` variable — it actually uses `subscription`

**Location:** Plan section "Pattern precedents", line 20

**Claim:** "Line 196: organization_ai_credit_purchase = current_organization.organization_ai_credit_purchases.subscription.find_by(...)"

**Actual:** Line 196 reads: `subscription = current_organization.organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])`

The variable name in the `cancel` action is `subscription`, not `organization_ai_credit_purchase`. The plan misrepresents what the analog does. This doesn't affect the prescribed behavior for the new actions (which correctly mandate `organization_ai_credit_purchase` per naming rules), but an implementation agent reading the analog will see `subscription` and might be confused by the mismatch with the plan's description.

**Impact:** Implementation agent may be confused about which variable name the analog uses. The prescribed behavior is correct — only the documentary claim about the analog is wrong.

### L1 (LOW): Portal action removal line numbers slightly off (comment boundaries)

**Location:** Plan sections A.4.1, A.4.2, A.4.3

- A.4.1 says "lines 229-281" — first comment line is 228 (misses one comment line)
- A.4.2 says "lines 284-338" — first comment line is 283 (misses one comment line)  
- A.4.3 says "lines 342-415" — first comment line is 340 (misses two comment lines)

**Impact:** Negligible — the implementation agent will delete entire method blocks including comments. The `def` keywords are at the correct positions and the end lines are exact.

### L2 (LOW): Plan's proposed Sentry extra hash uses `organization_id` key; analog uses `org_id`

**Location:** Plan A.2.2 step 8

**Plan proposes:** `Sentry.capture_exception(e, extra: { organization_id: current_organization.id })`

**Analog (`cancel` line 212):** `Sentry.capture_exception(e, extra: { org_id: current_organization&.id, action: 'organization_ai_credit_purchases#cancel' })`

Two differences: (1) key is `org_id` not `organization_id`, (2) analog includes `:action` key, (3) analog uses safe navigation `current_organization&.id`. The new code should match the analog's shape.

**Impact:** Low — Sentry extra fields are informational only. But matching the analog's pattern is cleaner.

## Summary

| Severity | Count |
|----------|-------|
| BLOCKER | 0 |
| HIGH | 0 |
| MED | 1 |
| LOW | 2 |
