# VERDICT — subscription-events-ledger impl review, Round 1

## PASS

**Counts: 0 BLOCKER / 0 HIGH / 0 MED / 6 LOW (note-only, two are the same observation shared across angles).** Per the harness profile (zero HIGH+ and no unaddressed MEDs = terminal; a round with only a couple of LOWs may be terminal), this round is CLEAN and terminal.

Reviewed: the COMMITTED diff `a0d59115d..89286fba8` (11 files, +739/−17) on `attribution-work-qa`. Rule 15 satisfied: `git status --porcelain` shows the only working-tree residue is the known unstaged `db/schema.rb` corruption; the committed schema hunks are exactly the two columns + partial unique index + version bump.

## Per-angle counts

| Angle | BLOCKER | HIGH | MED | LOW |
|---|---|---|---|---|
| 1 webhook-delicacy-audit (D11 — run first) | 0 | 0 | 0 | 0 |
| 2 conversion-predicate-correctness | 0 | 0 | 0 | 0 |
| 3 ledger-integrity | 0 | 0 | 0 | 0 |
| 4 fan-out-contract | 0 | 0 | 0 | 1 |
| 5 posthog-payload-integrity | 0 | 0 | 0 | 0 |
| 6 behavior-preservation | 0 | 0 | 0 | 0 |
| 7 test-coverage-and-ghost-tests | 0 | 0 | 0 | 2 |
| spec-compliance | 0 | 0 | 0 | 0 |
| code-quality | 0 | 0 | 0 | 1 |
| reinventing-the-wheel | 0 | 0 | 0 | 0 |
| data-integrity-security | 0 | 0 | 0 | 0 |
| operational-concerns | 0 | 0 | 0 | 2 (one shared with angle 4) |

**Delicacy audit (D11):** `app/jobs/stripe_webhook_handler_job.rb` diff = EXACTLY the two sanctioned additive, rescue-isolated insertion blocks (end of `invoice.paid` else-branch; end of `subscription.deleted` else-branch with the `if organization` guard). Zero removed/modified lines, no reordering, no attribute-access changes. Both insertion sites re-read in the live file with context.

**Ghost tests:** none (BLOCKER class — audited per example; the `have_enqueued_job(...).with { }` block form was empirically proven non-vacuous via a scratchpad probe whose deliberately wrong in-block assertion fails).

## Executed test results (exact counts)

- Four new spec files (`stripe_webhook_handler_subscription_events_spec.rb`, `create_subscription_event_spec.rb`, `subscription_event_fanout_spec.rb`, `organization_subscription_events_spec.rb`): **28 examples, 0 failures**.
- `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`: **17 examples, 17 failures** — ALL pre-existing, see Escalation E1.
- `spec/models/organization_ai_credits_lifecycle_spec.rb`: 3 examples, 1 failure at `:33` — the documented known pre-existing failure, failure mode unchanged.

## LOWs (note-only, no fixes requested)

1. (angle 4 / operational) `trial_started` writer call unrescued inside the Organization after_commit — exposure identical to the previous Discord `perform_later` at the same line; risk profile unchanged.
2. (angle 7) Ledger-failure-isolation example cannot falsify the insertion's own rescue (the branch's pre-existing tier-3 `rescue StandardError` also swallows; assertions precede the insertion); a log-message assertion would pin it.
3. (angle 7) Check-first guard examples individually shadowed by the `RecordNotUnique` backstop (defense-in-depth ambiguity); the uniqueness feature as a whole is falsifiable.
4. (code-quality) `create_subscription_event.rb` missing trailing newline at EOF — pre-existing, untouched.
5. (operational) Discord-after-ledger coupling — deliberate pattern property, carried from spec review.

## ESCALATIONS (report, don't fix — Jessica's rulings needed)

**E1 — SPEC §9.5's "must still pass" premise was already false at `a0d59115d` (evidence the spec is wrong, not the implementation).** `stripe_webhook_handler_ai_credits_spec.rb` fails 17/17: every example dies in setup with `ActiveModel::UnknownAttributeError: unknown attribute 'amount_cents_paid' for OrganizationAiCreditPurchase`. Cause: ancestor commit `c2f69130d`'s migration `20260611120002_add_stripe_payment_columns_to_organization_ai_credit_purchases.rb` renamed `amount_cents_paid` → `stripe_amount`; the spec was never updated. The spec file, `OrganizationAiCreditPurchase`, and that migration are byte-identical across the review range, and the failure fires before any feature code executes — NOT attributable to this diff. Updating the stale spec is out of this feature's scope (shared surface; rules 10/23). Note the same stale column name also appears in `spec/models/organization_ai_credit_purchase_spec.rb` and `spec/interactors/cancel_ai_credit_subscription_spec.rb` (not executed this round; likely the same drift). This was NOT in the known-pre-existing-failures list (which had only `organization_ai_credits_lifecycle_spec.rb:33`).

**E2 — Plan Task 9.6's checked "all green" claim is contradicted for the fifth file.** Task 1.2's `RAILS_ENV=test db:migrate` necessarily preceded 9.6 and guarantees the rename was applied, so the ai-credits spec cannot have passed at 9.6 time in any reconstruction. The four NEW files' green claim IS reproducible (28/28). Verification-integrity flag for Jessica; no code change follows from it.

## What NOT to change (for any downstream agent)

- The two webhook insertion blocks' boundaries — nothing else in `stripe_webhook_handler_job.rb`, ever (D11).
- D1–D12 + RESOLVED-at-go rulings — immutable.
- The unstaged `db/schema.rb` corruption — stays unstaged, never committed.
- All Slack `Notification::*` job files and enqueue sites.
- `ended_at` param and `@ended_at` assignment in `Notification::PaidSubscriptionDeletedJob` (the Slack `blocks` timestamp reads `@ended_at`).
- `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` — E1's fix is Jessica's call, not a feature fix agent's.
