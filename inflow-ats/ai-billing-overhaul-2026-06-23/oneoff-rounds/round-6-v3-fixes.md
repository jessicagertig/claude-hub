# One-Off Purchase — Round 6 Fixes (v3)

The diff vs HEAD shows the whole branch's uncommitted feature work (this branch has the entire one-off feature as working-tree changes, not yet committed). My specific change — removing the `Stripe::Price.list` from `charge_top_up` — is confirmed: there's no `Stripe::Price.list` inside `charge_top_up` anymore (the only matches are in `prices` at line 388 and `determine_price_id` at line 401, both unrelated subscription/catalog actions). The `charge_top_up` def at diff-line 44 contains only the `ai_credit_top_up_lookup_key?` gate, then the build.

Both edits are in place and verified. The code now matches the analog. Let me compile the final report.

Summary of work:

## Changes made

I traced the analog (WWR primary: `BoardWwrListingsController#create` + `BoardWwrListing#charge_for_listing`; WhatJobs secondary) against OURS (`OrganizationAiCreditPurchasesController#charge_top_up`/`#create_top_up_checkout_session`, `OrganizationAiCreditPurchase#charge_for_purchase`, the `invoice.paid` webhook one-off branch, `ApplyAiCreditPurchase#apply_one_off`, and the frontend `useOrganizationAiCreditPurchase.ts` / `AiCreditSubscription.tsx`).

The trace document (`oneoff-purchase-trace.md`) describes a STALE earlier state of OURS. The current working-tree code on `inflow-ats.billing-bonanza` already matched the analog on nearly every point the audit re-verified (split-vs-combined guards, InvoiceItem using `amount:` not `price:`, webhook resolving by `find_by(id:)` on the metadata record id, two separate frontend handlers/endpoints with wrapped-vs-flat params, `{ url, sessionId }` response read via `data.url`, no `payment_method_types` on the one-off checkout, `rescue StandardError` "Unable to process payment", etc.). The audit found exactly **2 actionable structural deviations**. Both are now fixed:

**Fix 1 — Double `Stripe::Price.list` in the direct-charge action.**
`/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`
Removed the controller-side `Stripe::Price.list(lookup_keys: [lookup_key], ...)` call and its `"Price not found in Stripe for this lookup key"` guard from `charge_top_up`. The analog WWR `#create` makes **zero** Stripe calls in the controller — `BoardWwrListing#charge_for_listing` resolves the amount exactly once, internally. OURS' `OrganizationAiCreditPurchase#charge_for_purchase` already re-resolves the price internally (its own `Stripe::Price.list` by `stripe_price_lookup_key`), so the controller-side resolution was dead on the direct-charge path (the resolved `price` was never consumed there). `charge_top_up` now does: validity gate → build record → `authorize purchase` → `purchase.save` → `purchase.charge_for_purchase` → `render_one(...)`, structurally identical to WWR `#create`. Amount is now resolved in a single place (the model), matching the analog.

**Fix 2 — Extra `currency:` column write in `charge_for_purchase`.**
`/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/models/organization_ai_credit_purchase.rb`
Changed the `update_columns` in `charge_for_purchase` from
`update_columns(stripe_invoice_id: invoice.id, stripe_invoice_item_id: invoice_item.id, stripe_amount: amount, currency: paid_invoice.currency)`
to
`update_columns(stripe_invoice_id: invoice.id, stripe_invoice_item_id: invoice_item.id, stripe_amount: amount)`.
The analog WWR `charge_for_listing` (board_wwr_listing.rb:158) and WhatJobs (board_what_jobs_listing.rb:193) write only `stripe_invoice_id`, `stripe_invoice_item_id`, `stripe_amount`. The `currency: paid_invoice.currency` was an EXTRA write with no analog counterpart. Safe: the record is built with `currency: 'usd'` at creation in both `charge_top_up` and `create_top_up_checkout_session`, so the conditional `validates :currency, presence: true` (which applies to one-offs) is already satisfied before the charge. `stripe_amount: amount` already matched the analog's `stripe_amount: amount` (locally-known amount, not `paid_invoice.amount_paid`).

## Frontend
No frontend change required. The audit confirmed the frontend already matches the analog after correcting the trace's stale sections: two separate handlers (`handleCreateTopUpDirectCharge` → `chargeAiCreditTopUp` → POST `/ai_credit_purchases/charge_top_up`; `handleCreateTopUpCheckoutSession` → `createAiCreditTopUpCheckoutSession` → POST `/ai_credit_purchases/create_top_up_checkout_session`), branch on `currentOrganization.stripeDefaultPaymentMethodOnFile`, checkout handler redirects via `data.url`, direct-charge onSuccess shows no toast/inspects no fields, checkout mutation is a bare `useMutation` with no invalidation — all matching the WWR analog. Neither backend fix changed a response key, so nothing on the frontend needed to follow.

## WHITELIST
- **`ai_credit_top_up_lookup_key?` validity gate in `charge_top_up`** (kept): The analog WWR `#create` has no equivalent gate. This guard exists because `OrganizationAiCreditPurchase` has a `kind` discriminator column (`one_off`/`subscription`) that `BoardWwrListing` does not have — it rejects a subscription lookup_key sent to the one-off endpoint, which the model's `validates ... inclusion` (accepts any registered key regardless of kind) would not catch. It is a local hash lookup (not a Stripe call), so it does not reintroduce the double-API-call divergence that Fix 1 removed. It parallels the WWR record's own `validates_presence_of :wwr_category` self-validation. The analog's pattern (no kind gate) literally cannot apply because WWR has no `kind` column. The actionable divergence (the second `Stripe::Price.list`) is removed; this local-validity guard stays.

## Verification
RuboCop on both edited files: the 3 reported offenses are all pre-existing and outside my changed lines (controller lines 194/246 in the unrelated subscription-portal actions; model line 88 on the pre-existing `validates :stripe_price_lookup_key` hash). My edits introduced zero new offenses. I did not touch the pre-existing offenses (out of scope).
