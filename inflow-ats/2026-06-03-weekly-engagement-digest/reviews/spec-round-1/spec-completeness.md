# Spec Completeness — Round 1

## Findings

- F1 [BLOCKER] Missing test requirements section — per pipeline known-failure-pattern #3 (`~/claude-hub/inflow-ats/CLAUDE.md` "Known Failure Patterns" section): "Every spec and implementation plan must state which existing tests need updating and what new test coverage is required. 'No tests' is acceptable only when explicitly documented with reasoning, never by omission." The spec has NO test requirements section. No mention of tests, specs, or Cypress anywhere in the document. The review-angles always-on "Test coverage" check (REVIEW-ANGLES.md:201-203) confirms: "No existing specs were found for `EngagementReport::OrganizationAnalyzer`, `EngagementReport::GeneratorJob`, or the existing mailers." The spec must add a Test Requirements section that states what tests are needed. Given the analogs have no tests, a reasonable stance is to document that and state what new coverage this feature should have (at minimum: analyzer extensions, bucket classifier, data migration).

- F2 [HIGH] Spec does not mention `settings_params` in `MeController` as a modified file — the Components Added table (spec lines 78-88) lists every new and modified component, but `MeController#settings_params` is not mentioned. The preference full-stack contract requires adding `:email_weekly_digest` to the permit list at me_controller.rb:128-129. Without this, the frontend checkbox would appear to save but the key would be silently dropped by strong parameters. The REVIEW-ANGLES "Modified files" list (REVIEW-ANGLES.md:17) correctly identifies this file, but the spec's own components table omits it. **Fix: add `MeController` to the Components Added table as a modified file.**

- F3 [HIGH] Spec does not mention `UserSettings` TypeScript interface as a modified file — same issue as F2. The `UserSettings` interface at `app/javascript/shared/types/user.ts` must gain `emailWeeklyDigest: boolean`. The spec's Components table does not list this file. The REVIEW-ANGLES "Modified files" list correctly includes it.

- F4 [MED] `SessionSerializer` not mentioned — `session_serializer.rb` surfaces `settings` to the frontend. It does not need code changes (it surfaces the raw column), but the spec does not mention it as a consumed dependency. The implementer should know the settings flow passes through this serializer. Not blocking because no code change is needed.

- F5 [MED] Bucket classifier input specification — spec line 163-167 defines the classifier logic using `stage_moves`, `comments`, `reviews`, `messages_sent_by_user`, `applications_received`, `messages_sent_by_organization`. These are plain names, not hash paths. The analyzer's output structure (as seen in the existing `build_result` method, analyzer lines 344-428) uses nested hashes like `candidate_management[:stage_moves][:count]`, `candidate_management[:comments][:count]`, `candidate_management[:reviews][:total]`. The spec's classifier section does not specify whether it consumes the raw metric sub-hashes directly from the analyzer or a flattened structure. The implementer will need to map between the analyzer output shape and the classifier input. This is an implementation detail but worth noting.

- F6 [MED] Metric #2 "Stage moves" — spec line 24 lists "Stage moves" as one of the seven metrics. The existing analyzer computes stage moves at `stage_move_metrics` (analyzer line 154-166). It counts `HiringStageVisit` records scoped by `@job_application_ids`. For the org_user-scoped case, `@job_application_ids` will be derived from the scoped `@job_ids`, so stage moves will be correctly scoped. No issue with the data, but noting the chain for completeness.

- F7 [MED] Metric #3 "Jobs published" — spec line 25 lists "Jobs published." The existing analyzer has `job_metrics` (line 90-112) which counts `jobs.where('published_at > ?', @cutoff)`. Currently this uses `@organization.jobs`. For the org_user scoped case, the spec says `@job_ids` is either all org jobs (admin) or the hiring-team-scoped set. Published jobs would only count jobs the org_user is on the hiring team of. For non-admin users, this seems correct (they only see their jobs). For admins, they see all. Reasonable.

- F8 [LOW] Open decisions reflected — OPEN-DECISIONS.md lists three resolved decisions. Checking each against the spec:
  1. "Task goes into existing `recurring_tasks.rake`" — spec line 78 and 202 confirm this. OK.
  2. "Kept as dedicated Sidekiq job" — spec line 81 and 194-198 confirm this. OK.
  3. "Class name `AddWeeklyDigestEmailPreference`" — spec line 127 confirms this. OK.
  All resolved decisions are reflected in the spec.

## Amendments Applied

- F1 (BLOCKER): Adding a Test Requirements section to the spec.
- F2 (HIGH): Adding `MeController` to the Components Added table.
- F3 (HIGH): Adding `UserSettings` to the Components Added table.
