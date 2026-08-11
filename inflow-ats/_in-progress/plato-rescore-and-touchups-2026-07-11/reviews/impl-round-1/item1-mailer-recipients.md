# item1-mailer-recipients — Round 1

Reviewed `app/mailers/bulk_all_stages_ai_summary_result_mailer.rb` + `spec/mailers/bulk_all_stages_ai_summary_result_mailer_spec.rb` (commit f9ec4a80d) against SPEC 1.6/1.7 and the recipient analog `job_application_mailer.rb:19,28-32`.

## Verified — mailer
- Both `complete` and `failed`: `recipients = @job.organization_users.actives.includes(:user)`; `return unless recipients.any?` (bare guard, core rule 8); `to_recipients = recipients.map { |organization_user| { name: "#{first} #{last}".strip, email } }`; `to: to_recipients` — ONE email, active-only.
- Faithful to the analog shape minus `.receives_new_job_application_emails` (owner-ruled omission). Block var named `organization_user` per rule 9 (analog uses `recipient`).
- `@user = User.find(user_id)` load removed in both; `user_first_name` removed from `variables` in both. `user_id` param retained in both signatures (callers unchanged).
- `actives` scope = `where(is_active: true)` (confirmed `organization_user.rb:48`) — inactive excluded, mapping does not re-widen.
- Per-stage mailer `bulk_job_application_ai_summary_result_mailer.rb` NOT touched (not in diff).
- No opt-out/preference filter added.

## Verified — spec (pre-existing staleness reconciled, not layered)
- `#complete` arity fixed to 6 args `complete(user.id, job.id, 5, 1, 2, 8)`; subject → "Your Plato reviews for #{job.title} are ready"; tags → `['polymer','user-facing']` (dropped `'ai-summaries'`). All reconciled to the real mailer.
- `#failed` subject → "We couldn't complete your Plato reviews for #{job.title}".
- Recipient assertions: `active_member` present, `inactive_member` absent — both methods.
- `variables` `not_to have_key(:user_first_name)` — both methods (falsifiable by reverting greeting removal).
- Falsifiable per core rule 26: `active_member` is a distinct org_admin (not the triggering owner); reverting B1 → `include(active_member.user.email)` fails. `total_count`/succeeded/failed/skipped/job_link assertions retained.

## Findings
No issues found.
