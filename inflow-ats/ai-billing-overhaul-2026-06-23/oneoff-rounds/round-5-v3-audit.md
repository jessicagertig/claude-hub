# One-Off Purchase — Round 5 Audit (v3)

The `authorize purchase` in `charge_top_up` resolves to `OrganizationAiCreditPurchasePolicy#create?` → `is_org_admin?` (matching WWR's `authorize @listing` → `BoardWwrListingPolicy#create?` → `is_org_admin?`). The stale `purchase_top_up?` reference at `AccountBillingAiCredits.tsx:31` is a comment, and there's no `AiCreditPolicy` — the comment references a non-existent policy/action. That's a stale documentation reference.

I now have a complete structural picture. Let me write up the deviations. The current code has been refactored to closely follow the analog. After applying the whitelist and sanctioned-deviations filter, here are the genuine remaining structural deviations from the analog pattern.

Let me do one last check to confirm the analog WWR `charge_for_listing` returns the paid invoice and the controller does NOT use the return value, and verify ours' controller path for direct-charge returns the serialized record (it does). And confirm there are no other one-off flow files I'm missing (the `OrganizationAiBilling.tsx` / `AccountBillingAiCredits.tsx` wrappers).

I have enough to report. Let me compile the final structural comparison.

Based on my trace of the analog (WWR primary: `BoardWwrListingsController` → `BoardWwrListing` → `StripeWebhookHandlerJob` invoice.paid → frontend `JobDistributionWeWorkRemotely.tsx`/`useJob.ts`/`useWwrListing.ts`; WhatJobs secondary) versus our CURRENT one-off AI-credit top-up code, here are the findings.

---

## Files traced

**Analog:** `app/controllers/api/v1/board_wwr_listings_controller.rb` → `app/models/board_wwr_listing.rb` → `app/jobs/stripe_webhook_handler_job.rb` (invoice.paid WWR branch :234-245) → `app/javascript/ats/src/views/jobApplications/jobDistribution/JobDistributionWeWorkRemotely.tsx` → `app/javascript/shared/queryHooks/useJob.ts` (createBoardWwrListing) + `useWwrListing.ts`. Secondary: `board_what_jobs_listings_controller.rb` → `board_what_jobs_listing.rb` → `WhatJobsSidebarActions.tsx` → `useWhatJobsListing.ts`.

**Ours:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (`charge_top_up` :75, `create_top_up_checkout_session` :123) → `app/models/organization_ai_credit_purchase.rb` (`charge_for_purchase` :131, `broadcast_purchase_complete` :181) → `stripe_webhook_handler_job.rb` (invoice.paid AI branch :212-232) → `apply_ai_credit_purchase.rb` (`apply_one_off` :37) → `AiCreditSubscription.tsx` → `useOrganizationAiCreditPurchase.ts` (`chargeAiCreditTopUp` :100, `createAiCreditTopUpCheckoutSession` :122) → `AiCreditPackCard.tsx`.

---

## CONTEXT: the working tree is a substantial refactor that ALREADY matches the analog far better than the trace's stale "OURS" sections describe.

The trace's "OURS" sections describe a single `purchase_top_up` action, a `charge_default_payment_method` method, `auto_advance: true`, `ai_credit_pack_top_up`/`stripe_price_lookup_key` webhook metadata + lookup, `finalize_stripe_payment` inside the interactor, and a frontend `redirectUrl`/`{charged:true}` shape. **None of that is in the current code.** The current code now: splits into `charge_top_up` (direct, RESTful-create analog) + `create_top_up_checkout_session` (checkout analog) mirroring WWR's two actions; the webhook keys on `organization_ai_credit_purchase_id` and finds the record directly (matching WWR's `board_wwr_listing_id` find); `finalize_stripe_payment` is the in-handler choke point (matching WWR :241); the business-work unit (`ApplyAiCreditPurchase` ↔ `create_on_wwr`) does its work then signals via model methods (`broadcast_purchase_complete` ↔ `broadcast_event`+`broadcast_show_growl`+`Notification::PaidAiCreditPackPurchasedJob` ↔ WWR's `Notification::PaidWwrListingCreatedJob`). These are all faithful to the analog — not deviations.

---

## Genuine remaining structural deviations (whitelist + sanctioned deviations already excluded)

**DEVIATION 1: checkout-session `invoice_creation.invoice_data.description` is a static literal**
- ANALOG: computed per-purchase description — `invoice_data: { description: @final_invoice_description }` where `@final_invoice_description` reflects the plan/upgrade and any discount (`board_wwr_listings_controller.rb:104`, built :73-74; WhatJobs uses `description: @description` = `"WhatJobs Job Listing - #{job.title}"`, `board_what_jobs_listings_controller.rb:245`)
- OURS: hardcoded `description: 'AI Credit Top-Up'` with no per-pack/lookup-key detail (`organization_ai_credit_purchases_controller.rb:163`)
- NOTE: The same controller's direct-charge model method DOES build a per-pack description (`"AI Credit Top-Up — #{...AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY.dig(stripe_price_lookup_key, :name)...}"`, `organization_ai_credit_purchase.rb:142`), so the per-pack description exists and is used on the direct-charge path but is dropped on the checkout-session path. The two paths are internally inconsistent, and the checkout path diverges from the analog which gives the checkout invoice a descriptive, variant-aware description.

**DEVIATION 2: checkout-session `invoice_creation.invoice_data.metadata` missing `organization_id` key**
- ANALOG: all three metadata blocks (invoice_data, payment_intent_data, top-level) carry the full key set the webhook/refund paths rely on — `board_wwr_listing_id` + `organization_id` + `job_id` present in all three (`board_wwr_listings_controller.rb:94-114`)
- OURS: `invoice_data.metadata` carries only `organization_ai_credit_purchase_id` (`organization_ai_credit_purchases_controller.rb:164-166`), while `payment_intent_data.metadata` and top-level `metadata` carry `organization_ai_credit_purchase_id` + `organization_id` (:154-158, :169-172)
- NOTE: The webhook only reads `organization_ai_credit_purchase_id` off the invoice (`stripe_webhook_handler_job.rb:212`), so this is not load-bearing for the happy path, but it is a literal metadata-shape divergence from the analog. The `organization_id` key present on the analog's invoice_data is absent from ours' invoice_data.

---

## Items examined and found NOT to be deviations (or excluded by whitelist/sanctioned list)

- **Two-action split, route shapes, params** (`organization_ai_credit_purchase_params` wrapped ↔ WWR `listing_params`; `checkout_top_up_params` flat ↔ WWR `checkout_listing_params`): match the analog. Frontend payloads match (direct = wrapped `{ organizationAiCreditPurchase }` ↔ WWR `{ boardWwrListing }`; checkout = flat `{ stripePriceLookupKey }` ↔ WWR flat `{ wwrCategory, ... }`).
- **Direct-charge authorization** `authorize purchase` → `OrganizationAiCreditPurchasePolicy#create?` → `is_org_admin?`: matches WWR `authorize @listing` → `BoardWwrListingPolicy#create?` → `is_org_admin?`. (Checkout path `authorize :billing, :checkout?` matches both analogs.)
- **`charge_for_purchase` model-method-does-Stripe, three-call InvoiceItem→Invoice→pay→`update_columns`, returns paid invoice, no `auto_advance`, Invoice `collection_method: 'charge_automatically'`, static invoice description:** matches `board_wwr_listing.rb:112-164` / `board_what_jobs_listing.rb:156-198`.
- **`line_items: [{ price: price.id }]` and InvoiceItem `price: price.id`-via-`Stripe::Price.list`:** WHITELISTED (Deviation 1 — price lives only in Stripe, resolved by lookup_key).
- **Double-charge guard** `stripe_invoice_id.present? && stripe_invoice_paid?`: WHITELISTED (2nd-predicate difference; no temporal lifecycle on the purchase model).
- **No `after_update`/charge-on-update callback:** WHITELISTED.
- **Webhook in-handler `finalize_stripe_payment` then business-work unit; interactor grant-once guard + `broadcast_purchase_complete` tail:** matches WWR (`stripe_webhook_handler_job.rb:241-242` → `create_on_wwr` tail). The interactor grant-once guard (`apply_ai_credit_purchase.rb:47`) is WHITELISTED.
- **Direct-charge `onSuccess` invalidates `["organizationAiCreditBalance"]`:** WHITELISTED (analog keys by `["jobs", data.id]`; ours' read model is the org singleton balance).
- **`PurchaseAiCreditTopUpConfirmModal` (extra confirm modal):** SANCTIONED.
- **`ai_credit_*` descriptor naming, `OrganizationAiCreditPurchase` row as the record source:** SANCTIONED.
- **`AiCreditPackCard` Button `loading={isLoading} disabled={isLoading}`:** present (`AiCreditPackCard.tsx:38-39`) — satisfies the analog-behavioral-props rule.
- **No `payment_method_types` on the one-off checkout session** (`create_top_up_checkout_session`): matches the analog (WWR/WhatJobs checkout sessions omit it). The `payment_method_types: ['card']` at `controller:36` belongs to the SUBSCRIPTION `checkout` action, out of scope.
- **`success_url`/`cancel_url` with `session_id={CHECKOUT_SESSION_ID}`:** matches analog shape (org-scoped billing URL instead of job-distribution URL — forced).
- **`redirectUrl` reads on subscription/portal lines:** WHITELISTED (subscription flow, out of scope).
- **Spec suite / `schema.rb` staleness:** WHITELISTED.

---

## Non-analog stale reference noticed (not a structural analog deviation, surfaced per anti-stale-reference rule)

- `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingAiCredits.tsx:31` comment references `AiCreditPolicy#purchase_top_up?` — that policy/action does not exist (the gate is `OrganizationAiCreditPurchasePolicy#create?` via `authorize purchase`), and `purchase_top_up` is the old single-action name now split into `charge_top_up` + `create_top_up_checkout_session`. Stale comment only.
