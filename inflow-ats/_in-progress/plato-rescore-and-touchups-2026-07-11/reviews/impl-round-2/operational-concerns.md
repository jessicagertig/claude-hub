# operational-concerns (always-on impl) — Round 2

- Mailer N+1: `recipients = @job.organization_users.actives.includes(:user)` eager-loads `:user` before the `.map` reads `first_name`/`last_name`/`email` — no per-recipient query. ✓
- Single email send preserved: one `Emails::SendTemplateEmail.new(message_params).send` with all recipients in `to:` (owner-ruled against per-recipient loop). ✓
- Guard against empty send: bare `return unless recipients.any?` in both methods prevents an empty `to:`. ✓
- Error handling: no new rescue paths needed; interactor retains its `context.fail!` on save failure; controller retains `render_errors`. ✓
- Debug `ap` lines in `create_ai_summary_generation.rb` are pre-existing and unchanged (not introduced by this diff). ✓
- Deployment: no migration, no schema change, no new env var. Manual step recorded (loose-ends #2): Jessica pastes the two updated all-stages templates into Mailgun after merge; the polymer-mail commit intentionally waits until then. ✓
- No performance regression: modal render logic is O(1) copy selection; no new network calls.

## Findings
No issues found.
