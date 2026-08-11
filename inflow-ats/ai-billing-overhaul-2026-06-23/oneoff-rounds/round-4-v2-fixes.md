# One-Off Purchase — Round 4 Fixes (v2)

### organization_ai_credit_purchase.rb

Everything is confirmed and consistent: the model emits `AI_CREDIT_TOP_UP_COMPLETE`, the frontend consumes the identical string, the routes for both actions exist, and the controller calls `charge_for_purchase` with no argument.

All changes are complete and verified. Here is my report.

---

CHANGES MADE (all in `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`)

Deviation 3 — `charge_for_purchase` now resolves its own amount internally (FIXED)
- `app/models/organization_ai_credit_purchase.rb:131` — changed `def charge_for_purchase(amount)` to `def charge_for_purchase` (no param). Added an internal `Stripe::Price.list(lookup_keys: [stripe_price_lookup_key], active: true, limit: 1)` → `price = prices.data.first` → `return if price.blank?` → `amount = price.unit_amount`. This mirrors `BoardWwrListing#charge_for_listing` resolving `amount = calculate_charge_amount` at the top of the method. OURS' price lives in Stripe (not hardcoded), so the in-method resolution is a `Stripe::Price.list` lookup. This restores the trace-documented two-lookup structure (controller validates the price exists; model resolves its own amount).
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:112` — changed the caller from `purchase.charge_for_purchase(price.unit_amount)` to `purchase.charge_for_purchase`, and updated the adjacent comment.

Deviation 4 — direct-charge `update_columns` now writes currency (FIXED)
- `app/models/organization_ai_credit_purchase.rb:165` — `update_columns(..., stripe_amount: amount, currency: paid_invoice.currency)`. `stripe_amount` uses the locally-resolved `amount` (analog-faithful: WWR/WhatJobs write the resolved `amount`, not `paid_invoice.amount_paid`); `currency` is written from `paid_invoice.currency`.

Deviation 2 — added the `broadcast_event` WebSocket signal in the one-off completion path (FIXED, backend + frontend)
- `app/models/organization_ai_credit_purchase.rb:193` — added `broadcast_event(event = 'AI_CREDIT_TOP_UP_COMPLETE')`, mirroring `BoardWwrListing#broadcast_event` (board_wwr_listing.rb:267). OURS is org-scoped (no `job`/JobChannel), so it broadcasts on `GlobalChannel` — the channel the AI-credit frontend already listens to for balance updates — with `action: event, payload: { organizationId: organization_id }`, using the same target resolution as `broadcast_show_growl`.
- `app/models/organization_ai_credit_purchase.rb:182` — `broadcast_purchase_complete` now calls `broadcast_event` first (then the existing growl + notification job), mirroring the WWR `create_on_wwr` tail order (`broadcast_event` → `broadcast_show_growl` → notification job).
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx:212` — added `case "AI_CREDIT_TOP_UP_COMPLETE": queryCache.invalidateQueries(["organizationAiCreditBalance"]); break;`, matching the existing AI-credit balance-invalidation cases (e.g., `AI_SUMMARY_COMPLETE`). The `shared/websockets/WebsocketGlobalChannelHandler.tsx` copy was intentionally NOT touched — it handles only `UPDATE_AVAILABLE`/`MAINTENANCE_COMPLETE` and has none of the AI-credit cases.

Tests updated to match (signature change ripple)
- `spec/models/organization_ai_credit_purchase_charge_spec.rb` — rewrote to the new behavior: stubs `Stripe::Price.list` to return a price with `unit_amount: 1500`; removed the `amount` argument from all `charge_for_purchase` calls; replaced the "does NOT look up the Stripe Price" example with "resolves the amount internally from the Stripe Price by lookup key"; added a "Price cannot be found → returns early" context; added a `currency` assertion to the `update_columns` example.
- `spec/controllers/api/v1/organization_ai_credit_purchases_purchase_top_up_spec.rb:86` — changed `.to receive(:charge_for_purchase).with(1500)` to `.with(no_args)`.

VERIFICATION
- `spec/models/organization_ai_credit_purchase_charge_spec.rb` + `spec/controllers/.../organization_ai_credit_purchases_purchase_top_up_spec.rb` + `spec/interactors/apply_ai_credit_purchase_spec.rb`: 41 examples, 0 failures (these cover every code path I touched).
- `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` + `spec/models/organization_ai_credit_purchase_spec.rb`: 11 pre-existing failures, NONE related to my changes. They are stale specs against changes that predate my work (the staged `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` now has 10 keys vs spec's expected 4; `subscription_status` enum now has 8 values vs expected 4; the `stripe_checkout_session_id` one_off validation was removed) plus subscription-path test-double gaps (`Double "subscription" received unexpected message :current_period_start`, `Double "line_item" received unexpected message :id`). Confirmed via grep that none of the 11 failing examples reference `charge_for_purchase`, `broadcast_event`, `broadcast_purchase_complete`, or the currency write.

---

DEVIATION 1 — NOT APPLICABLE (already matches the analog; no change made)

WHITELIST: Deviation 1 (double-charge guard "split across two return lines"): The working-tree code already matches the analog structurally, so no change was made — making the described change would DIVERGE from the analog, not converge.

Current OURS (organization_ai_credit_purchase.rb:133-134):
```ruby
return if stripe_invoice_id.present? && stripe_invoice_paid?   # double-charge guard (compound, one line)
return if organization.stripe_customer_id.blank?              # customer-blank guard (separate)
```
Analog WWR (board_wwr_listing.rb:115-122) and WhatJobs (board_what_jobs_listing.rb:160-166) have the SAME two-guard structure: a compound double-charge guard (`stripe_invoice_id.present? && is_active?` / `&& live?`) followed by a SEPARATE `return if organization.stripe_customer_id.blank?`. OURS line 133 is already one compound guard (with `stripe_invoice_paid?` as the OURS-equivalent of `is_active?`/`live?`), and line 134 is the separate customer guard exactly as the analog keeps it separate. The deviation's premise ("the double-charge guard is split across two return lines") does not hold against the working tree — line 133 is the whole double-charge guard, line 134 is a different concern. Merging them would not match the analog. The only stylistic difference is postfix `return if` vs the analog's multi-line `if … ap … return … end` with a log line; I did not add the `ap` log line because it is not a structural/behavioral element and adding debug logging is outside the deviation's scope.

NOTE on Deviation 4 ambiguity (flagging per your "surface the parse failure" rule): As written, deviation 4 ("`update_columns` does not write currency | ANALOG: board_wwr_listing.rb:158 / board_what_jobs_listing.rb:193") is internally contradictory — the cited analog lines do NOT write currency either (the `board_wwr_listings` / `board_what_jobs_listings` tables have no `currency` column; the only `currency` column in `db/schema.rb` belongs to `organization_ai_credit_purchases`). So a strict "match the analog" reading would mean writing NO currency, which is what the working tree already did (a no-op). I resolved it as "write currency" because (a) it is listed as a deviation to FIX, (b) OURS has a `currency` column + a presence validation for one-offs + serializer exposure, and (c) the trace's OURS skeleton and the prior staged version both wrote `currency` — the working tree had regressed by dropping it. The analog citation locates the corresponding `update_columns` line; it does not assert the analog writes currency. If you intended deviation 4 the other way (leave currency out to match the analog literally), revert the `currency: paid_invoice.currency` clause at organization_ai_credit_purchase.rb:165 — currency would remain `'usd'` from record creation, still satisfying the validation.

---

### stripe_webhook_handler_job.rb

The two branches are structurally identical. The one-off branch (212-232) mirrors the WWR branch (234-245) exactly:

| Step | WWR (analog) | One-off (ours) |
|---|---|---|
| Metadata check | `board_wwr_listing_id` present | `organization_ai_credit_purchase_id` present |
| Resolve record by id | `BoardWwrListing.find(listing_id)` | `OrganizationAiCreditPurchase.find_by(id: purchase_id)` |
| Present guard | `if listing&.present?` | `if purchase&.present?` |
| **Finalize in handler (choke point)** | `listing.finalize_stripe_payment` | `purchase.finalize_stripe_payment` |
| **One business call** | `listing.create_on_wwr` | `ApplyAiCreditPurchase.call(...)` |
| Early return | `return` | `return` |

`create_on_wwr` does NOT call `finalize_stripe_payment`; `apply_one_off` does NOT call `finalize_stripe_payment` (grep confirmed). Each path finalizes exactly once, in the handler. This is the analog's "finalize-then-business-call once" pattern, achieved.

The deviation described in the task is already resolved in the working tree. The line references the detector cited (223-224) point to code that already matches the analog. The detector was almost certainly run against the committed (HEAD) code — which is the pre-refactor version (trace's "OURS — full skeleton", lines 466-512: `ApplyAiCreditPurchase.call(organization_id:, checkout_session_id:, invoice_id:)` with finalize inside the interactor). The working tree already contains the fix.

No code change is needed. There is no double-finalize, no business-logic-in-handler beyond the analog's own choke-point pattern, and the one business call mirrors `create_on_wwr`.

NO CHANGE NEEDED: The cited deviation is already resolved in the working tree. The one-off branch at `app/jobs/stripe_webhook_handler_job.rb:212-232` is structurally identical to the WWR analog branch at lines 234-245: resolve record by metadata id → present guard → `finalize_stripe_payment` in handler (choke point) → ONE business call → `return`.

What the working tree currently has (no edits made by me):
- `app/jobs/stripe_webhook_handler_job.rb:223` — `purchase.finalize_stripe_payment` (handler choke point, mirrors WWR `listing.finalize_stripe_payment` at :241)
- `app/jobs/stripe_webhook_handler_job.rb:224-229` — `ApplyAiCreditPurchase.call(kind: :one_off, purchase: purchase, amount_cents:, currency:)` (the single business call, mirrors WWR `listing.create_on_wwr` at :242)
- `app/interactors/apply_ai_credit_purchase.rb` `apply_one_off` (lines 37-82) does NOT call `finalize_stripe_payment` — confirmed by grep. The comment at :56-59 documents that finalize is the handler's job, exactly like `create_on_wwr` does not finalize.

Verification that finalize happens exactly ONCE per path (grep of `finalize_stripe_payment`):
- one-off path: handler line 223 only (interactor `apply_one_off` does not finalize)
- subscription path: interactor `apply_subscription` line 110 only (handler subscription branch does not finalize)
- WWR/WhatJobs: handler lines 241/254 (analogs)

This is "finalize-then-business-call once" — the analog pattern. The deviation report's cited line numbers (223-224) point at the already-correct refactored code; the detector ran against HEAD, where the pre-refactor version still lives (the trace's "OURS — full skeleton" sections 466-512 describe that HEAD version: `ApplyAiCreditPurchase.call` with `organization_id`/`checkout_session_id`/`invoice_id` and finalize inside the interactor). The fix is present and uncommitted in the working tree.

No backend or frontend changes required. No WHITELIST or REVERT items.

---

### organization_ai_credit_purchases_controller.rb

All 17 examples pass. The current working-tree state is green and the spec explicitly verifies that `create_top_up_checkout_session` does NOT stamp `stripe_checkout_session_id`, documenting this as deliberate analog-matching behavior.

My investigation is complete. The trace chain I followed:

`organization_ai_credit_purchases_controller.rb` (create_top_up_checkout_session) → `stripe_webhook_handler_job.rb` (invoice.paid one-off branch lines 212-232; checkout.session.completed lines 58-69; charge.refunded → handle_charge_refunded lines 430-456) → `apply_ai_credit_purchase.rb` (apply_one_off) → `apply_ai_credit_refund.rb` → `organization_ai_credit_purchase.rb:93` (validation) → `db/schema.rb` (board_wwr_listings has no session column; org_ai_credit_purchases has stripe_checkout_session_id) → `board_wwr_listings_controller.rb` (analog create_checkout_session) → `organization_ai_credit_purchases_purchase_top_up_spec.rb` + `apply_ai_credit_refund_spec.rb`.

Here is my final determination.

---

CHANGES MADE: None.

REASON — OURS ALREADY MATCHES THE ANALOG ON THIS DEVIATION:

Deviation #1 asks about `create_top_up_checkout_session` not stamping `stripe_checkout_session_id` back onto the purchase record. The deviation's own ANALOG column states the analog has "no checkout-session-id stamp." I verified both sides:

- ANALOG (`board_wwr_listings_controller.rb#create_checkout_session`, lines 51-128): after `Stripe::Checkout::Session.create` it renders `{ url:, sessionId: }` and never writes the session id back to the listing. The `board_wwr_listings` table has no `stripe_checkout_session_id` column at all. The webhook resolves the listing by `board_wwr_listing_id` invoice metadata.
- OURS (`organization_ai_credit_purchases_controller.rb#create_top_up_checkout_session`, working tree lines 131-199): after `Stripe::Checkout::Session.create` it renders `{ url:, sessionId: }` and does NOT stamp `stripe_checkout_session_id`. The one-off `invoice.paid` webhook branch (`stripe_webhook_handler_job.rb:212-232`) resolves the purchase purely by `organization_ai_credit_purchase_id` metadata, then calls `ApplyAiCreditPurchase.call(kind: :one_off, purchase: purchase, ...)`. The interactor (`apply_ai_credit_purchase.rb#apply_one_off`) receives `context.purchase` directly — it does not look up by `stripe_checkout_session_id`.

So OURS structurally mirrors the analog: linkage rides on metadata (`organization_ai_credit_purchase_id` ≈ `board_wwr_listing_id`), not on a stamped session id. The TRACE document describes an OLDER single-action `purchase_top_up` design (its step 44 stamped the session id and its interactor had a triple-fallback lookup). The working tree on `billing-bonanza` has since refactored that away into the two-action split, eliminating the stamp deliberately. This is locked by `spec/controllers/api/v1/organization_ai_credit_purchases_purchase_top_up_spec.rb:147-155`, which asserts `purchase.stripe_checkout_session_id` is nil and comments that this mirrors the WWR analog. The spec passes (17 examples, 0 failures).

Making OURS "match the analog" here means leaving it as-is. Adding a stamp would DIVERGE from the analog and break that test, so no change was made.

---

REVERT: none.

---

WHITELIST: none for the requested deviation. (No change was needed; OURS already matches.)

---

SEPARATE LATENT INCONSISTENCY FOUND (not the requested deviation, not fixed, flagging per debugging discipline):

OURS has a refund flow the analog does not have, and that flow is broken precisely because the session id is (correctly, per the analog) never stamped on checkout-session one-offs:

- `stripe_webhook_handler_job.rb#handle_charge_refunded` (lines 444-450, live via `when 'charge.refunded'` at line 293-297) resolves a refunded one-off purchase with:
  ```ruby
  sessions = Stripe::Checkout::Session.list(payment_intent: payment_intent_id, limit: 1)
  session = sessions.data.first
  purchase = OrganizationAiCreditPurchase.find_by(stripe_checkout_session_id: session.id, kind: :one_off) if session
  ```
- Because `create_top_up_checkout_session` never stamps `stripe_checkout_session_id`, every checkout-session one-off purchase has that column nil, so this `find_by` returns nil and `ApplyAiCreditRefund` (a real interactor that sets `refunded_at` and writes a debit ledger row) is never called. Refunds of no-card top-ups are silently dropped.
- The direct-charge one-off path (`charge_top_up` → `charge_for_purchase`) also never sets `stripe_checkout_session_id`, so it is affected too; for it there is no checkout session at all, so the payment-intent→session lookup also yields nothing.
- The refund interactor's own spec (`apply_ai_credit_refund_spec.rb:16`) sets `stripe_checkout_session_id: 'cs_test_123'` by hand, testing `ApplyAiCreditRefund` in isolation — so the broken `handle_charge_refunded` lookup is not covered by any test.

This is a genuine bug, but resolving it is a design decision that conflicts with the analog-match directive and is outside this flow: either (a) stamp `stripe_checkout_session_id` on one-offs everywhere (diverges from the analog, breaks the current spec), or (b) rewrite `handle_charge_refunded` to resolve one-offs by `organization_ai_credit_purchase_id` from the payment-intent metadata (which `create_top_up_checkout_session` already sets at lines 167-171) — consistent with how the `invoice.paid` branch already works. Option (b) keeps the analog match and fixes refunds, but it is a change to the refund handler, not to the purchase controller, and it needs your call before I touch it.

Relevant files:
- /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb
- /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/jobs/stripe_webhook_handler_job.rb
- /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/interactors/apply_ai_credit_purchase.rb
- /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/interactors/apply_ai_credit_refund.rb
- /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/board_wwr_listings_controller.rb
- /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/spec/controllers/api/v1/organization_ai_credit_purchases_purchase_top_up_spec.rb
