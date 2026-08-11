# Suggested Whitelist Additions (for Jessica's review — NOT yet sanctioned)

These are deviations a fix agent could not match exactly to the analog because the
analog has no corresponding concept (data-model differences), not because matching
was hard. Jessica decides whether to add them to SANCTIONED-DEVIATIONS.md.

---

## AI Credit One-Off Purchase (analog: WWR / WhatJobs)

### W1. Balance notification-flag reset in `grant_credits` (audit Dev 5)

- **File:** `app/models/organization_ai_credit_purchase.rb` — `grant_credits`
- **What:** after granting credits, `balance.update_columns(sent_low_notification_since_increase: false, sent_zero_notification_since_increase: false)`.
- **Analog:** `BoardWwrListing#create_on_wwr` performs no companion-record column reset.
- **Why it cannot match:** the analog has no companion balance record. OURS delivers
  credits onto an `OrganizationAiCreditBalance` that carries notification-suppression
  flags. Resetting them on a credit increase is part of correctly delivering the
  product (otherwise low/zero-balance notifications stay suppressed after a top-up).
  Forced by the data-model difference (credits have a balance with notification
  state; WWR listings do not). Kept in the `create_on_wwr`-analog method, immediately
  after the grant.

### W2. Direct-charge / checkout metadata carries 2 keys vs analog's 1 (audit Dev 7/8)

- **Files:** `app/models/organization_ai_credit_purchase.rb` (`charge_for_purchase` InvoiceItem + Invoice metadata); `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (checkout `invoice_data.metadata` + session `metadata`).
- **What:** metadata is `{ organization_ai_credit_purchase_id: id, ai_credit_pack_top_up: 'true' }` (reduced from 4 keys to 2).
- **Analog:** metadata is `{ board_wwr_listing_id: id }` — one key serving as BOTH the
  webhook discriminator (presence check) AND the record id.
- **Why it cannot fully match:** OURS uses a SEPARATE boolean discriminator
  (`ai_credit_pack_top_up`) plus the record id, because one-off vs subscription
  metadata is distinguished by separate boolean flags (`ai_credit_pack_top_up` vs
  `ai_credit_pack_subscription`), not by which id key is present. Collapsing to
  id-presence-as-discriminator (true 1-key match) would change the shared webhook
  routing mechanism that also routes the subscription flow — out of scope for a
  one-off audit fix.

> Round-3 update: W2 is now SUPERSEDED. The round-3 fix fully collapsed the metadata
> to id-presence-as-discriminator (true 1-key match): `ai_credit_pack_top_up` was
> removed from every metadata block (InvoiceItem, Invoice, checkout invoice_data,
> checkout session) and the webhook now routes the one-off branch by
> `organization_ai_credit_purchase_id` presence (mirroring the analog's
> `board_wwr_listing_id` presence). Verified safe: only the one-off path stamps
> `organization_ai_credit_purchase_id` into Stripe invoice metadata; the subscription
> path does not, so subscription invoices do not match the new branch. No longer a
> deviation needing a whitelist.

### W3. Checkout-session metadata omits `job_id` present in the analog (audit Dev 9)

- **File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` — `purchase_top_up` checkout path (`payment_intent_data.metadata`, `invoice_creation.invoice_data.metadata`, session `metadata`).
- **What:** OURS' three metadata blocks carry `organization_ai_credit_purchase_id` and `organization_id` (added in round 3), but NOT `job_id`. The analog (`board_wwr_listings_controller.rb#create_checkout_session`) carries `board_wwr_listing_id`, `organization_id`, AND `job_id` in those blocks.
- **Analog:** `payment_intent_data.metadata` / session `metadata` = `{ board_wwr_listing_id, organization_id, job_id }`; `invoice_data.metadata` = `{ board_wwr_listing_id, job_id }`.
- **Why it cannot match:** an AI credit top-up is NOT scoped to a job — it is a per-organization purchase. There is no `Job` record anywhere in the `purchase_top_up` flow (no `params[:job_id]`, no `job` lookup) from which to read a `job_id`. The analog is job-scoped (a listing belongs to a job); OURS is org-scoped. Forced by the data-model difference. `organization_id` and the `payment_intent_data` metadata block WERE matched in round 3; only `job_id` is omitted.

> Round-4 update: `organization_id` was missing from `invoice_data.metadata` in the
> working tree at the start of round 4 (round-3's "matched" claim was stale). Round 4
> re-added `organization_id` to `invoice_data.metadata` and added a `description` to
> `invoice_data` (mirroring the analog's `@final_invoice_description`). Only `job_id`
> remains omitted, for the data-model reason above.

### W4. `broadcast_event` uses `GlobalChannel` / `action:` / `{ organizationId }` instead of analog's `JobChannel` / `event:` / `{ jobId, boardWwrListingId, wwrSlug, publishedAt }` (audit Dev 12)

- **File:** `app/models/organization_ai_credit_purchase.rb` — `broadcast_event`.
- **What:** `GlobalChannel.broadcast_to(user, action: event, payload: { organizationId: organization_id })`.
- **Analog:** `BoardWwrListing#broadcast_event` = `JobChannel.broadcast_to(job, event: event, payload: { jobId:, boardWwrListingId:, wwrSlug:, publishedAt: })`.
- **Why it cannot match:** `JobChannel#subscribed` requires `params[:jobId]` and `stream_for job` — it can ONLY broadcast to a `Job`. An AI credit top-up has no `Job` (org-scoped purchase), and the AI-credit frontend (account billing settings) never subscribes to any `JobChannel`; it listens on `GlobalChannel` (streamed for `current_user`). The `action:` key (vs `event:`) is the GlobalChannel consumer contract — the sibling `broadcast_show_growl` on the same record also uses `GlobalChannel ... action:`, and the GlobalChannel frontend handler dispatches exclusively on `data.action` (every one of its ~25 cases). The payload keys `wwrSlug`/`publishedAt` are WWR-listing columns OURS does not have. Forced by the absence of a `Job` and by the channel contract, not by effort.

> Round-4 update: the round-4 audit re-flagged this channel/key/target switch. The
> channel/key/target/payload portion remains CANNOT-MATCH for the reasons above
> (forced by no `Job` + GlobalChannel's `action:` dispatch contract). BUT round 4
> fixed the one genuinely-fixable, analog-matching gap the deviation contained: the
> analog's `broadcast_event` IS consumed by the frontend (`JobChannel` handler case
> `wwr_listing_published` → `invalidateQueries(["jobs", jobId])`), whereas OURS
> broadcast `AI_CREDIT_TOP_UP_COMPLETE` with NO matching frontend handler case — the
> message hit the `data.action` switch, matched nothing, and fell through to
> `default: break`, so the broadcast→consume→invalidate structure of the analog was
> broken (the websocket refresh did nothing). Round 4 added the missing
> `case "AI_CREDIT_TOP_UP_COMPLETE": queryCache.invalidateQueries(["organizationAiCreditBalance"]); break;`
> to `WebsocketGlobalChannelHandler.tsx`, restoring the analog's
> broadcast-consumed-and-invalidates structure (org-balance query is the OURS
> equivalent of the analog's `["jobs", jobId]` query).

> Round-5 (oneoff-v5) update: the round-5 audit re-flagged the channel/target/key
> switch (`GlobalChannel`/`action:`/`{ organizationId }` vs `JobChannel`/`event:`/
> `{ jobId, boardWwrListingId, wwrSlug, publishedAt }`). Re-verified against the live
> code: `JobChannel#subscribed` does `Job.find(params[:jobId]); stream_for job` — it
> can ONLY stream to a `Job`. The one-off purchase flow has no `Job` (org-scoped), and
> the AI-credit frontend (`WebsocketGlobalChannelHandler`) subscribes to `GlobalChannel`
> (`stream_for current_user`), never to any `JobChannel`; broadcasting on `JobChannel`
> would reach no consumer on the billing page. `GlobalChannel`'s `handleGlobalMessage`
> guards on `data.action != null` and switches on `data.action`, so the `event:`→
> `action:` key is the consumer's payload contract, not a free choice (the sibling
> `broadcast_show_growl` on the same record uses the identical `GlobalChannel ...
> action:` form). Position UNCHANGED: CANNOT-MATCH, forced by the absence of a `Job` +
> GlobalChannel's `action:` dispatch contract, not by effort. No broadcast code change
> in round 5 (already the closest possible match).

> Round-6 (oneoff-v5) update: the round-6 audit re-flagged the channel/key shape. The
> channel (`GlobalChannel` vs `JobChannel`) and top-level key (`action:` vs `event:`)
> remain CANNOT-MATCH for the standing reason above (no `Job` to stream to; the
> AI-credit billing frontend subscribes only to `GlobalChannel`, whose
> `handleGlobalMessage` guards on `data.action != null` and switches on `data.action`,
> so `action:` is the consumer contract, not a free choice). BUT round 6 matched the
> one genuinely-fixable structural gap in the deviation: the analog's payload carries
> the RECORD'S OWN id (`boardWwrListingId: id`) alongside the parent-target id
> (`jobId: job.id`), whereas OURS' payload carried only `organizationId` (the
> parent-target id) and was MISSING the record's own id. Round 6 added
> `organizationAiCreditPurchaseId: id` to the payload so its structure mirrors the
> analog's `{ <parent-id>, <record-own-id>, ... }` shape. The analog's remaining
> payload keys `wwrSlug`/`publishedAt` are `BoardWwrListing` columns with no
> `OrganizationAiCreditPurchase` equivalent (no slug, no publish timestamp on a credit
> purchase), and the frontend handler invalidates the balance query without reading
> the payload, so no further payload key is matchable. Channel/key portion UNCHANGED:
> CANNOT-MATCH, forced by the absence of a `Job` + GlobalChannel's `action:` dispatch
> contract.

### W5. No job-description blank guard before building/charging (audit Dev 4)

- **File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` — `purchase_top_up` and `purchase_top_up_checkout_session`.
- **What:** neither action has a precondition guard analogous to WWR's `render_general_errors(['Job description cannot be blank']) if job.description.blank?`.
- **Analog:** both WWR actions guard on `job.description.blank?` (a listing cannot be published without a job description).
- **Why it cannot match:** there is no `Job` in the AI credit top-up flow (no `params[:job_id]`, no `job` lookup), so there is no `job.description` precondition to validate. The analog's guard protects a job-scoped product; OURS is org-scoped with no equivalent precondition. Forced by the data-model difference, not by effort. The `exists(current_organization.jobs.where(...))` wrapper the analog uses to fetch the job is likewise absent for the same reason.

### W6. Direct-charge authorize passes explicit `:create?` instead of analog's bare `authorize @listing` (audit Dev 1)

- **File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` — `purchase_top_up` (`authorize organization_ai_credit_purchase, :create?`).
- **What:** the record-authorize passes an explicit `:create?` policy symbol.
- **Analog:** `BoardWwrListingsController#create` uses bare `authorize @listing`; Pundit infers the policy method (`create?`) from the action name (`create`).
- **Why it cannot match:** OURS' direct-charge action is the non-RESTful collection route `purchase_top_up`, not the RESTful `create`. Pundit's bare `authorize record` infers the policy method from the action name, so bare `authorize organization_ai_credit_purchase` would look for `OrganizationAiCreditPurchasePolicy#purchase_top_up?`, which does not exist. The explicit `:create?` is required to invoke the same `create?` policy method the analog's bare form resolves. Making it bare like the analog would require renaming the action to `create`, which cascades to `config/routes.rb`, the frontend hook path (`useOrganizationAiCreditPurchase.ts`), and the mutation — out of scope for a one-off audit fix. Forced by the non-RESTful action name, not by effort.

### W7. Direct-charge / checkout build pre-stamps `stripe_amount: 0` and `currency: 'usd'` (audit round-6 Dev 4)

- **File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` — `purchase_top_up` and `purchase_top_up_checkout_session` (`OrganizationAiCreditPurchase.new(... stripe_amount: 0, currency: 'usd')`).
- **What:** both builds set `stripe_amount: 0` and `currency: 'usd'` as placeholders before the charge runs. The real `stripe_amount`/`currency` are stamped later by `charge_for_purchase`'s `update_columns` (direct path) or `ApplyAiCreditPurchase` (checkout path).
- **Analog:** `BoardWwrListingsController#create` / `#create_checkout_session` build the record from `listing_params`/`checkout_listing_params` + `last_updated_by_organization_user` (+ `status`/`stripe_invoice_paid` for checkout) only. `stripe_amount` is left unset until `charge_for_listing`'s `update_columns` stamps it; there is no `currency` column on the listing at all.
- **Why it cannot match:** the `organization_ai_credit_purchases.stripe_amount` column is declared `null: false` (`db/schema.rb:972`) with no DB default, so an INSERT without `stripe_amount` raises a NOT NULL violation. The analog's `board_wwr_listings.stripe_amount` column is nullable (`db/schema.rb`, `t.integer "stripe_amount"` — no `null: false`), which is why the analog can build without it. Matching the analog exactly (drop the pre-stamp) requires a migration making `organization_ai_credit_purchases.stripe_amount` nullable and relaxing the model's `stripe_amount`/`currency` presence validations to fire only once the value is known (after charge) — a schema + shared-validation change (out of scope for a one-off audit fix, and a NOT-NULL/validation change is shared infrastructure requiring owner approval per pipeline failure-pattern #20). `currency` likewise has a DB default of `'usd'` so the build value is redundant, but it is kept alongside `stripe_amount` for symmetry. Forced by the `null: false` schema constraint, not by effort.

### W8. Direct-charge invoice description built from the lookup-key name map, not the analog's plan/discount construction (oneoff-v5 round-1 Dev 1)

- **File:** `app/models/organization_ai_credit_purchase.rb` — `charge_for_purchase` (`description = "AI Credit Top-Up — #{...AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY.dig(stripe_price_lookup_key, :name) || stripe_price_lookup_key}"`).
- **What:** the Stripe `InvoiceItem` description is built from the local `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY[...][:name]` display name (falling back to the raw lookup key).
- **Analog:** `BoardWwrListing#charge_for_listing` (`board_wwr_listing.rb:124-126`) builds `@description` from the listing `plan` (e.g. `"WWR Job Listing with #{plan.capitalize} upgrade - #{job.title}"`) then `@final_description` appending `"(#{wwr_percent_off}% WWR discount included)"` when `wwr_percent_off.positive?`.
- **Why it cannot match:** the analog's description is composed from two constructs OURS does not have — a `plan` enum (`standard/good/better/best`) and a `wwr_percent_off` org-settings discount — plus a `job.title` (no `Job` in the org-scoped AI credit flow). AI credit pricing follows the SUBSCRIPTION analog (SANCTIONED #6): prices/products live in Stripe by lookup key, with no plan tiers and no percent-off discount, so there is no `@final_description` discount clause to build. The closest structural match — a single base description with no discount append — is exactly what OURS produces, derived from the only available identifier (the lookup-key display name). Forced by the AI-credit pricing data model, not by effort.

> Note: oneoff-v5 round-1 Dev 2 (the `grant_credits` balance notification-flag reset)
> is the same deviation already whitelisted as **W1** above — no separate entry added.

### W9. Checkout `line_items` carries no Stripe-hosted product name/description, where the analog's does (oneoff-v5 round-2 Dev 5)

- **File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` — `purchase_top_up_checkout_session` (`line_items: [{ price: price.id, quantity: 1 }]`).
- **What:** OURS' checkout line item references a pre-built Stripe Price by id (`price: price.id`) and therefore carries no inline `product_data.name` / `product_data.description`. The Stripe-hosted checkout page shows the line item named/described from the Price's associated Product (configured in the Stripe dashboard), not from app-supplied strings.
- **Analog:** `BoardWwrListingsController#create_checkout_session` (`board_wwr_listings_controller.rb:83-92`) builds `line_items[0].price_data.product_data` inline with `name: "#{job.title} - We Work Remotely Job Listing"` and `description: @final_description`.
- **Why it cannot match:** SANCTIONED deviation #4/#6 mandates `line_items: [{ price: price.id, quantity: 1 }]` (AI credit prices/products live in Stripe by lookup key, not as inline `price_data` with hardcoded cents). Stripe's API rejects a single line item that mixes `price:` with `price_data`/`product_data` — they are mutually exclusive. Consequently the line-item name/description CANNOT be supplied inline; it lives on the Stripe Price's Product (dashboard-managed). The product-description content the analog puts on the line item is still preserved in OURS' `invoice_data.description` (now `@final_invoice_description`, mirroring the analog's invoice description). Forced by sanctioned deviation #4/#6, not by effort.

### W10. Frontend top-up error handler omits `setIsPurchasing(false)` and `setErrors(...)` that the analog has (oneoff-v5 round-3 Dev 3)

- **File:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` — `handlePurchaseError`.
- **What:** OURS' top-up onError handler logs (`window.logger`) and conditionally toasts the `general` error, matching the analog, but does NOT call `setIsPurchasing(false)` or `setErrors(response.data.errors)`.
- **Analog:** `JobDistributionWeWorkRemotely.tsx:273-287` `handleCreateBoardWwrListing` onError runs `setIsPurchasing(false)`, `setErrors(response.data.errors)`, `window.logger(...)`, then conditional `addToast({ title, kind: "warning" })`.
- **Why it cannot match:** OURS' `AiCreditSubscription` component carries neither piece of state. `isPurchasing` is derived from the mutation's `isLoading` (`usePurchaseAiCreditTopUp`, line 46), which React Query resets to `false` automatically on settle — there is no `useState`-backed `isPurchasing`/`setIsPurchasing` to call. And the component has no error state (`errors`/`setErrors`) at all: it surfaces errors only via toast, with no inline error-render path, whereas the analog's WWR component renders form-field errors from a `setErrors` state. Calling `setIsPurchasing(false)` / `setErrors(...)` would require fabricating two `useState`s (and, for `setErrors`, a consuming render path) the component does not have — an unscoped addition. Forced by OURS' component shape (mutation-derived loading + toast-only error surfacing) vs the analog's hand-managed loading + inline error rendering, not by effort. The matchable parts of the analog's handler (the `window.logger` call, the `if (errors.general != undefined)` toast guard, and removal of the non-analog `delay: 10000`) WERE applied.

> Note: oneoff-v5 round-3 Dev 2 (the `grant_credits` balance notification-flag reset,
> `organization_ai_credit_purchase.rb` `balance.update_columns(sent_low_notification_since_increase: false, sent_zero_notification_since_increase: false)`)
> was re-reported by the round-3 audit as having "no analog" and "NOT listed in
> SANCTIONED-DEVIATIONS.md." This is a CONFLICT with the authoritative list: the step IS
> explicitly SANCTIONED as item #9 ("Balance notification-suppression flag reset on credit
> grant"), and is already whitelisted here as W1. No code change was made — removing
> sanctioned code would destroy approved work and re-break the low/zero-credit re-warning
> behavior. Surfaced for owner resolution of the audit-vs-sanctioned-list disagreement.

### W11. Frontend top-up `onSuccess` is empty where the analog's runs `setErrors(null)` / `setIsDirty(false)` (oneoff-v5 round-4 Dev 3)

- **File:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` — `purchaseTopUp`'s direct-charge mutation `onSuccess: () => {}`.
- **What:** OURS' direct-charge `onSuccess` is an empty arrow — no post-success state cleanup.
- **Analog:** `JobDistributionWeWorkRemotely.tsx:268-272` `handleCreateBoardWwrListing`'s `onSuccess` runs `setErrors(null)` and `setIsDirty(false)`.
- **Why it cannot match:** the two states the analog resets do not exist in OURS' component. The analog's `errors` (`useState(null)`, line 157) holds inline form-validation errors rendered in the WWR listing-configuration form, and `isDirty` (`useState(false)`, line 158) tracks unsaved edits to that editable form (set true on field change, line 384; guards save/navigation). `AiCreditSubscription`'s top-up is a buy-a-pack button, NOT an editable form: it has no `errors` state (errors surface only as toasts via `handlePurchaseError`, no inline error-render path) and no `isDirty` state (no editable fields to dirty). There is no state to reset, so `onSuccess` is legitimately empty; the mutation's own `onSuccess` (in `usePurchaseAiCreditTopUp`) already invalidates the balance query, and the success growl is emitted server-side from `grant_credits`. Calling `setErrors(null)`/`setIsDirty(false)` would require fabricating two `useState`s (and, for `errors`, a consuming render path) the component does not have — an unscoped addition. Forced by OURS' component shape (purchase button vs the analog's editable, dirty-tracked, inline-error-rendering form), not by effort. (Parallels W10, which covers the same component's `onError` handler omitting `setIsPurchasing(false)`/`setErrors(...)` for the same structural reason.)

### W12. Checkout-session record build omits the analog's `status: 'approved'` listing-lifecycle stamp (oneoff-v5 round-8 Dev 1)

- **File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` — `purchase_top_up_checkout_session` (build at lines 123-132).
- **What:** OURS' checkout build sets `{ organization:, last_updated_by_organization_user:, kind:, stripe_price_lookup_key:, one_off_credits_granted:, stripe_amount: 0, currency:, stripe_invoice_paid: false }` with NO `status` field.
- **Analog:** `BoardWwrListingsController#create_checkout_session` (`board_wwr_listings_controller.rb:59-63`) merges `{ last_updated_by_organization_user:, status: 'approved', stripe_invoice_paid: false }`, explicitly stamping the listing-lifecycle status to `approved` on the awaiting-payment record.
- **Why it cannot match:** the analog's `status` is the WeWorkRemotely **listing-lifecycle** enum (`board_wwr_listings.status`, `integer default: 0`) — it gates whether a listing is publishable to the external WWR service once payment clears, so the awaiting-payment record is pre-stamped `approved`. `OrganizationAiCreditPurchase` has NO listing-lifecycle: the `organization_ai_credit_purchases` table has no general `status` column (only `subscription_status`, an integer enum for Stripe subscription state, irrelevant to a one-off purchase), and there is no enumerated counterpart to `approved` — credits are granted once, never published to a third party, and never expire as a listing. The record's only lifecycle marker is `stripe_invoice_paid` (false on the checkout/awaiting-payment build, set true after payment), which OURS already stamps `false` here — the same companion flag the analog also sets alongside `status: 'approved'`. Adding a `status` column or enum value to mirror the analog would be an unscoped shared-infrastructure change (a new column/enum solely to "match a finding"), which the failure-pattern rules prohibit. Closest fix is already present: `stripe_invoice_paid: false` is the lifecycle stamp our data model actually has. No code change made. Forced by the data-model difference (external publishable listing-lifecycle vs one-shot credit grant), not by effort.
