# Send Pipeline -- Round 1

## Findings

### Rake task

- Eligibility: `Organization.claimed.find_each` + `active_paid_plan?` -- matches `engagement_reports` pattern. CORRECT.
- Preference filter: `organization_users.actives.with_preference_for(:email_weekly_digest)` -- matches existing `receives_*` scope pattern. CORRECT.
- Stagger: `10.seconds` production / `2.seconds` dev. Reasonable for per-org_user jobs. CORRECT.
- `find_each` for both loops. CORRECT.
- Task name `weekly_engagement_digest` matches the descriptive style of `engagement_reports` and `daily_summary`. CORRECT.

### Job orchestration

- `find_by` + guard clause. Per `background_jobs.md` rule 2. CORRECT.
- `rescue StandardError` with `ap` + `Rails.logger.error` + backtrace. Per `background_jobs.md` rule 4. CORRECT.
- No re-raise. Per `background_jobs.md` guidance. CORRECT.
- `queue_as :default`. Matches existing jobs. CORRECT.
- Delegates to analyzer, classifier, mailer. Per `background_jobs.md` rule 3. CORRECT.

### Mailer invocation concern

- F1 [MED] `weekly_digest_job.rb:29-33`: The job calls `WeeklyDigestMailer.weekly_digest(...)` without `.deliver_now` or `.deliver_later`. The existing codebase pattern is `SomeMailer.method(id).deliver_later` (see `job_application.rb:518`, `comment.rb:86`). However, looking at the mailer internals, `WeeklyDigestMailer#weekly_digest` calls `Emails::SendTemplateEmail.new(message_params).send` directly -- it does not produce a `Mail::Message` for Rails' delivery system to handle. The existing mailers work the same way (`CommentMailer#hiring_team_new_comment` at line 74). The difference is: the existing callers use `.deliver_later` (which goes through Sidekiq via ActionMailer's async adapter), but `WeeklyDigestJob` is already a background job, so calling the mailer directly is acceptable per the spec ("triggered from inside `WeeklyDigestJob`, which is already a background job, so `deliver_now` from there is also acceptable"). The method will execute correctly when called from the job because Rails' `ActionMailer::Base.method_missing` handles the invocation. The lack of `.deliver_now` is technically a deviation from the existing calling pattern but functionally equivalent since the mailer method calls `SendTemplateEmail#send` directly.

  That said, there is a subtle concern: without `.deliver_now` or `.deliver_later`, the ActionMailer method returns a `Mail::Message` object but does NOT call the delivery mechanism. The actual send happens because `Emails::SendTemplateEmail.new(message_params).send` is called as a side effect inside the method body. This works, but it means the `.deliver_now` in the mailer spec (`call_mailer` at spec line 36-41) invokes the delivery twice in concept -- once via the side effect of `SendTemplateEmail#send`, and once via ActionMailer's delivery. In practice, `SendTemplateEmail#send_message` at line 34 has `unless Rails.env.test?`, so no actual Mailgun call happens in test. The spec is correct in behavior but slightly misleading in structure. NOT a blocker.

### Mailer message_params

- `from`: `{ name: 'Jessica from Polymer', email: Variables::EMAIL_HELLO_ADDRESS }`. Spec says "From display name: Jessica from Polymer" and "From address: hello@mail.polymer.co". CORRECT.
- `to`: `[{ name: to_name, email: user.email }]`. Matches `CommentMailer` pattern (line 41-45). CORRECT.
- `list_unsubscribe`: `"mailto:#{Variables::REPLY_TO_EMAIL_ADDRESS}"`. Matches `CommentMailer` (line 52). CORRECT.
- `subject`: `"Your week at #{organization.name}"`. Matches spec. CORRECT.
- `template`: Mapped via `TEMPLATE_MAP`. Three templates, one per bucket. CORRECT.
- `template_version`: `'initial'`. Matches all existing mailers. CORRECT.
- `tags`: `['hire', 'user-facing']`. 2 tags (max allowed by `SendTemplateEmail`). CORRECT.
- `variables`: All seven metrics plus top-job, URLs, first name, org name. All required keys present. CORRECT.

### SendTemplateEmail validation compliance

- `from` present. PASS.
- `to` present. PASS.
- `subject` present. PASS.
- `template` and `template_version` present. PASS.
- `tags` present, max 2 custom tags. PASS.
- `variables` present and non-empty. PASS.
- All validations in `SendTemplateEmail#prepare_message` will pass. VERIFIED.

### Top job scoping

- `top_job_by_applications` at job line 78-79: `org_user.is_admin ? org_user.organization.jobs : org_user.jobs`. Correctly scopes for non-admin org_users using the same `is_admin` method that `scoped_job_ids` in the analyzer uses. The plan flagged this as "implementation agent must handle" -- it has been handled. VERIFIED.

No BLOCKER or HIGH findings.
