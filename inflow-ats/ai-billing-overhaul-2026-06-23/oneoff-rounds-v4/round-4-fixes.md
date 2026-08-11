# Round 4 — One-Off Purchase Analog Audit — Fix Log

Analog: WWR (`BoardWwrListingsController#create` + `#create_checkout_session`, `BoardWwrListing`).
Audit reported 14 deviation entries. Several were explicitly "matches structurally"
notes (no fix needed); the rest are fixed below or reported as CANNOT-MATCH.

---

## Deviation 1 — Two analog paths collapsed into one controller action — FIXED

The analog has TWO actions (`#create` direct charge, `#create_checkout_session` no card),
each with its own route, authorize, and rescue. OURS had one `purchase_top_up` action
handling both branches with the org's `stripe_default_payment_method_on_file` checked
server-side.

**Backend** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`:
- Split `purchase_top_up` into:
  - `purchase_top_up` — direct-charge path ONLY (mirrors `#create`): build record →
    `authorize organization_ai_credit_purchase, :create?` → `if save → charge_for_purchase →
    render_one(serializer) else render_errors` → `rescue StandardError` rendering the
    payment-failure message.
  - `purchase_top_up_checkout_session` — checkout path ONLY (mirrors
    `#create_checkout_session`): `authorize :billing, :checkout?` at top → build → `if save`
    block → resolve Stripe price → create session → stamp session id via `update_columns` →
    `render { url, sessionId }` else `render_errors` → `rescue Stripe::StripeError`.
- **Route** `config/routes.rb:194`: added `post :purchase_top_up_checkout_session`.

**Frontend** (the analog decides which action to call client-side based on
`hasPaymentMethod`; OURS now matches):
- `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts`: added
  `purchaseAiCreditTopUpCheckoutSession` request fn + `usePurchaseAiCreditTopUpCheckoutSession`
  hook (POST `/ai_credit_purchases/purchase_top_up_checkout_session`); exported it.
- `app/javascript/.../accountPlatoAi/AiCreditSubscription.tsx`: imported and called the new
  hook. `handleBuyPack` now branches on `stripeDefaultPaymentMethodOnFile`: card-on-file →
  confirm modal → `purchaseTopUp` (direct-charge mutation, serialized response, success toast);
  no card → `purchaseTopUpCheckoutSession` (checkout mutation, redirect to `data.url`).
  `isLoading` on `AiCreditPackCard` now ORs both mutations' loading flags.

This split subsumes Deviations 2, 3, 5, 7, 8 (all were artifacts of the collapsed action).

## Deviation 2 — Direct-charge path authorization object — FIXED

The collapsed action ran BOTH `authorize :billing, :checkout?` AND `authorize record`.
After the split, `purchase_top_up` (direct charge) authorizes ONLY the record, via
`authorize organization_ai_credit_purchase, :create?` (mirrors WWR `#create`'s
`authorize @listing` → `BoardWwrListingPolicy#create?`). `:create?` is passed explicitly
because Pundit would otherwise infer `purchase_top_up?`, which does not exist on
`OrganizationAiCreditPurchasePolicy` (only `show?`/`create?`).

## Deviation 3 — Checkout path authorization placement/object — FIXED

`purchase_top_up_checkout_session` authorizes ONLY `:billing, :checkout?` at the top
(mirrors `#create_checkout_session`), with no record authorize.

## Deviation 4 — Job-description blank guard absent — CANNOT-MATCH (whitelist W5)

No `Job` exists in the AI credit top-up flow, so there is no `job.description` precondition
to validate. Forced by the data-model difference (org-scoped purchase vs job-scoped listing).
Added to SUGGESTED-WHITELISTS.md as W5.

## Deviation 5 — Record built/authorized before validity branch — FIXED

Restructured the checkout action so the Stripe price lookup happens INSIDE the
`if organization_ai_credit_purchase.save` success block — exactly where WWR's
`#create_checkout_session` computes `amount = @listing.calculate_charge_amount`. Added the
`else render_errors(...)` branch the analog has. The price lookup (vs a local calculation)
is the sanctioned price-model deviation (#4), now placed structurally identically to the
analog's amount resolution.

## Deviation 6 — Direct-charge response key — NO FIX NEEDED (matches)

OURS' direct-charge action renders `render_one(organization_ai_credit_purchase, serializer)`,
mirroring WWR `#create`'s `render_one(@listing, serializer)`. The direct-charge frontend hook
no longer branches on `data.url` (branch removed), matching WWR's `useCreateBoardWwrListing`
which has no such branch.

## Deviation 7 — Direct-charge save-failure handling — FIXED

`purchase_top_up` is now wrapped in `rescue StandardError => e` rendering
`render_general_errors(["Unable to process payment: #{e.message}"])` (mirrors WWR `#create`).
The `else render_errors(organization_ai_credit_purchase)` save-failure branch is preserved.

## Deviation 8 — Direct-charge rescue type and shape — FIXED

Direct-charge path now uses `rescue StandardError` with the payment message (WWR `#create`
style), not `rescue Stripe::StripeError` (which now lives only on the checkout action,
matching WWR `#create_checkout_session`).

## Deviation 9 — Model charge method records currency on update_columns — NO FIX NEEDED (matches)

`organization_ai_credit_purchase.rb` `charge_for_purchase` already does
`update_columns(stripe_invoice_id:, stripe_invoice_item_id:, stripe_amount:)` with NO currency
column — matches WWR's three-column `update_columns`. Audit confirmed "matches three columns."

## Deviation 10 — Extra metadata key not present in analog — NO FIX NEEDED (matches)

Audit confirmed InvoiceItem/Invoice metadata is a single record-id key
(`organization_ai_credit_purchase_id`) — matches WWR's single `board_wwr_listing_id`.

## Deviation 11 — Webhook produce-method tail split into extra model methods — FIXED

`app/models/organization_ai_credit_purchase.rb`: inlined the signaling tail
(`broadcast_event`, `broadcast_show_growl(...)`, `Notification::PaidAiCreditPackPurchasedJob.perform_later`)
directly into `grant_credits`, before the `rescue` — mirroring WWR's `create_on_wwr` which
has its tail inline in one method. Deleted the separate `broadcast_purchase_complete` method.
Confirmed no remaining references to `broadcast_purchase_complete` anywhere in `app/`.

## Deviation 12 — broadcast_event channel and payload — CANNOT-MATCH (whitelist W4)

WWR uses `JobChannel.broadcast_to(job, event:, payload: {jobId, boardWwrListingId, wwrSlug, publishedAt})`.
`JobChannel#subscribed` requires `params[:jobId]` and `stream_for job` — it can only broadcast
to a `Job`, which the org-scoped top-up does not have, and the AI-credit frontend listens on
`GlobalChannel` (streamed for `current_user`), not `JobChannel`. The `action:` key and
`{ organizationId }` payload are the GlobalChannel consumer contract (the sibling
`broadcast_show_growl` on the same record also uses `GlobalChannel ... action:`). The
`wwrSlug`/`publishedAt` payload fields are WWR columns OURS lacks. Forced by the absence of a
`Job` and the channel contract. Added to SUGGESTED-WHITELISTS.md as W4. Left unchanged.

## Deviation 13 — grant_credits balance-notification reset and rescue — CANNOT-MATCH (whitelist W1)

The `balance.update_columns(sent_low_notification_since_increase: false, sent_zero_notification_since_increase: false)`
reset has no WWR analog because WWR listings have no companion balance record. OURS delivers
credits onto an `OrganizationAiCreditBalance` carrying notification-suppression flags; resetting
them on a credit increase is part of correctly delivering the product (otherwise low/zero-balance
notifications stay suppressed after a top-up — a functional regression). Forced by the data-model
difference; already documented as whitelist W1. KEPT in code (an in-code CANNOT-MATCH comment was
added pointing at W1). The rescue (`rescue StandardError => e` + log) matches WWR's `create_on_wwr`
rescue structure; only the log string differs (domain-appropriate), which is not a deviation.

## Deviation 14 — Checkout-session metadata distribution — FIXED (partial; remainder CANNOT-MATCH W3)

The working tree's `invoice_data.metadata` carried ONLY `organization_ai_credit_purchase_id`
(round-3's "organization_id matched" claim was stale). Fixed:
- Added `organization_id` to `invoice_data.metadata`.
- Added a `description` to `invoice_data` (mirrors WWR's `@final_invoice_description`).
The remaining gap — `job_id` present in all three WWR metadata blocks — is forced (no `Job`
in the flow) and remains whitelisted as W3 (round-4 note appended).

---

## SUGGESTED-WHITELISTS additions/updates (this round)

- **W3** — appended a round-4 note: `organization_id` was missing from `invoice_data.metadata`
  in the working tree at round-4 start (stale round-3 claim); re-added it plus an
  `invoice_data.description`. Only `job_id` remains omitted (data-model forced).
- **W4 (new)** — `broadcast_event` GlobalChannel/`action:`/`{organizationId}` vs analog's
  JobChannel/`event:`/full payload. Forced by absence of a `Job` + channel contract.
- **W5 (new)** — no job-description blank guard (and no `exists(jobs...)` wrapper). Forced by
  absence of a `Job` in the org-scoped flow.

(W1 and W2 already present from prior rounds; W1 remains the home for Deviation 13.)

---

## Verification

- `ruby -c` passes on the edited controller and model.
- `node_modules/.bin/tsc --noEmit -p tsconfig.json` — 0 errors in app source
  (`AiCreditSubscription.tsx`, `useOrganizationAiCreditPurchase.ts`); the 186 reported errors
  are all pre-existing `node_modules`/`@types` duplicate-declaration noise.
- No `app/` references remain to the deleted `broadcast_purchase_complete`.
- Per instructions, no `spec/` files were touched and no pre-existing code was reverted.
