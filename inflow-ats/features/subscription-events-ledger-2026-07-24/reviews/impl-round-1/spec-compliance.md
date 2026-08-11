# Always-on — Spec compliance (every §-requirement) — impl round 1

**Method:** SPEC.md walked §-by-§ against the committed diff and live files. Spec-implementation mismatch is never MED — none found at any severity.

## Findings: 0 BLOCKER / 0 HIGH / 0 MED / 0 LOW

| Spec § | Requirement | Verdict |
|---|---|---|
| §1.1/§3 | Migration: two nullable columns + ≤1 conversion row per `stripe_subscription_id` (single-column partial unique index, `event_type IN (2, 8)`), no defaults/backfill/currency | MATCHES (`20260725033136`; index name plan-canonical) |
| §1.2/§2 | Enum +`trial_started: 7`, +`trial_converted_to_paid: 8`; 0/1 untouched; 2–6 kept; stale comment fixed; D2 main-plan comment; `canceled_subscription` gets a writer; 4/5/6 no writers | MATCHES (comment accurate against final enum) |
| §1.3/§5.1 | `trial_started` writer in the `subscription_started_trial_after_commit?` branch; Discord line removed; Slack + `reset_ai_credits` byte-identical; converted branch loses Discord line only | MATCHES (diff shows exactly this) |
| §5.2 | Insertion 1: end of `invoice.paid` else-branch, own begin/rescue, §4 predicate, args verbatim, `from_plan` nil | MATCHES |
| §5.3 | Insertion 2: end of `subscription.deleted` else-branch, own begin/rescue, `if organization` guard, args verbatim, no amount | MATCHES |
| §1.4/§6 | Interactor extended not replaced: conditional param merge, check-first conversion guard → graceful `fail!`, `RecordNotUnique` backstop, guard-order fix, dedupe/free-plan behavior unchanged | MATCHES |
| §1.5/§7 | `after_commit on: :create` fan-out keyed on event_type; per-type table incl. `converted_to_paid` no-Discord and the `subscription_canceled_at.present?` Discord gate; `assigned_free_plan*` → none | MATCHES |
| §7 payload | Owner distinct_id via `PosthogTrackJob`; event properties only; `amount`(compact)/`stripe_subscription_id`/`stripe_customer_id`/`to_plan`; defaults not duplicated; 13 attribution fields via `attribution_value` (D10 shape); `.compact`; `billing_interval` OMITTED; no groups/`$set` | MATCHES |
| §2 modified/created/untouched lists | Diff = exactly the 5 app files + 1 migration + schema hunks + 4 specs; removal shape in `paid_subscription_deleted_job.rb` exact (call + private method removed; `ended_at`/`@ended_at` stay) | MATCHES |
| §3 schema commit rule | Hunk-staged exactly columns+index+version bump; corruption unstaged | MATCHES (verified both directions) |
| §4 | Predicate placement, cash gate, live-retrieved `trial_end`, first-cash via invariant, no `billing_reason`/status | MATCHES |
| §8 | Analogs consulted; structural manifest honored (see fan-out-contract.md) | MATCHES |
| §9 | Four spec files with the required content; §4 matrix REQUIRED — present; adapter blocks present | MATCHES (28/28 green). §9.5 "ai_credits spec … must still pass": spec file untouched (byte-identical) ✓ but it does NOT pass — 17/17 pre-existing failures unrelated to the diff → ESCALATION E1 in verdict.md (evidence the spec's premise was already false at `a0d59115d`), not an implementation mismatch |
| §10 out-of-scope | No deferred writers, no Slack moves, no non-trial Discord job, no CAPI, no billing_interval, no currency, no backfill, no `sync_with_stripe`/other-branch/AI-credit changes | MATCHES |
| §11.6 | Rollout misclassification ships AS SPECCED (disclosed open question — not flagged as a defect per mandate) | AS SPECCED |

D1–D12 + RESOLVED-at-go audited: no implementation choice contradicts any ruling.
