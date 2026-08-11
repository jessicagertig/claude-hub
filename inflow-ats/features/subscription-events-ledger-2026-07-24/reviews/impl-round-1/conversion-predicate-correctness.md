# Angle 2 — Conversion-predicate correctness (§4/D5) — impl round 1

**Reviewed:** insertion 1 in `app/jobs/stripe_webhook_handler_job.rb` (live lines 313–331); `app/interactors/create_subscription_event.rb` (uniqueness guard + backstop); executed the predicate-matrix spec.

## Findings: NONE (0 BLOCKER / 0 HIGH / 0 MED / 0 LOW)

## Verification detail

- **Matrix per §4:** `object.amount_paid.to_i > 0` gate (spec-verbatim; the one sanctioned `.to_i`); `stripe_subscription.trial_end.present?` → `trial_converted_to_paid`, absent → `converted_to_paid`. $0 invoices record nothing (D5 accepted).
- **`trial_end` source:** the `stripe_subscription` local retrieved at line 297 by the pre-existing branch code — live at processing time. NOT the event payload snapshot; NO `status` field; NO second `Stripe::Subscription.retrieve`; NO `billing_reason` (D5 deliberately unused — confirmed absent from the diff).
- **Placement:** inside the main-plan else-branch only, after `raise CustomStripeSubscriptionMissingError if organization.stripe_subscription_id.nil?` (line 303) — nil main-plan subscription ids never reach the predicate; credit-pack invoices took `handle_subscription_credit_pack_invoice_paid` at the branch point above; the three metadata one-off branches `return` before the retrieve.
- **First-cash semantics via the invariant, no extra logic:** duplicate delivery / renewals / past_due recoveries on an already-converted subscription hit the interactor's check-first guard (`conversion_duplicate_exists?` — any `CONVERSION_EVENT_TYPES` row for the `stripe_subscription_id`) → graceful `context.fail!`; raced deliveries hit the partial unique index → `rescue ActiveRecord::RecordNotUnique` → same graceful failure. No fabricated fallbacks anywhere (`|| 0` absent; amount passed raw).
- **Args:** `amount: object.amount_paid` (cents, raw), `stripe_subscription_id: object.subscription`, `to_plan: organization.plan`, `from_plan` nil (SPEC-PROPOSED, rule 10 — implemented as specced).
- **§11.6 rollout misclassification** (pre-existing already-converted subscriptions record a false conversion on first post-deploy paid invoice): implemented AS SPECCED — this is the disclosed open question for Jessica, NOT flagged as a defect per the review mandate.
- **Executed evidence:** `stripe_webhook_handler_subscription_events_spec.rb` — all four matrix cells pass (0/present → no row; 0/absent → no row; positive/present → one `trial_converted_to_paid` row with amount/sub-id/to_plan/from_plan-nil asserted; positive/absent → one `converted_to_paid` row), duplicate delivery → exactly one row, no raise. 28/28 green across the four new files.
