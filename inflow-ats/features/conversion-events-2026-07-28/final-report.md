# FINAL REPORT — conversion events

Autonomous run, 2026-07-28. Branch `attribution-work-qa`, base `ada2feb9a`.
**The implementation is unstaged in the working tree. Nothing was committed or staged.**

---

## Working tree state

```
 M app/interactors/create_subscription_event.rb
 M app/jobs/stripe_webhook_handler_job.rb
 M app/models/subscription_event.rb
```

3 files, +184 / −106. `git diff --cached` empty. No `spec/` path touched. `ruby -c` returns
`Syntax OK` for all three.

Rubocop on the three files: 10 offenses, of which 9 are pre-existing in untouched code (verified by
running rubocop against the `ada2feb9a` version of each file via `git show HEAD:<path> | rubocop
--stdin`). The job went 8 → 7 offenses; the interactor is clean at 0 both before and after.

**One new offense, deliberately left:** `subscription_event.rb:71` `Style/RedundantReturn` — the bare
`return` ending `resolve_from_plan`'s rescue. It is not redundant. `Kernel#ap` in awesome_print 1.9.2
returns its argument outside a console, so without the bare `return` the method returns the exception
object, which is `present?`, and the `update_columns` write-back would put
`No such invoice: 'in_…'` into the `from_plan` string column and send it to PostHog. No
`# rubocop:disable` was added — `grep -rn "rubocop:disable" app/` returns zero hits, so the form is
alien to this codebase.

---

## Verified independently (not taken from agent reports)

| Check | Result |
|---|---|
| D14 divisor | `amount: amount.present? ? amount.to_i / 100.0 : nil` — float divisor, nil preserved, not fabricated as 0 |
| D9 helper is public | `def resolve_from_plan` at :46, `private` at :74 |
| D9 write-back | `update_columns(from_plan: resolved_from_plan) if resolved_from_plan.present?` at :84 — no write when nil |
| Line-300 `Stripe::Subscription.retrieve(object.subscription)` | still present (now :297) |
| D3 zero-amount guard | `if object.amount_paid.to_i > 0` still present at :314 |
| D11 five deletions | zero remaining references to all five |
| `downgrade_detected?` kept | still at :432 |

---

## Review results

| Phase | Agents | Errors | Outcome |
|---|---|---|---|
| Question hunt | 27 | 0 | 5 candidates, all refuted unanimously; 2 became spec amendments |
| Phase 1 spec review | 27 | 0 | 3 rounds. 50 findings, 3 blockers (2 resolved from code, 1 withdrawn) |
| Phase 2 plan | 8 | 0 | 4 defects applied, 0 blockers |
| Phase 3 implement | 8 | 0 | 3 of 4 verify angles zero; 2 MED, both report-only |
| Phase 4 final gate | 8 | 0 | 8 angles, **zero findings**, converged after round 1 |

The Phase 4 zero was checked rather than accepted: all eight agents' `files_traced` show real chains
through the diff, with verified hunk counts, `git diff --check` clean, and `ruby -c` run.

---

## Report-only items — BOTH CLOSED by Jessica, 2026-07-28

Neither is a concern. Rulings recorded inline below. No code change was made for either, and none is
wanted.

**1. D9's `organization.plan` invariant is not airtight for unmapped prior lookup keys.**
D9 says `organization.plan` is not read at creation, because `sync_with_stripe` races `invoice.paid`.
But D9 also moves `previous_plan_name` intact, and its last expression is
`organization.assign_plan_name_from_lookup_key(lookup_key: previous_lookup_key)`, which ends
`plan_key ? PLAN_LOOKUP_MAPPING[plan_key] : @organization.plan`
(`subscription_status_checker.rb:113-119`). A prior invoice whose lookup key has no
`PLAN_LOOKUP_MAPPING` entry therefore resolves to exactly the racy column. D19 pre-accepts that
fallback, but D19's acceptance is scoped to the interactor's conversion, not the callback's
resolution. Failure shape: a `converted_to_paid` PostHog event whose `from_plan` equals its `to_plan`.
The implementation is faithful to D9 as written; no alternative honors both sentences.

**Jessica's ruling: not a concern.** A plan with no `PLAN_LOOKUP_MAPPING` entry means something
upstream is already wrong. It is not a case to design around, and D9 stands as written.

**2. D18's top-up coverage claim does not hold.**
D18 says the `credit`/`plato` guard "covers AI credit top-up purchases as well as AI credit
subscriptions — both carry `credit` or `plato` in the lookup key." Top-up invoices do not.
`OrganizationAiCreditPurchase#charge_for_purchase` (`organization_ai_credit_purchase.rb:83-94`) builds
the line with `Stripe::InvoiceItem.create(customer:, amount:, currency:, description:, metadata:)` and
no `price:`, so there is no price object and no lookup key — the substring test matches nothing. The
lookup key lives only in `metadata[:stripe_price_lookup_key]`.

The guard as implemented is correct per D18's directive. What actually keeps a top-up row from being
written today is the `invoice.paid` metadata early return in `stripe_webhook_handler_job.rb`, which
returns before the interactor is reached. If that early return ever changes, the backstop D18 names is
not there. No code change made — adding a top-up-specific guard would be unspecced scope.

**Jessica's ruling: irrelevant.** If the guard happens to catch a top-up, fine; if it does not, also
fine. Those invoices would not produce a valid row either way. D18 stands as written.

---

## Test coverage

Rule 0a forbids RSpec specs and none were written. Recording the opinion here as the rule directs:
the two pieces carrying the most risk that manual exercise is least likely to cover are the D9 helper's
selection of the triggering invoice from the customer's invoice list, and the D4/D16 classification
tree across the real plan vocabulary. Both are pure functions of their inputs. Neither is a
recommendation to write a spec — that is your call, not mine.

---

## Manual verification

`plan.md` has the full list under "Manual verification". The paths worth exercising against a live
Stripe account, in priority order:

1. A free-plan organization converting to paid — confirm one `converted_to_paid` row with a resolved
   `from_plan`, and a PostHog event whose `amount` is dollars with cents intact.
2. A paid-to-higher-paid upgrade — one `upgraded_plan` row, no `$set`, no Discord.
3. A renewal — no row at all.
4. A cancellation — one `canceled_subscription` row, nil `amount`, Discord job under its existing
   `subscription_canceled_at.present?` guard.
5. A trial start — still writes `trial_started` and still fires `Discord::NotifyFreeTrialStartedJob`.
6. An AI credit purchase, subscription and top-up — no `subscription_events` row from either.

---

## Artifacts

| File | Contents |
|---|---|
| `SPEC.md` | approved spec, amended six times pre-run, synced to `approved-decisions-record-creation.md` |
| `RUN-LOG.md` | the six amendments and their verification |
| `RESUME.md` | run IDs, script paths, recovery routes |
| `spec-blockers.md` | 3 items with orchestration verdicts, none deleted |
| `spec-additions.md` | 47 implementation details from Phase 1 |
| `plan.md` | the implementation plan, 14 must-not-change items |
| `final-report.md` | this file |
