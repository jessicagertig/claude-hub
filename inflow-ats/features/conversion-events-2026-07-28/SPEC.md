# SPEC — Subscription conversion events

**Working directory:** `/Users/jessica/claude-hub/inflow-ats/features/conversion-events-2026-07-28/`
**Source repo:** the path in `REPO-PATH`

---

# JESSICA REVIEWED ITEMS — NOT MUTABLE

Everything in this section was decided by Jessica directly and is closed.

**No agent may modify, reword, reinterpret, extend, or narrow any item below.** They are not proposals,
not defaults, and not starting points. A review agent that disagrees with an item reports the
disagreement and changes nothing. An implementation agent that finds an item inconvenient implements it
as written and reports the difficulty.

Where an item says something is deferred, out of scope, untouched, or deliberately absent, that is a
decision — not an omission to be corrected.

---

## D1 — `pending: 0` is a column default, not a workflow state

`pending` exists so `event_type` can never be null, per `cursor_rules/core_critical_rules.md` rule 14.
It is not a state a row is meant to sit in. A row found at `pending` means the column was never
assigned — a defect to investigate, not a deferred verdict.

No row is ever deliberately saved as `pending`.

## D2 — `CreateSubscriptionEvent` classifies before it saves

The interactor builds the row with `event_type`, `from_plan`, `to_plan`, `stripe_subscription_id`,
and `amount` already set, and saves it once.

**The interactor makes no Stripe calls.** Every value comes off the Stripe object it is handed.

Where each value comes from, on `invoice.paid` — the object is the invoice:

| Column | `subscription_update` | `subscription_create` | `subscription_cycle` |
|---|---|---|---|
| `stripe_subscription_id` | `invoice.subscription` | `invoice.subscription` | — |
| `amount` | `invoice.amount_paid` | `invoice.amount_paid` | — |
| `from_plan` | plan name from the price lookup key of `lines.data.find { \|line\| line.amount.negative? }`, per D19 | nil | — |
| `to_plan` | plan name from the price lookup key of `lines.data.find { \|line\| line.amount.positive? }`, per D19 | plan name from the price lookup key of `lines.data.first`, per D19 | — |
| `event_type` | see D4 | `converted_to_paid` | — |

The negative/positive line selection is the one `OrganizationAiCreditPurchase#sync_grant` already uses
for `subscription_update` invoices. `subscription_cycle` creates no row at all — see D6.

On `customer.subscription.deleted` — the object is the subscription:

| Column | Source |
|---|---|
| `stripe_subscription_id` | the subscription's `id` |
| `amount` | nil |
| `from_plan` | `organization.plan` |
| `to_plan` | nil |
| `event_type` | `canceled_subscription` |

A zero `amount_paid` creates no row, so `amount` is never persisted as zero from an invoice. A null
`amount` therefore means the row came from `customer.subscription.deleted`.

## D3 — no event means no row

A renewal creates nothing. A zero-amount invoice creates nothing.

## D4 — `event_type` on a `subscription_update` invoice

Given the two plans D2 reads off the invoice lines, in this order:

- `converted_to_paid` when `from_plan` is nil or contains `free`
- no row when the two plans are equal
- `upgraded_plan` when the tier increased, per D16
- no row otherwise

The free test is `include?('free')`, which holds for both vocabularies — `plan_ats_tier_free` and
`plan_ats_tier_free_v2` contain it, as do the lookup keys they came from. It is deliberately NOT
membership in `Stripe::SubscriptionStatusChecker::PAID_PLANS`. Substring testing is also the house
form — `StripeWebhookHandlerJob#downgrade_detected?` does exactly it.

## D5 — `customer.subscription.deleted`

`canceled_subscription`, `from_plan` from `organization.plan`, `to_plan` nil. No Stripe call.

## D6 — `trial_converted_to_paid` is deferred

A trial conversion and an ordinary renewal both arrive as `subscription_cycle` with a single line and
the same plan on both sides. Whether the invoice itself distinguishes them is unresolved — Jessica is
generating a real trial conversion to find out.

Until it is settled, no `subscription_cycle` invoice creates a row, so trial conversions record
nothing in the interim.

**The `trial_converted_to_paid` scaffolding is written now and is not dead code.** Jessica's ruling:
its `case` branch, its `$set` values, and its `Discord::NotifyTrialConvertedToPaidJob` are built ahead
of the detection decision, so that settling detection is the only remaining change. Do not report the
branch as unreachable, dead, or premature — the unreachability is deliberate and temporary.

Note that `trial_started` rows already reach that dispatch today, written by
`Organization#handle_subscription_status_change_after_commit`, so the trial half of the callback is
live regardless.

A `pending_trial` enum value was considered and rejected: every renewal is also `subscription_cycle`,
so it would write one row per renewal per organization. The same objection applies to leaving those
rows at `pending` — the row count is identical either way.

## D7 — downgrades are out

`downgraded_plan` and `downgraded_to_free` are not written by this feature. A tier decrease on a
`subscription_update` invoice creates no row.

`handle_subscription_schedule_downgrade` is where a scheduled downgrade would be recorded — it already
holds the organization, both lookup keys, and the downgrade verdict. Recording it there is not part of
this feature and that handler is untouched.

## D8 — the callback resolves `from_plan`, then dispatches

Remove all classification from `SubscriptionEvent#handle_after_commit_on_create`. What remains is the
`from_plan` resolution in D9, then the existing branch dispatch to PostHog and Discord. Do not comment
the callback out.

## D9 — the callback's Stripe calls are for `from_plan`

The resolution runs for every row whose `from_plan` is nil. On a `subscription_create` conversion the
invoice carries no prior plan, so the interactor leaves `from_plan` nil and the callback resolves it:
`Stripe::Invoice.list` for the organization's Stripe customer, the qualifying filter that rejects
invoices with no `subscription` and no line-item lookup key and rejects keys containing `credit` or
`plato`, and the `'canceled'` branch that retrieves the prior invoice's subscription.

The callback has no invoice object, so the triggering invoice is recovered from the list the callback
already made. Within the qualified invoices, this row's own invoice is the most recent one whose
`subscription` equals the row's `stripe_subscription_id`. The prior invoice is then the most recent
qualified invoice created before it — the same `created` comparison
`StripeWebhookHandlerJob#previous_main_plan_invoice` makes today. No second `Stripe::Invoice.list` is
issued, and the `'canceled'` branch keeps a real guard comparing the prior invoice's `subscription`
against the triggering invoice's, so `Stripe::Subscription.retrieve` stays conditional.

The Stripe calls introduced by this branch move to the callback. They are exactly two, both currently
in `StripeWebhookHandlerJob`: `Stripe::Invoice.list` in `previous_main_plan_invoice` and
`Stripe::Subscription.retrieve` in `previous_plan_name`. No other Stripe call in that file moves. In
particular `Stripe::Subscription.retrieve(object.subscription)` on the `invoice.paid` path pre-dates
this work and stays — the AI credit routing check and the `stripe_current_period_end_at` update both
read it.

`organization.plan` is not read at creation. That column is written by `Organization#sync_with_stripe`
from the `customer.subscription.updated` webhook, which has no ordering guarantee against
`invoice.paid` — if it lands first the column already holds the new plan, and `from_plan` would record
the plan they moved to as the plan they came from.

It runs before dispatch, because `posthog_properties` sends `from_plan`.

The Stripe calls live in a public helper method on `SubscriptionEvent` that returns `from_plan`, above
`private`. The helper carries a method-level `rescue StandardError => e` — no `begin` block, per
`cursor_rules/backend/_base.md` rule 1 — which logs, `ap e`, then bare-returns. A failure therefore
yields a nil `from_plan` and nothing else: the row keeps its `event_type`, and dispatch runs normally.
A nil `from_plan` is an acceptable outcome and is not substituted with any other value.

The callback assigns what the helper returns and writes it back to the column. When the returned value
is present it is written with `update_columns(from_plan: <resolved>)`. `update_columns` skips
callbacks, so the write does not re-enter `handle_after_commit_on_create`, and `after_commit` runs
after the transaction commits, so nothing is bypassing a rollback. It also updates the in-memory
attribute, so the `from_plan` that `posthog_properties` reads is the resolved one. When the helper
returns nil — it rescued, or nothing qualified — no write happens and the column stays nil.

It never changes `event_type`. Where the resolved `from_plan` and `to_plan` contradict the
`event_type` the interactor assigned, nothing is corrected — remedial action is undecided and
deliberately not built.

## D10 — local development logging

Print the Stripe object the interactor receives. Local development only.

## D11 — unchanged

`Organization#log_assigned_free_plan_event` and the `trial_started` callback in
`Organization#handle_subscription_status_change_after_commit` both pass a finished `event_type` and
are untouched.

Still deleted from `StripeWebhookHandlerJob`: `TRIAL_CONVERSION_WINDOW_DAYS`,
`previous_main_plan_invoice`, `previous_plan_name`, `trial_conversion?`, and
`subscription_event_type_for`.

## D12 — `is_paying` is set as a person property on the existing capture

PostHog applies plain event properties to the event only. Person properties are written with `$set`
or `$set_once`, which are keys placed directly inside `properties` on a capture call — so the event
`SubscriptionEvent` already fires carries them, and no second PostHog call is added.

- `converted_to_paid` — `$set` `is_paying: true`
- `trial_converted_to_paid` — `$set` `is_paying: true`, once D6 is settled
- `canceled_subscription` — `$set` `is_paying: false`
- `downgraded_to_free` — `$set` `is_paying: false`

## D13 — `is_trialing` is set the same way

Carried in the same `$set` hash on the same capture:

- `trial_started` — `is_trialing: true`
- `trial_converted_to_paid` — `is_trialing: false`, `is_paying: true`
- `canceled_subscription` — `is_trialing: false`, `is_paying: false`
- `converted_to_paid` — `is_paying: true`, `is_trialing: false`

A trial that lapses without converting needs no separate handling: it is always canceled eventually,
and `canceled_subscription` clears `is_trialing`.

`upgraded_plan` dispatches to PostHog, where today it dispatches nothing, and carries no `$set` at
all. See D15 for the full dispatch table.

Nothing else about the PostHog payload changes.

The person is matched by `distinct_id` alone; no additional identifier is passed. `Posthog::Track`
sends `distinct_id: @user.id.to_s` and the browser calls `ph.identify(String(user.id), ...)` in
`app/javascript/shared/lib/posthog.ts`, so server and browser events land on the same person.

One thing to verify against a real event rather than assume: `PosthogTrackJob` calls
`properties.deep_symbolize_keys` before handing off, so `'$set'` reaches the client as a symbol.

## D14 — the PostHog `amount` is in dollars

`subscription_events.amount` stays in cents. `SubscriptionEvent#posthog_properties` divides it by
`100.0` before sending, so PostHog receives a decimal. A value that is not already a number is
converted to an integer first, then divided by `100.0`.

The divisor is `100.0`, never `100`. `amount` is an integer column, so integer division would truncate
— `4999 / 100` is `49`, losing the cents, while `4999 / 100.0` is `49.99`. The two non-AI
cents-to-dollars conversions in the codebase both use the float divisor
(`app/models/board_wwr_listing.rb:101` and `:103`).

A nil `amount` is sent as nil, not as zero. `canceled_subscription` rows carry no amount.

Only the PostHog payload converts. Nothing else reads or writes the column differently.

## D15 — the dispatch is a `case` on `event_type`

`handle_after_commit_on_create` resolves `from_plan` when it is nil, then runs a `case event_type`.
Each `when` supplies that event's `$set` hash and enqueues its Discord job. `posthog_properties`
builds the shared hash, the `$set` merges in, and one `enqueue_posthog_track` runs after the `case`.

| `event_type` | `$set` | Discord |
|---|---|---|
| `trial_started` | `is_trialing: true` | `Discord::NotifyFreeTrialStartedJob` |
| `trial_converted_to_paid` | `is_paying: true`, `is_trialing: false` | `Discord::NotifyTrialConvertedToPaidJob` |
| `converted_to_paid` | `is_paying: true`, `is_trialing: false` | none |
| `canceled_subscription` | `is_paying: false`, `is_trialing: false` | `Discord::NotifySubscriptionDeletedJob`, under its existing `subscription_canceled_at.present?` guard |
| `upgraded_plan` | none | none |

The `else` is a bare return, so `assigned_free_plan_on_creation`, `assigned_free_plan`,
`downgraded_plan`, `downgraded_to_free`, and `pending` dispatch nothing. The two downgrade types are
never written by this feature.

## D16 — upgrade detection is a tier index comparison on `SubscriptionEvent`

A class method on `SubscriptionEvent`, called from `CreateSubscriptionEvent` before the row is built,
indexes both plan names by substring against

    %w[free simple_ats_paid simple_ats_per_job apollo starter growth scale enterprise]

falling back to 0 when nothing matches, and reports an upgrade when the destination index is greater
than the origin index. It runs only after `converted_to_paid` and the equal-plans case are ruled out,
so `from_plan` is a paid, non-free plan by then. A lower or equal index creates no row.

Every entry matches both vocabularies: `plan_ats_tier_starter`, `plan_ats_tier_growth_v2`,
`plan_simple_ats_paid`, `plan_ats_tier_apollo`, and the rest all contain their tier substring, as do
the lookup keys they were converted from.

`StripeWebhookHandlerJob#downgrade_detected?` and its own `plan_tiers` array are untouched.

## D17 — the duplicate check never compares `from_plan`

`CreateSubscriptionEvent`'s 24-hour duplicate check matches on organization, `event_type`, `to_plan`,
`stripe_subscription_id`, and `amount`. `from_plan` is always omitted from it.

The parameter hash is built without `from_plan`, the check runs against it, and `from_plan` is added
afterwards for the build — the same sequence the interactor already uses for `stripe_subscription_id`
and `amount`.

## D18 — the interactor guards on the `credit` and `plato` substrings

After reading the destination lookup key off the invoice and before converting it to a plan name,
`CreateSubscriptionEvent` bare-returns and creates no row when that key contains `credit` or `plato`.
Nothing is logged as an error — this is an expected skip, not a failure.

The guard runs on the raw lookup key, not the converted plan name. AI credit price keys have no
`PLAN_LOOKUP_MAPPING` entry, so conversion would answer with `organization.plan` and the substrings
would be gone.

It covers AI credit top-up purchases as well as AI credit subscriptions — both carry `credit` or
`plato` in the lookup key, so a top-up that reaches the interactor is skipped by the same test.

This is the interactor's own guard. Both webhook branches already route AI credit subscriptions
elsewhere before reaching the interactor, and this does not replace or depend on that.

It is the same substring test D9's qualifying filter applies to prior invoices, and it is deliberately
not `OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?`, which is an exact hash
lookup against `Variables::AI_CREDIT_ALLOCATIONS`.

## D19 — plans are stored as plan names, not lookup keys

`from_plan` and `to_plan` hold internal plan names, matching what
`Organization#log_assigned_free_plan_event`, the `trial_started` callback, and `canceled_subscription`
already write. `CreateSubscriptionEvent` converts each lookup key it reads off the invoice with
`organization.assign_plan_name_from_lookup_key(lookup_key: <key>)`.

The conversion is called only when the key is present. A nil key is stored as nil and never passed to
that method, which answers a nil key with `organization.plan` — the racy column D9 keeps out of
`from_plan`.

A key that is present but matches no `PLAN_LOOKUP_MAPPING` entry also resolves to `organization.plan`.
That case cannot be planned for from here and is accepted.

---

# DON'T FUCK WITH THIS

Each item below is a predicted agent failure, listed because it is the thing an agent is most likely
to do while believing it is helping. Doing any of them is a defect regardless of how reasonable it
seemed.

**Do not delete or modify `StripeWebhookHandlerJob#downgrade_detected?`.** D16 puts a tier list on
`SubscriptionEvent` and D7 takes downgrades out of this feature, which together make that method look
orphaned. It is not. `handle_subscription_schedule_downgrade` calls it for the
`subscription_schedule.updated` and `subscription_schedule.created` events. Its `plan_tiers` array
stays where it is, duplication and all.

**Do not change anything in `app/jobs/stripe_webhook_handler_job.rb` beyond the two call-site
replacements and the five deletions in D11.** Not the `begin` blocks, not the metadata early returns,
not `handle_subscription_credit_pack_invoice_paid`, not `handle_charge_refunded`, not
`handle_subscription_schedule_downgrade`, and not the `CustomStripeSubscriptionMissingError` raise. D7
names `handle_subscription_schedule_downgrade` to say where a downgrade would eventually be recorded,
which is not permission to touch it. No main-subscription identity check is added at either call site.

**Do not move `Stripe::Subscription.retrieve(object.subscription)` out of the `invoice.paid` handler.**
It sits directly in front of the `CreateSubscriptionEvent` call site, so it looks like one of the calls
D9 relocates. It is not — it pre-dates this branch, and both the AI credit routing check and the
`stripe_current_period_end_at` update read what it returns. The only two Stripe calls that move are the
ones D9 names by method.

**Do not unify the two line selections.** `subscription_update` reads `from_plan` and `to_plan` from
the negative-amount and positive-amount lines; `subscription_create` reads `to_plan` from
`lines.data.first`. These are deliberately different and the difference is load-bearing. Using
`lines.data.first` on a `subscription_update` invoice fails silently, taking whichever line Stripe
happened to return first.

**Do not fabricate a `from_plan` value.** Nil is a correct, expected outcome — on a
`subscription_create` row before the callback resolves it, and permanently when D9's helper rescues.
The data migration `db/data/20260727185945_create_subscription_events_for_existing_paid_organizations.rb`
writes `from_plan: 'unknown'`; that is a backfill artifact, not a precedent. No `|| 'unknown'`, no
`|| organization.plan`, no substitution of any kind.

**Do not write RSpec specs.** The source repo's `.claude/CLAUDE.md` rule 0a forbids creating a spec
file and forbids adding examples to an existing one. Verification for this feature is manual.

**Do not restructure the `$set` payload.** `$set` is a key inside `properties` on the capture, not a
top-level argument and not a separate call. `PosthogTrackJob` calls `deep_symbolize_keys`, so it
arrives as a symbol — that is expected and is not to be "fixed" by stringifying keys or bypassing the
job.

**Do not divide `amount` by 100 anywhere except the PostHog payload.** The column stays in cents. D14
converts in `posthog_properties` and nowhere else.

**Do not make D9's `from_plan` helper private.** It is a public method above `private`.

**Do not give the `case` in D15 a dispatching `else`.** The `else` is a bare return.

**Do not remove the `TODO` above `handle_after_commit_on_create` in `app/models/subscription_event.rb`.**
It is marked to be kept and it records an undecided question, not stale work.

---

# END JESSICA REVIEWED ITEMS
