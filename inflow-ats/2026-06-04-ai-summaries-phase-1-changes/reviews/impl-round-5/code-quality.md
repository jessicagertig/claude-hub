# code-quality — Round 5

## Findings

- F1 [MED] `app/interactors/apply_ai_credit_purchase.rb:5-6` / Stale docstring / Says "checkout.session.completed -> call(session: session, kind: :one_off)" but one-off top-ups are now routed through `invoice.paid`, not `checkout.session.completed`. The `mode == 'payment'` branch was removed per spec.

- F2 [MED] `app/jobs/bulk_generate_ai_summaries_job.rb:162` / Missing trailing newline at end of file / Minor, violates common style.

- F3 [MED] `app/mailers/ai_credit_notification_mailer.rb:61` / Missing trailing newline at end of file / Same issue.

- F4 [MED] `app/jobs/bulk_generate_ai_summaries_job.rb:95-100` / Instance method `on_complete` calls private class methods via `self.class.send(:method, ...)` / This is a code smell. The `notify_complete` and `notify_failure` methods are declared as `private_class_method` for use from `discard_on`/`retry_on` class-level blocks. Calling them from instance `on_complete` via `send` bypasses access control. Consider making them regular private instance methods and having the class-level blocks delegate to instance methods (or make them public class methods since the access control is already broken).

No convention violations found against `cursor_rules/backend_base.md` or `cursor_rules/core_critical_rules.md`. Naming follows established patterns. Controller structure is clean. Interactor pattern matches existing codebase.
