# Always-on — Operational concerns — impl round 1

## Findings: 0 BLOCKER / 0 HIGH / 0 MED / 2 LOW

### LOW-1 (note-only; duplicate of fan-out-contract LOW-1): unrescued writer inside the Organization after_commit
The `trial_started` `CreateSubscriptionEvent.call` at organization.rb:1131 has no rescue; an enqueue-time raise (Redis down) inside the fan-out would propagate to the org-update caller. Identical exposure existed at the same line before (direct `Discord::NotifyFreeTrialStartedJob.perform_later(id)`), and the adjacent Slack `perform_later` shares it today. Risk profile unchanged; spec placed no rescue. Note-only.

### LOW-2 (note-only): Discord-after-ledger coupling
A failed/deduped interactor call now also skips the Discord ping (and PostHog) for that event — the pattern working as designed; already a deliberately-unamended spec-review LOW. Carried for the record.

## Checks — clean

- **Serialization:** `PosthogTrackJob.perform_later(Integer, String, Hash)` — all values ActiveJob-serializable (strings/integers/jsonb Hash for `utm_data`); symbol keys round-trip via ActiveJob and the job's `deep_symbolize_keys`. Proven live by the passing enqueue specs (args serialize at enqueue under the `:test` adapter).
- **Test-env safety of new inline paths:** `POSTHOG_CLIENT` is nil without `Variables::POSTHOG_API_KEY` (`config/initializers/posthog.rb:5`) — `Posthog::Track#track` bails; Discord jobs at these triggers fired inline before the change too (same trigger sites) — no new external-call exposure in the suite's `:inline` default outside the new specs' `:test` blocks.
- **Migration operational risk:** additive nullable columns + partial index on a tiny table (free-plan-assignment rows only today) — negligible lock window. Both DBs migrated (status verified).
- **Observability:** every failure path logs with context (`Rails.logger.error` + `ap`): both webhook insertions (org/invoice/subscription ids), interactor duplicate + race, PostHog track failure (pre-existing rescue in `Posthog::Track`). The fan-out logs each row's event_type at handler entry.
- **Redelivery/idempotency:** covered (guard/index/dedupe — see data-integrity-security.md).
- **Rollout §11.6:** ships as specced; residual production-payload validation is Jessica-owned (SPEC §11.1). No log-first soak — superseded per RESOLVED-at-go.
- **Commit hygiene:** single local commit `89286fba8` on `attribution-work-qa`, unpushed; message + `Co-Authored-By` trailer present; pre-commit (Cypress) ran at commit time by construction of the hook.
