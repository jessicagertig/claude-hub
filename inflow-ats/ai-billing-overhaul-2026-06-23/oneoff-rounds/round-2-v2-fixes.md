# One-Off Purchase — Round 2 Fixes (v2)

## organization_ai_credit_purchase.rb

Zero stale references; all 18 references renamed. The rename count matches the original grep exactly (1 model def + 1 controller call + 10 model-spec + 1 webhook-spec comment + 5 controller-spec = 18).

Deviation #1 fixed. The direct-charge model method was renamed `charge_default_payment_method` → `charge_for_purchase` to match the analog's `charge_for_<record>` verb pattern (`BoardWwrListing#charge_for_listing` at `board_wwr_listing.rb:112`; record noun `purchase` for `OrganizationAiCreditPurchase`).

Files changed:
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/models/organization_ai_credit_purchase.rb:124` — method definition (doc comment above it already said it "Mirrors BoardWwrListing#charge_for_listing"; left intact, still accurate)
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:108` — the single caller
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/spec/models/organization_ai_credit_purchase_charge_spec.rb` — 10 references (comment header line 5, `describe` line 45, 8 call sites)
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/spec/controllers/api/v1/organization_ai_credit_purchases_purchase_top_up_spec.rb` — 5 references (comment line 11, 4 stub/expectation sites)
- `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/spec/jobs/stripe_webhook_handler_ai_credits_spec.rb:179` — 1 comment reference

Frontend: no changes needed and none made — `charge_default_payment_method` was a backend-internal method name with zero frontend references (verified by grep over `app/javascript/`). The response key the frontend reads is unchanged (the card-on-file path renders the serialized purchase via `OrganizationAiCreditPurchaseSerializer`); only the Ruby method name changed.

**WHITELIST:** None.
**REVERT:** None.

---

## organization_ai_credit_purchases_controller.rb

Confirmed:
- The only remaining `stripe_checkout_session_id` write in the controller is at line 49, which is the **subscription `#checkout`** path (not the one-off `purchase_top_up`). That's correct and untouched — the subscription path legitimately needs it (its model validation at line 91-93 allows `stripe_subscription_id` to be blank when `stripe_checkout_session_id` is present).
- The frontend `AiCreditSubscription.tsx` reads `data.url` (line 187, shifted from 164 by the file's own edits) and redirects. The checkout path still returns `{ url: session.url, sessionId: session.id }`, so the frontend is unaffected. No frontend change is needed for any of the four deviations.

All four deviations are fixed and match the analog. No frontend code change was required (the frontend response contract is unchanged — still `{ url, sessionId }` for checkout). One controller spec assertion that encoded the removed deviation was updated to match the analog-matching behavior.

### Changed

All changes in `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`, `purchase_top_up` action:

1. **Deviation 1 (StandardError rescue):** Added a `rescue StandardError => e` block after the existing `rescue Stripe::StripeError` (lines 154-156), mirroring the analog's direct-charge `#create` rescue (`board_wwr_listings_controller.rb:28-31`): logs `"Failed to charge for AI credit top-up: #{e.message}"` and renders `["Unable to process payment: #{e.message}"]`. The Stripe rescue stays first (more specific) so Stripe errors keep their Sentry handling; non-Stripe errors in `charge_for_purchase`/checkout now get caught instead of escaping.

2. **Deviation 2 (extra post-session write):** Removed the `unless purchase.update(stripe_checkout_session_id: session.id) ... end` block (was lines 147-151). The action now renders immediately after `Stripe::Checkout::Session.create`, exactly like the analog checkout path. Verified safe: the `invoice.paid` webhook (`stripe_webhook_handler_job.rb:212-220`) looks the purchase up by `organization_ai_credit_purchase_id` metadata (carried in `invoice_creation.invoice_data.metadata`) and does not pass `checkout_session_id` to `ApplyAiCreditPurchase` at all — so dropping the stamp changes nothing in the grant flow. The subscription `#checkout` path's own `stripe_checkout_session_id` write (line 49) is untouched.

3. **Deviation 3 (stripe_invoice_paid default):** Added `stripe_invoice_paid: false` to the `OrganizationAiCreditPurchase.new(...)` build params (line 96), matching the analog's explicit `stripe_invoice_paid: false` (`board_wwr_listings_controller.rb:62`). Column exists via migration `20260611120002`.

4. **Deviation 4 (session_id in URLs):** Appended `&session_id={CHECKOUT_SESSION_ID}` to both `success_url` and `cancel_url` (lines 144-145), matching the analog (`board_wwr_listings_controller.rb:116-117`).

Spec updated (consequence of Deviation 2): `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/spec/controllers/api/v1/organization_ai_credit_purchases_purchase_top_up_spec.rb` — the test that asserted `purchase.stripe_checkout_session_id).to eq 'cs_top_up_test'` was renamed and changed to `expect(purchase.stripe_checkout_session_id).to be_nil`, since the analog never writes it. This test encoded the deviation being removed.

Frontend: no change required. `purchase_top_up` still returns `{ url, sessionId }`; `AiCreditSubscription.tsx` reads `data.url` and redirects, unaffected. Nothing in the frontend reads `ai_credit_top_up_success`/`ai_credit_top_up_cancel` or the appended `session_id` (the AI-credit flow is fully webhook/metadata-driven), so adding the placeholder is harmless and matches the analog.

**REVERT:** None.
**WHITELIST:** None for the 4 deviations.

### Pre-existing defects found (not in scope, not touched)

- **Method-name mismatch:** controller calls `purchase.charge_for_purchase` (line 109), but the trace/spec docstrings reference `charge_default_payment_method`. The model defines only `charge_for_purchase` (`organization_ai_credit_purchase.rb:124`), so the call resolves — but the docstrings/trace are stale on the name.
- **Stale `amount_cents_paid` in specs:** `spec/models/organization_ai_credit_purchase_spec.rb` (lines 38, 60-66) and `spec/interactors/apply_ai_credit_purchase_spec.rb` (line ~18) use `amount_cents_paid`, which migration `20260611120002` renamed to `stripe_amount`. These fixtures will fail independently of my changes. The model spec's "requires stripe_checkout_session_id for one_off" (line 47-48) is also stale — the model has no such validation (only a subscription-conditional one at lines 91-93); that test currently "passes" only because the renamed-column fixture makes the record invalid for the wrong reason.
- **`charged: true` contract drift (controller spec):** `organization_ai_credit_purchases_purchase_top_up_spec.rb` lines 88-93 assert `json_response['charged']).to eq true`, but the card-on-file branch returns `render_one(purchase, ...)` (a serialized purchase), not `{ charged: true }`. Pre-existing, unrelated to the 4 deviations.

---

## stripe_webhook_handler_job.rb

`finalize_stripe_payment` now appears only once in the interactor — inside `apply_subscription` (line 134), which I correctly left untouched (the subscription path was NOT in the deviation report; the analog being matched is the one-off purchase). `apply_one_off` no longer calls it; the handler does.

Let me do a final confirmation that the whole `handle_stripe_event` still parses and that I haven't disturbed the WWR/WhatJobs branches that immediately follow. Syntax already passed. Let me also verify there are no other references in `app/` that call `ApplyAiCreditPurchase` for one-off and would now miss finalize (only the handler does, and it now finalizes). Already confirmed: the only one-off caller is the handler.

Summary of verification status: the change is structurally correct and minimal. The full spec suite for these files is currently red due to a PRE-EXISTING, unrelated `amount_cents_paid` → `stripe_amount` rename that left the spec files stale (every example dies at `create!(amount_cents_paid:)` before reaching my code). That is outside this deviation's scope (fixing it would be scope creep across 32 examples in multiple files, touching the rename rather than the finalize-location deviation). I did not modify it. My two edits pass `ruby -c` and preserve all behavior that the specs (when fixed) assert.

### Changed

Fixed the single deviation: `finalize_stripe_payment` for the one-off AI credit top-up now runs IN-HANDLER (the choke point), mirroring the WWR analog (`listing.finalize_stripe_payment` at `stripe_webhook_handler_job.rb:239`), instead of inside `ApplyAiCreditPurchase`.

1. `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/jobs/stripe_webhook_handler_job.rb` (`invoice.paid` → `ai_credit_pack_top_up` branch, lines 212-230)
   - Captured the interactor result: `result = ApplyAiCreditPurchase.call(...)`.
   - Added `result.purchase&.finalize_stripe_payment` after the call — finalize now happens in the handler, like the WWR branch.

2. `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/interactors/apply_ai_credit_purchase.rb` (`apply_one_off`, line ~73)
   - Removed `existing.finalize_stripe_payment` (replaced with a NOTE comment). The interactor now only grants credits — the downstream business work — exactly like `BoardWwrListing#create_on_wwr`, which does not finalize the payment. `apply_subscription`'s `finalize_stripe_payment` was left untouched (subscription path is not part of this one-off deviation).

### Why `result.purchase&.finalize_stripe_payment` rather than resolving+finalizing before the call

The WWR analog resolves the record by a single always-present metadata id (`board_wwr_listing_id`) then does `finalize` → `create_on_wwr`. OURS cannot resolve by `organization_ai_credit_purchase_id` alone: the spec-locked direct-charge and race cases supply no metadata id and require the interactor's `invoice_id`/`checkout_session_id` fallbacks. The interactor is OUR canonical record resolver and sets `context.purchase` on every found path (including the grant-once early return). Finalizing `result.purchase` reuses that single resolution (no duplication, no divergence, preserves every fallback) while moving the finalize to the handler. `finalize_stripe_payment` is `update_columns(stripe_invoice_paid: true)` — idempotent and independent of granting (the grant-once guard keys off the ledger row, not `stripe_invoice_paid`), so running it after the grant call is behaviorally identical to the analog's finalize-first ordering.

### Verification

- `ruby -c` passes on both edited files.
- No spec asserts the one-off interactor sets `stripe_invoice_paid`, and no spec asserts the webhook sets it — so relocating finalize breaks no assertion (the only `stripe_invoice_paid` spec is the model double-charge guard in `organization_ai_credit_purchase_charge_spec.rb:94-95`, unaffected).
- I could NOT run the specs green: the entire AI-credit spec suite (32/32 in the two relevant files) is PRE-EXISTING RED, failing at record creation with `ActiveModel::UnknownAttributeError: unknown attribute 'amount_cents_paid'`. Migration `20260611120002` renamed `amount_cents_paid` → `stripe_amount` (test DB shows both new migrations `up`), but the spec files and `db/schema.rb` were never updated. Every example dies before reaching my code. This is unrelated to the finalize-location deviation and fixing it (updating `amount_cents_paid` across many specs + dumping schema) would be out-of-scope scope creep, so I did not touch it.

**WHITELIST:** None.
**REVERT:** None.

### Adjacent observation (not changed, flagging only)

The working tree I started from had already dropped the `checkout_session_id` lookup + `Stripe::Checkout::Session.list(payment_intent:)` that HEAD passes to the interactor, so the webhook now resolves one-offs by `purchase_id` → `invoice_id` only (the interactor's `checkout_session_id` fallback is reachable only from direct interactor specs). That pre-existed my edit; I preserved it and did not alter it.

---

## useOrganizationAiCreditPurchase.ts

Only 3 warnings (0 errors), and all 3 are **pre-existing** unused-variable warnings unrelated to my change: `isLoadingBalance` (line 29), `isLoadingSubscription` (line 30), and `subscribe` (line 37) — none of which I introduced or touched (they predate my edits; my changes were at lines 11-12, 46-51, 163-204). The variables I added (`chargeTopUp`, `createTopUpCheckoutSession`, `isChargingTopUp`, `isCreatingTopUpCheckoutSession`, `isPurchasing`) are all consumed, so they produce no warnings.

The fix is complete and verified. Let me produce the final summary.

### Summary

I fixed the deviation by splitting the single combined top-up endpoint into two endpoints, matching the WWR analog's structure (`BoardWwrListingsController#create` direct-charge + `#create_checkout_session` no-card; `useWwrListing.ts` checkout hook + `useJob.ts` direct-charge hook). Backend and frontend were changed together.

**Traced chain:** `useOrganizationAiCreditPurchase.ts` → `AiCreditSubscription.tsx` / `AccountBillingAiCredits.tsx` (callers) → `organization_ai_credit_purchases_controller.rb` (`purchase_top_up`) → `config/routes.rb`; analog `useWwrListing.ts` + `useJob.ts:91,278` → `board_wwr_listings_controller.rb` (`#create`, `#create_checkout_session`) → `JobDistributionWeWorkRemotely.tsx:247-351` (frontend branch).

### Files changed (all absolute)

1. `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/config/routes.rb` — replaced `post :purchase_top_up` with `post :charge_top_up` and `post :create_top_up_checkout_session`.

2. `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` — split the single `purchase_top_up` action (which branched internally on `stripe_default_payment_method_on_file`) into two actions, mirroring the analog's two-action split:
   - `charge_top_up` (mirrors `BoardWwrListingsController#create`): validate lookup_key → resolve price → pre-create record → `purchase.charge_for_purchase` → `render_one(serializer)`.
   - `create_top_up_checkout_session` (mirrors `#create_checkout_session`): validate → resolve price → pre-create record → `Stripe::Checkout::Session.create` → `render json: { url:, sessionId: }, status: :created`.
   Preserved the working-tree behaviors already present (the `stripe_invoice_paid: false` field, `&session_id={CHECKOUT_SESSION_ID}` URLs, the `rescue StandardError` block, and the no-session-id-stamping decision).

3. `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` — replaced the single `purchaseAiCreditTopUp`/`usePurchaseAiCreditTopUp` with two: `chargeAiCreditTopUp`/`useChargeAiCreditTopUp` (→ `charge_top_up`, mirrors `useCreateBoardWwrListing`) and `createAiCreditTopUpCheckoutSession`/`useCreateAiCreditTopUpCheckoutSession` (→ `create_top_up_checkout_session`, mirrors `useCreateWwrCheckoutSession`). Updated exports.

4. `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` — the live caller (rendered via `OrganizationAiBilling.tsx`). It already had the two-handler shape (`handleCreateTopUpDirectCharge` / `handleCreateTopUpCheckoutSession`) but both still called the single endpoint; pointed them at the two distinct hooks. The card-vs-no-card branch in `handleBuyPack` (which decides confirm-modal-then-direct-charge vs checkout-redirect) now drives two distinct endpoints, exactly mirroring `JobDistributionWeWorkRemotely.tsx`'s `createOrUpdateWwrListing`.

5. `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingAiCredits.tsx` — repointed to `useCreateAiCreditTopUpCheckoutSession`. See WHITELIST below.

6. `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/spec/controllers/api/v1/organization_ai_credit_purchases_purchase_top_up_spec.rb` — rewrote from one `describe 'POST #purchase_top_up'` into `describe 'POST #charge_top_up'` and `describe 'POST #create_top_up_checkout_session'`, each with its own happy path, invalid-key, missing-price, and Stripe-error contexts. Fixed a stale assertion (`json_response['charged']` → serialized-purchase shape, since the direct-charge path renders `render_one`). **17 examples, 0 failures.**

### Verification
- `tsc --noEmit`: zero type errors in any changed file; the removed `usePurchaseAiCreditTopUp` export is referenced nowhere.
- `eslint`: 0 errors (3 pre-existing unused-var warnings in `AiCreditSubscription.tsx` lines 29/30/37, not introduced by me).
- Controller spec: 17 examples, 0 failures. `ruby -c` on controller: Syntax OK.
- Repo-wide grep: no stale `purchase_top_up` / `purchaseAiCreditTopUp` / `usePurchaseAiCreditTopUp` references remain except one comment (see below).

### WHITELIST
- **`AccountBillingAiCredits.tsx` — repointed only to the no-card checkout-session hook, NOT given a card-on-file direct-charge branch**: This component is not rendered anywhere (dead/legacy — only `AiCreditSubscription` is mounted, via `OrganizationAiBilling.tsx`), and it never branched on payment method (it only ever read `data.url` and showed a redirect toast — i.e., the no-card checkout shape). Adding a card-on-file direct-charge path here would require inventing confirm-modal UX not in scope, and a direct charge without a confirmation modal would violate the sanctioned-deviation rule ("Confirm modal on direct charge ... are the ONLY acceptable divergences"). Repointing it to `useCreateAiCreditTopUpCheckoutSession` preserves its exact existing behavior and keeps it compiling. The live top-up UI (`AiCreditSubscription.tsx`) gets the full analog-matching card-vs-no-card split.

### Notes (out of scope, not changed)
- `AccountBillingAiCredits.tsx:31` has a comment referencing `AiCreditPolicy#purchase_top_up?` — that policy method does not exist (the real gate is `BillingPolicy#checkout?`); the comment was already inaccurate before my change and names a policy, not the endpoint/hook I renamed. Left untouched to avoid unscoped edits.
- 32 pre-existing failures in `apply_ai_credit_purchase_spec.rb`, `stripe_webhook_handler_ai_credits_spec.rb`, and `organization_ai_credit_purchase_charge_spec.rb` are caused by `ActiveModel::UnknownAttributeError: unknown attribute 'amount_cents_paid'` — those specs reference the old column name that migration `20260611120002` renamed to `stripe_amount`. These are pre-existing staleness in other agents' in-progress work, in files I did not touch, unrelated to this deviation.

---

## AiCreditSubscription.tsx

The change is complete and clean. Here is my report.

### Changed

File: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`

Split the single `purchaseTopUp` function (which had one onSuccess that branched on `data.url`) into two separate handlers, matching the analog's structure where `JobDistributionWeWorkRemotely.tsx` splits the two payment paths into `handleCreateBoardWwrListing` (direct charge) and `handleCreateCheckoutSession`:

1. `handleCreateTopUpDirectCharge(pack)` — onSuccess inspects NO response fields (empty body), mirroring the analog's direct-charge handler `handleCreateBoardWwrListing` onSuccess at JobDistributionWeWorkRemotely.tsx:269-272 (which only did `setErrors(null); setIsDirty(false)` — form-state clears that don't exist in our component, since AiCreditSubscription has no local form state).
2. `handleCreateTopUpCheckoutSession(pack)` — onSuccess reads only `data.url` and redirects, mirroring the analog's `handleCreateCheckoutSession` onSuccess at JobDistributionWeWorkRemotely.tsx:337-340 (`window.location.href = data.url`).

`handleBuyPack` already branched on `currentOrganization.stripeDefaultPaymentMethodOnFile` (exactly like the analog's `createOrUpdateWwrListing` branches on `hasPaymentMethod` at line 247-257), so it now dispatches to the two new handlers instead of calling the merged `purchaseTopUp`.

The removed `data.charged` reference: the field never existed in the actual backend response. The current backend `purchase_top_up` (organization_ai_credit_purchases_controller.rb:68) returns `render_one(...serializer...)` for the direct-charge path (line 109) and `{ url, sessionId }` for the checkout path (line 153). The `{ charged: true }` shape the deviation mentions is described in the stale trace but is not in the current code, so no backend response-key change was needed. The direct-charge onSuccess now correctly reads nothing (the serialized purchase is ignored), and the checkout onSuccess reads `url`, which matches the backend's actual `url` key.

### Verification
- ESLint on the file: 0 errors (3 pre-existing unused-var warnings on lines 28/29/36, untouched by this change).
- `grep purchaseTopUp` across app/javascript and spec: 0 remaining references (it was a local function only).
- `data: any` used in the checkout onSuccess to match the in-file convention (sibling handlers `handleUpdateWithPaymentMethod` / `handleChangeSubscriptionViaStripePortal` type their data loosely and read `data.redirectUrl`) and the analog's untyped `data.url`; build is Babel-only (no tsc typecheck in pipeline).

**No WHITELIST items.**
**No REVERT items.**

---

## AiCreditPackCard.tsx

### Changed

`/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditPackCard.tsx` (line 36) — Added `disabled={isLoading}` to `Styled.Button` alongside the existing `loading={isLoading}`, so the Buy pack button is disabled (not clickable) during an in-flight purchase. This matches the analog `JobDistributionWeWorkRemotely.tsx:477-481`, where the Button receives both `disabled` and `loading` driven by the same in-flight signal (`isPurchasing`/`isLoadingSomething`).

Trace verifying the prop is honored end-to-end: `AiCreditPackCard.tsx` → `SmallButton.tsx` (spreads `{...props}` into `Button`) → `Button/index.js` (applies `disabled={disabled}` to the `<button>` at line 250; with both props set, `&:disabled { opacity: loading ? 1 : 0.5 }` at line 70 keeps full opacity while showing the loader — exactly the analog's intended in-flight appearance).

No backend change needed — this is a pure frontend prop addition reading the existing `isLoading` prop.

**No WHITELIST items.**
**No REVERT items.**
