# PLAN — SubscriptionEvent ledger + PostHog/Discord fan-out

**Feature:** subscription-events-ledger (SPEC.md in this directory, as amended by spec review — READY FOR PLANNING)
**Branch:** `attribution-work-qa` @ `a0d59115d` (main checkout per `REPO-PATH`). Commits LOCAL ONLY — never push (PR #3075 open; push/PR are Jessica's).
**Repo state verified at plan time:** `git log --oneline -5` head = `a0d59115d Capture Meta, LinkedIn, and Google Analytics identifiers at signup`; `git status` clean except ` M db/schema.rb` (the known unstaged dev-schema corruption — leave unstaged, never commit it); current branch `attribution-work-qa`.

**⚠️ DELICACY DIRECTIVE (D11):** `app/jobs/stripe_webhook_handler_job.rb` is PARTICULARLY DELICATE, load-bearing billing logic. This plan specifies EXACTLY the two sanctioned insertions from SPEC §5 — each additive, at the END of its branch, wrapped in its OWN `begin/rescue StandardError` — and NOTHING else in that file. Every planned line there is individually justified against the spec (justification tables inside Tasks 7 and 8). No branch reordering, no attribute-access changes, no cleanup, no comment edits beyond the insertions. Anything beyond the two insertions in that file is a BLOCKER.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

---

## Required reading before any task

Every implementing agent reads, in order: `SPEC.md` (this directory), `approved-decisions.md` (D1–D12 + RESOLVED — immutable), `~/claude-hub/inflow-ats/documentation/stripe-subscription-lifecycle-2026-07-24/stripe-webhook-handler.md` and `organization-plan-callbacks.md`, `<REPO>/cursor_rules/core_critical_rules.md`, `<REPO>/cursor_rules/backend/_base.md`, plus per-task: `backend/migrations.md` (Task 1), `backend/interactors/interactor_patterns_and_structure.md` (Task 3).

## Style rulings binding ALL planned code (D10 + house rules)

- Early returns ONLY as implicit-nil bail-outs: bare `return unless x` / `return unless x.present?` — never `return false`/`return nil` (core rule 8). Predicate methods use the house shape seen at `organization.rb:1159–1205`: bare-`return` guards, then a final boolean expression.
- Value selection via full `if/elsif/else` expression with `present?` tests and an explicit `nil` else where the spec says so. **NO `.presence`** (banned house form).
- Rule 10: no fabricated fallbacks (`|| 0`, `|| ''`) — the one sanctioned `.to_i` is the SPEC §4 predicate's `object.amount_paid.to_i > 0` (spec-verbatim) and `organization.subscription_canceled_at.to_i` INSIDE a `present?` guard (SPEC §7).
- `ap` not `pp`; single quotes unless interpolating; rescue specific classes with `=> e`, never empty rescue; no bang methods in `app/` (bang OK in `spec/`); check `save`/`update` return values; no `reload` in `app/` (OK in specs); record variables named for their model (`subscription_event`, `organization` — never `record`/`row`/`entry`).
- `begin/rescue` inside a method is permitted only for rescuing a specific nested subset (backend/_base §1) — exactly what SPEC §5 mandates for the two webhook insertions.

---

## STRUCTURAL MANIFEST (mandatory) — fan-out design vs `Organization#handle_after_commit_on_update` analog

Analog read live: `organization.rb:59` (registration), `1023–1029` (dispatcher), `1031–1156` (handlers), `1159–1221` (predicate helpers); `private` in that file begins at line 1709, so ALL analog handlers/helpers are public. Row-by-row diff:

| # | Dimension | Analog (Organization) | New (SubscriptionEvent) | Verdict | Justification for DIFFERENT/EXTRA |
|---|---|---|---|---|---|
| 1 | File placement | callback + handlers + helpers live on the model owning the state (`organization.rb`) | callback + handler + helpers on `subscription_event.rb` | SAME | — |
| 2 | Files NOT created | no service object, no dedicated fan-out job class | same — zero new app files besides the migration | SAME | matches SPEC §2 Created list (one migration only) |
| 3 | Registration | `after_commit :handle_after_commit_on_update, on: [:update]` (organization.rb:59) | `after_commit :handle_after_commit_on_create, on: :create` | DIFFERENT | SPEC §7 / D8 mandate `on: :create` — rows are immutable facts; there is no update lifecycle. Naming mirrors the analog (`handle_after_commit_on_<lifecycle>`) |
| 4 | Dispatcher shape | dispatcher calls 5 handler methods, one per changed-attribute dimension (1024–1028) | single handler keyed on `event_type` | DIFFERENT | SPEC §7: fan-out is "keyed on event_type" — one domain dimension, not five independent attribute dimensions; a 5-method dispatch has nothing to dispatch across |
| 5 | Guard shape | `return unless persisted?` + `return unless saved_changes.key?('…')` per handler | no `persisted?`/`saved_changes` guards; branch predicates are the enum's own `trial_started?` etc. | DIFFERENT | saved_changes/persisted? are UPDATE semantics (which attribute changed, is the record still there). On `on: :create` the record is by definition newly persisted and `event_type` is validated present; the spec keys the fan-out on event_type. The task directive names this exact row ("saved_changes vs on-create semantics") |
| 6 | Branch keying | exact-transition predicate helpers (`subscription_started_trial_after_commit?`, 1189–1196) feeding non-exclusive sequential `if`s | Rails enum predicates (`trial_started?`, `trial_converted_to_paid?`, …) feeding an exclusive `if/elsif` chain | SAME in kind (predicate-per-branch), DIFFERENT in exclusivity | analog branches are non-exclusive by design (one commit can hit several); event_type values are mutually exclusive by construction — `if/elsif` states that; D10 favors if/elsif chains |
| 7 | Logging | `ap` context lines at handler entry (1110–1112, 1129, 1137) | one `ap` line at handler entry naming the event_type | SAME | — |
| 8 | Enqueue style | `Job.perform_later(id, …)` positional args, enqueued directly from the handler | `Discord::*Job.perform_later(organization_id)`, `PosthogTrackJob.perform_later(organization.owner.id, event_type, properties)` | SAME | same `perform_later` positional style; PostHog call shape matches the `billing_controller.rb:115/213/311` analog |
| 9 | Discord job classes + arities | `Discord::NotifyFreeTrialStartedJob(id)` (1131), `Discord::NotifyTrialConvertedToPaidJob(id)` (1139), `Discord::NotifySubscriptionDeletedJob(organization_id, ended_at)` (paid_subscription_deleted_job.rb:22) | identical classes and arities | SAME (classes/arities) / DIFFERENT (deleted-job `ended_at` source: `organization.subscription_canceled_at.to_i` behind a `present?` guard, vs the webhook-local `subscription_ended_at`) | SPEC §7 mandates the source and the skip-when-absent guard (amended §7 — never `nil.to_i` into a 1970 timestamp) |
| 10 | Rescue shape | analog after_commit handlers carry NO rescue (only `handle_before_update` has one, 1019) | no rescue added in the fan-out handler | SAME | matches analog; writer sites carry the rescue isolation instead (SPEC §5) |
| 11 | Method visibility | analog handlers + helpers PUBLIC (file's `private` starts at 1709) | handler + helpers `private` | DIFFERENT | SPEC §7 SPEC-PROPOSED: "private methods on SubscriptionEvent"; adopted for the whole fan-out set — nothing external calls them |
| 12 | Payload builders | none — analog handlers pass only ids | `posthog_properties` + `attribution_value` helpers | EXTRA | SPEC §7 defines the PostHog payload; the analog has no PostHog consumer. Shapes are spec-mandated (D9/D10) |
| 13 | Columns read | analog reads `saved_changes` + own attributes | new code reads own row attributes + `organization` (stripe_customer_id, subscription_canceled_at, 13 attribution cols) + `owner` (13 attribution cols) — DB-local only, zero Stripe calls | DIFFERENT | SPEC §7: properties built "from DB-local data only (the row + organization + owner; no Stripe calls)" |
| 14 | Record lifecycle | analog fires on org update; creates no records | fires on SubscriptionEvent create; creates no records, only enqueues | SAME (side-effects are enqueues only) | — |

Interactor manifest note (extended, not replaced — SPEC §1.4): `CreateSubscriptionEvent` keeps its file, class name, `include Interactor`, `context.*` param passing, 5-minute same-`event_params` dedupe, `build`/`save`-with-return-check, and `context.fail!(message:)` conventions byte-for-byte in shape; the additions are two conditional `event_params` merges, one check-first guard + private predicate, one guard-order fix, and one method-level `rescue ActiveRecord::RecordNotUnique`. Migration manifest: analog `20260723222212_add_adroll_click_id_to_users.rb` (bare `add_column` in `def change`) plus the house partial-unique-index shape from `20260408040501_create_organization_ai_credit_purchases.rb:25–29` (`add_index …, unique: true, where: '…', name: '…'`).

---

## Tasks

### Task 0 — Preflight (no code)

- [x] 0.1 `cd /Users/jessica/wrk/wrk-corp/inflow-ats && git log --oneline -5 && git status --short && git branch --show-current` — confirm `attribution-work-qa`, head `a0d59115d` (or a descendant created by an earlier task of THIS feature), and that the only unstaged change is `db/schema.rb` (corruption — leave it alone).
- [x] 0.2 Confirm line anchors still match before editing (they were verified at plan time): `organization.rb` trial branch 1128–1134 with Discord line at 1131, converted branch 1136–1140 with Discord line at 1139; webhook `invoice.paid` else-branch ends at 297 (`organization.organization_ai_credit_balance&.reset_ai_credits`), `subscription.deleted` else-branch ends at 210 (`EngagementReport::GeneratorJob…`); `paid_subscription_deleted_job.rb` `discord(…)` call at 13, private `discord` method at 21–23. If any anchor moved, STOP and re-locate by content, not by guessing.

### Task 1 — Migration (SPEC §3)

Analog: `db/migrate/20260723222212_add_adroll_click_id_to_users.rb`; partial-unique-index syntax from `db/migrate/20260408040501_create_organization_ai_credit_purchases.rb:25–29`.

- [x] 1.1 Create `db/migrate/<current UTC timestamp>_add_stripe_subscription_id_and_amount_to_subscription_events.rb`:

```ruby
# frozen_string_literal: true

class AddStripeSubscriptionIdAndAmountToSubscriptionEvents < ActiveRecord::Migration[6.1]
  def change
    add_column :subscription_events, :stripe_subscription_id, :string
    add_column :subscription_events, :amount, :integer

    # At most one conversion-type row per stripe_subscription_id.
    # event_type 2 = converted_to_paid, 8 = trial_converted_to_paid (SubscriptionEvent enum).
    add_index :subscription_events,
              :stripe_subscription_id,
              unique: true,
              where: 'event_type IN (2, 8)',
              name: 'idx_subscription_events_conversion_stripe_sub_id'
  end
end
```

  Both columns nullable, no defaults, no backfill, no currency column (SPEC §3). Single-column index on `stripe_subscription_id`, partial on `event_type IN (2, 8)` — the amended-§3 invariant verbatim. Postgres treats NULL `stripe_subscription_id` values as distinct, so conversion rows without a subscription id (console-created) never collide — consistent with the §6 guard, which only fires when `stripe_subscription_id` is present. Index name is 48 chars (< 63 limit).
- [x] 1.2 `bundle exec rails db:migrate` (dev DB) and `RAILS_ENV=test bundle exec rails db:migrate` (test DB). Both are on the sanctioned-safe list. NEVER `db:reset`/`db:setup`/`db:schema:load`/`db:test:prepare`; never set `DATABASE_URL`.
- [x] 1.3 Verify `git diff db/schema.rb` now contains, IN ADDITION to the pre-existing corruption hunks, exactly: the version bump on the `ActiveRecord::Schema.define` line, and in `create_table "subscription_events"` the two new columns + the new partial unique index. Do NOT stage anything yet (staging happens in Task 11).

### Task 2 — `SubscriptionEvent` model: enum + comment fix + constant (SPEC §2, §3; D2, D3)

- [x] 2.1 In `app/models/subscription_event.rb`, replace the stale comment block (current lines 4–11: duplicate "1:" labels, numbering off by one) and extend the enum. Target state for the top of the class:

```ruby
class SubscriptionEvent < ApplicationRecord
  belongs_to :organization

  CONVERSION_EVENT_TYPES = %w[converted_to_paid trial_converted_to_paid].freeze

  # MAIN subscription events only. AI-credit subscription events live in
  # OrganizationAiCreditPurchase / AiCreditBalanceTransaction.
  #
  # Event types stored as integers (Rails enum):
  # 0: assigned_free_plan_on_creation - Free plan assigned during org creation
  # 1: assigned_free_plan - Free plan assigned later (from nil/old-free/canceled)
  # 2: converted_to_paid - Non-trial conversion (free -> paid and canceled -> paid), created at invoice.paid with amount
  # 3: canceled_subscription - Subscription canceled (webhook subscription.deleted)
  # 4: downgraded_to_free - Paid -> Free (no writer yet)
  # 5: upgraded_plan - Paid -> higher paid plan (no writer yet)
  # 6: downgraded_plan - Paid -> lower paid plan (no writer yet)
  # 7: trial_started - Trial began (nil -> 'trialing' status transition)
  # 8: trial_converted_to_paid - Trial -> paid conversion, created at invoice.paid with amount
  enum event_type: {
    assigned_free_plan_on_creation: 0,
    assigned_free_plan: 1,
    converted_to_paid: 2,
    canceled_subscription: 3,
    downgraded_to_free: 4,
    upgraded_plan: 5,
    downgraded_plan: 6,
    trial_started: 7,
    trial_converted_to_paid: 8
  }

  validates :event_type, presence: true
```

  Values 0–6 keep their names and numbers byte-identical (0/1 are live production rows — D3). The comment block satisfies both the §2 "stale comment fix" and the §3 D2 main-plan-only comment. `CONVERSION_EVENT_TYPES` is the single Ruby home of the 2/8 pairing, consumed by the Task 3 guard (the migration's `IN (2, 8)` SQL hardcodes the ints with a comment naming them — schema DDL does not reference model code).

### Task 3 — `CreateSubscriptionEvent` changes (SPEC §6)

Extended, not replaced. Four changes, everything else byte-identical (existing dedupe, build/save, fail messages, `ap` lines).

- [x] 3.1 **Guard-order fix:** move `return unless organization` (currently line 13) ABOVE the two `ap` logging lines (currently 11–12: `ap 'Stripe subscription in good standing?'` / `ap organization.stripe_subscription_in_good_standing`). A nil organization currently raises NoMethodError on line 12 before the bail-out; after the fix the interactor no-ops gracefully for any caller. The only existing production caller (`log_assigned_free_plan_event`, organization.rb:1237) always passes `organization: self` — behavior unchanged for it.
- [x] 3.2 **Optional context params:** after building `event_params`, merge the new keys ONLY when present (absent params must be OMITTED from the hash — merging nils would enter the existing dedupe's `.where(event_params)` and change match semantics for `assigned_free_plan*` callers):

```ruby
    event_params[:stripe_subscription_id] = context.stripe_subscription_id if context.stripe_subscription_id.present?
    event_params[:amount] = context.amount if context.amount.present?
```

- [x] 3.3 **Conversion-type uniqueness guard, check-first, BEFORE the 5-minute dedupe and BEFORE build:**

```ruby
    if conversion_duplicate_exists?
      ap "Conversion SubscriptionEvent already exists for stripe_subscription_id #{context.stripe_subscription_id}"
      context.fail!(message: "Conversion SubscriptionEvent already exists for stripe_subscription_id #{context.stripe_subscription_id}")
    end
```

  with the private predicate (house guard shape — bare `return` bail-outs then boolean expression, matching `organization.rb:1189–1196`):

```ruby
  private

  def conversion_duplicate_exists?
    return unless SubscriptionEvent::CONVERSION_EVENT_TYPES.include?(context.event_type.to_s)
    return unless context.stripe_subscription_id.present?

    SubscriptionEvent.where(event_type: SubscriptionEvent::CONVERSION_EVENT_TYPES)
                     .where(stripe_subscription_id: context.stripe_subscription_id)
                     .exists?
  end
```

  The query is by `stripe_subscription_id` alone — NOT scoped to organization — matching the single-column partial index (amended §3: "the §6 interactor guard queries by stripe_subscription_id alone to match"). The duplicate is logged (`ap`) then `context.fail!` — graceful, never raised to callers using `.call`.
- [x] 3.4 **`RecordNotUnique` backstop** (raced concurrent delivery slips past check-first; the DB index raises at `save`) — method-level rescue on `call`, after the existing `if subscription_event.save … end` block:

```ruby
  rescue ActiveRecord::RecordNotUnique => e
    Rails.logger.error "CreateSubscriptionEvent raced conversion uniqueness index for stripe_subscription_id #{context.stripe_subscription_id}: #{e.message}"
    ap e
    context.fail!(message: "Conversion SubscriptionEvent already exists for stripe_subscription_id #{context.stripe_subscription_id}")
  end
```

  (`context.fail!` raises `Interactor::Failure`, which is NOT an `ActiveRecord::RecordNotUnique`, so the in-body `fail!` calls are unaffected by this rescue.)
- [x] 3.5 Confirm untouched: the 5-minute dedupe block, the `build`, the save-return check, both existing `context.fail!` messages, `context.subscription_event` assignment, and all existing `ap` text.

### Task 4 — Fan-out + PostHog payload on `SubscriptionEvent` (SPEC §7; D8, D9, D10)

Added to `app/models/subscription_event.rb` below `validates` (build on Task 2's file state). Analog: `Organization#handle_after_commit_on_update` handler style per the structural manifest above; PostHog call shape per `billing_controller.rb:115/213/311` → `PosthogTrackJob` → `Posthog::Track`.

- [x] 4.1 Register the callback and add the handler + helpers, ALL private (manifest row 11):

```ruby
  after_commit :handle_after_commit_on_create, on: :create

  private

  def handle_after_commit_on_create
    ap "SubscriptionEvent Created (After Commit): #{event_type}"

    if trial_started?
      enqueue_posthog_track
      Discord::NotifyFreeTrialStartedJob.perform_later(organization_id)
    elsif trial_converted_to_paid?
      enqueue_posthog_track
      Discord::NotifyTrialConvertedToPaidJob.perform_later(organization_id)
    elsif converted_to_paid?
      enqueue_posthog_track
    elsif canceled_subscription?
      enqueue_posthog_track
      if organization.subscription_canceled_at.present?
        Discord::NotifySubscriptionDeletedJob.perform_later(organization_id, organization.subscription_canceled_at.to_i)
      end
    end
  end

  def enqueue_posthog_track
    return unless organization&.owner

    PosthogTrackJob.perform_later(organization.owner.id, event_type, posthog_properties)
  end

  def posthog_properties
    owner = organization.owner
    {
      amount: amount,
      stripe_subscription_id: stripe_subscription_id,
      stripe_customer_id: organization.stripe_customer_id,
      to_plan: to_plan,
      utm_source: attribution_value(owner.utm_source, organization.utm_source),
      utm_campaign: attribution_value(owner.utm_campaign, organization.utm_campaign),
      utm_data: attribution_value(owner.utm_data, organization.utm_data),
      internal_ref: attribution_value(owner.internal_ref, organization.internal_ref),
      google_click_id: attribution_value(owner.google_click_id, organization.google_click_id),
      adroll_click_id: attribution_value(owner.adroll_click_id, organization.adroll_click_id),
      adroll_first_party_cookie: attribution_value(owner.adroll_first_party_cookie, organization.adroll_first_party_cookie),
      fbclid: attribution_value(owner.fbclid, organization.fbclid),
      fbp: attribution_value(owner.fbp, organization.fbp),
      fbc: attribution_value(owner.fbc, organization.fbc),
      li_fat_id: attribution_value(owner.li_fat_id, organization.li_fat_id),
      ga_client_id: attribution_value(owner.ga_client_id, organization.ga_client_id),
      ga_session_id: attribution_value(owner.ga_session_id, organization.ga_session_id)
    }.compact
  end

  def attribution_value(owner_value, organization_value)
    if owner_value.present?
      owner_value
    elsif organization_value.present?
      organization_value
    else
      nil
    end
  end
```

  Spec-mandated properties of this code, verified against live source:
  - Per-type table exactly per §7: `assigned_free_plan*` rows fall through the `if/elsif` chain and enqueue NOTHING (behavior unchanged); `converted_to_paid` has NO Discord job (none exists today; none added).
  - `Discord::NotifySubscriptionDeletedJob` (`ended_at` REQUIRED positional; runs `Time.at(ended_at)` — notify_subscription_deleted_job.rb:7,14) enqueued ONLY when `organization.subscription_canceled_at` is present; absent → Discord SKIPPED, PostHog still fires (amended §7 — never fabricate a 1970 timestamp). On the webhook path the column is written at stripe_webhook_handler_job.rb:208 before the row is created.
  - PostHog event name = enum name (`event_type` string). `return unless organization&.owner` bail-out per §7 (defensive — `belongs_to :owner` on Organization is required).
  - Properties DB-local ONLY (row + organization + owner; zero Stripe calls). `email`/`organization_id`/`organization_name`/`plan` NOT duplicated — they ride `Posthog::Track#default_properties` (track.rb:25–32); none of our keys (`amount`, `stripe_subscription_id`, `stripe_customer_id`, `to_plan`, 13 attribution keys) shadows a default (`default_properties.merge(@properties)` would let custom keys override on collision — there is no collision).
  - All 13 attribution columns exist on BOTH `users` (schema.rb:1300–1312) and `organizations` (`google_click_id` at schema.rb:1081; the other 12 at schema.rb:1092–1103) — verified at plan time. `attribution_value` is the D10 shape verbatim: full if/elsif/else, `present?` tests, explicit `nil` else, NO `.presence`. `.compact` drops every nil — absent fields are never sent; `amount` rides only on conversion rows (nil elsewhere → compacted away).
  - `billing_interval` deliberately ABSENT (RESOLVED-at-go flagged deviation) — do not add it.

### Task 5 — `app/models/organization.rb` branch edits (SPEC §5.1)

`cursor_rules` says "Do not automate edits to organization.rb" — the spec + harness profile sanction EXACTLY these two branch edits and nothing else in this file. Slack lines, `ap` lines, `organization_ai_credit_balance&.reset_ai_credits`, and every other handler stay byte-identical.

- [x] 5.1 `subscription_started_trial_after_commit?` branch (currently 1128–1134): add the `CreateSubscriptionEvent.call` writer on the line where the Discord enqueue was; REMOVE `Discord::NotifyFreeTrialStartedJob.perform_later(id)` (moves to fan-out). Target state:

```ruby
    if subscription_started_trial_after_commit?
      ap 'FREE TRIAL STARTED'
      Notification::FreeTrialStartedJob.perform_later(id)
      CreateSubscriptionEvent.call(organization: self, event_type: 'trial_started', to_plan: plan, stripe_subscription_id: stripe_subscription_id)

      organization_ai_credit_balance&.reset_ai_credits
    end
```

  The record-created-inside-a-callback → its own after_commit chain is explicitly accepted (D6). The exact `nil → 'trialing'` gate (organization.rb:1189–1196) plus the interactor's 5-minute dedupe guard this writer (the uniqueness index covers conversions only). `from_plan`/`amount` deliberately absent.
- [x] 5.2 `trial_converted_to_paid_after_commit?` branch (currently 1136–1140): REMOVE `Discord::NotifyTrialConvertedToPaidJob.perform_later(id)` ONLY. Target state:

```ruby
    if trial_converted_to_paid_after_commit?
      ap 'TRIAL CONVERTED TO PAID'
      Notification::TrialConvertedToPaidJob.perform_later(id)
    end
```

  This intentionally moves the trial-conversion Discord from trial expiry to actual payment (the fan-out fires it from the `invoice.paid`-written row) — the fix Jessica wanted. The Slack job stays (stated consequence: Slack fires at status flip, Discord at cash — accepted).
- [x] 5.3 Nothing else in organization.rb changes. `git diff app/models/organization.rb` must show exactly two hunks.

### Task 6 — `Notification::PaidSubscriptionDeletedJob` removal shape (SPEC §2, amended)

- [x] 6.1 In `app/jobs/notification/paid_subscription_deleted_job.rb`: remove the `discord(organization_id, ended_at)` call (line 13) AND the private `discord` method (lines 21–23). The `ended_at` param and the `@ended_at = ended_at` assignment (line 10) STAY — `blocks` line 34 uses `@ended_at` for the Slack timestamp. `slack`, `blocks`, `organization_fields`, `get_plan_display_name`, the rescue — all byte-identical. The Discord enqueue for cancellations now lives exclusively in the Task 4 fan-out.

### Task 7 — Webhook SANCTIONED INSERTION 1: `invoice.paid` main-plan branch (SPEC §5.2 + §4)

**⚠️ DELICACY DIRECTIVE (D11): `app/jobs/stripe_webhook_handler_job.rb` is particularly delicate, load-bearing billing logic. This task adds EXACTLY the block below at EXACTLY the stated position and touches NOTHING else in the file. No branch reordering, no attribute-access changes, no cleanup. Any other hunk in this file is a BLOCKER.**

- [x] 7.1 Append inside the `else` branch of `invoice.paid` (currently lines 288–298), immediately AFTER `organization.organization_ai_credit_balance&.reset_ai_credits` (line 297) and before that branch's `end` (line 298):

```ruby

          begin
            if object.amount_paid.to_i > 0
              subscription_event_type = if stripe_subscription.trial_end.present?
                                          'trial_converted_to_paid'
                                        else
                                          'converted_to_paid'
                                        end
              CreateSubscriptionEvent.call(
                organization: organization,
                event_type: subscription_event_type,
                to_plan: organization.plan,
                stripe_subscription_id: object.subscription,
                amount: object.amount_paid
              )
            end
          rescue StandardError => e
            Rails.logger.error "Stripe invoice.paid SubscriptionEvent ledger error: org=#{organization&.id} invoice=#{object&.id} subscription=#{object&.subscription} msg=#{e.message}"
            ap e
          end
```

- [x] 7.2 Line-by-line justification (every line traces to the spec):

| Line(s) | Justification |
|---|---|
| `begin`/`rescue StandardError => e`/log/`ap e`/`end` | §5.2: own begin/rescue, log with context, never re-raise — the branch's three-tier rescue (299–309) must never see ledger failures; existing behavior has already completed above |
| `if object.amount_paid.to_i > 0` | §4 predicate verbatim — cash moved; $0 trial-creation invoices and 100%-off cycles record nothing (D5 accepted) |
| `subscription_event_type = if stripe_subscription.trial_end.present? … else … end` | §4: `trial_end` present → `trial_converted_to_paid`, absent → `converted_to_paid`; sourced from the `stripe_subscription` the branch ALREADY retrieved at line 283 (live at processing time) — never the event payload snapshot, never `status`, NO second retrieve. D10 full if/else value selection |
| `CreateSubscriptionEvent.call(…)` args | §5.2 verbatim: `organization:`, `event_type:` per §4, `to_plan: organization.plan`, `stripe_subscription_id: object.subscription`, `amount: object.amount_paid` (cents, raw). `from_plan` deliberately absent (SPEC-PROPOSED, rule 10). Duplicate delivery → interactor no-ops gracefully (§6 guard; index backstop) |

  Position notes: the insertion runs AFTER the `raise CustomStripeSubscriptionMissingError` guard (line 289), so nil `organization.stripe_subscription_id` never reaches it, and AFTER all existing branch behavior (org update, `stripe_update_default_payment_method`, `reset_ai_credits`). `.call` (non-bang) never raises `Interactor::Failure`; the begin/rescue is defense in depth per spec.
- [x] 7.3 Verify: `git diff app/jobs/stripe_webhook_handler_job.rb` shows this insertion as the only hunk so far in the file.

### Task 8 — Webhook SANCTIONED INSERTION 2: `subscription.deleted` main branch (SPEC §5.3)

**⚠️ DELICACY DIRECTIVE (D11): same terms as Task 7 — EXACTLY this block at EXACTLY this position, nothing else in `app/jobs/stripe_webhook_handler_job.rb`. Any other hunk is a BLOCKER.**

- [x] 8.1 Append inside the `else` branch of `customer.subscription.deleted` (currently lines 204–211), immediately AFTER `EngagementReport::GeneratorJob.perform_later(organization&.id, trigger: 'subscription_canceled')` (line 210) and before that branch's `end` (line 211):

```ruby

          begin
            if organization
              CreateSubscriptionEvent.call(
                organization: organization,
                event_type: 'canceled_subscription',
                to_plan: organization.plan,
                stripe_subscription_id: stripe_subscription_id
              )
            end
          rescue StandardError => e
            Rails.logger.error "Stripe subscription.deleted SubscriptionEvent ledger error: org=#{organization&.id} subscription=#{stripe_subscription_id} msg=#{e.message}"
            ap e
          end
```

- [x] 8.2 Line-by-line justification:

| Line(s) | Justification |
|---|---|
| `begin`/`rescue StandardError => e`/log/`ap e`/`end` | §5.3: own begin/rescue; the branch's single rescue (212–215) must never see ledger failures |
| `if organization` | amended §5.3 verbatim: `organization` can be nil here (`Organization.find_by` miss at line 174 — surrounding lines all use `organization&.`); an interactor call cannot be `&.`-guarded (`organization.plan` in the argument list would raise first). Nil organization → ledger write skipped entirely (nothing to record for). The Task 3.1 guard-order fix is the interactor-side backstop |
| `CreateSubscriptionEvent.call(…)` args | §5.3 verbatim: `event_type: 'canceled_subscription'`, `to_plan: organization.plan`, `stripe_subscription_id: stripe_subscription_id` (the local from line 173). No `amount` (no cash moves at deletion). No uniqueness-index coverage for this type (re-subscribed orgs cancel again; new subscription id each time); the 5-minute dedupe covers redelivery |

  Position notes: runs AFTER all existing branch behavior (`sync_with_stripe` on id match, `update_column(:subscription_canceled_at, …)` at 208 — which is what the fan-out's Discord guard reads — and both job enqueues at 209–210).
- [x] 8.3 Verify: `git diff app/jobs/stripe_webhook_handler_job.rb` now shows EXACTLY two hunks — the Task 7 and Task 8 insertions — and nothing else. This is the Layer-1 delicacy-audit invariant (§11.5).

### Task 9 — Tests (SPEC §9; predicate matrix REQUIRED)

Harness calibration: the §4 predicate coverage is REQUIRED (new business logic in the delicate file); other missing coverage is never HIGH/MED on its own, but ghost tests are BLOCKERs (pipeline rule 26 — every assertion must fail if the feature is deleted; no enum-reflection tautologies, no assigned-but-unasserted variables). Bang methods OK in specs. `reload` OK in specs. ALL new specs that traverse job-enqueuing paths use the queue-adapter `:test` around-block per pipeline rule 31 (`config/environments/test.rb` sets `:inline`; without the swap, real Discord/PostHog/Slack side effects fire inside examples). House around-block shape — copy `spec/models/job_criteria_lifecycle_spec.rb:8–13`:

```ruby
  around do |example|
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
    ActiveJob::Base.queue_adapter = original_adapter
  end
```

`after_commit` callbacks DO fire under the suite's transactional fixtures (Rails 6.1; `spec/rails_helper.rb:15` `use_transactional_fixtures = true` — Rails ≥5 runs commit callbacks in transactional tests; existing after_commit-driven specs in `spec/models/` rely on this). Org setup via `create_credit_test_organization` (`spec/support/ai_credits_test_helpers.rb:21` — there is no factories directory; the helper stubs `complete_setup_workers`).

- [x] 9.1 **NEW `spec/jobs/stripe_webhook_handler_subscription_events_spec.rb`** — the REQUIRED predicate matrix spec. Analog: `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` (constructed doubles — `double('metadata', :[] => nil)` with stubbed `keys`, `Stripe::Event.retrieve` stub, `described_class.perform_now('evt_…')`). **⚠️ D11: this task READS `stripe_webhook_handler_job.rb`; it must not touch it.** Setup per example group:
  - The `:test` adapter around-block (preamble shape) — REQUIRED here, unlike the analog spec: this spec asserts `Notification::PaidSubscriptionDeletedJob`/`EngagementReport::GeneratorJob` are ENQUEUED (impossible under `:inline`), and every example that creates a `SubscriptionEvent` row fires the Task 4 fan-out — under the suite's `:inline` default the Discord jobs and `Notification::PaidSubscriptionDeletedJob`'s real Slack webhook would execute inside examples (pipeline rule 31).
  - `organization` via `create_credit_test_organization` (stripe_active: true gives `stripe_customer_id`/`stripe_subscription_id`/status 'active').
  - Invoice double: `id`, `customer: organization.stripe_customer_id`, `subscription: organization.stripe_subscription_id`, `amount_paid` (per matrix), `metadata: double('metadata', :[] => nil)` with `keys` stubbed (all three metadata branches must miss). `log_stripe_changes` is guarded by `respond_to?(:previous_attributes)` (line 420) — doubles return false for unstubbed messages, so the analog's `double('data', object: …)` shape passes through safely.
  - Stub `Stripe::Subscription.retrieve` → subscription double with `items.data.first.price.lookup_key` returning a NON-credit lookup key (e.g. `'plan_ats_tier_starter_v2_monthly'`), `current_period_end` (epoch int), and `trial_end` per matrix (epoch int or nil).
  - Route the job to OUR org instance so its Stripe-touching methods can be stubbed: `allow(Organization).to receive(:find_by).and_call_original` then `allow(Organization).to receive(:find_by).with(stripe_customer_id: organization.stripe_customer_id).and_return(organization)`; `allow(organization).to receive(:stripe_update_default_payment_method)`.
  - Examples (each asserts on `SubscriptionEvent` rows — falsifiable by deleting the insertion):
    - [x] `amount_paid: 0`, `trial_end` present → NO row created.
    - [x] `amount_paid: 0`, `trial_end` nil → NO row created.
    - [x] `amount_paid` positive, `trial_end` present → exactly one `trial_converted_to_paid` row with `amount == amount_paid`, `stripe_subscription_id == invoice.subscription`, `to_plan == organization.plan`, `from_plan` nil.
    - [x] `amount_paid` positive, `trial_end` nil → exactly one `converted_to_paid` row (same field assertions).
    - [x] Duplicate delivery: `perform_now` TWICE with the positive/trial_end-present event → exactly one row (uniqueness guard), no error raised.
    - [x] Existing branch behavior still happens around the insertion (load-bearing): `organization.stripe_current_period_end_at` persisted to the stubbed `current_period_end`; `stripe_update_default_payment_method` received; `reset_ai_credits` reached (spy on `organization.organization_ai_credit_balance` or assert credit state via the helper's balance).
    - [x] Ledger failure isolation: `allow(CreateSubscriptionEvent).to receive(:call).and_raise(StandardError)` → `perform_now` does NOT raise AND the org update/payment-method/reset assertions above still hold.
    - [x] `customer.subscription.deleted` (event double with `object.id`, `object.customer`, `object.ended_at` epoch, `items.data.first.price.lookup_key` non-credit) → one `canceled_subscription` row with `stripe_subscription_id == object.id`, `to_plan == organization.plan`; AND existing behavior intact: `subscription_canceled_at` written, `Notification::PaidSubscriptionDeletedJob` + `EngagementReport::GeneratorJob` enqueued. (`sync_with_stripe` should be stubbed on the org instance — it makes Stripe calls.)
    - [x] `subscription.deleted` with no matching organization (`find_by` miss) → no raise, no row.
- [x] 9.2 **NEW `spec/interactors/create_subscription_event_spec.rb`** (`:test` adapter around-block, preamble shape — after Task 4, every `SubscriptionEvent` create in these examples, whether via the interactor or direct model setup, fires the fan-out; under `:inline` the Discord/PostHog jobs would execute inside examples — pipeline rule 31):
  - [x] Conversion duplicate (check-first): create a `converted_to_paid` row for `sub_x` directly via the model, then `CreateSubscriptionEvent.call(organization:, event_type: 'trial_converted_to_paid', stripe_subscription_id: 'sub_x', …)` → `result.failure?`, no raise, no second row. Also the cross-type direction (existing `trial_converted_to_paid` blocks a new `converted_to_paid`).
  - [x] `RecordNotUnique` backstop: create the duplicate row, stub the check-first (`allow_any_instance_of(CreateSubscriptionEvent).to receive(:conversion_duplicate_exists?).and_return(false)`) so `save` hits the index → `result.failure?`, no raise. (Falsifiable: delete the Task 3.4 rescue and this example fails with a raised `ActiveRecord::RecordNotUnique`.)
  - [x] New params persisted: call with `stripe_subscription_id:` + `amount:` → row has both; call without them → row has nil in both columns and the dedupe `event_params` did not include the keys (assert via a second identical no-new-params call within 5 minutes deduping exactly as today).
  - [x] Existing free-plan behavior + 5-minute dedupe untouched: `event_type: 'assigned_free_plan'` twice within 5 minutes → one row + failed second context (message unchanged).
  - [x] Guard-order fix: `CreateSubscriptionEvent.call(organization: nil, event_type: 'canceled_subscription')` → returns without raising (currently raises NoMethodError; falsifies if the fix is reverted).
- [x] 9.3 **NEW `spec/models/subscription_event_fanout_spec.rb`** (`:test` adapter around-block; `include ActiveJob::TestHelper`): create rows directly via `organization.subscription_events.create!(…)` and assert enqueues:
  - [x] `trial_started` → `have_enqueued_job(PosthogTrackJob).with(organization.owner.id, 'trial_started', anything)` AND `have_enqueued_job(Discord::NotifyFreeTrialStartedJob).with(organization.id)`.
  - [x] `trial_converted_to_paid` → PostHog + `Discord::NotifyTrialConvertedToPaidJob`.
  - [x] `converted_to_paid` → PostHog and NO Discord job of any class.
  - [x] `canceled_subscription` with `organization.subscription_canceled_at` present → PostHog + `Discord::NotifySubscriptionDeletedJob.with(organization.id, organization.subscription_canceled_at.to_i)`.
  - [x] `canceled_subscription` with nil `subscription_canceled_at` → PostHog enqueued, `Discord::NotifySubscriptionDeletedJob` NOT enqueued.
  - [x] `assigned_free_plan` and `assigned_free_plan_on_creation` rows → NOTHING enqueued.
  - [x] No owner → no PostHog: stub `allow_any_instance_of(Organization).to receive(:owner).and_return(nil)` (owner is a required belongs_to, so a real ownerless org can't be built), create a `trial_started` row → no `PosthogTrackJob` enqueued (Discord still enqueues — bail-out is PostHog-only per §7).
  - [x] PostHog properties hash (assert via `have_enqueued_job(PosthogTrackJob).with { |_id, _event, properties| … }`): owner-first fallback (owner.utm_source set + organization.utm_source set → owner's wins; owner nil / org set → org's; both nil → key ABSENT from the hash, not nil — `.compact` behavior); `amount` key present with the row's value on a conversion row and ABSENT on a `canceled_subscription` row; `stripe_customer_id`/`to_plan` present when set; `email`/`organization_id`/`organization_name`/`plan` NOT in the hash (they ride `Posthog::Track#default_properties`).
- [x] 9.4 **NEW `spec/models/organization_subscription_events_spec.rb`** (`:test` adapter around-block): org built with stripe ids but NO status (`create_credit_test_organization(stripe_active: false)` then assign `stripe_customer_id`/`stripe_subscription_id` without status, or build attrs directly per the helper's pattern):
  - [x] `organization.update(stripe_subscription_status: 'trialing')` (nil → 'trialing') → one `trial_started` SubscriptionEvent row with `to_plan == organization.plan` and `stripe_subscription_id == organization.stripe_subscription_id`; `Notification::FreeTrialStartedJob` enqueued; `Discord::NotifyFreeTrialStartedJob` enqueued EXACTLY ONCE (via fan-out only — twice would mean the organization.rb line was not removed).
  - [x] 'trialing' → 'active' transition → `Notification::TrialConvertedToPaidJob` enqueued; `Discord::NotifyTrialConvertedToPaidJob` NOT enqueued (no row is written at the status flip — the Discord now rides the invoice.paid-written row); NO SubscriptionEvent row created by this transition.
- [x] 9.5 **Untouched test surface:** `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` stays byte-identical and must still pass. No existing spec anywhere references `SubscriptionEvent`/`CreateSubscriptionEvent` (verified by grep at plan time) — no rename ripple. Cypress untouched.
- [x] 9.6 Run: `bundle exec rspec spec/jobs/stripe_webhook_handler_subscription_events_spec.rb spec/interactors/create_subscription_event_spec.rb spec/models/subscription_event_fanout_spec.rb spec/models/organization_subscription_events_spec.rb spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` — all green. Known pre-existing failure elsewhere: `spec/models/organization_ai_credits_lifecycle_spec.rb:33` (documented; not attributable to this feature unless the failure mode changes).

### Task 10 — Diff audit (pre-commit)

- [x] 10.1 `git status --short` + `git diff` full sweep. The complete diff must be exactly: 1 new migration; `db/schema.rb` (Task 11 will hunk-stage); `app/models/subscription_event.rb`; `app/interactors/create_subscription_event.rb`; `app/models/organization.rb` (two hunks); `app/jobs/notification/paid_subscription_deleted_job.rb` (removal shape only); `app/jobs/stripe_webhook_handler_job.rb` (EXACTLY two additive hunks — D11); 4 new spec files. Zero hunks in: Slack `Notification::*` jobs, `Discord::Notify*` job files, `sync_with_stripe`, any other webhook branch, any AI-credit path, serializers, policies, routes, frontend (SPEC §2 Untouched + §10).

### Task 11 — Schema hunk-staging + detached commit (LOCAL ONLY)

- [x] 11.1 **Schema commit rule (HARD, verbatim from SPEC §3):** "never stage `db/schema.rb` wholesale; hunk-stage exactly this migration's columns/index + version bump; the dev schema's unstaged corruption stays unstaged." Mechanism (non-interactive): `git diff db/schema.rb > <scratchpad>/schema.diff`; copy ONLY the diff header + the `ActiveRecord::Schema.define(version: …)` hunk + the `create_table "subscription_events"` hunk (two new columns + partial unique index line) into `<scratchpad>/schema-staged.patch`; `git apply --cached <scratchpad>/schema-staged.patch`. Verify: `git diff --cached db/schema.rb` shows ONLY the version bump + subscription_events changes; `git diff db/schema.rb` still shows ONLY the pre-existing corruption hunks (channel_message_templates `subject`, channel_messages `subject`/`mailgun_message_id`, jobs `apply_response_template_subject`, organization_ai_credit_purchases `stripe_cancel_at_period_end` removal, textract_results block). If `git apply --cached` rejects (context drift), STOP and re-derive the patch — never fall back to `git add db/schema.rb`.
- [x] 11.2 Stage everything else normally (`git add` the migration, the 4 app files, the 4 spec files). Never stage `.env`, never stage the corruption.
- [x] 11.3 **Detached commit procedure:** pre-commit runs the full Cypress suite (~10–20 min). Commit nohup-detached, outside the sandbox, with `nvm use` — never under a killable timeout, never `--no-verify`, never rewrite tests to pass: `nohup bash -c 'cd /Users/jessica/wrk/wrk-corp/inflow-ats && source ~/.nvm/nvm.sh && nvm use && git commit -m "<message>"' > <scratchpad>/commit.log 2>&1 &` then poll `git log`/`commit.log`. Allow ≥20 minutes; if the process is killed, retry immediately; wait only if another tree's commit is live. Suggested message: `Turn subscription_events into a main-plan domain-event ledger with PostHog/Discord fan-out` + the `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` trailer.
- [x] 11.4 **LOCAL ONLY — never push.** PR #3075 is open; push/PR are Jessica's.

---

## Estimated scope

- App code: 5 modified files + 1 new migration. `stripe_webhook_handler_job.rb` +20/+13 lines (two insertions, nothing else); `subscription_event.rb` ~+75 (enum +2 values, comment block, constant, fan-out + 3 helpers); `create_subscription_event.rb` ~+25/−2; `organization.rb` +1/−2 across two hunks; `paid_subscription_deleted_job.rb` −4; migration ~15 lines.
- Tests: 4 new spec files, ~500–700 lines total. Zero frontend, zero Cypress, zero serializer/policy/route changes.

## Risks

1. **§11.6 rollout misclassification ships as specified** (open question is Jessica's; plan implements the spec AS WRITTEN — no backfill, no cutoff, no `billing_reason`): every pre-existing paying subscription's first post-deploy `invoice.paid` records a false conversion row + PostHog event, and a false Discord trial-converted ping where `trial_end` is present.
2. **Predicate vs. real payloads:** matrix specs + QA Layer 3 exercise constructed real-shape events; true validation is production observation (Jessica-owned residual risk, SPEC §11.1).
3. **Discord-after-ledger coupling:** a failed/deduped interactor call now also skips the Discord ping — the pattern working as designed (spec-review LOW, accepted).
4. **Migration on live table:** additive nullable columns + partial index on a tiny table (free-plan-assignment rows only) — negligible lock risk.
5. **`event_type IN (2, 8)` hardcodes enum ints in SQL** — mitigated by the migration comment naming the enum keys and `CONVERSION_EVENT_TYPES` being the single Ruby-side home of the pairing.
6. **after_commit-in-specs dependency:** fan-out specs rely on Rails ≥5 firing commit callbacks under transactional fixtures — verified against this app's existing after_commit-driven model specs; if a fan-out spec sees no enqueues, suspect adapter/around-block wiring before suspecting the feature.

## Flagged items (no open questions of my own)

- None unresolvable. The one standing open question (§11.6) belongs to Jessica per SPEC-REVIEW-COMPLETE and is planned AS WRITTEN (Risk 1 above). All SPEC-PROPOSED mechanics were resolved in this plan: index name `idx_subscription_events_conversion_stripe_sub_id`; `event_params` conditional merge; check-first guard as a stubbable private predicate `conversion_duplicate_exists?` querying by `stripe_subscription_id` alone; fan-out handler named `handle_after_commit_on_create`, private, keyed via enum predicates in an if/elsif chain; helpers `enqueue_posthog_track`/`posthog_properties`/`attribution_value` private on the model.
