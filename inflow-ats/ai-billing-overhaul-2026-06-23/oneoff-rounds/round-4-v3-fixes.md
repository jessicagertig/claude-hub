# One-Off Purchase — Round 4 Fixes (v3)

All confirmed. Final report.

## Summary

I independently traced the entire AI credit one-off purchase flow end-to-end (frontend → hook → controller → model → webhook → interactor → notification) and diffed it row-by-row against the WWR/WhatJobs analog. The audit's conclusion was correct: **the one-off purchase CODE is already structurally faithful to the analog** — it had been refactored from the trace's stale single-`purchase_top_up`-action skeleton into the analog's two-action shape (`#charge_top_up` + `#create_top_up_checkout_session`), with the webhook passing the resolved `purchase:` object (not the stale `checkout_session_id:`/`invoice_id:` keys), `charge_for_purchase` mirroring `charge_for_listing`, and the produce-result tail mirroring `create_on_wwr`. I found **no unfixed code deviations** in the one-off flow.

I did find and fix one real blocker the audit had merely whitelisted:

### Change made: `db/schema.rb` (was stale; migrations were unapplied)
- The two feature migrations (`20260611120002`, `20260611120003`) were `down` on the dev DB, and `schema.rb` was at version `2026_06_11_120001` still showing `amount_cents_paid` and missing all four feature columns. The model code references `stripe_amount`, `stripe_invoice_paid?`, `stripe_invoice_item_id`, and `last_updated_by_organization_user` — so the flow could not actually run.
- Applied both migrations to the dev DB via targeted `db:migrate:up VERSION=...` (test DB was already migrated).
- Rails' auto-dump pulled in massive unrelated schema state from the shared dev DB (other branches' NO-FILE migrations: `board_crypto_jobs_list_listings`, `vector` extension, `resume_chunk_embeddings`, dropped `connect_*` tables, `subject`/footer columns, etc.). I reverted that and hand-applied **only** the four feature-specific changes plus the version bump to `2026_06_11_120003`:
  - rename `amount_cents_paid` → `stripe_amount`
  - add `stripe_invoice_paid` (boolean, default false)
  - add `stripe_invoice_item_id` (string)
  - add `last_updated_by_organization_user_id` (bigint) + its index `idx_org_ai_purchases_last_updated_by_org_user_id` + FK to `organization_users`

Final schema diff is surgical (only the `organization_ai_credit_purchases` table + version + one FK line).

No backend response keys or frontend code needed changing — the direct-charge path returns the serialized record (frontend inspects nothing, like analog `#create`), and the checkout path returns `{ url, sessionId }` consumed via `window.location.href = data.url` (like analog `#create_checkout_session`).

### Verification
- One-off purchase spec set: **41 examples, 0 failures** (`organization_ai_credit_purchases_purchase_top_up_spec.rb` covering both actions, `organization_ai_credit_purchase_charge_spec.rb`, one-off contexts of `apply_ai_credit_purchase_spec.rb`).
- One-off webhook contexts: **4 examples, 0 failures**.

### WHITELIST (analog patterns that literally cannot exist on our record type — all pre-confirmed by the audit and re-verified by me)
- **Double-charge guard 2nd predicate `stripe_invoice_paid?` vs analog `is_active?`**: `is_active?` checks WWR listing `expires_at`/`approved?`; a credit pack has no expiry concept. `stripe_invoice_paid?` is the equivalent post-payment state. Same lifecycle property (guard fully effective only post-webhook) as the analog.
- **No `after_update` charge callback**: the analog's `handle_after_update` re-charges expired listings on update; one-off packs have no update/renewal path, so there is no update event to hook.
- **`price: price.id` (InvoiceItem/checkout) vs analog inline `amount:`/`price_data.unit_amount`**: OURS' dollar amount lives only in Stripe (resolved by `stripe_price_lookup_key`); the analog hardcodes amounts in the model. The analog's inline-amount pattern cannot exist without a hardcoded local price.
- **No `job_id` in the three checkout metadata blocks**: `job_id` is job-scoped; the one-off purchase is org-scoped with no job. Record-id key + `organization_id` are present, matching the analog minus the job dimension.
- **Direct-charge mutation invalidates `["organizationAiCreditBalance"]` vs analog `["jobs", data.id]`**: the analog refreshes the job (which owns the listing); OURS has no job — the org credit balance is the equivalent affected resource.
- **`broadcast_event` uses GlobalChannel + `action:` key vs analog JobChannel + `event:` key**: no job → no JobChannel; the AI-credit frontend already listens on GlobalChannel (`WebsocketGlobalChannelHandler` switches on `data.action`), so the broadcast is action-keyed there.

### Out of scope (NOT one-off deviations — left untouched)
11 spec failures in the broader file set are all in (a) `organization_ai_credit_purchase_spec.rb` stale assertions that contradict the analog-faithful one-off code (e.g., `:47` "requires stripe_checkout_session_id for one_off" — the analog's direct charge builds the record with no session id; `:140` "contains four packs" — the catalog now has 10 lookup keys; `:25` subscription_status enum now has 8 values) and (b) `stripe_webhook_handler_ai_credits_spec.rb` **subscription-flow** contexts (`Double "line_item" received unexpected message :id` at `handle_subscription_credit_pack_invoice_paid`). None touch the one-off purchase flow; fixing them would be scope creep into the subscription feature / catalog-expansion specs.

Files changed: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/db/schema.rb` (only file modified by me). A backup stash of the prior committed schema.rb remains at `stash@{0}` (label `temp-schema-oneoff`).
