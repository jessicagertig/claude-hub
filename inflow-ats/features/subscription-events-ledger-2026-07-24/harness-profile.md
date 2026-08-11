# Harness profile — subscription-events-ledger (Fable-trimmed, no human gate)

Same trimmed lifecycle Jessica approved for the attribution-identifiers round (`~/claude-hub/inflow-ats/features/attribution-identifiers-2026-07-24/harness-profile.md`), with this feature's adjustments. Jessica's go (2026-07-24): "write the spec. Run the harness... I can review it later... close to workable." NO human gate anywhere; escalations still stop the run.

## THE DELICACY DIRECTIVE (D11 — put this in EVERY agent prompt, every phase)

`app/jobs/stripe_webhook_handler_job.rb` is PARTICULARLY DELICATE, load-bearing billing logic. Minimum changes only. Additions, changes, and even removals that touch if/else statements must each be individually justified against SPEC.md. No reordering of branches, no changes to how Stripe object attributes are accessed (house-safe forms: `object.metadata&.[]('key')`, `&.data&.first&.price`, `respond_to?` structure checks), no "cleanup." The two sanctioned insertion points are defined in SPEC.md §5; anything beyond them in this file is a BLOCKER finding. Reference map: `~/claude-hub/inflow-ats/documentation/stripe-subscription-lifecycle-2026-07-24/`.

## Round-count trims (identical to attribution round)

| Phase | This run |
|---|---|
| 2 — Spec review | One round; a second only if round 1 produces HIGH+ |
| 3/4 — Plan + review | One plan pass (must include the structural manifest vs the analogs in SPEC §8), one review pass |
| 6 — Impl review | Exit on FIRST clean round; loop on HIGH+; cap unchanged |
| 7 — Hardening | Stock |

**Convergence rule (all loops incl. Phase 8 layers):** two clean passes never required. Zero HIGH+ and no unaddressed MEDs = terminal. A round with only a couple of LOWs may be terminal at orchestrator judgment.

**MED rule:** MED means "should be fixed"; note-only observations are LOW, never MED. Orchestrator fixes MEDs with judgment; deliberately-left MEDs listed with reasoning.

**Test priorities:** Cypress top (read-only, must pass — pre-commit runs full suite), customer/public API specs important (untouched here), other RSpec strongly deprioritized — missing coverage never HIGH/MED on its own; wrong/broken/ghost tests remain real findings (ghost = BLOCKER). Exception this round: the conversion predicate (SPEC §4) is new business logic in the delicate file — its behavioral spec coverage is REQUIRED, not optional.

## Phase 8 layers (backend-only feature — no UI surface)

- **Layer 1 (diff-to-spec):** ~10 agents, slices by spec structure: one per writer site (3), one for the migration+enum+uniqueness, one for the interactor changes, one for the fan-out + PostHog payload, one for the Discord moves (three enqueue-site changes) + Slack-untouched verification, one for webhook-delicacy audit (the diff inside stripe_webhook_handler_job.rb line-by-line against the two sanctioned insertion points), one for tests-vs-spec, one REVERSE direction (everything in the diff the spec never asked for — first-class). Every finding HIGH.
- **Layer 3 (script runner):** the runtime layer that matters here. Agents use `test_frr` scripts (in /tmp) + the qa-harness test server to: construct real-shape Stripe event objects and drive `StripeWebhookHandlerJob#handle_stripe_event` directly (stubbing `Stripe::Subscription.retrieve` where needed); verify the D5 predicate matrix (amount 0/positive × trial_end present/absent × duplicate delivery), row creation, uniqueness under redelivery, fan-out job enqueues, PostHog payload shape (attribution owner-first fallback + compact), trial_started via the org callback path, canceled via deleted-event path, and that assigned_free_plan behavior is byte-identical.
- **Layer 4 (regression):** full — relevant RSpec suites (including `stripe_webhook_handler_ai_credits_spec.rb`, the organization AI-credits lifecycle suite) + Cypress via the standard mechanism. Known pre-existing failure: `organization_ai_credits_lifecycle_spec.rb:33` (documented in the attribution round's QA-MED-FINDINGS) — not attributable to this feature unless the failure mode changes.
- **Layers 2 and 5: SKIPPED** — Layer 2 per the standing trim; Layer 5 because the feature has zero browser-reachable surface (webhook + callback + jobs only). Record both skips in QA-COMPLETE.md.

## Repo rules for every implementing/committing agent

- Branch `attribution-work-qa`; commits LOCAL ONLY — never push (PR #3075 open; push is Jessica's).
- Schema commit hard rule: never stage `db/schema.rb` wholesale; hunk-level staging of exactly this migration's columns/index + version bump; the dev schema still carries unstaged corruption — leave it unstaged.
- Detached commit procedure: pre-commit runs full Cypress (~10–20 min); nohup-detached commit, never under a killable timeout, immediate retry on kill, wait only if another tree's commit is live.
- DB safety absolutes per pipeline CLAUDE.md (no drop/reset/schema:load/test:prepare; RAILS_ENV only; both dev and test DBs migrated via `db:migrate`).
