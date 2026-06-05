# Spec Review — Round 1 Verdict
**Date:** 2026-06-03

## Counts
- BLOCKER: 1
- HIGH: 3
- MED: 10
- LOW: 5

## Amendments Applied

1. **[BLOCKER] Added Test Requirements section** — the spec had no test plan, violating pipeline known-failure-pattern #3. Added a full section specifying RSpec specs for the classifier, analyzer extensions, job, mailer, and data migration, plus frontend QA notes.

2. **[HIGH] Added `MeController` to Components Added table** — `settings_params` permit list must add `:email_weekly_digest`. Was missing from the spec's components inventory.

3. **[HIGH] Added `UserSettings` TypeScript interface to Components Added table** — `emailWeeklyDigest: boolean` must be added. Was missing from the spec's components inventory.

4. **[HIGH] Added deploy-order constraint** — `settings_params`, `UserSettings`, and `AccountPreferences.tsx` changes MUST deploy together. `MeController#update_settings` does a full JSONB column replacement; if the backend permits the new key before the frontend sends it, any preference save silently deletes the digest key.

## Verdict: FAIL

Four amendments applied (1 BLOCKER, 3 HIGH). Proceeding to Round 2.
