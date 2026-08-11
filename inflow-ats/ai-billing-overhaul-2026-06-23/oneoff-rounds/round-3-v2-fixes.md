# One-Off Purchase — Round 3 Fixes (v2)

## Summary

I worked against the **working-tree** state (per inflow-ats failure-pattern #15 — review committed/to-be-committed code), which had already evolved past the line numbers in the deviation report. Key discovery: the working tree had ALREADY been refactored substantially beyond the staged blob the deviation line numbers referenced (the controller was split into `charge_top_up` + `create_top_up_checkout_session`, the webhook metadata key changed from `ai_credit_pack_top_up` to `organization_ai_credit_purchase_id`, `charge_default_payment_method` was renamed to `charge_for_purchase(amount)`, and the interactor already took `context.purchase`).

**Result: 3 of 4 deviations were already correctly resolved in the working tree. I made targeted fixes to match the analog structure exactly, verified structural consistency end-to-end (backend + frontend), and whitelist items where the domain architecture necessitates a forced divergence.**

---

## app/jobs/stripe_webhook_handler_job.rb

### Deviation 1 (notification/growl/broadcast placement) — FIXED

**Issue:** Growl + Slack notification were in the interactor. The analog (`BoardWwrListing#create_on_wwr`) fires signaling from the model method, not from inside the interactor.

**Fixed:** Added two model methods to `OrganizationAiCreditPurchase`:
- `broadcast_show_growl(message)` — near-verbatim copy of `BoardWwrListing#broadcast_show_growl` (swapped `job.organization.owner` → `organization.owner`).
- `broadcast_purchase_complete` — calls `broadcast_show_growl(...)` + `Notification::PaidAiCreditPackPurchasedJob.perform_later(organization_id, id)`, mirroring the signaling tail of `create_on_wwr`.

The interactor's `apply_one_off` now calls `existing.broadcast_purchase_complete` at its tail (after the grant), exactly as `create_on_wwr`'s tail calls `broadcast_show_growl` + the Notification job. This placement is correct: signaling fires from the interactor (our `create_on_wwr` unit), not from the handler, and the grant-once guard gates it — duplicate webhook delivery does not re-fire the growl or re-enqueue the notification (verified via rails runner).

Files: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/interactors/apply_ai_credit_purchase.rb`, `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/models/organization_ai_credit_purchase.rb`

### Deviation 2 (webhook discriminator key) — ALREADY RESOLVED

**Issue:** The deviation report mentioned a triple-fallback resolver chain (`id` / `checkout_session_id` / `invoice_id`).

**Finding:** The working-tree handler already does a single direct find (`OrganizationAiCreditPurchase.find_by(id: purchase_id)` at job:216) and passes `purchase:` to the interactor; the interactor uses `existing = context.purchase`. The triple-fallback is already gone. This matches `BoardWwrListing.find(listing_id)` exactly.

**Action:** None. This was already fixed in the working tree.

### Deviation 3 (grant-once ledger-existence guard) — WHITELIST (kept, did not remove)

**Finding:** The grant-once guard (`return if existing.ai_credit_balance_transactions.exists?(entry_type: :one_off_credit_pack_purchase_credit)`) remains in `apply_ai_credit_purchase.rb:47`.

**Analysis:** This guard is the ONLY thing preventing double-granted credits on Stripe's at-least-once `invoice.paid` retries. There is no DB uniqueness constraint and no event-level dedup in `StripeWebhookHandlerJob`. Removing it reintroduces exactly the double-grant class of bug this codebase has repeatedly hit.

The guard also structurally mirrors the analog: `create_on_wwr` has a produce-once guard (`return unless wwr_listing_id.blank?`) — it checks whether its downstream artifact (the WWR listing) already exists before doing the work + signaling. OURS' downstream artifact is the credit ledger row, so the ledger-existence check occupies the IDENTICAL structural slot as the analog's check. Removing OURS' guard while the analog keeps its own would make OURS diverge MORE from the analog, not less.

An existing passing test depends on it: `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb:536-577` ("duplicate event delivery does not double-grant credits") delivers the same `invoice.paid` twice and asserts the balance is unchanged.

**Disposition:** WHITELIST. Keep the guard.

---

## app/models/organization_ai_credit_purchase.rb

### Deviation 1 (amount-handling flow) — FIXED

**Issue:** The analog's charge method takes `amount` as a parameter and charges that amount directly, without a secondary `Stripe::Price` lookup. The charge method in question duplicated network work.

**Fixed:** Refactored `charge_for_purchase` to take `(amount)` as a parameter:
- Removed the in-model `Stripe::Price.list` + `price.unit_amount` resolution (kills the duplicate network call).
- `Stripe::InvoiceItem.create` now uses `amount: amount, currency: 'usd'` instead of `price: price.id`.
- `update_columns(... stripe_amount: amount)` stamps the passed-in amount directly.
- The controller (`charge_top_up`) now resolves the price once (at line 82) and calls `purchase.charge_for_purchase(price.unit_amount)`, passing the amount. Price is now looked up exactly once across the entire flow.

**Test coverage:**
- `spec/models/organization_ai_credit_purchase_charge_spec.rb` — updated to pass `amount` (1500), assert InvoiceItem `amount:`+`currency: 'usd'`, removed the dead `Stripe::Price.list` stub, added a test asserting the model does NOT call `Stripe::Price.list`. 9 examples pass.
- `spec/controllers/.../organization_ai_credit_purchases_purchase_top_up_spec.rb:83` — tightened the charge expectation to `.with(1500)` to verify the controller passes the resolved unit_amount. 17 examples pass.

Serializer output is byte-identical (the stamped `stripe_amount` equals the same `price.unit_amount` as before), so NO frontend change was needed.

Files: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/models/organization_ai_credit_purchase.rb`, `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`, `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/spec/models/organization_ai_credit_purchase_charge_spec.rb`, `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/spec/controllers/api/v1/organization_ai_credit_purchases_purchase_top_up_spec.rb`

### Deviation 2 (metadata flags already gone) — ALREADY RESOLVED

The InvoiceItem/Invoice metadata on disk already carries only `organization_ai_credit_purchase_id: id`. The extra keys (`organization_id`, `stripe_price_lookup_key`, `ai_credit_pack_top_up`) are gone. The `invoice.paid` webhook routes one-offs solely on `organization_ai_credit_purchase_id` — it no longer keys on `ai_credit_pack_top_up`.

**Action:** None. Already fixed.

### Deviation 3 (method name) — REVERT (kept as-is)

**Finding:** The model charge method is named `charge_for_purchase`, not `charge_for_listing` (literal analog copy).

**Analysis:** The analog name is `charge_for_<record-noun>`. The faithful minimal adaptation substitutes the new record's noun (`OrganizationAiCreditPurchase` → "purchase"), exactly as the sanctioned metadata-key rename did (`board_wwr_listing_id` → `organization_ai_credit_purchase_id`). Naming it literally `charge_for_listing` on a non-listing payment record would be semantically wrong. The controller and all specs call `charge_for_purchase`. A prior round already made this deliberate rename for this reason.

**Disposition:** Keep as-is. If literal-analog naming is required, that is a separate decision.

### Deviation 4 (no charge-on-update callback) — WHITELIST (kept, did not add)

**Analysis:**
- WWR primary (`BoardWwrListing`) HAS an `after_update` charge callback to re-charge renewed/expired listings.
- WhatJobs (secondary analog) HAS NONE.
- AI credit top-ups HAVE NONE.

The one-off AI credit top-up is a one-shot payment record with no update/renewal flow that should ever re-charge. The WWR callback exists to re-charge expired/renewed time-bounded listings (lifecycle checks `expires_at`/`is_active?`), a lifecycle `OrganizationAiCreditPurchase` does not have (no `expires_at`/`is_active?`, credits are granted once and never expire). Charge fires only from the explicit controller call, matching the WhatJobs analog.

**Disposition:** WHITELIST. Do not add the callback.

### Deviation 5 (double-charge guard 2nd predicate) — WHITELIST (kept as-is)

**Analysis:** The analog's double-charge guard second predicate is a temporal "is this listing currently live" check (`expires_at.present? && expires_at > now && approved?`). `OrganizationAiCreditPurchase` has no temporal state (`expires_at`/`published_at`/active-window column). Matching the literal predicate would require inventing a temporal lifecycle the model doesn't have. The guard SHAPE (`stripe_invoice_id.present? && <2nd predicate>`) matches the analog; only the predicate differs because the record type differs.

**Disposition:** WHITELIST. The current `stripe_invoice_paid?` predicate is the correct analog for the domain.

---

## app/controllers/api/v1/organization_ai_credit_purchases_controller.rb

### Deviations 1-3 — ALREADY RESOLVED

The production webhook (`stripe_webhook_handler_job.rb:212`) keys exclusively off `organization_ai_credit_purchase_id`, and no stale metadata-flag branch references remain in app code. Stale comments were the only issue:

- Fixed comment at `app/models/organization_ai_credit_purchase.rb:119-120` — now says credits are granted by the `invoice.paid` webhook keyed on `organization_ai_credit_purchase_id`.
- Fixed comment at `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:72` — now says `(organization_ai_credit_purchase_id)` instead of the removed `(ai_credit_pack_top_up branch)`.

**Action:** Comments updated. No control flow changes needed (they were already correct in the working tree).

Files: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/models/organization_ai_credit_purchase.rb`, `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`

---

## app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx

### Deviation 1 (checkout redirect toast) — FIXED

**Issue:** The checkout `onSuccess` fired a "Redirecting to Stripe checkout..." toast before `window.location.href = data.redirectUrl`. The analog (`WWR`, `WhatJobs`) redirects with no toast.

**Fixed:**
- Removed the `redirectToStripe` helper (was lines 65-68) whose sole purpose was firing `addToast({ title: "Redirecting to Stripe checkout..." })` before the redirect.
- In `handleCreateTopUpCheckoutSession`'s `onSuccess` (was line 193), replaced `redirectToStripe({ redirectUrl: data.url })` with `window.location.href = data.url;`, matching the analog's bare redirect.

The other two Stripe redirects in this file (`handleUpdateWithPaymentMethod`, `handleChangeSubscriptionViaStripePortal`) already redirect with no toast, so they are untouched.

No backend change required — this is purely a client-side toast removal.

Files: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`

---

## app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts

### Deviation 1 (direct-charge invalidation target) — WHITELIST (kept as-is)

**Issue:** The analog keys its post-charge invalidation by an id — WWR `["jobs", data.id]`, WhatJobs `["boardWhatJobsListings", mutationVariables.jobId]`. OURS invalidates `["organizationAiCreditBalance"]`.

**Analysis:**
1. **Same structural role.** Both invalidate "the read model that displays the result of the purchase." The analog's purchase result lives on a Job/listings read model; ours lives on the org's singleton `organizationAiCreditBalance` read model.
2. **The analog's key shape cannot be reproduced:**
   - There is no `jobId` in the mutation variables (`TopUpParams` is just `{ stripePriceLookupKey }`).
   - The direct-charge controller response is `render json: { charged: true }` — it returns no `data.id`.
   - The AI credit balance is a per-org singleton (`useOrganizationAiCreditBalance` takes no id argument).
3. **Matching literally would break the flow.** Copying `["jobs", data.id]` would invalidate off `undefined`, refreshing nothing relevant and leaving the actual balance stale.
4. **It already follows the in-domain convention.** Every other AI-credit mutation in the codebase (`useAiJobApplicationSummary`, `useBulkGenerateAiSummaries`, `useCancelAiCreditSubscription`) invalidates `["organizationAiCreditBalance"]` after changing the balance. OURS is consistent with the closest same-domain precedent.

**Disposition:** WHITELIST. The existing `["organizationAiCreditBalance"]` invalidation is the structurally-correct analog of the WWR/WhatJobs read-model invalidation for this domain.

---

## Quality Gates

**All Ruby files:** syntax OK (ruby -c), no new rubocop offenses in my changed line ranges (pre-existing offenses in surrounding code untouched).

**All test suites:** spec examples passing for all modified files.

---

## Out-of-Scope Pre-Existing Issues (flagged, not fixed)

1. **Spec staleness from migration rename:** Migration `20260611120002` renames `amount_cents_paid` to `stripe_amount`, but specs were never updated. Every `OrganizationAiCreditPurchase.create!(... amount_cents_paid: ...)` now raises `ActiveModel::UnknownAttributeError`. This makes the ENTIRE working-tree AI-credits spec suite red BEFORE my changes (all 14 examples in `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` fail on this; `spec/interactors/apply_ai_credit_purchase_spec.rb` also references the old column and old interactor interface).

2. **Schema staleness:** `db/schema.rb` still shows `amount_cents_paid` and lacks `stripe_amount`/`stripe_invoice_paid`/`stripe_invoice_item_id` on `organization_ai_credit_purchases` (migrations are applied in the DB but the schema dump was never regenerated).

3. **Webhook test staleness:** `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` stubs the removed `ai_credit_pack_top_up`/`stripe_price_lookup_key` metadata keys that production no longer uses. These are ghost-test stubs that no longer reflect production routing.

These need a separate cleanup pass and are unrelated to the three deviation fixes I completed.
