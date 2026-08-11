# Round 2 Fixes — AI Credit One-Off Purchase Analog Audit

Analog: WWR (`BoardWwrListing` primary), WhatJobs secondary. Live code compared against the ANALOG.

Note on audit staleness: the audit's "OURS" line numbers/method names (e.g. `charge_default_payment_method`, `apply_one_off` line refs) did not all match the live tree (live has `charge_for_purchase`, `apply_one_off` in the interactor). Fixes were made against the live code's STRUCTURE, matching the analog.

---

## Deviation 1 — Webhook fulfillment placement (interactor vs inline model calls) — FIXED

ANALOG: `stripe_webhook_handler_job.rb` WWR branch calls `listing.finalize_stripe_payment` then `listing.create_on_wwr` directly on the model inside the `invoice.paid` handler.

OURS (before): the handler found the `OrganizationAiCreditPurchase` then routed ALL fulfillment through `ApplyAiCreditPurchase.call(kind: :one_off, ...)`.

Fix:
- `app/jobs/stripe_webhook_handler_job.rb` (one-off `invoice.paid` branch, ~line 218): replaced the `ApplyAiCreditPurchase.call(...)` block with inline model calls:
  ```ruby
  organization_ai_credit_purchase.finalize_stripe_payment
  organization_ai_credit_purchase.grant_credits
  ```
  This mirrors `listing.finalize_stripe_payment; listing.create_on_wwr`.
- `app/models/organization_ai_credit_purchase.rb`: added `grant_credits` — a model method that is the structural analog of `BoardWwrListing#create_on_wwr` (product-delivery method invoked inline by the webhook). It contains the grant-once guard, the credit-grant ledger row, the notification-flag reset, and `broadcast_purchase_complete`. Wrapped in `rescue StandardError => e` + `Rails.logger.info`, mirroring `create_on_wwr`'s rescue tail.
- `app/interactors/apply_ai_credit_purchase.rb`: removed the entire `:one_off` path — the `when :one_off` dispatch branch and the `apply_one_off` method (~60 lines). The interactor now handles ONLY `:subscription` (the subscription path is unchanged and still calls `ApplyAiCreditPurchase.call(..., kind: :subscription)` from `handle_subscription_credit_pack_invoice_paid`). Updated the class header comment to describe the subscription-only responsibility.

## Deviation 2 — Webhook record-found guard shape — FIXED (with #1)

ANALOG: `listing = BoardWwrListing.find(listing_id)` then `if listing&.present?` and fulfillment called on the model inside the block.

Fix: OURS already did `OrganizationAiCreditPurchase.find(...)` + `if organization_ai_credit_purchase&.present?`. With #1, the found record is now used DIRECTLY (model method calls), not passed to an interactor by `purchase_id`. Structurally matches the analog.

## Deviation 3 — Grant-once guard location/shape — FIXED (location)

The grant-once PREDICATE (`find_by(entry_type: :one_off_credit_pack_purchase_credit)` + `amount.positive?`) is SANCTIONED (SANCTIONED-DEVIATIONS.md "Grant-once guard"). The audit's complaint was LOCATION (in the interactor, not in a model method analogous to `create_on_wwr`).

Fix: moved the sanctioned predicate INTO `grant_credits` at the top, mirroring WWR's `unless wwr_listing_id.blank?` produce-once guard at the top of `create_on_wwr`. Predicate unchanged; only location moved.

## Deviation 4 — stripe_amount backfill on the purchase record — FIXED (removed)

ANALOG: no equivalent — WWR never backfills `stripe_amount` in the webhook/fulfillment path (it has no currency column and its checkout path never stamps `stripe_amount`).

Fix: removed the conditional `existing.update(stripe_amount:, currency:)` backfill. It lived only in the deleted `apply_one_off`. `grant_credits` does not backfill. Checkout-path purchases keep their creation-time `stripe_amount: 0` placeholder (valid: presence + `>= 0`), matching the analog leaving listing `stripe_amount` unstamped on the checkout path. Direct-charge path still stamps `stripe_amount` via `charge_for_purchase`'s `update_columns` (mirroring `charge_for_listing`).

## Deviation 5 — balance notification-flag reset step — KEPT (CANNOT-MATCH, reported)

ANALOG: no equivalent — WWR's `create_on_wwr` performs no companion-record column reset because a WWR listing has no companion balance record carrying notification-suppression state.

This is NOT removable to "match the analog": the analog has no analog. OURS' product is credits, delivered onto an `OrganizationAiCreditBalance` that carries `sent_low_notification_since_increase` / `sent_zero_notification_since_increase`. Resetting these on a credit increase is part of correctly delivering the product (otherwise low/zero-balance notifications stay suppressed after a top-up). Forced by the data-model difference (credits have a balance with notification state; listings do not). Kept inside `grant_credits` (the `create_on_wwr` analog), immediately after the grant — the same place the deleted interactor reset them. Reported as CANNOT-MATCH and appended to SUGGESTED-WHITELISTS.md.

## Deviation 6 — Second Stripe::Price.list inside the direct-charge model method — KEPT (sanctioned-derived)

SANCTIONED-DEVIATIONS.md #4 establishes that AI credit prices live in Stripe and are resolved by lookup key (deliberate architectural choice). `charge_for_purchase` resolving its own amount via `Stripe::Price.list(lookup_keys: [stripe_price_lookup_key], ...)` is the in-method amount resolution that mirrors `amount = calculate_charge_amount` at the top of `charge_for_listing` — the analog's local hardcoded calc becomes a Stripe lookup BECAUSE the price lives in Stripe. The controller's separate `Stripe::Price.list` (line 77) validates the price exists before pre-creating the record (the analog controller has nothing to validate because WWR has no Stripe price). Both calls are forced consequences of sanctioned deviation #4. NOT changed.

## Deviations 7 & 8 — Direct-charge InvoiceItem / Invoice metadata keys (four vs one) — FIXED (reduced to 2)

ANALOG: metadata is `{ board_wwr_listing_id: id }` only — one key serving as BOTH the webhook discriminator (presence check) AND the record id.

OURS (before): four keys — `organization_id`, `organization_ai_credit_purchase_id`, `stripe_price_lookup_key`, `ai_credit_pack_top_up: 'true'`.

Fix: after the #1 restructure, the webhook finds the record by `organization_ai_credit_purchase_id` and calls model methods that read `organization` and `stripe_price_lookup_key` from the RECORD — so `organization_id` and `stripe_price_lookup_key` in metadata are dead. Removed both. Remaining two keys:
- `organization_ai_credit_purchase_id` — the record-id (analog of `board_wwr_listing_id`)
- `ai_credit_pack_top_up: 'true'` — the webhook routing discriminator

Applied identically in `charge_for_purchase`'s InvoiceItem + Invoice metadata (`organization_ai_credit_purchase.rb`) and the checkout-session `invoice_data.metadata` + session `metadata` (`organization_ai_credit_purchases_controller.rb`).

Residual: 2 keys vs the analog's 1. The analog folds discriminator + id into one key (presence of `board_wwr_listing_id`). OURS keeps a SEPARATE boolean discriminator `ai_credit_pack_top_up` because the one-off and subscription metadata are distinguished by separate boolean flags (`ai_credit_pack_top_up` vs `ai_credit_pack_subscription`) rather than by which id key is present. Reducing further (collapsing to id-presence-as-discriminator) would change the webhook routing mechanism — out of scope for a one-off audit fix and would touch the subscription routing. Reported as CANNOT-MATCH (residual 2-vs-1) in SUGGESTED-WHITELISTS.md.

## Deviation 9 — Direct-charge Invoice description literal — NO CHANGE (parallel constant)

ANALOG: `'We Work Remotely Listing'`. OURS: `'AI Credit Top-Up'`. The audit itself flagged this only "per instruction to list every non-sanctioned difference" — it is the correct domain-parallel literal (each flow names its own product). No structural deviation. Not changed.

## Deviation 10 — Direct-charge update_columns stamps differ (currency) — NO CHANGE (already matches)

ANALOG: `update_columns(stripe_invoice_id:, stripe_invoice_item_id:, stripe_amount:)` — three columns, no currency (WWR has no currency column).

OURS' `charge_for_purchase` `update_columns` ALREADY stamps exactly those three columns and does NOT include currency — it already matches the analog's 3-column shape. The audit's note was that OURS HAS a `currency` column (left at creation-time `'usd'`) that the analog lacks. Since the analog has no currency column, there is nothing to match; the `update_columns` shape is already correct. With Deviation 4's backfill removed, currency is no longer touched in fulfillment either. No change needed.

## Deviation 11 — Direct-charge controller response status/key — FIXED

ANALOG: `board_wwr_listings_controller.rb` direct-charge renders `render_one(@listing, Api::V1::BoardWwrListingSerializer)` (HTTP 200, full serialized record).

OURS (before): `render json: { charged: true }, status: :created` (bare boolean, 201).

Fix:
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`: direct-charge path now renders `render_one(organization_ai_credit_purchase, Api::V1::OrganizationAiCreditPurchaseSerializer)` (HTTP 200, full serialized record), mirroring the analog. The serializer already exposes the one-off fields.
- Frontend `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`: the direct-charge response is now a serialized purchase (no `url`, no `charged`). Updated the `onSuccess` param type from `{ url?; sessionId?; charged? }` to `{ url?; sessionId? }`. The existing branch `if (data.url) { redirect } else { toast }` already handles this correctly: a serialized purchase has no `url`, so it falls into the else branch and shows the "Payment received" toast (same UX as before). The checkout path still returns `{ url, sessionId }` and redirects. Removed the now-dead `charged` reference.

---

## CANNOT-MATCH items (appended to SUGGESTED-WHITELISTS.md)

1. **Balance notification-flag reset in `grant_credits` (Dev 5)** — analog has no companion balance record, so no analog to match; forced by OURS' credit-balance notification-suppression data model.
2. **Residual 2 metadata keys vs analog's 1 (Dev 7/8)** — OURS uses a separate boolean discriminator (`ai_credit_pack_top_up`) plus the record id, because one-off vs subscription routing is keyed on separate boolean flags rather than id-presence. Collapsing to 1 would change the shared webhook routing mechanism.

## SANCTIONED / no-change (not fixed, with reason)

- Dev 6 (second `Stripe::Price.list` in `charge_for_purchase`) — sanctioned-derived (SANCTIONED #4: price lives in Stripe).
- Dev 9 (Invoice description literal) — parallel domain constant, no structural deviation.
- Dev 10 (currency in update_columns) — `update_columns` already matches the analog's 3-column shape; analog has no currency column to match.
