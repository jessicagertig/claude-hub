# FAILURE REPORT — Implementation Review Round 5

**Status:** FAIL
**Date:** 2026-06-05
**Branch:** `feature-ai-credits-summaries-scoring-qa`

---

## Executive Summary

The spec-specified changes are correctly implemented. The failure is caused by **~200 lines of out-of-spec code** added by a fix agent to the Stripe webhook handler and the `ApplyAiCreditPurchase` interactor. This code was never specified, was not reviewed during prior rounds, and introduces scope creep that the user explicitly flagged.

---

## Blocking Findings (9 HIGH)

### 1. `apply_one_off_from_invoice` is unnecessary scope creep

**File:** `app/interactors/apply_ai_credit_purchase.rb:84-130`

The spec says the `invoice.paid` top-up branch should "grant one-off credits using the `organization_id` and `stripe_price_lookup_key` from the invoice metadata." The existing `apply_one_off(session)` method already does this work. The fix agent created a 46-line parallel method that duplicates ~80% of `apply_one_off`.

The user's observation is correct: the `board_wwr_listing_id` and `board_what_jobs_listing_id` branches process one-off `invoice.paid` events inline in 8-12 lines each, with no interactor method. The credit pack top-up could follow the same pattern.

**Fix:** Either (a) process inline in the webhook handler like listings, or (b) parameterize `apply_one_off` to accept either session or invoice data, eliminating the duplicate method.

### 2. `stripe_checkout_session_id` validation change is out of spec

**File:** `app/models/organization_ai_credit_purchase.rb:53`

Changed from unconditional `presence: true` (for one-offs) to `presence: true, if: -> { one_off? && stripe_invoice_id.blank? }`. This was introduced solely to support `apply_one_off_from_invoice`. The spec's validation relaxation section (Note #9B-5) covers ONLY subscription records.

**Fix:** Revert to `validates :stripe_checkout_session_id, presence: true, if: :one_off?` (the original per-spec validation).

### 3-5. Three new webhook event handlers not in spec

**Files:** `app/jobs/stripe_webhook_handler_job.rb`

- `charge.refunded` handler + `handle_charge_refunded` (lines 285-289, 424-455)
- `customer.subscription.updated` AI credit branch (lines 114-136)
- `customer.subscription.deleted` AI credit branch (lines 155-168)

These are 66 lines of new webhook routing that were never specified. While they may be needed for a complete credit system, they were not part of this spec.

**Fix:** Remove entirely. If these features are needed, they should go through the spec/plan/review cycle.

### 6-7. `handle_credit_pack_invoice_paid` and `subscription_status_for_stripe` rewritten

**Files:** `app/jobs/stripe_webhook_handler_job.rb:456-527`

The spec says to modify the existing `handle_credit_pack_invoice_paid` (add `amount_cents_paid`/`currency`, remove `else` branch). Instead, the fix agent wrote a 59-line method from scratch with additional idempotency logic, transaction wrapping, and error handling. Plus a new 11-line `subscription_status_for_stripe` helper.

**Fix:** Write the method as specified: find existing purchase, update with `amount_cents_paid` and `currency`, create renewal ledger row. Remove the `else` branch. Remove `subscription_status_for_stripe`.

### 8-9. Code duplication across interactor and webhook handler

`apply_one_off_from_invoice` duplicates `apply_one_off`. `handle_credit_pack_invoice_paid` duplicates `apply_subscription` logic. Both create ledger rows, reset notification flags, and do org lookups in parallel code paths.

**Fix:** Consolidate to single code paths as described above.

---

## Non-blocking MED Findings (13 total)

See `verdict.md` for the complete list. Key items:
- New migration `20260605035312` should be deleted
- `amount_cents_paid: 0` hardcoded at checkout (should be nil per validation design)
- Missing `exact={false}` on Plato AI route
- Stale docstring in interactor
- Plato AI tab behind feature flipper (not in spec, but likely intentional)

---

## What passes

All spec-specified changes are correctly implemented:
- Enum renames cascade with zero stale references
- Controller restructuring and route alignment correct
- Hook consolidation and response shape change correct
- Mailer bug fixes correct
- Bulk job notifications with proper .deliver_later
- Plato AI container matches analog
- All model/service cleanups verified
- Test coverage adequate for spec requirements
