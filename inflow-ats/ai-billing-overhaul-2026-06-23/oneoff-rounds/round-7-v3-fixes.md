# One-Off Purchase — Round 7 Fixes (v3)

The one-off branch (lines 215-231) now mirrors the WWR analog branch (lines 237-244) and the WhatJobs analog branch (lines 250-262) iota-for-iota at the structural level: `.find(id)` followed by the redundant `if X&.present?` guard, finalize-in-handler, produce-the-product call, `return`.

The fix is complete. No frontend change is required — the deviation was purely the backend record-lookup method, and it does not change any response key or contract (the webhook handler returns nothing to the frontend; it's a Stripe-driven job).

---

## Summary of changes made

### DEVIATION FIXED — Webhook one-off record lookup method

File: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/jobs/stripe_webhook_handler_job.rb` line 216

Changed the one-off `invoice.paid` branch's record lookup from `find_by(id:)` (returns nil on a missing id) to `.find` (raises `ActiveRecord::RecordNotFound` on a missing id), matching both analog branches in the same handler:
- `BoardWwrListing.find(listing_id)` (line 238)
- `BoardWhatJobsListing.find(listing_id)` (line 251)

Before:
```ruby
purchase = OrganizationAiCreditPurchase.find_by(id: purchase_id)
```

After:
```ruby
purchase = OrganizationAiCreditPurchase.find(purchase_id)
```

The surrounding `if purchase&.present?` guard (line 218) was left intact — both analog branches keep their own redundant `if listing&.present?` guard after `.find`, so preserving it is what matches the analog structure exactly.

### Frontend

No change required. This deviation is entirely server-side inside a Stripe-driven background job; it changes no response key, no controller contract, and nothing the frontend consumes. The findings note independently confirmed "No frontend-only deviation found beyond the whitelisted invalidation target."

### Safety check performed

Grepped `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` for any test asserting the old nil-return behavior (missing/unknown/nonexistent purchase id, RecordNotFound, `find_by`). Zero matches — no spec relies on the graceful-nil path, so switching to the raising `.find` breaks no existing test.

---

## Whitelist items

Carried over from the findings, confirmed by independent trace — these are sanctioned/structural and cannot be made identical to the analog on our record type:

- **Price model** `Stripe::Price.list` + `line_items: [{ price: price.id }]` (vs analog inline `price_data`/`amount`): OURS' price lives in Stripe resolved by `stripe_price_lookup_key`; the analog hardcodes amounts in the model. This is the sanctioned price-model divergence.
- **Frontend invalidation** `useChargeAiCreditTopUp` onSuccess invalidates `["organizationAiCreditBalance"]` (vs analog's `["jobs", data.id]`): OURS is org-scoped credits, not job-scoped listings; there is no job key to invalidate.
- **Confirm modal** `PurchaseAiCreditTopUpConfirmModal` confirm modal on the direct-charge path: the sanctioned EXTRA (clean Confirm/Cancel), per the project's recorded list of acceptable AI-credit divergences.

I did not whitelist anything for being hard to match. The one genuine, matchable deviation was fixed.
