# REVIEW-ANGLES — subscription-events-ledger (Phase 1 output, 2026-07-24)

Source repo: `/Users/jessica/wrk/wrk-corp/inflow-ats`, branch `attribution-work-qa` @ `a0d59115d` (verified live). Backend-only — no frontend layers exist for this feature.

**⚠️ DELICACY DIRECTIVE (from Jessica, verbatim intent — every downstream agent carries this):** `app/jobs/stripe_webhook_handler_job.rb` is PARTICULARLY DELICATE, load-bearing billing logic. Minimum changes only; additions, changes, and even removals that touch if/else statements must each be individually justified; no branch reordering; no changes to Stripe-object attribute access. SPEC.md §5 defines the only two sanctioned insertion points.

Required reading for every reviewer: SPEC.md, approved-decisions.md (D1–D12 + RESOLVED — immutable), harness-profile.md, `~/claude-hub/inflow-ats/documentation/stripe-subscription-lifecycle-2026-07-24/stripe-webhook-handler.md` + `organization-plan-callbacks.md`, `<REPO>/cursor_rules/core_critical_rules.md`.

---

## Subsystems touched

| Subsystem | Files |
|---|---|
| Webhook handler (DELICATE) | `app/jobs/stripe_webhook_handler_job.rb` — insertion 1: `invoice.paid` main-plan else-branch, appended after line 297 (`organization.organization_ai_credit_balance&.reset_ai_credits`); insertion 2: `customer.subscription.deleted` main else-branch, appended after line 210 (`EngagementReport::GeneratorJob`). Nothing else in this file. |
| Organization callbacks | `app/models/organization.rb` — `subscription_started_trial_after_commit?` branch (1128–1134: add `CreateSubscriptionEvent.call`, remove line 1131 `Discord::NotifyFreeTrialStartedJob`); `trial_converted_to_paid_after_commit?` branch (1136–1140: remove line 1139 `Discord::NotifyTrialConvertedToPaidJob` only). Note core_critical_rules "Do not automate edits to organization.rb" — the harness profile/spec sanctions these two edits explicitly. |
| Ledger model + enum | `app/models/subscription_event.rb` — enum gains `trial_started: 7`, `trial_converted_to_paid: 8`; stale comment block (lines 4–11: duplicate "1:" labels, off-by-one numbering) corrected; new `after_commit on: :create` fan-out + private helpers; main-plan-only comment (D2). |
| Interactor | `app/interactors/create_subscription_event.rb` — optional `stripe_subscription_id:`/`amount:` context params; conversion-type uniqueness guard (check-first, `RecordNotUnique` rescued to the same graceful `context.fail!`). |
| Migration | New migration (analog `db/migrate/20260723222212_add_adroll_click_id_to_users.rb` + `add_index`): `stripe_subscription_id` string, `amount` integer (cents), partial unique index on conversion types (enum ints 2 and 8). Current table shape: `db/schema.rb:1189–1197`. |
| Discord enqueue sites (moves) | `app/models/organization.rb:1131`, `:1139`; `app/jobs/notification/paid_subscription_deleted_job.rb:22` (inside private `discord` method called from `perform` line 13). Discord job FILES untouched. |
| PostHog capture | `app/jobs/posthog_track_job.rb` (untouched — consumer), `app/services/posthog/track.rb` (untouched — `default_properties` = email/organization_id/organization_name/plan, merged UNDER custom properties). |
| Tests | New `spec/jobs/stripe_webhook_handler_subscription_events_spec.rb` (analog `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`); interactor, fan-out, and organization-callback coverage per SPEC §9. |

## Full-stack analog (priority rule)

Analogs are internal and named in SPEC §8 — all verified live at a0d59115d:

1. **Fan-out style:** `Organization#handle_after_commit_on_update` → five handlers (organization.rb:1023–1156). Handler shape: `return unless persisted?` bail-outs, `saved_changes` gates, `ap` logging, `perform_later` enqueues.
2. **Interactor:** `CreateSubscriptionEvent` itself (extended, not replaced) — 5-minute same-`event_params` dedupe at lines 21–27.
3. **PostHog path:** `PosthogTrackJob.perform_later(user_id, event, properties)` (billing_controller.rb:115, 213, 311) → `Posthog::Track`.
4. **Constructed-event testing:** `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` — doubles for metadata (`double('metadata', :[] => nil)`), `Stripe::Event.retrieve` stub, `described_class.perform_now`.

**Priority rule:** when the spec and an analog disagree, the spec + approved-decisions win (D-rulings are immutable); when the spec is silent, the analog's structure is the default and every deviation must be justified per the analog-manifest rule (SPEC §8 last paragraph). Structural mismatch with the analog = BLOCKER (pipeline rule 14).

---

## Angle 1 — Webhook-delicacy audit

**⚠️ DELICACY DIRECTIVE (D11, verbatim intent):** `app/jobs/stripe_webhook_handler_job.rb` is PARTICULARLY DELICATE, load-bearing billing logic. Minimum changes only; additions, changes, and even removals that touch if/else statements must each be individually justified; no branch reordering; no changes to Stripe-object attribute access. SPEC.md §5 defines the only two sanctioned insertion points.

**Files:** `app/jobs/stripe_webhook_handler_job.rb` (the FULL diff of this file, line by line).
**What to verify:**
- The diff contains EXACTLY two additive blocks: end of `invoice.paid` else-branch (after current line 297) and end of `subscription.deleted` else-branch (after current line 210). Anything else in this file — reordering, attribute-access changes, cleanup, comment edits beyond the insertions — is a BLOCKER.
- Each block carries its OWN `begin/rescue StandardError` (log with context, never re-raise); the `invoice.paid` three-tier rescue (lines 299–309) and the `subscription.deleted` single rescue (212–215) must never see ledger failures.
- Insertions run AFTER all existing branch behavior completes — org update, `stripe_update_default_payment_method`, `reset_ai_credits` (invoice.paid); `sync_with_stripe`, `update_column(:subscription_canceled_at)`, both jobs (subscription.deleted).
- House-safe attribute access only in new code (`object.metadata&.[]('key')` forms; the branch's already-retrieved `stripe_subscription` — no new Stripe API calls).
- §5.3 nil-organization handling: the else branch uses `organization&.` throughout (organization can be nil — `Organization.find_by` miss at line 174). Trap: `CreateSubscriptionEvent` line 12 calls `ap organization.stripe_subscription_in_good_standing` BEFORE its `return unless organization` guard — a nil organization passed through raises NoMethodError inside the interactor (caught by the new rescue, but noisy and wrong). The writer must guard nil organization before calling, or the interactor guard order must be addressed — flag whichever the implementation chose and check it against the spec.
**Convention context:** D11; harness-profile delicacy section; reference map `stripe-webhook-handler.md`; cursor rule "rescue most specific class, never empty rescue blocks."

## Angle 2 — Conversion-predicate correctness (§4)

**Files:** the new predicate code in `stripe_webhook_handler_job.rb` insertion 1; `app/interactors/create_subscription_event.rb` (uniqueness backstop).
**What to verify:**
- Matrix per §4: `object.amount_paid.to_i > 0` gate; `stripe_subscription.trial_end.present?` → `trial_converted_to_paid`, absent → `converted_to_paid`.
- `trial_end` sourced from the subscription object the branch ALREADY retrieves at line 283 (`Stripe::Subscription.retrieve(object.subscription)`, live at processing time) — NEVER the event payload's embedded snapshot, NEVER any `status` field, NO second retrieve.
- Predicate evaluated only inside the main-plan else branch, after the `CustomStripeSubscriptionMissingError` guard (line 289) — nil `organization.stripe_subscription_id` never reaches it.
- First-cash semantics ride the uniqueness invariant, not extra logic: renewals/past_due recoveries on an already-converted subscription = graceful duplicate no-op; a first-ever cash recovery IS the conversion. No `billing_reason` logic (the reference map discusses it; D5 deliberately does not use it).
- `amount: object.amount_paid` (cents, raw), `stripe_subscription_id: object.subscription`, `to_plan: organization.plan`, `from_plan` nil (SPEC-PROPOSED, rule-10 rationale).
- $0 invoices (trial-creation invoice, 100%-off cycles) record NOTHING — accepted per D5.
**Convention context:** D4/D5 immutable; rule 10 (no fabricated fallbacks — watch for `|| 0` on amount); D10 style (bail-outs `return unless x.present?`, selection full if/elsif/else).

## Angle 3 — Ledger integrity (migration + enum + interactor guard)

**Files:** new migration; `db/schema.rb` staging; `app/models/subscription_event.rb`; `app/interactors/create_subscription_event.rb`.
**What to verify:**
- Enum: `trial_started: 7`, `trial_converted_to_paid: 8` added; 0/1 (`assigned_free_plan_on_creation`/`assigned_free_plan`) byte-identical — live production rows; 2–6 keep names/numbers per spec (`converted_to_paid: 2` = non-trial conversion). Stale comment block (subscription_event.rb:4–11 — duplicate "1:" labels, every number off by one) actually corrected, and corrected ACCURATELY against the final enum.
- Migration: both columns nullable, no defaults, no backfill, no currency column. Partial unique index enforces ≤1 row per `stripe_subscription_id` where `event_type IN (2, 8)` — the INVARIANT is binding, mechanics SPEC-PROPOSED. Note a wording delta to check at plan/impl time: D7 says the key is "organization + stripe_subscription_id" while SPEC §3 says per `stripe_subscription_id` alone (functionally equivalent — Stripe sub ids are globally unique — but the implemented index must satisfy the D7 invariant; flag if it can't).
- Interactor: check-first guard BEFORE build, fires only when `event_type` is a conversion type AND `stripe_subscription_id` present; duplicate → `context.fail!` (graceful, logged, never raised); raced `ActiveRecord::RecordNotUnique` rescued to the same graceful no-op. Existing 5-minute dedupe untouched for existing callers. Trap: the dedupe `.where(event_params)` — if the new params are merged into `event_params` unconditionally, nil `stripe_subscription_id`/`amount` enter the dedupe WHERE clause and change match semantics for existing `assigned_free_plan*` callers (`WHERE stripe_subscription_id IS NULL` matches, but verify no rows/params regressions); spec says merge "when present" — confirm absent params are OMITTED from the hash, not merged as nil.
- Main-plan-only comment on the model (D2). No new model validations beyond what the spec states.
- Schema commit HARD rule: never stage `db/schema.rb` wholesale — hunk-stage exactly this migration's columns/index + version bump; dev-schema corruption stays unstaged.
- Variable naming: `subscription_event`, `organization` — never `record`/`row`/`entry` (core rules "Variable Naming for Records").
**Convention context:** D3, D7; rule 20 (enum/shared-infrastructure changes need explicit sanction — here 7/8 ARE sanctioned, anything beyond is not); rule 11 (no bang methods outside specs); rule 12 (check save/update returns).

## Angle 4 — Fan-out contract (Discord moves + enqueue table)

**Files:** `app/models/subscription_event.rb` (the callback); `app/models/organization.rb:1128–1140`; `app/jobs/notification/paid_subscription_deleted_job.rb`.
**What to verify:**
- `after_commit on: :create`, keyed on `event_type`, handler style structurally matched to `Organization#handle_after_commit_on_update` (bail-out guards, `perform_later`) — analog-manifest diff required; unjustified DIFFERENT rows are findings.
- Per-type table exactly per §7: `trial_started` → PostHog + `Discord::NotifyFreeTrialStartedJob.perform_later(organization_id)`; `trial_converted_to_paid` → PostHog + `Discord::NotifyTrialConvertedToPaidJob.perform_later(organization_id)`; `converted_to_paid` → PostHog only (NO Discord job exists today; none added); `canceled_subscription` → PostHog + `Discord::NotifySubscriptionDeletedJob.perform_later(organization_id, ended_at)`; `assigned_free_plan*` → NOTHING.
- Exactly three enqueue-site moves, verified as the only current sites (grep confirms one site each): organization.rb:1131, organization.rb:1139, paid_subscription_deleted_job.rb:22. The line-22 removal lives inside the private `discord` method that `perform` calls at line 13 — verify the removal shape leaves the Slack path intact (no call to a now-empty/missing method, no accidental deletion of the `slack` call). Discord job FILES byte-identical.
- `Discord::NotifySubscriptionDeletedJob#perform(organization_id, ended_at)` — `ended_at` is a REQUIRED positional arg and the job runs `Time.at(ended_at)` (notify_subscription_deleted_job.rb:7,14). The fan-out passes `organization.subscription_canceled_at.to_i` (SPEC-PROPOSED — §11.4 says verify). Trap: nil `subscription_canceled_at` (console-created row, or webhook `update_column` failed) → `nil.to_i` = 0 → Time.at(0) = 1970 — a fabricated-fallback shape (rule 10/13 spirit). The webhook writes the column before the row is created in §5.3, but the fan-out fires for ALL creation paths (§11.3). Check what the plan/impl does with nil here.
- **All Slack `Notification::*` jobs stay exactly where they are** — verify byte-identical: `Notification::FreeTrialStartedJob` (org callback), `Notification::TrialConvertedToPaidJob` (org callback), `Notification::PaidSubscriptionDeletedJob` enqueue in the webhook (line 209) and its internal `slack` method. Stated consequence (accepted): Slack trial-converted fires at status flip, Discord at cash.
- Callback-inside-callback chain for `trial_started` (row created inside `handle_subscription_status_change_after_commit`) explicitly accepted (D6) — verify no re-entrancy surprise beyond it.
- No-owner bail-out: `return unless organization&.owner` before the PostHog enqueue (`belongs_to :owner, class_name: 'User'` is non-optional, so this is defensive — fine).
**Convention context:** D1, D6, D8; pipeline rule 14 (structural matching, mismatch = BLOCKER); helper placement SPEC-PROPOSED as private model methods (the analog keeps callback helpers on the model).

## Angle 5 — PostHog payload integrity

**Files:** `app/models/subscription_event.rb` (properties builder + `attribution_value` helper — NEW code, no existing definition in the repo: grep confirms zero hits at a0d59115d).
**What to verify:**
- `PosthogTrackJob.perform_later(organization.owner.id, <enum name as event name>, properties)` — matches the billing_controller call shape; event names = enum names (+ `canceled_subscription`).
- Properties from DB-local data ONLY (row + organization + owner; NO Stripe calls at fan-out time): `amount` (only when present on the row), `stripe_subscription_id`, `stripe_customer_id` (organization), `to_plan` (row).
- `email`/`organization_id`/`organization_name`/`plan` NOT duplicated — they ride `Posthog::Track#default_properties` (track.rb:25–32; note `default_properties.merge(@properties)` means custom keys would OVERRIDE defaults on collision — `to_plan` avoids colliding with `plan`; flag any new key that shadows a default).
- Attribution: 13 fields exactly (`utm_source`, `utm_campaign`, `utm_data`, `internal_ref`, `google_click_id`, `adroll_click_id`, `adroll_first_party_cookie`, `fbclid`, `fbp`, `fbc`, `li_fat_id`, `ga_client_id`, `ga_session_id`) — all 13 exist on BOTH `organizations` (schema.rb:1081–1103) and `users` (schema.rb:1300–1312). Each via `attribution_value(owner.<col>, organization.<col>)` — owner-first, org fallback, else nil. Helper shape per D10: FULL if/elsif/else with `present?` tests and explicit `nil` else — **NO `.presence`** (banned house form). Final hash `.compact`ed — absent fields never sent, no `|| ''`/`|| 0` fabrication anywhere (rule 10).
- `billing_interval` deliberately ABSENT (RESOLVED-at-go deviation, flagged) — its presence would be a finding in the wrong direction.
- No groups, no `$set`/`$set_once` (D9).
**Convention context:** D9, D10; core rule 10; pipeline rule 13.

## Angle 6 — Behavior preservation (the reverse audit)

**Files:** every modified file, diffed hunk by hunk; plus grep sweeps.
**What to verify:**
- `invoice.paid` and `subscription.deleted` existing branch bodies byte-identical around the insertions; all other webhook branches (checkout.session.completed, subscription.updated, charge.refunded, credit-pack branches, schedule handlers) untouched. All AI-credit paths untouched. `sync_with_stripe` untouched.
- organization.rb: ONLY the two named branches change, only as specified — `Notification::FreeTrialStartedJob` line, `organization_ai_credit_balance&.reset_ai_credits`, `Notification::TrialConvertedToPaidJob` line, all the `ap` lines, every other handler byte-identical. (core_critical_rules: "Do not automate edits to organization.rb" — the two sanctioned edits are the entire permitted surface.)
- Removed Discord enqueues no longer fire from the OLD sites; a `trial_started`/`trial_converted_to_paid`/`canceled_subscription` row is now the ONLY path to those three Discord jobs. `assigned_free_plan*` rows (created via `log_assigned_free_plan_event` → `CreateSubscriptionEvent`, organization.rb:1092/1231) enqueue NOTHING from the new callback and their creation behavior is unchanged.
- Nothing out of SPEC §2's file list appears in the diff (serializers, policies, routes, frontend, Slack jobs, Discord job files = zero hunks). Reverse direction is first-class: everything in the diff the spec never asked for is a finding (Layer-1 mirror; fix-agent rules 10/23).
- Commits reviewed, not working tree (pipeline rule 15 — run `git diff HEAD` first). Commits stay LOCAL; never push (PR #3075 open).
**Convention context:** SPEC §2 Untouched list, §10 out-of-scope list; pipeline rules 10, 15, 23.

## Angle 7 — Test coverage and ghost tests

**Files:** new `spec/jobs/stripe_webhook_handler_subscription_events_spec.rb`; specs for the interactor, the fan-out, the organization callback; existing `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` (must still pass, untouched).
**What to verify:**
- **§4 predicate coverage is REQUIRED this round** (harness-profile exception — new business logic in the delicate file): matrix `amount_paid` 0/positive × `trial_end` present/absent (stubbing `Stripe::Subscription.retrieve`), duplicate delivery → exactly one row, `canceled_subscription` row from `subscription.deleted`, and — load-bearing — existing branch behavior still happens around the insertions (org update, payment-method call, `reset_ai_credits`) and a ledger failure does not break them.
- Analog structure: constructed events per `stripe_webhook_handler_ai_credits_spec.rb` (`double('metadata', :[] => nil)` pattern, `Stripe::Event.retrieve` stub, `perform_now`; org via `create_credit_test_organization`-style helpers — there is no spec/factories directory).
- Fan-out specs: queue adapter `:test` around-block per pipeline rule 31 (`config/environments/test.rb` sets `:inline` — without the swap, real Discord/PostHog side effects fire inside examples); right jobs per event_type; `assigned_free_plan*` → nothing; no owner → no PostHog; properties hash: owner-first fallback, `.compact` (nil fields ABSENT, not nil), amount only on conversion rows.
- Organization callback spec: `nil → 'trialing'` creates the `trial_started` row; removed Discord lines no longer enqueue from the callback; Slack jobs still do.
- Interactor spec: conversion duplicate → graceful fail (no raise), new params persisted, existing free-plan behavior + 5-minute dedupe untouched. Bang methods OK in specs only (rule 11 exception).
- **Ghost tests = BLOCKER** (pipeline rule 26): every assertion must fail if the feature is deleted — no reflection-on-enum tautologies, no assigned-but-unasserted variables. Missing coverage outside the §4 exception is never HIGH/MED on its own (harness profile); wrong/broken/ghost tests are.
- Cypress untouched; full suite passes at commit (pre-commit hook, detached ≥20-min procedure).
**Convention context:** SPEC §9; harness-profile test priorities; pipeline rules 26, 31.

---

## Always-on checks (every reviewer, every round)

1. **Source accuracy** — claims cite real file:line at `attribution-work-qa` @ a0d59115d; re-verify line numbers against the actual diff (insertion coordinates above are pre-diff).
2. **Test coverage** — per Angle 7 calibration; §4 predicate coverage REQUIRED; ghost tests BLOCKER.
3. **Backward compatibility** — enum 0/1 frozen (live rows); existing `CreateSubscriptionEvent` callers unchanged; existing webhook/callback behavior byte-identical; nullable columns, no backfill.
4. **Analog completeness** — every SPEC §8 analog actually consulted; every pattern the analog carries (guards, logging, rescue shape, enqueue style) present in the new code or its absence justified.
5. **Analog structural matching** — signatures/guards/lifecycle compared structurally per the manifest rule, not layer-existence; **structural mismatch = BLOCKER** (pipeline rule 14).
6. **Delicacy compliance** — any hunk in `stripe_webhook_handler_job.rb` beyond the two sanctioned insertions = BLOCKER (D11; §11.5).
7. **Spec-implementation mismatch is never MED** (hub failure patterns); MED = should-be-fixed (harness profile); D1–D12 + RESOLVED are immutable — a finding that contradicts a D-ruling is a finding against the finding.
8. **Style/house forms** — D10 (bail-outs + if/elsif/else, no `.presence`), core rules 8 (bare `return`), 10 (no fabricated fallbacks), 11/12 (no bang methods; check save/update returns), variable naming for records, single quotes, `ap` not `pp`.
