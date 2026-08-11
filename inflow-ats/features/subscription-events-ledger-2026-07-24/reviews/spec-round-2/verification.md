# Spec round 2 — verification (scope: confirm round-1 amendments + stale-reference sweep only)

Repo re-verified before this round: `attribution-work-qa` @ a0d59115d, tree clean except the known unstaged db/schema.rb corruption. No drift.

## Amendment confirmation (full SPEC.md re-read)

1. **Angle 2 F1 (HIGH) — rollout misclassification:** §11.6 present and complete (consequence sized: one false row + PostHog event per pre-existing paying subscription over its next billing cycle; false Discord `Discord::NotifyTrialConvertedToPaidJob` ping when `trial_end` present; no DB-local discriminator inside D5; mitigation options listed as Jessica's decisions). CONFIRMED. Residual stale reference found and fixed in this round: §4's "renewals ... classify correctly by construction" was still unqualified — cross-reference to Risk §11.6 added so the boundary condition is visible where the predicate is defined.
2. **Angle 1 F1 (MED) — nil organization at §5.3:** §5.3 nil-organization paragraph present (`if organization` conditional inside the rescue-wrapped block; rationale that an interactor call cannot be `&.`-guarded); §6 guard-order bullet present (move `return unless organization` above create_subscription_event.rb:11–12's `ap` lines; sole production caller organization.rb:1237 unaffected); §1.4 summary mentions the guard-order fix. CONFIRMED against source (create_subscription_event.rb:11–13 verified as described).
3. **Angle 3 F1 (MED) — uniqueness key:** §3 commits to the single-column partial index on `stripe_subscription_id` (`event_type IN (2, 8)`), states it strictly satisfies D7; §1.1 and §6 wording consistent (per-`stripe_subscription_id` throughout). CONFIRMED. No D-ruling conflict.
4. **Angle 4 F1 (MED) — nil `subscription_canceled_at`:** §7 canceled_subscription cell defines the skip behavior (Discord only when present; PostHog still fires); cited job facts re-verified (notify_subscription_deleted_job.rb:7 `def perform(organization_id, ended_at)`, :14 `Time.at(ended_at)`); §11.4 updated from "plan must verify" to the defined behavior; §9.3 carries the matching test case. CONFIRMED.
5. **Angle 4 F2 (MED) — removal shape:** §2 pins the exact removal (perform:13 call + private `discord` method lines 21–23; `ended_at` param and `@ended_at` stay — `blocks`:34 uses `@ended_at`); §1.5 cross-references §2. Re-verified against paid_subscription_deleted_job.rb (line 13 call, 21–23 method, 34 `@ended_at || Time.now.to_i`). CONFIRMED.

## Stale-reference sweep (whole document)

Grep for superseded phrases: "ended_at?", "verify the job's argument handling", "job's tolerance", "Guarded `organization&.`", "plan time" — zero hits. "organization + stripe_subscription_id" appears only inside §3's explicit D7-comparison sentence (intentional). §11 risk numbering 1–6 consistent; no section references a stale risk number. Internal cross-references (§1.4→§6, §1.5→§2, §4→§11.6, §5.3→§6, §7→§11.3, §11.4→§7) all resolve.

## Delicacy check

The amended §5 still permits exactly two additive, rescue-isolated insertions in `app/jobs/stripe_webhook_handler_job.rb`; the only round-1 change inside that file's spec is the `if organization` conditional WITHIN sanctioned insertion 2 — the delicacy property is preserved and tightened.

## Verdict

All round-1 amendments confirmed in place and source-accurate; one residual stale reference (§4) fixed within this round's scope. No new findings. Round 2 CLEAN.
