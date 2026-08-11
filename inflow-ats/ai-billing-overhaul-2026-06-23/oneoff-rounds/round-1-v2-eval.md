# One-Off Purchase — Round 1 Eval (v2)

Count: 4
Previous: -1
Consecutive same: 0

## F1: Double-charge guard semantic mismatch

**File:** `app/models/organization_ai_credit_purchase.rb`

**Finding:** Second predicate of double-charge guard uses `stripe_invoice_paid?` (payment-flag check) where analog uses `is_active?`/`live?` (temporal state check). Different semantic for the same guard position.

**Analog:**
- `app/models/board_wwr_listing.rb:115` (def at :54)
- `board_what_jobs_listing.rb:160` (def at :80)

**Ours:**
- `app/models/organization_ai_credit_purchase.rb:125`

---

## F2: last_updated_by_organization_user column unused

**File:** `app/models/organization_ai_credit_purchase.rb`

**Finding:** Migration adds `last_updated_by_organization_user` column, but model declares no `belongs_to` association, controller never sets it on create, and post-payment growl targets `organization.owner` instead of that user. Column is permanently null/unused.

Analog stamps this field at creation and broadcasts the growl to `last_updated_by_organization_user.user`.

**Analog:**
- `app/controllers/api/v1/board_wwr_listings_controller.rb:11` (checkout :59)
- `app/models/board_wwr_listing.rb:6`, `:271-273` (from create_on_wwr :194)

**Ours:**
- `app/models/organization_ai_credit_purchase.rb:78-79`
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:89-96`
- `app/interactors/apply_ai_credit_purchase.rb:94-98`

---

## F3: Checkout-session response wire key mismatch

**File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`

**Finding:** Checkout-session response uses `redirectUrl` key (read by frontend as `data.redirectUrl`) where analog uses `url` (read as `data.url`). Contract is internally consistent but wire key differs from analog.

**Analog:**
- `app/controllers/api/v1/board_wwr_listings_controller.rb:120` (WhatJobs :261)
- `JobDistributionWeWorkRemotely.tsx:339`

**Ours:**
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:152`
- `AiCreditSubscription.tsx:162`

---

## F4: Direct-charge success messaging: double toast

**File:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`

**Finding:** Direct-charge (card-on-file) success path fires an immediate `addToast` in addition to the later webhook growl (two messages total). Analog's direct-charge `onSuccess` shows no toast (only `setErrors`/`setIsDirty`) and emits only the later WebSocket growl (one message).

**Analog:**
- `app/javascript/ats/src/views/jobApplications/jobDistribution/JobDistributionWeWorkRemotely.tsx:269-272` (errors-only addToast at 285/319/350)
- `board_wwr_listing.rb:194`

**Ours:**
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:165-168`
- `apply_ai_credit_purchase.rb:94-98`
