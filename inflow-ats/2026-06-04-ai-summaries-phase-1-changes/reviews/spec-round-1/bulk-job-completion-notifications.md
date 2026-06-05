# angle-5: bulk-job-completion-notifications — Round 1

Verified against source:
- `retry_on` before `discard_on` confirmed at lines 12/19 of `bulk_generate_ai_summaries_job.rb` — spec correctly identifies this as the bug.
- `on_complete` currently has no mailer call and no failure branch — spec correctly adds both.
- `JobResumeExportMailer` pattern confirmed as the right analog for ID-based args, `Emails::SendTemplateEmail`, template/version/tags.

## Finding 1

**[MED]** Note #13 `failed` mailer method args include `total_queued_count` but the spec description says "the total originally initiated: `payload['job_application_ids'].size + payload['skipped_count']`" — clarify where this calculation happens

**Where:** SPEC.md Note #13, `failed` method description

**What:** The `failed` mailer method takes `total_queued_count` as an argument. The spec's approved decisions say `total_queued_count` is `payload['job_application_ids'].size + payload['skipped_count']`. This calculation needs to happen in the `notify_failure` helper on `BulkGenerateAiSummariesJob`, not in the mailer. The spec describes the mailer args correctly (ID-based), but `total_queued_count` is not an ID — it's a derived value that the caller must compute. This is implicit but not explicitly stated. No fix needed — the implementing agent should understand this from context.

## Finding 2

**[MED]** `notify_failure` in `discard_on` and `retry_on` blocks — payload access needs verification

**Where:** SPEC.md Note #13; `bulk_generate_ai_summaries_job.rb` lines 12-21

**What:** The spec says `notify_failure` is called from the `discard_on` and `retry_on` exhaustion blocks. These blocks receive `|current_job, error|` and access the payload via `current_job.arguments.first`. The `notify_failure` method needs access to `user_id`, `job_id`, `job_application_ids`, and `skipped_count` from the payload. The current blocks call `update_remaining_statuses_to_failed(current_job.arguments.first)` — `notify_failure` would need the same `current_job.arguments.first` pattern. This is implicit but the spec doesn't explicitly show the block parameter threading. No fix needed — follows existing pattern.

No BLOCKER or HIGH findings for this angle.
