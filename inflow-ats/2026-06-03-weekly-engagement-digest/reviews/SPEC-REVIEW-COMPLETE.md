# Spec Review Complete

**Final Verdict: READY FOR PLANNING**
**Date:** 2026-06-03
**Rounds:** 3 (two consecutive passes achieved at Rounds 2 and 3)

---

## Plain English Summary

This feature sends a weekly email to every paying customer's team members, summarizing what happened in their hiring account over the past seven days. The email shows counts like how many new applications came in, how many candidates were moved between stages, how many messages were exchanged, and which job posting got the most applications. The email comes in three flavors depending on activity level: one for weeks with zero activity (a gentle "we're here" nudge), one for weeks where applications are coming in but nobody on the team is interacting with them (the most important case for keeping customers engaged), and one for weeks where the team is actively working. Each team member can turn this email on or off from their account preferences page. The system reuses an existing analytics engine that already knows how to compute hiring metrics, extending it to work per-person rather than per-company, and adding message counts it didn't track before.

## Blast Radius Analysis

| Touched area | Risk if wrong | Scope of breakage |
|---|---|---|
| `EngagementReport::OrganizationAnalyzer` (modified) | Existing engagement reports to Google Sheets break | Internal tool only; digest emails also send wrong data |
| `OrganizationUser#default_settings` (modified) | New org_users miss the digest preference key | Those users silently never receive digests |
| `MeController#settings_params` (modified) | Users can't toggle the digest preference from UI | Checkbox appears to save but key is silently dropped |
| `UserSettings` TypeScript interface (modified) | Build-time type errors or wrong key names | Preferences page potentially breaks |
| `AccountPreferences.tsx` (modified) | Layout issues or broken save for ALL preferences | Preferences page |
| `recurring_tasks.rake` (modified) | Digest never sends, wrong recipients, or Sidekiq overload | Digest emails only (no effect on existing tasks) |
| Mailgun stored templates (external, new) | All digest sends fail silently | Digest emails only |

**Critical deploy-order constraint:** The `settings_params`, `UserSettings`, and `AccountPreferences.tsx` changes must deploy together. Deploying the backend permit-list change before the frontend sends the new key would cause any user who saves preferences to silently lose the digest setting.

---

## Round-by-Round Summary

| Round | Verdict | BLOCKER | HIGH | MED | LOW | Amendments |
|---|---|---|---|---|---|---|
| 1 | FAIL | 1 | 3 | 10 | 5 | 4 (test requirements section, MeController in components table, UserSettings in components table, deploy-order constraint) |
| 2 | PASS | 0 | 0 | 0 | 0 | 0 |
| 3 | PASS | 0 | 0 | 0 | 0 | 0 |

## Round 1 Amendments (applied to SPEC.md)

1. **[BLOCKER] Added Test Requirements section** (spec lines 246-265) -- the spec had no test plan, violating pipeline known-failure-pattern #3. Covers RSpec specs for classifier, analyzer extensions, job, mailer, and data migration.
2. **[HIGH] Added `MeController` to Components Added table** (spec line 87) -- `settings_params` permit list must add `:email_weekly_digest`.
3. **[HIGH] Added `UserSettings` TypeScript interface to Components Added table** (spec line 88) -- `emailWeeklyDigest: boolean` must be added.
4. **[HIGH] Added deploy-order constraint** (spec lines 240-242) -- `settings_params`, `UserSettings`, and `AccountPreferences.tsx` changes must deploy together to prevent silent data loss.

## Remaining MED/LOW observations (not blocking, no spec amendments needed)

- `load_base_ids` wording: "derived from `@job_ids` as today" is slightly misleading since the current code derives from `@organization` not `@job_ids`, but the spec's Note sentence clarifies the intent.
- `messages_sent_total` parenthetical says "equivalently: not `sent_by_candidate`" but the primary definition ("sum of user + org") is what governs. System messages (sent_by_system) are excluded by the primary definition but would be included by the parenthetical. Primary definition is unambiguous.
- Section placement in `AccountPreferences.tsx` (new FormSection vs new FormFieldset within existing FormSection) is a visual design decision left to implementation.
- `list_unsubscribe` header format and placeholder URL are tracked in Open Items.
- Job stagger delay for per-org_user volume is tracked in Open Items.

## Open Questions for Jessica

None. All design-level questions are resolved. The remaining Open Items in the spec are implementation-time decisions that do not block planning.
