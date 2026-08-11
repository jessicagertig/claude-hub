# Round 6 — Fix Log (AI credit one-off purchase analog audit)

Audit reported 7 deviations. 1 was a real bug and is FIXED. 1 is already sanctioned
(no change). 5 are data-model-forced CANNOT-MATCH items already documented in
SUGGESTED-WHITELISTS (one newly added this round).

---

## FIXED

### Dev 3 — `prices` action references undefined `registered_keys`
- **File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:201`
- **Before:** `Stripe::Price.list(lookup_keys: OrganizationAiCreditPurchase.registered_keys, ...)` — `registered_keys` is not defined on the model (it defines `ai_credit_lookup_keys`). This raised `NoMethodError` at runtime, so the `prices` catalog endpoint was broken (diverging from the analog's working catalog fetch).
- **After:** `Stripe::Price.list(lookup_keys: OrganizationAiCreditPurchase.ai_credit_lookup_keys, ...)` — calls the real method. This matches the data-fetching analog (a working catalog fetch) and the trace's documented `ai_credit_lookup_keys` usage.
- No frontend change needed: the response shape (`Stripe::Price.list` json) is unchanged; only the lookup-key source method name was wrong.

---

## NO CHANGE — already sanctioned

### Dev 6 — direct-charge amount resolved from Stripe (not local hardcode)
- `charge_for_purchase` resolves the charge amount via `Stripe::Price.list(...).data.first.unit_amount` rather than the analog's local `calculate_charge_amount`.
- This is covered by **SANCTIONED-DEVIATIONS #4**: "the product data model for AI credit purchases follows the subscription analog (Stripe Products/Prices resolved by lookup key), not the WWR analog (locally hardcoded cent amounts) ... The charge/fulfillment FLOW follows WWR; the data-fetching pattern follows the subscription analog." The in-model `Stripe::Price.list` is the direct consequence of the sanctioned "amount lives in Stripe" data model (also confirmed by the trace's price-model section). No change.

---

## CANNOT-MATCH (data-model-forced; already in SUGGESTED-WHITELISTS)

These were re-flagged by the audit because they are not in SANCTIONED-DEVIATIONS
(owner-only). They cannot be matched to the analog because the analog's concept does
not exist in the AI credit flow. None are forced by effort.

- **CANNOT-MATCH: Dev 1 (broadcast_event channel/target/payload):** analog broadcasts on `JobChannel.broadcast_to(job, event:, payload: { jobId, boardWwrListingId, wwrSlug, publishedAt })`. OURS has no `Job` (org-scoped purchase) and the AI-credit billing frontend listens on `GlobalChannel` (keyed by `action:`), never on `JobChannel`. The payload keys `wwrSlug`/`publishedAt` are WWR-listing columns OURS lacks. → existing **W4**.
- **CANNOT-MATCH: Dev 2 (notification-flag reset in grant_credits):** `balance.update_columns(sent_low_notification_since_increase: false, sent_zero_notification_since_increase: false)`. Analog `create_on_wwr` has no companion balance record to reset. Forced by the data model. → existing **W1**.
- **CANNOT-MATCH: Dev 5 (no job-scope `exists(...)` lookup + no job-description guard):** the analog wraps the body in `exists(current_organization.jobs.where(id: params[:job_id]), ...)` and guards `job.description.blank?`. There is no `Job`, no `params[:job_id]`, and no `job.description` in the AI credit top-up flow (org-scoped). Forced by the data model. → existing **W5**.
- **CANNOT-MATCH: Dev 7 (authorize passes explicit `:create?`):** analog's bare `authorize @listing` infers `create?` from the action name `create`. OURS' action is `purchase_top_up`, so a bare `authorize` would infer the nonexistent `purchase_top_up?`; the explicit `:create?` invokes the same policy method the analog's bare form resolves. Forced by the non-RESTful action name. → existing **W6**.

### Newly added to SUGGESTED-WHITELISTS this round

- **CANNOT-MATCH: Dev 4 (build pre-stamps `stripe_amount: 0` and `currency: 'usd'`):** I removed the pre-stamps in both `purchase_top_up` and `purchase_top_up_checkout_session` to match the analog (which leaves `stripe_amount` unset until charged), but the save then failed at the DB layer: `organization_ai_credit_purchases.stripe_amount` is declared `null: false` with no default (`db/schema.rb:972`), whereas the analog's `board_wwr_listings.stripe_amount` is nullable. Matching the analog exactly requires a migration making the column nullable plus relaxing the `stripe_amount`/`currency` presence validations to fire only after charge — a schema + shared-validation change, out of scope for a one-off audit fix and a NOT-NULL/validation change is shared infrastructure (pipeline failure-pattern #20). I reverted the pre-stamp removal and the validation relaxation; the original pre-stamps stand unchanged. Added as **W7** in SUGGESTED-WHITELISTS with the `null: false` reasoning.

---

## Files changed
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` — line 201: `registered_keys` → `ai_credit_lookup_keys` (Dev 3). No other code changes (Dev 4 attempt reverted).
- `/Users/jessica/claude-hub/inflow-ats/ai-billing-overhaul-2026-06-23/SUGGESTED-WHITELISTS.md` — added W7 (Dev 4).

No `spec/` files touched. No migrations, new methods, branches, or validations added.
