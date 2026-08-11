# Angle 3: Credit Granting Correctness — Round 1

## Checks performed

1. Verified `ApplyAiCreditUpgrade` line item extraction against real invoice structure
2. Verified `ai_credit_allocation_for_lookup_key` exists and works as described
3. Verified idempotency mechanism (`stripe_invoice_id == invoice.id`)
4. Verified entry_type/bucket values against model enums
5. Verified `entry_type_and_amount_valid` validation compatibility
6. Verified `finalize_stripe_payment` method exists and behavior
7. Checked for `fail_with_record_invalid` availability
8. Verified that `customer.subscription.updated` handler does NOT grant credits (constraint C1)

## Findings

### C1: `fail_with_record_invalid` is private to `ApplyAiCreditPurchase` — not available to `ApplyAiCreditUpgrade` — HIGH

**Location:** SPEC.md lines 316, 328 (calls to `fail_with_record_invalid` in `ApplyAiCreditUpgrade`)

**Problem:** The spec's `ApplyAiCreditUpgrade` code calls `fail_with_record_invalid` three times (lines 316, 328, and implicitly at line 334 via the pattern). This method is defined as a PRIVATE method inside `ApplyAiCreditPurchase` (lines 82-90 of that file). It is NOT on the `Interactor` module, NOT a shared concern, and NOT available to any other interactor.

The implementation will fail with `NoMethodError` at runtime when any save/update fails in `ApplyAiCreditUpgrade`.

**Code from `ApplyAiCreditPurchase` (lines 82-90):**
```ruby
private

def fail_with_record_invalid(label, errors)
  Rails.logger.error "ApplyAiCreditPurchase #{label} failed: #{errors.full_messages.join(', ')}"
  ap errors
  context.fail!(error: :record_invalid, message: "#{label}: #{errors.full_messages.join(', ')}")
end
```

**Fix:** The spec must state that `ApplyAiCreditUpgrade` defines its own `fail_with_record_invalid` private method (copying the pattern from `ApplyAiCreditPurchase`, with the class name in the log message updated to `ApplyAiCreditUpgrade`). Alternatively, extract a shared concern — but that would modify `ApplyAiCreditPurchase`, which the spec says is "Not modified."

**Recommended approach:** Define the method locally in `ApplyAiCreditUpgrade` (same pattern as the analog, with updated log prefix). This is the minimum change.

## Verdict

1 HIGH finding (C1). Requires spec amendment.
