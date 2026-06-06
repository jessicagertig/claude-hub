# Angle 6: Mailer Bug Fixes and Template Renames -- Round 2

## Scope

`is_admin?` -> `is_admin` fix, template name renames, new mailer spec, test helper.

## Findings

### F1 (CLEAR) -- `is_admin?` -> `is_admin` fixed

`ai_credit_notification_mailer.rb:59`: `select(&:is_admin)`.

### F2 (CLEAR) -- Template names renamed

`'user-ai-credit-balance-low'` and `'user-ai-credit-balance-zero'`.

### F3 (CLEAR) -- TODO comment removed

The `# TODO: Create Mailgun templates` comment at the top is removed.

### F4 (CLEAR) -- Round 1 MED3 fix: mailer `name:` field

`BulkJobApplicationAiSummaryResultMailer` uses `name: user.full_name` in the `to:` field (line 12, line 37). The `AiCreditNotificationMailer` continues to omit `name:` per its existing pattern (sends to multiple recipients with just `email:`). This is consistent.

### F5 (CLEAR) -- Mailer spec covers required assertions

`spec/mailers/ai_credit_notification_mailer_spec.rb`: admin_recipients filtering verified (owner, admin included; member, interviewer excluded), template names verified, `credits_remaining` variable verified, `Emails::SendTemplateEmail#send` invocation count verified.

### F6 (CLEAR) -- Test helper added

`spec/support/ai_credits_test_helpers.rb`: `create_credit_test_organization_user(organization, role:)` added.

## Verdict: 0 findings. PASS for this angle.
