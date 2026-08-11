# Plan review pass 1 — Angle 5: PostHog payload integrity

## Call shape

- `PosthogTrackJob#perform(user_id, event, properties = {})` verified live (posthog_track_job.rb:6). Planned `PosthogTrackJob.perform_later(organization.owner.id, event_type, posthog_properties)` matches the billing_controller analog shape — analog citations verified exact: api/v1/billing_controller.rb:115, 213, 311.
- Event name = enum name string (`event_type` getter) per RESOLVED-at-go.

## Properties (Task 4.1 `posthog_properties`)

- DB-local only: row (`amount`, `stripe_subscription_id`, `to_plan`) + organization (`stripe_customer_id`, 13 attribution cols) + owner (13 attribution cols). Zero Stripe calls at fan-out time. CORRECT per §7.
- `Posthog::Track#default_properties` verified live (track.rb:24–31): `email`, `organization_id`, `organization_name`, `plan` — NOT duplicated in the planned hash. `default_properties.merge(@properties)` means custom keys override on collision — verified NO planned key collides (`amount`, `stripe_subscription_id`, `stripe_customer_id`, `to_plan`, 13 attribution keys vs the 4 defaults). `to_plan` deliberately avoids shadowing `plan`. (Plan cites track.rb:25–32; def is at 24, hash 25–30 — content claim accurate, citation off by a hair; not worth amending.)
- All 13 attribution columns verified present on BOTH tables: users at schema.rb:1300–1312 (exact); organizations at schema.rb:1081 (`google_click_id`) + 1092–1103 (the other 12). The plan's original citation "organizations (schema.rb:1092–1103)" omitted `google_click_id`'s line — **MED-3 (source accuracy) — AMENDED**. The existence claim itself was true.
- `attribution_value`: D10 shape verbatim — full if/elsif/else, `present?` tests, explicit `nil` else, NO `.presence`. Final hash `.compact`ed — nil keys never sent; `amount` rides only conversion rows (nil elsewhere, compacted). No `|| 0` / `|| ''` anywhere (rule 10).
- `billing_interval` deliberately ABSENT (RESOLVED-at-go flagged deviation) — plan says "do not add it." CORRECT direction.
- No groups, no `$set`/`$set_once` (D9) — the planned code has none.
- `utm_data` is jsonb (Hash) — serializable through `perform_later`, same as existing callers' hash properties.

## Findings

- MED-3 (source accuracy): organizations attribution-column citation incomplete (google_click_id at schema.rb:1081 outside the cited 1092–1103 range). AMENDED inline.
- LOW (note-only): track.rb citation "25–32" vs actual def 24–31. Content claim accurate; deliberately left.
