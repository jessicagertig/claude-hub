# AI Credit Billing — Session Handoff

Branch: `ai-feature-work-v5`. Consolidated map of everything done this session, what's in the working tree, what's committed, open questions, decisions/conclusions, and hard-won context.

Companion doc (per-fix trail): `ai-credit-change-and-topup-analog-summary.md`. Migration plan: `ai-credit-cancel-at-period-end-migration-plan.md`. DB dump: `ai_credit_rollback_dump/`.

---

## 1. What this session built (two billing features + a DB column prep)

**A. AI credit subscription upgrade/downgrade** — mirror of the main-plan **Stripe Billing Portal** redirect (`BillingController#change_subscription_portal_session`). Redirect to Stripe's `subscription_update_confirm` portal; Stripe charges/schedules; `customer.subscription.updated` reconciles locally. No in-app item swap, no interactor, no service.

**B. One-off credit top-up direct charge** — mirror of the **WWR** payment-method-first flow (`BoardWwrListing#charge_for_listing`). Record pre-created, charged via a model method, webhook finalizes by metadata id. Card-on-file → immediate charge behind a confirmation modal; no card → existing Stripe Checkout.

**C. `stripe_cancel_at_period_end` column** on `organization_ai_credit_purchases` — added (committed) to support cancel-at-period-end. The *behavior* that uses it is NOT built yet (see Open Questions).

---

## 2. Working-tree changes (staged, 9 files) — uncommitted

- **`app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`** — added `#change_subscription_portal_session` (POST, builds `Stripe::BillingPortal::Session` with `subscription_update_confirm` flow_data, live-retrieves the subscription item id, renders `{ redirectUrl }`, fires `PosthogTrackJob('change_subscription_stripe_portal_opened')`). Rewrote `#purchase_top_up` to pre-create the `OrganizationAiCreditPurchase` then branch on `stripe_default_payment_method_on_file`: card-on-file → `purchase.charge_default_payment_method` + render `{ charged: true }`; else → Checkout Session + `{ redirectUrl }` (invoice metadata carries `organization_ai_credit_purchase_id`). Single params method extended with `:return_url`.
- **`app/models/organization_ai_credit_purchase.rb`** — added `#charge_default_payment_method` (mirrors `charge_for_listing`: `InvoiceItem` → `Invoice(charge_automatically)` → `pay` → `update_columns(stripe_invoice_id, amount_cents_paid, currency)`; guard `return if stripe_invoice_id.present?`; metadata incl. `organization_ai_credit_purchase_id`). Relaxed the one-off `stripe_checkout_session_id` presence validation to `if: -> { one_off? && stripe_invoice_id.blank? }`. Added Stripe statuses to the `subscription_status` enum: `trialing:4, incomplete:5, incomplete_expired:6, unpaid:7`.
- **`app/interactors/apply_ai_credit_purchase.rb`** — `apply_one_off` flipped from CREATE to FIND+GRANT (finds by `purchase_id` from invoice metadata, then `stripe_checkout_session_id`, then `stripe_invoice_id`); grant-once guard via existence of the `one_off_credit_pack_purchase_credit` ledger row. `apply_subscription` got a re-delivery idempotency guard (`return if existing.stripe_invoice_id == invoice.id`, single-line guard clause) and stamps `stripe_invoice_id`. Dead `lookup_key` removed.
- **`app/jobs/stripe_webhook_handler_job.rb`** — `customer.subscription.updated`: credit-pack branch (updates the purchase row's lookup_key/credits/status/period_end) + guarded main-plan branch (`object.id == organization.stripe_subscription_id`) which now also sets `stripe_cancel_at_period_end: object.cancel_at_period_end` (merged from your HEAD via the conflict resolution). `invoice.paid`: the `ai_credit_pack_top_up` branch passes `purchase_id`; the `CustomStripeSubscriptionMissingError` guard moved into the main-plan `else`; the `StandardError` rescue **no longer re-raises** (reverted to swallow-and-log, matching the other 3 handlers — your no-retry convention).
- **`app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts`** — added `useChangeAiCreditSubscriptionViaStripePortal`; `usePurchaseAiCreditTopUp` response type allows `{ redirectUrl?, charged? }`.
- **`app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`** — `handleSelectTier` change-branch (subscribed → portal redirect); `handleBuyPack` opens the confirm modal when card-on-file else Checkout; current-tier highlight now matches `subscription.stripePriceLookupKey === tier.lookupKey` (was a derived credit-count match).
- **`config/routes.rb`** — `post :change_subscription_portal_session`.
- **Specs (staged):** `spec/interactors/apply_ai_credit_purchase_spec.rb`, `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`.

### Untracked (new)
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/PurchaseAiCreditTopUpConfirmModal.tsx` — stateless confirmation modal (mirrors `CancelAiCreditSubscriptionConfirmModal`), "$X for N credits — card on file charged today."
- `spec/controllers/api/v1/organization_ai_credit_purchases_change_subscription_spec.rb`
- `spec/controllers/api/v1/organization_ai_credit_purchases_purchase_top_up_spec.rb`
- `spec/models/organization_ai_credit_purchase_charge_spec.rb`

Verification last run: 65 AI-credit specs, 0 failures (before the stash round-trip; re-run after resolving anything new).

---

## 3. Committed this session (by you, during the UI pause)

- `stripe_cancel_at_period_end` column on `organization_ai_credit_purchases`, added by **editing the create migration in place** (`db/migrate/20260408040501_create_organization_ai_credit_purchases.rb`, `t.boolean ... null: false, default: false`) — NOT a new migration. Committed in `fc6f70b9b` / `266886da9`; `schema.rb` cleaned to the proper version.
- `customer.subscription.updated` main-plan branch also sets `stripe_cancel_at_period_end: object.cancel_at_period_end` (your addition, merged with our credit-pack branch in the conflict resolution).

### DB operations performed (dev DB, all via allowed commands)
1. Dumped 4 tables (`organization_ai_credit_purchases` 3, `ai_job_criteria` 3, `ai_job_application_summary_statuses` 45, `bulk_ai_summary_job_applications` 0) + `ai_credit_balance_transactions` (167) to `~/claude-hub/inflow-ats/_in-progress/ai_credit_rollback_dump/` via `rails runner`.
2. NULLed the 2 ledger rows' `organization_ai_credit_purchase_id` (so the FK re-add would validate).
3. `db:rollback STEP=5` (reverted the 4 migrations after the create + the create itself).
4. Edited the create migration to add the column.
5. `db:migrate` (re-applied all 5; column present).
6. Reseeded the 4 tables with original ids (insert_all, reset sequences).
7. Restored the 2 ledger FKs.
All ids preserved; balances intact (counter_culture tracks `amount`, not the FK).

---

## 4. Open questions / not-yet-built

1. **Cancel-at-period-end BEHAVIOR (the reason for the column) — NOT built.** Plan in `ai-credit-cancel-at-period-end-migration-plan.md`. Remaining work:
   - credit-pack `customer.subscription.updated` branch should also set `purchase.stripe_cancel_at_period_end = object.cancel_at_period_end` (currently sets lookup_key/credits/status/period_end only).
   - `CancelAiCreditSubscription` should STOP eager-flipping to `:canceled` + `subscription_canceled_at`; let the webhook drive it.
   - NEW `customer.subscription.deleted` credit-pack branch: finalize to `:canceled` + set `subscription_canceled_at = ended_at` (the real cancellation moment). Today that handler only touches the org.
   - serializer exposes `stripeCancelAtPeriodEnd`; UI shows "cancels on `subscriptionCurrentPeriodEnd`" and keeps the card visible (`#show` already returns `[:active, :past_due]`, so a cancel-pending row still shows).
   - DATA: the sub you cancelled is currently locally `:canceled` though live until period end — needs flipping back to active + flag true via console, or reset as test data.
2. **`charged` response field unread** (`AiCreditSubscription.tsx`) — branch keys off `redirectUrl` presence; `charged` is declared but unread. Cosmetic.
3. **Unreachable fallback lookups** in `apply_one_off` (`stripe_checkout_session_id` / `stripe_invoice_id`) — `purchase_id` is always stamped before pay, so they're dead on the happy path. Harmless defensive code.
4. **Double-charge guard for top-ups** — now mostly moot (record pre-created + `stripe_invoice_id.present?` guard in `charge_default_payment_method`); a rapid double-submit is also blunted by the card-level loading state. Not separately hardened.

---

## 5. Decisions & investigative conclusions reached

- **The analog for subscription change is the Stripe Billing Portal redirect**, NOT an in-app `Stripe::Subscription.update` item swap. The 3 prior failed attempts all diverged by building the item-swap interactor+service. That was the weeks-long miss.
- **The analog for one-off top-up is WWR's create-record-then-charge-via-model-method**, with the webhook finalizing the existing record found by a metadata id (`board_wwr_listing_id` → `organization_ai_credit_purchase_id`). The first attempt's service + create-in-webhook was a structural deviation that spawned the idempotency hole.
- **No migration was needed for idempotency** — the existing `stripe_invoice_id` column + the model's own "require one ref if the other blank" idiom covered it.
- **`invoice.paid`'s re-raise/Sidekiq-retry was a model's deviation** (commit `6d060e38b`, "Batches 3+4+5+6", committed under your name but authored by a model), not your convention. Your Stripe-webhook convention is swallow-and-log, no retries — confirmed across `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`. Reverted to match.
- **`subscription_status` enum crash** — assigning raw Stripe `object.status` (e.g. `trialing`/`unpaid`) into the 4-value enum raised `ArgumentError`, swallowed by the rescue, silently dropping the credit-pack row update. Fixed by adding the statuses. `[:active, :past_due]` surface-as-active is your deliberate call; the new statuses store but don't surface.
- **Cancel-at-period-end disappears** because `CancelAiCreditSubscription` eagerly sets `:canceled`, so `#show`'s `[:active, :past_due]` filter drops it immediately though Stripe keeps it live till period end. Fix = webhook-driven (see Open #1). `subscription_canceled_at` must be set only at the REAL cancellation (period end), not at cancel-click — distinct from the cancel-pending flag.
- **Tier-stripping is prompt-level, not code.** Lives in `app/services/ai_job_application_action/scoring/prompts/integrated_analysis.rb:34-35` ("Do NOT reference requirement tiers… `Tier 1`, `Tier 2`…") and `job_description_criteria_extraction.rb:108` (never write tier label into `text`/`source_text`). No deterministic `gsub`. No equivalent guard on the per-criterion `reasoning` field in `job_application_scoring.rb` — likely the gap if tiers leak into reasoning. NOT touched this session (billing only).
- **"Regenerating status stuck" bug** = the AI summary-status pipeline (`ai_job_application_summary_statuses`), separate from billing. Our work did not touch it and most likely did not fix it.

---

## 6. Hard-won context (don't relearn the hard way)

- **Match the analog's STRUCTURE, not just its PROCESS.** Reproducing the runtime sequence (same end-to-end feel) while reinventing the skeleton (where logic lives, record lifecycle, which columns are read/written, which files exist) is the recurring failure. "Exactly" must be a row-by-row manifest diff, never a vibe. (Now codified in global CLAUDE.md.)
- **Don't reach for a migration by reflex** — find a guard on existing columns first; the analog usually proves it's unnecessary. When genuinely needed, doc every part first, then ask.
- **Audit the WHOLE flow, not the assigned subset.** The cancel bug was missed because the audit scoped to the two assigned features; "it pre-existed this session" is not a valid exclusion.
- **Rolling back to edit a create migration drags in the FK.** `organization_ai_credit_purchases`'s create migration also does `add_foreign_key :ai_credit_balance_transactions, :organization_ai_credit_purchases`. On re-migrate that FK re-validates; ledger rows pointing at the old purchases make it ERROR against the freshly-empty table. The procedure: dump → null the ledger FK → rollback → edit → migrate → reseed (forced ids) → restore the ledger FK. Reseed with ORIGINAL ids so surviving FKs realign.
- **The migration history matters before a rollback.** The create migration `20260408040501` had 4 migrations after it (`auto_generate_ai_summaries`, `bulk_ai_summary_job_applications`, `ai_job_criteria`, `ai_job_application_summary_statuses`) — `STEP=5` reverts all 5; the 3 unrelated AI tables get dropped + recreated too, so they were dumped/reseeded.
- **Reviewers only answer the question you ask.** Pre-blessing your own deviations ("treat the service as approved") produces clean reviews that validate the wrong question. Reviewers must challenge claimed-sanctioned deviations.
- **Ask about every merge/stash conflict** — never auto-resolve. (The one conflict this session, `stripe_webhook_handler_job.rb`, was resolved keeping both sides per your "keep both" call.)
- **DB rules are absolute** — only `db:migrate`/`rollback`/`migrate:status` etc.; never drop/reset/setup/schema:load/test:prepare; all data via `rails runner`/console, never `psql`.
- **`stash@{0}` ("Billing corrections") is still intact** (applied with `apply`, not `pop`) as a backstop for the working-tree billing changes.
