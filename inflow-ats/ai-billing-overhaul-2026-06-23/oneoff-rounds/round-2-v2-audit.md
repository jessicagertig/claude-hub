# One-Off Purchase — Round 2 Audit (v2)

## Trace Summary

Files read in complete end-to-end trace:

**Trace spec:** `traces/oneoff-purchase-trace.md`

**Analog backend (WWR/WhatJobs paths):**
- `board_wwr_listing.rb` (model: direct-charge methods)
- `board_what_jobs_listing.rb` (model: direct-charge methods)
- `board_wwr_listings_controller.rb` (both paths: checkout-session creation + direct charge)
- `board_what_jobs_listings_controller.rb` (both paths: checkout-session creation + direct charge)
- `stripe_webhook_handler_job.rb` (both paths: `invoice.paid` webhook handling)

**Analog frontend (WWR path):**
- `JobDistributionWeWorkRemotely.tsx` (dual-endpoint branching + form state)
- `useWwrListing.ts` (endpoint selection logic)
- `useJob.ts` (endpoint selection logic)
- `api.ts` (endpoint definitions)

**Ours backend (current AI credit one-off):**
- `organization_ai_credit_purchase.rb` (model)
- `organization_ai_credit_purchases_controller.rb` (both paths: checkout-session creation + direct charge)
- `apply_ai_credit_purchase.rb` (interactor: webhook handling)
- `stripe_webhook_handler_job.rb` (webhook dispatch)

**Ours frontend (current AI credit one-off):**
- `AiCreditSubscription.tsx` (single-endpoint form)
- `useOrganizationAiCreditPurchase.ts` (hook: single endpoint)
- `AiCreditPackCard.tsx` (pricing UI)
- `PurchaseAiCreditTopUpConfirmModal.tsx` (confirm modal)

---

## Deviations from Analog Pattern

All deviations listed below. Whitelisted and sanctioned deviations are explicitly excluded from this list.

### 1. Direct-charge method naming

| Aspect | Analog | Ours | Severity |
|--------|--------|------|----------|
| **Method name** | `charge_for_listing` | `charge_default_payment_method` | MED |

**Analog:** `BoardWwrListing#charge_for_listing` (WWR); `BoardWhatJobsListing#charge_for_listing` (WhatJobs). Called at `board_wwr_listings_controller.rb:22` and `board_what_jobs_listings_controller.rb:163`.

**Ours:** `OrganizationAiCreditPurchase#charge_default_payment_method` (`organization_ai_credit_purchase.rb:124`), called at `organization_ai_credit_purchases_controller.rb:108`.

**Issue:** The analog follows `charge_for_<record>` naming. Ours names it `charge_default_payment_method`, which is a generic payment verb disconnected from the purchase record. This deviates from the analog's record-specific naming convention. (The `ai_credit_*` descriptor renames are sanctioned; this is a direct-charge method name outside that scope.)

---

### 2. Direct-charge action rescue clause (non-Stripe error handling)

| Aspect | Analog | Ours | Severity |
|--------|--------|------|----------|
| **Error rescue** | `StandardError` caught + rendered | `Stripe::StripeError` only | HIGH |

**Analog:** 
- WWR: `board_wwr_listings_controller.rb:28-31` wraps entire save+charge in `rescue StandardError => e -> render_general_errors(["Unable to process payment: #{e.message}"])`
- WhatJobs: `board_what_jobs_listings_controller.rb:167-178` rescues `WhatJobsApi::ValidationError`, then `Stripe::StripeError`, then `StandardError -> render_general_errors(["Unable to process payment: ..."])`

**Ours:** `organization_ai_credit_purchases_controller.rb:154-158` rescues only `Stripe::StripeError`, no `StandardError` rescue.

**Issue:** Non-Stripe errors raised inside `charge_default_payment_method` (e.g., database write failure on `update_columns`, `ActiveRecord` errors) escape unhandled instead of rendering a payment-failure error. The analog ensures all payment-path exceptions surface as a user-facing error message; ours allows non-Stripe exceptions to become unhandled 500 errors. This is a gap in error handling coverage.

---

### 3. Checkout-session creation ordering relative to record save

| Aspect | Analog | Ours | Severity |
|--------|--------|------|----------|
| **Post-session record update** | None | One `update` call after session create | MED |

**Analog:** Record is saved first (line inside `if @listing.save` block); Stripe session is created afterward using the saved record's id in metadata. The session id is NOT stored back onto the record; the webhook lookup relies solely on metadata.

**Ours:** Record is pre-created/saved (`organization_ai_credit_purchases_controller.rb:89-97`), then `Stripe::Checkout::Session.create` is called (`organization_ai_credit_purchases_controller.rb:140-147`), then a SECOND write performs `purchase.update(stripe_checkout_session_id: session.id)` (`organization_ai_credit_purchases_controller.rb:147`).

**Issue:** The analog avoids storing the session id on the record; the webhook looks up by `metadata['organization_ai_credit_purchase_id']`. Ours performs an extra write to attach `stripe_checkout_session_id` to the record. This is not a functional bug (the metadata-based lookup succeeds), but the analog demonstrates the session id as unnecessary to persist on the record, and ours introduces an extra write the analog pattern avoids.

---

### 4. `stripe_invoice_paid` not explicitly set at checkout-path record creation

| Aspect | Analog | Ours | Severity |
|--------|--------|------|----------|
| **Explicit field in build** | `stripe_invoice_paid: false` passed in create params | Relies on column default | MED |

**Analog:** 
- WWR: `board_wwr_listings_controller.rb:62` explicitly sets `stripe_invoice_paid: false` in build params
- WhatJobs: `board_what_jobs_listings_controller.rb:186` explicitly sets `stripe_invoice_paid: false` in build params

**Ours:** `organization_ai_credit_purchases_controller.rb:89-97` builds purchase without setting `stripe_invoice_paid`; relies on migration `20260611120002:5` column default (`default: false`). Final persisted state is identical.

**Issue:** The analog passes the field explicitly in create params; ours relies on the database column default. End result is the same, but the analog's explicit approach is clearer and less implicit than relying on column defaults.

---

### 5. Checkout success/cancel URL structure (no session id embedding)

| Aspect | Analog | Ours | Severity |
|--------|--------|------|----------|
| **URL structure** | Includes session id placeholder | Static flags only | MED |

**Analog:**
- `success_url`/`cancel_url` embed `&session_id={CHECKOUT_SESSION_ID}` (WWR `board_wwr_listings_controller.rb:116-117`; WhatJobs `board_what_jobs_listings_controller.rb:257-258`)
- Allows frontend to read the session id from the redirect URL and use it for post-redirect operations

**Ours:**
- `success_url`: `...?ai_credit_top_up_success=1` (static flag)
- `cancel_url`: `...?ai_credit_top_up_cancel=1` (static flag)
- No session id available to frontend after redirect (`organization_ai_credit_purchases_controller.rb:143-144`)

**Issue:** The analog embeds the session id in the redirect URL so the frontend can look it up without making an extra API call. Ours uses static flags and provides no way for the frontend to retrieve the session id from the post-redirect URL. This is a structural difference in post-redirect navigation. Functionally, if the redirect destinations don't need the session id, this may be benign — but the analog's inclusion suggests it could be useful.

---

### 6. Webhook success path method-call location (interactor vs. inline)

| Aspect | Analog | Ours | Severity |
|--------|--------|------|----------|
| **Finalize call location** | Inline in webhook handler | Inside `ApplyAiCreditPurchase` interactor | MED |

**Analog:** In `stripe_webhook_handler_job.rb`, the `invoice.paid` path calls `listing.finalize_stripe_payment` directly on the found record:
- WWR: `stripe_webhook_handler_job.rb:231-232`
- WhatJobs: `stripe_webhook_handler_job.rb:243-251`

**Ours:** The `invoice.paid` `ai_credit_pack_top_up` branch (`stripe_webhook_handler_job.rb:213-220`) delegates to `ApplyAiCreditPurchase.call(...)`, and `finalize_stripe_payment` is invoked inside the interactor (`apply_ai_credit_purchase.rb:73`).

**Issue:** The analog calls `finalize_stripe_payment` directly from the webhook handler (single call site, easy to trace); ours nests it inside an interactor. This is a placement difference, not a behavioral gap — the code executes the same steps — but the analog pattern is more transparent (webhook handler is the choke point that coordinates the entire payment finalization).

---

### 7. Frontend endpoint branching (dual endpoints vs. single endpoint with controller branching)

| Aspect | Analog | Ours | Severity |
|--------|--------|------|----------|
| **Endpoint selection** | Frontend decides → calls `createBoardWwrListing` OR `createCheckoutSession` | Frontend calls single `purchase_top_up` endpoint; controller branches internally | MED |

**Analog:** 
- `JobDistributionWeWorkRemotely.tsx:247-257` checks `hasPaymentMethod` and calls:
  - `createBoardWwrListing` (POST `/board_wwr_listings`, direct charge) if card on file
  - `createCheckoutSession` (POST `/board_wwr_listings/create_checkout_session`) if no card
- `useWwrListing.ts:7-24` and `useJob.ts:91-99` implement the two-endpoint logic
- Decision logic lives on the frontend

**Ours:**
- Frontend always calls single endpoint `purchase_top_up` (POST `/organization_ai_credit_purchases`) (`useOrganizationAiCreditPurchase.ts:97-102`)
- Controller branches internally on `stripe_default_payment_method_on_file` (`organization_ai_credit_purchases_controller.rb:104`)
- Decision logic moved to the controller

**Issue:** The analog's design places the branch decision on the frontend (two distinct API calls with different contract shapes); ours collapses to a single endpoint with internal branching. This is a structural divergence from the analog's two-endpoint architecture. Both approaches work, but they distribute responsibility differently — the analog keeps the contract separation explicit and visible to the API consumer.

---

### 8. Frontend direct-charge onSuccess return-shape handling

| Aspect | Analog | Ours | Severity |
|--------|--------|------|----------|
| **Response inspection** | No field inspection; only form state cleared | Branches on `data.url` and `data.charged` | LOW |

**Analog:** 
- Direct-charge (card on file) `onSuccess` handler (`JobDistributionWeWorkRemotely.tsx:269-272`) receives the serialized listing but performs NO redirect and NO branch on response fields
- Only clears local form state

**Ours:**
- Single `purchaseTopUp` `onSuccess` handler (`AiCreditSubscription.tsx:161-165`) branches on `data.url` to potentially redirect
- On the card-on-file path, controller returns a serialized purchase (`render_one`), so `data.url` is `undefined` and the branch is a no-op
- Functionally matches the analog (no redirect on direct charge), but reads response fields the analog never inspects

**Issue:** Ours defensively reads `data.url` and `data.charged` fields that the direct-charge response doesn't provide. The fields are unused (no-op branch), but the code structure suggests they might be used, creating potential confusion. The analog's approach is clearer: direct charge has no redirect logic.

---

### 9. Frontend buy button missing `disabled` prop

| Aspect | Analog | Ours | Severity |
|--------|--------|------|----------|
| **Button props** | `disabled={isMissingRequirements() \|\| isLoadingSomething \|\| isPurchasing}` and `loading={isLoadingSomething \|\| isPurchasing}` | Only `loading={isLoading}` | MED |

**Analog:** 
- `JobDistributionWeWorkRemotely.tsx:477-481` passes BOTH `disabled` and `loading`:
  ```tsx
  disabled={isMissingRequirements() || isLoadingSomething || isPurchasing}
  loading={isLoadingSomething || isPurchasing}
  ```

**Ours:**
- `AiCreditPackCard.tsx:36` passes only `loading={isLoading}`, no `disabled` prop
- `isPurchasing` is threaded as `isLoading` (`AiCreditSubscription.tsx:272`) but only to the `loading` prop

**Issue:** Per known failure pattern #11 (analog behavioral props must be copied), both `disabled` and `loading` should be passed. The button is not disabled during an in-flight purchase. A user could click multiple times and queue duplicate requests. The analog prevents this with the `disabled` guard.

---

## Whitelisted Deviations (Explicitly Excluded)

The following deviations are known to be WHITELISTED per project memory and are excluded from the findings above:

1. **WHITELIST #1:** `charge_default_payment_method` double-charge guard second predicate — ours uses `stripe_invoice_paid?` vs. analog's `is_active?`/`live?`. Whitelisted difference between org records (ours, non-subscription mode) and listing records (analog, subscription-based).

2. **WHITELIST #2:** Subscription/billing-portal `redirectUrl` responses at controller lines 60, 198, 253. Whitelisted as phase-2 (out-of-scope for one-off purchase).

---

## Sanctioned Deviations (Explicitly Excluded)

The following deviations flow from sanctioned design differences and are excluded from the findings:

1. **Confirm modal:** `PurchaseAiCreditTopUpConfirmModal` (`AiCreditSubscription.tsx:186-196`, `PurchaseAiCreditTopUpConfirmModal.tsx`) — sanctioned per spec.

2. **Record source:** `OrganizationAiCreditPurchase` as the payment-mode-agnostic record (vs. analog's listing-specific record). This is the sanctioned structural choice enabling both subscription and one-off modes from a single model.

3. **Naming descriptors:** `ai_credit_*` lookup-key/method/constant naming conventions flowing from the record-source choice.

4. **Price model:** `price: price.id` usage (InvoiceItem `organization_ai_credit_purchase.rb:139`; checkout line_items `organization_ai_credit_purchases_controller.rb:116`) replacing analog's `amount:`/`price_data.unit_amount:` — sanctioned flow from using `Stripe::Price` catalog records instead of inline price data.

---

## Context: Working Tree Review

**Uncommitted changes detected.** The billing-bonanza worktree has staged and unstaged modifications on all key files:

- `organization_ai_credit_purchases_controller.rb` (MM)
- `apply_ai_credit_purchase.rb` (MM)
- `organization_ai_credit_purchase.rb` (MM)
- `stripe_webhook_handler_job.rb` (MM)
- `AiCreditSubscription.tsx` (MM)
- `useOrganizationAiCreditPurchase.ts` (MM)
- `AiCreditPackCard.tsx` (MM)
- `app/jobs/notification/paid_ai_credit_pack_purchased_job.rb` (untracked)

Per known failure pattern #15, this audit reviews the WORKING TREE on disk, not a committed diff. If you intend to merge, commit first and re-verify the committed code matches this audit.

---

## Summary

**9 deviations identified:**
- **HIGH:** 1 (error rescue clause)
- **MED:** 7 (method naming, ordering, session ID embedding, inline vs. interactor, endpoint branching, response inspection, button props)
- **LOW:** 1 (response field inspection)

**Severity spike notes:**
- The HIGH finding (#2) is a genuine gap in error handling that could surface unhandled exceptions as 500 errors.
- The MED findings (#3, #5, #7) are structural divergences that work but deviate from the analog's architecture.
- The MED finding (#9) is a behavioral gap (missing `disabled` prop) that matches known failure pattern #11.

---

**Files read in trace:** See "Trace Summary" section above. Full trace doc at `traces/oneoff-purchase-trace.md`.

**Date:** 2026-06-24  
**Branch:** billing-bonanza
