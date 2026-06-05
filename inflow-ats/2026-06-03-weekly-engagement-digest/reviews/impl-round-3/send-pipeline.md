# Send Pipeline -- Round 3

## Findings

### Round 2 BLOCKER fix verification

The Round 2 BLOCKER was: `weekly_digest_job.rb:29-33` called `WeeklyDigestMailer.weekly_digest(...)` without `.deliver_now`, resulting in the email never being sent due to Rails 6.1 ActionMailer lazy evaluation.

**Fix verified:**
- `weekly_digest_job.rb:29-33` now reads:
  ```ruby
  WeeklyDigestMailer.weekly_digest(
    organization_user_id: org_user.id,
    bucket: bucket,
    metrics: metrics
  ).deliver_now
  ```
- `.deliver_now` at line 33 forces ActionMailer to call `processed_mailer`, which executes the method body, which calls `Emails::SendTemplateEmail.new(message_params).send`. The email will be sent.

**Spec fix verified:**
- `weekly_digest_job_spec.rb:40` stubs: `allow(WeeklyDigestMailer).to receive(:weekly_digest).and_return(double(deliver_now: true))` -- returns a double that responds to `deliver_now`. CORRECT.
- `weekly_digest_job_spec.rb:55-73` ("triggers the mailer with the correct bucket and metrics and delivers"): creates a `message_delivery` double, stubs `.weekly_digest` to return it, runs the job, then verifies both `WeeklyDigestMailer.weekly_digest` was called with correct args AND `message_delivery.deliver_now` was called. This test would fail if the `.deliver_now` were removed from the job. CORRECT.

### Rake task

- Eligibility: `Organization.claimed.find_each` + `active_paid_plan?` -- matches `engagement_reports`. CORRECT.
- Preference filter: `organization_users.actives.with_preference_for(:email_weekly_digest)`. CORRECT.
- Stagger: `count * delay_between_jobs` (10s prod / 2s dev). Per-org_user granularity. CORRECT.
- `perform_later(org_user.id)` -- passes integer ID. Job receives `organization_user_id` and calls `OrganizationUser.find_by(id: organization_user_id)`. CORRECT.

### Job orchestration

- `find_by` + guard clause at lines 9-13. CORRECT.
- Analyzer instantiation at lines 17-21 with `organization:`, `organization_user_id:`, `since: 1.week.ago`. CORRECT.
- `result = analyzer.analyze` + guard `return unless result` at lines 22-23. CORRECT.
- `extract_metrics` reads from the analyzer result structure. Key path verified:
  - `result[:inbound][:total_applications]` -- from `build_result` line 411. CORRECT.
  - `result[:setup_activity][:jobs][:published]` -- from `build_result` line 421. CORRECT.
  - `result[:candidate_management][:stage_moves][:count]` -- from `build_result` line 439. CORRECT.
  - `result[:candidate_management][:comments][:count]` -- from `build_result` line 451. CORRECT.
  - `result[:candidate_management][:reviews][:total]` -- from `build_result` line 457. CORRECT.
  - `result[:candidate_management][:channel_messages]` -- from `build_result` line 460. Contains `:messages_sent_by_user`, `:messages_sent_by_organization`, `:messages_sent_total`, `:messages_received`. CORRECT.
- `classifier_metrics` extracts the 6 keys the classifier needs. CORRECT.
- `rescue StandardError` with `ap` + `Rails.logger.error`. Per `background_jobs.md`. CORRECT.

### Mailer message_params

- `from`: `{ name: 'Jessica from Polymer', email: Variables::EMAIL_HELLO_ADDRESS }`. `EMAIL_HELLO_ADDRESS` = `hello@mail.polymer.co` at `01_variables.rb:11`. CORRECT.
- `to`: `[{ name: to_name, email: user.email }]`. CORRECT.
- `list_unsubscribe`: `"mailto:#{Variables::REPLY_TO_EMAIL_ADDRESS}"`. `REPLY_TO_EMAIL_ADDRESS` = `support@polymer.co` at `01_variables.rb:9`. Matches `CommentMailer` pattern. CORRECT.
- `subject`: `"Your week at #{organization.name}"`. CORRECT per spec.
- `template`: From `TEMPLATE_MAP[bucket]`. Three buckets, three templates. CORRECT.
- `template_version`: `'initial'`. CORRECT.
- `tags`: `['hire', 'user-facing']`. 2 tags, within `SendTemplateEmail` max of 2 (auto-appends template name as 3rd). CORRECT.
- `variables`: All 14 keys present. CORRECT.

### SendTemplateEmail validation compliance

- `add_from`: `from` hash present with `:name` and `:email`. PASS.
- `add_to_recipients`: `to` array with one hash containing `:name` and `:email`. PASS.
- `add_subject`: subject string present and non-blank. PASS.
- `add_template`: `template` and `template_version` present and non-blank. PASS.
- `add_tags`: 2 tags (not > 2). PASS.
- `add_variables`: variables hash present and non-blank. PASS.
- `add_list_unsubscribe`: string present. PASS.

No issues found.
