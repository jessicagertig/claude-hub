# Phase 8 QA — COMPLETE

**Final verdict: APPROVED**
**Date:** 2026-07-27
**Code under QA:** committed diff `a0d59115d..33dffbe3e` on `attribution-work-qa` (local, never pushed)
**Branch state at completion:** HEAD `33dffbe3e`, tree clean except the pre-existing unstaged `db/schema.rb` corruption (untouched throughout, as required)

The diff is app commit `89286fba8` plus four spec-only fix commits (`7574df408`, `e850c74fe`, `549039a0c`, `33dffbe3e`). **The app code has not changed since `89286fba8`** — all four fix cycles corrected test falsifiability, never behavior. Every one of the five commits passed its full Cypress pre-commit hook.

---

## Per-layer results

| Layer | Status | Rounds | Agents | HIGH+ | MED | LOW |
|---|---|---|---|---|---|---|
| 1 — diff-to-spec | PASS (closed in run 5) | 5 runs × 1 round | 50 | 0 in run 5 | 1 (M3) | — |
| 2 — code correctness | **SKIPPED** by profile | — | — | — | — | — |
| 3 — script runner | PASS | 1 | 9 | 0 | 2 → 1 after dedup (M1) | 6 |
| 4 — regression | PASS | 1 | 1 | 0 | 1 (M4) | — |
| 5 — Playwright | **SKIPPED** by profile | — | — | — | — | — |

**Recorded skips.** Layer 2 is skipped per the standing trim in `harness-profile.md`. Layer 5 is skipped because the feature has zero browser-reachable surface — webhook, model callback and background jobs only. Both skips are profile decisions made before the run, not layers that failed to execute. Every layer the profile calls for was executed to a clean round.

**Convergence rule applied:** one clean round per layer is terminal (`harness-profile.md`), not the stock two.

---

## Run history

| Run | Layer 1 result | Outcome |
|---|---|---|
| 1 | 1 HIGH (`l1-a2-001`) — ledger-failure example missing the `reset_ai_credits` assertion | fix `7574df408` → run 2 |
| 2 | 1 HIGH (`r2-l1-a3-001`) — `sync_with_stripe` stubbed but never asserted | fix `e850c74fe` → run 3 |
| 3 | 2 HIGH (`r3-l1-a4-001`, `r3-l1-a9-001`) — duplicate-delivery example inside the dedupe window; ledger-failure example satisfiable by the pre-existing outer rescue | fix `549039a0c` → run 4 |
| 4 | 10 HIGH filed, 9 to the fix loop — exhaustive 55-row mechanism matrix | fix `33dffbe3e` → run 5 |
| 5 | CLEAN — Layer 1 closed; Layers 3 and 4 executed and clean | **APPROVED** |

All 14 findings across runs 1–4 were test-falsifiability defects in the new spec files. **App code was clean in every slice of every Layer 1 audit, five consecutive times**, including the D11 delicacy audit (34 insertions / 0 deletions, two sanctioned hunks, blob-hash identical across all four fix commits).

Run 5 was executed by two orchestrators: a predecessor closed Layer 1 and ran Layer 3 agents 1–6 before being stopped mid-round; a replacement finished Layer 3 (agents 7–9), ran Layer 4, and completed the run. No completed work was redone.

**Total agents dispatched across all runs and layers: 60** (50 Layer 1, 9 Layer 3, 1 Layer 4).

---

## What Layer 3 established at runtime

Nine agents drove `StripeWebhookHandlerJob#handle_stripe_event` directly with constructed real-shape Stripe event doubles against a live test database, with all Stripe calls stubbed and the ActiveJob queue adapter held at `:test` so no Discord, Slack or PostHog send could fire.

- **SPEC §4 predicate matrix, live:** zero-cash and nil-amount deliveries write no row while every pre-existing branch effect still runs; positive cash with `trial_end` present classifies `trial_converted_to_paid`, absent classifies `converted_to_paid`; rows born complete with `amount` and the event-sourced `stripe_subscription_id`.
- **Uniqueness under redelivery:** exactly one conversion row, and agent 9 proved the check-first guard is the enforcing mechanism — not the 5-minute dedupe — by backdating the first row past the dedupe window and asserting the dedupe query evaluated false before redelivering. The partial unique index is a live backstop, and the interactor's `rescue ActiveRecord::RecordNotUnique` path (never previously driven) fails gracefully.
- **Rescue isolation at both sanctioned insertions:** under three forced error classes, including when the forced error is exactly the type an outer tier catches, every pre-existing effect survives byte-identically, the insertion's own rescue logs once with context, and the outer tiers never fire.
- **`trial_started`** from a real `nil -> 'trialing'` `organization.update!` flip; **`canceled_subscription`** from `subscription.deleted`, including the nil-`subscription_canceled_at` Discord skip with PostHog still firing.
- **Fan-out** fires exactly the SPEC §7 job set per `event_type`; `assigned_free_plan*` and the three deferred types enqueue nothing; fires only on create.
- **PostHog payload:** the 13-field owner-first fallback exercised across all six cells, `.compact` behavior confirmed, `distinct_id` is the owner's id, no `groups`/`$set`, no duplication of `default_properties`, verified end-to-end into the stubbed `capture`.
- **AI-credit paths (D2)** write zero ledger rows with zero interactor invocations; the `CustomStripeSubscriptionMissingError` guard keeps nil-`stripe_subscription_id` orgs away from the predicate.

Agent 9 independently reproduced 7 of 7 load-bearing claims from agents 1–6 using its own seed data and scripts. Zero disagreements.

## What Layer 4 established

The entire RSpec suite was run (73 files, 5 batches) rather than a subset, because the diff touches `app/models/organization.rb`, which nearly every spec instantiates.

**724 examples, 148 failures, 1 pending — all 148 proven pre-existing, zero feature-caused.** The four new feature spec files are green (34 examples, 0 failures, all four confirmed loaded via `--dry-run`). No failure message mentions `SubscriptionEvent`, `CreateSubscriptionEvent`, `PosthogTrackJob`, `subscription_events` or any `Discord::` job. The one genuine regression vector — the feature removing two Discord enqueues from `Organization#handle_after_commit` — is asserted by no non-feature spec.

Cypress was not re-run: the full suite passed at all five pre-commit hooks on this branch.

---

## Open items for Jessica

See **`QA-MED-FINDINGS.md`**. Nothing was fixed during this QA phase. Two entries need a decision:

1. **M1 — `utm_data` with an ActiveJob reserved key breaks the fan-out.** Feature-introduced, spec-compliant, and not reachable through the app's own UI. Consequences include a skipped `reset_ai_credits` on the trial path and silently lost notifications on the webhook paths. Five options laid out, including a cheap feature-local fix.
2. **M2 — SPEC §11.6 rollout misclassification**, the pre-existing open question carried forward: as specified, every already-paying subscription records one false conversion on its first post-deploy paid invoice.

M3 (placement has no runtime pin), M4 (148 pre-existing suite failures, no green baseline) and M5 (`POSTHOG_CLIENT` is live in test) are report-only.

---

## Safety record

No `db:drop`/`reset`/`setup`/`schema:load`/`test:prepare` and no migration command of any kind was run. No `psql`, no `DATABASE_URL`, no `.env` access. Zero real Stripe HTTP (a loud `Stripe::StripeClient#execute_request` raise guard was installed and never fired). No real PostHog, Discord or Slack sends. All scripts written to `/tmp`; nothing written into the source repo; no git write commands, no stash operations. The test server was stopped via `qa-harness stop` and the two orphaned test-env processes (verified via `lsof` as writing `log/test.log`) were SIGTERMed; port 5007 is free. Jessica's dev server and browser sessions were never touched.
