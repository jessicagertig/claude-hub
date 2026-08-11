# AI Credit Billing — Sanctioned Deviations from Analogs

These are the ONLY acceptable deviations from the analog patterns. Any deviation not on this list must be reported to Jessica for decision — never self-classify as forced/appropriate/minor.

---

## AI Credit One-Off Purchase (analog: WWR / WhatJobs one-off)

1. **EXTRA: PurchaseAiCreditTopUpConfirmModal** — WWR charges immediately on click; AI credit one-off purchase shows a confirm modal first ("Your card on file will be charged $X today"). Jessica explicitly requested this to prevent refund requests.

2. **Double-charge guard second predicate uses `stripe_invoice_paid?`** instead of analog's `is_active?`/`live?` — the analog's second predicate is a temporal lifecycle check (`expires_at.present? && expires_at > now && approved?`) for time-bounded, renewable listings. `OrganizationAiCreditPurchase` has no temporal lifecycle (no `expires_at`, no `published_at`, no active window) — credits are granted once and never expire as a listing. `stripe_invoice_paid?` is the semantically correct second predicate for a one-shot payment record.

3. **No `after_update :handle_after_update` callback** — WWR's callback syncs changes to the external WeWorkRemotely listing service (`update_on_wwr`) and charges unpaid listings on update (`charge_for_listing unless stripe_invoice_paid`). AI credit one-off purchases have no third-party listing service to sync with and no update flow that should trigger a charge. WhatJobs (secondary analog) also has no such callback.

4. **Checkout `line_items` uses `price: price.id`** instead of inline `price_data` with `unit_amount` — the product data model for AI credit purchases follows the subscription analog (Stripe Products/Prices resolved by lookup key), not the WWR analog (locally hardcoded cent amounts). This is a deliberate architectural choice: prices are configured in the Stripe dashboard, enabling coupon codes and dashboard-managed pricing without deploys. The charge/fulfillment FLOW follows WWR; the data-fetching pattern follows the subscription analog.

5. **Direct-charge invalidation key `["organizationAiCreditBalance"]`** instead of analog's `["jobs", data.id]` — the mutation variables contain `{ stripePriceLookupKey }` with no `jobId`, and the AI credit balance is a per-org singleton read model. Copying the analog's literal key would invalidate on `undefined` and leave the actual balance stale.

6. **Pricing data follows the SUBSCRIPTION analog (`BillingController#prices`), NOT WWR** — for obtaining price data, using it on the frontend, and sending it to Stripe ONLY (the charge/fulfillment flow still follows WWR). WWR hardcodes cents (`calculate_charge_amount`) and uses inline `price_data`; AI credit prices live in Stripe Products/Prices (dashboard-managed). Sanctioned specifically:
   - `Stripe::Price.list(lookup_keys: [lookup_key], active: true, limit: 1)` at `organization_ai_credit_purchases_controller.rb:77` and `organization_ai_credit_purchase.rb:142` — resolves amount/price by lookup_key (vs WWR's local `calculate_charge_amount`).
   - Checkout `line_items: [{ price: price.id, quantity: 1 }]` (`controller:116`) and the direct-charge amount taken from `price.unit_amount`.
   - Frontend price fetch/display: `useOrganizationAiCreditPurchasePrices` + `aiCreditPrices` building from Stripe `price.unitAmount` (`planHelpers.ts`).
   (Expands item #4. See the trace's "Data-Fetching Analog (Subscription flow, NOT WWR)" section.)

7. **No `job` association** — AI credit purchases are org-level, not job-level. OURS legitimately OMITS, and must keep omitting, every WWR job construct:
   - the `exists(current_organization.jobs.where(id: params[:job_id]), …)` action wrapper (WWR `board_wwr_listings_controller.rb:6`)
   - the `job.description.blank?` guard (WWR `board_wwr_listings_controller.rb:8`)
   - `job_id` in every Stripe metadata block (WWR checkout `:119, :129, :136`)
   - building via `job.board_wwr_listings.build`; OURS builds on `current_organization` (`organization_ai_credit_purchases_controller.rb:88`)

8. **Action named `purchase_top_up`, not RESTful `create`** — OURS uses `authorize :billing, :checkout?` (`organization_ai_credit_purchases_controller.rb:69`) for both paths (matches WWR Path B's checkout auth), where WWR Path A uses `authorize @listing`.

9. **Balance notification-suppression flag reset on credit grant** — after granting credits, `grant_credits` clears the org's credit-balance warning flags so the user is re-warned the next time they run low. WWR has NO parallel: its fulfillment (`create_on_wwr`) touches no companion record because WWR has no credit balance. Forced by our domain (the `OrganizationAiCreditBalance` companion record). Specifically sanctioned:
   - `balance.update_columns(sent_low_notification_since_increase: false, sent_zero_notification_since_increase: false)` at `organization_ai_credit_purchase.rb:222-225` (one-off `grant_credits`).
   (The subscription path makes the same write at `apply_ai_credit_purchase.rb:62-65`; that flow is audited separately.)

10. **`broadcast_event` rides the org-level `GlobalChannel` (key `action:`), not WWR's job-level `JobChannel` (key `event:`)** — `grant_credits`' data broadcast is `GlobalChannel.broadcast_to(<initiating org user or org owner>, action: event, payload: { organizationId: organization_id })` at `organization_ai_credit_purchase.rb:244-246`. WWR's `create_on_wwr` broadcasts `JobChannel.broadcast_to(job, event: event, payload: { jobId:, boardWwrListingId:, wwrSlug:, publishedAt: })` (`board_wwr_listing.rb:267-269`). Forced by the no-`job`/org-level domain: no `job` ⇒ no `JobChannel`; AI-credit events are org-level and use the org user's `GlobalChannel`, matching our existing `broadcast_show_growl` convention. Same no-`job` family as #7.

11. **Checkout loading state uses the React Query mutation's `isLoading`, not a local `setIsPurchasing` flag** — OURS derives the checkout button's loading state from `usePurchaseAiCreditTopUpCheckoutSession`'s `isLoading` (`AiCreditSubscription.tsx:190-200`). WWR uses a local `setIsPurchasing(true)` at start / `setIsPurchasing(false)` in onError (`JobDistributionWeWorkRemotely.tsx:327,342,347`). The mutation's `isLoading` already covers our only async step (creating the Stripe checkout session); WWR's manual flag brackets additional client work tied to its external job-listing-creation flow, which AI credits have no parallel for. A manual flag would be redundant with the mutation state.

---

## Sanctioned Decisions

These are explicit decisions about HOW something should work, approved by Jessica. Future agents must not change these patterns without Jessica's approval.

### Grant-once guard (one-off purchase)

The analog (WWR) guards fulfillment with `return unless wwr_listing_id.blank?` — a column check on the same record that confirms the product (a WWR listing) was delivered.

Our equivalent: the product delivered to the customer is credits, and the delivery mechanism is creating an `AiCreditBalanceTransaction`. The guard fetches the grant record and verifies the amount is positive:

```ruby
existing_grant = organization_ai_credit_purchase.ai_credit_balance_transactions.find_by(
  entry_type: :one_off_credit_pack_purchase_credit
)
return if existing_grant && existing_grant.amount.positive?
```

Why `find_by(entry_type:)` is needed: a single `OrganizationAiCreditPurchase` can have multiple `AiCreditBalanceTransaction` records — the grant (`one_off_credit_pack_purchase_credit`) and potentially a refund (`one_off_credit_pack_refund_debit`). The entry type filter distinguishes the grant from the refund.

Why `amount.positive?` is checked: mere existence of the row is insufficient. If the row somehow exists with zero credits, the customer did not receive their product. The guard must confirm actual delivery, not just the existence of a delivery attempt.

---

## AI Credit Subscription Change (analog: BillingController portal flow)

1. **`flow_data.subscription`** uses `purchase.stripe_subscription_id` (not `organization.stripe_subscription_id`) — forced by separate Stripe subscription tracked on the purchase row
2. **Operates on `OrganizationAiCreditPurchase` record**, not org columns — forced by data model
3. **No `ValidateSubscriptionChange` / `PlanFeatureGate` / job-limit gate** — AI credit plans have no job-limit constraints
4. **Live-subscription endpoint retrieves by `purchase.stripe_subscription_id`** — same forced cause as #1
5. **`ai_credit_*` descriptor naming** with `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` — naming convention for the AI credit domain

---

## AI Credit Subscription Renewal (analog: main subscription `invoice.paid`)

- **Updates `organization_ai_credit_purchases` columns** instead of `organizations` columns — same record-level deviation as subscription change #2
- (Full column mapping pending — deviation-2-mapping agent in flight)

---

## NOT sanctioned (must be fixed or explicitly approved)

Any structural deviation from the analog that is not listed above. Examples of things that have been incorrectly self-classified as acceptable in past sessions:
- Missing columns that the analog has
- Different error handling patterns
- Different method placement (interactor vs model vs inline)
- Different guard structures
- Missing logging/notification/broadcast steps
- Different toast severity/behavior
