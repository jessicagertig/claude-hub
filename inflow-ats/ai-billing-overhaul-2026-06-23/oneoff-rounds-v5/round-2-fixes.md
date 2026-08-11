# One-Off Purchase Analog Audit — Round 2 Fixes

Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`
Audit: `oneoff-rounds-v5/round-2-audit.md` (6 deviations)

All 6 deviations addressed. Files changed:
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`
- `app/models/organization_ai_credit_purchase.rb`

No response keys changed → no frontend changes required.
The earlier `checkout` action (lines 15-66, `mode: 'subscription'`) is the SUBSCRIPTION flow, out of scope for this one-off audit; left untouched.

---

## Dev 1 — Direct-charge action missing new-record logging before authorize

- **Analog:** `board_wwr_listings_controller.rb:16-17` logs `Rails.logger.info 'New WWR Listing'` then `Rails.logger.info @listing.inspect` between building the record and `authorize @listing`.
- **Fix:** `organization_ai_credit_purchases_controller.rb` `purchase_top_up` — inserted, immediately after the `OrganizationAiCreditPurchase.new(...)` build and before `authorize ..., :create?`:
  ```ruby
  Rails.logger.info 'New AI Credit Top-Up'
  Rails.logger.info organization_ai_credit_purchase.inspect
  ```

## Dev 2 — Checkout action missing new-record logging before save

- **Analog:** `board_wwr_listings_controller.rb:67-68` logs `'New WWR Listing via Checkout Session'` then `@listing.inspect` after building the record.
- **Fix:** `purchase_top_up_checkout_session` — inserted, immediately after the `OrganizationAiCreditPurchase.new(...)` build and before the description vars / save:
  ```ruby
  Rails.logger.info 'New AI Credit Top-Up via Checkout Session'
  Rails.logger.info organization_ai_credit_purchase.inspect
  ```

## Dev 3 — Checkout description structure differs from analog

- **Analog:** `board_wwr_listings_controller.rb:70-74` builds FOUR controller instance vars before the save block: `@description`/`@final_description` (line-item product description, with WWR discount note) and `@invoice_description`/`@final_invoice_description` (invoice description).
- **Was:** a SINGLE local `description` used only for `invoice_data.description`.
- **Fix:** replaced the single local with the four-instance-var structure, matching the analog:
  ```ruby
  pack_name = OrganizationAiCreditPurchase::AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY.dig(lookup_key, :name) || lookup_key
  @description = "AI Credit Top-Up — #{pack_name}"
  @final_description = @description
  @invoice_description = "AI Credit Top-Up — #{pack_name}"
  @final_invoice_description = @invoice_description
  ```
  The analog's `@final_*` variants append a WWR per-org discount note (`organization.settings['wwr_percent_off']`). AI credit one-off purchases have no per-org discount mechanism, so the `@final_*` variants collapse to the base (data-model difference, documented in-code). `invoice_data.description` updated from the old local `description` to `@final_invoice_description` (mirrors the analog, which uses `@final_invoice_description` for `invoice_data.description`).

## Dev 4 — Checkout price-not-found guard the analog has no analog for

- **Analog:** `board_wwr_listings_controller.rb:77` resolves `amount = @listing.calculate_charge_amount` as the single first statement inside the `if @listing.save` block with NO subsequent guard.
- **Was:** resolved `prices = Stripe::Price.list(...)` / `price = prices.data.first`, then `unless price ... render_general_errors(['Price not found in Stripe for this lookup key']); return`.
- **Fix:** removed the `unless price` guard/early-return and the `Price not found` error string; resolve `price` inline as the single first statement in the save block, mirroring the analog's `amount = @listing.calculate_charge_amount`:
  ```ruby
  price = Stripe::Price.list(lookup_keys: [lookup_key], active: true, limit: 1).data.first
  ```
  (The `Stripe::Price.list` resolution itself remains, per sanctioned deviation #6 — only the extra guard was removed.)

## Dev 5 — Checkout `line_items` omits product_data name/description the analog provides

- **Analog:** `board_wwr_listings_controller.rb:84-92` `line_items[0].price_data.product_data` carries `name` and `description: @final_description`.
- **OURS:** `line_items: [{ price: price.id, quantity: 1 }]` (using `price: price.id` is sanctioned #4/#6), which carries no inline product name/description.
- **CANNOT-MATCH:** Stripe rejects mixing `price:` with `price_data`/`product_data` in one line item — they are mutually exclusive. Because sanctioned deviation #4/#6 mandates `price: price.id`, the line-item name/description cannot be supplied inline; it lives on the Stripe Price's Product (dashboard-managed). The product-description content the analog puts on the line item is preserved in OURS' `invoice_data.description` (now `@final_invoice_description` after Dev 3). Forced by sanctioned deviation #4/#6, not by effort.
- **Action:** appended as **W9** to `SUGGESTED-WHITELISTS.md`. No code change (the closest match — relying on the Stripe Price's Product name/description plus the invoice description — is already in place).

## Dev 6 — Direct-charge model issues a Stripe network call before its guards

- **Analog:** `board_wwr_listing.rb:113` computes `amount = calculate_charge_amount` (LOCAL, no I/O) before the double-charge guard (:115) and the `stripe_customer_id.blank?` guard (:122) — zero Stripe calls before the guards short-circuit.
- **Was:** `charge_for_purchase` (`organization_ai_credit_purchase.rb`) called `Stripe::Price.list(...).data.first.unit_amount` BEFORE the double-charge guard and the blank-customer guard, so the Stripe API call fired even for an already-charged purchase or an org with no `stripe_customer_id`.
- **Fix:** moved both guards (`return if stripe_invoice_id.present? && stripe_invoice_paid?` and `return if organization.stripe_customer_id.blank?`) ABOVE the `Stripe::Price.list` amount resolution, so the amount-resolving network call now fires only after both guards pass — restoring the analog's local-then-guard ordering (zero Stripe calls before short-circuit). The `Stripe::Price.list` amount resolution itself is unchanged (sanctioned #6); only its placement moved.

---

## CANNOT-MATCH summary

- **Dev 5** (checkout line-item product name/description) — forced by sanctioned deviation #4/#6 (`price: price.id` is mutually exclusive with inline `product_data`). Recorded as W9 in SUGGESTED-WHITELISTS.md.

## SUGGESTED-WHITELISTS additions

- **W9** — checkout `line_items` carries no Stripe-hosted product name/description where the analog's does (Dev 5). Forced by sanctioned deviation #4/#6.

## Verification

- `ruby -c` passes on both edited files.
