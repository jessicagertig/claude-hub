# CLAUDE.md Hardening Report — subscription-events-ledger

**Source:** reviews/spec-round-1/ (+ verdict), reviews/spec-round-2/verification.md, reviews/plan-review.md + pass-1/, reviews/impl-round-1/ (+ verdict), reviews/SPEC-REVIEW-COMPLETE.md, reviews/IMPL-REVIEW-COMPLETE.md
**Date:** 2026-07-24
**Run shape:** zero fix loops — spec round 1 (1 HIGH + 4 MED, amended at spec level), plan pass 1 (3 MED, amended), impl round 1 PASS (6 LOW note-only). No FAILURE-REPORT.md files exist.

## Rules Added to ~/claude-hub/inflow-ats/CLAUDE.md

### 36. First-occurrence detection on a new ledger: the pre-existing cohort has no history rows — the spec must address it explicitly

From spec-round-1 conversion-predicate-correctness F1 (the run's only HIGH). Generalizes to any "first-X" event detection added to a live system: entities already past the event when the ledger ships have no history row, so their next occurrence looks like the first. The rule requires the spec to explicitly choose backfill / predicate cutoff / accept-and-disclose, with the choice surfaced to the owner. No existing rule covered this class (rule 16 is companion-record ownership; rule 20 is shared-infrastructure fixes; neither touches rollout-cohort semantics).

### 37. "Must still pass" test claims require an executed baseline run — never assert or checkbox green without one

From impl-round-1 escalations E1/E2. SPEC §9.5's "must still pass" premise for `stripe_webhook_handler_ai_credits_spec.rb` was already false at branch base (17/17 failures from a stale attribute name), and plan Task 9.6's "all green" checkbox was checked when green was impossible. Assessed as candidate territory item 4: chose a NEW baseline-verification rule over sharpening rule 6, because the lesson (execute the baseline before asserting it) applies to any pre-existing red, not only rename drift; rule 6 is cited in the motivation rather than amended.

## Existing Rules That Were Violated

- **Rule 6 (rename cascades: grep ALL references, including spec files)** — violated by ancestor commit `c2f69130d` (migration `20260611120002`, prior AI-billing work, NOT this run's agents): `amount_cents_paid` → `stripe_amount` renamed with three spec files never updated (`stripe_webhook_handler_ai_credits_spec.rb`, `organization_ai_credit_purchase_spec.rb`, `cancel_ai_credit_subscription_spec.rb`). Discovered mid-run as the 17/17 base failure; fix is Jessica's call (shared surface, rules 10/23). No weakening of rule 6 needed — it correctly names this exact failure; new rule 37 covers the detection-timing gap.

No rules were violated by this run's own agents. Rule 15 (review committed code), rule 26 (ghost tests), rule 31 (inline queue adapter), and D11 delicacy discipline were all actively applied and held.

## Findings Skipped (not hardened), with reasons

1. **Interactor pre-guard crash** (`ap organization.stripe_subscription_in_good_standing` at create_subscription_event.rb:12 executing before `return unless organization`; spec-round-1 webhook-delicacy-audit F1, MED). Skipped: the discipline that catches it already exists — rule 8 explicitly extends to "any method with early guards/raises: trace the full control flow from method entry," and the global Code Investigation Discipline requires reading the callee. The reviewer traced, caught it in round 1, and the fix was amended at spec level with zero downstream cost. A "no code above nil guards" rule would be generic hygiene, not a recurring harness gap.
2. **Required positional job argument receiving nil → `Time.at(nil.to_i)` = 1970 fabrication** (spec-round-1 fan-out-contract F1, MED). Skipped: covered by rule 13 (never fabricate fallback values — `.to_i` on nil is the same fabrication class as `|| 0`); the finding itself cited rule 10/13 and was caught in round 1, proving existing coverage works.
3. **Removal-shape ambiguity** (removing an enqueue living inside a private method; spec amended to pin call site + method + what stays; spec-round-1 fan-out-contract F2, MED). Skipped: feature-local spec-precision, caught routinely at MED by source-verification review; the implementer-side risk is already covered by rule 23 (fix agents must not remove beyond scope), and rule 35 covers the test-file side of removals. A general "pin removal shape" rule would restate what the review angles already enforce.
4. **Impl-round-1 LOWs** (unrescued `trial_started` writer matching prior exposure at the same line; two test-shadowing notes; pre-existing EOF newline; deliberate Discord-after-ledger coupling; isolation-example limitation). Skipped: all note-only, feature-local, or deliberate design properties carried from spec review.
5. **Plan-review MEDs** (missing `:test` queue-adapter around-blocks in Tasks 9.1/9.2; two line-number citation corrections). Skipped: the queue-adapter gap is exactly rule 31 doing its job (the plan reviewer cited it); citation drift is one-off source-accuracy noise.

## Process note

The run converged with zero fix loops: every MED+ was amended at the artifact level (spec or plan) before implementation, and impl round 1 passed clean. The two added rules capture the only findings with cross-feature recurrence value — a spec-design blind spot (rollout cohort of first-occurrence semantics) and a verification-integrity gap (unexecuted baseline claims).
