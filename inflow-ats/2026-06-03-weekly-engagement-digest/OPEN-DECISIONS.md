# Open Decisions

All design-level decisions have been resolved. Decisions made 2026-06-03:

1. **`lib/tasks/README.md`** — dropped. Task goes into existing `recurring_tasks.rake`; no other tasks there have a README.
2. **`WeeklyDigestJob`** — kept as dedicated Sidekiq job. Matches `EngagementReport::GeneratorJob` precedent.
3. **Data migration class name** — `AddWeeklyDigestEmailPreference` (semantic-content convention).

Remaining implementation-time decisions are tracked in the "Open Items" section of `SPEC.md`.
