# One-Off Purchase — Round 4 Audit (v2)

## Setup

I have a complete trace picture. The current code's `Notification::PaidAiCreditPackPurchasedJob` and `broadcast_purchase_complete` are the structural equivalents of the WWR tail (Slack notification + growl). The `broadcast_event` in the analog updates the job-distribution UI via WebSocket; OURS uses the React Query invalidation on the frontend + the growl. The `broadcast_event` analog is a listing-specific UI signal that has no AI-credit equivalent (there's no listing-published UI state to push). This is a reasonable structural equivalent and the WWR/WhatJobs analogs themselves disagree on placement (WWR inside create_on_wwr, WhatJobs in handler). Reported below per the "report ALL" instruction.

The current code is substantially analog-faithful — far more so than the stale "OURS" section of the earlier trace. This audit compares the current code against the ANALOG sections only, excluding whitelisted/sanctioned divergences.

---

## Chain Traced

`oneoff-purchase-trace.md` (ANALOG sections) → `organization_ai_credit_purchases_controller.rb` → `organization_ai_credit_purchase.rb` → `apply_ai_credit_purchase.rb` → `stripe_webhook_handler_job.rb` → `useOrganizationAiCreditPurchase.ts` → `AiCreditSubscription.tsx` → `routes.rb`; analog cross-checks → `board_wwr_listings_controller.rb`, `board_wwr_listing.rb`, `board_what_jobs_listings_controller.rb`, `board_what_jobs_listing.rb`, `board_wwr_listing_policy.rb`, `billing_policy.rb`, `organization_ai_credit_purchase_policy.rb`, `paid_ai_credit_pack_purchased_job.rb`, `paid_wwr_listing_created_job.rb`.

---

## Important Framing

The current code has **two** controller actions (`charge_top_up` + `create_top_up_checkout_session`) which structurally matches the analog's two actions:
- WWR: `#create` + `#create_checkout_session`
- WhatJobs: `#create_paid_listing` + `#create_checkout_session`

The trace's stale "OURS" section described a single `purchase_top_up` action and was ignored per instructions. Compared against the ANALOG sections, the current code is largely faithful.

---

## Structural Deviations from Analog

### 1. Direct-charge double-charge guard structure

**FINDING:** Guard is split across two `return` lines instead of one compound guard.

**ANALOG:**
- WWR: `return if stripe_invoice_id.present? && is_active?` (single compound guard line; customer-blank guard is a SEPARATE second line)
- WhatJobs: `return if stripe_invoice_id.present? && live?` (same pattern)

**OURS:** `charge_for_purchase` at `organization_ai_credit_purchase.rb:133–134`:
```ruby
return if stripe_invoice_id.present? && stripe_invoice_paid?
return if organization.stripe_customer_id.blank?
```

**ASSESSMENT:** The guard shape (compound line + separate customer-blank line) actually MATCHES the analog. Only the second predicate differs (`stripe_invoice_paid?` vs `is_active?`/`live?`), which is WHITELIST #1/#7 (whitelisted on-status synonyms). This guard structurally matches — flagging only to confirm the predicate substitution is the whitelisted one and nothing else differs.

**VERDICT:** ✓ Matches analog (with whitelisted predicate substitution).

---

### 2. Webhook one-off finalization ordering

**FINDING:** Webhook one-off branch performs `finalize_stripe_payment` in the handler AND a second time inside the interactor, vs. analog finalize-then-business-call once.

**ANALOG:**
- WWR handler calls `listing.finalize_stripe_payment` then `listing.create_on_wwr` (stripe_webhook_handler_job analog steps 7–8); `create_on_wwr` does NOT call finalize again.
- WhatJobs handler: same pattern.

**OURS:** `stripe_webhook_handler_job.rb:223–224`:
```ruby
purchase.finalize_stripe_payment
ApplyAiCreditPurchase.call(...)
```

`apply_one_off` at `apply_ai_credit_purchase.rb:56–59`:
```ruby
# Does NOT call finalize again (comment confirms)
```

**ASSESSMENT:** Handler calls finalize once, then business-work interactor second — no re-finalize. This MATCHES the analog's ordering.

**VERDICT:** ✓ Matches analog.

---

### 3. Broadcast event WebSocket signal in completion path

**FINDING:** No `broadcast_event` WebSocket signal in the one-off completion path.

**ANALOG:**
- WWR: `create_on_wwr` emits `broadcast_event('wwr_listing_published')` (board_wwr_listing.rb:192) as part of the post-payment tail.
- WhatJobs handler: emits `listing.broadcast_event('what_jobs_listing_payment_received')` (stripe_webhook_handler_job.rb:258, trace line 298).

**OURS:** `broadcast_purchase_complete` at `organization_ai_credit_purchase.rb:175–178` emits only `broadcast_show_growl` + `Notification::PaidAiCreditPackPurchasedJob`, with NO `broadcast_event`.

**ASSESSMENT:** The two analogs themselves disagree on placement (WWR in model, WhatJobs in handler), but both emit a WebSocket event. OURS relies on React Query `invalidateQueries(["organizationAiCreditBalance"])` (useOrganizationAiCreditPurchase.ts:111) instead. There is no AI-credit "published" UI channel event equivalent; the frontend's balance update is the functional equivalent. This is a structural divergence from both analogs' tails, reported per "report ALL; let Jessica decide" rule.

**VERDICT:** ⚠️ Structural divergence (no broadcast_event; using React Query invalidation instead). Reasonable equivalent; both analogs disagree on placement. Report for review.

---

### 4. Charge-for-purchase amount resolution location

**FINDING:** `charge_for_purchase` takes the amount as a parameter resolved by the controller, vs. analog model method resolving its own amount internally.

**ANALOG:**
- WWR/WhatJobs: `charge_for_listing` takes NO arguments; computes `amount = calculate_charge_amount` as its first line inside the model (board_wwr_listing.rb:113; board_what_jobs_listing.rb:157) — amount source lives entirely in the model.

**OURS:** `charge_for_purchase(amount)` at `organization_ai_credit_purchase.rb:131` receives amount as an argument. Controller resolves it via `Stripe::Price.list` and passes `price.unit_amount` in (controller:82–83, 113).

**ASSESSMENT:** This is the structural consequence of WHITELIST #8 (AI credits have no local `calculate_charge_amount`; the dollar amount lives only in Stripe). The signature and amount-resolution location differ from the analog, but the divergence is entirely sanctioned by the price-source whitelistization. Reported for completeness.

**VERDICT:** ⚠️ Structural divergence (amount as parameter; controller-resolved); driven by sanctioned WHITELIST #8 (Stripe-resolved price model).

---

### 5. Checkout-session record stamping

**FINDING:** Checkout-session path does not stamp `stripe_checkout_session_id` back onto the purchase record.

**ANALOG:**
- WWR/WhatJobs: `#create_checkout_session` never stamp a checkout-session ID; the analog models have no such column. Webhook lookup is purely via `board_wwr_listing_id`/`board_what_jobs_listing_id` in invoice metadata.

**OURS:** `create_top_up_checkout_session` at `controller:147–190` likewise does NOT stamp `stripe_checkout_session_id`. Webhook lookup is via `organization_ai_credit_purchase_id` metadata (stripe_webhook_handler_job.rb:212–216).

**ASSESSMENT:** This MATCHES the analog's behavior for the purchase/webhook flow. No checkout-session column is stamped on either; the ID lives only in metadata.

**CAVEAT:** `handle_charge_refunded` at stripe_webhook_handler_job.rb:447 looks one-offs up by `stripe_checkout_session_id`, which would never be populated — but refund handling is outside the one-off-purchase trace scope, so not a deviation from THIS trace's analog.

**VERDICT:** ✓ Matches analog (no checkout-session-id stamp; webhook lookup via purchase ID metadata).

---

### 6. Direct-charge update_columns write set

**FINDING:** Direct-charge `update_columns` does not write `currency`.

**ANALOG:**
- WWR/WhatJobs: `charge_for_listing` final `update_columns(stripe_invoice_id:, stripe_invoice_item_id:, stripe_amount:)` writes no currency (analog has no currency column).

**OURS:** `charge_for_purchase` at `organization_ai_credit_purchase.rb:159`:
```ruby
update_columns(stripe_invoice_id: invoice.id, stripe_invoice_item_id: invoice_item.id, stripe_amount: amount)
```

Also writes no currency, even though OURS has a `currency` column the record was created with (`currency: 'usd'`, controller:95).

**ASSESSMENT:** The column-write set MATCHES the analog's shape (currency is set at record creation, not re-stamped at charge). Confirmed faithful — reported only to document that the column-write set matches the analog exactly.

**VERDICT:** ✓ Matches analog (currency set at creation, not re-stamped at charge).

---

## Net Result

After tracing the ANALOG sections against the current `inflow-ats.billing-bonanza` code, the one-off purchase flow is **structurally faithful to the WWR/WhatJobs analog**.

**Every candidate deviation resolves to:**

1. **Exact structural match:** compound double-charge guard shape, finalize-once-in-handler + business-call ordering, no-checkout-session-id-stamp webhook lookup, update_columns column set
2. **Sanctioned/whitelisted divergence:** the `amount`-parameter signature + `price: price.id` checkout line_items (both forced by the Stripe-resolved price model — WHITELIST #8); the `stripe_invoice_paid?` second predicate (WHITELIST #1/#7)
3. **Single genuine structural divergence** (not covered by whitelist):
   - **Absent `broadcast_event` WebSocket signal in the one-off completion path** — the analog's WWR `create_on_wwr` and WhatJobs handler both emit one; ours does not, relying on React Query balance invalidation instead (functional equivalent, but structurally different from both analogs' tails)

---

## Recommendation

The code is **analog-faithful** with one reported structural divergence. The missing `broadcast_event` is a functional equivalent (balance update via React Query instead of WebSocket) and both analogs disagree on placement (WWR in model, WhatJobs in handler), making the absence a reasonable design choice rather than an oversight. Surface this for Jessica's decision; all other deviations from the analog trace back to whitelisted price-source and status-synonym rules.
