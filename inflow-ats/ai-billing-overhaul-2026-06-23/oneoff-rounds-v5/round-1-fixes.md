# One-Off Purchase Analog Audit — Round 1 Fixes

Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`
Audit: `oneoff-rounds-v5/round-1-audit.md` (7 deviations)

---

## D3 — AccountBillingAiCredits.tsx top-up onSuccess reads `data.redirectUrl` from the direct-charge action (FIXED)

**File:** `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingAiCredits.tsx`

The top-up `onSubmit` called the direct-charge mutation `usePurchaseAiCreditTopUp` (which renders the
serialized purchase via `render_one`, NOT `{ redirectUrl }`) yet did
`addToast("Redirecting to Stripe checkout…"); window.location.href = data.redirectUrl` — `data.redirectUrl`
is always `undefined` on that response, so the redirect was internally broken and diverged from the analog's
success handler.

**Fix:** rewrote the top-up handler to mirror the in-repo structural analog `AiCreditSubscription.tsx`
(`handleBuyPack` / `purchaseTopUp` / `purchaseTopUpCheckoutSession`), itself a copy of the WWR frontend's
`handleCreateBoardWwrListing` (direct charge: `onSuccess` does nothing, no redirect, no toast — the success
growl is emitted server-side from `grant_credits`) and `handleCreateCheckoutSession` (redirect to `data.url`).
The direct-charge `purchaseTopUp` now has `onSuccess: () => {}` (no toast, no redirect), matching the analog.

## D4 — AccountBillingAiCredits.tsx has no no-card (checkout-session) branch (FIXED)

**File:** `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingAiCredits.tsx`

The component always called the direct-charge mutation regardless of payment method, omitting the no-card
checkout-session path the analog provides. `AiCreditSubscription.tsx` (the other consumer) already branches
correctly on `currentOrganization.stripeDefaultPaymentMethodOnFile`.

**Fix (same edit as D3):**
- Imports added: `usePurchaseAiCreditTopUpCheckoutSession`, `useCurrentSession`,
  `PurchaseAiCreditTopUpConfirmModal`, `AiCreditPack`.
- Added `purchaseCheckoutSession` mutation (`usePurchaseAiCreditTopUpCheckoutSession`) and
  `currentOrganization` (`useCurrentSession`).
- New `handleBuyPack(pack)` branches exactly like `AiCreditSubscription.tsx`:
  - card on file → open `PurchaseAiCreditTopUpConfirmModal` → on confirm `removeModal(); purchaseTopUp(pack)`
    (direct charge, no redirect).
  - no card → `purchaseTopUpCheckoutSession(pack)` → `window.location.href = data.url`.
- `AiCreditPurchaseModal.onSubmit(lookupKey)` resolves the full pack from `topUpTiers` (needed because the
  confirm modal and checkout flow consume `priceDollars`/`credits`), then calls `handleBuyPack(pack)`.
- Modal `isLoading` now reflects both mutations (`isPurchasing || isPurchasingCheckoutSession`).

## D5 — Duplicated identical build params across the two one-off actions (FIXED)

**File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`

The two one-off build sites (`purchase_top_up` direct-charge :79-87, `purchase_top_up_checkout_session`
:115-123) were byte-identical, whereas the analog's two build sites differ (WWR direct-charge builds from
`listing_params`; checkout build merges `status: 'approved', stripe_invoice_paid: false`).

**Fix (same edit as D6):** the checkout build now adds `stripe_invoice_paid: false`, so the checkout build
differs from the direct-charge build, matching the analog's structure (checkout build ≠ direct-charge build).

## D6 — Checkout-session build omits the `stripe_invoice_paid: false` default the analog sets (FIXED)

**File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` — `purchase_top_up_checkout_session`

**Before:** checkout build set no `stripe_invoice_paid` default.
**After:** added `stripe_invoice_paid: false` to the `OrganizationAiCreditPurchase.new(...)` build, mirroring
the analog's checkout build (`board_wwr_listings_controller.rb:59-63`) which merges `stripe_invoice_paid: false`
on the awaiting-payment record. (The analog's `status: 'approved'` has no parallel — `OrganizationAiCreditPurchase`
has no listing-`status` enum; its only status column is `subscription_status`, which is subscription-only. Noted
in the in-code comment.)

## D7 — checkout-session Stripe rescue omits the analog's error log line (FIXED)

**File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` — `purchase_top_up_checkout_session`

**Before:** `rescue Stripe::StripeError => e` only `render json: { error: e.message }, status: :unprocessable_entity`.
**After:** added `Rails.logger.error "Stripe Checkout Session Error: #{e.message}"` before the render, verbatim
from `board_wwr_listings_controller.rb:126`.

---

## CANNOT-MATCH

### D1 — Direct-charge invoice description source (CANNOT-MATCH → SUGGESTED-WHITELISTS W8)

**File:** `app/models/organization_ai_credit_purchase.rb` — `charge_for_purchase` (`description = ...`)

The analog builds `@description`/`@final_description` from the listing `plan` enum + `wwr_percent_off`
org-settings discount + `job.title`. OURS has no `plan` tier, no `wwr_percent_off` discount, and no `Job`
(org-scoped purchase). AI credit pricing follows the SUBSCRIPTION analog (SANCTIONED #6): prices/products live
in Stripe by lookup key with no plan tiers and no percent-off, so there is no `@final_description` discount
clause to construct. The closest structural match — a single base description with no discount append — is
exactly what OURS produces, derived from the only available identifier (the lookup-key display name in
`AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY`). Forced by the AI-credit pricing data model. Left unchanged; appended to
SUGGESTED-WHITELISTS.md as **W8**.

### D2 — grant_credits resets balance notification-suppression flags (CANNOT-MATCH → already W1)

**File:** `app/models/organization_ai_credit_purchase.rb` — `grant_credits`
(`balance.update_columns(sent_low_notification_since_increase: false, sent_zero_notification_since_increase: false)`)

The analog's `create_on_wwr` has no companion balance-record column reset because WWR listings have no balance
record. OURS delivers credits onto an `OrganizationAiCreditBalance` that carries notification-suppression flags;
resetting them on a credit increase is part of correctly delivering the product. Forced by the data-model
difference. This is the SAME deviation already whitelisted as **W1** in SUGGESTED-WHITELISTS.md — no separate
entry added (a cross-reference note was appended under W8). Left unchanged.

---

## SUGGESTED-WHITELISTS additions

- **W8** (new): Direct-charge invoice description built from the lookup-key name map, not the analog's
  plan/discount construction (D1).
- D2 maps to existing **W1** (no new entry; cross-reference note added).
