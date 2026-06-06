# Bulk Job Completion Notifications — Round 1

## Findings

- F1 [MED] `app/jobs/bulk_generate_ai_summaries_job.rb:93-96` / In `on_complete`, the `notify_failure` and `notify_complete` calls use `self.class.send(:notify_failure, payload)` and `self.class.send(:notify_complete, payload, user, succeeded, failed)`. This works but is unusual -- calling `private_class_method`s via `send` from an instance method. The `discard_on` and `retry_on` blocks call `notify_failure(payload)` directly because they execute in class context. This inconsistency is not a bug but could confuse future maintainers.

- F2 [MED] `spec/jobs/bulk_generate_ai_summaries_job_spec.rb:108-113` / In the first `on_complete` test, the `allow(BulkJobApplicationAiSummaryResultMailer).to receive(:complete).and_return(mailer_double)` stub is placed AFTER the `GlobalChannel.broadcast_to` expectation but is needed for the test to pass (the `on_complete` method calls `notify_complete` which calls the mailer). The stub should be placed before `on_complete` is called, which it is (line 113 is before `job_instance.on_complete` on line 116). On closer inspection this is fine -- the stub is set up before the method call. No issue.

No blocking issues found. The `retry_on`/`discard_on` declaration order is correct. The TDD spec checks `rescue_handlers` indices. Mailer calls chain `.deliver_later` as required by failure pattern #4.
