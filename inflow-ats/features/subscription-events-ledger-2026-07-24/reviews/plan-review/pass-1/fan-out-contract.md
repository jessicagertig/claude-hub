# Plan review pass 1 — Angle 4: Fan-out contract (Discord moves + enqueue table)

## Structural manifest verification (rows checked against live source)

- Registration: `after_commit :handle_after_commit_on_update, on: [:update]` is at organization.rb:**59**, not 58 as the manifest cited. **MED-2 (source accuracy) — AMENDED** (both occurrences: the "Analog read live" line and manifest row 3).
- Dispatcher 1023–1029 (five handler calls 1024–1028) — CORRECT. Handlers 1031–1156 — CORRECT. Predicate helpers 1159–1221 — CORRECT. `private` at 1709 (all analog handlers/helpers public) — CORRECT. `handle_before_update`'s rescue at 1019 (the only rescue in the callback family) — CORRECT. `ap` entry lines 1110–1112 / 1129 / 1137 — CORRECT.
- Manifest verdicts and justifications hold: `on: :create` (D8), single event_type-keyed handler, no `persisted?`/`saved_changes` guards (update semantics), enum predicates in exclusive if/elsif, no rescue in the handler (matches analog; writers carry isolation), private visibility (SPEC §7 SPEC-PROPOSED adopted), payload builders EXTRA justified by D9. No unjustified DIFFERENT/EXTRA rows.

## Enqueue-site moves — grep-verified as the ONLY current sites

`grep -rn "Discord::NotifyFreeTrialStartedJob\|Discord::NotifyTrialConvertedToPaidJob\|Discord::NotifySubscriptionDeletedJob" app/ lib/` → exactly three enqueue sites: organization.rb:1131, organization.rb:1139, notification/paid_subscription_deleted_job.rb:22 (plus the three job-class definitions, untouched). CORRECT.

- Task 5.1 target state matches live 1128–1134 byte-for-byte minus the Discord line plus the writer call (Slack line, `ap` line, `reset_ai_credits` preserved). Task 5.2 matches live 1136–1140 minus the Discord line. Task 5.3 pins the two-hunk invariant. core_critical_rules "Do not automate edits to `app/models/organization.rb`" (line 340) acknowledged; the spec/harness-profile sanction is the entire permitted surface.
- Task 6 removal shape verified against live `paid_subscription_deleted_job.rb`: `discord(organization_id, ended_at)` call at 13, private `discord` method at 21–23 (line 22 the enqueue), `@ended_at = ended_at` at 10 STAYS, `blocks` uses `@ended_at` at 34 for the Slack timestamp. Slack path intact; no call to a removed method remains after the removal. CORRECT per amended SPEC §2.

## Per-type enqueue table (Task 4.1)

- Arities verified live: `Discord::NotifyFreeTrialStartedJob#perform(organization_id)`, `Discord::NotifyTrialConvertedToPaidJob#perform(organization_id)`, `Discord::NotifySubscriptionDeletedJob#perform(organization_id, ended_at)` — `ended_at` REQUIRED positional, `Time.at(ended_at)` at notify_subscription_deleted_job.rb:14 (perform at :7). Plan's citations correct.
- `canceled_subscription`: Discord enqueued ONLY when `organization.subscription_canceled_at.present?`; `.to_i` sits INSIDE the guard — never a fabricated 1970 timestamp (amended §7; the Angle-4 trap resolved). Webhook path writes the column at stripe_webhook_handler_job.rb:208 before insertion 2 creates the row — verified live. PostHog still fires when absent.
- `converted_to_paid`: PostHog only, no Discord (none exists; none added). `assigned_free_plan*`: falls through the if/elsif chain — NOTHING enqueued.
- No-owner bail-out `return unless organization&.owner` — `belongs_to :owner, class_name: 'User'` (organization.rb:41, non-optional) so defensive, as stated.
- D6 callback-inside-callback for `trial_started` accepted and noted in Task 5.1.
- No name clashes: `handle_after_commit_on_create`, `enqueue_posthog_track`, `posthog_properties`, `attribution_value` — zero grep hits in app/ and lib/ at a0d59115d.

## Findings

- MED-2 (source accuracy): manifest cited organization.rb:58 for the analog registration; live line is 59. AMENDED inline (two occurrences). No other manifest anchor was wrong.
