# Round 1 Fixes — AI Credit One-Off Purchase Analog Audit

Analog: WWR (`BoardWwrListing` / `board_wwr_listings_controller.rb`), secondary WhatJobs.
All 18 audited deviations addressed. No CANNOT-MATCH items.

Note on the trace: the trace's OURS sections were stale relative to live code (the live
controller's `purchase_top_up` was checkout-only with NO pre-create and NO direct-charge
path; `charge_for_purchase` and `broadcast_purchase_complete` existed but were dead). Fixes
align live OURS with the ANALOG, using the trace's OURS skeleton as the target shape where it
matches the analog.

---

## Backend — controller (`app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`)

### DEV 1, 2, 3 — pre-create record + direct-charge path + invoke model charge method
`purchase_top_up` (lines 68-146) rewritten to mirror `BoardWwrListing` create/charge flow:
- After resolving the Stripe price, **build + save** an `OrganizationAiCreditPurchase`
  (`kind: :one_off`, `stripe_price_lookup_key`, `one_off_credits_granted` via
  `ai_credit_allocation_for_lookup_key`, `stripe_amount: 0` placeholder, `currency: 'usd'`,
  `last_updated_by_organization_user: current_organization_user`) BEFORE any charge/checkout —
  so a persisted id exists to stamp into metadata (analog: `@listing.save` then charge).
- Branch on `current_organization.stripe_default_payment_method_on_file`:
  - true → `organization_ai_credit_purchase.charge_for_purchase` (the previously-dead model
    method is now invoked, mirroring `@listing.charge_for_listing`) → `render json: { charged: true }, status: :created`.
  - false → `Stripe::Checkout::Session.create` → stamp `stripe_checkout_session_id` → checkout JSON.

### DEV 4 — direct-charge capability exposed
OURS uses ONE action (`purchase_top_up`) that now performs BOTH paths internally (the OURS
design: frontend always calls one action; controller branches on payment method). The route
`post :purchase_top_up` is unchanged — no companion route is needed because the single action
now does the direct charge it previously omitted. (Analog uses two routes only because its
frontend calls two distinct actions.)

### DEV 5 — checkout invoice/session metadata now carries the record id
`invoice_creation.invoice_data.metadata` AND top-level `metadata` now include
`organization_ai_credit_purchase_id: organization_ai_credit_purchase.id` (plus existing
`organization_id`, `ai_credit_pack_top_up`). Analog: checkout `invoice_data.metadata` carries
`board_wwr_listing_id`.

### DEV 16 — checkout success response shape
Was `render json: { redirectUrl: session.url }`. Now
`render json: { url: session.url, sessionId: session.id }, status: :created` — matches analog
`board_wwr_listings_controller.rb:120`.

### DEV 18 — checkout error rescue shape
Was `rescue Stripe::StripeError` → `Rails.logger.error` + `ap e` + `Sentry.capture_exception` +
`render_general_errors([...])`. Now `rescue Stripe::StripeError => e; render json: { error: e.message }, status: :unprocessable_entity` — matches analog `board_wwr_listings_controller.rb:125-127`.

### Method-name correction (not a numbered deviation, required to compile)
Controller called `OrganizationAiCreditPurchase.one_off_key?` which does not exist on the model.
Replaced with the actual model method `ai_credit_top_up_lookup_key?`. (The `checkout`/`prices`
actions still call other non-existent names `subscription_key?` / `credit_amount_for_key` /
`registered_keys`; those are subscription-flow / out of one-off scope and were left untouched.)

---

## Backend — model (`app/models/organization_ai_credit_purchase.rb`)

### DEV 12 — double-charge guard second predicate
Was `if stripe_invoice_id.present? ... return end` (NO second predicate). Now
`return if stripe_invoice_id.present? && stripe_invoice_paid?` — matches SANCTIONED-DEVIATIONS.md
item #2 (`stripe_invoice_paid?` as the OURS substitute for the analog's `is_active?`/`live?`).

### DEV 5 (model side) — direct-charge InvoiceItem/Invoice metadata
`charge_for_purchase` InvoiceItem (lines 152-161) and Invoice (lines 162-173) metadata expanded
from `{ organization_ai_credit_purchase_id: id }` to
`{ organization_id:, organization_ai_credit_purchase_id: id, stripe_price_lookup_key:, ai_credit_pack_top_up: 'true' }`.
Required because the OURS `invoice.paid` webhook branches on `ai_credit_pack_top_up == 'true'`
and the interactor reads `organization_id` from invoice metadata — the direct-charge invoice
must carry the routing/find keys (the OURS analog of the analog's single `board_wwr_listing_id`
metadata key, which is both the analog's routing and find key). Matches the trace OURS skeleton
(hops 37-39).

### DEV 11, 13 — reported-for-completeness, SANCTIONED, no change
Grant-once guard (DEV 11) and price-from-Stripe (DEV 13) are sanctioned; left as-is.

---

## Backend — webhook (`app/jobs/stripe_webhook_handler_job.rb`, invoice.paid AI-credit branch)

### DEV 9 — removed extra `Stripe::Checkout::Session.list` call
Deleted the `Stripe::Checkout::Session.list(payment_intent:, limit: 1)` lookup. The analog
reads metadata and finds the record directly with no list call. `checkout_session_id` is no
longer derived or passed (the interactor finds by `purchase_id` from metadata; the
`checkout_session_id` fallback is dropped, mirroring the analog's metadata-id-only find).

### DEV 6, 7 — metadata lookup + `.find` + presence-guard
Branch now reads `object.metadata.organization_ai_credit_purchase_id.to_i` (a key the
producer now reliably stamps after DEV 5), then `OrganizationAiCreditPurchase.find(...)` then
`if organization_ai_credit_purchase&.present?` — structurally matches the analog's
`BoardWwrListing.find(listing_id)` + `if listing&.present?` (analog also uses `.find`).

### DEV 8 — finalize moved out of the webhook into the fulfillment unit
Removed `organization_ai_credit_purchase.finalize_stripe_payment` from the webhook. Finalize
now lives inside `ApplyAiCreditPurchase#apply_one_off` (the fulfillment unit), so the webhook's
sole fulfillment call is `ApplyAiCreditPurchase.call(...)` — matching the analog where the
webhook's fulfillment is the single `listing.create_on_wwr`.

---

## Backend — interactor (`app/interactors/apply_ai_credit_purchase.rb`, `apply_one_off`)

### DEV 8 — finalize inside the fulfillment unit
Added `existing.finalize_stripe_payment` before the ledger grant (mirrors the trace OURS hop 15
and the analog's `finalize_stripe_payment` being part of the invoice.paid fulfillment).

### DEV 10 — signaling tail now invoked
Added `existing.broadcast_purchase_complete` at the tail of `apply_one_off` (after the ledger
grant + balance reset). Mirrors `create_on_wwr`'s tail
(`broadcast_event` + `broadcast_show_growl` + `Notification::Paid...Job.perform_later`). The
previously-dead `broadcast_purchase_complete` (broadcast_event + broadcast_show_growl +
`Notification::PaidAiCreditPackPurchasedJob.perform_later`) is now live.

---

## Backend — new job (`app/jobs/notification/paid_ai_credit_pack_purchased_job.rb`)

### DEV 10 (completion) — created `Notification::PaidAiCreditPackPurchasedJob`
The model's pre-existing `broadcast_purchase_complete` referenced
`Notification::PaidAiCreditPackPurchasedJob`, which did NOT exist — invoking the signaling tail
(required by DEV 10) would raise `NameError`. Created the org-scoped analog of
`Notification::PaidWwrListingCreatedJob` (same structure: `perform(org_id, record_id)` →
find org + record → Slack ping via `SLACK_3RD_PARTY_PURCHASES_WEBHOOK`, with the same
`ActiveRecord::RecordNotFound` and Slack-failure rescues). This completes a reference the model
already made; it is the analog-faithful third leg of the signaling tail, not new functionality.

---

## Frontend (`app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`)

### DEV 16 — consume `url` (was `redirectUrl`)
`redirectToStripe` param/body changed from `{ redirectUrl }` / `data.redirectUrl` to
`{ url }` / `data.url`, matching the new backend checkout response key. (The two
subscription-change handlers at lines 87 and 127 still read `data.redirectUrl` — those backends
are unchanged subscription-flow endpoints, out of one-off scope, left untouched.)

### DEV 14, 15 — onSuccess handles `url` (checkout) and `charged` (direct charge)
`purchaseTopUp` onSuccess type changed to `{ url?: string; sessionId?: string; charged?: boolean }`.
Branch: `data.url` → redirect to Stripe checkout; else (direct-charge `{ charged: true }`
response, which the backend now actually returns) → "Payment received" toast. Previously the
else branch was unreachable because the backend only ever returned `{ redirectUrl }`.

(onError left as `error?.data?.errors?.general?.[0] || "Top-up checkout failed"` — the audit did
not flag it, and it mirrors the analog frontend's `errors?.general?.[0] || fallback` pattern with
a safe fallback.)

---

## CANNOT-MATCH items
None.

## SUGGESTED-WHITELISTS additions
None. (The missing notification job was created as the analog-faithful completion of a reference
the model already made, not whitelisted.)

## Verification
`ruby -c` passes on all 4 changed Ruby files and the new job. Model validations confirmed to
accept the pre-created record (one_off: `stripe_amount: 0` passes `>= 0`; `currency`,
`one_off_credits_granted`, `stripe_price_lookup_key` all present/positive).
