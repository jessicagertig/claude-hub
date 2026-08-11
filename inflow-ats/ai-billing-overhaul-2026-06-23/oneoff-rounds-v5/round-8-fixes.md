# Round 8 Fixes — AI Credit One-Off Purchase Analog Audit

Audit reported 1 deviation. No code changes were made (the one deviation is a genuine CANNOT-MATCH, data-model-forced).

---

## Dev 1 — Checkout-session build omits the analog's `status: 'approved'` listing-lifecycle stamp

**CANNOT-MATCH.**

- **OURS:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:123-132` — `purchase_top_up_checkout_session` builds `OrganizationAiCreditPurchase.new({ organization:, last_updated_by_organization_user:, kind:, stripe_price_lookup_key:, one_off_credits_granted:, stripe_amount: 0, currency:, stripe_invoice_paid: false })` with no `status` field.
- **ANALOG:** `app/controllers/api/v1/board_wwr_listings_controller.rb:59-63` — `create_checkout_session` merges `{ last_updated_by_organization_user:, status: 'approved', stripe_invoice_paid: false }`.

**Why it cannot be matched (verified against live schema, not inferred):**

- `db/schema.rb:965-993` — the `organization_ai_credit_purchases` table has NO general `status` column. Its only status-like column is `subscription_status` (integer, line 978), the Stripe subscription-lifecycle enum, which is irrelevant to a one-off purchase and has no `approved` member.
- `db/schema.rb:259-279` — the analog's `board_wwr_listings.status` (integer, `default: 0`, line 262) is the WeWorkRemotely **listing-lifecycle** enum. It gates whether a listing is publishable to the external WWR service once payment clears; the awaiting-payment record is pre-stamped `approved` so it can go live after Stripe confirms payment.
- `OrganizationAiCreditPurchase` has no listing lifecycle: credits are granted once, never published to a third-party service, and never expire as a listing. There is no column to set and no enumerated counterpart to `approved`.
- The record's actual lifecycle marker is `stripe_invoice_paid` — `false` on the awaiting-payment checkout build, set `true` after payment. OURS already stamps `stripe_invoice_paid: false` at line 131, which is the same companion flag the analog also sets alongside `status: 'approved'` (line 62).

**Closest fix (already present):** `stripe_invoice_paid: false` is the lifecycle stamp our data model has, and it is already on the build. Adding a `status` column or a new enum value purely to mirror the analog would be an unscoped shared-infrastructure change — exactly the failure pattern prohibited by inflow-ats CLAUDE.md rule #20 (don't add enum values / repurpose status to "match a finding" without owner approval). No code change made.

Traced: `round-8-audit.md` → `organization_ai_credit_purchases_controller.rb:123-132` → `db/schema.rb:965-993` (no `status` col) → `board_wwr_listings_controller.rb:59-63` (analog) → `db/schema.rb:259-279` (analog `status` is listing-lifecycle enum).

---

## CANNOT-MATCH items

- **Dev 1** (above): checkout-session `status: 'approved'` has no corresponding column/enum in `organization_ai_credit_purchases`; the analog's `status` is an external-listing-lifecycle enum with no counterpart in a one-shot credit grant. Forced by the data-model difference, not by effort.

## SUGGESTED-WHITELISTS additions

- Appended **W12** to `/Users/jessica/claude-hub/inflow-ats/ai-billing-overhaul-2026-06-23/SUGGESTED-WHITELISTS.md` documenting Dev 1 for Jessica's review.

## SANCTIONED-DEVIATIONS

- Not modified (owner-only).
