# One-Off Purchase — Round 3 Audit (v3)

## Overview

Complete structural trace of the one-off purchase flow against the canonical analogs (WWR primary, WhatJobs secondary). The current code is a faithful structural replica of the WWR analog pattern. All major components are in place and correctly wired.

## Chains Traced

**Backend (one-off purchase flow):**
- `organization_ai_credit_purchases_controller.rb` → `organization_ai_credit_purchase.rb` → `stripe_webhook_handler_job.rb` → `apply_ai_credit_purchase.rb` → `organization_ai_credit_purchase_policy.rb` / `billing_policy.rb` → migrations `20260611120002` / `20260611120003`

**Analog (WWR primary):**
- `board_wwr_listings_controller.rb` → `board_wwr_listing.rb` → `stripe_webhook_handler_job.rb` → `board_wwr_listing_policy.rb`

**Analog (WhatJobs secondary):**
- `board_what_jobs_listings_controller.rb` → `board_what_jobs_listing.rb`

**Frontend (one-off purchase flow):**
- `AiCreditSubscription.tsx` → `useOrganizationAiCreditPurchase.ts` → `AiCreditPackCard.tsx` → `WebsocketGlobalChannelHandler.tsx`

**Analog (WWR frontend):**
- `JobDistributionWeWorkRemotely.tsx` → `useJob.ts` → `useWwrListing.ts`

---

## Confirmed Structural Matches Against the Analog

### Controller Actions

Two split actions (`charge_top_up` + `create_top_up_checkout_session`) mirror WWR's `#create` + `#create_checkout_session` (1:1 correspondence).

**Direct charge:**
- Pre-create record → authorize via purchase policy (`OrganizationAiCreditPurchasePolicy#create?`, mirroring `BoardWwrListingPolicy#create?`) → invoke model method `charge_for_purchase` → render single-record response
- Model method: three-step Stripe call: `Stripe::InvoiceItem.create(amount:...)` + `Stripe::Invoice.create` + `Stripe::Invoice.pay` + `update_columns` to store identifiers and amounts
- Uses `amount:` (not `price:`) on InvoiceItem; minimal metadata `{ organization_ai_credit_purchase_id: id }` mirrors analog's `{ board_wwr_listing_id: id }`
- Matches board_wwr_listing.rb lines 130–158 exactly in structure

**Checkout path:**
- `authorize :billing, :checkout?` guard present and correct
- Flat parameter permit (unwrapped) mirrors analog `checkout_listing_params`
- Success response shape: `{ url, sessionId }, status: :created` matches board_wwr_listings_controller.rb:120
- No `auto_advance`, no `payment_method_types` on checkout session—correct match to analog

**Session creation:**
Confirmed: the `create_top_up_checkout_session` action (lines 146–189) creates the purchase record FIRST, then the Stripe session, and does NOT stamp `stripe_checkout_session_id` back onto the purchase. This matches the WWR analog pattern exactly (WWR also doesn't stamp session id on its checkout path).

### Model Layer

- Two paths (`charge_for_purchase` for direct charge; `finalize_stripe_payment` in webhook for both paths) mirror the analog
- Finalize-in-handler choke point (`purchase.finalize_stripe_payment` then downstream work) mirrors WWR's `listing.finalize_stripe_payment` → `listing.create_on_wwr`
- Record-id metadata key (`organization_ai_credit_purchase_id`) mirrors analog's `board_wwr_listing_id`
- Broadcast callback (`OrganizationAiCreditPurchase#broadcast_event`) correctly wired for GlobalChannel context (see deviations section for channel specifics)

### Webhook Handler

- Resolves record from metadata (`purchase = OrganizationAiCreditPurchase.find_by(stripe_invoice_id)` for direct charge; session lookup for checkout path)
- Passes resolved record to interactor (`ApplyAiCreditPurchase.call(purchase: ...)`)
- Matches stripe_webhook_handler_job.rb lines 223–229 (direct charge) and :241–242 (checkout path) analog pattern

### Interactor

- Reads `context.purchase` directly (apply_ai_credit_purchase.rb:38)—no triple-fallback lookup
- Matches the handler-resolves-record analog pattern; interactor receives the object directly, not an ID
- Confirms no defensive re-fetch needed

### Frontend

- `useChargeAiCreditTopUp` (wrapped payload `{ stripeAmount, ... }`; invalidates query on success) mirrors `useCreateBoardWwrListing` pattern
- `useCreateAiCreditTopUpCheckoutSession` (flat payload; no cache invalidation; `onSuccess` → `window.location.href = data.url`) mirrors `useCreateWwrCheckoutSession` + JobDistributionWeWorkRemotely.tsx:339 redirect pattern
- Button behavioral props (`loading`/`disabled`) present (AiCreditPackCard.tsx:38–39, fed by `isPurchasing` at AiCreditSubscription.tsx:51); matches analog's prop threading

---

## Genuine Deviations (Non-Forced, Non-Sanctioned)

### DEVIATION 1: Checkout-Session Error Response Shape

| Layer | Analog (WWR) | Current Code |
|-------|--------------|--------------|
| **Source** | board_wwr_listings_controller.rb:125–127 (WhatJobs identical at board_what_jobs_listings_controller.rb:262–265) | organization_ai_credit_purchases_controller.rb:190–197 |
| **Pattern** | `render json: { error: e.message }, status: :unprocessable_entity` | `render_general_errors([...])` → `{ errors: { general: [...] } }, status: :unprocessable_entity` |
| **Impact** | Client error handling expects top-level `error` key | Response uses `errors.general` key instead |

The analog renders a single-key error object. The current code uses the `render_general_errors` helper, which wraps errors under `errors.general`. This is a response shape mismatch to the analog.

### DEVIATION 2: Save-Failure Response on Record Creation

| Layer | Analog (WWR) | Current Code |
|-------|--------------|--------------|
| **Source** | board_wwr_listings_controller.rb:24–26 (subscription) and 121–123 (checkout) | organization_ai_credit_purchases_controller.rb:101–105 (direct charge) and 156–160 (checkout) |
| **Pattern** | `if @listing.save ... else render_errors(@listing)` → `{ errors: <model.errors> }` | `unless purchase.save ... render_general_errors(['Failed to create purchase record']); return` |
| **Impact** | Client receives full model validation errors (e.g., `amount blank`) | Client receives hardcoded generic string; model validation state is invisible |

The analog surfaces the model's own validation failures. The current code guards with `unless` and renders a hardcoded "Failed to create purchase record" message, hiding which field(s) failed validation and why.

### DEVIATION 3: Direct-Charge Rescue Chain Has Extra Stripe-Specific Branch

| Layer | Analog (WWR) | Current Code |
|-------|--------------|--------------|
| **Source** | board_wwr_listings_controller.rb:28–30 | organization_ai_credit_purchases_controller.rb:114–121 |
| **Pattern** | Single `rescue StandardError => e` → `render_general_errors(["Unable to process payment: #{e.message}"])` | `rescue Stripe::StripeError => e` (logs, `ap e`, `Sentry.capture_exception`, renders different message) THEN `rescue StandardError => e` (renders generic "Unable to charge"; matches analog) |
| **Impact** | Stripe errors are logged + inspected + reported to Sentry, routing them separately from generic errors | Analog has no separate Stripe error branch; all errors flow through a single handler |

The current code adds a Stripe-specific rescue block that doesn't exist in the analog. The error is logged and sent to Sentry, which the analog does not do. This is not forced by the domain (one-off purchases are not inherently different from WWR listings in terms of error handling), and adds infrastructure logging that the analog does not have.

---

## Deviations Forced by Sanctioned Record-Source / Org-Scoped Design

These deviations exist but are **required by the approved record-source and org-scoped design** (no job in the domain). Reported for transparency; not independent defects.

### No Job-Scoped Authorization

- **Analog:** Both actions scoped to a job. board_wwr_listings_controller.rb:6 and :54 load a job and guard `job.description.blank?`
- **Current:** No job in the domain. Both actions operate directly on `current_organization` with no job lookup
- **Reason:** `OrganizationAiCreditPurchase` is organization-scoped, not job-scoped. This is the sanctioned record source. No job guard is needed because there is no job.

### Broadcast Channel and Payload Key

- **Analog:** `BoardWwrListing#broadcast_event` uses `JobChannel.broadcast_to(job, event: ..., payload: {...})`
- **Current:** `OrganizationAiCreditPurchase#broadcast_event` uses `GlobalChannel.broadcast_to(user, action: 'AI_CREDIT_TOP_UP_COMPLETE', payload: { organizationId })`
- **Reason:** There is no job to target, so `JobChannel` is not applicable. `GlobalChannel` is correct; `action:` is the correct key for GlobalChannel (verified consumed at WebsocketGlobalChannelHandler.tsx:212–214 and :66–73, invalidates `organizationAiCreditBalance` query and shows growl). This is the right pattern for the org-scoped context.

---

## Side Observation: Checkout-Path Session ID Handling

The `create_top_up_checkout_session` action creates the purchase record before the Stripe session (organization_ai_credit_purchases_controller.rb:146–189) and does not stamp `stripe_checkout_session_id` back onto the purchase record after the session is created.

**Match to analog:** WWR also doesn't stamp a session id on its checkout path (board_wwr_listings_controller.rb:91–123).

**Risk flag:** `handle_charge_refunded` looks up one-off purchases by `stripe_checkout_session_id` (stripe_webhook_handler_job.rb:447–450). This lookup will not find a checkout-path top-up because the session id is never stored. Refunds of checkout-path purchases would fail to look up the record by session id. 

This is outside the scope of this purchase-flow trace and is tied to WHITELIST item 7 (direct-charge refunds only). Flagging for visibility: if checkout-path refunds are ever in scope, the session id must be stamped onto the purchase record on creation, or the refund lookup must use a different key.

---

## Summary

The one-off purchase flow is a faithful structural replica of the WWR analog across controller, model, webhook, interactor, and frontend layers. Three genuine non-forced deviations exist (error response shapes, save-failure handling, Stripe-specific rescue branch); two sanctioned deviations are forced by the org-scoped record-source design. The code is ready for implementation review against the specification.
