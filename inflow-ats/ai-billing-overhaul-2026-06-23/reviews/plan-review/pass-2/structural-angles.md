# Pass 2: Angles 7-8 + CLAUDE.md Compliance

## 1. Correction verification

### Angle 8 corrections: VERIFIED
- A.2.2 step 8: `render_general_errors(['Unable to load subscription preview. Please try again.'])` — array ✓
- A.3.1 step 6: `render_general_errors([result.message || 'Unable to schedule plan change.'])` — array ✓
- A.3.1 step 8: `['Unable to change subscription. Please try again.']` — array ✓
- Sentry extra hash: `org_id: current_organization&.id, action: '...'` — matches cancel analog ✓

### Angle 7 correction: VERIFIED
- Pattern Precedents line 196: `subscription = current_organization...` with naming warning — correct ✓

## 2. Fresh scrutiny findings

### HIGH-P2-1: `raise StandardError` guards will return 500 — no rescue catches them

**Location:** Plan A.2.2 step 3, A.3.1 step 2 (which references A.2.2 step 3)

**Problem:** The plan uses `raise StandardError` guards for missing customer/subscription/subscription_id:
```ruby
raise StandardError, 'Stripe customer ID missing.' unless current_organization.stripe_customer_id.present?
raise StandardError, 'No active AI credit subscription found.' unless organization_ai_credit_purchase
raise StandardError, 'Subscription ID missing.' unless organization_ai_credit_purchase.stripe_subscription_id.present?
```

The method-level rescue only catches `Stripe::StripeError`. There is NO global `rescue_from StandardError` in `ApplicationController` (line 21 is commented out). The `StandardError` will bubble up unrescued and return a raw 500 error to the frontend.

**Why the portal actions worked:** `change_subscription_portal_session` (lines 268-281) has an explicit `rescue StandardError => e` block after `Stripe::InvalidRequestError`. The cancel action avoids this by NOT raising — it uses `render_general_errors + return` instead.

**Two valid fixes (pick one — must match throughout):**

Option A (match cancel pattern): Replace `raise StandardError` guards with `render_general_errors(['...']) and return`:
```ruby
unless current_organization.stripe_customer_id.present?
  render_general_errors(['Stripe customer ID missing.'])
  return
end
```

Option B (match portal pattern): Add `rescue StandardError => e` to the method:
```ruby
rescue Stripe::StripeError => e
  # ... existing Stripe error handling ...
rescue StandardError => e
  Rails.logger.error "Error in organization_ai_credit_purchases#preview_subscription_change: #{e.message}"
  render_general_errors([e.message])
```

**Impact:** Without this fix, the three most common error paths (no Stripe customer, no active subscription, no subscription ID) will return opaque 500 errors instead of user-facing messages.

**Severity:** HIGH

### No other findings

**3a. Controller multi-rescue pattern:**
The cancel action (lines 209-214) uses only `rescue Stripe::StripeError => e`. The portal actions use multi-rescue. The plan correctly says "matching `cancel` action pattern" for the new rescue. However, the cancel action does NOT raise `StandardError` — it uses `render_general_errors + return`. The plan mixes the portal actions' guard style (`raise StandardError`) with the cancel action's rescue style (`rescue Stripe::StripeError` only), which is the root of HIGH-P2-1 above.

**3b. Interactor `context.fail!` return flow:**
`context.fail!` does NOT raise an exception — it sets the context as failed and the interactor's `call` method returns normally. The controller then checks `result.success?`. The plan's A.3.1 step 6 (`unless result.success?`) matches the cancel action pattern (lines 204-208) exactly. PASS.

For the downgrade path specifically: the interactor's internal `rescue Stripe::StripeError` catches the error first (before the controller's method-level rescue can), calls `context.fail!`, and returns. The controller then sees `result.success? == false` and renders the error via `render_general_errors`. This is correct.

**3c. Sentry extra hash consistency:**
A.3.1 step 8 says "Same method-level rescue as preview action (A.2.2 step 8)." This is sufficiently clear that the implementation agent should use the same Sentry shape with a different `:action` value. PASS.

**4a. Pundit authorization:**
`Pundit::NotAuthorizedError` is handled globally by `rescue_from` at `ApplicationController` line 10, which calls `user_not_authorized` (line 15), rendering `{ errors: [...] }` with status 403. The plan's actions don't need to rescue Pundit errors. PASS.

**4b. `StandardError` guards:**
This IS the HIGH finding above. No global handler exists.

## 3. CLAUDE.md compliance fresh check

### Variable naming: PASS
All code snippets use `organization_ai_credit_purchase`, `ai_credit_balance_transaction`, `organization_ai_credit_balance`. The cancel analog's `subscription` and `purchase` violations are called out with explicit "do NOT copy" warnings.

### Single quotes in Ruby: PASS
All string literals in amended code use single quotes (e.g., `'Unable to load subscription preview. Please try again.'`). Interpolated strings use double quotes correctly.

### No fabricated fallbacks: PASS
The `|| 'Unable to schedule plan change.'` in the downgrade error path (A.3.1 step 6) is a fallback error message, not data fabrication. This matches the cancel action analog (line 207: `|| 'Failed to cancel subscription'`).

### No begin blocks: PASS
All controller code uses method-level rescue.

### No bang methods: PASS
No `save!`, `update!`, `create!` in non-spec code.

### Return value checks: PASS
All `.save` and `.update` calls check return values via `fail_with_record_invalid` or conditionals.

## Summary

| Severity | Count | Finding |
|----------|-------|---------|
| BLOCKER  | 0     | — |
| HIGH     | 1     | HIGH-P2-1: `raise StandardError` guards unrescued, returns 500 |
| MED      | 0     | — |
| LOW      | 0     | — |
