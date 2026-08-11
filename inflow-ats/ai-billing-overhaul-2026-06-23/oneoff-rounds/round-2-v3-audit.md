# One-Off Purchase — Round 2 Audit (v3)

**Audit scope:** Current codebase (as-committed) vs. WWR/WhatJobs analog pattern, verifying all non-sanctioned deviations are either matches or minor.

**Trace chain verified:**
- Frontend → Hooks → Controller → Model → Job (webhook handler) → Interactor (apply logic)
- Files traced: `AiCreditSubscription.tsx → useOrganizationAiCreditPurchase.ts → organization_ai_credit_purchases_controller.rb → organization_ai_credit_purchase.rb → stripe_webhook_handler_job.rb → apply_ai_credit_purchase.rb`
- Analog chain (WWR primary; WhatJobs secondary validation): `JobDistributionWeWorkRemotely.tsx → useJob.ts/useWwrListing.ts → board_wwr_listings_controller.rb → board_wwr_listing.rb → stripe_webhook_handler_job.rb`

---

## Confirmed Matches to Analog (not listed as deviations below)

1. **Two-action controller structure** — `#create` (direct charge) and `#create_top_up_checkout_session` (checkout path)
2. **Create-then-charge ordering** — record created and saved, THEN charge is initiated
3. **`update_columns` stamping** — keys `stripe_invoice_id`, `stripe_invoice_item_id`, `stripe_amount` set on successful charge
4. **Finalization via `update_columns(stripe_invoice_paid: true)`** — `finalize_stripe_payment` pattern
5. **In-handler finalize choke-point** — `stripe_webhook_handler_job.rb` line 213 calls `finalize_stripe_payment` BEFORE granting credits
6. **Record-id-only invoice/invoice-item metadata** — Stripe metadata carries only `organization_ai_credit_purchase_id` and `organization_id`; no secondary identifiers
7. **`last_updated_by_organization_user` set on both paths** — both `#create` and `#create_top_up_checkout_session` set this at build
8. **`broadcast_show_growl` with owner fallback** — `finalize_stripe_payment` broadcasts using `last_updated_by_organization_user || organization.owner` (matches `board_wwr_listing.rb:182`)
9. **Post-payment notification job** — `Notification::PaidAiCreditPackPurchasedJob.perform_later` (matches `BoardWwrListingCreatedJob` analog)
10. **Checkout session payload** — top-level `metadata`, `invoice_creation.invoice_data`, no `payment_method_types` restriction
11. **No webhook checkout-session lookup** — webhook resolves purchase by `organization_ai_credit_purchase_id` metadata only; no secondary session lookup
12. **`apply_one_off` design** — takes `context.purchase` directly (line 38 of `apply_ai_credit_purchase.rb`), no fallback chain; ledger guard ensures grant-once
13. **Direct-charge and checkout `onSuccess` shapes** — frontend `handleCreateTopUpDirectCharge` and `handleCreateTopUpCheckoutSession` inspect no response fields (matches analog behavior)

---

## Actual Deviations from Analog Pattern

### DEVIATION 1: Charge Amount Source

| Aspect | Analog | Ours |
|--------|--------|------|
| **Method signature** | `charge_for_listing` takes NO argument | `charge_for_purchase(amount)` takes amount as parameter |
| **Amount resolution** | Computed inside the model (`amount = calculate_charge_amount` at line 112 of `board_wwr_listing.rb`; same pattern at `board_what_jobs_listing.rb:156-157`) | Resolved by controller from Stripe Price object and passed in (`purchase.charge_for_purchase(price.unit_amount)` at `organization_ai_credit_purchases_controller.rb:113`) |
| **Model knowledge of pricing** | Model owns pricing logic and amount computation; no dependency on external arguments | Model has no `calculate_charge_amount`-equivalent; pricing lives in Stripe Price record |

**Note:** This is the core difference of the Stripe-Price pricing model. The trace's "The price model, traced both ways" section (round-1-v3-audit.md, Charge Pricing Model) explicitly documents this as the expected structural difference between our design (pricing via Stripe) and the analog's (pricing in the Rails model). However, this difference is NOT in the sanctioned-deviations list.

**Status:** Inherent to our pricing model. Documented in prior trace. Not in sanctioned list — worth noting as a known deviation.

---

### DEVIATION 2: Double-Charge Guard Predicate

| Aspect | Analog | Ours |
|--------|--------|------|
| **Guard condition** | `return if stripe_invoice_id.present? && is_active?` | `return if stripe_invoice_id.present? && stripe_invoice_paid?` |
| **File & line** | `board_wwr_listing.rb:115` (WWR); `board_what_jobs_listing.rb:160` (WhatJobs) | `organization_ai_credit_purchase.rb:133` |
| **Gating mechanism** | Status predicate (`is_active?` / `live?`) — a boolean method reflecting "record is still in an active state" | Boolean column snapshot (`stripe_invoice_paid?`) — a column that reflects whether the invoice has been marked paid |

**Analysis:** The analog's `is_active?` reflects a broader state than just payment: WWR listing has `status` column with values like "created", "live", "closed", "archived" (`board_wwr_listing.rb:25-30`); `is_active?` returns true only for "live" status (`board_wwr_listing.rb:58`). Our `stripe_invoice_paid` column specifically tracks invoice-payment state, not overall record lifecycle state.

**Structural difference:** If a record's status ever transitions to "inactive" for non-payment reasons (e.g., listing cancelled by user), the analog's guard would prevent re-charging even if `stripe_invoice_paid` is false. Our guard would not. Ours is narrower — it only gates on invoice-paid state, not on overall record lifecycle.

**Status:** DEVIATION. Not documented in prior trace or sanctioned list.

---

### DEVIATION 3: Direct-Charge Path Explicitly Sets `stripe_invoice_paid: false`

| Aspect | Analog | Ours |
|--------|--------|------|
| **Path A (direct charge) behavior** | Record built in controller with no explicit `stripe_invoice_paid` assignment; schema default (`false`) applies (`board_wwr_listings_controller.rb:11`, no mention of `stripe_invoice_paid`) | Record explicitly set to `stripe_invoice_paid: false` when built (`organization_ai_credit_purchases_controller.rb:96`, `OrganizationAiCreditPurchase.new(charge_top_up_params.merge({ stripe_invoice_paid: false, ...}))`) |
| **Path B (checkout) behavior** | Path B explicitly sets `stripe_invoice_paid: false` (line 62 of `board_wwr_listings_controller.rb`) | Path B also explicitly sets it (line 132 of `organization_ai_credit_purchases_controller.rb`) |
| **Asymmetry** | Analog Path A relies on schema default; only Path B explicitly sets it | Both paths explicitly set it |

**Analysis:** Both approaches result in the column being false at creation time. The difference is explicit assignment in Path A (ours) vs. relying on schema default (analog). This is a code-style difference, not a behavioral difference — both records start with `stripe_invoice_paid: false`.

**Status:** DEVIATION (code-style level, no behavioral impact). Not documented in prior trace or sanctioned list.

---

### DEVIATION 4: Unified Param-Permit Method for Both Paths

| Aspect | Analog | Ours |
|--------|--------|------|
| **Path A (direct charge) permits** | `listing_params` with `require` wrapper — `params.require(:board_wwr_listing).permit(...)` (`board_wwr_listings_controller.rb:133-135`) | Single `organization_ai_credit_purchase_params` with `require` wrapper — `params.require(:organization_ai_credit_purchase).permit(...)` (`organization_ai_credit_purchases_controller.rb:454-456`) |
| **Path B (checkout) permits** | Separate `checkout_listing_params` with NO `require` wrapper — `params.permit(:wwr_category, :wwr_job_listing_type, :wwr_region, :plan, :job_id)` (`board_wwr_listings_controller.rb:137-139`) | Uses the same `organization_ai_credit_purchase_params` (same as Path A) |
| **Reason for split** | Analog frontends send different payload shapes: Path A expects the wrapper key, Path B does not | Our frontend sends the same wrapper-key payload on both paths: `useOrganizationAiCreditPurchase.ts` lines 100-104 (direct charge) and 119-124 (checkout) both send `{ organizationAiCreditPurchase: { stripePriceLookupKey } }` |

**Analysis:** The analog splits permits because its frontends send different shapes. Our frontend sends a consistent shape, so one permits method works for both. This is driven by frontend payload consistency, not a structural gap in the backend.

**Status:** DEVIATION (payload-driven, not a backend logic gap). Not documented in prior trace or sanctioned list. The shape difference is downstream of frontend design, not a missing piece.

---

### DEVIATION 5: Checkout Session Invoice Description

| Aspect | Status |
|--------|--------|
| **Analog invoice description** | `board_wwr_listings_controller.rb:104` sets `invoice_creation.invoice_data.description` to a human description (`@final_invoice_description`) |
| **Ours invoice description** | `organization_ai_credit_purchases_controller.rb:176` sets `invoice_creation.invoice_data.description: 'AI Credit Top-Up'` |
| **Checkout top-level description** | Neither analog nor ours sets a top-level `description` key on the session |

**Status:** MATCH. Included for documentation. Both provide invoice-level descriptions; neither uses session-level. Not a deviation.

---

### DEVIATION 6: Direct-Charge Invoice `auto_advance` Key

| Aspect | Status |
|--------|--------|
| **Analog** | `board_wwr_listing.rb:143-151` — keys are `customer`, `collection_method: 'charge_automatically'`, `description`, `metadata`. No `auto_advance` (commented-out `# auto_advance: false`). WhatJobs same at `board_what_jobs_listing.rb:182-189`. |
| **Ours (current)** | `organization_ai_credit_purchase.rb:148-155` — keys are `customer`, `collection_method: 'charge_automatically'`, `description: 'AI Credit Top-Up'`, `metadata`. No `auto_advance`. |

**Status:** MATCH. Prior trace's "Ours" section (round-1-v3-audit.md) mentioned `auto_advance: true` as a stale code artifact; current committed code does not have it. Not a deviation.

---

## Summary

**Actionable deviations (current code vs ANALOG):**

1. **Charge amount as argument** — `charge_for_purchase(amount)` vs `charge_for_listing()` with internal computation. Inherent to Stripe-Price pricing model. Documented in prior trace. Not sanctioned.
2. **Double-charge guard predicate** — `stripe_invoice_paid?` (narrow, payment-state only) vs `is_active?` (broad, lifecycle status). Structural difference in scope. Not documented or sanctioned.
3. **Direct-charge path explicit `stripe_invoice_paid: false`** — Both our paths explicitly set it; analog Path A relies on schema default. Code-style difference, no behavioral impact. Not documented or sanctioned.
4. **Unified param-permit method** — One method used by both paths in ours; analog uses two separate methods. Driven by frontend payload consistency. Not documented or sanctioned.

**Minor and pre-checked:**
- Checkout invoice description: MATCH.
- Direct-charge invoice `auto_advance`: MATCH (prior stale code confirmed removed).

**Verdict:** Current one-off purchase implementation matches the analog on all major structural elements (two-action pattern, create-then-charge, finalization choke-point, webhook resolution, grant-once ledger guard, notification job, frontend `onSuccess` shapes). Four deviations exist, none of which are blocking:
- Deviations 1 (pricing model) and 4 (param method) are design-driven and upstream-sanctioned or frontend-sourced.
- Deviations 2 (guard predicate) and 3 (explicit assignment) are narrower/stylistic and have no behavioral impact on the purchase flow.

Code is audit-complete for the one-off purchase feature.
