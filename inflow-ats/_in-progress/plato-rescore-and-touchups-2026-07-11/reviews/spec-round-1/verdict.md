# Spec Review — Round 1 Verdict
**Date:** 2026-07-11 (Phase 2 spec review)

## Counts
- BLOCKER: 0
- HIGH: 0
- MED: 3 (item1-mailer-recipients F1 [accuracy amended + decision escalated], item1-mailer-recipients F2 [stale spec, amended], item2-single-send-gate F1 [double stub, amended])
- LOW: 2 (item1-modal F1 [body wrapper unpinned], item1-runplato F1 [candidatesCount vs candidatesToScoreCount, numerically equal])

## Amendments Applied
1. SPEC 1.6 — retain `@user = User.find(user_id)` in `complete`/`failed`; only `to:` broadens; `user_first_name` continues to resolve from the triggering user. Added an inline ESCALATION note about the whole-team greeting.
2. SPEC 1.7 — expanded the "extend the mailer spec" bullet to direct reconciling the pre-existing staleness: 6-arg `complete` call, subject strings ("Your Plato reviews…" / "We couldn't complete your Plato reviews…"), tags `['polymer','user-facing']`, and multi-recipient `to:` assertions.
3. SPEC 2.8 — the interactor spec's `validation_result` double must also stub `textract_pending: false` (single-send interactor reads it at :41; bulk double omits it).

## Escalations (owner decision needed — NOT amended)
- SPEC 1.6 greeting semantics: with `@user` retained, every hiring-team recipient's email carries the triggering user's `user_first_name`. Acceptable, or should the greeting variable change? (Contingent on how the external Postmark templates use `user_first_name` — not verifiable from the repo.)

## Verdict: FAIL (3 amendments applied; 1 open escalation)
