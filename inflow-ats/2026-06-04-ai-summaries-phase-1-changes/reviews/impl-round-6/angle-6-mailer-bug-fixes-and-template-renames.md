# Angle 6: Mailer Bug Fixes and Template Renames — Round 6

## Review

### `AiCreditNotificationMailer`

**`is_admin?` fix (Note #1):**
Line 59: `organization.organization_users.select(&:is_admin).map(&:user).uniq`. Uses `is_admin` (not `is_admin?`). Correct.

**Template renames (Notes #20, #38):**
- `low_credits`: template `'user-ai-credit-balance-low'` (line 15). Correct.
- `zero_credits`: template `'user-ai-credit-balance-zero'` (line 41). Correct.

**`from` address:**
Uses `Variables::DEFAULT_EMAIL_FROM_ADDRESS` (lines 11, 37). The spec says to follow the `JobResumeExportMailer` analog which uses `EMAIL_NOTIFICATIONS_ADDRESS`. However, this mailer existed before the spec changes -- the spec only asked to fix `is_admin?` and rename templates. The `from` address was NOT part of the spec changes. The mailer uses `DEFAULT_EMAIL_FROM_ADDRESS` because it follows the pattern of other org-level notification mailers. The new `BulkJobApplicationAiSummaryResultMailer` correctly uses `EMAIL_NOTIFICATIONS_ADDRESS` per its spec.

### Mailer spec

**`spec/mailers/ai_credit_notification_mailer_spec.rb`:**
- Stubs `Emails::SendTemplateEmail`. Correct.
- Tests `admin_recipients` includes owner and admin, excludes member and interviewer. Correct.
- Tests `low_credits` with template `'user-ai-credit-balance-low'` and `credits_remaining` variable. Correct.
- Tests `zero_credits` with template `'user-ai-credit-balance-zero'`. Correct.
- Tests `send` called once per admin recipient. Correct.
- Uses `create_credit_test_organization_user` helper from `spec/support/ai_credits_test_helpers.rb`. Correct.

## Findings

### MED F1 -- `AiCreditNotificationMailer` uses `DEFAULT_EMAIL_FROM_ADDRESS`

**File:** `app/mailers/ai_credit_notification_mailer.rb:11,37`

The `AiCreditNotificationMailer` uses `Variables::DEFAULT_EMAIL_FROM_ADDRESS` while the spec's mailer analog (`JobResumeExportMailer`) uses `Variables::EMAIL_NOTIFICATIONS_ADDRESS`. However, this is pre-existing behavior -- the spec only asked to fix `is_admin?` and rename templates. The new `BulkJobApplicationAiSummaryResultMailer` correctly uses `EMAIL_NOTIFICATIONS_ADDRESS`. Not a spec violation.

## Verdict: PASS (0 HIGH, 1 MED)
