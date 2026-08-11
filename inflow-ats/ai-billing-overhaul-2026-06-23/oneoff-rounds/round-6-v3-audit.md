# One-Off Purchase — Round 6 Audit (v3)

## Overview

This audit documents the structural comparison between the current one-off direct-charge and checkout-session code and the primary analog (`BoardWwrListing` / We Work Remotely) and secondary analog (`BoardWhatJobsListing` / WhatJobs). The comparison traces the full pipelines from frontend through controller, model, webhook, and interactor (where applicable).

**Chain traced:**

- **ANALOG (WWR):** `JobDistributionWeWorkRemotely.tsx` → `useJob.ts` (createBoardWwrListing / useCreateBoardWwrListing) → `board_wwr_listings_controller.rb` (#create, #create_checkout_session) → `board_wwr_listing.rb` (charge_for_listing, finalize_stripe_payment, create_on_wwr, broadcast_event) → `stripe_webhook_handler_job.rb` (invoice.paid WWR branch)

- **ANALOG (WhatJobs):** `board_what_jobs_listings_controller.rb` + `board_what_jobs_listing.rb` + webhook WhatJobs branch (secondary — verifies patterns)

- **OURS:** `AiCreditSubscription.tsx` → `useOrganizationAiCreditPurchase.ts` → `organization_ai_credit_purchases_controller.rb` (#charge_top_up, #create_top_up_checkout_session) → `organization_ai_credit_purchase.rb` (charge_for_purchase, finalize_stripe_payment, broadcast_purchase_complete) → `stripe_webhook_handler_job.rb` (invoice.paid one-off branch) → `apply_ai_credit_purchase.rb` (#apply_one_off)

---

## WHITELISTED Deviations

The following deviations from the analog are explicitly sanctioned by architecture and were reviewed/approved during spec work:

1. **Price in Stripe (not local):** AI credit prices exist only in Stripe; resolved by lookup key. Checkout session uses `price: price.id` instead of inline `price_data: { unit_amount: ... }`. Direct-charge resolves `Stripe::Price.list` in model. ✓ Approved.

2. **No job dimension:** AI credit purchases belong to `Organization`, not `Job`. All job-keyed metadata/channels/flows are replaced with org-scoped equivalents (no `job_id` in metadata, `GlobalChannel` instead of `JobChannel`, purchase id instead of listing id). ✓ Approved.

3. **Credit grant via interactor:** Instead of calling `create_on_wwr` (model method) directly in webhook, credit granting is delegated to `ApplyAiCreditPurchase` interactor with its own `apply_one_off` method. The interactor applies the credit with guard (`grant_once_guard`) and triggers completion signaling. ✓ Approved (sanctioned credit-grant unit).

4. **Query invalidation target:** Direct-charge frontend invalidates `["organizationAiCreditBalance"]` (the org's singleton balance) instead of `["jobs", data.id]` (job-keyed listing). ✓ Approved (domain read model divergence).

5. **Confirmation modal on direct-charge:** `PurchaseAiCreditTopUpConfirmModal` is an EXTRA interposed before the direct-charge action with no analog equivalent. ✓ Approved (UX requirement, whitelisted).

---

## Confirmed Matches (Trace Corrections)

The following were described incorrectly in the OURS section of the trace and have been verified as matching the analog after review of current code:

1. **Checkout-session return shape (`{ url, sessionId }`):** Currently matches the analog exactly. No `redirectUrl` confusion.

2. **Frontend checkout handler:** Correctly calls `window.location.href = data.url`, matching the analog.

3. **Frontend direct-charge handler:** No success toast; no response inspection. Matches the analog's silent-on-success pattern.

4. **Frontend branch decision:** Branches on `stripeDefaultPaymentMethodOnFile` at the frontend, calling two separate mutations/endpoints (`charge_top_up` vs `create_top_up_checkout_session`). Matches the analog's frontend-decides-which-endpoint structure.

5. **Checkout-session record:** Created with `stripe_invoice_paid: false` explicitly set, matching the analog. No `stripe_checkout_session_id` stamp on the record.

6. **Webhook resolution:** Webhook resolves `purchase = OrganizationAiCreditPurchase.find_by(id: purchase_id)` from metadata and passes the object to the interactor; no triple-fallback chain. Matches the analog's handler-resolves-then-acts pattern.

7. **InvoiceItem `amount:` field:** Currently uses `amount: amount` (resolves price to `unit_amount`), matching the analog's use of `amount:` not `price:`.

---

## ACTIONABLE Structural Deviations

These deviations are NOT whitelisted and represent genuine divergences from the analog pattern:

### 1. Double `Stripe::Price.list` in the direct-charge path

**Current code:**
- `charge_top_up` controller action resolves `Stripe::Price.list(lookup_keys: [lookup_key], ...)` (organization_ai_credit_purchases_controller.rb:77-87)
- Also calls `ai_credit_top_up_lookup_key?(lookup_key)` gate with no analog equivalent
- Builds and saves the record
- Calls `purchase.charge_for_purchase`

**`charge_for_purchase` model method:**
- Re-resolves `Stripe::Price.list(lookup_keys: [stripe_price_lookup_key], active: true, limit: 1)` (organization_ai_credit_purchase.rb:136-140)
- Uses `price.unit_amount` to set `amount`

**Analog pattern (WWR `#create`):**
- Controller does NO Stripe call
- Controller does NO price lookup or validity gate
- Controller builds and saves the listing
- Calls `@listing.charge_for_listing`, which has the ONLY `calculate_charge_amount` resolution

**Impact:** The controller-side `price` variable (lines 77-87 ours) is never consumed by the direct-charge path. It is only used by the checkout path (line 161, `line_items: [{ price: price.id, ... }]`). The direct-charge action pays the cost of the lookup but throws away the result and lets the model re-resolve it. Additionally, the `ai_credit_top_up_lookup_key?(lookup_key)` gate in the controller (line 81, ours) has no analog equivalent in WWR `#create` (validity is enforced only by the record's own `validates_presence_of :wwr_category`).

**Status:** Genuine divergence. Not forced by price-in-Stripe architecture (checkout path needs the price, but direct-charge path does not). Refactor candidate: remove the controller-side lookup for the direct-charge action, or refactor both paths to use a shared pre-validated price.

---

### 2. Extra `currency:` write in `charge_for_purchase`'s `update_columns`

**Current code:**
```ruby
update_columns(stripe_invoice_id: invoice.id, stripe_invoice_item_id: invoice_item.id, stripe_amount: amount, currency: paid_invoice.currency)
```
(organization_ai_credit_purchase.rb:165)

**Analog pattern (WWR `charge_for_listing`):**
```ruby
update_columns(stripe_invoice_id: invoice.id, stripe_invoice_item_id: invoice_item.id, stripe_amount: amount)
```
(board_wwr_listing.rb:158; board_what_jobs_listing.rb:193 identical)

**Impact:** The `currency:` column exists on `organization_ai_credit_purchases` (real schema column at line 610) and is conditionally validated (organization_ai_credit_purchase.rb:52-53, validates_presence_of when invoice_paid?), but the analog's `board_wwr_listings` and `board_what_jobs_listings` have no `currency` column at all. The `charge_for_purchase` method writes a value that the analog's equivalent method does not.

**Status:** Genuine extra write with no analog counterpart. Not forced by any architecture divergence — it's a simple addition that the analog never made. Remove or justify.

---

## Summary Table

| Aspect | Status | Notes |
|--------|--------|-------|
| Direct-charge create→charge lifecycle | ✓ Match | Build → authorize → save → charge → render |
| Direct-charge authorization | ✓ Match | Authorize record via `create?` policy |
| Checkout-session authorization | ✓ Match | `authorize :billing, :checkout?` |
| Direct-charge rescue pattern | ✓ Match | `rescue StandardError`, `render_general_errors(["Unable to process payment: ..."])` |
| Checkout-session rescue pattern | ✓ Match | `rescue Stripe::StripeError`, `render json: { error: ... }` |
| Invoice shape (direct-charge) | ✓ Match | `customer`, `collection_method: 'charge_automatically'`, description, record-id metadata |
| InvoiceItem shape | ✓ Match | `amount:` (not `price:`), description, record-id metadata |
| Webhook handler resolution | ✓ Match | Resolve record by metadata id, guard with nil check, early return if missing |
| Webhook finalize→credit→signal flow | ✓ Match | `finalize_stripe_payment` → interactor/business method → completion broadcast |
| Frontend direct-charge branch | ✓ Match | Calls `charge_top_up` endpoint, no toast on success |
| Frontend checkout branch | ✓ Match | Calls `create_top_up_checkout_session`, redirects to `data.url` |
| Frontend direct-charge `price` resolution | ✗ DEV-1 | Double lookup (controller + model); controller result discarded |
| Model direct-charge `update_columns` | ✗ DEV-2 | Extra `currency:` write with no analog counterpart |

---

## Files Reviewed

All file paths absolute under `/Users/jessica/wrk/wrk-corp/inflow-ats/`:

- `inflow-ats/.billing-bonanza/organization_ai_credit_purchases_controller.rb`
- `inflow-ats/.billing-bonanza/organization_ai_credit_purchase.rb`
- `inflow-ats/.billing-bonanza/apply_ai_credit_purchase.rb`
- `inflow-ats/.billing-bonanza/stripe_webhook_handler_job.rb` (one-off branch)
- `inflow-ats/app/javascript/components/AiCreditSubscription.tsx`
- `inflow-ats/app/javascript/hooks/useOrganizationAiCreditPurchase.ts`
- `inflow-ats/app/models/board_wwr_listing.rb` (primary analog)
- `inflow-ats/app/models/board_what_jobs_listing.rb` (secondary analog)
- `inflow-ats/app/controllers/board_wwr_listings_controller.rb` (primary analog)
- `inflow-ats/app/controllers/board_what_jobs_listings_controller.rb` (secondary analog)
- `inflow-ats/app/javascript/components/JobDistributionWeWorkRemotely.tsx` (primary analog)

---

## Recommendation

**DEV-1 (double price resolution)** and **DEV-2 (extra currency write)** are the only structurally unapproved deviations. Both are low-risk cleanups:

1. **DEV-1:** Refactor to eliminate duplicate `Stripe::Price.list` in the direct-charge action. Options: remove controller-side lookup for direct-charge (only checkout needs it), or extract to a shared helper that both paths use.

2. **DEV-2:** Remove `currency: paid_invoice.currency` from the `update_columns` call in `charge_for_purchase`, or add explicit justification and document why the one-off model needs currency stamping when the analogs do not.

Both should be fixed in the implementation phase before final review.
