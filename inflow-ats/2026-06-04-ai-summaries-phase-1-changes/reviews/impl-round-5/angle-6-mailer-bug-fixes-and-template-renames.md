# angle-6: mailer-bug-fixes-and-template-renames — Round 5

## Findings

- F1 [MED] `app/mailers/ai_credit_notification_mailer.rb:11,37` / Uses `Variables::DEFAULT_EMAIL_FROM_ADDRESS` instead of `Variables::EMAIL_NOTIFICATIONS_ADDRESS` / The spec (Note #13) says to pattern after `job_resume_export_mailer.rb`. That mailer uses `EMAIL_NOTIFICATIONS_ADDRESS` (`notifications@mail.polymer.co`). The `AiCreditNotificationMailer` uses `DEFAULT_EMAIL_FROM_ADDRESS` (`support@mail.polymer.co`). The `BulkJobApplicationAiSummaryResultMailer` correctly uses `EMAIL_NOTIFICATIONS_ADDRESS`. The low/zero credit notification emails are user-facing notifications, not support communications, so `EMAIL_NOTIFICATIONS_ADDRESS` would be the correct `from` address. However, this file was originally authored outside this spec's scope (it's a pre-existing mailer being fixed), and the spec only specifies changing `is_admin?` and template names. The `from` address may be intentionally different. Flagging for awareness, not blocking.

No other issues found. The `is_admin?` to `is_admin` fix is correct. The template names are correctly updated to `user-ai-credit-balance-low` and `user-ai-credit-balance-zero`. The mailer spec correctly tests `admin_recipients`, template names, variables, and invocation count. The `create_credit_test_organization_user` helper is added to the test helpers.
