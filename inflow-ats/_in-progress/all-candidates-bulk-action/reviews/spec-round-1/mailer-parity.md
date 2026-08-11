# Mailer Parity — Round 1

## Findings

- Verified: `BulkJobApplicationAiSummaryResultMailer` (mailer:1-52) uses `Emails::SendTemplateEmail.new(message_params).send` pattern. The spec correctly says the new mailer follows this structure.

- Verified: both call sites in `BulkGenerateAiSummariesJob` chain `.deliver_later` (job:144, job:171). The spec says `kind`-based branching dispatches to the correct mailer. The implementation must chain `.deliver_later` on the new mailer calls too. The spec mentions this in the "Existing patterns to follow" section via the analog reference but does not explicitly state it in the mailer section.

- F1 [MED] The spec's "New mailer" section says the new mailer's `failed` method has "same signature as the existing mailer's `failed`" — verified: the existing `failed` takes `(user_id, job_id, total_queued_count)`. Correct and consistent. But the spec doesn't mention that the new mailer's call sites must chain `.deliver_later`. While the "Existing patterns to follow" section references the mailer analog, the spec should be explicit per known failure pattern #4.

## Amendments Applied

- Spec "New mailer" section: added "Both call sites in `BulkGenerateAiSummariesJob` (`notify_complete` and `notify_failure`) must chain `.deliver_later` on the new mailer, per known failure pattern #4"
