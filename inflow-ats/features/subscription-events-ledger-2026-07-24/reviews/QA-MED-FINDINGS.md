# QA MED findings — subscription-events-ledger

Consolidated across all five QA runs and all executed layers. Deduplicated aggressively: same area + same concern = one entry regardless of how differently agents worded it. **Nothing here was fixed.** Each entry is either report-only by the severity rules or a decision that is yours to make.

Diff under QA: `a0d59115d..33dffbe3e` on `attribution-work-qa` (app commit `89286fba8` + four spec-only fix commits). App code unchanged since `89286fba8`.

---

## M1 — `utm_data` with an ActiveJob reserved key breaks the fan-out (DECISION NEEDED)

**Where:** `app/models/subscription_event.rb:71` (`utm_data: attribution_value(owner.utm_data, organization.utm_data)`) → `:59` `PosthogTrackJob.perform_later`
**Found:** QA run 5, Layer 3, agent 7 (filed HIGH); confirmed independently by agents 8 and 9. Adjudicated MED.

A `utm_data` jsonb value containing any of the five ActiveJob reserved keys (`_aj_globalid`, `_aj_serialized`, `_aj_symbol_keys`, `_aj_ruby2_keywords`, `_aj_hash_with_indifferent_access`) — on **either** the owner User or the Organization — makes `PosthogTrackJob.perform_later` raise `ActiveJob::SerializationError` inside `SubscriptionEvent#handle_after_commit_on_create`.

**Consequences, all observed live:**

| Writer | What happens |
|---|---|
| `trial_started` (organization.rb:1131) | Not rescue-wrapped. The raise escapes `Organization#update!` to its caller. Ledger row persists; `Discord::NotifyFreeTrialStartedJob` lost; PostHog event lost; **`organization_ai_credit_balance&.reset_ai_credits` skipped** |
| `invoice.paid` conversion | The insertion's own rescue swallows it. Ledger row persists; PostHog conversion event and `Discord::NotifyTrialConvertedToPaidJob` silently lost. Nothing escapes `handle_stripe_event` |
| `subscription.deleted` | Same as above; the two pre-existing branch jobs still enqueue |

The skipped `reset_ai_credits` was found separately (agent 9) and is the reason this entry exists in this shape: the consequence list was incomplete without it. The writer call took the exact line the removed `Discord::NotifyFreeTrialStartedJob.perform_later(id)` occupied, which sits ahead of `reset_ai_credits`. Control/poison pair on org 37146: `last_reset_at` moved 2026-05-27 → 2026-07-27 clean, stayed at 2026-05-27 poisoned.

**Why MED and not HIGH — reachability, not fix cost.** The app's own frontend cannot produce the trigger: `app/javascript/shared/lib/utils.js:192-208` filters `utm_data` keys to the `utm_` prefix, and all five reserved keys begin with `_aj_`. It takes a hand-crafted POST to the public signup endpoint — `Api::V1::RegistrationsController#sign_up_params` (registrations_controller.rb:328) permits `utm_data: {}` with no key restriction, and `Api::V1::OrganizationsController#create:34` copies it onto the Organization. That is adversarial input, not the "reasonable workflow" the HIGH bar describes. The code is also exactly what D9 and SPEC §7 specify, so this is a defect in the approved design rather than a deviation from it.

**Two things that argue it still matters:**
- **Feature-introduced.** `subscription_event.rb:59` is the only site in the codebase that passes user-controlled data to `perform_later`. All 11 other `PosthogTrackJob` callers pass hand-built scalar hashes (`{ method: 'magic_link' }`, `{ price_id:, plan: }`). This is not an existing pattern the feature merely joined.
- **The blast radius reaches checkout.** The `nil -> 'trialing'` flip happens inside `Organization#sync_with_stripe`, called from `stripe_webhook_handler_job.rb:161,205,237` and `billing_controller.rb:171,211,260,624`. An unrescued raise on a controller path could 500 a user's checkout-return request.

**Options, none taken:**
1. A rescue around `enqueue_posthog_track` in `subscription_event.rb` — feature-local, no spec deviation, cheap; cost is that PostHog enqueue failures become silent.
2. Drop `utm_data` from the payload — contradicts D9's explicit 13-field list.
3. JSON-stringify `utm_data` — changes the wire shape D9 approved.
4. Restrict the `utm_data: {}` permit at `registrations_controller.rb:328` — a pre-existing permissiveness, and that file is on SPEC §2's explicitly-untouched list.
5. Accept it as adversarial-input-only.

No fix agent was dispatched because choosing among these is a design decision, and a unilateral pick is the failure pattern pipeline rules 10, 20 and 23 exist to prevent.

---

## M2 — SPEC §11.6 rollout misclassification (DISCLOSED OPEN QUESTION, carried forward)

Not a QA finding — the spec discloses it and it is awaiting your ruling. Recorded here so it is not lost.

First-cash semantics hold only for subscriptions whose ledger history starts before their first cash. Every subscription that converted before this ships has no conversion row (no backfill), so its first post-deploy paid invoice records a false conversion: one ledger row and one PostHog conversion event per existing paying subscription over its next billing cycle, plus a false `Discord::NotifyTrialConvertedToPaidJob` ping for every subscription with `trial_end` present. Mitigations (seed conversion rows for currently-subscribed orgs, a subscription-created cutoff, or accept-and-filter by date in PostHog) are design decisions. As specified, the false positives ship.

---

## M3 — §5.2/§5.3 "appended at the END" placement has no runtime test pin

**Found:** QA run 5, Layer 1, agent 9 (filed HIGH); adjudicated MED by the previous orchestrator. That adjudication stands.

Placement is a structural property, verified line-by-line by the D11 delicacy audit every Layer 1 round (run 5 agent 8: byte-compare of base vs head outside the insertions, both blocks at exact branch end, blob-hash identical across all four fix commits). A runtime pin would need raise-an-earlier-line contortions duplicating the audit.

**Disclosed consequence:** after QA, an in-file move of either insertion would not fail RSpec. A correction was also recorded — the run-4 consolidation had claimed the ledger-failure example covered placement; it does not (with the own-rescue intact, moving the block still passes).

---

## M4 — Pre-existing RSpec failures: 148 across 22 files, no usable green baseline

**Found:** QA run 5, Layer 4. All 148 proven pre-existing and unrelated to this feature. Zero feature-caused failures.

The known list carried into this run understated the blast radius:

- **90 of 148** share one signature: `ActiveModel::UnknownAttributeError: unknown attribute 'amount_cents_paid' for OrganizationAiCreditPurchase`, firing in spec setup. Root cause confirmed at schema level — the column is `stripe_amount`; commit `c2f69130d` renamed it and is an ancestor of base `a0d59115d`. **It affects 7 spec files, not the 3 previously documented.** The four additional: `apply_ai_credit_subscription_spec.rb` (18), `apply_ai_credit_upgrade_spec.rb` (13), `apply_ai_credit_refund_spec.rb` (5), `organization_ai_credit_purchases_subscription_change_spec.rb` (20).
- `organization_ai_credits_lifecycle_spec.rb:33` — mode unchanged, exactly as documented.
- **New, not previously on the list:** `plan_feature_gate_ai_credits_spec.rb`, 4 failures. `plan_rules` hardcodes `monthly_ai_credit_allocation: 0` for `plan_no_plan`/`plan_simple_ats_free`; 0 is truthy in Ruby so the `|| MINIMUM_AI_CREDIT_ALLOCATION` fallback at `plan_feature_gate.rb:134` never fires. Plus `SCALE_AI_CREDIT_ALLOCATION` resolving to 150 against an expected 250. Non-causation is airtight: the spec's `gate_for` helper builds an `OpenStruct`, so no ActiveRecord callback can run. Same root cause as the lifecycle:33 failure.
- 17 route-drift failures (`No route matches charge_top_up`), 11 constant/stub/readonly drift, 25 assorted across AI-summary/mailer/textract/bulk suites.

Also carried from the implementation review: six migrations are "up" in the shared test database with no migration files on this branch (sibling-worktree drift). Not touched — fixing it needs prohibited schema operations.

---

## M5 — `POSTHOG_CLIENT` is live in the test environment

**Found:** QA run 5, Layer 3, agent 7. Operational note for future QA work, not a feature defect.

`POSTHOG_CLIENT` is not nil under `RAILS_ENV=test` — it is a real `PostHog::Client` with the API key present. Any unstubbed `Posthog::Track#track` in a runner script or an `:inline`-adapter spec would send to PostHog for real. Every agent in this round held the queue adapter at `:test` and stubbed captures with an assertion the stub took effect.

---

## LOW notes (recorded, no action)

- `PosthogTrackJob#perform`'s pre-existing `deep_symbolize_keys` also symbolizes nested `utm_data` keys. Wire bytes verified identical via `JSON.generate`.
- `subscription_events.amount` is a 4-byte integer; an `amount_paid` above 2147483647 would lose the conversion row inside the ledger block's own rescue. Needs a single invoice above $21.4M.
- The partial unique index does not constrain NULL `stripe_subscription_id`. Proven unreachable from both insertions: `Stripe::Subscription.retrieve(nil)` raises locally before HTTP, so the main-plan branch is never entered.
- `conversion_duplicate_exists?` queries globally rather than org-scoped — verified live with two real orgs. The outcome is SPEC §3's stated invariant, since Stripe subscription ids are globally unique.
- Repeat `trial_started` is possible beyond the 5-minute dedupe, but no production path returns `stripe_subscription_status` to nil.
- A late invoice for a superseded subscription stamps the org's current plan — what SPEC §5.2 specifies.
- Six LOWs from the implementation review (unrescued trial_started writer matching the prior Discord line's exposure at the same site; two test-shadowing notes; pre-existing EOF newline; deliberate Discord-after-ledger coupling; isolation-example limitation).
