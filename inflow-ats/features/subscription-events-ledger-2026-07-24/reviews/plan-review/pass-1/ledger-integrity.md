# Plan review pass 1 — Angle 3: Ledger integrity (migration + enum + interactor guard)

## Enum (Task 2.1)

- Live `app/models/subscription_event.rb`: stale comment block at lines 4–11 confirmed stale exactly as described (duplicate "1:" labels, `0:` labeled `assigned_free_plan` while the enum has `assigned_free_plan_on_creation: 0`, numbering off by one throughout). The planned replacement comment is accurate against the planned final enum, and carries the D2 main-plan-only sentence.
- Values 0–6: names and numbers byte-identical in the planned target state (0/1 live production rows — D3). `trial_started: 7`, `trial_converted_to_paid: 8` added. `belongs_to :organization` and `validates :event_type, presence: true` preserved.
- `CONVERSION_EVENT_TYPES = %w[converted_to_paid trial_converted_to_paid].freeze` — single Ruby home of the 2/8 pairing; migration SQL hardcodes ints with a naming comment (plan Risk 5 discloses this).

## Migration (Task 1)

- Analog `db/migrate/20260723222212_add_adroll_click_id_to_users.rb` EXISTS live — bare `add_column` in `def change`, matches the planned shape.
- Cited partial-unique-index analog `db/migrate/20260408040501_create_organization_ai_credit_purchases.rb:25–29` EXISTS live and lines 25–29 are exactly the `add_index ..., unique: true, where: '...', name: '...'` block the plan copies syntax from. CORRECT.
- Planned index: single-column on `stripe_subscription_id`, partial `event_type IN (2, 8)` — the amended-§3 invariant verbatim (strictly tighter than D7's wording; ruled satisfied a fortiori by spec amendment 3). Enum ints 2/8 match the planned enum. Index name `idx_subscription_events_conversion_stripe_sub_id` = 48 chars < 63. Both columns nullable, no defaults, no backfill, no currency column. NULLs distinct under Postgres partial unique index — consistent with the §6 guard firing only when `stripe_subscription_id` present.
- Live `db/schema.rb` `create_table "subscription_events"` block (1189–1197): organization_id / event_type / from_plan / to_plan / timestamps / org index — matches the plan's assumed base state.
- Task 1.2 migrates BOTH dev and test DBs via `db:migrate` only; prohibited commands named. Task 1.3/11.1 carry the schema hunk-staging HARD rule verbatim from SPEC §3. Additive only, no data loss.

## Interactor (Task 3)

- Guard-order fix: live create_subscription_event.rb has `ap 'Stripe subscription in good standing?'` at 11, `ap organization.stripe_subscription_in_good_standing` at 12, `return unless organization` at 13 — exactly as the plan states. Sole production caller: `CreateSubscriptionEvent.call` at organization.rb:1237 inside `log_assigned_free_plan_event` (def 1231), always `organization: self` — behavior unchanged for it (the `ap` lines still run for present organizations; verified the fix only moves the guard above them). 5-minute dedupe (lines 21–27) untouched.
- Conditional `event_params` merge (`if context.<param>.present?`) — absent params OMITTED from the hash, so the dedupe's `.where(event_params)` semantics for `assigned_free_plan*` callers are unchanged (the Angle-3 trap from REVIEW-ANGLES is explicitly addressed).
- Check-first guard: fires only for conversion types with `stripe_subscription_id` present; queries by `stripe_subscription_id` alone — matches the single-column partial index per amended §3. Logged (`ap`) + `context.fail!` — graceful. Private predicate uses the house bare-`return` guard shape (organization.rb:1189–1196 confirmed as the cited exemplar).
- `RecordNotUnique` backstop: method-level rescue (the preferred house form per backend/_base.md §1); `context.fail!` raises `Interactor::Failure` (not a `RecordNotUnique`), so in-body `fail!` calls pass through unaffected — plan's parenthetical is correct.
- `stripe_subscription_in_good_standing` exists (organization.rb:678).
- Variable naming: `subscription_event`, `organization`, `subscription_event_type` — compliant.

## Findings

- LOW (note-only): Task 3.3 places the uniqueness guard "BEFORE the 5-minute dedupe" where SPEC §6 only requires "BEFORE build." Harmless strictness — for a row matching both guards, the conversion-duplicate message wins; no caller-visible behavior difference (both are graceful `context.fail!`). Deliberately left.
