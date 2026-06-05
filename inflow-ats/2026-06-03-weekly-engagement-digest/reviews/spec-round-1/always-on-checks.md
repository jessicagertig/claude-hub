# Always-On Checks — Round 1

## Source Accuracy

| Reference | Spec claim | Actual | Status |
|---|---|---|---|
| `OrganizationUser#default_settings` at line 83-89 | Three email boolean keys | Confirmed: organization_user.rb:83-89 has `email_job_applications_new`, `email_comments_new`, `email_messages_new` | OK |
| `OrganizationUser.with_preference_for` at line 165-169 | Uses `@>` JSON containment | Confirmed: organization_user.rb:165-169 `where('settings @> ?', preferences.to_json)` | OK |
| `OrganizationUser#is_admin` at line 54 | Returns true for org_admin or owner | Confirmed: organization_user.rb:54-56 `org_admin? \|\| is_owner` | OK |
| `Organization.claimed` scope at line 130 | `where(is_claimed: true)` | Confirmed: organization.rb:130 | OK |
| `Organization#active_paid_plan?` at line 651 | `paid_plan? && stripe_subscription_in_good_standing` | Confirmed: organization.rb:651-653 | OK |
| `ChannelMessage.sent_by` enum values | `:sent_by_system`, `:sent_by_user`, `:sent_by_candidate`, `:sent_by_organization` | Confirmed: channel_message.rb:27-32 | OK |
| `Channel belongs_to :job_application` | At channel.rb:6 | Confirmed: channel.rb:6 | OK |
| `Emails::SendTemplateEmail` | At `app/services/emails/send_template_email.rb` | Confirmed: file exists with expected shape | OK |
| `Variables::EMAIL_HELLO_ADDRESS` at line 11 | `hello@mail.polymer.co` | Confirmed: 01_variables.rb:11 (with staging override) | OK |
| `Variables::ATS_PREFERENCES_URL` at line 21 | `"#{AtsRootUrl}/hire/settings/preferences"` | Confirmed: 01_variables.rb:21 | OK |
| `Settingsable` concern | At `app/models/concerns/settingsable.rb` | Confirmed: file exists with `add_default_settings`, `update_settings`, `add_new_default_settings` | OK |
| `settings_params` permit list at line 128-129 | Three keys permitted | Confirmed: me_controller.rb:128-129 `.permit(:email_job_applications_new, :email_comments_new, :email_messages_new)` | OK |
| `SessionSerializer#settings` at line 58-60 | Surfaces `current_organization_user&.settings` | Confirmed: session_serializer.rb:58-60 | OK |
| `OrganizationUser` has_many chains (lines 14-19) | `:jobs through :hiring_team_memberships`, `:job_applications through :jobs`, etc. | Confirmed: organization_user.rb:14-19 | OK |
| `engagement_reports` task at lines 134-159 | Iterates claimed orgs, filters `active_paid_plan?`, enqueues with stagger | Confirmed: recurring_tasks.rake:134-159 | OK |
| `EngagementReport::GeneratorJob` | `find_by` + guard, method-level rescue, `ap` + `Rails.logger.error` | Confirmed: generator_job.rb:1-27 | OK |
| `ReportGenerator` calls `OrganizationAnalyzer.new(organization: @organization)` | Line 17 | Confirmed: report_generator.rb:17 `.new(organization: @organization)` — note: does NOT pass `months:`, so it uses the default of 6 | OK |
| `OrganizationAnalyzer` constructor signature | `organization:`, `months: 6` | Confirmed: organization_analyzer.rb:5 | OK |

All source references verified. No inaccuracies found.

## Test Coverage

Covered in spec-completeness angle (F1 BLOCKER). The spec now has a Test Requirements section (amendment applied).

## Backward Compatibility

- `EngagementReport::ReportGenerator` calls `OrganizationAnalyzer.new(organization: @organization)` — adding optional `organization_user_id: nil` and `since: nil` parameters preserves backward compatibility. Verified: ReportGenerator does not pass either new param, and both default to nil, so existing behavior is identical. **OK.**
- `settings_params` in `MeController` — adding a new permitted key does not break existing saves. The permit list is additive. **OK.** (The deploy-order issue is separately addressed.)
- `UserSettings` TypeScript interface — adding a new field does not break existing destructuring at AccountPreferences.tsx:27 (`const { emailCommentsNew, emailMessagesNew, emailJobApplicationsNew } = settings;`). Destructuring ignores extra keys. **OK.**
- `default_settings` in `OrganizationUser` — adding a key. `Settingsable#add_default_settings` only fires when `settings.blank?` (new users). `add_new_default_settings` iterates and adds keys where nil. `delete_unused_settings` removes keys NOT in `default_settings` — so the new key being present means it is "used" and won't be deleted. **OK.**

## Full-Stack Analog Completeness

| Analog layer | Analog file | Digest equivalent | Status |
|---|---|---|---|
| Rake task | `recurring_tasks.rake:134-159` | New `weekly_engagement_digest` task in same file | Specified |
| Sidekiq job | `engagement_report/generator_job.rb` | `weekly_digest_job.rb` | Specified |
| Analyzer | `organization_analyzer.rb` | Same file, extended | Specified |
| Output consumer | `report_generator.rb` (Google Sheets) | `weekly_digest_classifier.rb` + `weekly_digest_mailer.rb` | Specified |
| Mailer | (none in analog) | `weekly_digest_mailer.rb` | Specified (uses CommentMailer/JobApplicationMailer as secondary analog) |
| Data migration | (none in analog) | `db/data/` migration | Specified |
| Model defaults | (none in analog) | `default_settings` update | Specified |
| API permit | (none in analog) | `settings_params` in `me_controller.rb` | NOW specified (added in this round) |
| Frontend type | (none in analog) | `UserSettings` in `user.ts` | NOW specified (added in this round) |
| Frontend UI | (none in analog) | `AccountPreferences.tsx` new section | Specified |

All layers accounted for after amendments.
