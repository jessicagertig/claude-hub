# notification-and-user-feedback — Round 1

## Findings

- F1 [INFO] Change 2's exhaustion block calls `broadcast_ai_summary_failed` which requires `requesting_organization_user`. For auto-generated summaries (`requested_by_organization_user_id: nil`), the guard at textract_result.rb:128 (`return unless requesting_organization_user`) means no notification is sent. The summary IS still destroyed (cleanup happens before notification). Silent failure for auto-generation is acceptable — confirmed by spec's Risks section item 2.

- F2 [MED] If the user reloads the page after Change 2's exhaustion block destroys the `textract_processing` summary, the next API response returns no summary for that job application. The user sees no indication that an AI summary was ever attempted or failed. The WebSocket `AI_SUMMARY_FAILED` toast was the only signal, and if they missed it (navigated away, page reload), there is no persistent indication. This is outside the 3 spec changes (it would require a new status or audit trail) — MED per scope rules.

- F3 [INFO] The `broadcast_ai_summary_failed` method signature is `broadcast_ai_summary_failed(requesting_organization_user, validation_error = nil)`. Change 2 needs to pass the requesting_organization_user and optionally a validation_error string. The spec says "call `broadcast_ai_summary_failed` on the job application's latest `TextractResult` to notify the `requesting_organization_user_id` from the destroyed `AiJobApplicationSummary`." This is correct — the method is on TextractResult, and the requesting_organization_user comes from the summary being destroyed.

## Amendments Applied

None.
