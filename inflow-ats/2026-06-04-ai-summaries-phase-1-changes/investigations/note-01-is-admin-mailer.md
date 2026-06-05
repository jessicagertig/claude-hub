# Investigation — Note #1: is_admin? mailer bug

## File chain
`app/interactors/notify_low_ai_credits.rb:34` + `app/interactors/notify_zero_ai_credits.rb:25` (`.deliver_later`)
→ `app/mailers/ai_credit_notification_mailer.rb:62` (`admin_recipients` → `select(&:is_admin?)`)
→ `app/models/organization_user.rb:54` (`is_admin` = `org_admin? || is_owner`)
→ `organization_user.rb:50` (`is_owner` = `org_owner? || god_admin?`)
→ `organization_user.rb:39` (`role` enum: org_user/org_admin/org_owner/org_interviewer/god_admin → supplies `org_admin?`, `org_owner?`, `god_admin?` predicates)
→ `db/schema.rb` (no `is_admin` column)

## Findings (ground truth)
- BUG CONFIRMED. `OrganizationUser#is_admin` is a plain method (no `?`), not a column. AR generates no `is_admin?` predicate; no `alias_method` for it. Only other `is_admin?` in app is `current_user_is_admin?` in admin/base_controller.rb (unrelated, locally defined).
- `select(&:is_admin?)` raises `NoMethodError` for both `low_credits` and `zero_credits`.
- Nuance not in the note: both callers use `.deliver_later`; the mailer body sends via `Emails::SendTemplateEmail.new(message_params).send` per recipient and never calls `mail()`. So the `NoMethodError` is raised inside the ActionMailer delivery job at perform time, not synchronously at the interactor call site. Net effect identical: no email delivered.
- No existing spec file for `AiCreditNotificationMailer` (searched `spec/` — none).

## Fix
Change `select(&:is_admin?)` → `select(&:is_admin)` at `ai_credit_notification_mailer.rb:62`.

## cursor_rules consulted
- `cursor_rules/core_critical_rules.md` (= backend/core_critical_rules.md, identical): rules #10/#11 (no bang methods outside specs; check return values) — not directly triggered by the one-line fix.
- RSpec-only convention (memory): any recipient-selection test is RSpec, not Minitest.

## Open decisions for Jessica
1. The fix itself (is_admin? → is_admin).
2. Whether to add regression test coverage for recipient selection, and at what level (RSpec mailer spec — no existing file).
