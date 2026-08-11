# AI Credit Billing — Open Items

Branch: `ai-feature-work-v5`. All billing work uncommitted in the working tree. This is the live list of what is NOT yet done. Architecture/state lives in `ai-credit-session-handoff.md`; the structural analog manifest lives in `ai-credit-change-and-topup-analog-manifest.md`.

---

## 1. Cancel-at-period-end behavior (NOT built; column exists)

The `stripe_cancel_at_period_end` column is committed on `organization_ai_credit_purchases`, but the behavior that uses it is not built. Today `CancelAiCreditSubscription` eagerly flips the row to `:canceled`, so `#show`'s `[:active, :past_due]` filter drops a subscription the customer still has until period end. Full plan in `ai-credit-cancel-at-period-end-migration-plan.md` (the migration part is already done via the in-place column edit — only the behavior remains). Remaining:

- credit-pack `customer.subscription.updated` branch → also set `stripe_cancel_at_period_end = object.cancel_at_period_end`
- `CancelAiCreditSubscription` → stop eager-flipping `:canceled` / `subscription_canceled_at`; let the webhook drive it
- NEW `customer.subscription.deleted` credit-pack branch → finalize to `:canceled` + `subscription_canceled_at = Time.at(object.ended_at)` (the real cancellation moment)
- serializer exposes `stripeCancelAtPeriodEnd`; UI keeps the card and shows "cancels on `subscriptionCurrentPeriodEnd`"
- DATA: the already-cancelled sub is locally `:canceled` but live until ~July 17 — flip back to active + flag true via console, or reset as test data

---

## 2. Finalization-marker decision for one-off grants

The one-off grant-once guard relies on the existence of the `one_off_credit_pack_purchase_credit` ledger row, but `AiCreditBalanceTransaction belongs_to :organization_ai_credit_purchase, optional: true` — so the purchase link is not DB/model-enforced; the guard rests on the interactor setting it.

**Leaning option 1 (Jessica):** add a model validation requiring `organization_ai_credit_purchase` presence for the credit ledger entry types (`one_off_credit_pack_purchase_credit` and the subscription credit type) — "check the one value that's fragile." No migration. Then existence-by-(purchase, entry_type) is robustly sufficient. Not yet implemented.

---

## 3. `checkout.session.completed` missing top-up guard (pre-existing bug)

`checkout.session.completed` has no `ai_credit_pack_top_up` early-return guard, so a top-up checkout-session completion falls through to the main-plan org branch and silently swallows a `NoMethodError`. Pre-existing, adjacent to this work, out of scope when surfaced. Flag for a focused fix.

---

## 4. Cleanup / styling (LOW)

UI cleanup pass on the AI-credit billing views. General polish — not yet scoped in detail. Includes the minor dead-weight introduced by this branch's rewrite (both items below are byproducts of this session's work, not pre-existing, so they're safe to tighten):

- `AiCreditSubscription.tsx:91` — the `charged?: boolean` field is declared in the `purchaseTopUp` success type but never read; the branch keys off `redirectUrl` presence. Drop it or read it explicitly.
- `apply_ai_credit_purchase.rb:47-51` — the `stripe_checkout_session_id` / `stripe_invoice_id` fallback lookups in `apply_one_off` are unreachable because `purchase_id` is always stamped on invoice metadata before pay. Defensive dead branches.

---

## 5. Cancellation modal (LAST PRIORITY — deferred, do not discuss yet)

Placeholder per Jessica. A `CancelAiCreditSubscriptionConfirmModal` already exists and is wired (`AiCreditSubscription.tsx:132` `handleCancelClick`), so the exact scope of this item is undefined until Jessica defines it. Last priority; not for discussion now.

---

## Reference: confirmation flow (resolved, NOT an open item)

Recorded to prevent re-confusion — these are working as intended:

- **One-off top-up, card on file:** in-app `PurchaseAiCreditTopUpConfirmModal` gates the charge (`AiCreditSubscription.tsx:116`). Customer sees "$X for N credits — card charged today" and must Confirm before `charge_default_payment_method` runs. The auto-charge-without-confirmation risk is solved here.
- **One-off top-up, no card:** Stripe Checkout (Stripe confirms).
- **Subscription upgrade/downgrade:** Stripe Billing Portal redirect — Stripe's hosted page is the confirmation; our side never charges directly. Replacing Stripe's confirmation with an in-app one for upgrades would require in-app `Stripe::Subscription.update` (item-swap), the rejected anti-analog approach — a product fork, deferred.

---

## Subscription-change mirror — follow-ups (open worklist)

Remaining work after the analog mirror + rename + audit (audit was clean except these).

**Real code (Jessica's concern):** item D (the toast).
**Specs (A, B, C):** parked — Jessica audits specs separately at her own time; do not surface them to her.

- [ ] **A. Rewrite stale model spec** — `spec/models/organization_ai_credit_purchase_spec.rb` (~`:139-181`). The catalog now holds 10 keys (6 new `plato_ai_credit_*` production + 4 old dev keys), but the spec still asserts the old catalog: `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY.size == 4`, one-off `== 2`, subscription `== 2`, and `ai_credit_lookup_keys` matching exactly the 4 old keys. Update to: 10 total, 5 one-off (3 new top-ups + 2 dev), 5 subscription (3 new + 2 dev), `match_array` of all 10 keys.
- [ ] **B. Rewrite stale change-action controller spec** — `spec/controllers/api/v1/organization_ai_credit_purchases_change_subscription_spec.rb`. Written for the OLD contract: POSTs `stripe_price_lookup_key`, stubs `Stripe::Price.list` and `Stripe::Subscription.retrieve`, asserts "Price not found in Stripe for this lookup key" and those calls. The new action takes `price_id` + `subscription_item_id` from params, resolves the lookup_key via `Stripe::Price.retrieve(price_id).lookup_key`, and calls neither of those. Rewrite to: POST `{ price_id, subscription_item_id, return_url }`, stub `Stripe::Price.retrieve` + `Stripe::BillingPortal::Session.create`, assert the new guards (missing `stripe_customer_id`, missing `subscription_item_id`) and the flow_data built from params.
- [ ] **C. Add specs for new untested code** — the `customer_subscription` endpoint, the `OrganizationAiCreditPurchase#stripe_subscription` model method, and the frontend `useAiCreditCustomerSubscription` hook all have no tests. Not failing, just uncovered.
- [ ] **D. Toast on the change path (deferred — needs Jessica)** — `AiCreditSubscription.tsx` `redirectToStripe` (~`:49-52`) fires "Redirecting to Stripe checkout…" before the Billing Portal redirect. The analog shows no toast on the change path, and "checkout" is wrong (it's the Billing Portal). The helper is shared with the subscribe/top-up checkout paths where the wording is correct, so the fix is to branch the copy or skip the toast only on the change path. Held pending your decision.
