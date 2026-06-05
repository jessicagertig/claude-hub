# Review Angles — Weekly Engagement Digest

Generated from: `/Users/jessica/claude-hub/inflow-ats/2026-06-03-weekly-engagement-digest/SPEC.md`
Date: 2026-06-03

## Subsystems touched

**New files:**
- `app/jobs/weekly_digest_job.rb` — per-org_user Sidekiq job
- `app/mailers/weekly_digest_mailer.rb` — sends via `Emails::SendTemplateEmail`
- `app/services/weekly_digest_classifier.rb` — bucket classification
- `db/data/YYYYMMDDHHMMSS_add_weekly_digest_email_preference.rb` — data migration

**Modified files:**
- `app/services/engagement_report/organization_analyzer.rb` — new `organization_user_id:` param, `since:` param, `ChannelMessage` query
- `app/models/organization_user.rb` — `default_settings` hash, new scope
- `app/controllers/api/v1/me_controller.rb` — `settings_params` permit list
- `app/javascript/shared/types/user.ts` — `UserSettings` interface
- `app/javascript/ats/src/views/accountAdmin/AccountPreferences.tsx` — new digest section
- `lib/tasks/recurring_tasks.rake` — new `weekly_engagement_digest` task

**Consumed (read-only, but contract matters):**
- `app/services/emails/send_template_email.rb` — mailer sends through this
- `app/models/concerns/settingsable.rb` — `add_default_settings`, `update_settings`
- `app/serializers/api/v1/session_serializer.rb` — surfaces `settings` to frontend
- `app/models/organization.rb` — `Organization.claimed`, `active_paid_plan?`
- `app/models/channel_message.rb` — `sent_by` enum values
- `app/models/channel.rb` — join path from `ChannelMessage` to `job_application`
- `config/initializers/01_variables.rb` — `EMAIL_HELLO_ADDRESS`, `ATS_PREFERENCES_URL`, `AtsRootUrl`
- `app/javascript/shared/queryHooks/useMe.ts` — `useUpdateSettings`, `useGetMe`

## Full-stack analog

The `engagement_reports` rake task through `EngagementReport::GeneratorJob` through `EngagementReport::OrganizationAnalyzer` is the primary analog. This is the only codebase flow that shares the same shape: a scheduled rake task in `recurring_tasks.rake` that iterates eligible organizations, enqueues a per-entity Sidekiq job, and the job runs the same `OrganizationAnalyzer` to compute metrics. The weekly digest extends this by adding per-org_user scoping, a bucket classifier, and a mailer at the end.

For the mailer layer specifically, `CommentMailer#hiring_team_new_comment` and `JobApplicationMailer#hiring_team_new_job_application` are the analogs — they show the `message_params` shape and `Emails::SendTemplateEmail` integration pattern.

### Engagement reports pipeline (analog)

- **Rake task:** `lib/tasks/recurring_tasks.rake:134-159` — `engagement_reports` task. Iterates `Organization.claimed`, filters `active_paid_plan?`, enqueues `EngagementReport::GeneratorJob` per org with stagger delay (`count * delay_between_jobs`).
- **Sidekiq job:** `app/jobs/engagement_report/generator_job.rb` — receives `organization_id`, loads org with `find_by` + guard, delegates to `ReportGenerator`, method-level `rescue StandardError` with both `ap` and `Rails.logger.error`.
- **Orchestrator:** `app/services/engagement_report/report_generator.rb` — instantiates `OrganizationAnalyzer`, runs `analyze`, builds payload, sends to Google Sheets.
- **Analyzer:** `app/services/engagement_report/organization_analyzer.rb` — constructor takes `organization:` and `months:`, computes `@job_ids`/`@job_application_ids`/`@candidate_ids` in `load_base_ids`, runs metric groups (`team_metrics`, `inbound_metrics`, `setup_activity_metrics`, `candidate_management_metrics`), computes scoring and summary.
- **No mailer in this analog.** The digest adds a mailer step where the engagement report sends to Google Sheets.

### Mailer analogs

- `app/mailers/comment_mailer.rb` — `hiring_team_new_comment`: builds `message_params` hash (`from`, `to`, `list_unsubscribe`, `subject`, `template`, `template_version`, `tags`, `variables`), calls `Emails::SendTemplateEmail.new(message_params).send`. Selects template name internally based on `@comment.review?`.
- `app/mailers/job_application_mailer.rb` — `hiring_team_new_job_application`: same `message_params` shape, same `Emails::SendTemplateEmail` call.
- `app/services/emails/send_template_email.rb` — validates all params, builds `Mailgun::MessageBuilder`, enforces max 2 tags (auto-appends template name as 3rd), requires variables, handles `list_unsubscribe` header.

### Settings/preference analog

- `app/models/organization_user.rb:83-89` — `default_settings` hash with `email_job_applications_new`, `email_comments_new`, `email_messages_new`.
- `app/models/organization_user.rb:165-169` — `self.with_preference_for` uses `@>` JSON containment.
- `app/models/concerns/settingsable.rb` — `add_default_settings` callback, `update_settings` method.
- `app/controllers/api/v1/me_controller.rb:50-59` — `update_settings` action permits specific keys via `settings_params`.
- `app/controllers/api/v1/me_controller.rb:128-129` — `settings_params` permit list.
- `app/serializers/api/v1/session_serializer.rb:58-60` — surfaces `current_organization_user.settings`.
- `app/javascript/shared/types/user.ts` — `UserSettings` interface.
- `app/javascript/shared/queryHooks/useMe.ts:32-35` — `updateSettings` calls `PUT /me/update_settings`.
- `app/javascript/ats/src/views/accountAdmin/AccountPreferences.tsx` — `FormCheckbox` rows, `handleEmailPreferenceChange`, `handleSubmitForm`.

**Priority rule:** Where the full-stack analog deviates from convention, the analog wins. Note the deviation so the reviewer does not flag it.

Known analog deviations:
- `EngagementReport::GeneratorJob` lives at `app/jobs/engagement_report/generator_job.rb` (namespaced directory), not the flat `app/jobs/` naming in `background_jobs.md`. The spec names the new job `weekly_digest_job.rb` at `app/jobs/` (flat). Both patterns exist in the codebase — the reviewer should verify the spec's choice is intentional and consistent.
- `OrganizationAnalyzer` constructor uses positional-style keyword `organization:` plus `months:` with a default. The digest extends this with `organization_user_id:` and `since:` — the reviewer should verify backward compatibility (existing caller passes neither new param).

## Angles

### 1. analyzer-extensions
**What this covers:** Everything changing in `OrganizationAnalyzer` — the new constructor params (`organization_user_id:`, `since:`), the `load_base_ids` branching for admin vs non-admin org_users, the new `ChannelMessage` query joining through `Channel`, and the four message counts it produces. The reviewer should verify the existing `EngagementReport::ReportGenerator` caller still works identically when passing neither new param, that the admin/non-admin scoping correctly determines which jobs (and thus which downstream data) each org_user sees, and that the `ChannelMessage` query uses the `sent_by` enum values correctly and produces counts the classifier and mailer can consume.

**Files across all layers:**
- `app/services/engagement_report/organization_analyzer.rb` (modified — constructor, `load_base_ids`, new query method)
- `app/services/engagement_report/report_generator.rb` (existing caller — must still work identically)
- `app/jobs/engagement_report/generator_job.rb` (existing caller)
- `app/jobs/weekly_digest_job.rb` (new caller)
- `app/services/weekly_digest_classifier.rb` (new consumer of analyzer output)
- `app/mailers/weekly_digest_mailer.rb` (passes message counts as template variables)
- `app/models/channel_message.rb` — `sent_by` enum values
- `app/models/channel.rb` — join path from `ChannelMessage` to `job_application`
- `app/models/organization_user.rb` — `is_admin`, `has_many :jobs, through: :hiring_team_memberships`, `has_many :job_applications, through: :jobs`

**Analog files for comparison:**
- `app/services/engagement_report/organization_analyzer.rb:5-8` — current constructor signature
- `app/services/engagement_report/report_generator.rb:17` — existing caller instantiation
- `app/services/engagement_report/organization_analyzer.rb:47-51` — current `load_base_ids` (org-wide only)
- `app/services/engagement_report/organization_analyzer.rb:144-219` — existing `candidate_management_metrics` methods (pattern for joining through `@job_application_ids` with cutoff timestamps)

**Convention context:**
- `cursor_rules/backend/services.md`
- `cursor_rules/core_critical_rules.md`

---

### 2. preference-full-stack-contract
**What this covers:** The `email_weekly_digest` preference key must flow correctly across every layer — data migration, model defaults, `Settingsable` concern, backend permit list, serializer, API response, TypeScript type, React UI checkbox, and the rake task's `with_preference_for` query. This is a customer-facing feature: a mismatch at any layer (wrong key name, missing permit, missing type field, camelCase/snake_case error) means the preference silently doesn't work and customers either can't unsubscribe or never receive the digest.

**Files across all layers:**
- `db/data/YYYYMMDDHHMMSS_add_weekly_digest_email_preference.rb` (new)
- `app/models/organization_user.rb` — `default_settings`, `with_preference_for`
- `app/models/concerns/settingsable.rb` — `add_default_settings`, `update_settings`
- `app/controllers/api/v1/me_controller.rb` — `settings_params` permit list
- `app/serializers/api/v1/session_serializer.rb` — surfaces `settings`
- `app/javascript/shared/types/user.ts` — `UserSettings` interface
- `app/javascript/shared/queryHooks/useMe.ts` — `useUpdateSettings`
- `app/javascript/ats/src/views/accountAdmin/AccountPreferences.tsx` — new checkbox
- `lib/tasks/recurring_tasks.rake` — `with_preference_for(:email_weekly_digest)`

**Analog files for comparison:**
- The existing `email_job_applications_new` / `email_comments_new` / `email_messages_new` keys traced through the same stack — each key appears in `default_settings`, `settings_params`, `UserSettings`, and `AccountPreferences.tsx`.

**Convention context:**
- `cursor_rules/core_critical_rules.md` (rule 7: snake_case backend, camelCase frontend)
- `cursor_rules/backend/migrations.md`

---

### 3. send-pipeline
**What this covers:** The end-to-end path from rake task through job through mailer to Mailgun. The rake task enumerates eligible recipients (org + org_user loops), the job orchestrates analyzer → classifier → mailer, and the mailer builds `message_params` that satisfy `Emails::SendTemplateEmail`'s validations. This is customer-facing email — the reviewer should look at the whole chain as one flow: does the right set of people get the right email with the right data? The `from` address intentionally uses `Variables::EMAIL_HELLO_ADDRESS` (not `EMAIL_NOTIFICATIONS_ADDRESS` like the existing mailers).

**Files across all layers:**
- `lib/tasks/recurring_tasks.rake` — new `weekly_engagement_digest` task
- `app/jobs/weekly_digest_job.rb` (new)
- `app/services/weekly_digest_classifier.rb` (new)
- `app/mailers/weekly_digest_mailer.rb` (new)
- `app/services/emails/send_template_email.rb` (consumed — validations, tag limits, `list_unsubscribe`)
- `app/models/organization.rb` — `Organization.claimed`, `active_paid_plan?`
- `app/models/organization_user.rb` — `actives`, `with_preference_for`
- `config/initializers/01_variables.rb` — `EMAIL_HELLO_ADDRESS`, `ATS_PREFERENCES_URL`, `AtsRootUrl`

**Analog files for comparison:**
- `lib/tasks/recurring_tasks.rake:134-159` — `engagement_reports` task (org loop, `active_paid_plan?` filter, stagger delay)
- `app/jobs/engagement_report/generator_job.rb` — `find_by` + guard, method-level rescue, `ap` + `Rails.logger.error`
- `app/mailers/comment_mailer.rb:10-75` — `message_params` shape, template selection, `SendTemplateEmail` call
- `app/mailers/job_application_mailer.rb:10-77` — same pattern

**Convention context:**
- `cursor_rules/backend/background_jobs.md`
- `cursor_rules/backend/services.md`
- `cursor_rules/core_critical_rules.md`

---

### 4. ui-preference-section
**What this covers:** The customer-facing preference UI in `AccountPreferences.tsx`. The new digest section must match the existing email-preference checkboxes exactly in component choice, layout, and save flow — customers see these side by side, so inconsistency is visible. The reviewer should check that the section is visually separate from the existing job-notification preferences (spec requirement) while using the same underlying pattern.

**Files across all layers:**
- `app/javascript/ats/src/views/accountAdmin/AccountPreferences.tsx` — new section
- `app/javascript/shared/types/user.ts` — `UserSettings` interface
- `app/javascript/shared/queryHooks/useMe.ts` — `useUpdateSettings`
- `app/controllers/api/v1/me_controller.rb` — `settings_params`
- `app/serializers/api/v1/session_serializer.rb` — surfaces settings

**Analog files for comparison:**
- `app/javascript/ats/src/views/accountAdmin/AccountPreferences.tsx:119-142` — existing `FormSection` > `FormFieldset` > three `FormCheckbox` rows

**Convention context:**
- `cursor_rules/frontend/_base.md`
- `cursor_rules/frontend/forms/`
- `cursor_rules/core_critical_rules.md` (rule 7, rule 9)

---

### 5. spec-completeness
**What this covers:** The spec must be complete and internally consistent before planning begins. This angle checks for missing sections (notably: the spec has no test requirements section — per pipeline known-failure-pattern #3, every spec must state which existing tests need updating and what new test coverage is required), unresolved ambiguities, claims that contradict the codebase, and whether the bucket classifier logic and the seven metrics are fully specified with no gaps the implementer would have to guess at.

**Files across all layers:**
- `SPEC.md` (the spec itself)
- `OPEN-DECISIONS.md` (resolved decisions — verify they're reflected in the spec)
- All files referenced by the spec (source accuracy — do the paths, methods, line numbers, and behaviors the spec claims actually exist?)

**Analog files for comparison:**
- The engagement reports pipeline files (verify the spec's claims about how the analog works)

**Convention context:**
- `~/claude-hub/inflow-ats/CLAUDE.md` — known failure pattern #3 (test requirements)

## Always-on checks

These apply to every feature regardless of angles:

### Source accuracy
The review agent verifies every file path, class, method, column, route, and component the spec references against the current source. Key references to verify:
- `OrganizationUser#default_settings` at `organization_user.rb:83-89`
- `OrganizationUser.with_preference_for` at `organization_user.rb:165-169`
- `OrganizationUser#is_admin` at `organization_user.rb:54`
- `Organization.claimed` scope at `organization.rb:130`
- `Organization#active_paid_plan?` at `organization.rb:651`
- `ChannelMessage.sent_by` enum values at `channel_message.rb:27-32`
- `Channel belongs_to :job_application` at `channel.rb:6`
- `Emails::SendTemplateEmail` at `app/services/emails/send_template_email.rb`
- `Variables::EMAIL_HELLO_ADDRESS` at `config/initializers/01_variables.rb:11`
- `Variables::ATS_PREFERENCES_URL` at `config/initializers/01_variables.rb:21`
- `Settingsable` concern at `app/models/concerns/settingsable.rb`
- `settings_params` permit list at `me_controller.rb:128-129`
- `SessionSerializer#settings` at `session_serializer.rb:58-60`

### Test coverage
The review agent checks what existing tests cover the affected code and what new tests the spec should require. Note: the codebase has specs at `spec/` (RSpec) and Cypress tests at `cypress/`. No existing specs were found for `EngagementReport::OrganizationAnalyzer`, `EngagementReport::GeneratorJob`, or the existing mailers. The review should note what tests the feature needs even if the analog lacks them.

### Backward compatibility
The review agent identifies all consumers of modified code and verifies they are addressed:
- `EngagementReport::ReportGenerator` calls `OrganizationAnalyzer.new(organization: @organization)` — must still work with new optional params defaulting to `nil`.
- `settings_params` in `MeController` — adding a new permitted key must not break existing settings saves.
- `UserSettings` TypeScript interface — adding a new field must not break existing destructuring at `AccountPreferences.tsx:27`.
- `default_settings` in `OrganizationUser` — adding a key must not break `Settingsable#add_default_settings` or `add_new_default_settings`.

### Full-stack analog completeness
The review agent verifies the new feature has a corresponding piece for every layer of the analog pipeline. A missing layer is a BLOCKER.

| Analog layer | Analog file | Digest equivalent |
|---|---|---|
| Rake task | `recurring_tasks.rake:134-159` | New `weekly_engagement_digest` task in same file |
| Sidekiq job | `engagement_report/generator_job.rb` | `weekly_digest_job.rb` |
| Analyzer | `engagement_report/organization_analyzer.rb` | Same file, extended |
| Output consumer | `engagement_report/report_generator.rb` (Google Sheets) | `weekly_digest_classifier.rb` + `weekly_digest_mailer.rb` |
| Mailer | (none in analog) | `weekly_digest_mailer.rb` — uses `CommentMailer`/`JobApplicationMailer` as secondary analog |
| Data migration | (none in analog) | `db/data/` migration for `email_weekly_digest` preference |
| Model defaults | (none in analog) | `default_settings` update in `organization_user.rb` |
| API permit | (none in analog) | `settings_params` in `me_controller.rb` |
| Frontend type | (none in analog) | `UserSettings` in `user.ts` |
| Frontend UI | (none in analog) | `AccountPreferences.tsx` new section |
