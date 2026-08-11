# Handoff: server-to-server conversion forwarding

**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`
**Branch:** `server-side-conversion-events`, already created off `develop` at `04a5c2d57`. PR #3080 merged.

**First task: write Jessica the instructions for obtaining the GA4 credentials.** The Measurement Protocol needs a measurement ID and an API secret. Before any code, give her step-by-step directions for where in the GA4 admin interface each one is created and found, and confirm whether either already exists in `config/initializers/01_variables.rb` or the `.env`. Never edit `.env` yourself — tell her what to add and let her do it.

## The two phases

**Phase 1 — Google Analytics.** Send conversion events server-side via the **GA4 Measurement Protocol**. This is the whole of the current work.

**Phase 2 — AdRoll.** Server-to-server conversion events. **Not now.** Do not build it, do not design for it, do not add abstractions in anticipation of it. AdRoll has issued Jessica only a single key, which is the same one production uses, so testing is constrained and she needs to work out that setup before the phase starts.

Both are transport work. The events, the trigger point, and the identifiers all already exist.

---

## 1. The fan-out point already exists — do not abstract it

`SubscriptionEvent#handle_after_commit_on_create` (`app/models/subscription_event.rb`) is where PostHog and Discord already dispatch from. It is a `case event_type` with a statement block per branch, deliberately shaped so additional `perform_later` calls sit alongside the existing ones.

**Jessica has explicitly ruled out designing an abstraction ahead of real payloads.** Do not propose an adapter layer, a platform registry, a generic `analytics_properties` rename, or a plugin interface. The inputs these APIs need are not yet known. Add branches and jobs; revisit structure when there are real payload shapes to generalise from.

Follow the existing shape: enqueue a job (`SomeJob.perform_later(...)`), never call an external API inline from the callback.

## 2. The event type names changed on 2026-07-29 — use the new ones

| enum key | int | status |
|---|---|---|
| `converted_to_paid` | 3 | **retroactive only** — appears in no `when` branch |
| `trial_converted_to_paid` | 9 | **retroactive only** — appears in no `when` branch |
| `converted_to_paid_subscription` | 10 | live |
| `trial_converted_to_paid_subscription` | 11 | live |

A `when` branch added under the old names **will never execute**, and nothing will tell you: the `else` branch does a bare `return`, and there is no test coverage anywhere.

Background: the `db/data/20260727185945` migration backfilled the old two types for every existing paying organization. Because the `after_commit` fires on create, each row sent a PostHog event dated the migration run. PostHog has no event-level deletion, so those two names permanently contain that retroactive set — hence the rename rather than a cleanup. Backfilled rows are identifiable by `from_plan: 'unknown'`.

## 3. The identifiers are already captured and already on the payload

`SubscriptionEvent#posthog_properties` already assembles:

`amount`, `stripe_subscription_id`, `stripe_customer_id`, `from_plan`, `to_plan`, `billing_interval`, `utm_source`, `utm_campaign`, `utm_data`, `internal_ref`, `google_click_id`, `adroll_click_id`, `adroll_first_party_cookie`, `fbclid`, `fbp`, `fbc`, `li_fat_id`, `ga_client_id`, `ga_session_id`

GA4's Measurement Protocol requires `client_id` — that is `ga_client_id`, already present. AdRoll's needs are `adroll_click_id` and `adroll_first_party_cookie`, also present.

Each field goes through `attribution_value(owner_value, organization_value)`, which prefers the owner's value and falls back to the organization's, because the same identifier columns exist on **both** `users` and `organizations`. The hash is `.compact`ed, so absent identifiers are dropped rather than sent as nil.

The event is attributed to the organization **owner**: `PosthogTrackJob.perform_later(organization.owner.id, ...)`.

## 4. Timestamps — decide deliberately

`Posthog::Track#track` calls `POSTHOG_CLIENT.capture` with **no `timestamp`**, so PostHog dates events at ingestion. That is exactly why the backfill piled several hundred conversions onto a single day.

The codebase already has the counter-precedent: `TrackNewSsoOwnerSignupJob#capture` passes `timestamp:` explicitly, and uses fractional offsets (`base_timestamp + 0.001`) to force event ordering.

GA4 Measurement Protocol accepts `timestamp_micros`; AdRoll accepts an event time. Choose consciously rather than inheriting the omission.

## 5. `amount` is in cents

`posthog_properties` sends `amount: amount.to_i / 100.0`. The column is cents. Conversion value for ad platforms needs the same conversion.

Note `plan_simple_ats_per_job` organizations were written with `amount: 0` by the backfill, because per-job billing is driven by published job count and a single price is meaningless for them.

## 6. How to verify — there are no tests, so this is the harness

**Nothing under `spec/`, `test/` or `cypress/` references `SubscriptionEvent`.** Four spec files that did were deleted by `ada2feb9a` on 2026-07-28. Combined with the silent `else` → `return`, a wrong branch literal fails invisibly in every environment. Manual verification is the only signal.

Jessica has local development environments for PostHog and Discord, so **real calls from dev are fine and are the point** — do not stub them out.

### The harness that worked on 2026-07-29

Run with `bundle exec rails runner <script.rb>` from the repo root. Do not set `RAILS_ENV`; development is correct. Never set `DATABASE_URL`.

**a. Swap the queue adapter to `:inline`.**

```ruby
ActiveJob::Base.queue_adapter = :inline
```

`config/environments/development.rb:108` sets `:sidekiq`. Left alone, `perform_later` puts the job in Redis and the *Sidekiq worker process* executes it — the HTTP call happens somewhere you cannot observe. `:inline` runs the job inside your runner process, so you can read the outbound payload **and the real HTTP call still goes out**. This is the key move. `:test` would also let you inspect, but it suppresses the call entirely — wrong for this purpose.

**b. Prepend an echo module on the client to read, not block.**

```ruby
SENT = []

module PosthogCaptureEcho
  def capture(payload)
    SENT << { event: payload[:event], distinct_id: payload[:distinct_id], set: payload[:properties][:'$set'] }
    super
  end
end
POSTHOG_CLIENT.singleton_class.prepend(PosthogCaptureEcho)
```

`super` is what keeps the real delivery intact. For a GA or AdRoll client, prepend on whatever object holds the HTTP call and record the request body the same way. To observe a job rather than a client, alias its `perform`:

```ruby
DISCORD = []
Discord::NotifyTrialConvertedToPaidJob.class_eval do
  alias_method :perform_without_echo, :perform
  def perform(*args)
    DISCORD << self.class.name
    perform_without_echo(*args)
  end
end
```

**c. Build a real fixture, following `Cypress::UsersController#create`.**

```ruby
user = User.where(email: 'some-marker@wrkhq.com').first_or_create do |u|
  u.first_name = 'Some'
  u.last_name = 'Marker'
  u.password = 'password'
  u.password_confirmation = 'password'
end
user.confirm

organization = Organization.where(name: 'Some Marker Org').first_or_create do |o|
  o.owner_id = user.id
  o.is_claimed = true
end

organization.users.push(user) unless organization.users.include?(user)
user.reload.current_organization_user&.org_owner!
```

`organization.users.push(user)` is what creates the `OrganizationUser` through the has_many :through. `posthog_properties` calls `organization.owner`, so the owner must exist.

**d. Set the subscription columns by hand.**

```ruby
organization.update(
  plan: 'plan_ats_tier_starter_v2',
  stripe_subscription_id: "test_subscription_#{SecureRandom.hex(8)}",
  stripe_subscription_status: 'active',
  stripe_current_period_end_at: 1.month.from_now
)
```

These are exactly the columns `Organization#setup_paid_test_subscription` writes. **You cannot call that helper** — it and all its siblings begin `return unless Rails.env.test?`. Mirror it instead. This combination makes `organization.active_paid_plan?` true, which several code paths gate on.

**e. Always pass `from_plan` when creating the event.**

`handle_after_commit_on_create` runs `resolve_from_plan` whenever `from_plan` is nil, and that method makes **real Stripe API calls** (`Stripe::Invoice.list`, `Stripe::Subscription.retrieve`). Passing any non-nil value skips it. Use a marker string so the rows are identifiable and deletable:

```ruby
from_plan: 'ga4_verification'
```

**f. Assert the record persisted.**

```ruby
raise 'not saved' unless subscription_event.persisted?
```

The codebase forbids bang methods, so `create` returns an unsaved record on validation failure — and then `after_commit` never fires, and your harness reports "no events sent," which looks identical to a broken branch. This assertion is what distinguishes the two.

**g. Include a control event type.**

Create one event per type you touched *plus* one you didn't (`trial_started` works well). If the control stops emitting, you broke something shared rather than something specific.

**h. Flush before the process exits.**

```ruby
POSTHOG_CLIENT.flush
```

`posthog-ruby` batches and flushes on a background thread. A runner process that exits immediately can drop the events. Any new client library needs the equivalent check.

### The guard paths worth re-testing after any change

- Generated enum helpers resolve to the right integers (`SubscriptionEvent.event_types['converted_to_paid_subscription']` → 10)
- The 24-hour dedup guard in **both** `CreateSubscriptionEvent:28-33` and `CreateSubscriptionEventFromStripe:39-45` — keyed on `event_type` + `to_plan` + `stripe_subscription_id` (+ `amount` in the Stripe one)
- A legacy-type row does **not** block a new-type write inside that window — reviewed and accepted, not a bug
- The `trial_started` lookup at `create_subscription_event_from_stripe.rb:143-149` that gates trial conversions: requires a `trial_started` row for the same subscription within ±12 hours of the invoice period start

### Existing fixture, left in place in dev

User **143** `rename-guard-test@wrkhq.com`, organization **143** "Rename Guard Test Org", `plan_ats_tier_starter_v2` / `active`, `SubscriptionEvent` rows 49–53 spanning both legacy and new types.

---

## Known pre-existing bug, out of scope

`CreateSubscriptionEvent` and `CreateSubscriptionEventFromStripe` both wrap their whole body in `rescue StandardError`, and `Interactor::Failure` subclasses `StandardError` (`interactor-3.1.2/lib/interactor/error.rb:4`). So every deliberate `context.fail!` message — including the duplicate-guard message and the no-plan-change message — is swallowed and replaced with `"An error occurred while creating the SubscriptionEvent"`. The guards work; only their diagnostics are lost. Do not fix this as part of forwarding work.

## Related files from the prior session

`~/claude-hub/inflow-ats/_in-progress/sendgrid-list-2026-07-29/` holds the rename plan, the PostHog backfill write-up for Shelly and Justin, the Plato launch email, and the console functions for the SendGrid contact list and credit grants.
