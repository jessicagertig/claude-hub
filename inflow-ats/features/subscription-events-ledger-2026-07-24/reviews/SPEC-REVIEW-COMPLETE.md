# SPEC-REVIEW-COMPLETE — subscription-events-ledger (Phase 2)

## VERDICT: READY FOR PLANNING

One open question for Jessica (§11.6 rollout misclassification — below); it does not block planning because the spec is implementable as written and the run is ungated with her review after, but it should be ruled on before (or at) ship.

(Plain English Summary + Blast Radius were written BEFORE round 1 per stock procedure.)

## Plain English Summary (pre-review)

The spec turns the dormant `subscription_events` table into a real ledger for MAIN-plan subscription facts. Four event types get writers: `trial_started` (in the Organization `nil → 'trialing'` status callback), `trial_converted_to_paid` and `converted_to_paid` (at the end of the webhook's `invoice.paid` main-plan branch — conversion means cash actually moved), and `canceled_subscription` (at the end of the webhook's `subscription.deleted` main branch). A partial unique index guarantees at most one conversion row per `stripe_subscription_id`, which is what makes "first cash = the conversion" work without extra logic. An `after_commit on: :create` callback on `SubscriptionEvent` fans out to PostHog (all four types, with owner-first attribution properties) and to the three existing Discord jobs, whose enqueues MOVE out of their current sites — the payoff being that the trial-conversion Discord ping now fires when money moves instead of ~2h earlier at trial expiry (and never on a declined card). Slack jobs do not move. The webhook file is delicate: exactly two additive, rescue-isolated insertions and nothing else.

## Blast Radius (pre-review)

- `app/jobs/stripe_webhook_handler_job.rb` — DELICATE. Two additive insertions only (end of `invoice.paid` else-branch after line 297; end of `subscription.deleted` else-branch after line 210), each in its own `begin/rescue StandardError`. Existing three-tier rescue (299–309) and single rescue (212–215) must never see ledger failures.
- `app/models/organization.rb` — two callback branches only: 1128–1134 (add `CreateSubscriptionEvent.call`, remove `Discord::NotifyFreeTrialStartedJob` line 1131) and 1136–1140 (remove `Discord::NotifyTrialConvertedToPaidJob` line 1139). Slack jobs and `reset_ai_credits` stay byte-identical.
- `app/models/subscription_event.rb` — enum +`trial_started: 7`, +`trial_converted_to_paid: 8`; stale comment block fixed; new fan-out callback + private PostHog helpers.
- `app/interactors/create_subscription_event.rb` — optional `stripe_subscription_id:`/`amount:` params; conversion uniqueness guard; existing 5-minute dedupe and free-plan behavior unchanged.
- `app/jobs/notification/paid_subscription_deleted_job.rb` — Discord enqueue removed (Slack path intact).
- One migration: two nullable columns + partial unique index on `subscription_events`.
- Runtime consumers affected: PostHog event stream (4 new server-side events), Discord #subscriptions channel (3 jobs re-timed to ledger creation). Slack notifications, all AI-credit paths, all other webhook branches: zero change.
- Failure containment: every writer is rescue-isolated; interactor failure is a graceful `context.fail!`, so billing behavior is never blocked by the ledger.

---

## Round outcomes

**Round 1** (`reviews/spec-round-1/` — 7 angle files + verdict.md): 1 HIGH, 4 MED, 5 LOW. All five Phase 1 candidate findings verified against live source; four warranted amendments, one (the stale enum comment block) confirmed accurate as already specified. No BLOCKER; no finding contradicts a D-ruling; no escalation. Five amendments applied inline to SPEC.md:

1. (HIGH, Angle 2) §11 Risk 6 + §4 cross-reference — pre-existing already-converted subscriptions have no ledger row, so their first post-deploy paid invoice records a FALSE conversion: one row + PostHog event per existing paying subscription over its next billing cycle (up to ~12 months for annual), and a false Discord "Trial Converted to Paid" ping wherever `trial_end` is present (most trial-era customers). Disclosed with mitigation options; decision is Jessica's.
2. (MED, Angle 1) §5.3 + §6 — the §5.3 insertion runs only when `organization` is present (nil possible via `Organization.find_by` miss at stripe_webhook_handler_job.rb:174; the literal call's `organization.plan` would raise); root-cause backstop in §6: move `return unless organization` above create_subscription_event.rb:11–12's `ap organization.stripe_subscription_in_good_standing`, which currently crashes on nil before the guard.
3. (MED, Angle 3) §3 — uniqueness index committed to SINGLE-COLUMN `stripe_subscription_id` (partial, `event_type IN (2, 8)`); strictly tighter than D7's "organization + stripe_subscription_id" wording (Stripe sub ids globally unique), so the D7 invariant is satisfied — no ruling conflict.
4. (MED, Angle 4) §7/§11.4/§9.3 — `Discord::NotifySubscriptionDeletedJob` (required positional `ended_at`, runs `Time.at(ended_at)`) is enqueued ONLY when `organization.subscription_canceled_at` is present; absent → skip Discord, PostHog still fires — never `nil.to_i` into a fabricated 1970 timestamp.
5. (MED, Angle 4) §2/§1.5 — removal shape in `Notification::PaidSubscriptionDeletedJob` pinned: remove the `discord(...)` call at line 13 AND the private `discord` method (21–23); the `ended_at` param and `@ended_at` STAY (used by `blocks`:34 for the Slack timestamp).

LOWs (note-only, deliberately unamended): Discord noise from Risk 6 limited to trial-era subs (`converted_to_paid` has no Discord job); canceled→'trialing' second trials produce no `trial_started` row — exact mirror of today's behavior under the D6-pinned gate; Discord-after-ledger coupling means a failed/deduped interactor call skips the Discord ping — the pattern working as designed; new spec files listed in §9 not §2; the nil-`subscription_canceled_at` test line was folded into amendment 4.

**Round 2** (`reviews/spec-round-2/verification.md` — triggered by the round-1 HIGH; scope limited to amendment confirmation + stale-reference sweep): all five amendments confirmed in place and source-accurate; one residual stale reference fixed (§4's unqualified "classify correctly by construction" now cross-references Risk §11.6); sweep clean; delicacy property preserved (webhook file spec still exactly two additive rescue-isolated insertions — the round-1 nil-guard lives INSIDE sanctioned insertion 2). Round 2 CLEAN.

## Open questions for Jessica

1. **§11.6 — rollout misclassification of pre-existing subscriptions.** As specified, every already-paying subscription's first post-deploy `invoice.paid` writes a false conversion row + PostHog event, and a false Discord trial-converted ping when `trial_end` is present. Options: (a) accept and filter by date in PostHog (current spec behavior); (b) seed/backfill conversion rows for currently-subscribed orgs before enabling writers (would need §10's "no backfill" exclusion lifted); (c) a subscription-`created`-timestamp cutoff in the predicate. All three are design decisions outside the spec review's authority; D5's predicate itself is untouched by any of them except (c).

No other open questions. D1–D12 + RESOLVED audited against the spec and live source — no contradictions.
