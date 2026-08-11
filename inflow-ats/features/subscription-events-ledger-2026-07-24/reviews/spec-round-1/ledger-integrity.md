# Angle 3 — Ledger integrity: migration + enum + interactor guard (spec round 1)

Verified against `app/models/subscription_event.rb`, `app/interactors/create_subscription_event.rb`, `db/schema.rb:1189–1197`, `db/migrate/20260723222212_add_adroll_click_id_to_users.rb`.

## Verifications (clean)

- Stale comment block confirmed EXACTLY as SPEC §1.2 describes (subscription_event.rb:4–11): duplicate "1:" labels (`assigned_free_plan_on_creation` and `converted_to_paid` both labeled 1), 0/1 names swapped vs the actual enum, every subsequent number off by one. Phase 1 candidate 5 verified; §1.2's directive to fix it stands, no amendment needed (accurate correction against the final 0–8 enum is plan-level).
- Enum values 7 and 8 are free (current enum tops out at `downgraded_plan: 6`); 0/1 untouched per D3; `converted_to_paid: 2` retained as the non-trial type. No conflicts.
- `subscription_events` current shape (schema.rb:1189–1197): `organization_id` (null: false), `event_type` (integer, null: false), `from_plan`, `to_plan`, timestamps, one index on `organization_id`. No `stripe_subscription_id`/`amount` columns exist; the two nullable additions with no defaults leave existing `assigned_free_plan*` rows valid.
- Migration analog verified live: `AddAdrollClickIdToUsers` is a single `add_column` change-method migration — the stated shape (+ `add_index`) is real.
- Interactor dedupe trap checked: §6 merges the new params into `event_params` only "when present" — absent params are omitted from the hash, so the 5-minute dedupe `.where(event_params)` clause is byte-identical for the existing caller (`log_assigned_free_plan_event`, organization.rb:1231–1243, the ONLY production caller — grep confirms). No regression path.
- Race handling: unique-index violation on non-bang `save` raises `ActiveRecord::RecordNotUnique`; §6 rescues it to the same graceful `context.fail!` no-op. Correct and complete.
- `Interactor` semantics: `CreateSubscriptionEvent.call` (non-bang class method) returns a failed context on `context.fail!` without raising — the webhook writers get graceful no-ops, matching §5.2/§5.3's "duplicate → interactor no-ops gracefully."

## Findings

- F1 [MED] SPEC §3 vs approved-decisions D7 / uniqueness key stated ambiguously for the migration author / D7: "uniqueness enforcement for one converted-type row per organization + stripe_subscription_id"; SPEC §3: "≤1 row per `stripe_subscription_id`" alone. A migration author reading both has a real fork: composite `[organization_id, stripe_subscription_id]` partial index vs single-column `stripe_subscription_id` partial index — and the §6 interactor guard must match whichever is chosen. Functionally the single-column form is STRICTLY TIGHTER (Stripe subscription ids are globally unique, so per-`stripe_subscription_id` uniqueness implies per-organization+subscription uniqueness); it satisfies the D7 invariant a fortiori, so no D-ruling conflict exists — the spec just has to commit to one form. / Fix (amendment): §3 amended to state the index is single-column on `stripe_subscription_id` (partial, `event_type IN (2, 8)`), explicitly noting it is strictly tighter than and therefore satisfies D7's wording, and that the §6 guard queries by `stripe_subscription_id` alone to match.

No other findings. Variable-naming, no-bang, and check-save-return rules are restated in the angles for plan/impl time; nothing in the spec text violates them.
