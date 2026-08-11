# Angle 7 — Test coverage and ghost tests (+ always-on test-coverage) — impl round 1

**Reviewed:** all four new spec files read in full; falsifiability analyzed per example (mentally deleting the feature per angle instructions); stubs checked against production types; EXECUTED all mandated runs.

## Executed results (exact counts)

| Run | Result |
|---|---|
| `spec/jobs/stripe_webhook_handler_subscription_events_spec.rb` + `spec/interactors/create_subscription_event_spec.rb` + `spec/models/subscription_event_fanout_spec.rb` + `spec/models/organization_subscription_events_spec.rb` | **28 examples, 0 failures** |
| `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` | **17 examples, 17 failures** — every example fails in setup: `ActiveModel::UnknownAttributeError: unknown attribute 'amount_cents_paid' for OrganizationAiCreditPurchase`. PRE-EXISTING (see verdict escalation E1): ancestor commit `c2f69130d`'s migration `20260611120002` renamed `amount_cents_paid` → `stripe_amount`; the spec was never updated. Spec file, model, and migration are byte-identical across `a0d59115d..89286fba8`; failure fires before any feature code executes. NOT diff-attributable. |
| `spec/models/organization_ai_credits_lifecycle_spec.rb` | 3 examples, 1 failure at `:33` — the documented known pre-existing failure; failure mode unchanged (value comparison at line 37). |
| Scratchpad falsifiability probe (with-block) | deliberately-wrong in-block assertion FAILS → `have_enqueued_job(...).with { }` block is invoked; property assertions non-vacuous. |

## Findings: 0 BLOCKER / 0 HIGH / 0 MED / 2 LOW

### LOW-1 (note-only): ledger-failure-isolation example cannot falsify the insertion's own rescue
`'does not break the existing branch behavior when the ledger write raises'` stubs `CreateSubscriptionEvent.call` to raise and asserts no raise + prior behavior intact. Mentally deleting the insertion's inner `begin/rescue`: the branch's PRE-EXISTING tier-3 `rescue StandardError` (stripe_webhook_handler_job.rb:342–346) also swallows the raise, and both behavioral assertions precede the insertion — the example also passes with the whole insertion deleted (the stub is simply never invoked). It DOES exercise the inner rescue path when present, and it is exactly the test SPEC §9.1 ordered; positive-row examples in the same file carry the insertion's falsifiability. A `Rails.logger.error` assertion on the `'SubscriptionEvent ledger error'` message would pin the inner rescue specifically. Note-only.

### LOW-2 (note-only): uniqueness-guard examples individually shadowed by the backstop (defense-in-depth ambiguity)
If ONLY the check-first guard were deleted, the two cross-type guard examples would still pass via the `RecordNotUnique` backstop (identical failure message by design); if ONLY the backstop were deleted, the backstop example fails (it stubs `conversion_duplicate_exists?` false — proven falsifiable). The uniqueness FEATURE as a whole is falsifiable (delete guard + backstop → raised `ActiveRecord::RecordNotUnique` fails both). Same class as the plan-review's deliberately-left LOW on duplicate-delivery ambiguity. Note-only.

## Ghost-test audit (rule 26) — CLEAR

- No enum-reflection tautologies, no assigned-but-unasserted variables, no always-true type checks anywhere in the four files.
- Positive examples assert row creation with field values, specific job enqueues with args, and property-hash contents — each fails if its feature slice is deleted (predicate matrix ↔ insertion 1; canceled row ↔ insertion 2; `exactly(:once)` Discord ↔ the organization.rb line removal; Discord-absent + Slack-present ↔ the converted-branch removal; nil-organization no-raise ↔ the guard-order fix, which previously raised NoMethodError).
- Negative examples ($0 → no row, no-org → no row, `assigned_free_plan*` → nothing, nil `subscription_canceled_at` → no Discord) are inherently non-falsifiable by deletion alone but are each paired with a positive counterpart in the same file.
- Property-hash assertions proven non-vacuous by the executed probe (block form invoked).

## Requirement coverage (§9, harness-calibrated)

1. §4 predicate matrix (REQUIRED): all four cells + duplicate delivery + canceled row + around-insertion preservation + failure isolation — present and green. Stub types match production (rule 7): `Stripe::Subscription.retrieve` stubbed with the invoice's `object.subscription` value; invoice/metadata/subscription doubles follow the `stripe_webhook_handler_ai_credits_spec.rb` analog shapes (`double('metadata', :[] => nil)` + stubbed `keys`, `Stripe::Event.retrieve` stub, `perform_now`); `log_stripe_changes`' `respond_to?(:previous_attributes)` guard is double-safe.
2. Interactor: uniqueness guard both directions, backstop, new params persisted, nil-column + dedupe-unchanged, free-plan dedupe message, nil-organization guard order — all present and green.
3. Fan-out: per-type enqueues, `assigned_free_plan*` → nothing, no owner → no PostHog (Discord still fires), nil `subscription_canceled_at` → Discord skipped/PostHog fires, properties owner-first/fallback/compact/amount-presence/default-key-absence — all present and green.
4. Organization callback: `nil → 'trialing'` row + Slack + Discord exactly-once; `'trialing' → 'active'` Slack-only, no row, no Discord — present and green.
5. Rule 31: all four files carry the `:test` queue-adapter around-block (house shape). `include ActiveJob::TestHelper` where enqueued-jobs introspection is used. Bang methods and `reload`/`update_columns` confined to spec files (sanctioned).
6. Cypress: untouched (zero cypress hunks); commit `89286fba8` exists on the branch (pre-commit hook ran at commit time).
