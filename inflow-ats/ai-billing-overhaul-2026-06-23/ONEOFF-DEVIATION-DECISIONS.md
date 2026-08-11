# One-Off Purchase — Deviation Decision Sheet (round 2 audit, 11 deviations)

Loop PAUSED after round 2 fix. Awaiting Jessica's rulings. Sanctioned items get added to SANCTIONED-DEVIATIONS.md (owner-only) before the loop resumes, so the audit stops re-flagging them.

---

## A. Forced by our domain — no analog equivalent (recommend SANCTION)

**A1 — Balance notification-flag reset** (`apply_ai_credit_purchase.rb:88-91`)
We clear `sent_low_notification_since_increase` / `sent_zero_notification_since_increase` on the `OrganizationAiCreditBalance` after granting, so the user gets re-warned next time they run low. WWR has no balance and no such notifications — nothing to match. Recommend sanction (keep).

**A2 / A3 — Multi-key Invoice & InvoiceItem metadata** (`organization_ai_credit_purchase.rb:157-162`, `:169-174`)
We stamp 4 keys (`organization_id`, `organization_ai_credit_purchase_id`, `stripe_price_lookup_key`, `ai_credit_pack_top_up: 'true'`). WWR stamps one (`board_wwr_listing_id`). WWR has a dedicated invoice.paid branch keyed on that one key; we have ONE shared handler that routes on `ai_credit_pack_top_up=='true'`, then the interactor reads org + finds by purchase id. Stripping to one key breaks our routing. Recommend sanction (or re-architect routing to key on purchase_id presence — bigger).

**A4 — Invoice description string** (`:168`)
`'AI Credit Top-Up'` vs analog `'We Work Remotely Listing'`. Domain constant. Recommend sanction.

**A5 — Currency column** (`:179`)
We have a `currency` column (set `'usd'` at creation, backfilled in interactor); WWR has none. Recommend sanction the column. Sub-question: should direct-charge stamp real invoice currency vs creation-time `'usd'`? (Minor; USD-only today.)

---

## B. Architecture decision — one call covers findings #1, #2, #3-location

Question: does one-off fulfillment run through the `ApplyAiCreditPurchase` interactor, or inline on the model in the handler like WWR?
- #1: WWR handler calls `listing.finalize_stripe_payment` then `listing.create_on_wwr` inline; ours routes finalize + grant + broadcast through `ApplyAiCreditPurchase.call`.
- #2: WWR uses the found record directly; ours passes `purchase_id` to the interactor, which re-finds.
- #3: grant-once guard FORM is already sanctioned; audit only flags that it lives in the interactor, not a model method.

`ApplyAiCreditPurchase` is SHARED with subscription renewal (`apply_subscription`). Inlining one-off to match WWR dismantles half a shared interactor. Recommend sanction the interactor architecture for one-off. If sanctioned, audit stops re-flagging #1/#2/#3.

---

## C. Genuine deviations — ours CAN match (FIX, not sanction)

**C1 — Double `Stripe::Price.list`** (`organization_ai_credit_purchase.rb:142-146`)
Fetching price from Stripe is sanctioned; fetching it TWICE (controller:77 + charge_for_purchase) is redundant. Fix: fetch once, pass amount through.

**C2 — Direct-charge response shape** (`controller:108`)
Analog returns serialized record (HTTP 200); ours returns `{ charged: true }, status: :created`. Matchable (frontend onSuccess branches on `data.charged`, changes in same round). Decision: fix to match, or sanction the bare boolean.

**C3 — `stripe_amount` backfill** (`apply_ai_credit_purchase.rb:72-74`)
Checkout path creates with `stripe_amount: 0`, webhook backfills paid amount. WWR never backfills. Decision: keep (record paid amount on checkout purchases) or drop to match WWR. Real product choice.

---

## Recommendation summary
- Sanction: A1, A2, A3, A4, A5, B (interactor architecture).
- Fix: C1 (drop duplicate Price.list).
- Your product call: C2 (response shape), C3 (backfill), and A5 sub-question (real currency on direct charge).
