# Send Pipeline -- Round 4

## Findings

### Delivery chain (end-to-end re-verification)

1. **Rake task** (`recurring_tasks.rake:161-179`): `Organization.claimed.find_each` -> `active_paid_plan?` -> `organization_users.actives.with_preference_for(:email_weekly_digest).find_each` -> `WeeklyDigestJob.set(wait: count * delay_between_jobs).perform_later(org_user.id)`. Each eligible org_user gets one queued job. CORRECT.

2. **Job** (`weekly_digest_job.rb:6-40`): `OrganizationUser.find_by(id:)` + guard -> `OrganizationAnalyzer.new(...)` -> `analyze` + guard -> `extract_metrics` -> `WeeklyDigestClassifier.new(...).classify` -> `WeeklyDigestMailer.weekly_digest(...).deliver_now`. CORRECT.

3. **Mailer** (`weekly_digest_mailer.rb:10-33`): `OrganizationUser.find_by(id:)` + guard -> `TEMPLATE_MAP[bucket]` + guard -> build `message_params` -> `Emails::SendTemplateEmail.new(message_params).send`. CORRECT.

4. **SendTemplateEmail** (`send_template_email.rb:8-11`): `prepare_message` (validates all params, builds `Mailgun::MessageBuilder`) -> `send_message` (calls `email_client.send_message` unless test env). CORRECT.

### .deliver_now chain verification

`weekly_digest_job.rb:29-33`:
```ruby
WeeklyDigestMailer.weekly_digest(
  organization_user_id: org_user.id,
  bucket: bucket,
  metrics: metrics
).deliver_now
```

`ActionMailer::Base.method_missing` returns `MessageDelivery`. `.deliver_now` calls `processed_mailer.handle_exceptions`, which calls the mailer method body. The method body calls `Emails::SendTemplateEmail.new(message_params).send`. The email is sent. VERIFIED.

### Double org_user lookup

Both the job (line 9) and the mailer (line 11) call `OrganizationUser.find_by(id:)`. This means two database lookups for the same record. This is intentional and correct -- the mailer is an `ApplicationMailer` subclass that could be called from contexts other than the job (e.g., console, rake), so it must be self-contained with its own guard clause. The extra DB query is negligible compared to the analyzer's query cost. Not a finding.

### Stagger delay

`delay_between_jobs = Rails.env.production? ? 10.seconds : 2.seconds`. With `count * delay_between_jobs`, for N org_users the total stagger is N * 10s (prod). The `engagement_reports` task uses `30.seconds` prod / `5.seconds` dev per org. The digest has more granular jobs (per org_user vs per org), so the shorter delay is appropriate. Not a finding.

### Error handling

`rescue StandardError => e` at job line 36 with `ap` + `Rails.logger.error` + first 5 backtrace lines. No re-raise. This matches `EngagementReport::GeneratorJob` and `background_jobs.md` conventions. A failure for one org_user does not affect other org_users' digests. CORRECT.

### Template name safety

`TEMPLATE_MAP` is frozen (`TEMPLATE_MAP.freeze`). Bucket symbols `:all_counts_zero`, `:passive_flow`, `:active_team` are the only keys. The classifier only returns these three symbols. Any other value (impossible in normal flow, but if somehow injected) would return `nil` from the map, and the mailer's `return unless template_name` guard at line 18 would exit without sending. SAFE.

No issues found.
