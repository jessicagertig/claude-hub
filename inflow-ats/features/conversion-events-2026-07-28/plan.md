# PLAN — conversion events

**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`
**Branch:** `attribution-work-qa`, base `ada2feb9a` (clean tree)
**Spec:** `SPEC.md` (CLOSED — never modified), `spec-additions.md` (47 details), `spec-blockers.md` (B1/B2 VALID and resolved below; B3 WITHDRAWN — D9's scope stays "every row whose `from_plan` is nil")

Every line number below is as it stands at `ada2feb9a`, before any edit in this plan. Tasks run in the
order given. Within a file, later tasks' anchors are stated relative to the earlier tasks' insertions,
not to the original line numbers.

**Rule 0a is absolute.** No task in this plan creates an RSpec spec file or adds an example to one.
Verification is manual — see "Manual verification". If coverage seems needed, it goes in the final
report, nowhere else.

---

## Files touched

| Path | What changes |
|---|---|
| `app/models/subscription_event.rb` | Adds two public methods above `private` — `self.upgrade_detected?(from_plan, to_plan)` (D16) and `resolve_from_plan` (D9). Rewrites the private `handle_after_commit_on_create` as `from_plan` resolution + `case event_type` on String literals with a bare-return `else` and one shared `enqueue_posthog_track` after it (D8/D9/D15). `enqueue_posthog_track` and `posthog_properties` each gain a required `person_properties` parameter; `'$set' => person_properties` becomes the last pair inside the `posthog_properties` literal, before its existing `.compact` (D12/D13); `amount:` becomes nil-guarded dollars (D14). |
| `app/interactors/create_subscription_event.rb` | Adds a three-entry-shape dispatch at the top of `call` (B1/B2 resolution, D2); rewrites the `event_params` / duplicate-check / build sequence so `from_plan` is assigned AFTER the check (D17); adds five private helpers — `attributes_from_context`, `attributes_from_stripe_subscription`, `attributes_from_stripe_invoice`, `attributes_from_subscription_update_invoice`, `attributes_from_subscription_create_invoice` (D2/D4/D5/D6/D16/D18/D19) — including the two D10 dev-guarded `ap` lines. Lines 6–14 unchanged. |
| `app/jobs/stripe_webhook_handler_job.rb` | Exactly three hunks: the `customer.subscription.deleted` call site (216–222) becomes `organization:` + `subscription:`; the `invoice.paid` call site (318–330) becomes `organization:` + `invoice:` with the `if object.amount_paid.to_i > 0` guard at 317 retained; lines 383–446 deleted (the five D11 members). |

No other file is created, edited, deleted, or moved.

### Must NOT change

1. **`Stripe::Subscription.retrieve(object.subscription)` at `stripe_webhook_handler_job.rb:300`** and `subscription_lookup_key` at `:301`. They sit directly in front of the replaced `invoice.paid` call site and look like the Stripe calls D9 relocates. They are not: the AI-credit routing check at `:303` and the `stripe_current_period_end_at` update at `:308` both read them (SPEC "DON'T FUCK WITH THIS").
2. **`if object.amount_paid.to_i > 0` at `stripe_webhook_handler_job.rb:317`.** It is the only implementation of D3's "a zero-amount invoice creates nothing" and it is not one of D11's five deletions. Exactly one such guard exists after this plan — never zero, never two.
3. **`StripeWebhookHandlerJob#downgrade_detected?` (508–519) and its `plan_tiers = %w[free starter growth scale enterprise]` (513).** Still called by `handle_subscription_schedule_downgrade` at `:496`. Duplication with D16's array is intended.
4. **`handle_subscription_schedule_downgrade` (447–506)**, **`handle_charge_refunded`**, **`handle_subscription_credit_pack_invoice_paid`**, **`log_stripe_changes` (521+)**.
5. **The `begin`/`rescue` blocks at 212–227 and 316–335, and the outer `invoice.paid` rescues at 337–347**, including their `Rails.logger.error` messages and `ap e` lines. Do not convert them to method-level rescues — `_base.md` rule 1 permits `begin` for a nested subset of operations and these pre-date the branch.
6. **The metadata early returns at 256–267, 269–285, 287–298** and **`raise CustomStripeSubscriptionMissingError` at `:306` and `:582`**.
7. **The two comment lines at `stripe_webhook_handler_job.rb:214-215`** ("Cancelling changes subscription status, not plan…"). They stay true and they document why the interactor may read `organization.plan` on that path.
8. **Both `Organization` call sites — `organization.rb:1131` (`trial_started`) and `organization.rb:1236` (`log_assigned_free_plan_event`)** — keep their exact argument lists. `app/models/organization.rb` is not edited at all (D11).
9. **`Stripe::SubscriptionStatusChecker::PAID_PLANS`, `FREE_PLANS_WITH_ONE_JOB`, and `app/services/stripe/subscription_status_checker.rb`.** After the D11 deletions the job no longer references the first two; they are still read at `organization.rb:143,679,684,688,696,713,717`.
10. **`DisableAutomationsOnDowngrade#plan_downgraded?` and its `plan_hierarchy` (`disable_automations_on_downgrade.rb:44-58`).** It is the nearest plan-NAME hierarchy an implementer will find and it orders the legacy-unlimited plans opposite to D16. Do not import, reuse, reconcile, or "fix" it.
11. **The `# TODO: KEEP THIS TODO…` comment block at `subscription_event.rb:35-37`** and the `ap "SubscriptionEvent Created (After Commit): #{event_type}"` line at `:39`.
12. **`.compact` at `subscription_event.rb:84`** and the fourteen attribution keys at `:71-83`, `attribution_value`, `stripe_subscription_id:`, `stripe_customer_id:`, `from_plan:`, `to_plan:`.
13. **`create_subscription_event.rb` lines 6–14**, including the commented-out `# ap context` at `:8` and both unguarded `stripe_subscription_in_good_standing` prints.
14. **No RSpec spec file, anywhere, for any of this** (`.claude/CLAUDE.md` rule 0a).

---

## Tasks

### Area A — `app/models/subscription_event.rb`

Run A first: the interactor (Area B) calls `SubscriptionEvent.upgrade_detected?`, and the job deletions
(Area C) hand `Stripe::Invoice.list` / `Stripe::Subscription.retrieve` to `resolve_from_plan`. T1–T5 all
run against the file as it stands at `ada2feb9a`; no other area edits this file.

---

#### T1 — Add the public class method `self.upgrade_detected?` — implements D16

**File:** `app/models/subscription_event.rb`

Insert immediately below `after_commit :handle_after_commit_on_create, on: :create` (line 31) and above
the `private` keyword (line 33), so it is public.

```ruby
  # Higher index = higher tier. Both vocabularies (plan names and the lookup keys
  # they came from) contain their tier substring.
  def self.upgrade_detected?(from_plan, to_plan)
    plan_tiers = %w[free simple_ats_paid simple_ats_per_job apollo starter growth scale enterprise]

    from_tier = plan_tiers.find_index { |tier| from_plan&.include?(tier) } || 0
    to_tier = plan_tiers.find_index { |tier| to_plan&.include?(tier) } || 0

    to_tier > from_tier
  end
```

- **This is the ONLY place `upgrade_detected?` is added.** It does not exist on the branch (`grep -rn "upgrade_detected?" app/ lib/ db/ config/ spec/` returns zero hits). The interactor consumes it; the interactor does not define it.
- The array, its order, and the `|| 0` fallback are D16 verbatim and closed. Eight entries, that order. No v2 entries, no reordering.
- Structure and naming mirror the analog `StripeWebhookHandlerJob#downgrade_detected?` (`stripe_webhook_handler_job.rb:508-519`): positional arguments, predicate name, `plan_tiers` as a method-local array (NOT a new constant), `find_index` + `|| 0`, `&.include?` on both sides.
- **`&.include?` is mandatory on BOTH arguments.** `to_plan` arrives nil whenever a `subscription_update` invoice's positive line carries no `price.lookup_key`; `nil.include?` raises `NoMethodError`, which the call site's `rescue StandardError` at `stripe_webhook_handler_job.rb:332` swallows into a bogus ledger error (`d16-tier-index-nil-to-plan`).
- Returns a boolean only. The "no row on a lower or equal tier" decision (D7) belongs to `CreateSubscriptionEvent`, not here.
- Do not touch `StripeWebhookHandlerJob#downgrade_detected?` or its own `plan_tiers` array. Do not reconcile with `DisableAutomationsOnDowngrade#plan_downgraded?` (`d16-second-plan-name-hierarchy-unnamed`).

---

#### T2 — Add the public `resolve_from_plan` helper — implements D9

**File:** `app/models/subscription_event.rb`

Insert directly below T1's `upgrade_detected?`, still above `private`. It is the relocation of
`StripeWebhookHandlerJob#previous_main_plan_invoice` (389–396) and `#previous_plan_name` (401–413),
which T16 deletes.

```ruby
  # The plan the organization was on before this event. Recovered from invoice
  # history because the triggering invoice is not available in the callback.
  def resolve_from_plan
    return unless organization&.stripe_customer_id.present?

    qualified_invoices = Stripe::Invoice.list(customer: organization.stripe_customer_id, limit: 20).data.reject do |listed_invoice|
      lookup_key = listed_invoice.lines.data.first&.price&.lookup_key.to_s
      listed_invoice.subscription.blank? || lookup_key.blank? || lookup_key.include?('credit') || lookup_key.include?('plato')
    end

    triggering_invoice = qualified_invoices.select { |listed_invoice| listed_invoice.subscription == stripe_subscription_id }.max_by(&:created)
    return unless triggering_invoice

    previous_invoice = qualified_invoices.select { |listed_invoice| listed_invoice.created < triggering_invoice.created }.max_by(&:created)
    return unless previous_invoice

    previous_subscription = Stripe::Subscription.retrieve(previous_invoice.subscription) if previous_invoice.subscription != triggering_invoice.subscription
    previous_lookup_key = previous_invoice.lines.data.first&.price&.lookup_key

    if previous_subscription&.status == 'canceled'
      'canceled'
    elsif previous_lookup_key.present?
      organization.assign_plan_name_from_lookup_key(lookup_key: previous_lookup_key)
    end
  rescue StandardError => e
    Rails.logger.error "SubscriptionEvent from_plan resolution error: subscription_event=#{id} org=#{organization_id} msg=#{e.message}"
    ap e
    return
  end
```

Load-bearing points, none of which may be "cleaned up":

- **PUBLIC.** Above `private`. SPEC "DON'T FUCK WITH THIS": "Do not make D9's `from_plan` helper private."
- **Method-level `rescue`, no `begin` block** (`cursor_rules/backend/_base.md` rule 1), `=> e` (core rule 16).
- **The trailing bare `return` is the LAST statement of the rescue body and is NOT redundant.** `Kernel#ap` in awesome_print 1.9.2 returns its argument outside a console, so without it the method returns the exception object — which is `present?`, and T3's `update_columns` would write `No such invoice: 'in_…'` into the `from_plan` string column and send it to PostHog (`d9-ap-returns-its-argument`). Rule 8 governs guard clauses at the top of a method, not the terminal statement of a rescue whose value the caller reads.
- **Exactly ONE `Stripe::Invoice.list`** (D9: "No second `Stripe::Invoice.list` is issued"), and `Stripe::Subscription.retrieve` stays conditional on the subscription mismatch.
- **The reject block has THREE rejections, not the analog's one.** `previous_main_plan_invoice` implements only credit/plato, which lets WWR / WhatJobs one-off invoices (no subscription, no price) qualify and reach `Stripe::Subscription.retrieve(nil)` → `Stripe::InvalidRequestError` swallowed by the rescue (`d9-qualifying-filter-not-in-the-analog`). Nil-safety is the analog's `&.price&.lookup_key.to_s` before `.include?`.
- **Both lookup-key reads use `lines.data.first&.price&.lookup_key`.** Do NOT apply D2's negative/positive line selection here — that selection is scoped to the triggering invoice inside `CreateSubscriptionEvent`, and applying it here would also break the qualified-invoice recovery (`d9-helper-keeps-lines-data-first`).
- **The literal `'canceled'` is returned as-is.** It is not a plan name and must not be normalized, mapped through `assign_plan_name_from_lookup_key`, or dropped (`d19-canceled-sentinel-not-a-plan-name`).
- **Value selection is the trailing `if/elsif` expression**, NOT `return 'canceled' if …`. `code_style_and_structure.md` "Method Return Patterns" and core rule 8 forbid value-returning guards; the only existing cluster of them is the three lines T16 deletes (`value-returning-guard-clauses`).
- **`return unless triggering_invoice`** exists so nothing dereferences `.created` on nil for rows with a nil `stripe_subscription_id` (`assigned_free_plan*` rows). **`organization&.stripe_customer_id.present?`** is the house guard preventing `Stripe::Invoice.list(customer: nil)` — stripe-9.4.0 keeps the nil pair and transmits `customer=`; the analog is `Organization#free_plan_eligible_for_free_trial?` (`organization.rb:705-708`) (`d9-helper-runs-on-rows-with-no-stripe-context`).
- **Scope stays "every row whose `from_plan` is nil"** — B3 is WITHDRAWN, D9 is correct as written. Trial-start and `assigned_free_plan*` rows resolve through this helper too, and that is intended.
- Single-quoted strings except the interpolated log message (`_base.md` rule 7).

---

#### T3 — Rewrite `handle_after_commit_on_create` as resolution + `case` dispatch — implements D8, D9, D12, D13, D15

**File:** `app/models/subscription_event.rb`

Replace the body of the private `handle_after_commit_on_create` (lines 38–55 — the `if trial_started? /
elsif … end` chain). Keep the `# TODO: KEEP THIS TODO…` block (35–37) exactly as-is and in place above
the method. Keep the `ap "SubscriptionEvent Created (After Commit): #{event_type}"` line as the first
statement.

```ruby
  def handle_after_commit_on_create
    ap "SubscriptionEvent Created (After Commit): #{event_type}"

    if from_plan.nil?
      resolved_from_plan = resolve_from_plan
      update_columns(from_plan: resolved_from_plan) if resolved_from_plan.present?
    end

    person_properties = case event_type
                        when 'trial_started'
                          Discord::NotifyFreeTrialStartedJob.perform_later(organization_id)
                          { is_trialing: true }
                        when 'trial_converted_to_paid'
                          Discord::NotifyTrialConvertedToPaidJob.perform_later(organization_id)
                          { is_paying: true, is_trialing: false }
                        when 'converted_to_paid'
                          { is_paying: true, is_trialing: false }
                        when 'canceled_subscription'
                          if organization.subscription_canceled_at.present?
                            Discord::NotifySubscriptionDeletedJob.perform_later(organization_id, organization.subscription_canceled_at.to_i)
                          end
                          { is_paying: false, is_trialing: false }
                        when 'upgraded_plan'
                          # No $set. This branch exists only so upgraded_plan reaches the shared
                          # capture below instead of falling into the bare-return else.
                        else
                          return
                        end

    enqueue_posthog_track(person_properties)
  end
```

Every one of these is load-bearing:

- **Resolution runs BEFORE the `case`**, because `posthog_properties` sends `from_plan` (D9, D15). Predicate is `from_plan.nil?` — every row (B3 WITHDRAWN).
- **`update_columns` only when the resolved value is present**; nil means no write and the column stays nil. No `|| 'unknown'`, no `|| organization.plan`, no substitution of any kind (SPEC "Do not fabricate a `from_plan` value"; core rule 10). `update_columns` skips callbacks so this does not re-enter the callback, and `after_commit` is post-transaction so nothing bypasses a rollback.
- **`when` clauses are single-quoted STRINGS.** The Rails enum reader returns a String; symbol `when` clauses match nothing and every row silently falls into the bare-return `else`, killing the live `trial_started` dispatch too (`d15-case-compares-strings`, `d15-case-on-enum-reader-returns-string`, `d15-case-must-match-strings`).
- **In every branch the `$set` hash is the LAST expression.** `perform_later` returns the job instance; a job object reaching `PosthogTrackJob.perform_later` raises `ActiveJob::SerializationError` at enqueue, which propagates out of `save` and, on the `trial_started` path, out of `organization.save` — that call site (`organization.rb:1131`) has no rescue (`d15-case-value-vs-discord-enqueue-order`).
- **`canceled_subscription` keeps BOTH the existing `organization.subscription_canceled_at.present?` guard and the second `organization.subscription_canceled_at.to_i` argument.** `Discord::NotifySubscriptionDeletedJob#perform(organization_id, ended_at)` takes two required positionals and calls `Time.at(ended_at)`; the other two Discord jobs take one (`d15-discord-deleted-job-arity`).
- **`when 'upgraded_plan'` has an EMPTY body**, so it evaluates to `nil`, never `{}`. Omitting the branch drops the one payload change D13 adds ("`upgraded_plan` dispatches to PostHog, where today it dispatches nothing"); initialising to `{}` ships `"$set": {}` because `Hash#compact` drops nil only (`d15-upgraded-plan-when-branch-is-load-bearing`, `d15-empty-set-hash-survives-compact`).
- **`else` is a bare `return`** — no dispatching else (SPEC "DON'T FUCK WITH THIS"). `assigned_free_plan_on_creation`, `assigned_free_plan`, `downgraded_plan`, `downgraded_to_free` and `pending` therefore dispatch nothing; D12's `is_paying: false` cell for `downgraded_to_free` gets no `when` branch and is inert (`d12-downgraded-to-free-cell`).
- **The `trial_converted_to_paid` branch is written now and is not dead code** (D6). Do not remove it, comment it out, or report it as unreachable.
- Do not comment the callback out (D8). Do not add any branch not in D15's table.

---

#### T4 — Give `enqueue_posthog_track` a `person_properties` parameter — implements D15

**File:** `app/models/subscription_event.rb` (private method, lines 57–61)

```ruby
  def enqueue_posthog_track(person_properties)
    return unless organization&.owner

    PosthogTrackJob.perform_later(organization.owner.id, event_type, posthog_properties(person_properties))
  end
```

- **The merge happens INSIDE this method, after the `return unless organization&.owner` guard.** `posthog_properties` assigns `owner = organization.owner` (line 64) and dereferences `owner.utm_source` (line 71) with no nil check; building the merged hash in the callback body moves that dereference in front of the guard and raises `NoMethodError` on an ownerless organization (`organizations.owner_id` is nullable) (`d15-enqueue-posthog-track-arity`, `d15-set-key-placement`).
- **Required, not optional, parameter.** A `= {}` default would let a caller ship `"$set": {}`.
- Do not add a second `PosthogTrackJob.perform_later` and do not call `POSTHOG_CLIENT` directly — person properties ride on the existing capture (D12).
- Event name stays `event_type`; recipient stays `organization.owner.id` — the person is matched by `distinct_id` alone (D13).
- T3 is the only caller. `grep -rn "enqueue_posthog_track\|posthog_properties" app/ spec/ db/ lib/` returns hits in this file only.

---

#### T5 — Add `'$set'` inside the `posthog_properties` literal and convert `amount` to dollars — implements D12, D13, D14

**File:** `app/models/subscription_event.rb` (private method, lines 63–85)

Two edits:

**(a) Signature and `$set` placement.** `def posthog_properties(person_properties)`, and add `'$set' =>
person_properties` as the LAST pair inside the hash literal — after `ga_session_id: …` (line 83, which
gains a trailing comma) and BEFORE `}.compact` (line 84).

- The key must be the string literal `'$set' =>`. The label form `{ $set: … }` is a Ruby syntax error — `$set` is a global-variable name (`d12-set-key-literal`).
- Placement inside the literal is what makes `upgraded_plan`'s nil `$set` disappear for free: `.compact` runs on the literal, so a nil value is stripped. `posthog_properties.merge('$set' => …)` after the fact would ship `"$set": null`, because merge runs after compact (`d13-upgraded-plan-absent-set`, `d15-set-key-placement`).
- `Hash#compact` is shallow and drops nil only, so `is_paying: false` / `is_trialing: false` survive intact.

**(b) Amount in dollars.** Replace line 66 `amount: amount,` with:

```ruby
      amount: amount.present? ? amount.to_i / 100.0 : nil,
```

- Divisor is `100.0`, never `100` — `amount` is an integer column and `4999 / 100` truncates to `49` (D14; precedent `app/models/board_wwr_listing.rb:101` and `:103`).
- **The nil test comes BEFORE the `to_i`.** Written literally as `amount.to_i / 100.0`, every `canceled_subscription` row (D2: those rows carry no amount) sends `amount: 0.0`, which is not nil, survives `.compact`, and lands in PostHog as a real $0.00 payment — a fabricated fallback banned by core rule 10 (`d14-nil-amount-to-i-yields-zero`, `d14-nil-amount-to-i-fabricates-zero`, `posthog-properties-compact-drops-nils`).
- `x.present? ? y : nil` is the house ternary form (`organization.rb:571`, `board_wwr_listing.rb:280`).
- **KEEP `.compact`.** It is what makes a nil `amount`, `from_plan`, and `to_plan` absent rather than transmitted; deleting it would newly emit nil-valued keys for all fourteen attribution properties on every subscription event (`d14-compact-drops-nil-amount`, `d14-nil-amount-vs-compact`).
- Change nothing else in the hash (D13: "Nothing else about the PostHog payload changes"). Do not divide `amount` by 100 anywhere else — the column stays in cents.

**Final layout of `app/models/subscription_event.rb` after T1–T5:** `belongs_to` → enum comment block →
`enum event_type` → `after_commit` → `self.upgrade_detected?` → `resolve_from_plan` → `private` → TODO
block → `handle_after_commit_on_create` → `enqueue_posthog_track(person_properties)` →
`posthog_properties(person_properties)` → `attribution_value` (untouched).

---

### Area B — `app/interactors/create_subscription_event.rb`

This area touches ONE file. `app/models/subscription_event.rb` is Area A's; this area only calls
`SubscriptionEvent.upgrade_detected?`.

**Cross-area contract consumed here (owned by T1):** `SubscriptionEvent.upgrade_detected?(from_plan,
to_plan)` — positional arguments, returns a boolean, `&.include?` on both arguments so a nil `to_plan`
does not raise. Do not define it here.

**Cross-area contract consumed here (owned by T14/T15):**
`stripe_webhook_handler_job.rb:322` becomes `CreateSubscriptionEvent.call(organization: organization,
invoice: object)` and `:216` becomes `CreateSubscriptionEvent.call(organization: organization,
subscription: object)`.

---

#### T6 — Add the three-entry-shape dispatch at the top of `call` — implements D2 and the B1/B2 resolution

**File:** `app/interactors/create_subscription_event.rb`

Keep lines 6–14 exactly as they are. Immediately after line 14 and BEFORE anything that touches
`event_params`, insert:

```ruby
    subscription_event_attributes = if context.invoice.present?
                                      attributes_from_stripe_invoice(organization, context.invoice)
                                    elsif context.subscription.present?
                                      attributes_from_stripe_subscription(organization, context.subscription)
                                    else
                                      attributes_from_context
                                    end

    return unless subscription_event_attributes
```

Discriminator facts the implementer must not re-derive:

- `Interactor::Context < OpenStruct` (interactor-3.1.2 `context.rb:31`), so `context.invoice` and `context.subscription` read as nil — never `NoMethodError` — on the two `Organization` callers (`organization.rb:1131`, `organization.rb:1236`), and `context.event_type` reads as nil on the two webhook callers.
- `.present?` on a Stripe object is safe and always true: `Stripe::StripeObject#respond_to_missing?` (stripe-9.4.0 `stripe_object.rb:416-418`) answers `@values.key?(:empty?)` ⇒ false, so `Object#blank?` falls through to `!self` ⇒ false.
- Do NOT duck-type the object — `stripe_object.billing_reason` on a subscription raises `NoMethodError` via `stripe_object.rb:373-413` (`stripe-object-probe-raises`). Do NOT use `amount.nil?` as a discriminator — four event types produce null-amount rows (`d2-null-amount-discriminator-false`).
- **Four callers, not two** (B1/B2). The two webhook call sites pass distinct keys — `invoice:` and `subscription:` — because the two objects are different types with different D2 column tables. The two `Organization` callers pass a finished `event_type` and no Stripe object, and D11 declares them untouched, so the pre-classified entry shape must keep working byte-for-byte.

The hash the three helpers return always has exactly these five keys: `:event_type, :from_plan, :to_plan,
:stripe_subscription_id, :amount`. A helper returns nil when no row is to be created; the single
`return unless subscription_event_attributes` is the one place every no-row case exits — D3's renewal via
D6's `subscription_cycle`, D4 rules 2 and 4, D18's credit/plato skip, and any unlisted `billing_reason`.

---

#### T7 — Rewrite the `event_params` / duplicate-check / build sequence — implements D1, D2, D17

**File:** `app/interactors/create_subscription_event.rb`

Replace current lines 16–42 (the `event_params = {` literal through the end of the save if/else) with,
in this order:

```ruby
    event_params = {
      event_type: subscription_event_attributes[:event_type],
      to_plan: subscription_event_attributes[:to_plan]
    }

    event_params[:stripe_subscription_id] = subscription_event_attributes[:stripe_subscription_id] if subscription_event_attributes[:stripe_subscription_id].present?
    event_params[:amount] = subscription_event_attributes[:amount] if subscription_event_attributes[:amount].present?

    # Check for duplicate within last 24 hours. from_plan is deliberately not part of it.
    recent_duplicate = organization.subscription_events
                                   .where(event_params)
                                   .where('created_at >= ?', 24.hours.ago)
                                   .exists?

    context.fail!(message: 'Duplicate SubscriptionEvent created within the last 24 hours') if recent_duplicate

    event_params[:from_plan] = subscription_event_attributes[:from_plan]

    subscription_event = organization.subscription_events.build(event_params)

    if subscription_event.save
      ap 'Successfully created SubscriptionEvent'
      ap subscription_event.event_type
      context.subscription_event = subscription_event
    else
      context.subscription_event = subscription_event
      context.fail!(message: "Could not create SubscriptionEvent for organization with id #{organization.id}")
    end
```

What changed and why:

- **`from_plan:` is REMOVED from the hash literal** (it sits at line 18 today) and assigned on its own line AFTER `context.fail!`, so it is never part of `where(event_params)` (D17). D17's closing analogy is wrong about the existing code — `stripe_subscription_id` and `amount` are added at lines 22–23 BEFORE the check at 26–29 and ARE matched on, which is what D17's first paragraph requires of them. There is no existing "added afterwards" key; this sequence is new (`d17-analog-sequence-is-backwards`, `d17-param-hash-sequence-analogy`, `d17-duplicate-check-precedent-inverted`).
- **Do not gate the `from_plan` assignment on `.present?`.** A nil `from_plan` must be built as nil on `subscription_create` rows so T3's callback can resolve it.
- The two conditional adds keep their `.present?` form and their position above the check, now reading from `subscription_event_attributes` instead of `context`.
- **The whole derive → D18 guard → D19 convert → D4/D16 classify sequence (T6 and T10–T12) runs ABOVE this block.** Appended below it, the check would run with `event_type: nil` (matching nothing, so redelivered `invoice.paid` webhooks create duplicate rows) and `build` would fall to the column default `0` = `pending`, which D1 declares a defect (`d17-classify-before-duplicate-check`).
- Line 37's `ap context.event_type` becomes `ap subscription_event.event_type`, because `context.event_type` is nil on both webhook paths now. Nothing else in the save block changes — keep both `context.subscription_event =` assignments and both `context.fail!` messages verbatim.

---

#### T8 — Add private `attributes_from_context` — implements D2 ("derivation runs only when a Stripe object is present") and D11

**File:** `app/interactors/create_subscription_event.rb`

Open a `private` section at the bottom of the class and add:

```ruby
  # The four callers arrive in three shapes: an invoice (invoice.paid), a
  # subscription (customer.subscription.deleted), or a finished event_type from
  # Organization with no Stripe object.
  def attributes_from_context
    {
      event_type: context.event_type,
      from_plan: context.from_plan,
      to_plan: context.to_plan,
      stripe_subscription_id: context.stripe_subscription_id,
      amount: context.amount
    }
  end
```

A straight passthrough of the five context keys the interactor reads today (current lines 17–23). It
exists so `Organization#handle_subscription_status_change_after_commit` (`organization.rb:1131` —
`event_type: 'trial_started', to_plan: plan, stripe_subscription_id: stripe_subscription_id`) and
`Organization#log_assigned_free_plan_event` (`organization.rb:1236-1241` — `event_type:`, `from_plan:
previous_plan`, `to_plan: current_plan`) keep working unchanged. No derivation, no Stripe read, no
classification runs on this path. Both callers always supply `event_type`, so this helper never yields a
nil `event_type` and no `pending` row can be built (D1).

---

#### T9 — Add private `attributes_from_stripe_subscription` — implements D2 (second table), D5, D9, D10

**File:** `app/interactors/create_subscription_event.rb`

```ruby
  def attributes_from_stripe_subscription(organization, subscription)
    ap subscription if Rails.env.development?

    # Cancelling changes subscription status, not plan, so the plan column still
    # holds the plan they are leaving. There is no plan to go to.
    {
      event_type: 'canceled_subscription',
      from_plan: organization.plan,
      to_plan: nil,
      stripe_subscription_id: subscription.id,
      amount: nil
    }
  end
```

- Every value is D2's second table and D5.
- **`organization.plan` IS read here.** D9's sentence "`organization.plan` is not read at creation" is scoped to the `invoice.paid` path, where `Organization#sync_with_stripe` (`organization.rb:574`) races the write. On the cancellation path the existing call site already reads it (`stripe_webhook_handler_job.rb:219`, with the comment at 214–215), and the ordering is safe: `organization&.update_column(:subscription_canceled_at, …)` at `:208` and the `sync_with_stripe` identity gate at `:205` both run before the interactor call at `:216` (`d9-vs-d2-d5-organization-plan-at-creation`). Dropping it would save every cancellation with `from_plan: nil`, which then satisfies D9's trigger and fires a Stripe round-trip per cancellation.
- `subscription.id` is identical to what the call site passes today (`stripe_subscription_id = object.id`, `:173`).
- `amount` is nil — never 0.
- No Stripe API call. No credit/plato guard here — that guard is D18's and reads an invoice lookup key; AI-credit subscription deletions are already routed away at `:182`.
- The `ap subscription if Rails.env.development?` line is D10 — see T13 for the form fence.

---

#### T10 — Add private `attributes_from_stripe_invoice` — implements D2 (first table), D3, D6, D10

**File:** `app/interactors/create_subscription_event.rb`

```ruby
  # subscription_cycle creates no row: a renewal is not an event, and trial
  # conversion detection is unsettled. Any other billing_reason (manual,
  # subscription_threshold) creates no row either.
  def attributes_from_stripe_invoice(organization, invoice)
    ap invoice if Rails.env.development?

    case invoice.billing_reason
    when 'subscription_update'
      attributes_from_subscription_update_invoice(organization, invoice)
    when 'subscription_create'
      attributes_from_subscription_create_invoice(organization, invoice)
    end
  end
```

- `invoice.billing_reason` is the discriminator D2's three column headings are drawn from. The house precedent for branching on it is `OrganizationAiCreditPurchase#sync_subscription_invoice_grant` (`case billing_reason` at `organization_ai_credit_purchase.rb:199-217`), which also falls through to no action for unlisted reasons. D2 cites this analog as `#sync_grant`, which does not exist (`d2-sync-grant-does-not-exist`, `d2-billing-reason-and-analog-name`).
- **There is NO `else` and NO `when 'subscription_cycle'` body.** The case evaluates to nil for `subscription_cycle`, `manual`, `subscription_threshold` and anything else; the helper returns nil; T6's `return unless subscription_event_attributes` is the bare return that implements D6's skip. Do not add a dispatching else, do not raise, do not log an error — these are expected skips (`d6-subscription-cycle-skip-location`).
- Do NOT add a `billing_reason` guard in `app/jobs/stripe_webhook_handler_job.rb` — the skip lives here.

---

#### T11 — Add private `attributes_from_subscription_update_invoice` — implements D2, D4, D7, D16, D18, D19

**File:** `app/interactors/create_subscription_event.rb`

```ruby
  def attributes_from_subscription_update_invoice(organization, invoice)
    old_line = invoice.lines.data.find { |line| line.amount.negative? }
    new_line = invoice.lines.data.find { |line| line.amount.positive? }

    to_lookup_key = new_line&.price&.lookup_key.to_s
    return if to_lookup_key.include?('credit') || to_lookup_key.include?('plato')

    from_lookup_key = old_line&.price&.lookup_key
    from_plan = organization.assign_plan_name_from_lookup_key(lookup_key: from_lookup_key) if from_lookup_key.present?
    to_plan = organization.assign_plan_name_from_lookup_key(lookup_key: to_lookup_key) if to_lookup_key.present?

    event_type = if from_plan.nil? || from_plan.include?('free')
                   'converted_to_paid'
                 elsif from_plan == to_plan
                   nil
                 elsif SubscriptionEvent.upgrade_detected?(from_plan, to_plan)
                   'upgraded_plan'
                 end

    return unless event_type

    {
      event_type: event_type,
      from_plan: from_plan,
      to_plan: to_plan,
      stripe_subscription_id: invoice.subscription,
      amount: invoice.amount_paid
    }
  end
```

Point by point, none of which may be substituted:

- **Line selection is the negative/positive pair, never `lines.data.first`.** The analog is `organization_ai_credit_purchase.rb:207-208`, duplicated at `apply_ai_credit_upgrade.rb:41-42` (SPEC "Do not unify the two line selections").
- **`Array#find` returns nil when no line matches** — a $0 free plan being upgraded has a proration line of amount 0, and `0.negative?` is false, which is exactly D4's nil-`from_plan` case. So the line objects are safe-navigated (`old_line&.price&.lookup_key`). Do NOT copy the analog's `if old_line && new_line` gate: requiring a negative line would kill the feature's primary case (`d2-line-find-returns-nil-object`).
- **`.to_s` before `include?` on the destination key** is the house form from `previous_main_plan_invoice` (`stripe_webhook_handler_job.rb:391`); it makes the D18 guard nil-safe. The guard runs on the RAW lookup key, before conversion, and bare-returns with nothing logged. It is deliberately not `OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?` (`d18-nil-lookup-key-guard`).
- **D19:** `assign_plan_name_from_lookup_key` (`organization.rb:683` → `Stripe::SubscriptionStatusChecker#assign_plan_from_lookup_key`, `subscription_status_checker.rb:113-119`) is called ONLY when the key is present, because it answers a nil key with `@organization.plan`. A blank key leaves the plan nil.
- **D4's four rules run in exactly this order**, and the `elsif from_plan == to_plan` branch's `nil` value is deliberate (rule 2, "no row when the two plans are equal"). The free test is `include?('free')` on the plan NAME, not `PAID_PLANS` membership.
- **Write the classification as one if/elsif expression, not as `return '<value>' if …` guards.** Value-returning guard clauses are banned by `code_style_and_structure.md` "Method Return Patterns" and core rule 8; the three existing offenders are the methods T16 deletes (`value-returning-guard-clauses`).
- `SubscriptionEvent.upgrade_detected?` (T1) is reached only after rules 1 and 2, so `from_plan` is a paid non-free plan name; `to_plan` may still be nil, which the class method handles with `&.include?`.
- **No row is created for a tier decrease or an equal tier (D7):** `event_type` stays nil and the helper bare-returns.
- `amount` is `invoice.amount_paid` in cents, unconverted; `stripe_subscription_id` is `invoice.subscription`.

---

#### T12 — Add private `attributes_from_subscription_create_invoice` — implements D2, D18, D19

**File:** `app/interactors/create_subscription_event.rb`

```ruby
  def attributes_from_subscription_create_invoice(organization, invoice)
    to_lookup_key = invoice.lines.data.first&.price&.lookup_key.to_s
    return if to_lookup_key.include?('credit') || to_lookup_key.include?('plato')

    to_plan = organization.assign_plan_name_from_lookup_key(lookup_key: to_lookup_key) if to_lookup_key.present?

    {
      event_type: 'converted_to_paid',
      from_plan: nil,
      to_plan: to_plan,
      stripe_subscription_id: invoice.subscription,
      amount: invoice.amount_paid
    }
  end
```

- This branch reads `lines.data.first` — **deliberately different from T11's negative/positive selection, and the difference is load-bearing** (the same split the analog makes at `organization_ai_credit_purchase.rb:200-201` vs `:207-208`).
- `event_type` is unconditionally `'converted_to_paid'` per D2's table. No classification, no call to `upgrade_detected?` here.
- **`from_plan` is nil and STAYS nil.** Do not substitute `organization.plan`, `'unknown'`, or anything else; T3's callback resolves it after commit (SPEC "Do not fabricate a `from_plan` value").
- The same D18 raw-key guard with the same `.to_s` form runs before the D19 conversion.

---

#### T13 — D10 logging fence: exactly two dev-guarded `ap` lines, one per Stripe object shape — implements D10

**File:** `app/interactors/create_subscription_event.rb`

No new code beyond what T9 and T10 already contain. The only D10 lines are the first line of
`attributes_from_stripe_invoice` (`ap invoice if Rails.env.development?`) and the first line of
`attributes_from_stripe_subscription` (`ap subscription if Rails.env.development?`). Placing them at the
top of those helpers means the object is printed for every Stripe object the interactor receives,
including invoices that go on to create no row (`subscription_cycle`, `manual`, credit/plato skips).

- `ap`, never `pp` (`core_critical_rules.md` rule 3).
- Trailing `if Rails.env.development?` — the house form for dumping an object during a flow, 32 uses in `app/`, e.g. `registrations_controller.rb:280` and `invites_controller.rb:69-70` (`d10-dev-only-print-form`).
- Do NOT copy the unguarded prints already in this file (lines 7, 13–14) — those run in every environment and D10 says local development only.
- Do NOT add a print in `attributes_from_context` (no Stripe object exists on that path), and do NOT build a combined `context.invoice || context.subscription` local just to print.

---

### Area C — `app/jobs/stripe_webhook_handler_job.rb`

Runs last: the call sites must not point at an interactor signature that does not exist yet, and the
deletions must not remove `Stripe::Invoice.list` / `Stripe::Subscription.retrieve` before T2 re-homes
them.

---

#### T14 — Replace the `customer.subscription.deleted` call site — implements D2 (second table), D5, B1/B2

**File:** `app/jobs/stripe_webhook_handler_job.rb`

Inside the existing `begin` (212) / `if organization` (213) / `rescue StandardError => e` (224–227)
structure, replace ONLY lines 216–222:

```ruby
              CreateSubscriptionEvent.call(
                organization: organization,
                event_type: 'canceled_subscription',
                from_plan: organization.plan,
                to_plan: nil,
                stripe_subscription_id: stripe_subscription_id
              )
```

with (14-space indent on `CreateSubscriptionEvent.call(` and the closing `)`, 16-space on the two
argument lines, matching the current block):

```ruby
              CreateSubscriptionEvent.call(
                organization: organization,
                subscription: object
              )
```

- `object` is `event.data.object` (assigned at line 48); in this branch it is the `Stripe::Subscription`. Its `id` is what the local `stripe_subscription_id` (line 173) holds, so the interactor gets the same value from `subscription.id` per D2's second table.
- `event_type:`, `from_plan:`, `to_plan:` are now derived inside the interactor per D2/D5. Do NOT keep any of them, and do NOT pass `stripe_subscription_id:` alongside `subscription:`.
- The key name is `subscription:` — not `stripe_subscription:`, not a generic `stripe_object:` (B1 resolution; precedent `apply_ai_credit_upgrade.rb:27`, `apply_ai_credit_subscription.rb:16`, `organization_ai_credit_purchase.rb:123`).
- KEEP in the same hunk: the two comment lines 214–215, the `if organization` guard at 213, the `begin`, and the rescue at 224–227 including its `Rails.logger.error "Stripe subscription.deleted SubscriptionEvent ledger error: …"` and `ap e`. The local `stripe_subscription_id` (173) stays live — it is still read at 188, 201, 205 and 225.
- No main-subscription identity check is added.

---

#### T15 — Replace the `invoice.paid` call site, keeping the zero-amount guard — implements D2 (first table), D3, D4, D11, D16, D18, D19, B1/B2

**File:** `app/jobs/stripe_webhook_handler_job.rb`

Inside the existing `begin` (316) / `rescue StandardError => e` (332–335), replace lines 318–330 — the
two locals, the blank line, the `if subscription_event_type` wrapper and the six-argument call:

```ruby
              previous_invoice = previous_main_plan_invoice(object)
              subscription_event_type = subscription_event_type_for(organization, object, stripe_subscription, subscription_lookup_key, previous_invoice)

              if subscription_event_type
                CreateSubscriptionEvent.call(
                  organization: organization,
                  event_type: subscription_event_type,
                  from_plan: previous_plan_name(organization, object, previous_invoice),
                  to_plan: organization.assign_plan_name_from_lookup_key(lookup_key: subscription_lookup_key),
                  stripe_subscription_id: object.subscription,
                  amount: object.amount_paid
                )
              end
```

with (14-space indent on `CreateSubscriptionEvent.call(` and the closing `)`, 16-space on the two
argument lines — one level shallower than today, because the `if subscription_event_type` wrapper is
gone):

```ruby
              CreateSubscriptionEvent.call(
                organization: organization,
                invoice: object
              )
```

- `object` here is the `Stripe::Invoice`. Everything the deleted arguments computed — `event_type`, `from_plan`, `to_plan`, `stripe_subscription_id`, `amount` — is derived inside `CreateSubscriptionEvent` off that invoice per D2's first table, D4, D16, D18, D19. Do NOT pass any of them.
- **LINE 317 STAYS EXACTLY AS IS:** `if object.amount_paid.to_i > 0` remains the enclosing conditional and the new call goes inside it. It is the only implementation of D3's "a zero-amount invoice creates nothing" and is not one of D11's five deletions. **Cross-area contract:** because it stays, `CreateSubscriptionEvent` must NOT add a second zero-amount guard — exactly one, never zero and never two (`d3-zero-amount-guard-placement`). If it were dropped here, a trial's $0 `subscription_create` invoice would reach the interactor and produce a false `converted_to_paid` row with `amount` persisted as 0 (`0.present?` is true in ActiveSupport), plus a false `$set is_paying: true` PostHog event at trial start.
- KEEP UNCHANGED in and around the hunk: `Stripe::Subscription.retrieve(object.subscription)` at 300 and `subscription_lookup_key` at 301 (still read at 303 and 308); the `CustomStripeSubscriptionMissingError` raise at 306; the `updated = organization.update(…)` block at 308–312; `organization.stripe_update_default_payment_method` at 313; `organization.organization_ai_credit_balance&.reset_ai_credits` at 314; the `begin` at 316; the rescue at 332–335 with its `Rails.logger.error "Stripe invoice.paid SubscriptionEvent ledger error: …"` and `ap e` (every interpolated identifier in that message is still in scope).
- After the replacement no local named `previous_invoice` or `subscription_event_type` exists in the branch; `subscription_lookup_key` and `stripe_subscription` remain in use, so neither becomes an unused local.

---

#### T16 — Delete the five D11 members (lines 383–446) — implements D11 and D9's relocation

**File:** `app/jobs/stripe_webhook_handler_job.rb`

Delete lines 383 through 446 inclusive — the contiguous run of five private members, their leading
comments, and the trailing blank line:

- 383–384 comment, 385 `TRIAL_CONVERSION_WINDOW_DAYS = 15`, 386 blank
- 387–388 comment, 389–396 `def previous_main_plan_invoice(invoice)` … `end` (holds `Stripe::Invoice.list(customer: invoice.customer, limit: 20)` at 390 and the credit/plato reject block), 397 blank
- 398–400 comment, 401–413 `def previous_plan_name(organization, invoice, previous_invoice)` … `end` (holds `Stripe::Subscription.retrieve(previous_invoice.subscription)` at 405 and `return 'canceled' if previous_subscription.status == 'canceled'` at 406), 414 blank
- 415–416 comment, 417–423 `def trial_conversion?(invoice, stripe_subscription, previous_invoice)` … `end`, 424 blank
- 425–426 comment, 427–445 `def subscription_event_type_for(organization, invoice, stripe_subscription, new_lookup_key, previous_invoice)` … `end`, 446 blank

After the deletion the file reads `  private` (381), one blank line (382), then `  def
handle_subscription_schedule_downgrade(schedule_object)` — exactly one blank line between them.

- These hold the only two Stripe calls D9 relocates; T2 re-homes them in `SubscriptionEvent#resolve_from_plan`. This task deletes them and adds nothing in their place.
- Reference-freeness verified at `ada2feb9a`: `grep -rn` across `app/ lib/ spec/ db/ config/` finds `TRIAL_CONVERSION_WINDOW_DAYS` only at 385 and 419; `previous_main_plan_invoice` only at 318 and 389; `trial_conversion?` only at 417 and 428; `subscription_event_type_for` only at 319 and 427; this file's `previous_plan_name` only at 325, 401 and 430. The identically-named LOCAL variable in `app/jobs/discord/notify_subscription_plan_changed_job.rb:11,21,37` is unrelated and must not be touched. Every call site is inside T14/T15's replaced ranges or inside this deletion range.
- After this deletion the job no longer references `Stripe::SubscriptionStatusChecker::PAID_PLANS` (was 431) or `FREE_PLANS_WITH_ONE_JOB` (was 440). Do NOT delete, move, or edit those constants or `app/services/stripe/subscription_status_checker.rb`.

---

#### T17 — Diff invariant check for `stripe_webhook_handler_job.rb`

Run `git diff app/jobs/stripe_webhook_handler_job.rb` and confirm it contains **exactly three hunks** —
T14's call-site replacement, T15's call-site replacement, T16's deletion — and nothing else. Anything
else in the diff is a defect regardless of how correct it looks.

Then run:

```
grep -n 'TRIAL_CONVERSION_WINDOW_DAYS\|previous_main_plan_invoice\|previous_plan_name\|trial_conversion?\|subscription_event_type_for' app/jobs/stripe_webhook_handler_job.rb
```

and confirm zero matches. Then `ruby -c app/jobs/stripe_webhook_handler_job.rb` to confirm the file
parses.

Do not reformat, re-indent, or re-quote any untouched line — `.claude/CLAUDE.md` limits linter fixes to
lines you wrote.

---

## Manual verification

Rule 0a: no test file is written for any of this. Everything below is exercised by hand against Stripe
test mode with the webhook forwarded to the local Rails server, plus `rails runner` / `rails console`
reads. Report what was actually observed.

**Interactor / row-creation paths**

1. **Paid → higher paid tier** (`subscription_update` invoice with a negative and a positive line). Then `rails runner 'ap Organization.find(<id>).subscription_events.last.attributes'`: exactly one row, `event_type` `upgraded_plan`, `from_plan` the old plan NAME, `to_plan` the new plan NAME, `amount` the proration in cents, `stripe_subscription_id` = `invoice.subscription`.
2. **Free → paid mid-cycle** (`subscription_update` with no negative-amount line, because a $0 proration credit is not `negative?`). Exactly one `converted_to_paid` row — this proves the `find`-returns-nil path does not raise. Grep the dev log for `Stripe invoice.paid SubscriptionEvent ledger error` to confirm nothing was swallowed.
3. **Brand-new paid subscription** (`subscription_create` invoice). One `converted_to_paid` row whose `from_plan` is nil at creation time, then written by the callback (step 10).
4. **Renewal** (`subscription_cycle`, e.g. via a Stripe test clock). NO new `subscription_events` row for that organization.
5. **Paid → lower paid tier** via `subscription_update`: NO row. Then a same-plan `subscription_update` (seat/quantity change): NO row.
6. **Cancel a main-plan subscription.** One `canceled_subscription` row with `from_plan` = the organization's `plan` column value, `to_plan` nil, `amount` nil, `stripe_subscription_id` = the deleted subscription's id. Confirm the surrounding handler still runs: `organizations.subscription_canceled_at` written, `Notification::PaidSubscriptionDeletedJob` and `EngagementReport::GeneratorJob` enqueued.
7. **AI credit subscription upgrade or renewal** (a `plato`/`credit` lookup key): NO `subscription_events` row, and no error logged for it. Also pay an AI credit subscription invoice and confirm it still routes to `handle_subscription_credit_pack_invoice_paid` (credits granted, `OrganizationAiCreditPurchase` updated).
8. **Trial start in the app**: the `trial_started` row is still written with the same values as before this branch. **Create a new organization**: the `assigned_free_plan_on_creation` row is still written. Both take the pre-classified path and must be unchanged.
9. **Re-deliver the same `invoice.paid` event** from the Stripe dashboard within 24 hours: no second row, and the interactor result message reads `Duplicate SubscriptionEvent created within the last 24 hours`.

**Callback / PostHog / Discord**

10. On the step-3 conversion, confirm the PostHog `converted_to_paid` event carries `from_plan` (resolved by the callback), `to_plan`, `amount` as a decimal (e.g. `49.99`, not `4999` and not `49`), and `$set { is_paying: true, is_trialing: false }`.
11. In the PostHog UI, open the person for that organization's owner and confirm `is_paying` / `is_trialing` actually changed on the PERSON — event properties alone would not, which is the whole point of `$set`.
12. On the step-6 cancellation, confirm the PostHog capture has NO `amount` key at all (compacted away, not `0.0`), carries `$set { is_paying: false, is_trialing: false }`, and that the Discord subscription-deleted message still posts with the correct cancellation timestamp (the two-argument `perform_later`).
13. On the step-8 trial start, confirm `Discord::NotifyFreeTrialStartedJob` still fires and the PostHog `trial_started` capture carries `$set { is_trialing: true }`. **Expect a `from_plan` on the row and in the payload where there was none before** — that is D9 running on nil-`from_plan` rows (B3 withdrawn) and is intended, not a regression.
14. On the step-1 upgrade, confirm a PostHog `upgraded_plan` event arrives (it dispatched nothing before), the payload has NO `$set` key whatsoever — not `"$set": null`, not `"$set": {}` — and no Discord message posts.
15. **New organization with no `stripe_customer_id`:** org creation completes normally, the `assigned_free_plan_on_creation` row dispatches nothing to PostHog or Discord, and no `Stripe::Invoice.list` request goes out (the `stripe_customer_id` guard bails first).
16. `rails runner` sanity check, no side effects: `SubscriptionEvent.upgrade_detected?('plan_ats_tier_starter_v2', 'plan_ats_tier_growth_v2')` → `true`; `('plan_ats_tier_growth', 'plan_ats_tier_starter')` → `false`; `('plan_ats_tier_starter', nil)` → `false` and does not raise.
17. `rails runner` against a real organization with invoice history: `SubscriptionEvent.last.resolve_from_plan` returns a plan name, `'canceled'`, or nil, does not raise, and the Stripe request log shows exactly one `Stripe::Invoice.list` per call.
18. **Force the helper's failure path** (e.g. a row whose organization has a `stripe_customer_id` Stripe rejects): the log line is written, the row keeps its `event_type`, `from_plan` stays nil, PostHog/Discord dispatch still runs — and `from_plan` is NOT the exception's message.

**Regression sweeps on the untouched paths**

19. On any paid `invoice.paid`, `organizations.stripe_current_period_end_at` is still updated and the default payment method still synced (proves the `Stripe::Subscription.retrieve` at 300 was not moved).
20. Fire a `subscription_schedule.updated` downgrade and confirm `Discord::NotifyDowngradeScheduledJob` still enqueues (proves `downgrade_detected?` and `handle_subscription_schedule_downgrade` are intact).
21. In development, watch the console during one `invoice.paid` and one `customer.subscription.deleted` and confirm the full Stripe object prints once per event from the interactor. Read the code to confirm both `ap` lines carry `if Rails.env.development?`.
22. Run T17's diff/grep/parse checks.

---

## Out of scope

Things an implementer will be tempted to do and must not:

1. **No RSpec spec file, no new example in an existing one, for any part of this feature** (`.claude/CLAUDE.md` rule 0a). Coverage opinions go in the final report only.
2. **No second zero-amount guard.** `if object.amount_paid.to_i > 0` at `stripe_webhook_handler_job.rb:317` stays and is the only one. If it turns up missing, escalate rather than adding one in the interactor.
3. **No `|| 'unknown'`, no `|| organization.plan`, no `''`, no `|| 0`** for a nil `from_plan`, `to_plan`, or `amount` (core rule 10; SPEC "Do not fabricate a `from_plan` value"). The backfill's `from_plan: 'unknown'` is an artifact, not a precedent.
4. **No division of `amount` by 100 outside `posthog_properties`.** The column stays in cents.
5. **No `Stripe::` API call in `CreateSubscriptionEvent`.** Every value comes off the object it is handed (D2). The two relocated calls live only in `SubscriptionEvent#resolve_from_plan`.
6. **No `billing_reason` branch, no `subscription_cycle` skip, and no `credit`/`plato` guard in `stripe_webhook_handler_job.rb`.** Those belong to the interactor (D6, D18).
7. **No D10 print in the job**, and none in `attributes_from_context`.
8. **No main-subscription identity check** at either call site (`if object.subscription == organization.stripe_subscription_id` or similar).
9. **No changes to `app/models/organization.rb`.** Both `CreateSubscriptionEvent` call sites keep their exact argument lists (D11).
10. **No `when 'downgraded_to_free'` or `when 'downgraded_plan'` branch** in T3's `case`. D12's `is_paying: false` cell for `downgraded_to_free` is inert until downgrades are recorded elsewhere (`d12-downgraded-to-free-cell`, D7).
11. **Do not remove or comment out the `trial_converted_to_paid` branch** as unreachable or dead — the unreachability is deliberate and temporary (D6).
12. **Do not touch `Stripe::SubscriptionStatusChecker`, `DisableAutomationsOnDowngrade`, or `Discord::NotifySubscriptionPlanChangedJob`.**
13. **Do not reformat, re-indent, or re-quote untouched lines**, and do not run linter auto-fix on any whole file (`.claude/CLAUDE.md` "Linter & Formatting Scope").
14. **Do not commit, stage, or create a git worktree** as part of executing this plan.

**Two pre-existing conditions this plan deliberately does NOT address — escalate, do not fix:**

- **Enum renumbering has no row backfill** (`d1-enum-renumber-no-row-backfill`). `ada2feb9a` inserted `pending: 0` and shifted every existing `event_type` integer by +1, and no data migration shifts the historical rows, so every pre-branch row now decodes one name lower. This changes what D1's "a row at `pending` is a defect" diagnostic means for historical rows and what T3's `case` sees on them. Any renumber has to be scoped to rows written before this branch's code loaded, and the correct scoping depends on whether `db/data/20260727185945_…` has already run in a given environment. That is its own spec, not part of this feature.
- **The existing backfill fires the new dispatch on deploy** (`d15-backfill-fires-new-dispatch-on-deploy`). `bin/heroku-release:26` runs `data:migrate` on every release, and `db/data/20260727185945_…:37` calls `SubscriptionEvent.create` per paid organization — which now enters T3's `case`, posting one Discord "Trial converted to paid" per trial-era organization and one PostHog capture per `converted_to_paid` row, at deploy time. Those rows carry `from_plan: 'unknown'`, so `resolve_from_plan` does not fire on them and no extra Stripe calls result. Blast radius is the paid-organization count. Flagged for Jessica's decision before deploy; this plan changes nothing about it.
