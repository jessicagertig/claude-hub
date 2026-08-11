# SPEC — Correct subscription conversion events

**Branch:** `attribution-work-qa` (main checkout). Follows the ledger work already committed there (`89286fba8` + fixes, merged with #3076).
**Origin:** Jessica's rulings in conversation, 2026-07-27 evening, after observing wrong data on a real upgrade. Every rule below is hers unless marked OPEN.
**Problem that started it:** on a real free → paid upgrade (Writers Corner Exclusive, org 5), the `converted_to_paid` row recorded `to_plan` as the FREE plan. The writer passed `to_plan: organization.plan`, and that column had not yet been synced from Stripe.

**DELICACY:** `app/jobs/stripe_webhook_handler_job.rb` is load-bearing billing logic. Every change below is confined to the two existing sanctioned insertions plus new private methods. No branch reordering, no changes to existing behavior.

---

## 1. Root cause

`organization.plan` is written by `sync_with_stripe`, which runs from `customer.subscription.updated` — a different webhook event with no ordering guarantee relative to `invoice.paid`. Reading it at `invoice.paid` is a race: sometimes the old plan, sometimes the new one. It cannot be the source for either side of the transition at that site.

Cancellation is the opposite case: cancelling changes subscription STATUS, not plan, so `organization.plan` there is a current, correct read.

## 2. Rulings — cancellation (`canceled_subscription`)

At the `customer.subscription.deleted` insertion:

- `from_plan: organization.plan` — the plan they are leaving, known and correct at that moment
- `to_plan: nil` — there is no destination plan

## 3. Rulings — the prior-plan lookup (new private method)

Used by the `invoice.paid` insertion to establish what plan the organization was on before this invoice.

1. List the customer's invoices (`Stripe::Invoice.list(customer:)`).
2. REJECT any whose first line's price lookup key contains `credit` or `plato` — those are AI credit pack / Plato invoices, not main plan. (Same filter `sync_with_stripe` uses.)
3. Of what remains, take the most recent invoice created BEFORE the current invoice (compare `created`).
4. If none exists → no prior plan.
5. If the prior invoice is on a DIFFERENT subscription than the current invoice, retrieve that subscription. If its status is `canceled`, the prior plan is recorded as the literal string **`'canceled'`** — not a plan, but the fact that they came back from a cancellation rather than from a plan. (Jessica: "obviously canceled is not a plan, but it's what would work best for us.")
6. Otherwise map the prior invoice's lookup key through `organization.assign_plan_name_from_lookup_key`.

Note: `assign_plan_name_from_lookup_key` returns `organization.plan` when given a nil lookup key — never call it with nil.

## 4. Rulings — what fires at `invoice.paid`

Preconditions for any event at this site: `amount_paid > 0`, and the invoice is a main-plan invoice (the credit/plato filter already routes credit-pack invoices elsewhere).

Then, using the prior plan from §3:

| Prior plan | Condition | Event |
|---|---|---|
| none, free, or `'canceled'` | — | `converted_to_paid` |
| a trial on the same subscription | `trial_end` present AND a prior $0 invoice on the SAME subscription AND that trial ended within **15 days** | `trial_converted_to_paid` |
| already a paid plan (`PAID_PLANS`), same subscription, plan differs, new tier higher | — | `upgraded_plan` |
| already a paid plan, same subscription, plan differs, new tier lower | — | `downgraded_plan` / `downgraded_to_free` (see §6) |
| already a paid plan, same plan | — | **nothing** — it is a renewal |

- **15 days is literal, not `TRIAL_PERIOD_DAYS`** (which is 14). Jessica: the wider window prevents timezone skew at the boundary from dropping people.
- A trial conversion is by definition the SAME subscription — the trial ends and that subscription takes its first charge. A different subscription means it is not a trial conversion.
- Tier comparison uses the ranking already in this file: `%w[free starter growth scale enterprise]` in `downgrade_detected?`.
- `upgraded_plan` exists ONLY because paid → paid changes were firing `converted_to_paid`. This is not plan-change tracking.

On every event above: `from_plan` from §3, `to_plan` from `organization.assign_plan_name_from_lookup_key(lookup_key: subscription_lookup_key)` — the lookup key already computed at line ~297 from the invoice's own subscription.

## 5. Rulings — trial start

`subscription_started_trial_after_commit?` currently tests `previous_status.nil? && current_status == 'trialing'`, which misses a free-plan organization (status `active`) starting a trial, and a returning customer's trial.

Change to: `previous_status != 'trialing' && current_status == 'trialing'` — the same shape as `subscription_became_canceled_after_commit?` directly below it in the same file.

## 6. OPEN — for Jessica

1. **Downgrades are out of scope** (Jessica, explicit). The tier check at `invoice.paid` still runs both directions so a downgrade arriving with a positive charge is not mistyped — but downgrades normally produce a credit or $0 invoice and will not reach this site at all. `downgraded_plan` / `downgraded_to_free` therefore remain effectively unwritten. Confirm that is acceptable.
2. **`trial_started` `from_plan`/`to_plan`** — it currently reads `organization.plan` for `to_plan` and passes no `from_plan`. Now that a free-plan organization can start a trial, the plan they came from is real. Not ruled on.

## 7. Existing code to reuse (no new mechanisms)

| Need | Existing |
|---|---|
| credit/plato invoice filter | `sync_with_stripe`, organization.rb ~540 |
| lookup key → plan name | `Organization#assign_plan_name_from_lookup_key` |
| paid plan test | `Stripe::SubscriptionStatusChecker::PAID_PLANS` |
| tier ranking | `downgrade_detected?`, stripe_webhook_handler_job.rb |
| status transition helper shape | `subscription_became_canceled_after_commit?`, organization.rb |
| the invoice itself | `object` in the `invoice.paid` branch — already in scope, no extra retrieval |
| the subscription | `stripe_subscription` retrieved at line ~296 |

## 8. Current uncommitted state to resolve first

`app/jobs/stripe_webhook_handler_job.rb` carries an edit made mid-conversation and superseded by later rulings: a `previous_plan_from_invoices` private method that returns nil (not `'canceled'`) for a canceled prior subscription, and an insertion passing `from_plan`/`to_plan` without the §4 event-type gating. It must be reworked against this spec, not built on.
