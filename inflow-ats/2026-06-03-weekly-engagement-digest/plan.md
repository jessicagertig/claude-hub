# Implementation Plan: Weekly Engagement Digest

## Summary

A weekly per-organization digest email sent every Monday at 00:00 UTC to active organization_users in eligible (claimed, active paid plan) organizations. The email surfaces seven hiring-activity metrics and one highlight computed over the previous 7-day window, scoped per organization_user (admins see org-wide data; non-admins see only their hiring-team-assigned jobs). A bucket classifier sorts each recipient into one of three Mailgun stored templates (all-counts-zero, passive-flow-only, active-team). Users control the digest via a new `email_weekly_digest` preference checkbox in AccountPreferences. The feature is a retention tool, with particular value for orgs receiving applications but not engaging with them.

---

## Pattern Precedents

Each new component is modeled on at least two existing codebase patterns.

### Rake task pattern
- **Primary:** `engagement_reports` task at `lib/tasks/recurring_tasks.rake:134-159` -- iterates `Organization.claimed`, filters `active_paid_plan?`, enqueues jobs with stagger delay (`count * delay_between_jobs`).
- **Secondary:** `daily_summary` task at `recurring_tasks.rake:60-63` -- simple enqueue pattern for a recurring job.

### Sidekiq job pattern
- **Primary:** `EngagementReport::GeneratorJob` at `app/jobs/engagement_report/generator_job.rb` -- receives ID, `find_by` + guard, delegates to service, method-level `rescue StandardError` with both `ap` and `Rails.logger.error`.
- **Secondary:** `ExportJobCandidatesToCsvJob` at `app/jobs/export_job_candidates_to_csv_job.rb` -- flat `app/jobs/` placement, `rescue StandardError` pattern.

### Mailer pattern
- **Primary:** `CommentMailer#hiring_team_new_comment` at `app/mailers/comment_mailer.rb:10-75` -- builds `message_params` hash (`from`, `to`, `list_unsubscribe`, `subject`, `template`, `template_version`, `tags`, `variables`), calls `Emails::SendTemplateEmail.new(message_params).send`. Selects template name internally based on `@comment.review?`.
- **Secondary:** `JobApplicationMailer#hiring_team_new_job_application` at `app/mailers/job_application_mailer.rb:10-77` -- same `message_params` shape, same `Emails::SendTemplateEmail` call.

### Service/classifier pattern
- **Primary:** `SpamDetector` at `app/services/spam_detector.rb` -- single-purpose service with a descriptive public method (`spam_score`), no "Service" in name.
- **Secondary:** `CorporateEmailValidator` at `app/services/corporate_email_validator.rb` -- single public method (`validate`), keyword arguments.

### Settings/preference full-stack pattern
- **Model:** `OrganizationUser#default_settings` at `organization_user.rb:83-89` -- hash of `email_job_applications_new: true`, `email_comments_new: true`, `email_messages_new: true`.
- **Scope:** `OrganizationUser.with_preference_for` at `organization_user.rb:165-169` -- Postgres `@>` JSON containment.
- **Concern:** `Settingsable#add_default_settings` at `app/models/concerns/settingsable.rb:27-29` -- called `after_create`, writes `default_settings` when `settings.blank?`.
- **Controller:** `MeController#settings_params` at `me_controller.rb:128-129` -- `params.require(:settings).permit(...)`.
- **Serializer:** `SessionSerializer#settings` at `session_serializer.rb:58-60` -- `object&.current_organization_user&.settings`.
- **Frontend type:** `UserSettings` at `app/javascript/shared/types/user.ts:1-5`.
- **Frontend hook:** `updateSettings` at `app/javascript/shared/queryHooks/useMe.ts:32-35` -- `apiPut` to `/me/update_settings`.
- **Frontend UI:** `AccountPreferences.tsx:119-155` -- `FormSection` > `FormFieldset` > `FormCheckbox` rows, `handleEmailPreferenceChange` handler, `handleSubmitForm` sends `{ ...settings }`.

### Data migration pattern
- **Primary:** `AddCompensationToJobApplicationsSettings` at `db/data/20240922221458_add_compensation_to_job_applications_settings.rb` -- iterates records, merges into existing JSONB `settings`, uses `update_columns` to bypass callbacks, `down` raises `IrreversibleMigration`.
- **Secondary:** `SetDefaultModalDisplaySettings` at `db/data/20251025011948_set_default_modal_display_settings.rb` -- `find_each`, skip if already present, `save(validate: false)`, `down` raises `IrreversibleMigration`.

---

## Files to Create or Modify

### New files

| # | File | Purpose |
|---|---|---|
| 1 | `db/data/YYYYMMDDHHMMSS_add_weekly_digest_email_preference.rb` | Data migration: adds `email_weekly_digest: true` to all existing org_user `settings` JSONB |
| 2 | `app/services/weekly_digest_classifier.rb` | Bucket classifier: returns `:all_counts_zero`, `:passive_flow`, or `:active_team` from analyzer output |
| 3 | `app/mailers/weekly_digest_mailer.rb` | Builds `message_params` for the digest email, maps bucket to template name, sends via `Emails::SendTemplateEmail` |
| 4 | `app/jobs/weekly_digest_job.rb` | Per-org_user orchestrator: analyzer -> classifier -> mailer |
| 5 | `spec/services/weekly_digest_classifier_spec.rb` | Unit tests for classifier bucket logic |
| 6 | `spec/services/engagement_report/organization_analyzer_spec.rb` | Unit tests for analyzer extensions |
| 7 | `spec/jobs/weekly_digest_job_spec.rb` | Unit tests for job orchestration |
| 8 | `spec/mailers/weekly_digest_mailer_spec.rb` | Unit tests for mailer message_params |
| 9 | `spec/data_migrations/add_weekly_digest_email_preference_spec.rb` | Unit tests for data migration |

### Modified files

| # | File | Change |
|---|---|---|
| 10 | `app/models/organization_user.rb` | Add `email_weekly_digest: true` to `default_settings` hash; add `receives_weekly_digest_emails` scope |
| 11 | `app/services/engagement_report/organization_analyzer.rb` | Add `organization_user_id:` and `since:` params; branch `load_base_ids` for org_user scoping; add `ChannelMessage` query method |
| 12 | `app/controllers/api/v1/me_controller.rb` | Add `:email_weekly_digest` to `settings_params` permit list |
| 13 | `app/javascript/shared/types/user.ts` | Add `emailWeeklyDigest: boolean` to `UserSettings` interface |
| 14 | `app/javascript/ats/src/views/accountAdmin/AccountPreferences.tsx` | Add new "Weekly digest" section with one `FormCheckbox` |
| 15 | `lib/tasks/recurring_tasks.rake` | Add `weekly_engagement_digest` task |

---

## Backend Changes

### Step 1: Data Migration
**Read before implementing:** `cursor_rules/backend/migrations.md`

**File:** `db/data/YYYYMMDDHHMMSS_add_weekly_digest_email_preference.rb`

**Class name:** `AddWeeklyDigestEmailPreference` (matches `SetEmailPreferences` precedent at `db/data/20220302005956_set_email_preferences.rb`).

**Inherits:** `ActiveRecord::Migration[6.0]` (matching all existing data migrations).

**`up` method:**
```ruby
OrganizationUser.find_each do |org_user|
  existing_settings = org_user.settings || {}
  next if existing_settings.key?('email_weekly_digest')

  existing_settings['email_weekly_digest'] = true
  org_user.update_columns(settings: existing_settings)
end
```

Key details:
- Uses `find_each` for batching (per `migrations.md` guidance for large datasets).
- Uses `update_columns` to bypass model validations and callbacks (matching `AddCompensationToJobApplicationsSettings` precedent).
- Skips records that already have the key, making it safe to re-run.
- String key (`'email_weekly_digest'`) because JSONB stores string keys.

**`down` method:**
```ruby
raise ActiveRecord::IrreversibleMigration

# Uncomment below during active development if you need to rollback:
# OrganizationUser.find_each do |org_user|
#   existing_settings = org_user.settings || {}
#   existing_settings.delete('email_weekly_digest')
#   org_user.update_columns(settings: existing_settings)
# end
```

Matches `migrations.md` pattern: production raises, development has commented-out reverse logic.

### Step 2: OrganizationUser Model Update
**Read before implementing:** `cursor_rules/core_critical_rules.md`

**File:** `app/models/organization_user.rb`

Two changes:

**2a.** Add `email_weekly_digest: true` to `default_settings` (line 83-89):
```ruby
def default_settings
  {
    email_job_applications_new: true,
    email_comments_new: true,
    email_messages_new: true,
    email_weekly_digest: true
  }
end
```

This ensures new org_users created after deploy get the key. The `Settingsable#add_default_settings` callback (`after_create`) calls `update_settings(settingsable_settings) if settings.blank?` -- so the new key is automatically included for fresh records. For existing org_users whose `settings` is already non-blank, the data migration (Step 1) handles backfill.

**Note on `add_new_default_settings`:** The `Settingsable` concern at `settingsable.rb:16-24` has an `add_new_default_settings` method that iterates `settingsable_settings` and adds any key whose value is `nil` in the current settings. This method exists for rake-task-driven backfills. The data migration approach is preferred here because `add_new_default_settings` would require a separate rake task invocation and uses `save` (which triggers callbacks), while the migration uses `update_columns` (which skips them). The data migration is more atomic and self-contained.

**2b.** Add a convenience scope (near line 37, alongside the existing `receives_*` scopes):
```ruby
scope :receives_weekly_digest_emails, -> { with_preference_for(:email_weekly_digest) }
```

This is not strictly required (the rake task can call `with_preference_for(:email_weekly_digest)` directly), but it matches the pattern of the three existing `receives_*` scopes at lines 35-37.

### Step 3: Analyzer Extensions
**Read before implementing:** `cursor_rules/backend/services.md`, `cursor_rules/core_critical_rules.md`

**File:** `app/services/engagement_report/organization_analyzer.rb`

Three changes to the existing `OrganizationAnalyzer` class:

**3a. Constructor signature** (line 5):
```ruby
def initialize(organization:, months: 6, organization_user_id: nil, since: nil)
  @organization = organization
  @months = months
  @organization_user_id = organization_user_id
  @cutoff = since || months.months.ago
end
```

Both new params default to `nil`. The existing caller (`ReportGenerator` at `report_generator.rb:17`) passes only `organization:` and hits the defaults -- backward compatible.

**3b. `load_base_ids` branching** (line 47-51):

Replace the current `load_base_ids` with:
```ruby
def load_base_ids
  @job_ids = scoped_job_ids
  @candidate_ids = Candidate.where(id: JobApplication.where(job_id: @job_ids).select(:candidate_id)).select(:id)
  @job_application_ids = JobApplication.where(job_id: @job_ids).select(:id)
end
```

Add a new private method:
```ruby
def scoped_job_ids
  if @organization_user_id
    org_user = @organization.organization_users.find_by(id: @organization_user_id)
    return @organization.jobs.none.select(:id) unless org_user

    if org_user.is_admin
      @organization.jobs.select(:id)
    else
      org_user.jobs.select(:id)
    end
  else
    @organization.jobs.select(:id)
  end
end
```

Key details:
- When `organization_user_id` is nil (existing caller), behavior is identical to today: `@organization.jobs.select(:id)`.
- When provided, loads the org_user, checks `is_admin` (method at `organization_user.rb:54` -- returns `org_admin? || is_owner`). Admins get all org jobs. Non-admins get `org_user.jobs` which goes through `has_many :jobs, through: :hiring_team_memberships` (line 15).
- `@candidate_ids` and `@job_application_ids` are now derived from `@job_ids` rather than from `@organization` directly. This ensures the scoping cascades correctly. The current code uses `@organization.candidates.select(:id)` and `@organization.job_applications.select(:id)` which are equivalent when `@job_ids` is all org jobs, but diverge when org_user scoping limits `@job_ids`.
- Guard clause: if `find_by` returns nil (invalid org_user_id), returns `@organization.jobs.none.select(:id)` so downstream queries produce zero counts rather than raising. The job's own guard clause (`find_by` + `return unless`) should prevent this path, but defense-in-depth.

**3c. New `channel_message_metrics` method:**

Add to the `candidate_management_metrics` return hash:
```ruby
def candidate_management_metrics
  {
    stage_moves: stage_move_metrics,
    candidate_updates: candidate_update_metrics,
    job_application_updates: job_application_update_metrics,
    comments: comment_metrics,
    reviews: review_metrics,
    channel_messages: channel_message_metrics
  }
end
```

New private method:
```ruby
def channel_message_metrics
  messages = ChannelMessage
    .joins(channel: :job_application)
    .where(job_applications: { id: @job_application_ids })
    .where('channel_messages.created_at > ?', @cutoff)

  sent_by_user = messages.where(sent_by: :sent_by_user).count
  sent_by_organization = messages.where(sent_by: :sent_by_organization).count

  {
    messages_sent_by_user: sent_by_user,
    messages_sent_by_organization: sent_by_organization,
    messages_sent_total: sent_by_user + sent_by_organization,
    messages_received: messages.where(sent_by: :sent_by_candidate).count
  }
end
```

Key details:
- Joins `ChannelMessage` -> `Channel` (via `belongs_to :channel` at `channel_message.rb:9`) -> `JobApplication` (via `belongs_to :job_application` at `channel.rb:6`).
- Filters by `@job_application_ids` and `@cutoff` timestamp. This pattern matches existing metrics (e.g., `stage_move_metrics` at lines 155-166 filters by `@job_application_ids` and `@cutoff`).
- `sent_by` enum values at `channel_message.rb:27-32`: `sent_by_system: 0`, `sent_by_user: 1`, `sent_by_candidate: 2`, `sent_by_organization: 3`.
- `messages_sent_total` sums user + organization (excludes `sent_by_system` and `sent_by_candidate`). The spec notes the parenthetical "equivalently: not `sent_by_candidate`" is superseded by the primary definition.
- Existing churn-monitoring caller (`ReportGenerator`) does not use `channel_messages` from the result today. Adding the key to the return hash is additive and does not break the existing consumer (the Google Sheets sender serializes whatever payload `build_payload` produces, and `build_payload` cherry-picks specific keys -- it will simply not access `channel_messages` unless updated).

**IMPORTANT: `build_result` must also be updated.** The `build_result` method (lines 344-428) cherry-picks keys from `candidate_mgmt` to produce the final result hash. It does NOT automatically include new keys added to `candidate_management_metrics`. Add `channel_messages: candidate_mgmt[:channel_messages]` to the `candidate_management` section of `build_result` (after line 407, alongside the existing `reviews` entry). Without this, `result[:candidate_management][:channel_messages]` will be nil when accessed by the digest job's `extract_metrics` method. This is a safe, additive change -- the existing `ReportGenerator` consumer does not access `[:channel_messages]`.

**Backward compatibility verification:**
- `ReportGenerator` at `report_generator.rb:17` calls `OrganizationAnalyzer.new(organization: @organization).analyze` -- passes only `organization:`. The new `organization_user_id: nil` and `since: nil` defaults mean `@cutoff` resolves to `6.months.ago` (via `months.months.ago`) and `scoped_job_ids` takes the `else` branch (all org jobs). No behavioral change.
- The new `channel_message_metrics` key in the `candidate_management_metrics` hash is additive. `ReportGenerator#build_payload` at `report_generator.rb:29-69` accesses `candidate_mgmt[:stage_moves]`, `[:comments]`, `[:reviews]`, `[:candidate_updates]`, `[:job_application_updates]` -- it does not access `[:channel_messages]`. The new key is silently ignored.

**Scoping gap for `inbound_metrics` and `job_metrics`:** The `load_base_ids` changes (Step 3b) scope `@job_ids`, `@job_application_ids`, and `@candidate_ids` for org_user-scoped calls. However, `inbound_metrics` (line 62) uses `@organization.job_applications` directly and `job_metrics` (line 91) uses `@organization.jobs` directly -- neither uses the scoped instance variables. For non-admin org_users, `applications_received` and `jobs_published` will be org-wide, not scoped to their hiring-team jobs. The implementation agent must either: (a) modify these methods to use `@job_ids`/`@job_application_ids` when `@organization_user_id` is present, (b) have the digest job compute these metrics directly from the org_user's scoped associations, or (c) confirm with Jessica that org-wide counts are acceptable for these two metrics (since they represent organizational activity the user benefits from knowing about even if they can only act on their assigned jobs).

### Step 4: Bucket Classifier
**Read before implementing:** `cursor_rules/backend/services.md`

**File:** `app/services/weekly_digest_classifier.rb`

**Class name:** `WeeklyDigestClassifier` (no "Service" suffix per `services.md` rule 1).

**Location:** Flat in `app/services/` (not namespaced under `engagement_report/` -- it is a digest-specific service, not a general engagement report component).

```ruby
# frozen_string_literal: true

class WeeklyDigestClassifier
  def initialize(metrics:)
    @metrics = metrics
  end

  def classify
    if active_team?
      :active_team
    elsif passive_flow?
      :passive_flow
    else
      :all_counts_zero
    end
  end

  private

  def active_team?
    @metrics[:stage_moves].to_i > 0 ||
      @metrics[:comments].to_i > 0 ||
      @metrics[:reviews].to_i > 0 ||
      @metrics[:messages_sent_by_user].to_i > 0
  end

  def passive_flow?
    @metrics[:applications_received].to_i > 0 ||
      @metrics[:messages_sent_by_organization].to_i > 0
  end
end
```

Key details:
- Constructor uses keyword arguments per `services.md` rule 5.
- Public method is `classify` (descriptive, not `call` or `execute`, per `services.md` rule 2).
- The `metrics` hash is assembled by the job from analyzer output (see Step 6). Using `.to_i` on each value is defensive -- ensures nil-safety without needing explicit nil checks.
- Bucket priority: `:active_team` > `:passive_flow` > `:all_counts_zero` (per spec logic at line 166-169).

### Step 5: Weekly Digest Mailer
**Read before implementing:** `cursor_rules/backend/background_jobs.md` (rule 0b, rule 6 -- `deliver_later` note), `cursor_rules/core_critical_rules.md` (rule 7: snake_case backend)

**File:** `app/mailers/weekly_digest_mailer.rb`

**Inherits:** `ApplicationMailer` (at `app/mailers/application_mailer.rb`).

**One method** (`digest` or `weekly_digest`) receives the bucket symbol, org_user, and computed data, then maps the bucket to its template name and sends via `Emails::SendTemplateEmail`.

```ruby
# frozen_string_literal: true

class WeeklyDigestMailer < ApplicationMailer
  TEMPLATE_MAP = {
    all_counts_zero: 'user-weekly-digest-zero',
    passive_flow: 'user-weekly-digest-passive',
    active_team: 'user-weekly-digest-active'
  }.freeze

  def weekly_digest(organization_user_id:, bucket:, metrics:)
    org_user = OrganizationUser.find_by(id: organization_user_id)
    return unless org_user

    user = org_user.user
    organization = org_user.organization

    template_name = TEMPLATE_MAP[bucket]
    return unless template_name

    to_name = "#{user.first_name} #{user.last_name}".strip

    message_params = {
      from: { name: 'Jessica from Polymer', email: Variables::EMAIL_HELLO_ADDRESS },
      to: [{ name: to_name, email: user.email }],
      list_unsubscribe: "mailto:#{Variables::REPLY_TO_EMAIL_ADDRESS}",
      subject: "Your week at #{organization.name}",
      template: template_name,
      template_version: 'initial',
      tags: ['hire', 'user-facing'],
      variables: build_variables(user: user, organization: organization, metrics: metrics)
    }

    Emails::SendTemplateEmail.new(message_params).send
  end

  private

  def build_variables(user:, organization:, metrics:)
    {
      recipient_first_name: user.first_name,
      organization_name: organization.name,
      applications_received: metrics[:applications_received].to_i,
      stage_moves: metrics[:stage_moves].to_i,
      jobs_published: metrics[:jobs_published].to_i,
      comments: metrics[:comments].to_i,
      reviews: metrics[:reviews].to_i,
      messages_sent_total: metrics[:messages_sent_total].to_i,
      messages_received: metrics[:messages_received].to_i,
      top_job_title: metrics[:top_job_title] || '',
      top_job_application_count: metrics[:top_job_application_count].to_i,
      jobs_url: "#{Variables::AtsRootUrl}/jobs?utm_source=weeklyDigestEmail",
      app_preferences_url: "#{Variables::ATS_PREFERENCES_URL}?utm_source=weeklyDigestEmail",
      unsubscribe_url: "#{Variables::ATS_PREFERENCES_URL}?utm_source=weeklyDigestEmail"
    }
  end
end
```

Key details:
- **From address:** `Variables::EMAIL_HELLO_ADDRESS` (`hello@mail.polymer.co`) per spec, NOT `EMAIL_NOTIFICATIONS_ADDRESS`. Display name is `'Jessica from Polymer'` per spec.
- **Template names:** Placeholder names (`user-weekly-digest-zero`, `user-weekly-digest-passive`, `user-weekly-digest-active`). These are the names Jessica will use when creating the Mailgun stored templates. If she chooses different names, update `TEMPLATE_MAP`.
- **Tags:** `['hire', 'user-facing']` matching `CommentMailer` and `JobApplicationMailer`. `SendTemplateEmail` auto-appends the template name as a 3rd tag (at `send_template_email.rb:90`). Max 2 custom tags enforced at line 86.
- **`list_unsubscribe`:** Placeholder using `mailto:` fallback to `Variables::REPLY_TO_EMAIL_ADDRESS` (`support@polymer.co`). Matches `CommentMailer` pattern at line 53. The real unsubscribe URL is added later per spec.
- **`unsubscribe_url` variable:** Points to the in-app preferences page as a placeholder. The Mailgun template will render an unsubscribe link using this variable. The real unsubscribe endpoint is added in a future pass.
- **`template_version: 'initial'`:** Matches all existing mailers.
- The `to_name` construction (`"#{user.first_name} #{user.last_name}".strip`) matches `CommentMailer` at line 43.
- Method receives `organization_user_id:` (not the object) for consistency with job invocation, but the mailer is called from within `WeeklyDigestJob` which already loaded the record. Passing the ID and re-loading is safer (the mailer may be called via `deliver_later` in other contexts). However, since the spec notes the job calls the mailer directly (not via `deliver_later`), passing the loaded objects is also acceptable. The plan uses IDs for consistency with `background_jobs.md` rule 1.

### Step 6: Weekly Digest Job
**Read before implementing:** `cursor_rules/backend/background_jobs.md`

**File:** `app/jobs/weekly_digest_job.rb`

**Location:** Flat in `app/jobs/` (not namespaced). The spec names it `weekly_digest_job.rb` at `app/jobs/`. Both flat and namespaced patterns exist in the codebase (`app/jobs/export_job_candidates_to_csv_job.rb` is flat; `app/jobs/engagement_report/generator_job.rb` is namespaced). Flat is the spec's choice and is simpler for a single file.

```ruby
# frozen_string_literal: true

class WeeklyDigestJob < ApplicationJob
  queue_as :default

  def perform(organization_user_id)
    ap "WeeklyDigestJob starting for org_user #{organization_user_id}"

    org_user = OrganizationUser.find_by(id: organization_user_id)
    unless org_user
      ap "WeeklyDigestJob - org_user #{organization_user_id} not found"
      return
    end

    organization = org_user.organization

    # Run analyzer scoped to this org_user over the past 7 days
    analyzer = EngagementReport::OrganizationAnalyzer.new(
      organization: organization,
      organization_user_id: org_user.id,
      since: 1.week.ago
    )
    result = analyzer.analyze
    return unless result

    # Extract metrics for classifier and mailer
    metrics = extract_metrics(result, organization)

    # Classify into bucket
    bucket = WeeklyDigestClassifier.new(metrics: classifier_metrics(metrics)).classify

    # Send the digest email
    WeeklyDigestMailer.weekly_digest(
      organization_user_id: org_user.id,
      bucket: bucket,
      metrics: metrics
    )

    ap "WeeklyDigestJob completed for org_user #{organization_user_id}"
  rescue StandardError => e
    ap "WeeklyDigestJob FAILED for org_user #{organization_user_id}: #{e.message}"
    Rails.logger.error "WeeklyDigestJob failed for org_user #{organization_user_id}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end

  private

  def extract_metrics(result, organization)
    candidate_mgmt = result[:candidate_management]
    inbound = result[:inbound]
    setup = result[:setup_activity]
    channel_msgs = candidate_mgmt[:channel_messages]

    # Top job by application volume
    top_job = top_job_by_applications(organization, result)

    {
      applications_received: inbound[:total_applications],
      stage_moves: candidate_mgmt[:stage_moves][:count],
      jobs_published: setup[:jobs][:published],
      comments: candidate_mgmt[:comments][:count],
      reviews: candidate_mgmt[:reviews][:total],
      messages_sent_by_user: channel_msgs[:messages_sent_by_user],
      messages_sent_by_organization: channel_msgs[:messages_sent_by_organization],
      messages_sent_total: channel_msgs[:messages_sent_total],
      messages_received: channel_msgs[:messages_received],
      top_job_title: top_job[:title],
      top_job_application_count: top_job[:count]
    }
  end

  def classifier_metrics(metrics)
    {
      stage_moves: metrics[:stage_moves],
      comments: metrics[:comments],
      reviews: metrics[:reviews],
      messages_sent_by_user: metrics[:messages_sent_by_user],
      applications_received: metrics[:applications_received],
      messages_sent_by_organization: metrics[:messages_sent_by_organization]
    }
  end

  def top_job_by_applications(organization, result)
    # The analyzer doesn't compute per-job application counts,
    # so we query directly using the same scoping
    # This is a lightweight query: count grouped by job_id, ordered, limit 1
    job_app_counts = JobApplication
      .where(job_id: organization.jobs.select(:id))
      .where('job_applications.created_at > ?', 1.week.ago)
      .group(:job_id)
      .count

    return { title: '', count: 0 } if job_app_counts.empty?

    # Pick the job with the most applications; tie-break by lowest job_id
    top_job_id = job_app_counts.max_by { |job_id, count| [count, -job_id] }&.first
    top_job = Job.find_by(id: top_job_id)

    {
      title: top_job&.title || '',
      count: job_app_counts[top_job_id] || 0
    }
  end
end
```

Key details:
- **`find_by` + guard clause** (per `background_jobs.md` rule 2).
- **Method-level `rescue StandardError`** with `ap` + `Rails.logger.error` + backtrace (per `background_jobs.md` rule 4, matching `EngagementReport::GeneratorJob` at lines 22-26).
- **No re-raise** -- job completes, does not retry (per `background_jobs.md` "don't re-raise" guidance).
- **`queue_as :default`** (matching all existing jobs).
- The job delegates to analyzer, classifier, and mailer (per `background_jobs.md` rule 3: "Jobs Orchestrate -- Don't Contain Business Logic"). The `extract_metrics` and `top_job_by_applications` helpers are lightweight data extraction, not business logic.
- **Top job computation:** The analyzer does not produce per-job application breakdowns. The job runs a simple `group(:job_id).count` query. On a tie, picks the job with the most applications, then lowest `job_id` (per spec: "On a tie, picks one arbitrarily (e.g., by lowest `job.id`)").
- **Note on org_user scoping for top_job:** The `top_job_by_applications` method currently uses `organization.jobs` (org-wide) regardless of the org_user's admin status. This is intentional for admin org_users. For non-admin org_users, it should use the same job scoping as the analyzer. The implementation agent should use `org_user.is_admin ? organization.jobs : org_user.jobs` to scope the top-job query correctly for non-admin users. This is flagged as a detail the implementation agent must handle.
- The mailer is called directly (not via `deliver_later`) since we are already in a background job. The spec notes this is acceptable.

### Step 7: Rake Task
**Read before implementing:** `cursor_rules/core_critical_rules.md`

**File:** `lib/tasks/recurring_tasks.rake`

Add a new top-level task after the `engagement_reports` task (after line 159). Named `weekly_engagement_digest` to match the descriptive style of its neighbors.

```ruby
desc 'Send weekly engagement digest to all eligible organization users'
task weekly_engagement_digest: :environment do
  puts 'Starting weekly engagement digest...'
  count = 0

  # Stagger to avoid Mailgun API throttling
  # Per org_user = more jobs than engagement_reports (per org)
  # Use a shorter stagger since the work per job is lighter
  delay_between_jobs = Rails.env.production? ? 10.seconds : 2.seconds

  Organization.claimed.find_each do |organization|
    next unless organization.active_paid_plan?

    organization.organization_users.actives.with_preference_for(:email_weekly_digest).find_each do |org_user|
      WeeklyDigestJob.set(wait: count * delay_between_jobs).perform_later(org_user.id)
      count += 1
    end
  end

  puts "Queued weekly engagement digest for #{count} organization users (staggered #{delay_between_jobs.to_i}s apart)"
  puts 'done.'
end
```

Key details:
- **Eligibility:** `Organization.claimed` (scope at `organization.rb:130`) + `active_paid_plan?` (method at `organization.rb:651`) -- matching `engagement_reports` at rake line 149-150.
- **Preference filter:** `organization_users.actives.with_preference_for(:email_weekly_digest)` -- `actives` scope at `organization_user.rb:48`, `with_preference_for` at `organization_user.rb:165-169`.
- **Stagger:** 10 seconds production / 2 seconds dev. The `engagement_reports` task uses 30s/5s for per-org jobs that hit the Google Sheets API. The digest has more jobs (per org_user, not per org) but each does less external API work (one Mailgun send vs Google Sheets API). 10s is conservative; can be tuned after initial production runs.
- **No day-of-week check** -- unlike `engagement_reports` which has a `Date.current.sunday? || Date.current.wednesday?` guard, the digest task has none. Heroku Scheduler handles the Monday-only scheduling. The task is invocable any time for testing.
- **`find_each`** for both org loop and org_user loop (batched loading for memory efficiency).

### Step 8: Settings Params Update (ATOMIC with Steps 13-14)
**Read before implementing:** `cursor_rules/core_critical_rules.md` (rule 5: one params method per controller)

**File:** `app/controllers/api/v1/me_controller.rb`

Add `:email_weekly_digest` to the `settings_params` permit list (line 129):

```ruby
def settings_params
  params.require(:settings).permit(:email_job_applications_new, :email_comments_new, :email_messages_new, :email_weekly_digest)
end
```

**CRITICAL:** This must deploy atomically with the `UserSettings` TypeScript interface update (Step 13) and the `AccountPreferences.tsx` UI change (Step 14). See Deploy Order section.

---

## Frontend Changes

### Step 13: UserSettings Type Update (ATOMIC with Steps 8, 14)
**Read before implementing:** `cursor_rules/frontend/_base.md` (rule 3: trust API transformation; rule 7: camelCase), `cursor_rules/core_critical_rules.md` (rule 7: camelCase frontend)

**File:** `app/javascript/shared/types/user.ts`

Add `emailWeeklyDigest: boolean` to the `UserSettings` interface:

```typescript
export interface UserSettings {
  emailJobApplicationsNew: boolean;
  emailCommentsNew: boolean;
  emailMessagesNew: boolean;
  emailWeeklyDigest: boolean;
}
```

Key details:
- camelCase on the frontend, matching the existing keys. The API transformation layer converts to/from `email_weekly_digest` (snake_case backend) automatically.
- The `updateSettings` function at `useMe.ts:32-35` sends the full `UserSettings` object to `PUT /me/update_settings`. With the new key in the type, TypeScript will enforce that `emailWeeklyDigest` is present when calling `updateSettings`.

### Step 14: AccountPreferences UI Update (ATOMIC with Steps 8, 13)
**Read before implementing:** `cursor_rules/frontend/_base.md`, `cursor_rules/frontend/forms/` (if exists), `cursor_rules/core_critical_rules.md` (rule 9: never deliberately set undefined)

**File:** `app/javascript/ats/src/views/accountAdmin/AccountPreferences.tsx`

Two changes:

**14a.** Add `emailWeeklyDigest` to the destructuring at line 27:
```typescript
const { emailCommentsNew, emailMessagesNew, emailJobApplicationsNew, emailWeeklyDigest } = settings;
```

**14b.** Add a new `FormSection` after the existing "Notifications" `FormSection` (after the closing `</FormSection>` at line 155, before `</FormContainer>`):
```tsx
<FormSection title="Weekly digest">
  <FormFieldset
    legend="Email"
    description="Receive a weekly summary of your hiring activity."
  >
    <FormCheckbox
      name="emailWeeklyDigest"
      label="Weekly engagement digest"
      checked={emailWeeklyDigest}
      onChange={handleEmailPreferenceChange}
    />
  </FormFieldset>
</FormSection>
```

Key details:
- **New `FormSection`** (not a new `FormFieldset` within the existing "Notifications" section). The spec says "new section... separate from the existing job-notification preferences section."
- Uses the existing `FormSection`, `FormFieldset`, and `FormCheckbox` components -- no new UI components.
- The `name="emailWeeklyDigest"` matches the `UserSettings` interface key. The `handleEmailPreferenceChange` handler at line 82-88 uses `Object.assign({}, settings, { [name]: value })` which dynamically sets any key -- it already works for the new preference without modification.
- The `handleSubmitForm` at line 65-80 spreads `{ ...settings }` into `updateSettings(...)` which sends the full settings object to the API. With `emailWeeklyDigest` now in the settings state, it is included in the PUT payload.
- The `checked` prop reads `emailWeeklyDigest` from the destructured settings. For org_users who have not yet received the data migration (edge case: migration hasn't run), this would be `undefined`. The `FormCheckbox` component passes `checked` directly to `<input checked={checked} />` -- React treats `undefined` as `false` for the `checked` prop, so the checkbox would appear unchecked. This is acceptable behavior (the user can check it manually).
- **No `useMemo` needed** for the new section (per `_base.md` rule 6: don't use `useMemo` for minor computation).

---

## Validation and Constraints

1. **`settings_params` permit list** -- the only input validation for the preference. Rails strong parameters permit `:email_weekly_digest`. The value must be a boolean. `MeController#update_settings` at line 54-59 does `current_organization_user.update(settings: temp_params)` -- this is a full JSONB column replacement with only the permitted keys. No additional server-side validation needed (the column accepts any JSON, and the permit list constrains the keys).

2. **Analyzer scoping** -- `organization_user_id` is validated by `find_by` in `scoped_job_ids`. Invalid IDs produce an empty job set (zero counts), which is safe behavior.

3. **Bucket classifier** -- defensive `.to_i` on all input values ensures nil/missing keys produce 0 (falsy), which maps to `:all_counts_zero`. No explicit validation needed.

4. **Mailer template mapping** -- `TEMPLATE_MAP[bucket]` returns nil for unknown buckets; the `return unless template_name` guard prevents sending with an invalid template.

5. **Job guard clause** -- `find_by` + `return unless org_user` prevents processing deleted/invalid org_users.

6. **Rake task eligibility** -- reuses existing `Organization.claimed`, `active_paid_plan?`, `actives`, and `with_preference_for` -- no new eligibility logic to validate.

---

## Test Plan

The spec directory structure uses `spec/interactors/` and `spec/requests/` but has no `spec/services/`, `spec/jobs/`, `spec/mailers/`, or `spec/data_migrations/` directories. The implementation agent should create the necessary directories.

The codebase does not use FactoryBot. Test objects are created manually using `create!`, matching the pattern in `spec/support/api_factories.rb`.

### New RSpec Spec Files

**1. `spec/services/weekly_digest_classifier_spec.rb`**

Test cases:
- Returns `:all_counts_zero` when all metrics are zero
- Returns `:all_counts_zero` when all metrics are nil
- Returns `:passive_flow` when only `applications_received` > 0
- Returns `:passive_flow` when only `messages_sent_by_organization` > 0
- Returns `:passive_flow` when both `applications_received` and `messages_sent_by_organization` > 0
- Returns `:active_team` when only `stage_moves` > 0
- Returns `:active_team` when only `comments` > 0
- Returns `:active_team` when only `reviews` > 0
- Returns `:active_team` when only `messages_sent_by_user` > 0
- Returns `:active_team` even when passive metrics are also non-zero (priority test)

This spec is pure unit -- no database needed. Instantiate with a metrics hash and assert the return value.

**2. `spec/services/engagement_report/organization_analyzer_spec.rb`**

Test cases:
- Existing caller behavior: passes only `organization:`, gets correct results (backward compat)
- `since:` parameter overrides `months:` for cutoff
- `organization_user_id:` for admin org_user returns org-wide data
- `organization_user_id:` for non-admin org_user returns scoped data (only hiring-team jobs)
- `organization_user_id:` for non-existent org_user returns zero counts
- `channel_message_metrics` returns correct counts grouped by `sent_by` type
- `channel_message_metrics` excludes messages outside the cutoff window
- `channel_message_metrics` excludes `sent_by_system` messages from sent totals

This spec requires database records. Create an organization, org_users, jobs, hiring_team_memberships, job_applications, channels, and channel_messages. Use the `ApiFactories#create_api_test_setup` helper as a starting point for the organization/user/org_user setup.

**3. `spec/jobs/weekly_digest_job_spec.rb`**

Test cases:
- Runs analyzer with correct parameters (organization, organization_user_id, since: 1.week.ago)
- Passes analyzer output to classifier
- Triggers mailer with correct bucket and data
- Returns early (no error) when org_user not found
- Rescues StandardError and logs (does not re-raise)

Use `allow`/`expect` on `EngagementReport::OrganizationAnalyzer`, `WeeklyDigestClassifier`, and `WeeklyDigestMailer` to verify the orchestration without needing full integration data.

**4. `spec/mailers/weekly_digest_mailer_spec.rb`**

Test cases:
- Builds `message_params` with correct `from` (name: 'Jessica from Polymer', email: EMAIL_HELLO_ADDRESS)
- Builds `message_params` with correct `to` (recipient name and email)
- Maps `:all_counts_zero` bucket to `'user-weekly-digest-zero'` template
- Maps `:passive_flow` bucket to `'user-weekly-digest-passive'` template
- Maps `:active_team` bucket to `'user-weekly-digest-active'` template
- Subject is `"Your week at [Organization Name]"`
- Variables hash includes all required keys
- Returns early when org_user not found
- Calls `Emails::SendTemplateEmail.new(message_params).send`

Stub `Emails::SendTemplateEmail` to capture the `message_params` and verify the shape.

**5. `spec/data_migrations/add_weekly_digest_email_preference_spec.rb`**

Test cases:
- Adds `email_weekly_digest: true` to org_users missing the key
- Skips org_users that already have `email_weekly_digest` in settings
- Preserves existing settings keys when adding the new key
- `down` raises `ActiveRecord::IrreversibleMigration`

Requires creating org_user records with various settings states and running the migration.

### Existing Tests to Update

None identified. The existing analog code has no tests. The `OrganizationUser#default_settings` hash is not directly tested.

### Frontend Tests

None required. The existing preference checkboxes in `AccountPreferences.tsx` have no component tests. The new checkbox follows the identical pattern. Manual QA should verify:
- The checkbox appears in the "Weekly digest" section
- The checkbox reflects the current `emailWeeklyDigest` value from the API
- Toggling and saving round-trips correctly (check → save → reload → still checked; uncheck → save → reload → still unchecked)

---

## Deploy Order

### Phase A (safe to deploy early, independently)

1. **Data migration** (`db/data/YYYYMMDDHHMMSS_add_weekly_digest_email_preference.rb`) -- writes directly to the JSONB column via `update_columns`, does not go through `settings_params`. Safe to deploy before anything else.

2. **`default_settings` update** (`organization_user.rb`) -- affects only newly created org_users. The `add_default_settings` callback writes the full `default_settings` hash on create when `settings.blank?`. Does not interact with the settings save flow (no permit list involvement). Safe to deploy early.

3. **`receives_weekly_digest_emails` scope** (`organization_user.rb`) -- additive scope, no consumers until the rake task deploys. Safe to deploy with step 2.

### Phase B (safe to deploy independently, after or alongside Phase A)

4. **Analyzer extensions** (`organization_analyzer.rb`) -- backward compatible. Existing caller behavior unchanged.

5. **Bucket classifier** (`weekly_digest_classifier.rb`) -- new file, no consumers until the job deploys.

6. **Weekly digest mailer** (`weekly_digest_mailer.rb`) -- new file, no consumers until the job deploys.

7. **Weekly digest job** (`weekly_digest_job.rb`) -- new file, no consumers until the rake task deploys.

8. **Rake task** (`recurring_tasks.rake`) -- can deploy any time; it is not invoked until Jessica adds it to Heroku Scheduler. Even if deployed before the Mailgun templates are created, the `Emails::SendTemplateEmail` call would fail (Mailgun returns an error for missing templates), but the job's `rescue StandardError` catches it cleanly.

### Phase C (MUST DEPLOY ATOMICALLY)

9. **`settings_params` addition** (`me_controller.rb`) + **`UserSettings` interface update** (`user.ts`) + **`AccountPreferences.tsx` UI change**

**Why atomic:** `MeController#update_settings` at line 54 does `current_organization_user.update(settings: temp_params)` -- this is a full JSONB column replacement. The `settings_params` permit list at line 128-129 determines which keys `temp_params` contains. If the backend permits `email_weekly_digest` before the frontend sends it, any user who saves their existing preferences sends only the three old keys -- the backend writes those three keys as the complete `settings` column, silently deleting `email_weekly_digest`. Conversely, if the frontend sends `emailWeeklyDigest` before the backend permits it, the key is silently dropped by strong parameters -- harmless but the checkbox would not save.

**Deploy together** means they should be in the same deploy (same commit or same PR merged together). They do not need to be in a single commit.

### Phase D (external, parallel work)

10. **Three Mailgun stored templates** -- created by Jessica in the Mailgun control panel. Required before the rake task is activated in Heroku Scheduler. The template names must match `TEMPLATE_MAP` in `WeeklyDigestMailer`.

11. **Heroku Scheduler entry** -- Jessica configures `rake weekly_engagement_digest` at 00:00 UTC Monday. Done at go-live after all code is deployed and templates are created.

---

## Risks and Open Questions

### Risks

1. **JSONB full-replacement hazard.** The `MeController#update_settings` action does a full column replacement. This is an existing design pattern, not introduced by this feature. But it means any frontend form that sends `settings` must send ALL keys. If a future feature adds another settings key and that change doesn't coordinate with this one, the same silent-deletion problem recurs. This is a pre-existing architectural risk, not something this feature introduces or can fix.

2. **Mailgun template names.** The `TEMPLATE_MAP` in the mailer uses placeholder names. If Jessica chooses different names when creating the templates in Mailgun, the map must be updated. This is a coordination item, not a code risk.

3. **Analyzer performance.** Adding the `ChannelMessage` query adds one more database query per analyzer invocation. For the existing churn-monitoring use case, the query runs but the result is unused. The additional load is minimal (one count query with a join), but worth noting.

4. **Top job query in the job.** The `top_job_by_applications` method runs a separate `group(:job_id).count` query outside the analyzer. This is necessary because the analyzer does not produce per-job breakdowns. The query is lightweight (single aggregate), but it does not reuse the analyzer's `@job_ids` scoping directly -- it queries `organization.jobs` (or `org_user.jobs` for non-admins). The implementation agent must ensure the scoping matches.

5. **Stagger delay tuning.** The 10-second stagger is a starting guess. In production with many org_users, the total enqueue time could be long (e.g., 1000 org_users = ~2.8 hours of staggered processing). This is likely acceptable for a weekly digest (no urgency), but may need tuning.

### Open Questions (for implementation time)

1. **`List-Unsubscribe-Post` header.** `Emails::SendTemplateEmail#add_list_unsubscribe` at line 105-106 sets only `List-Unsubscribe`. The one-click POST header (`List-Unsubscribe-Post: List-Unsubscribe=One-Click`) makes compliant clients' native unsubscribe button POST immediately. Decide whether to add it now (requires modifying `SendTemplateEmail` or setting the header manually in the mailer) or with the real unsubscribe endpoint later. Recommendation: add it later with the real endpoint, since the placeholder unsubscribe URL does not have a POST handler.

2. **Exact Mailgun template names.** Settle when Jessica creates the templates. Update `TEMPLATE_MAP` to match.

3. **Exact copy for the "Weekly digest" section.** The section heading and checkbox label in `AccountPreferences.tsx` are placeholders. Jessica may want different copy (e.g., "Weekly summary" instead of "Weekly digest"). Settle during visual QA.

4. **Non-admin top job scoping.** The `top_job_by_applications` method in the job needs to scope by the org_user's hiring-team jobs for non-admin users. The implementation agent must handle this (see note in Step 6).

---

## Estimated Scope

| Category | Count |
|---|---|
| New files | 9 (4 app + 5 spec) |
| Modified files | 6 |
| Total files touched | 15 |
| Estimated new lines of code (app) | ~200 |
| Estimated new lines of code (spec) | ~300 |
| Estimated lines modified in existing files | ~30 |

The feature is medium-sized. The largest single file is the job (~80 lines). The analyzer modifications are ~40 lines of additions. The frontend changes are ~15 lines. The bulk of the work is in the specs.
