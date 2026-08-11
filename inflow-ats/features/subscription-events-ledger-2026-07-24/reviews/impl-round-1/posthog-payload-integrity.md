# Angle 5 — PostHog payload integrity — impl round 1

**Reviewed:** `posthog_properties` + `attribution_value` + `enqueue_posthog_track` on `SubscriptionEvent`; `app/jobs/posthog_track_job.rb` and `app/services/posthog/track.rb` (both untouched, read live); schema columns for all 13 attribution fields on both tables; executed property-hash specs plus a scratchpad falsifiability probe.

## Findings: 0 BLOCKER / 0 HIGH / 0 MED / 0 LOW

## Verification detail

- **Call shape:** `PosthogTrackJob.perform_later(organization.owner.id, event_type, posthog_properties)` — matches the billing_controller analog shape (`PosthogTrackJob.perform_later(user_id, event, properties)`; job signature `perform(user_id, event, properties = {})` verified live). Event name = enum name string (`trial_started`, `trial_converted_to_paid`, `converted_to_paid`, `canceled_subscription`).
- **DB-local only:** properties built from the row (`amount`, `stripe_subscription_id`, `to_plan`), `organization` (`stripe_customer_id`, 13 attribution cols), `owner` (13 attribution cols). Zero Stripe calls in the fan-out path.
- **No default duplication / no collisions:** `email`/`organization_id`/`organization_name`/`plan` absent from the custom hash — they ride `Posthog::Track#default_properties`; `default_properties.merge(@properties)` would let a custom key override on collision, and none of the 17 custom keys collides (`to_plan` ≠ `plan`). Executed evidence: the fanout spec asserts the four default keys are NOT in the enqueued hash.
- **Attribution:** exactly the 13 spec'd fields, each `attribution_value(owner.<col>, organization.<col>)`. All 13 columns verified present on BOTH `users` and `organizations` in db/schema.rb (per-column grep, 13/13 on each). Helper is the D10 shape verbatim: full if/elsif/else, `present?` tests, explicit `nil` else, NO `.presence` (diff-wide grep: zero `.presence`, zero `|| 0`/`|| ''` in app code). Hash `.compact`ed — nil keys never sent; `amount` rides only conversion rows (nil elsewhere → compacted away).
- **`billing_interval` ABSENT** (RESOLVED-at-go flagged deviation — its presence would have been a finding; it is not there). **No groups, no `$set`/`$set_once`** (D9) — confirmed absent.
- **`utm_data` is jsonb** on both tables — `present?` and ActiveJob serialization both handle the Hash; `PosthogTrackJob` `deep_symbolize_keys` handles nesting.
- **Bail-out:** `return unless organization&.owner` (defensive; `belongs_to :owner, class_name: 'User'` at organization.rb:41 is required). `posthog_properties` is only reached behind that bail-out, so its `organization.owner` access is safe.
- **Assertions proven non-vacuous:** the fanout spec's property examples use the block form `have_enqueued_job(PosthogTrackJob).with { |_user_id, _event, properties| … }` — no prior codebase precedent for the block form, so I probed it: a scratchpad spec with a deliberately wrong in-block assertion (`properties[:to_plan]` vs a wrong value) FAILS, proving rspec-rails invokes the block with the deserialized args. The owner-first/org-fallback/absent-key/compact/amount-presence assertions are therefore real coverage, not vacuous passes.
