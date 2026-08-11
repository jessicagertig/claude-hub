# One-Off Purchase — Round 1 Fixes (v2)

### app/models/organization_ai_credit_purchase.rb

Definitively confirmed. The task's cited "OURS" line numbers correspond exactly to the **working-tree (already-fixed) content**:
- Model:125-126 = the guard with `&& stripe_invoice_paid?` (Deviation 1's described state)
- Model:78-79 = `belongs_to :last_updated_by_organization_user` (Deviation 2 leg A — already present)
- Controller:89-96 = the `OrganizationAiCreditPurchase.new(...)` block ending at `last_updated_by_organization_user: current_organization_user` (Deviation 2 leg B — already present)
- Interactor:94-98 = the growl block targeting `last_updated_by_organization_user.user` (Deviation 2 leg C — already present)

The task author wrote the deviation report against the working tree, which already contains the fixes for Deviation 2 and the `stripe_invoice_paid?` choice for Deviation 1. So:

- **Deviation 2 is already fully resolved** in the working tree and structurally matches the analog across all three legs (belongs_to declaration, creation-time stamp, growl targeting `last_updated_by_organization_user.user`). No change needed.

- **Deviation 1 cannot be matched to the analog's exact `is_active?`/`live?` temporal semantic** because `OrganizationAiCreditPurchase` has no temporal lifecycle (no `expires_at`/`published_at`/active-window). The existing `stripe_invoice_paid?` is the semantically-correct second predicate for a one-off payment record. This is a WHITELIST.

I am making **no code edits** — the working tree already represents the correct end state for both assigned deviations, and the only "fix" Deviation 1 could take (adding a temporal lifecycle) would be inventing infrastructure that violates CLAUDE.md rule 20 (don't add shared infrastructure to close a gap) and rule 10 (minimum change).

I should NOT touch the stale spec files (the `amount_cents_paid` rename misses and the two response-shape assertion lags) — those are out of scope for my two assigned deviations, and fixing them would violate scope discipline (rules 10, 21). But I must surface them clearly since they're failing tests in the area.

Here is my final report.

---

**SUMMARY: No code changes made. Both assigned deviations are already in their correct end state in the working tree (`/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`). The deviation report's cited "OURS" line numbers (model:125, model:78-79, controller:89-96, interactor:94-98) match the working tree, which already contains the fixes — confirming the report was written against the working tree, not the staged blob.**

Files inspected (chain traced):
`organization_ai_credit_purchase.rb` → `board_wwr_listing.rb` (analog, `is_active?` :54, `broadcast_show_growl` :271) → `board_what_jobs_listing.rb` (analog, `live?` :80) → `organization_ai_credit_purchases_controller.rb` → `board_wwr_listings_controller.rb` (analog `#create` :5-11) → `apply_ai_credit_purchase.rb` → `paid_ai_credit_pack_purchased_job.rb` / `paid_wwr_listing_created_job.rb` → `organization_user.rb` (`belongs_to :user`) → `base_controller.rb` (`current_organization_user` :27) → `db/schema.rb` (purchases table :965-989).

---

**DEVIATION 1 (double-charge guard second predicate) — WHITELIST**

`WHITELIST: organization_ai_credit_purchase.rb:126 double-charge guard second predicate (stripe_invoice_paid? instead of is_active?/live?): The analog's second predicate (BoardWwrListing#is_active? = expires_at.present? && expires_at > now && approved?; BoardWhatJobsListing#live? = what_jobs_expires_at.present? && what_jobs_expires_at > now && active?) is a temporal "is this listing currently live" check. A listing is a time-bounded, renewable record with an expiry window. A one-off AI-credit top-up is NOT — OrganizationAiCreditPurchase has no expires_at, published_at, or active-window column (verified against db/schema.rb:965-989 and grep of the model: no active?/live?/is_active?/expires_at/published_at exist), because credits are granted once and never expire as a listing. There is no structural equivalent of is_active?/live? on this model. Matching the analog's literal predicate would require inventing a temporal lifecycle (new column + method) the purchase model does not have and does not need — an infrastructure addition (violates the "minimum change" and "don't add shared infrastructure to close a gap" rules). stripe_invoice_paid? is the semantically-correct second predicate for a payment record: skip re-charging only if a Stripe invoice id is already stamped AND that prior charge was confirmed paid. The guard shape (stripe_invoice_id.present? && <second predicate>) matches the analog; only the second predicate differs, and it differs because the underlying record type differs (one-shot payment vs. time-bounded listing).`

---

**DEVIATION 2 (`last_updated_by_organization_user` unused / growl targets owner) — ALREADY MATCHED, no change needed**

All three legs of the analog pattern are already present in the working tree and structurally match the analog:

- **Leg A — model belongs_to** (`organization_ai_credit_purchase.rb:79`): `belongs_to :last_updated_by_organization_user, class_name: 'OrganizationUser', optional: true` — byte-for-byte identical to the analog `board_wwr_listing.rb:6`.
- **Leg B — controller stamps at creation** (`organization_ai_credit_purchases_controller.rb:96`): `last_updated_by_organization_user: current_organization_user` set on the `OrganizationAiCreditPurchase.new(...)` in `#purchase_top_up`, mirroring the analog's `listing_params.merge({ last_updated_by_organization_user: current_organization_user })` at `board_wwr_listings_controller.rb:11`. `current_organization_user` resolves via `base_controller.rb:27`.
- **Leg C — post-payment growl targets the stamping user** (`apply_ai_credit_purchase.rb:94-99`): `growl_target = existing.last_updated_by_organization_user_id.nil? ? organization.owner : existing.last_updated_by_organization_user.user`, then `GlobalChannel.broadcast_to(growl_target, action: 'showGrowl', ...)` — structurally identical to the analog's `broadcast_show_growl` at `board_wwr_listing.rb:271-273` (`last_updated_by_organization_user_id.nil? ? job.organization.owner : last_updated_by_organization_user.user`). The column is therefore populated at creation and consumed at growl time — not null/unused. `OrganizationUser#user` exists (`organization_user.rb:10`), so `.user` resolves. The companion Slack notification `Notification::PaidAiCreditPackPurchasedJob` (interactor:102) mirrors the analog's `Notification::PaidWwrListingCreatedJob` structurally.

---

**OUT-OF-SCOPE FINDING (NOT one of my two deviations — flagging, not fixing):** The targeted specs for these files are RED (20 failures), but every failure is a pre-existing test-staleness issue unrelated to my two deviations, in two categories:

1. **`amount_cents_paid` rename cascade miss (CLAUDE.md rule 6).** Migration `20260611120002` renames `amount_cents_paid` → `stripe_amount`. App code is fully migrated (grep of `app/`/`config/`/`lib/` = zero stale refs). But 6 spec files still reference `amount_cents_paid` (`spec/models/organization_ai_credit_purchase_spec.rb`, `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`, `spec/interactors/apply_ai_credit_purchase_spec.rb`, `spec/interactors/cancel_ai_credit_subscription_spec.rb`, `spec/interactors/apply_ai_credit_refund_spec.rb`, `spec/controllers/api/v1/organization_ai_credit_purchases_change_subscription_spec.rb`), causing `ActiveModel::UnknownAttributeError`.
2. **Response-shape assertion lag (separate working-tree change, not my deviation).** `organization_ai_credit_purchases_purchase_top_up_spec.rb:91` still asserts `json_response['charged'] == true` but the direct-charge path now returns a serialized purchase; line 129 still asserts HTTP 200 but the checkout path now returns 201 (`status: :created`). These align the controller responses to the WWR analog but their specs were not updated.

I did not edit these spec files because the rename and the response-shape changes are outside the two deviations I was assigned, and fixing them inline would exceed the defect scope. If you want them brought green, that is a separate spec-update task (mechanical: rename `amount_cents_paid` → `stripe_amount` in the 6 spec files; update the two `purchase_top_up` controller-spec assertions to expect the serialized body and 201).

---

### app/controllers/api/v1/organization_ai_credit_purchases_controller.rb

All confirmed. The deviation is already resolved in the working tree.

Findings:

- **`render json:` at line 153** (the `purchase_top_up` checkout-session path) is `render json: { url: session.url, sessionId: session.id }, status: :created` — already matches the WWR analog (`board_wwr_listings_controller.rb:120`).
- **WWR analog frontend** (`JobDistributionWeWorkRemotely.tsx:339`) reads `data.url`.
- **Our frontend** (`AiCreditSubscription.tsx:161-164`) reads `data.url` (`onSuccess: (data: { url?: string; charged?: boolean })` → `if (data.url) { redirectToStripe({ redirectUrl: data.url }) }`) — already matches.
- The **spec** (`organization_ai_credit_purchases_purchase_top_up_spec.rb:127-130`) already asserts `json_response['url']` for the checkout path and `json_response` has no key `url` for the direct-charge path (line 92).

No changes were made — the `purchase_top_up` one-off flow already uses the `url` / `sessionId` wire key matching the analog on both backend and frontend, and the spec already pins this contract.

WHITELIST: redirectUrl on lines 60, 198, 253 of organization_ai_credit_purchases_controller.rb (read at AiCreditSubscription.tsx:61, 87, 127): These belong to the subscription `checkout` and Stripe Billing-Portal flows (`change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`), NOT the one-off `purchase_top_up` flow that `oneoff-purchase-trace.md` analogs against. They are internally consistent (`{ redirectUrl: session.url }` ↔ `window.location.href = data.redirectUrl`) and outside the scope of this one-off-purchase deviation; the WWR one-off analog only governs the `purchase_top_up` checkout-session response, which already uses `url` + `sessionId`. Changing them would alter unrelated working code paths.

---

### app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx

Confirmed. Tracing every `addToast` in `AiCreditSubscription.tsx` against the direct-charge (card-on-file) success path:

- Line 60 (`redirectToStripe`): only reachable on the **checkout/no-card** path (`if (data.url)`), not the direct-charge path.
- Lines 98, 137: `onError` for subscription change flows — unrelated to top-up direct charge.
- Line 174: `onError` of `purchaseTopUp` — error path, not success.
- Lines 211, 213: cancel-subscription flow — unrelated.

`PurchaseAiCreditTopUpConfirmModal` (the card-on-file confirm modal) has no toast; its `onConfirm` just calls `removeModal()` then `purchaseTopUp(pack)` (`AiCreditSubscription.tsx:190-193`).

There is **no `addToast` on the direct-charge success path**. The single user-facing message is the later WebSocket growl from `ApplyAiCreditPurchase` (`apply_ai_credit_purchase.rb:95-99`). This structurally matches the analog WWR direct-charge flow (`JobDistributionWeWorkRemotely.tsx:269-272` errors-only `setErrors`/`setIsDirty`; single growl from `board_wwr_listing.rb:194`).

Chain traced: `AiCreditSubscription.tsx` (`purchaseTopUp` onSuccess 161-172; `handleBuyPack` 184-202) → `PurchaseAiCreditTopUpConfirmModal.tsx` (no toast) → backend growl `apply_ai_credit_purchase.rb:95-99`. Analog: `JobDistributionWeWorkRemotely.tsx:269-272` → `board_wwr_listing.rb:194`.

No changes were made — the deviation was already resolved in the working tree before I started.

---

CHANGED: nothing. Deviation item 1 is already fixed in the working tree (the fix predates this task; it is an uncommitted change relative to HEAD).

Evidence:
- The deviation report cited an immediate `addToast({ title: 'Payment received -- your credits will appear shortly.', kind: 'success' })` at `AiCreditSubscription.tsx:165-168`. That toast does NOT exist in the current working tree (nor in HEAD). Lines 165-171 are now a comment block explaining the direct-charge path intentionally shows no toast.
- Current `purchaseTopUp` `onSuccess` (`AiCreditSubscription.tsx:161-172`) only calls `redirectToStripe` when `data.url` is present (checkout/no-card path). The direct-charge path (no `data.url`) fires no toast.
- Traced every `addToast` in the file (lines 60, 98, 137, 174, 211, 213) — none is reachable on the direct-charge success path. `PurchaseAiCreditTopUpConfirmModal.tsx` has no toast either.
- This matches the analog: WWR direct-charge `onSuccess` (`JobDistributionWeWorkRemotely.tsx:269-272`) shows only `setErrors(null)`/`setIsDirty(false)`, and the single user-facing message is the later growl `board_wwr_listing.rb:194`. OURS' single message is the later WebSocket growl in `apply_ai_credit_purchase.rb:95-99` (the TRACE's `apply_ai_credit_purchase.rb:94-98`).

Result: one message on the direct-charge path (webhook growl only), structurally matching the analog. No code edits needed.

No WHITELIST or REVERT items.
