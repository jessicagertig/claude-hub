# SPEC BLOCKERS — conversion events

Phase 1 spec review, run `wf_f572c2d9-f78`. Three claimed blockers, all raised in round 1; rounds 2
and 3 raised none. Cap is five and no item is ever deleted — orchestration verdicts are written in
below, and Jessica rules for herself.

Everything else from the review is in `spec-additions.md` (47 items).

---

## B1 — `CreateSubscriptionEvent` has four callers, not two

**Claimed against:** D2 ("Every value comes off the Stripe object it is handed") vs D11 (two callers
untouched)

**Orchestration verdict: VALID — resolvable from the code, no ruling needed.**

Verified directly. `CreateSubscriptionEvent` has four call sites, not the two the spec discusses:

- `app/jobs/stripe_webhook_handler_job.rb:216` — `customer.subscription.deleted`
- `app/jobs/stripe_webhook_handler_job.rb:322` — `invoice.paid`
- `app/models/organization.rb:1131` — the `trial_started` callback
- `app/models/organization.rb:1236` — `log_assigned_free_plan_event`

The two in `Organization` pass a finished `event_type` and no Stripe object:

```ruby
CreateSubscriptionEvent.call(organization: self, event_type: 'trial_started', to_plan: plan, stripe_subscription_id: stripe_subscription_id)

result = CreateSubscriptionEvent.call(
  organization: self,
  event_type: event_type,
  from_plan: previous_plan,
  to_plan: current_plan
)
```

D11 declares both untouched. An interactor rewritten to require a Stripe object breaks both:
`Interactor::Context < OpenStruct`, so a missing key reads as `nil` rather than raising, and the first
dereference raises `NoMethodError`. At `organization.rb:1131` that raise happens inside
`handle_subscription_status_change_after_commit`, skipping the handlers that follow it, and is then
swallowed by the `rescue StandardError` at `stripe_webhook_handler_job.rb:163`.

**Resolution the code determines:** the interactor keeps both entry shapes. The existing
`event_type`/`from_plan`/`to_plan`/`stripe_subscription_id` path stays for the two `Organization`
callers, and the D2/D4/D16/D18/D19 derivation runs only when a Stripe object is present. The two
objects are different types with different D2 tables, so the two webhook call sites pass distinct keys
— `invoice:` and `subscription:` — which is also the only parameter naming with precedent in the repo
(`apply_ai_credit_upgrade.rb:27`, `apply_ai_credit_subscription.rb:16`,
`organization_ai_credit_purchase.rb:123`).

No decision of Jessica's is contradicted by this. It is a signature the spec never wrote out.

---

## B2 — same defect as B1, reported separately

**Claimed against:** D2 / D11

**Orchestration verdict: VALID, merged into B1.** Two reviewers found the same thing from different
angles. B2 adds the failure-path detail (`run!` rolls back and re-raises; `.call` rescues only
`Interactor::Failure`, so the error escapes) and the caller-shape analysis. No separate action.

---

## B3 — D9's scope fires on `trial_started` and `assigned_free_plan` rows

**Claimed against:** D9 ("runs for every row whose `from_plan` is nil") vs D11 (the `trial_started`
callback and `log_assigned_free_plan_event` untouched) and D13 ("Nothing else about the PostHog
payload changes")

**Orchestration verdict: VALID — needs Jessica's ruling. The code cannot decide it.**

Verified directly. `organization.rb:1131` passes no `from_plan` at all, so every `trial_started` row
has a nil `from_plan`. `organization.rb:1236` passes `from_plan: previous_plan`, and `previous_plan`
is nil-able — `assigned_free_plan?` admits `nil` as a qualifying previous plan
(`organization.rb:1225-1227`).

Read literally, D9's resolution therefore fires on those rows too, with two consequences the spec does
not name:

1. **PostHog payload.** For a `trial_started` row the helper can resolve a value, `update_columns`
   writes it and updates the in-memory attribute, and `posthog_properties` then emits a `from_plan`
   key on `trial_started` events. Today that key is always absent — `from_plan` is nil and the
   `.compact` at `subscription_event.rb:84` drops it. D13 says nothing else about the payload changes.

2. **Stripe calls on paths D11 freezes.** `Stripe::Invoice.list` fires inside `after_commit` on every
   trial start and on every organization creation that writes `assigned_free_plan_on_creation`. A
   brand-new organization has no `stripe_customer_id`, so the call goes out as
   `Stripe::Invoice.list(customer: nil)`, Stripe rejects it, and D9's method-level rescue swallows it
   — a live HTTP round-trip per organization creation that resolves nothing.

**Recommended resolution, for Jessica:** narrow D9's stated scope to the path it was written for. D9's
own second sentence already describes it — "On a `subscription_create` conversion the invoice carries
no prior plan, so the interactor leaves `from_plan` nil and the callback resolves it." Changing the
first sentence from "runs for every row whose `from_plan` is nil" to "runs for a `converted_to_paid`
row whose `from_plan` is nil" closes the collision, keeps D11's untouched paths untouched, and leaves
D13's payload unchanged.

**Status: WITHDRAWN — not a blocker. D9 is unchanged and correct as written.**

The finding rested on the premise that the rows swept in by D9's scope could not resolve a meaningful
`from_plan`. Jessica states as fact that the free plan produces a Stripe invoice. That invalidates the
premise: free-plan organizations appear in invoice history, so D9's resolution resolves correctly on
every path that reaches it, including `trial_started` and `assigned_free_plan*` rows.

D9's scope stays "every row whose `from_plan` is nil." No amendment to D9, D11, or D13.

The `Stripe::Invoice.list` call is already in the callback under D9, so the additional rows are the
same call on more rows, not a new kind of call.

Process note for the implementation phase: this item should never have been escalated. The premise was
checkable in the codebase and was not checked before it went to the owner.
