# Implementation Review -- Failure Report
**Round:** 2
**Date:** 2026-06-03

## Issues Requiring Fix

1. **[BLOCKER] weekly_digest_job.rb:29-33 -- Email never sent**
   
   `WeeklyDigestMailer.weekly_digest(...)` is called without `.deliver_now` or `.deliver_later`. In Rails 6.1, this returns an `ActionMailer::MessageDelivery` object with lazy evaluation. The mailer method body (which contains `Emails::SendTemplateEmail.new(message_params).send`) never executes. The email is silently not sent.
   
   **Fix:** Change line 29-33 to:
   ```ruby
   WeeklyDigestMailer.weekly_digest(
     organization_user_id: org_user.id,
     bucket: bucket,
     metrics: metrics
   ).deliver_now
   ```
   
   `.deliver_now` is appropriate because the job is already a background process.

2. **[HIGH] spec/jobs/weekly_digest_job_spec.rb -- Missing delivery verification**
   
   The job spec stubs `WeeklyDigestMailer` with `allow(WeeklyDigestMailer).to receive(:weekly_digest)` which masks the BLOCKER above. The spec verifies the class method is called but does NOT verify that `.deliver_now` is invoked on the resulting `MessageDelivery`.
   
   **Fix:** Update the mailer stub to return a message delivery double and verify `.deliver_now` is called:
   ```ruby
   let(:message_delivery) { instance_double(ActionMailer::MessageDelivery, deliver_now: nil) }
   
   before do
     allow(WeeklyDigestMailer).to receive(:weekly_digest).and_return(message_delivery)
   end
   
   # In the "triggers the mailer" test:
   expect(message_delivery).to have_received(:deliver_now)
   ```

## What NOT To Change

- The mailer itself (`weekly_digest_mailer.rb`) is correct. It follows the established pattern of calling `Emails::SendTemplateEmail.new(message_params).send` inside the method body.
- The mailer spec (`weekly_digest_mailer_spec.rb`) is correct. It calls `.deliver_now` in its `call_mailer` helper.
- All other new files (classifier, data migration, rake task) are correct.
- All analyzer changes are correct.
- The full-stack preference contract is correct.
- The frontend changes are correct.

## cursor_rules/ Violations

None. The issue is not a cursor_rules violation -- it is a Rails ActionMailer behavior that all existing codebase callers handle correctly (they all use `.deliver_later`), but the new job omitted.
