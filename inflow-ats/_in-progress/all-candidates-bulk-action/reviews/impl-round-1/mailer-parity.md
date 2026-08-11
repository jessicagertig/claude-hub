# Mailer Parity — Round 1

## Findings

No issues found.

Verified against `BulkJobApplicationAiSummaryResultMailer`:
- **`complete` method:** same structure — `User.find`, `Job.find`, `message_params` hash, `Emails::SendTemplateEmail.new(message_params).send`
- **`message_params` shape:** identical keys — `from`, `to`, `list_unsubscribe`, `subject`, `template`, `template_version`, `tags`, `variables`
- **`from`:** `{ name: 'Polymer', email: Variables::EMAIL_NOTIFICATIONS_ADDRESS }` — matches analog
- **`to`:** `[{ name: @user.full_name, email: @user.email }]` — matches analog
- **`list_unsubscribe`:** `"mailto:#{Variables::REPLY_TO_EMAIL_ADDRESS}"` — matches analog
- **`tags`:** `['polymer', 'user-facing', 'ai-summaries']` — matches analog
- **`template_version`:** `'initial'` — matches analog
- **`variables`:** new mailer uses `job_link` instead of `hiring_stage_link` — correct deviation per spec
- **No `hiring_stage_id` param** in `complete` — correct per spec
- **`failed` method:** same structure as analog's `failed`
- **`.deliver_later`:** chained at both call sites in `bulk_generate_ai_summaries_job.rb` (:152, :157 for `all_stages` complete; :187, :192 for `all_stages` failed)
