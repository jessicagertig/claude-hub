# Plan review pass 1 — Always-on checks: CLAUDE.md / cursor-rules / migration-safety compliance

(REVIEW-ANGLES defines 7 angles + always-on checks; this file records the always-on sweep that is not fully owned by a single angle.)

## Migration safety

- Additive only: two nullable columns, no defaults, one partial unique index on a tiny table (free-plan rows only). No data loss possible; no backfill.
- Schema hunk-staging HARD rule carried VERBATIM from SPEC §3 into Task 11.1, with a concrete non-interactive mechanism (`git apply --cached` of a hand-built patch) and an explicit no-fallback instruction (never `git add db/schema.rb`); pre-existing corruption hunks enumerated for the verify step.
- Both dev and test DB migrate steps present (Task 1.2), `db:migrate` only; prohibited commands (`db:reset`/`db:setup`/`db:schema:load`/`db:test:prepare`, `DATABASE_URL`) named as prohibited.
- Detached-commit procedure per memory rules: nohup outside sandbox, `nvm use`, ≥20 min, retry on kill, never `--no-verify`. LOCAL ONLY, never push (PR #3075).

## Cursor rules / house style (citations verified against live cursor_rules/core_critical_rules.md)

- Rule 8 ("Guard Clauses: No Truthy/Falsy Return Values") — plan's style section mandates bare `return unless x` guards; planned code complies.
- Rule 10 ("Never Fabricate Fallback Values") — the two sanctioned `.to_i` uses are spec-verbatim (`amount_paid.to_i > 0`) or inside a `present?` guard (`subscription_canceled_at.to_i`); `.compact` semantics respected.
- Rule 11/12 (no bang methods in app/; check save/update returns) — planned app code uses `.call`, non-bang `save` via the existing interactor; bang confined to specs.
- Line 340 "Do not automate edits to `app/models/organization.rb`" — acknowledged in Task 5 with the explicit spec/harness-profile sanction for exactly two branch edits.
- backend/_base.md §1 — method-level rescue preferred (Task 3.4 complies); `begin/rescue` inside a method only for a nested subset (exactly the two webhook insertions, spec-mandated).
- D10: no `.presence` anywhere in the planned code; full if/elsif/else selection shapes; `ap` not `pp`; single quotes except interpolation; record variables named for their models.

## Immutable rulings (D1–D12 + RESOLVED)

No plan step contradicts any ruling. D7's wording delta (organization + stripe_subscription_id) was ruled satisfied a fortiori by spec amendment 3 — the plan implements the amended §3 invariant. §11.6 open question NOT resolved by the plan (correctly planned AS WRITTEN, plan Risk 1). The D8 PROPOSED log-first soak stays superseded per RESOLVED — the plan does not resurrect it.

## Findings

None beyond those recorded in the angle files (MED-1 rule-31 setup omission, MED-2/MED-3 line-anchor accuracy — all amended).
