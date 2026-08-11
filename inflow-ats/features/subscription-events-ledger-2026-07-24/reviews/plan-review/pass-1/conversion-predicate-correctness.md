# Plan review pass 1 — Angle 2: Conversion-predicate correctness (§4)

## §4 predicate encoding in planned insertion 1 (Task 7.1) — verified line by line

- `if object.amount_paid.to_i > 0` — SPEC §4 verbatim (the one sanctioned `.to_i`, per the plan's style rulings section). CORRECT.
- `stripe_subscription.trial_end.present?` → `'trial_converted_to_paid'`; absent → `'converted_to_paid'` — full if/else value-selection expression assigned to `subscription_event_type` (D10 shape). Uses the `stripe_subscription` local the branch ALREADY retrieves at stripe_webhook_handler_job.rb:283 — no second `Stripe::Subscription.retrieve`, no event-payload snapshot, no `status` field, no `billing_reason`. CORRECT per D5.
- Call args: `organization:`, `event_type: <per §4>`, `to_plan: organization.plan`, `stripe_subscription_id: object.subscription`, `amount: object.amount_paid` (cents, raw — no fabricated fallback). `from_plan` deliberately absent (SPEC-PROPOSED, rule 10). CORRECT per SPEC §5.2.
- Position: after the `raise CustomStripeSubscriptionMissingError` guard (289) — nil `organization.stripe_subscription_id` never reaches the predicate; after all existing branch behavior (org update 291, payment method 296, `reset_ai_credits` 297). CORRECT.
- Duplicate delivery → graceful interactor no-op: check-first guard (Task 3.3) + `RecordNotUnique` backstop (Task 3.4) + partial unique index (Task 1.1). First-cash semantics ride the uniqueness invariant with no extra logic — no cutoff/backfill logic added (§11.6 planned AS WRITTEN, plan Risk 1). CORRECT.
- $0 invoices record nothing (trial-creation invoice, 100%-off cycles) — accepted per D5; the matrix spec (9.1) covers both $0 cells.

Cross-checked against the reference map (`stripe-webhook-handler.md` — trial-conversion signal: first `invoice.paid` with `amount_paid > 0` where `trial_end` present): consistent.

## Findings

None.
