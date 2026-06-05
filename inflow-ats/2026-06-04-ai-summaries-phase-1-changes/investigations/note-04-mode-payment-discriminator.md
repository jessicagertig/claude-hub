# Investigation — Note #4: brittle mode:payment discriminator

## File chain
`ai_credits_controller.rb:29-40` / `board_wwr_listings_controller.rb:80-112` / `board_what_jobs_listings_controller.rb:~220`
→ `stripe_webhook_handler_job.rb:53` (checkout.session.completed) → `:58` (`object.mode == 'payment'` → `apply_top_up_checkout` → early `return`)
→ `organization_ai_credit_balance.rb:35` (`apply_top_up_checkout` → `ApplyAiCreditPurchase(session:, kind: :one_off)`)
→ `stripe_webhook_handler_job.rb:190` (invoice.paid) → `:206/:218` (board_wwr_listing_id / board_what_jobs_listing_id branches), `:237` else → subscription path

## Audit: three mode:'payment' checkout flows
1. AI top-up — `ai_credits_controller.rb:31`. Session metadata `{ organization_id, ai_credit_pack_top_up: 'true' }`. NO invoice_creation.
2. WWR listing — `board_wwr_listings_controller.rb:82`. Sets payment_intent_data.metadata, `invoice_creation: { enabled: true, invoice_data: { metadata: { board_wwr_listing_id } } }` (:101-106), and session metadata.
3. WhatJobs listing — `board_what_jobs_listings_controller.rb:~220`. Same shape (payment_intent_data.metadata).

## Key findings
- Board listings deliberately enable `invoice_creation` → Stripe makes an invoice carrying `board_*_listing_id` in invoice metadata → fulfilled on `invoice.paid` (a true paid signal).
- AI top-up enables NO invoice_creation → no invoice → handled on `checkout.session.completed`.
- `apply_top_up_checkout` / `ApplyAiCreditPurchase` never check `session.payment_status` (grep: no `payment_status` in handler). `checkout.session.completed` can fire unpaid for async methods → credits could be granted before payment confirmed.
- The line-58 branch routes ALL payment-mode sessions to apply_top_up_checkout + early return. Board listing payment sessions only fail to mis-grant because their price lookup key isn't in `AiCreditPacks.registered_keys` (accidental backstop). Board fulfillment is unaffected (separate invoice.paid event).
- The invoice.paid `else` branch (:237) assumes `object.subscription` exists (retrieves Stripe::Subscription) — a one-off top-up invoice has no subscription, so it MUST be caught by an explicit metadata branch before the else (like the board branches).

## Decision (see approved-decisions.md Note #4): option (c) — mirror board pattern, move to invoice.paid, metadata-keyed.
