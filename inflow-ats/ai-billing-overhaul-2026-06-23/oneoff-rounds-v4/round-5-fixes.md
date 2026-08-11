# Round 5 Fix Log — AI Credit One-Off Purchase Analog Audit

Audit reported 8 deviations. 5 fixed in code; 3 are CANNOT-MATCH (forced by the
no-Job org-scoped data model and the non-RESTful action name).

---

## Dev 1 — Direct-charge authorize passes explicit `:create?` symbol — CANNOT-MATCH

- **Analog:** `board_wwr_listings_controller.rb:19` bare `authorize @listing` (Pundit
  infers `create?` from the `create` action name).
- **Ours:** `organization_ai_credit_purchases_controller.rb:93`
  `authorize organization_ai_credit_purchase, :create?`.
- **CANNOT-MATCH:** OURS' direct-charge action is the non-RESTful collection route
  `purchase_top_up`. Bare `authorize record` infers the policy method from the action
  name, so bare `authorize organization_ai_credit_purchase` would look for a
  non-existent `purchase_top_up?` policy method. The explicit `:create?` is required
  to reach `OrganizationAiCreditPurchasePolicy#create?` — the same method the analog's
  bare form resolves. Making it bare would require renaming the action to `create`,
  cascading to routes + the frontend hook path + the mutation (unscoped).
- **Action:** left as-is (closest possible). Appended as **W6** to SUGGESTED-WHITELISTS.md.

## Dev 2 — Direct-charge action lacks the job-scoped `exists(...)` guard wrapper — CANNOT-MATCH

- **Analog:** `board_wwr_listings_controller.rb:6-9` wraps the body in
  `exists(current_organization.jobs.where(id: params[:job_id]), 'no job found') do |job|`
  and guards `job.description.blank?` / `return if performed?`.
- **Ours:** `purchase_top_up` builds the purchase on `current_organization` with no
  job lookup and no blank guard.
- **CANNOT-MATCH:** there is no `Job` in the AI credit top-up flow (no `params[:job_id]`,
  no `job`, no `job.description`). The wrapper and its guard are entirely job-scoped;
  OURS is org-scoped. Forced by the data-model difference.
- **Action:** left as-is. Already documented as **W5** in SUGGESTED-WHITELISTS.md (the
  job-description guard and the `exists(...)` wrapper are both covered there). No new
  whitelist entry needed.

## Dev 3 — Model adds `Stripe::Price.list` + `return if price.blank?` not in analog — FIXED

- **Analog:** `board_wwr_listing.rb:113` `amount = calculate_charge_amount` (single
  local statement, no network call, no blank guard).
- **Ours (before):** `organization_ai_credit_purchase.rb:136-138`
  `prices = Stripe::Price.list(...)` / `price = prices.data.first` /
  `return if price.blank?` / `amount = price.unit_amount`.
- **Fix:** collapsed to a single amount-resolving statement
  `amount = Stripe::Price.list(lookup_keys: [stripe_price_lookup_key], active: true, limit: 1).data.first.unit_amount`
  and removed the extra `return if price.blank?` early-return guard. The
  `Stripe::Price.list` call itself stays — it is the sanctioned price-via-Stripe
  resolution (SANCTIONED-DEVIATIONS #4); only the extra blank guard and the multi-line
  shape were the deviation. Now structurally mirrors the analog's single amount
  assignment with no guard.
- **File:** `app/models/organization_ai_credit_purchase.rb:136`.

## Dev 4 — Order of the "attempt to charge" log relative to amount resolution/guards — FIXED

- **Analog:** `board_wwr_listing.rb:113-115` — `amount = ...`, then
  `'Attempt to charge for WWR Listing'`, then the double-charge guard.
- **Ours (before):** resolved price + `return if price.blank?` FIRST, then logged, then
  the double-charge guard (log not adjacent to amount resolution).
- **Fix:** same edit as Dev 3. Now `amount = ...` → `Rails.logger.info 'Attempt to
  charge for AI Credit Top-Up'` → `return if stripe_invoice_id.present? &&
  stripe_invoice_paid?` (double-charge guard) → `return if
  organization.stripe_customer_id.blank?`, matching the analog's order exactly. The
  `stripe_invoice_paid?` second predicate is SANCTIONED-DEVIATIONS #2.
- **File:** `app/models/organization_ai_credit_purchase.rb:136-145`.

## Dev 5 — Checkout-session path stamps `stripe_checkout_session_id` on the record — FIXED

- **Analog:** `board_wwr_listings_controller.rb#create_checkout_session` never writes a
  checkout-session id back onto the record; the webhook keys off invoice metadata only.
- **Ours (before):** `organization_ai_credit_purchases_controller.rb:167`
  `organization_ai_credit_purchase.update_columns(stripe_checkout_session_id: session.id)`.
- **Fix:** removed the `update_columns(stripe_checkout_session_id: session.id)` line.
- **Webhook safety verified:** the one-off `invoice.paid` branch
  (`stripe_webhook_handler_job.rb:243-254`) finds the record purely by
  `organization_ai_credit_purchase_id` metadata (mirroring the analog's
  `board_wwr_listing_id` lookup); it does NOT use `stripe_checkout_session_id`. The
  session's `invoice_data.metadata` carries `organization_ai_credit_purchase_id`, so
  the primary lookup still resolves. (The `stripe_checkout_session_id` lookup at
  `stripe_webhook_handler_job.rb:59` is the SUBSCRIPTION `checkout.session.completed`
  path, out of scope for this one-off audit and unaffected.)
- **File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:167` (removed).

## Dev 6 — Checkout-session metadata omits `job_id` — CANNOT-MATCH

- **Analog:** `board_wwr_listings_controller.rb:94-115` puts `job_id: job.id` into all
  three metadata blocks.
- **Ours:** metadata carries `organization_ai_credit_purchase_id` and `organization_id`
  only — no `job_id`.
- **CANNOT-MATCH:** an AI credit top-up is org-scoped, not job-scoped — there is no
  `Job` record anywhere in the flow from which to read a `job_id`. Forced by the
  data-model difference.
- **Action:** left as-is. Already documented as **W3** in SUGGESTED-WHITELISTS.md. No new
  whitelist entry needed.

## Dev 7 — Frontend direct-charge `onSuccess` fires an extra success toast — FIXED

- **Analog:** `JobDistributionWeWorkRemotely.tsx:269-272` direct-charge `onSuccess` only
  `setErrors(null); setIsDirty(false)` — no toast (success growl is server-side from
  `create_on_wwr`).
- **Ours (before):** `AiCreditSubscription.tsx:178-180` `onSuccess` called
  `addToast({ title: "Payment received — your credits will appear shortly.", kind: "success" })`.
- **Fix:** removed the toast; `onSuccess` is now `() => {}`. OURS has no
  `setErrors`/`setIsDirty` state (different component), so the body is empty — the
  closest match to the analog's "no toast" success handler. The user-facing success
  growl is emitted server-side from `grant_credits`.
- **File:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:174-185`.

## Dev 8 — Frontend checkout-redirect shows an extra "Redirecting to Stripe checkout..." toast — FIXED

- **Analog:** `JobDistributionWeWorkRemotely.tsx:337-339` checkout `onSuccess` only
  `window.location.href = data.url` — no toast.
- **Ours (before):** `AiCreditSubscription.tsx:64-66` `redirectToStripe` called
  `addToast({ title: "Redirecting to Stripe checkout...", kind: "success" })` then set
  `window.location.href`.
- **Fix:** removed the toast; `redirectToStripe` now only sets `window.location.href = data.url`.
- **File:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:64-66`.

---

## CANNOT-MATCH summary

- **Dev 1** (explicit `:create?` authorize) — forced by non-RESTful action name → new **W6**.
- **Dev 2** (job-scoped `exists(...)` wrapper + blank guard) — forced by no-Job → already **W5**.
- **Dev 6** (`job_id` in checkout metadata) — forced by no-Job → already **W3**.

## SUGGESTED-WHITELISTS additions this round

- **W6** added (Dev 1, authorize `:create?`).
- W3 and W5 already existed and cover Dev 6 and Dev 2 respectively — no duplicate added.

## Files changed

- `app/models/organization_ai_credit_purchase.rb` (Dev 3, 4)
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (Dev 5)
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` (Dev 7, 8)
