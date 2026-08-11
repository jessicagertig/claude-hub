# item1-mailer-recipients — Round 2

Independent re-verification of `bulk_all_stages_ai_summary_result_mailer.rb` (both `complete` and `failed`) against SPEC 1.6, and the polymer-mail templates.

Mailer (`complete` + `failed`, identical change):
- `recipients = @job.organization_users.actives.includes(:user)` then bare `return unless recipients.any?` (core rule 8). ✓
- `to_recipients = recipients.map { |organization_user| { name: "#{organization_user.user.first_name} #{organization_user.user.last_name}".strip, email: organization_user.user.email } }` — same shape as the analog `JobApplicationMailer#hiring_team_new_job_application` (`job_application_mailer.rb:28-32`), block var named `organization_user` per rule 9. ✓
- `to: to_recipients` replaces the single-recipient `to: [{ name: @user.full_name, email: @user.email }]`. One email, all recipients in one `to:` array (no per-recipient loop). ✓
- `.receives_new_job_application_emails` deliberately omitted (owner-ruled — no Plato-bulk opt-out key); active-only enforced by `.actives`. ✓ (sanctioned deviation)
- `@user = User.find(user_id)` removed; `user_first_name` removed from `variables` in both methods. `user_id` param retained in both signatures (callers unchanged). Grep confirms zero remaining `@user` references in the mailer. ✓ (SPEC 1.6)
- Subject/tags/template/other variables untouched. Remaining `variables` (`total_count`, `job_title`, counts, `job_link`) still populated; template placeholders `{{total_count}}`/`{{job_title}}`/`{{succeeded_count}}` etc. still supplied. No orphaned template variable. ✓

Per-stage mailer `bulk_job_application_ai_summary_result_mailer.rb`: not in the commit diff — untouched (single triggering user, greeting stays correct). ✓ (SPEC 1.8)

polymer-mail working tree (uncommitted by design — repo convention, loose-ends #2):
- `user-bulk-all-stages-ai-summary-complete.mjml`: exactly the `<p>Hi {{user_first_name}},</p>` line deleted, nothing else. ✓
- `user-bulk-all-stages-ai-summary-failed.mjml`: exactly the `<p>Hi {{user_first_name}},</p>` line deleted, nothing else. ✓
- Per-stage templates (`user-bulk-ai-summary-complete.mjml`, `user-bulk-ai-summary-failed.mjml`) not modified. ✓
- Untracked `.cursorindexingignore` / `.specstory/` are unrelated tooling artifacts, out of scope.

## Findings
No issues found.
