# angle-8: model-and-service-cleanups — Pass 1

## Fact Check

| Claim | Verification | Result |
|-------|-------------|--------|
| `ApplyAiCreditRefund` `.order(:created_at).first` at line 17 | Read apply_ai_credit_refund.rb line 17 | CORRECT — `.order(:created_at).first` |
| Plan C.5.1 changes to `.last` | Plan step | CORRECT |
| `.reload` at line 21 on balance | Read line 21 | CORRECT — `purchase.organization.organization_ai_credit_balance&.reload` |
| `.reload` at line 62 on purchase | Read line 62 | CORRECT — `context.purchase = purchase.reload unless context.failure?` |
| `OVERDUE_RESET_GRACE` at line 4 of organization_ai_credit_balance.rb | Read line 4 | CORRECT |
| `period_overdue?` at line 30 | Read lines 30-33 | CORRECT |
| `reset_ai_credits_if_overdue` at line 49 | Read lines 49-53 | CORRECT |
| `apply_top_up_checkout` at lines 35-43 | Read lines 35-43 | CORRECT |
| `process_overdue_ai_credit_resets` at line 904 of organization.rb | Read lines 904-921 | CORRECT |
| Calls `reset_ai_credits_if_overdue` at line 912 | Read line 912 | CORRECT |
| Error log at line 916 | Read line 916 | CORRECT |
| Rake task at line 76 calls `Organization.process_overdue_ai_credit_resets` | Grep confirmed line 76 | CORRECT |
| `create_ai_credit_state_if_needed` rescue block at lines 203-206 | Read lines 203-206 | CORRECT — has `Rails.logger.error` and `ap`, no Sentry |
| `PlanFeatureGate::DAILY_AI_CREDIT_ALLOCATION = 5` at line 133 | Read line 133 | CORRECT |
| `daily_ai_credit_allocation` returns nil for unknown plans | Read lines 139-141 | CORRECT — no fallback, returns `nil` |
| `monthly_ai_credit_allocation` has `|| MINIMUM_AI_CREDIT_ALLOCATION` fallback | Read lines 135-137 | CORRECT |
| `ResetDailyAiCredits` has no Flipper guard | Read reset_daily_ai_credits.rb | CORRECT — no Flipper check |
| `ValidateAiSummaryGeneration` line 29 error string | Read line 29 | CORRECT — `'Resume processing has failed. Try uploading a different file.'` |
| `ConsumeAiCredits` at textract_result.rb line 81 | Read line 81 | CORRECT |
| `ConsumeAiCredits` comment in notify_zero_ai_credits.rb line 8 | Grep confirmed line 8 | CORRECT |
| `ConsumeAiCredits` class name and logger strings (2 occurrences) in consume_ai_credits.rb | Grep confirmed lines 19, 30, 60 | CORRECT — class at 19, logger at 30 and 60 |
| `saved_change_to_id?` in textract_result.rb line 97 | Read line 97 | CORRECT — `saved_change_to_textract_job_result_text? || saved_change_to_id?` |
| `broadcast_credits_exhausted` at line 127 of textract_result.rb | Read lines 127-140 | CORRECT |
| Action string `'AI_CREDITS_EXHAUSTED'` at line 134 | Read line 134 | CORRECT |
| `RoleCategoryGroups` zero references outside its own file | Grep confirmed only self-reference | CORRECT |
| `prompt_text` in generate.rb at lines 67, 168 | Grep confirmed lines 67, 168 | CORRECT |
| `prompt_text` in ai_bulk_extract.rake at lines 62, 78 | Grep confirmed lines 62, 78 | CORRECT |
| Plan C.6.3 correctly preserves line 78 (`AiApiRequest.create` prompt_text) | Plan step | CORRECT |

## Completeness

Spec requirements covered by this angle:
- Note #3 `.last` fix — plan step C.5.1
- Note #32 `.reload` removal — plan steps C.5.2, C.5.3
- Note #27 overdue chain removal — plan steps C.7.1-C.7.8
- Note #30 Sentry capture — plan step C.11
- Note #31 PlanFeatureGate fallback fix — plan steps C.10.1-C.10.4
- Note #8 Flipper guard — plan step C.9
- Note #34 WebSocket rename — plan steps C.13.1-C.13.4
- Note #35 saved_change_to_id? removal — plan step C.12
- Note #12 ConsumeAiCredits rename — plan steps C.4.1-C.4.4
- Note #26 prompt_text removal — plan steps C.6.1-C.6.3
- Note #6B RoleCategoryGroups deletion — plan step C.2
- Note #37 comment removal — plan step C.10.4

All spec requirements have corresponding plan steps.

## Findings

No issues found.

## Amendments Applied

(none)
