# Angle 5 — PostHog payload integrity (spec round 1)

Verified against `app/jobs/posthog_track_job.rb`, `app/services/posthog/track.rb`, `db/schema.rb` (organizations + users attribution columns), `app/controllers/api/v1/billing_controller.rb:115,213,311`.

## Verifications (clean)

- Call shape matches the analog exactly: `PosthogTrackJob.perform_later(user_id, event, properties)` — job signature `perform(user_id, event, properties = {})`, `find_by(id:)` + bail on nil, `deep_symbolize_keys`. §7's `perform_later(organization.owner.id, <event name>, properties)` conforms.
- Default-property collision audit: `Posthog::Track#track` sends `default_properties.merge(@properties)` — custom keys OVERRIDE defaults on collision. The spec's full key set (`amount`, `stripe_subscription_id`, `stripe_customer_id`, `to_plan`, 13 attribution keys) has zero overlap with defaults (`email`, `organization_id`, `organization_name`, `plan`); `to_plan` deliberately avoids shadowing `plan`. Clean.
- All 13 attribution columns verified present on BOTH `organizations` and `users` in schema.rb: `utm_source`, `utm_campaign`, `utm_data` (jsonb — `present?` works), `internal_ref`, `google_click_id`, `adroll_click_id`, `adroll_first_party_cookie`, `fbclid`, `fbp`, `fbc`, `li_fat_id`, `ga_client_id`, `ga_session_id`.
- `attribution_value` — grep confirms zero existing definitions at a0d59115d; the new helper name collides with nothing. D10 shape (full if/elsif/else, `present?` tests, explicit `nil` else, no `.presence`) is spelled out in §7.
- `.compact` on the assembled hash satisfies rule 10 (absent fields never sent, no fabricated fallbacks). `amount` present only on conversion rows via the same `.compact`.
- `billing_interval` correctly ABSENT (RESOLVED-at-go deviation, flagged in §7); no groups, no `$set`/`$set_once` (D9).
- DB-local-only constraint holds: every property source is the row, the organization, or the owner — no Stripe calls at fan-out time.

## Findings

None. No amendments from this angle.
