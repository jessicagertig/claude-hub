# Plan review pass 1 — Angle 6: Behavior preservation (reverse audit of the plan)

## Planned diff vs SPEC §2 / §10

Task 10.1's enumerated complete diff matches SPEC §2 exactly: 1 migration; hunk-staged `db/schema.rb`; `subscription_event.rb`; `create_subscription_event.rb`; `organization.rb` (two hunks); `paid_subscription_deleted_job.rb` (removal shape only); `stripe_webhook_handler_job.rb` (exactly two additive hunks); 4 new spec files. Zero-hunk list carried: Slack `Notification::*` jobs, `Discord::Notify*` job FILES, `sync_with_stripe`, every other webhook branch, AI-credit paths, serializers, policies, routes, frontend.

## §10 out-of-scope sweep — nothing planned that §10 excludes

- No `upgraded_plan`/`downgraded_plan`/`downgraded_to_free` writers (D12) — enum values planned with "no writer yet" comments only.
- No Slack job migrations; no Discord job for non-trial conversion; no CAPI/ad-platform sends; no `billing_interval` property (explicitly "do not add it"); no currency column; no backfill of any kind (§11.6 planned AS WRITTEN — plan Risk 1); no `assigned_free_plan*` behavior change (conditional param merge preserves dedupe semantics; fan-out falls through); no `sync_with_stripe` change; no other webhook branch; no AI-credit path.

## §11 risks carried

§11.1 → plan Risk 2. §11.2 → Task 5.2 stated consequence. §11.3 → fan-out Discord guard + Task 4.1 note. §11.4 → Task 4.1 (skip-when-absent, defined). §11.5 → Task 8.3 two-hunk verification. §11.6 → plan Risk 1, planned as written, NOT resolved by the plan (correct — Jessica's open question).

## Existing-behavior preservation claims verified against live source

- Both insertion points append after ALL existing branch behavior (invoice.paid: update 291 / payment method 296 / reset 297; subscription.deleted: sync 205 / update_column 208 / both enqueues 209–210).
- organization.rb: only the two sanctioned branch edits; Slack lines, `ap` lines, `reset_ai_credits`, every other handler byte-identical in the target states (diffed against live 1128–1140).
- Removed Discord enqueues: the three grep-confirmed sites are the only ones; after the moves, a ledger row is the ONLY path to those three Discord jobs.
- Free-plan writer (`log_assigned_free_plan_event` → organization.rb:1237): behavior unchanged (guard-order fix is a no-op for `organization: self`; params merge conditional).
- Estimated scope figures consistent with the planned edits (organization.rb +1/−2 across two hunks; paid_subscription_deleted_job.rb −4).
- Commits-not-working-tree (pipeline rule 15) is an impl-review concern; the plan's Task 11 commit procedure (detached, ≥20 min, LOCAL ONLY, never push, PR #3075 Jessica's) matches the harness profile and memory rules.

## Findings

None.
