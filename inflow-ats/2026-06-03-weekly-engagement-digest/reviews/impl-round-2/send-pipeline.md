# Send Pipeline -- Round 2

## Findings

### F1 [BLOCKER] weekly_digest_job.rb:29-33 -- Email is never sent

`WeeklyDigestMailer.weekly_digest(...)` is called WITHOUT `.deliver_now` or `.deliver_later`.

In Rails 6.1, `ActionMailer::Base.method_missing` returns an `ActionMailer::MessageDelivery` object (confirmed at `actionmailer-6.1.7.7/lib/action_mailer/base.rb:585`). `MessageDelivery` is a `Delegator` subclass with lazy evaluation (confirmed at `actionmailer-6.1.7.7/lib/action_mailer/message_delivery.rb`). The mailer action method body is only executed when `processed_mailer` is called, which happens ONLY when `.deliver_now`, `.deliver_later`, `.message`, or a delegated `Mail::Message` method is invoked.

Without any of these calls, the `MessageDelivery` object is created, the method body never runs, `Emails::SendTemplateEmail.new(message_params).send` is never called, and the email is never sent. The `MessageDelivery` object goes out of scope and is garbage collected. No error is raised.

**Evidence:**
- `ActionMailer::Base.method_missing` at line 585: `MessageDelivery.new(self, method_name, *args)`
- `MessageDelivery#initialize` at line 18: `@processed_mailer = nil; @mail_message = nil`
- `MessageDelivery#processed_mailer` at line 133: only called by `deliver_now`, `deliver_later`, `deliver_now!`, `deliver_later!`, and `__getobj__` (delegator)
- All existing mailer callers in the codebase use `.deliver_later`: `comment.rb:86`, `job_application.rb:518`, `job_application.rb:533`, `complete_job_application.rb:62`

**Why the job spec doesn't catch this:** The job spec at line 46 stubs the mailer class: `allow(WeeklyDigestMailer).to receive(:weekly_digest)`. This replaces the class method entirely, so no `MessageDelivery` object is created. The spec verifies that `.weekly_digest` was called with the right arguments, but not that the email is actually delivered.

**Why the mailer spec doesn't catch this:** The mailer spec's `call_mailer` helper at line 35-41 correctly calls `.deliver_now`, so the mailer method body DOES execute in that spec. The mailer spec tests the mailer in isolation -- correctly. The gap is in the job-to-mailer integration.

**Recommended fix:** Change `weekly_digest_job.rb:29-33` from:
```ruby
WeeklyDigestMailer.weekly_digest(
  organization_user_id: org_user.id,
  bucket: bucket,
  metrics: metrics
)
```
to:
```ruby
WeeklyDigestMailer.weekly_digest(
  organization_user_id: org_user.id,
  bucket: bucket,
  metrics: metrics
).deliver_now
```

`.deliver_now` is appropriate here because the job is already a background process (the spec explicitly notes this: "triggered from inside `WeeklyDigestJob`, which is already a background job, so `deliver_now` from there is also acceptable").
