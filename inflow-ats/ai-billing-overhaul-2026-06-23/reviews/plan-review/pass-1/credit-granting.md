# Angle 3: Credit Granting Correctness — Pass 1

## Verified Claims

### `ApplyAiCreditPurchase` analog structure (all line numbers verified)
- `include Interactor` at line 10 — **CORRECT**
- `def call` at line 12 — **CORRECT**
- Idempotency check at line 39 (`return if organization_ai_credit_purchase.stripe_invoice_id == invoice.id`) — **CORRECT**
- Balance lookup at line 41 — **CORRECT**
- Transaction block at line 53 — **CORRECT**
- Purchase update fields at lines 54-59 — **CORRECT**
- `finalize_stripe_payment` at line 62 — **CORRECT**
- `AiCreditBalanceTransaction` creation at lines 64-71 — **CORRECT** (note: `amount` is at line 69, plan says "line 70" in one place — off by one but harmless)
- Balance notification reset at lines 74-78 — **CORRECT**
- `fail_with_record_invalid` private method at lines 82-90 — **CORRECT**, confirmed local (not shared via concern)
- 91 lines total — **CORRECT** (file has 91 code lines + trailing newline)

### `ai_credit_allocation_for_lookup_key` class method
- Located at lines 71-76 of `organization_ai_credit_purchase.rb` — **CORRECT**
- Returns `pack[:credits] || pack[:credits_per_period]` — **CORRECT** (line 75)

### `finalize_stripe_payment` method
- Located at lines 156-158 of `organization_ai_credit_purchase.rb` — **CORRECT**
- Body: `update_columns(stripe_invoice_paid: true)` — **CORRECT**

### `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` constant
- Exists at lines 4-57 — **CORRECT**
- Contains both production and development lookup keys with `:credits` (one-off) and `:credits_per_period` (subscription) — **CORRECT**

### `AiCreditBalanceTransaction` model
- `entry_type: :subscription_credit_pack_purchase_credit` at value 30 — **CORRECT** (line 21)
- `bucket: :addon_subscription` at value 2 — **CORRECT** (line 39)
- `entry_type_and_amount_valid` validation — **CORRECT** (lines 62-72): checks credit entry types require positive amounts, debit entry types require negative amounts

### `CancelAiCreditSubscription` variable naming
- Line 31 uses `purchase = context.purchase` — **CORRECT**, violates naming rule as plan notes

### Real Stripe invoice structure
- Line 65: `"amount": -83727` — **CORRECT**
- `price.lookup_key` nested under `price` on line 132 — **CORRECT** (`"lookup_key": "plan_ats_tier_starter_v2_yearly"`)
- Structure confirmed: negative-amount line = old plan credit, positive-amount line = new plan charge — **CORRECT**

---

## Findings

### F1 — LOW: Stripe invoice JSON line number off by one for second line item

**Plan says:** "line item at JSON line 181 has `amount: 156777`" (step A.5.2)

**Actual:** The second line item's `"id"` is at line 180, and `"amount": 156777` is at line 182.

**Plan also says:** "JSON lines 132, 243: `price.lookup_key`"

**Actual:** First lookup_key is at line 132 (correct). Second lookup_key is at line 244 (plan says 243).

**Impact:** None. The implementation agent reads the actual JSON, not by line number. The structural claim (negative line = old, positive line = new, `price.lookup_key` nested under `price`) is correct.

**Severity:** LOW

### F2 — LOW: Structural manifest description string for analog is incorrect

**Plan says (structural manifest table, "Description" row):** Analog's description is `'Subscription credit pack purchase credit'`

**Actual (line 70):** `"Credit pack subscription grant for #{organization_ai_credit_purchase.stripe_price_lookup_key}"`

**Impact:** None. The new interactor's description is specified differently anyway (`"Upgrade credit grant: #{old_lookup_key} -> #{new_lookup_key} (+#{credit_difference} credits)"`), so the analog description is for reference only. But the manifest should be accurate.

**Severity:** LOW

---

## Verdict

0 BLOCKER, 0 HIGH, 0 MED, 2 LOW

All critical claims verified:
- The `ApplyAiCreditPurchase` analog is accurately described with correct line numbers
- The `ai_credit_allocation_for_lookup_key` method exists and works as claimed
- The `AiCreditBalanceTransaction` enums and validation exist as claimed
- The real Stripe invoice confirms the line item extraction pattern
- The `finalize_stripe_payment` method does what the plan says
- The `fail_with_record_invalid` is correctly identified as local (not shared)
- The variable naming violation in `CancelAiCreditSubscription` is correctly flagged
