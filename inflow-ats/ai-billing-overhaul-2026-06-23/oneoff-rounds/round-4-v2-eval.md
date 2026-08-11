# One-Off Purchase — Round 4 Eval (v2)

Count: 6
Previous: 19
Consecutive same: 0

## Findings

### 1. Direct-charge double-charge guard split across two return lines

**File:** `organization_ai_credit_purchase.rb`  
**Lines:** 133-134  
**Analog:** `board_wwr_listing.rb:115` / `board_what_jobs_listing.rb:160`

The guard checking for an existing completed charge is split across two separate return statements instead of one compound guard. This is inconsistent with the analog pattern.

**Current (ours):**
```ruby
return if completed_at.present?
return if charge_already_recorded?
```

**Analog pattern:**
```ruby
return if completed_at.present? || charge_already_recorded?
```

---

### 2. Webhook one-off branch performs finalize then business call sequentially vs once

**File:** `stripe_webhook_handler_job.rb`  
**Lines:** 223-224  
**Analog:** `oneoff-purchase-trace.md:165-166` (WWR handler)

The one-off purchase webhook handler calls `finalize_stripe_payment` in the webhook handler, then `ApplyAiCreditPurchase` which likely processes the payment again. The analog finalizes once and then executes the business call once as a unit.

**Current (ours):**
```ruby
# Line 223-224 context — performing finalize in handler then business call after
finalize_stripe_payment(...)
ApplyAiCreditPurchase.call(...)
```

**Analog pattern:**  
WWR handler finalizes payment once, then calls the business interactor without re-finalizing.

---

### 3. No broadcast_event WebSocket signal in one-off completion path

**File:** `organization_ai_credit_purchase.rb`  
**Lines:** 175-178  
**Analog:** `board_wwr_listing.rb:192` / `stripe_webhook_handler_job.rb:258`

The one-off purchase completion path does not broadcast a WebSocket event to notify connected clients of the state change. The analog patterns include `broadcast_event` calls for completion states.

---

### 4. charge_for_purchase takes amount as parameter resolved by controller

**File:** `organization_ai_credit_purchase.rb`  
**Line:** 131  
**Analog:** `board_wwr_listing.rb:113` / `board_what_jobs_listing.rb:157`

The `charge_for_purchase` method signature takes `amount_cents` as a parameter resolved by the controller, vs the analog where the model method resolves its own amount internally based on the record state.

**Current (ours):**
```ruby
def charge_for_purchase(amount_cents)
  # amount passed in
end
```

**Analog pattern:**  
Model method determines amount from its own state, not from caller.

---

### 5. Checkout-session path does not stamp stripe_checkout_session_id back onto purchase record

**File:** `organization_ai_credit_purchases_controller.rb`  
**Lines:** 147-190  
**Analog:** WWR/WhatJobs `#create_checkout_session` pattern

The checkout-session creation path does not write the `stripe_checkout_session_id` back to the purchase record for later webhook reference. The analog pattern stamps this ID for webhook matching.

---

### 6. Direct-charge update_columns does not write currency

**File:** `organization_ai_credit_purchase.rb`  
**Line:** 159  
**Analog:** `board_wwr_listing.rb:158` / `board_what_jobs_listing.rb:193`

The direct-charge completion path updates `amount_cents_paid` and `completed_at` but does not write `currency` to the record. The analog patterns include currency in the update.

**Current (ours):**
```ruby
update_columns(
  amount_cents_paid: amount_cents,
  completed_at: Time.current
)
```

**Analog pattern:**
```ruby
update_columns(
  amount_cents_paid: amount_cents,
  currency: currency,
  completed_at: Time.current
)
```
