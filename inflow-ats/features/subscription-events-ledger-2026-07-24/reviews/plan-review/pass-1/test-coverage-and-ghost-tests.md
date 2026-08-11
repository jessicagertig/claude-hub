# Plan review pass 1 — Angle 7: Test coverage and ghost tests

## Infrastructure claims — all verified live

- `config/environments/test.rb:64` sets `config.active_job.queue_adapter = :inline` — CORRECT.
- House around-block copied from `spec/models/job_criteria_lifecycle_spec.rb:8–13` — verbatim match confirmed.
- `spec/rails_helper.rb:15` `config.use_transactional_fixtures = true` — CORRECT; after_commit fires in transactional tests on Rails ≥5 (plan Risk 6 discloses the dependency).
- `create_credit_test_organization` at `spec/support/ai_credits_test_helpers.rb:21` — CORRECT; `stripe_active: true` sets stripe_customer_id/stripe_subscription_id/status 'active'; `with_balance: true` creates `OrganizationAiCreditBalance` (reset_ai_credits assertion feasible); `complete_setup_workers` stubbed per-instance.
- Analog `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`: `double('metadata', :[] => nil)`, `Stripe::Event.retrieve` stub, `described_class.perform_now('evt_…')` — all confirmed; `spec/interactors/` directory exists.
- `log_stripe_changes` guard `return unless event.data.respond_to?(:previous_attributes)` at stripe_webhook_handler_job.rb:420 — CORRECT; RSpec doubles answer `respond_to?` false for unstubbed messages, so the analog double shape passes through safely.
- `OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?` is a hash lookup on `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` — `'plan_ats_tier_starter_v2_monthly'` misses → routes to the main-plan else branch as intended.
- Grep confirms NO existing spec references `SubscriptionEvent`/`CreateSubscriptionEvent` (plan 9.5 claim) — no rename ripple.

## Coverage vs SPEC §9

- §9.1 predicate matrix (REQUIRED): all four cells + duplicate delivery + ledger-failure isolation + existing-behavior-intact + subscription.deleted row + no-org miss — planned in 9.1. PRESENT and REQUIRED.
- §9.2 interactor: uniqueness guard both directions (cross-type — deliberately dedupe-immune, so falsifiable against the guard specifically), `RecordNotUnique` backstop (explicitly falsifiable — stubs the check-first so save hits the index), params persisted/omitted, free-plan dedupe untouched, guard-order fix (falsifiable: currently raises NoMethodError). PRESENT.
- §9.3 fan-out: per-type enqueues, `assigned_free_plan*` → nothing, no owner → no PostHog (Discord still fires), nil `subscription_canceled_at` → no Discord (PostHog still), properties hash owner-first/`.compact`/amount-only-on-conversion/defaults-not-duplicated. PRESENT.
- §9.4 organization callback: nil→'trialing' row + Slack + Discord-exactly-once (twice = removal missed — good falsifiability), trialing→active → no row, no Discord, Slack still. PRESENT.
- Cypress untouched; pre-commit full suite in Task 11.3. PRESENT.

## Ghost-test audit (rule 26)

Every planned assertion fails if the feature is deleted: row-existence assertions (9.1), failure-mode assertions designed to raise without the fix (9.2 backstop, 9.2 guard-order), enqueue assertions keyed on the new callback (9.3), exactly-once assertions that catch the un-removed Discord line (9.4). No enum-reflection tautologies, no assigned-but-unasserted variables planned. No ghost tests.

## Findings

- **MED-1 (rule 31): Tasks 9.1 and 9.2 omitted the `:test` adapter around-block from their per-task setup** (9.3/9.4 named it). Both traverse job-enqueuing paths: after Task 4, EVERY `SubscriptionEvent` creation fires the fan-out, and 9.1 additionally asserts `Notification::PaidSubscriptionDeletedJob`/`EngagementReport::GeneratorJob` are enqueued — impossible under `:inline`, and under `:inline` the fan-out would execute real Discord sends and `Notification::PaidSubscriptionDeletedJob`'s real Slack webhook (`Variables::SLACK_SUBSCRIPTIONS_WEBHOOK`) inside examples — the exact rule-31 incident class. The Task 9 preamble's blanket sentence covered it in principle; the per-task setup lists are what implementers follow. AMENDED: explicit around-block requirement added to 9.1 (first setup bullet) and 9.2 (task header).
- LOW (note-only): 9.1's duplicate-delivery example ("perform_now TWICE → exactly one row") would pass via the 5-minute dedupe even if the conversion-uniqueness guard were deleted (identical event_params within 5 minutes). Guard-specific falsifiability is carried by 9.2's cross-type examples, so coverage is adequate; the 9.1 example remains spec-mandated (§9.1) and falsifiable against whole-feature deletion. Deliberately left.
