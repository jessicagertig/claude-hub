# angle-6: mailer-bug-fixes-and-template-renames — Round 1

Verified against source:
- `ai_credit_notification_mailer.rb` line 62: `select(&:is_admin?)` confirmed — `is_admin?` does not exist on `OrganizationUser`
- `OrganizationUser#is_admin` exists at line 54 as a method (not a column, not a `?` predicate)
- The mailer uses `Emails::SendTemplateEmail` pattern, same as `JobResumeExportMailer`
- Template name strings confirmed as `'ai-credits-low'` and `'ai-credits-zero'` in the current code — spec correctly renames to `'user-ai-credit-balance-low'` and `'user-ai-credit-balance-zero'`

No BLOCKER, HIGH, or MED findings for this angle. All claims verified.
