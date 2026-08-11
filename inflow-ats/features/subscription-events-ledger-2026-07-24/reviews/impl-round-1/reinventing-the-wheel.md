# Always-on — Reinventing the wheel — impl round 1

## Findings: 0 BLOCKER / 0 HIGH / 0 MED / 0 LOW

- **PostHog:** reuses the existing `PosthogTrackJob` → `Posthog::Track` path (billing_controller analog shape); no new PostHog client, service, or wrapper.
- **Interactor:** `CreateSubscriptionEvent` extended in place — existing 5-minute dedupe, build/save, `context.fail!` conventions reused; no parallel create path introduced.
- **Fan-out:** implemented as model callback + private helpers per the `Organization#handle_after_commit_on_update` analog — no new service object, no dedicated fan-out job class, no event-bus abstraction (SPEC §2: zero new app files besides the migration — holds).
- **Discord:** existing `Discord::Notify*` job classes reused with existing arities; no new notifier.
- **Uniqueness:** DB partial unique index + check-first guard — no bespoke locking/advisory-lock machinery.
- **`attribution_value`:** genuinely new (repo grep at `a0d59115d`: zero prior definition; no existing owner-first coalescing helper to reuse) — 8 lines, D10-mandated shape, correctly placed as a private model helper rather than a new utility module.
- **Specs:** reuse `create_credit_test_organization` / `create_credit_test_user` helpers and the constructed-double shapes from the `stripe_webhook_handler_ai_credits_spec.rb` analog; the `:test`-adapter around-block copies the house shape. No new factories or helper frameworks.

Nothing duplicated, nothing over-built.
