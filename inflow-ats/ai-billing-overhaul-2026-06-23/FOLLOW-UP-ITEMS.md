# AI Credit Billing — Follow-Up Items

Items to address after the current audit/fix cycle completes. Not blocking the analog-matching work.

---

1. **Rename `ai_credit_pack_subscription` metadata key** — controller:42 sets it, webhook:58 reads it. Should be `ai_credit_subscription` (drop "pack"). Only dev lookup keys should contain "pack."

2. **Rename `existing` variable** in `apply_ai_credit_purchase.rb` — should be `organization_ai_credit_purchase` per the new variable naming rule (CLAUDE.md rule 18).

3. **Spec updates for `amount_cents_paid` → `stripe_amount` rename** — 6 spec files still reference `amount_cents_paid`, causing `ActiveModel::UnknownAttributeError`. Mechanical rename pass needed.

4. **Spec updates for response shape changes** — `purchase_top_up` spec still asserts `json_response['charged'] == true` (now returns serialized purchase) and HTTP 200 (now returns 201 for checkout path).

5. **`schema.rb` regeneration** — still shows `amount_cents_paid`, lacks `stripe_invoice_paid`, `stripe_invoice_item_id`, `last_updated_by_organization_user_id`. Run migration to update.

6. **Credit amounts in `planHelpers.ts`** — verify frontend credit counts match backend `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` for all production keys.
