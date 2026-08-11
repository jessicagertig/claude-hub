# Round 3 — One-Off Purchase Analog Audit — Fix Log

Audit reported 11 deviations. All addressed below. The trace's OURS sections were
stale; all comparisons were made against the ANALOG sections and the LIVE code.

Files touched:
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (`purchase_top_up`)
- `app/models/organization_ai_credit_purchase.rb` (`charge_for_purchase`)
- `app/jobs/stripe_webhook_handler_job.rb` (`invoice.paid` handler)
- `app/policies/organization_ai_credit_purchase_policy.rb` (`create?`)

---

## Dev 1 — Direct-charge path lacks record-level authorize

ANALOG: `board_wwr_listings_controller.rb:19` `authorize @listing` →
`BoardWwrListingPolicy#create?` → `is_org_admin?`.

FIX:
- `organization_ai_credit_purchase_policy.rb`: added `create?` returning `is_org_admin?`
  (mirrors `BoardWwrListingPolicy#create?`).
- `purchase_top_up`: after building `organization_ai_credit_purchase`, added
  `authorize organization_ai_credit_purchase` (record-level, before the branch).
- Kept the top-level `authorize :billing, :checkout?` because OURS combines both paths
  in one action and Path B (checkout) is governed by `BillingPolicy#checkout?` in the
  analog (`board_wwr_listings_controller.rb:52`).

## Dev 2 — Save+charge not wrapped in save-success branch

ANALOG: `controller:21-26` `if @listing.save then charge_for_listing; render_one else render_errors(@listing) end`.

FIX (direct-charge path): replaced the separate save-guard + separate charge block with
the analog's single if/else:
```ruby
if organization_ai_credit_purchase.save
  organization_ai_credit_purchase.charge_for_purchase
  render_one(organization_ai_credit_purchase, Api::V1::OrganizationAiCreditPurchaseSerializer)
else
  render_errors(organization_ai_credit_purchase)
end
```
Changed the save-failure render from `render_general_errors([...])` to `render_errors(record)`
to match the analog's `render_errors(@listing)`.

## Dev 3 — Controller resolved Stripe::Price before record creation

ANALOG: `#create` has no `Stripe::Price.list`.

FIX: removed the top-of-action `Stripe::Price.list` call. Price resolution now lives ONLY
on the checkout path (Path B), after the direct-charge branch returns. The direct-charge
path no longer makes any controller-level price call (matches analog `#create`). The
checkout path still resolves the Stripe Price because sanctioned deviation #4 keeps
`line_items: [{ price: price.id }]` for checkout.

## Dev 4 — Pre-charge lookup-key validity guard has no analog

ANALOG: `#create` has no `ai_credit_top_up_lookup_key?` guard.

FIX: removed the `unless OrganizationAiCreditPurchase.ai_credit_top_up_lookup_key?(lookup_key) ... return` guard from the controller. The class method `ai_credit_top_up_lookup_key?`
is left defined on the model (a spec references it; removing the method is out of scope
and would be an unscoped deletion).

## Dev 5 — Model resolved Stripe::Price "again"

ANALOG: amount resolved once, inside the model (`calculate_charge_amount`).

FIX: resolved by Dev 3 — with the controller's direct-charge price call removed, the
model's `Stripe::Price.list` in `charge_for_purchase` is now the SINGLE price resolution
for the direct-charge path (mirroring the analog's single in-model `calculate_charge_amount`).
No further change needed in the model for this item.

## Dev 6 — Double-charge guard ordering (amount-first)

ANALOG: `board_wwr_listing.rb:113-122` computes `amount = calculate_charge_amount` FIRST,
then `return if stripe_invoice_id.present? && is_active?`, then `return if customer blank`.

FIX (`charge_for_purchase`): moved price/amount resolution to the TOP of the method
(`Stripe::Price.list` → `price` → `amount = price.unit_amount`, with `return if price.blank?`),
then the double-charge guard (`return if stripe_invoice_id.present? && stripe_invoice_paid?`),
then `return if organization.stripe_customer_id.blank?`. Order now matches the analog.
Per sanctioned deviation #2, the second predicate stays `stripe_invoice_paid?`.
`return if price.blank?` is part of OURS' Stripe-resolved amount step (no analog because
the analog's amount is a local calc that cannot be nil) — kept adjacent to resolution.

## Dev 7 — Direct-charge InvoiceItem metadata had extra key

ANALOG: `board_wwr_listing.rb:135-137` InvoiceItem metadata = `{ board_wwr_listing_id: id }`
(single record-id key).

FIX (`charge_for_purchase`): InvoiceItem metadata reduced to
`{ organization_ai_credit_purchase_id: id }` (dropped `ai_credit_pack_top_up: 'true'`).

## Dev 8 — Direct-charge Invoice metadata had extra key

ANALOG: `board_wwr_listing.rb:148-150` Invoice metadata = `{ board_wwr_listing_id: id }`.

FIX (`charge_for_purchase`): Invoice metadata reduced to
`{ organization_ai_credit_purchase_id: id }` (dropped `ai_credit_pack_top_up: 'true'`).

NOTE (cross-cutting with Dev 11): dropping `ai_credit_pack_top_up` from the Invoice
metadata required the webhook to stop discriminating on that flag. The analog
discriminates by `board_wwr_listing_id` PRESENCE; OURS now discriminates by
`organization_ai_credit_purchase_id` presence (see Dev 11). Verified safe: only the
one-off path stamps `organization_ai_credit_purchase_id` into Stripe invoice metadata;
the subscription path does not, so subscription invoices do not match the one-off branch.
This fully collapses the prior 2-key metadata to a true 1-key analog match, superseding
the W2 whitelist note (annotated in SUGGESTED-WHITELISTS.md).

## Dev 9 — Checkout-session metadata omits organization_id / job_id and payment_intent_data block

ANALOG: `board_wwr_listings_controller.rb:94-115`:
- `payment_intent_data.metadata` = `{ board_wwr_listing_id, organization_id, job_id }`
- `invoice_data.metadata` = `{ board_wwr_listing_id, job_id }`
- session `metadata` = `{ board_wwr_listing_id, organization_id, job_id }`

FIX (checkout path):
- Added the `payment_intent_data: { metadata: { organization_ai_credit_purchase_id, organization_id } }` block (was absent entirely).
- session `metadata` now `{ organization_ai_credit_purchase_id, organization_id }` (added `organization_id`, dropped `ai_credit_pack_top_up`).
- `invoice_data.metadata` now `{ organization_ai_credit_purchase_id }` (dropped `ai_credit_pack_top_up`).

CANNOT-MATCH: `job_id` — an AI credit top-up is org-scoped, not job-scoped. There is no
`Job` anywhere in `purchase_top_up` (no `params[:job_id]`, no job lookup). The analog is
job-scoped (a listing belongs to a job); OURS has no job to reference. Recorded as W3 in
SUGGESTED-WHITELISTS.md. `organization_id` and the `payment_intent_data` block WERE
matched.

## Dev 10 — Checkout session had payment_method_types: ['card']

ANALOG: `Stripe::Checkout::Session.create` has no `payment_method_types` key.

FIX (checkout path): removed `payment_method_types: ['card']` from the session.

## Dev 11 — Webhook AI-credit branch placed ahead of analog record-id branches

ANALOG: `stripe_webhook_handler_job.rb:225` `board_wwr_listing_id` branch is the first
metadata record-id branch; `board_what_jobs_listing_id` second.

FIX (`invoice.paid` handler):
- Moved the AI-credit branch to AFTER both the `board_wwr_listing_id` (now first) and
  `board_what_jobs_listing_id` (second) branches — AI-credit is now third.
- Changed the discriminator from `object.metadata['ai_credit_pack_top_up'] == 'true'` to
  `object.metadata&.[]('organization_ai_credit_purchase_id').present?`, mirroring the
  analog's `object.metadata&.[]('board_wwr_listing_id').present?` presence check.
- Branch body unchanged (`finalize_stripe_payment` + `grant_credits` + early `return`).

---

## CANNOT-MATCH items

- **Dev 9 `job_id`** — no job exists in the org-scoped AI credit top-up flow. Closest
  fix applied (organization_id + payment_intent_data block added; job_id omitted).
  Appended to SUGGESTED-WHITELISTS.md as W3.

## SUGGESTED-WHITELISTS additions

- **W3** — checkout-session metadata omits `job_id` (Dev 9), forced by org-scoped vs
  job-scoped data model.
- **W2 annotation** — marked SUPERSEDED: the `ai_credit_pack_top_up` flag was fully
  removed and the metadata collapsed to a true 1-key analog match (Dev 7/8/11).

## Frontend

No frontend response-key changes were needed. The controller's response shapes are
unchanged: checkout returns `{ url, sessionId }` (read as `data.url` in
`AiCreditSubscription.tsx:162`), direct charge returns the serialized purchase via
`render_one` (the frontend falls through to the success toast when no `data.url`).

## Verification

`ruby -c` passes on all four modified Ruby files.
