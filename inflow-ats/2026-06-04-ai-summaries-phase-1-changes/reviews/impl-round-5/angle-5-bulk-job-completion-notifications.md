# angle-5: bulk-job-completion-notifications — Round 5

## Findings

- F1 [MED] `app/jobs/bulk_generate_ai_summaries_job.rb:162` / Missing trailing newline at end of file / Minor code quality issue.

- F2 [MED] `app/jobs/bulk_generate_ai_summaries_job.rb:95-100` / `on_complete` calls `self.class.send(:notify_failure, payload)` and `self.class.send(:notify_complete, ...)` to access private class methods from an instance method / This uses `send` to break encapsulation. The `notify_complete` and `notify_failure` methods are `private_class_method`, which is the correct pattern for `discard_on`/`retry_on` blocks (which are class-level). But calling them from the instance `on_complete` via `self.class.send(:method, ...)` is an awkward bypass. The existing code uses `update_remaining_statuses_to_failed` from class-level blocks directly (where it works without `send`), so the pattern is consistent for the class-level callers. The instance-level `send` is a design smell but not a bug.

No blocking issues found. The retry/discard ordering is correct (discard_on first at line 11, retry_on second at line 16 -- ActiveJob checks in reverse declaration order). The TDD spec correctly tests this ordering. Both `notify_complete` and `notify_failure` chain `.deliver_later` on mailer calls per known failure pattern #4. The spec stubs mailers with `instance_double(ActionMailer::MessageDelivery)` and verifies `.deliver_later`.
