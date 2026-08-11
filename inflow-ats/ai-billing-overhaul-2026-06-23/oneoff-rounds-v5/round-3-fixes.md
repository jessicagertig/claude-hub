# Round 3 — One-Off Purchase Analog Audit — Fix Log

Audit reported 4 deviations. 3 fixed in code; 1 is a conflict with SANCTIONED-DEVIATIONS.md (no change made, recorded below).

---

## Dev 1 — Amount resolution placement (FIXED)

**Finding:** ANALOG `board_wwr_listing.rb:113` computes `amount = calculate_charge_amount` as the FIRST statement of `charge_for_listing`, BEFORE the double-charge guard and the `stripe_customer_id.blank?` guard. OURS resolved `amount` (`Stripe::Price.list(...).unit_amount`) AFTER both guards. Sanctioned #6 covers using `Stripe::Price.list` in place of `calculate_charge_amount`, but the before-guards → after-guards placement inversion is not sanctioned.

**Fix:** `app/models/organization_ai_credit_purchase.rb` `charge_for_purchase`. Moved the `amount = Stripe::Price.list(...).data.first.unit_amount` line to be the FIRST statement of the method (now line 137), before `Rails.logger.info`, before the `stripe_invoice_id.present? && stripe_invoice_paid?` double-charge guard (line 144), and before the `organization.stripe_customer_id.blank?` guard (line 146) — matching the analog's `amount = calculate_charge_amount` first-statement placement. Replaced the old "placed AFTER both guards" comment with one noting the amount is resolved first, mirroring the analog. No other behavior changed.

**Before/after intent:** amount was computed only after the guards short-circuited (deferring the Stripe::Price.list network call); now it is computed unconditionally at method entry exactly like the analog computes its local amount.

---

## Dev 4 — Invoice/item description local var vs analog's instance variables (FIXED)

**Finding:** ANALOG `board_wwr_listing.rb:124-126` sets `@description` and `@final_description` (instance variables) and passes `@final_description` into the `Stripe::InvoiceItem`. OURS set a local `description` and passed it into the InvoiceItem; no `@final_description` instance variable existed.

**Fix:** `app/models/organization_ai_credit_purchase.rb` `charge_for_purchase` (lines 148-158). Changed `description = "AI Credit Top-Up — ..."` to `@description = "AI Credit Top-Up — ..."`, added `@final_description = @description`, and changed the `Stripe::InvoiceItem.create` `description:` argument from `description` to `@final_description`. Structure now mirrors the analog (base `@description` → `@final_description` → passed into the InvoiceItem). The analog's `@final_description` appends a `wwr_percent_off` discount clause when present; OURS has no discount concept (per W8 — AI credit pricing follows the subscription analog, no plan/discount), so `@final_description = @description` is the no-discount form of the analog's construction.

**Note:** the description CONTENT deviation (lookup-key name map vs the analog's plan/discount/job.title construction) is already whitelisted as **W8** in SUGGESTED-WHITELISTS.md and is not re-addressed; this fix only converts the storage from a local var to the analog's `@description`/`@final_description` instance variables.

---

## Dev 3 — Frontend top-up error handler (PARTIALLY FIXED; 2 sub-items CANNOT-MATCH)

**Finding:** ANALOG `JobDistributionWeWorkRemotely.tsx:273-287` `handleCreateBoardWwrListing` onError runs `setIsPurchasing(false)`, `setErrors(response.data.errors)`, `window.logger(...)`, then conditional `addToast({ title, kind: "warning" })` (no delay). OURS `handlePurchaseError` ran only `addToast({ title: error?.data?.errors?.general?.[0] || "Top-up checkout failed", kind: "warning", delay: 10000 })` — no logger, no error-state set, and a `delay: 10000` absent from the analog.

**Fix:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` `handlePurchaseError` (lines 161-170). Rewrote to mirror the analog's structure:
- Added the `window.logger("%c[AiCreditSubscription] purchaseTopUp", "color: #FF0602", { error })` call the analog has.
- Removed the `delay: 10000` (absent from the analog).
- Wrapped the `addToast` in the analog's `if (errors["general"] != undefined)` guard and removed the fabricated `|| "Top-up checkout failed"` fallback string (the analog toasts only the real `general[0]` message and only when present).
- Kept the `error.data.errors` access path. The analog names its param `response` and uses direct access; OURS' `apiMutate` (`api.ts:54-62`) rejects with the same normalized `{ ...response, data: camelCased }` object, so `error.data.errors.general[0]` reads the same field. Optional chaining retained on the guard read for the same robustness the rest of OURS' handlers use.

**CANNOT-MATCH (2 sub-items):**
- `setIsPurchasing(false)`: OURS' `AiCreditSubscription` component has NO `isPurchasing`/`setIsPurchasing` local state. `isPurchasing` is derived from the mutation's `isLoading` (`usePurchaseAiCreditTopUp`, `AiCreditSubscription.tsx:46`), which React Query resets to `false` automatically on settle. The analog's `JobDistributionWeWorkRemotely` carries a `useState`-backed `isPurchasing` because its loading is hand-managed; OURS does not. Adding `setIsPurchasing(false)` would require fabricating a `useState` the component does not have and that would shadow the mutation-derived flag — an unscoped addition. Closest match: rely on React Query's automatic reset (already in place).
- `setErrors(response.data.errors)`: OURS' `AiCreditSubscription` component has NO error state (`setErrors`) at all — no `errors`/`setErrors` `useState`, and no UI consumer of such state. The analog's WWR component renders form-field errors from a `setErrors` state; OURS surfaces errors only via toast. Adding `setErrors` would require fabricating a `useState` and a consuming render path the component does not have — unscoped. Closest match: surface the error via the toast (already in place).

Both sub-items are forced by OURS' component shape (mutation-derived loading + toast-only error surfacing vs the analog's hand-managed loading + inline error rendering). Appended to SUGGESTED-WHITELISTS.md as W10.

---

## Dev 2 — Extra balance notification-flag reset in grant_credits (NO CHANGE — CONFLICT WITH SANCTIONED-DEVIATIONS.md)

**Finding (audit):** OURS `grant_credits` adds `balance.update_columns(sent_low_notification_since_increase: false, sent_zero_notification_since_increase: false)` before the broadcast/notification tail; the audit claims this step "has no analog and is NOT listed in SANCTIONED-DEVIATIONS.md (it is only marked CANNOT-MATCH/whitelist in the trace)."

**Resolution: NO CODE CHANGE.** The audit finding is incorrect on the sanctioning status. This exact step IS sanctioned:
- **SANCTIONED-DEVIATIONS.md item #9** ("Balance notification-suppression flag reset on credit grant") explicitly sanctions `balance.update_columns(sent_low_notification_since_increase: false, sent_zero_notification_since_increase: false)` at `organization_ai_credit_purchase.rb:222-225` in the one-off `grant_credits`, stating it is "Forced by our domain (the `OrganizationAiCreditBalance` companion record)" because WWR has no credit balance to reset.
- It is ALSO whitelisted as **W1** in SUGGESTED-WHITELISTS.md (W8's closing note confirms: "oneoff-v5 round-1 Dev 2 ... is the same deviation already whitelisted as W1").

Per the fix-agent rules, SANCTIONED-DEVIATIONS.md is the authoritative list of acceptable deviations, and item #9 covers this exact line. Removing it would destroy sanctioned/approved work (and would re-break the user-facing low/zero-credit re-warning behavior the flag reset exists to provide). I made no change and surfaced the conflict for owner resolution rather than self-classifying. Recorded in SUGGESTED-WHITELISTS.md note alongside W1.

---

## Files changed

- `app/models/organization_ai_credit_purchase.rb` — Dev 1 (amount-first placement) + Dev 4 (`@description`/`@final_description` instance vars).
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` — Dev 3 (logger added, delay removed, analog `if general != undefined` toast structure).

## SUGGESTED-WHITELISTS additions

- **W10** — Dev 3 sub-items `setIsPurchasing(false)` and `setErrors(...)` cannot match (OURS component has neither state).
- **Conflict note on W1** — Dev 2 re-reported by the round-3 audit as unsanctioned, but it is SANCTIONED #9 + whitelisted W1; no change made.
