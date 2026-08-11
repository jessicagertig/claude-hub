# QA run 5 — Layer 3 (script runner) — Round 1 summary — CLEAN (terminal)

**Diff under test:** `a0d59115d..33dffbe3e` on `attribution-work-qa` (feature `89286fba8` + four spec-only fix commits)
**Agents:** 9, sequential, against the qa-harness test server (RAILS_ENV=test, port 5007).
**Result: 0 HIGH — Layer 3 passes** (one clean round terminal per harness-profile; both MEDs deliberately left with reasoning).

| Agent | Slice | Findings |
|---|---|---|
| 1 | D5 predicate zero-cash cells | 0 |
| 2 | D5 cash cells + row completeness + fan-out | 0 |
| 3 | uniqueness invariant + redelivery live | 0 |
| 4 | trial_started callback chain live | 0 |
| 5 | subscription.deleted branch live | 0 |
| 6 | fan-out matrix live | 0 |
| 7 | PostHog payload + attribution fallback live | 1 HIGH (adjudicated MED), 1 LOW |
| 8 | rescue isolation + existing-branch preservation | 0 (211 live checks) |
| 9 | adversarial sweep + spot-check of priors | 0 HIGH; 1 MED addendum, 5 LOW |

## What the round establishes at runtime

The SPEC §4 predicate matrix behaves as ruled against a live database: zero-cash and nil-amount deliveries write no row while every pre-existing branch effect still runs; positive cash with `trial_end` present classifies `trial_converted_to_paid`, absent classifies `converted_to_paid`, rows born complete with `amount` and the event-sourced `stripe_subscription_id`. Duplicate redelivery yields exactly one conversion row, and agent 9 proved the *guard* is what holds it — not the 5-minute dedupe — by backdating the first row past the dedupe window and asserting the dedupe query evaluated false before redelivering. The DB index is a live backstop (`ActiveRecord::RecordNotUnique` on a direct second insert), and the interactor's own `rescue ActiveRecord::RecordNotUnique` path, which no earlier agent had driven, fails gracefully with nothing written and no fan-out.

Rescue isolation holds under three forced error classes at both sanctioned insertions, including when the forced error is exactly the type an outer tier catches: all pre-existing effects survive byte-identically, the insertion's own rescue logs once with context, and the outer tiers never fire. AI-credit `invoice.paid` and `subscription.deleted` events write zero ledger rows with zero interactor invocations. The `CustomStripeSubscriptionMissingError` guard keeps nil-`stripe_subscription_id` orgs away from the predicate, with a falsifier confirming the same event writes a row once the id is present.

The fan-out fires exactly the SPEC §7 job set per `event_type`, skips the Discord enqueue when `organization.subscription_canceled_at` is nil while PostHog still fires, enqueues nothing for `assigned_free_plan*` or the three deferred types, and fires only on create. The 13-field attribution fallback was exercised across all six cells: owner wins when present, blank `""`/`{}` falls through to the organization (proving `present?` not `nil?`), both-blank drops the key via `.compact`.

## The one thing that needs Jessica's ruling — A7-H1 (filed HIGH, adjudicated MED)

A `utm_data` jsonb value containing an ActiveJob reserved key (`_aj_globalid`, `_aj_serialized`, `_aj_symbol_keys`, `_aj_ruby2_keywords`, `_aj_hash_with_indifferent_access`) on **either** the owner User or the Organization makes `PosthogTrackJob.perform_later` raise `ActiveJob::SerializationError` inside `SubscriptionEvent#handle_after_commit_on_create`. Reproduced independently by agents 7, 8 and 9.

Consequences, all observed live:
- **`trial_started`:** the raise escapes `Organization#update!` to its caller. The ledger row persists; `Discord::NotifyFreeTrialStartedJob` and the PostHog event are lost; and **`organization_ai_credit_balance&.reset_ai_credits` is skipped** (A9-M1 — the writer call took the exact line the removed Discord enqueue held, ahead of `reset_ai_credits`).
- **Both webhook writers:** the insertion's own rescue swallows it. The ledger row persists while the PostHog conversion event and the Discord cash notification are silently lost. Nothing escapes `handle_stripe_event`.

Held at MED on **reachability**, not on fix cost: the app's own frontend cannot produce the trigger (`utils.js:192-208` filters `utm_data` keys to the `utm_` prefix; all five reserved keys begin with `_aj_`), so it takes a hand-crafted POST to the public signup endpoint, which permits `utm_data: {}` unrestricted. That is adversarial input, not the "reasonable workflow" the HIGH bar describes. The code is exactly what D9 and SPEC §7 specify, so this is a defect in the approved design rather than a deviation from it.

Two things worth Jessica's attention when she rules: the exposure is **feature-introduced** — `subscription_event.rb:59` is the only site in the codebase that passes user-controlled data to `perform_later`, all 11 other `PosthogTrackJob` callers pass hand-built scalar hashes — and the blast radius reaches the checkout path, because the `nil -> 'trialing'` flip happens inside `Organization#sync_with_stripe`, called from three webhook branches and four `billing_controller` sites. A feature-local fix does exist (a rescue around `enqueue_posthog_track`), so this need not be expensive; it is left unfixed because choosing among the options is a design decision, not a QA call.

## LOW notes (no action)

`deep_symbolize_keys` symbolizes nested `utm_data` keys with identical wire bytes; the 4-byte `amount` column would lose a conversion row above $21.4M; the partial unique index does not constrain NULL `stripe_subscription_id` (proven unreachable — `Stripe::Subscription.retrieve(nil)` raises locally before the branch is entered); `conversion_duplicate_exists?` is global rather than org-scoped, which is SPEC §3's stated invariant; repeat `trial_started` needs a status reset to nil that no production path performs; a late invoice for a superseded subscription stamps the current plan, per SPEC §5.2.

## Safety

Zero real Stripe HTTP (agent 9's `execute_request` raise guard never fired). `POSTHOG_CLIENT` is **not** nil in the test environment — it is a live client with a real API key — so the queue adapter was held at `:test` throughout and every capture was stubbed with an assertion the stub took effect; no real sends. Database left clean. Source repo untouched, HEAD still `33dffbe3e`, the pre-existing unstaged `db/schema.rb` never touched.
