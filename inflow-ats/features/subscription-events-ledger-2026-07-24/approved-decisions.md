# Approved decisions — SubscriptionEvent ledger + PostHog/Discord fan-out

Captured from the design session with Jessica, 2026-07-24 (evening). These are her rulings unless marked PROPOSED. Spec not yet written — awaiting her go. Reference maps: `~/claude-hub/inflow-ats/documentation/stripe-subscription-lifecycle-2026-07-24/` (stripe-webhook-handler.md + organization-plan-callbacks.md).

## D1 — Pattern and purpose
Persisted domain events on the existing `subscription_events` table: business facts get rows; side effects hang off `after_commit on: :create`. PostHog tracking and the Discord::Notify* jobs are the FIRST consumers — deliberately, because neither is load-bearing ("perfect things to practice on"). Slack `Notification::*` jobs stay exactly where they are this round.

## D2 — Main-plan only
`SubscriptionEvent` records MAIN subscription events exclusively. AI-credit subscription events keep their own existing tables (`OrganizationAiCreditPurchase`, `AiCreditBalanceTransaction`); nothing AI-side ever writes a SubscriptionEvent. Enforcement is structural: writers live only inside the webhook's main-plan branches (behind the existing `ai_credit_subscription_plan_lookup_key?` / subscription-id-match guards) plus the Organization status callback. New `stripe_subscription_id` column makes every row attributable.

## D3 — Enum
- Values 0/1 (`assigned_free_plan_on_creation`, `assigned_free_plan`) frozen — live writer since `b0aaccd32` (2025-09-07), real production rows, though currently dormant (nothing assigns free_v2 today). Nobody consumes these rows.
- Values 2–6: zero rows ever (no writer ever existed) — freely renameable/renumberable.
- **Trial vs non-trial conversion are TWO distinct enum values** (exact names settled in spec; e.g. `trial_converted_to_paid` + `converted_to_paid`).
- **canceled→paid and free→paid are the SAME event** — both are plain non-trial `converted_to_paid`. Trial→paid is not.
- `trial_started` is a NEW additive value (Jessica: trivial in this table).
- Deferred, NO writers this round: `upgraded_plan`, `downgraded_plan`, `downgraded_to_free`.
- The stale comment block above the enum (mislabeled numbering) gets corrected in passing.

## D4 — Conversion = cash, single create
Converted events are created ONCE, at `invoice.paid` (the only money-confirming event), born complete with `amount`. NO create-then-update, NO placeholder row at trial expiry. `trial_started` and the conversion are two independent rows linked only by organization + stripe_subscription_id.

## D5 — Trial-conversion discriminator
At the `invoice.paid` main-plan branch, a trial conversion is:
`object.amount_paid > 0` AND `stripe_subscription.trial_end.present?` (on the subscription the handler already live-retrieves — NOT the event payload snapshot, NOT any status field; `trial_end` is written at subscription creation so no transition-ordering window exists) AND no prior converted-type row for this `stripe_subscription_id` (uniqueness key = first-cash semantics; renewals and past_due recoveries classify correctly for free).
Non-trial conversion: same predicate with `trial_end` absent. Reactivation checkouts get no trial (`eligible_for_free_trial?` fails on non-blank status / lifetime spend), so canceled→paid lands as non-trial automatically.
Accepted consequence (Jessica's "they have to hand over cash" definition): a 100%-off first cycle (`amount_paid: 0`) produces no conversion event until real money moves.

## D6 — Writer placements
- `trial_started`: Organization `handle_subscription_status_change_after_commit`, the exact `nil → 'trialing'` branch (where FreeTrialStarted jobs fire today). Record-created-inside-a-callback chain explicitly accepted.
- `trial_converted_to_paid` / `converted_to_paid`: `StripeWebhookHandlerJob` `invoice.paid` main-plan branch — additive, at the END of the branch, individually rescue-wrapped so ledger failure never breaks existing handling; mind the `CustomStripeSubscriptionMissingError` guard above.
- `canceled_subscription`: webhook `customer.subscription.deleted` main branch (has `ended_at`; the reliable side per organization.rb:1154's split).

## D7 — Schema additions
`stripe_subscription_id` (string) and `amount` (integer, cents) on `subscription_events`; uniqueness enforcement for one converted-type row per organization + stripe_subscription_id (index vs interactor guard = plan-level).

## D8 — Fan-out consumers
`after_commit on: :create` on `SubscriptionEvent`, keyed on event_type:
- `PosthogTrackJob.perform_later(owner.id, <event>, properties)` — payload per D9.
- The matching `Discord::Notify*` job — MOVED from its current trigger site. Consequence (desired): the trial-conversion Discord fires at actual payment, not trial expiry (fixes the ~2h-early / declined-card false positive). Existing Slack jobs and all other current behavior untouched.
- PROPOSED (not yet ruled): run writers log-first on staging before attaching consumers, to verify the D5 predicate against real Stripe payloads.

## D9 — PostHog payload (from the earlier session segment)
- Existing `Posthog::Track` capture path; owner passed as the user (distinct_id = owner id; email/organization_id/organization_name/plan ride the service's default_properties — `plan_name` would near-duplicate `plan`).
- Event properties only — NO groups (unused in this codebase, confirmed), no `$set`/`$set_once` (that fragment came from a web draft, dropped).
- `trial_started`: no amount; has plan + billing interval. Conversions: real `amount` from `invoice.amount_paid`.
- Attribution fields (utm_source, utm_campaign, utm_data, internal_ref, gclid→google_click_id, adroll_click_id, adroll_first_party_cookie, fbclid, fbp, fbc, li_fat_id, ga_client_id, ga_session_id): owner's column first, organization's as fallback, else omitted — via the `attribution_value` helper (full if/elsif/else form, Jessica's shape; NO `.presence`), then `.compact` so nil keys are never sent.

## D10 — Style rulings binding this feature
- Early returns ONLY as implicit-nil bail-outs (`return unless x.present?`); value selection is a full if/elsif/else expression (memory: inflow-guard-clauses-bailout-only).
- `.presence` is not a house form — do not use.

## D11 — Webhook delicacy directive (Jessica, 2026-07-24, verbatim intent)
Minimum changes in `StripeWebhookHandlerJob`. Additions, changes, AND removals that touch if/else statements must each be individually and carefully considered/justified. Every harness agent that reads or writes this file must be told it is particularly delicate. Removals elsewhere are fine.

## D12 — Deferral rationale (Jessica, 2026-07-24)
`upgraded_plan` / `downgraded_plan` / `downgraded_to_free` ARE determinable (Jessica knows how) — deferred deliberately because the point of this round is testing the pattern, not completeness.

## RESOLVED at go (2026-07-24, second session segment)
- **Branch: `attribution-work-qa`** — Jessica: "the most up-to-date branch. I want work to occur here." Implementation commits stay LOCAL (no push — PR #3075 was open at ruling time; local commits do not affect it until pushed; push/PR remain Jessica's).
- **Go given:** write SPEC.md, run the harness with NO human gating; bar is "close to workable," Jessica reviews after.
- Defaults adopted without further questions (all reviewable in her later review): enum names `trial_started: 7`, `trial_converted_to_paid: 8`, `converted_to_paid: 2` stays as the non-trial type; PostHog event names = enum names (+ `canceled_subscription`); `amount` in cents, no currency column; `billing_interval` OMITTED this round (not DB-local at writer sites — flagged deviation from Jessica's original property list); no Discord job for non-trial conversion (none exists today; none added); Discord::NotifySubscriptionDeletedJob's enqueue moves out of `Notification::PaidSubscriptionDeletedJob:22` (its current site) into the fan-out; QA layers for this backend-only feature: 1 (diff-to-spec), 3 (script runner), 4 (regression) — Layers 2 and 5 skipped (no UI surface; browser adds nothing).
- The log-first staging soak (D8 PROPOSED) is superseded by QA Layer 3 exercising the predicate against constructed real-shape events; true production-payload validation noted as a residual risk for Jessica.
