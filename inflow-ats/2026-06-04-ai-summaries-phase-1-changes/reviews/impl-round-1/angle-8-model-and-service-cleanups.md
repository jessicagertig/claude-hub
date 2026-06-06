# Model and Service Cleanups — Round 1

## Findings

- F1 [MED] `app/interactors/reset_ai_credits.rb:6` / Comment still references `Organization.process_overdue_ai_credit_resets` (old name). Should be updated to `Organization.process_ai_credit_resets` to match the rename done in Note #27.

- F2 [MED] `db/schema.rb:125` / `prompt_text` column still appears in schema on the `ai_api_requests` table. This is CORRECT -- per the plan (C.6.3), `prompt_text` was only removed from `ai_job_application_summaries`, not from `ai_api_requests`. The `generate.rb` line 308 still writes `prompt_text` to `AiApiRequest.create`, which is correct. Not a finding -- just confirming this is intentional.

No blocking issues found. All cleanup changes are correct:
- `ApplyAiCreditRefund` `.last` fix applied
- `.reload` calls removed
- Overdue chain removed (constant, 3 methods, `apply_top_up_checkout`)
- `RoleCategoryGroups` deleted
- Flipper guard added to `ResetDailyAiCredits`
- `PlanFeatureGate` fallback fixed
- Sentry capture added
- `saved_change_to_id?` removed
- WebSocket action renamed with `errorMessage` payload
- `ConsumeAiCredits` rename complete in all production code
- `AiResumeStructuredData` reconciled correctly
