# Send Pipeline — Round 1

## Findings

- F1 [MED] `from` address difference — spec line 181 says `from` uses `Variables::EMAIL_HELLO_ADDRESS` (`hello@mail.polymer.co`). Verified at 01_variables.rb:11. The existing mailer analogs (`CommentMailer` line 50, `JobApplicationMailer` line 35) use `Variables::EMAIL_NOTIFICATIONS_ADDRESS` (`notifications@mail.polymer.co`). The spec explicitly calls out this intentional difference ("Jessica from Polymer" vs. "Polymer"). The REVIEW-ANGLES.md also notes this at line 122: "The `from` address intentionally uses `Variables::EMAIL_HELLO_ADDRESS`." No issue — just confirming this is deliberate.

- F2 [MED] `from` display name — spec line 36 says `Jessica from Polymer`. The existing mailers use `Polymer` as the display name (CommentMailer line 50: `name: 'Polymer'`). The spec's `message_params` section (line 181) says `from: { name:` (display name) without specifying the exact value inline — only the Sender section (line 36) states it. The implementer must connect these. Minor clarity gap but not a blocker.

- F3 [MED] `list_unsubscribe` header format — spec line 188 says "a placeholder URL plus a `mailto:` fallback." Looking at `add_list_unsubscribe` in send_template_email.rb:105-107, it sets the raw header value: `message_builder.header("List-Unsubscribe", list_unsubscribe)`. The existing mailers pass a simple mailto string (CommentMailer line 52: `"mailto:#{Variables::REPLY_TO_EMAIL_ADDRESS}"`). The spec says "placeholder URL plus a mailto fallback" which implies a multi-value header like `<https://placeholder>, <mailto:...>`. The implementer needs to know the exact format. This is tracked in Open Items ("Placeholder unsubscribe URL") so not blocking.

- F4 [MED] Tag count constraint — send_template_email.rb:85-86 enforces max 2 tags: `raise "Max of 2 tags allowed" if tags.length > 2`. Then line 90 auto-appends the template name as a third tag. Spec line 186 says `tags: 1-2 tags, e.g. ['hire', 'user-facing']` and notes SendTemplateEmail auto-appends. With 2 tags + the auto-appended template name = 3 tags total. This matches the existing mailers (CommentMailer line 56: `['hire', 'user-facing']`). No issue.

- F5 [LOW] `variables` format — send_template_email.rb:93-95: `add_variables` passes variables as a header value via `message_builder.header('X-Mailgun-Variables', variables)`. The existing mailers pass a Ruby hash (CommentMailer lines 57-71). The Mailgun gem's `MessageBuilder#header` presumably handles hash-to-JSON conversion. The spec says "plain data values, not rendered HTML" which is correct. No issue.

- F6 [LOW] Job stagger — spec line 248 notes the stagger delay as an open item. The engagement_reports task (recurring_tasks.rake:147) uses 30s prod / 5s dev. The digest enqueues per org_user (more jobs). The spec acknowledges this needs a different delay. Implementation detail, not blocking.

## Amendments Applied

None required — all findings are MED or LOW.
