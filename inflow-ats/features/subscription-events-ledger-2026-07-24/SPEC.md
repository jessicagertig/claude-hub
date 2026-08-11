# SPEC — SubscriptionEvent ledger + PostHog/Discord fan-out (domain-events practice round)

**Working branch:** `attribution-work-qa` @ `a0d59115d` (main checkout, see `REPO-PATH`). Commits stay LOCAL — never push; PR #3075 is open and push/PR are Jessica's.
**Binding design source:** `approved-decisions.md` in this directory (D1–D12 + the RESOLVED-at-go block). Every mechanism below comes from those rulings; SPEC-PROPOSED marks mechanical details left to review/planning.
**Reference maps (required reading for every agent):** `~/claude-hub/inflow-ats/documentation/stripe-subscription-lifecycle-2026-07-24/stripe-webhook-handler.md` and `organization-plan-callbacks.md`.
**DELICACY (D11):** `app/jobs/stripe_webhook_handler_job.rb` is particularly delicate, load-bearing billing logic. Minimum changes. Additions, changes, and removals touching if/else statements are each individually justified. The ONLY changes permitted in that file are the two insertion points in §5. No branch reordering, no attribute-access changes, no cleanup.

---

## 1. Summary

Turn the dormant `subscription_events` table into a real (main-plan-only) domain-event ledger and hang the non-load-bearing consumers off it — PostHog capture and three Discord jobs — as the practice run for the pattern. Conversion means cash: conversion rows are created once, at `invoice.paid`, born complete with the amount. Backend only; zero UI surface.

1. **Migration:** `subscription_events` gains `stripe_subscription_id` (string, nullable) and `amount` (integer, cents, nullable), plus a uniqueness guarantee: **at most one conversion-type row per `stripe_subscription_id`** (partial unique index; mechanics plan-level).
2. **Enum:** add `trial_started: 7` and `trial_converted_to_paid: 8`; `converted_to_paid: 2` stays and now means NON-trial conversion — free→paid and canceled→paid are the same event (Jessica's ruling); trial→paid is not. Values 0/1 untouched (live production rows). Fix the stale comment block above the enum (it mislabels the numbering). `canceled_subscription: 3` gets a writer (§5.3). Deferred with no writers: `downgraded_to_free: 4`, `upgraded_plan: 5`, `downgraded_plan: 6` (D12: determinable, deliberately deferred — the point is testing the pattern).
3. **Writers (three sites, §5):** `trial_started` in the Organization `nil → 'trialing'` callback branch; `trial_converted_to_paid` / `converted_to_paid` at the end of the webhook's `invoice.paid` main-plan branch; `canceled_subscription` at the end of the webhook's `subscription.deleted` main branch.
4. **`CreateSubscriptionEvent` extended** (not replaced): optional `stripe_subscription_id:` and `amount:` context params; conversion-type uniqueness guard (check-first; duplicate = graceful no-op `context.fail`, logged, never raised); a nil-organization guard-order fix (§6); existing 5-minute dedupe and behavior for the free-plan types unchanged.
5. **Fan-out:** `after_commit on: :create` on `SubscriptionEvent`, keyed on `event_type` (§7): PostHog capture for all four written types; Discord jobs move to it (`NotifyFreeTrialStartedJob`, `NotifyTrialConvertedToPaidJob` from the Organization callback; `NotifySubscriptionDeletedJob`'s enqueue moves out of `Notification::PaidSubscriptionDeletedJob:22` — removal shape in §2). **All Slack `Notification::*` jobs stay exactly where they are** — stated consequence: Slack's trial-converted still fires at the status flip while Discord now fires at cash; accepted, this round practices on non-load-bearing consumers only.
6. **PostHog payload (§7):** owner as distinct_id via the existing `Posthog::Track` path; event properties only (no groups, no `$set`); attribution fields owner-first via the `attribution_value` helper (Jessica's if/elsif/else shape), `.compact`ed.

## 2. Stack scope

- **Modified:** `app/models/subscription_event.rb`; `app/interactors/create_subscription_event.rb`; `app/jobs/stripe_webhook_handler_job.rb` (two sanctioned insertions ONLY); `app/models/organization.rb` (one branch: add writer call, remove one Discord line; a second branch: remove one Discord line); `app/jobs/notification/paid_subscription_deleted_job.rb` (remove the Discord enqueue — removal shape: the `discord(organization_id, ended_at)` call at line 13 AND the private `discord` method at lines 21–23, line 22 being its body; the `ended_at` param and `@ended_at` assignment STAY — `blocks` line 34 uses `@ended_at` for the Slack timestamp; `slack` and everything else byte-identical).
- **Created:** one migration.
- **Untouched (explicit):** all Slack `Notification::*` jobs and their call sites; `Discord::Notify*` job FILES (only their enqueue sites move); `sync_with_stripe`; every other webhook branch; all AI-credit code paths; serializers, policies, routes, frontend — nothing.

## 3. Data model

Migration (analog shape: `20260723222212_add_adroll_click_id_to_users.rb` plus an `add_index`):
- `add_column :subscription_events, :stripe_subscription_id, :string`
- `add_column :subscription_events, :amount, :integer` (cents, from `invoice.amount_paid`)
- Partial unique index enforcing ≤1 row per `stripe_subscription_id` where `event_type` is a conversion type (2 or 8). The index is SINGLE-COLUMN on `stripe_subscription_id` (partial: `event_type IN (2, 8)`), and the §6 interactor guard queries by `stripe_subscription_id` alone to match. This is strictly tighter than D7's "organization + stripe_subscription_id" wording — Stripe subscription ids are globally unique, so per-`stripe_subscription_id` uniqueness implies per-organization uniqueness; the D7 invariant is satisfied a fortiori. SPEC-PROPOSED mechanics (index name, migration syntax); the INVARIANT is binding.
- Both columns nullable, no defaults (existing `assigned_free_plan*` rows have neither). No currency column (single-currency today; `invoice.currency` available if ever wanted). No backfill.

**Main-plan-only (D2):** a comment on the model states the table records MAIN subscription events only; AI-credit subscription events live in `OrganizationAiCreditPurchase` / `AiCreditBalanceTransaction`. Enforcement is structural — writers exist only in main-plan-guarded code paths.

**Schema commit rule (HARD):** never stage `db/schema.rb` wholesale; hunk-stage exactly this migration's columns/index + version bump; the dev schema's unstaged corruption stays unstaged.

## 4. Conversion predicate (D5 — the new business logic)

Evaluated ONLY inside the `invoice.paid` main-plan branch (after `raise CustomStripeSubscriptionMissingError`, so orgs with nil `stripe_subscription_id` never reach it — consistent with existing behavior):

- `object.amount_paid.to_i > 0` — cash moved. (The $0 trial-creation invoice and 100%-off cycles fail this; per Jessica's "cash = converted," a fully-comped first cycle records no conversion until real money moves — accepted.)
- `stripe_subscription.trial_end.present?` → `trial_converted_to_paid`; absent → `converted_to_paid`. Uses the subscription object the branch ALREADY retrieves (`Stripe::Subscription.retrieve(object.subscription)`, live at processing time) — never the event payload's embedded snapshot, never any `status` field (Jessica: the paid event may or may not reflect the status change; `trial_end` is written at subscription creation, so no ordering window exists).
- First-cash semantics via the §3 uniqueness invariant — renewals and past_due recoveries classify correctly by construction (an already-converted subscription's later paid invoices are duplicates; a first-ever cash recovery IS the conversion, late). This holds only for subscriptions whose ledger history starts before their first cash — pre-existing already-converted subscriptions have no row and misclassify on their first post-deploy paid invoice (Risk §11.6, OPEN QUESTION for Jessica).
- Reactivations: a canceled customer's new checkout gets no trial (`eligible_for_free_trial?` fails on non-blank status / lifetime spend), so canceled→paid lands as `converted_to_paid` with no extra logic.

## 5. Writers

### 5.1 `trial_started` — `app/models/organization.rb`, the `subscription_started_trial_after_commit?` branch (currently lines 1128–1134)
Inside the existing `if`: add `CreateSubscriptionEvent.call(organization: self, event_type: 'trial_started', to_plan: plan, stripe_subscription_id: stripe_subscription_id)`; REMOVE the `Discord::NotifyFreeTrialStartedJob.perform_later(id)` line (moves to fan-out). `Notification::FreeTrialStartedJob` (Slack) and `organization_ai_credit_balance&.reset_ai_credits` stay byte-identical. The record-created-inside-a-callback → its own after_commit chain is explicitly accepted (D6). The exact `nil → 'trialing'` gate plus the interactor's 5-minute dedupe guard this writer (the uniqueness index covers conversions only).

Also in this file, the `trial_converted_to_paid_after_commit?` branch (1136–1140): REMOVE the `Discord::NotifyTrialConvertedToPaidJob.perform_later(id)` line only. The Slack line stays. **This intentionally moves the trial-conversion Discord from trial expiry to actual payment — the fix Jessica wanted.** Nothing else in `organization.rb` changes.

### 5.2 Conversions — `app/jobs/stripe_webhook_handler_job.rb`, `invoice.paid` main-plan branch (SANCTIONED INSERTION 1)
Appended at the END of the existing else-branch body (after `organization_ai_credit_balance&.reset_ai_credits`), wrapped in its OWN `begin/rescue StandardError` (log with context; never let ledger failure reach the branch's existing rescue tiers or alter existing behavior, which has already completed):
apply §4; on match, `CreateSubscriptionEvent.call(organization: organization, event_type: <per §4>, to_plan: organization.plan, stripe_subscription_id: object.subscription, amount: object.amount_paid)`. `from_plan` left nil for webhook writers (SPEC-PROPOSED: not fabricating history the moment doesn't carry — rule 10). Duplicate → interactor no-ops gracefully. NO other lines in this file's branch change; no reordering; house-safe attribute access only.

### 5.3 `canceled_subscription` — `subscription.deleted` main branch (SANCTIONED INSERTION 2)
Appended at the END of the existing else-branch body (after the `EngagementReport::GeneratorJob` line), own `begin/rescue`: `CreateSubscriptionEvent.call(organization: organization, event_type: 'canceled_subscription', to_plan: organization.plan, stripe_subscription_id: stripe_subscription_id)`. **Nil-organization handling:** `organization` can be nil here (`Organization.find_by` miss at line 174 — the surrounding lines all use `organization&.`), and an interactor call cannot be `&.`-guarded (`organization.plan` in the argument list would raise first). The call runs only when `organization` is present — a plain `if organization` conditional inside the rescue-wrapped block; a nil organization skips the ledger write entirely (there is no organization to record for). Backstop: the §6 guard-order fix makes the interactor no-op gracefully on a nil organization for any caller. No uniqueness index coverage (a re-subscribed org can cancel again — new subscription id per cancellation anyway); 5-minute dedupe suffices for redelivery.

## 6. `CreateSubscriptionEvent` changes

- Accept optional `context.stripe_subscription_id` and `context.amount`; merge into `event_params` when present (absent → nil columns, existing callers unchanged).
- Conversion-type uniqueness guard BEFORE build: when `event_type` is a conversion type and `stripe_subscription_id` present, `context.fail!` gracefully if any conversion-type row already exists for that `stripe_subscription_id` (check-first; the DB index is the backstop — a raced `RecordNotUnique` is rescued and treated as the same graceful no-op). Style per D10: bail-outs as `return unless x.present?` guards; selection as if/elsif/else.
- Existing 5-minute same-params dedupe and all `assigned_free_plan*` behavior unchanged.
- Guard-order fix: the `ap organization.stripe_subscription_in_good_standing` logging (create_subscription_event.rb:11–12) currently executes BEFORE the `return unless organization` guard (line 13) — a nil organization raises NoMethodError before the graceful bail-out. Move the `return unless organization` guard above the two `ap` logging lines. The only existing production caller (`log_assigned_free_plan_event`, organization.rb:1237) always passes `organization: self`, so existing behavior is unchanged.

## 7. Fan-out + PostHog payload

`after_commit on: :create` on `SubscriptionEvent` (analog: `Organization#handle_after_commit_on_update`'s handler style). Keyed on `event_type` (if/elsif/else or case — plan-level):

| event_type | PostHog event (name = enum name) | Discord |
|---|---|---|
| `trial_started` | `trial_started` | `Discord::NotifyFreeTrialStartedJob.perform_later(organization_id)` |
| `trial_converted_to_paid` | `trial_converted_to_paid` | `Discord::NotifyTrialConvertedToPaidJob.perform_later(organization_id)` |
| `converted_to_paid` | `converted_to_paid` | none (none exists today; none added) |
| `canceled_subscription` | `canceled_subscription` | `Discord::NotifySubscriptionDeletedJob.perform_later(organization_id, organization.subscription_canceled_at.to_i)` — enqueued ONLY when `organization.subscription_canceled_at` is present; when absent (console-created row, §11.3), the Discord enqueue is SKIPPED (PostHog still fires). The job's `ended_at` is a required positional arg and runs `Time.at(ended_at)` (notify_subscription_deleted_job.rb:7,14): `nil.to_i` would fabricate a 1970 timestamp (rule 10), raw nil would raise inside the job. On the webhook path the column is written (line 208) before the row is created |
| `assigned_free_plan*` | none — behavior unchanged | none |

PostHog: `PosthogTrackJob.perform_later(organization.owner.id, <event name>, properties)` — bail out (`return unless organization&.owner`) when no owner. Properties built at enqueue time from DB-local data only (the row + organization + owner; no Stripe calls):
- `amount` (when present on the row — `.compact` drops it otherwise), `stripe_subscription_id`, `stripe_customer_id` (from organization), `to_plan` (row).
- `email` / `organization_id` / `organization_name` / `plan` already ride `Posthog::Track#default_properties` — NOT duplicated.
- Attribution (13 fields): `utm_source`, `utm_campaign`, `utm_data`, `internal_ref`, `google_click_id`, `adroll_click_id`, `adroll_first_party_cookie`, `fbclid`, `fbp`, `fbc`, `li_fat_id`, `ga_client_id`, `ga_session_id` — each via `attribution_value(owner.<col>, organization.<col>)`: full if/elsif/else, `present?` tests, explicit `nil` else (D10; NO `.presence`). Assembled hash `.compact`ed — absent fields are never sent (rule 10).
- `billing_interval` is deliberately OMITTED this round (not DB-local at writer sites) — flagged deviation from Jessica's original property list, revisit via a lookup-key column if wanted.
- Helper placement SPEC-PROPOSED: private methods on `SubscriptionEvent` (the analog keeps callback helpers on the model).

## 8. Analogs (verified live)

| Pattern | Analog | Used for |
|---|---|---|
| after_commit fan-out keyed on domain condition | `Organization#handle_after_commit_on_update` → handlers (organization.rb:1023–1156) | §7 callback |
| Interactor create + dedupe | `CreateSubscriptionEvent` itself (extended, not replaced) | §6 |
| Add-column migration | `db/migrate/20260723222212_add_adroll_click_id_to_users.rb`; index shape from `subscription_events`' own creation migration | §3 |
| Server-side PostHog capture | `PosthogTrackJob` callers in `billing_controller.rb:115,213,311`; `Posthog::Track` service | §7 |
| Rescue-isolated additive block in a webhook branch | the three-tier rescue structure already in `invoice.paid` (stripe_webhook_handler_job.rb:299–309) — the addition carries its OWN rescue so those tiers never see it | §5.2/§5.3 |
| Constructed-event webhook testing | `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` | §9 |

Per the analog-manifest rule: the plan must diff the fan-out design against the `Organization` callback analog structurally (files, methods, guard shapes, enqueue style) and justify every DIFFERENT row.

## 9. Test requirements (calibrated per harness-profile — but the §4 predicate coverage is REQUIRED)

1. **New `spec/jobs/stripe_webhook_handler_subscription_events_spec.rb`** (analog: `stripe_webhook_handler_ai_credits_spec.rb`): constructed events through `#handle_stripe_event` — predicate matrix (`amount_paid` 0/positive × `trial_end` present/absent, stubbing `Stripe::Subscription.retrieve`), duplicate delivery → exactly one row, `canceled_subscription` row from `subscription.deleted`, and — load-bearing — existing branch behavior byte-identical around the insertions (the org update, payment-method call, `reset_ai_credits` still happen; a ledger failure does not break them).
2. **`CreateSubscriptionEvent`**: uniqueness guard (conversion duplicate → graceful fail, no raise), new params persisted, existing free-plan behavior + 5-min dedupe untouched.
3. **`SubscriptionEvent` fan-out**: per event_type, the right jobs enqueue (queue adapter `:test` around-block per pipeline rule 31 — `:inline` is the suite default and would fire real Discord/PostHog paths); `assigned_free_plan*` rows enqueue NOTHING; no owner → no PostHog enqueue; a `canceled_subscription` row with nil `organization.subscription_canceled_at` → no Discord enqueue (PostHog still enqueues); PostHog properties hash: attribution owner-first fallback, `.compact` behavior (nil fields absent), amount present only on conversion rows. No ghost tests (assertions must fail if the feature is deleted — BLOCKER otherwise).
4. **Organization callback**: `nil → 'trialing'` creates the `trial_started` row; the removed Discord lines no longer enqueue from the callback (and the Slack jobs still do).
5. **Cypress:** untouched; full suite passes at commit (pre-commit hook).

## 10. Out of scope (explicit)

`upgraded_plan`/`downgraded_plan`/`downgraded_to_free` writers (D12); Slack job migrations; a Discord job for non-trial conversion; CAPI/ad-platform sends; `billing_interval` property; currency column; backfill of any kind; consuming/altering `assigned_free_plan*` behavior; any change to `sync_with_stripe`, any webhook branch other than the two insertions, or any AI-credit path.

## 11. Risks / notes for review

1. **Predicate vs. real payloads:** QA Layer 3 exercises constructed real-shape events; true validation is production observation after ship (residual risk, Jessica-owned).
2. **Slack/Discord timing divergence** for trial-converted (Slack at status flip, Discord at cash) — deliberate, non-load-bearing practice scope.
3. **Console/backfill row creation fires the fan-out** — accepted property of the pattern (a comped conversion recorded via console SHOULD notify).
4. **`Discord::NotifySubscriptionDeletedJob` argument** (`ended_at`) — sourced from `organization.subscription_canceled_at` at fan-out time; nil handling is DEFINED in §7 (absent value → skip the Discord enqueue, PostHog still fires — never fabricate a timestamp).
5. **The webhook diff must survive the Layer-1 delicacy audit:** exactly two additive, rescue-isolated blocks; anything else in that file is a BLOCKER.
6. **Rollout misclassification of pre-existing subscriptions (OPEN QUESTION for Jessica — spec-review finding):** first-cash semantics hold only for subscriptions whose ledger history starts before their first cash. Every subscription that converted BEFORE this ships has no conversion row (no backfill), so its FIRST post-deploy paid invoice records a false conversion: one ledger row + one PostHog conversion event per existing paying subscription over its next billing cycle (~1 month monthly, up to ~12 months annual), plus a false Discord `Discord::NotifyTrialConvertedToPaidJob` ping for every subscription with `trial_end` present (most trial-era customers; `trial_end` persists for the subscription's lifetime). No DB-local discriminator exists within D5's ruled predicate (`stripe_subscription_status` is 'active' at both a trial conversion and a renewal; `billing_reason` is deliberately unused per D5). Mitigation options — seed/backfill conversion rows for currently-subscribed orgs (currently excluded by §10's "backfill of any kind"), a subscription-`created`-timestamp cutoff, or accept-and-filter by date in PostHog — are design decisions that are Jessica's. As specified, the false positives ship.
