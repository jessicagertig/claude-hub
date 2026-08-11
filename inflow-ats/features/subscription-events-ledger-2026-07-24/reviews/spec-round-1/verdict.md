# Spec round 1 — verdict

All 7 angles + always-on checks run against SPEC.md and live source (`attribution-work-qa` @ a0d59115d, tree clean except the known unstaged db/schema.rb corruption). Every concrete spec claim (file paths, line numbers, method signatures, enqueue sites, schema columns, analog files) verified against source; no repo drift.

## Finding counts

| Angle | HIGH | MED | LOW |
|---|---|---|---|
| 1 webhook-delicacy-audit | 0 | 1 | 0 |
| 2 conversion-predicate-correctness | 1 | 0 | 1 |
| 3 ledger-integrity | 0 | 1 | 0 |
| 4 fan-out-contract | 0 | 2 | 2 |
| 5 posthog-payload-integrity | 0 | 0 | 0 |
| 6 behavior-preservation | 0 | 0 | 1 |
| 7 test-coverage-and-ghost-tests | 0 | 0 | 1 |
| **Total** | **1** | **4** | **5** |

No BLOCKER. No finding contradicts a D-ruling (D1–D12 + RESOLVED audited; the Angle 3 D7-wording delta resolves in D7's favor — the spec's index is strictly tighter). No escalation.

## Amendments applied to SPEC.md (all MED+; sweep for stale references done)

1. Angle 2 F1 (HIGH): §11 Risk 6 added — pre-existing subscriptions' first post-deploy paid invoice records a false conversion (row + PostHog; false Discord trial-converted ping when `trial_end` present); mitigation options listed; OPEN QUESTION for Jessica.
2. Angle 1 F1 (MED): §5.3 — insertion runs only when `organization` is present (`if organization` inside the rescue-wrapped block; the literal call's `organization.plan` raises on nil); §6 — guard-order fix, `return unless organization` moved above the `ap` lines (create_subscription_event.rb:11–13); §1.4 summary updated.
3. Angle 3 F1 (MED): §3 — index committed to single-column `stripe_subscription_id` (partial, `event_type IN (2, 8)`), stated as strictly tighter than and satisfying D7.
4. Angle 4 F1 (MED): §7 canceled_subscription cell — Discord enqueued only when `subscription_canceled_at` present, skip otherwise (PostHog still fires); §11.4 updated from "plan must verify" to the defined behavior; §9.3 gains the matching test case.
5. Angle 4 F2 (MED): §2 — removal shape in `Notification::PaidSubscriptionDeletedJob` pinned (perform:13 call + private `discord` method 21–23 removed; `ended_at` param and `@ended_at` stay — used by `blocks`:34); §1.5 cross-reference added.

LOWs (note-only, no amendment beyond the §9.3 line folded into amendment 4): Angle 2 F2, Angle 4 F3/F4, Angle 6 F1, Angle 7 F1.

## Delicacy audit

Every amendment PRESERVES OR TIGHTENS the §5 delicacy property: the `stripe_webhook_handler_job.rb` diff surface is still exactly two additive, rescue-isolated insertions; amendment 2 adds a conditional INSIDE sanctioned insertion 2 (removing a rescue-logged error path); no other amendment touches the file's spec.

## Outcome

Round 1 produced 1 HIGH → verification round 2 required (confirm amendments + stale-reference sweep only), per harness profile.
