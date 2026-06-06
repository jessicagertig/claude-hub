# Angle 8: Model and Service Cleanups -- Round 2

## Scope

All smaller correctness/cleanup changes: `ApplyAiCreditRefund` fixes, overdue chain removal, Flipper guard, `PlanFeatureGate` fallback, Sentry addition, `prompt_text` removal, `ConsumeAiCredits` rename, WebSocket rename, `saved_change_to_id?` removal, `RoleCategoryGroups` deletion, `AiResumeStructuredData` reconciliation.

## Findings

### F1 (CLEAR) -- `ApplyAiCreditRefund` fixes applied

`.order(:created_at).last` (line 16), `.reload` calls removed (lines 18, 62).

### F2 (CLEAR) -- Overdue chain removed

`OVERDUE_RESET_GRACE`, `period_overdue?`, `reset_ai_credits_if_overdue`, `apply_top_up_checkout` all removed from `organization_ai_credit_balance.rb`. `process_overdue_ai_credit_resets` renamed to `process_ai_credit_resets` in `organization.rb` and `ai_credits.rake`.

### F3 (CLEAR) -- Flipper guard added to `ResetDailyAiCredits`

`return unless Flipper.enabled?(:AI_DAILY_CREDITS, organization)` at line 15.

### F4 (CLEAR) -- `PlanFeatureGate` fallback fixed

`DAILY_AI_CREDIT_ALLOCATION = Variables::AI_DAILY_CREDIT_ALLOCATION`. `daily_ai_credit_allocation` returns `plan_rules[@plan]&.dig(:daily_ai_credit_allocation) || DAILY_AI_CREDIT_ALLOCATION`. Comment removed.

### F5 (CLEAR) -- Sentry capture added

`organization.rb` `create_ai_credit_state_if_needed`: `Sentry.capture_exception(e)` before `Rails.logger.error`.

### F6 (CLEAR) -- `prompt_text` removal

Removed from `generate.rb` (both `extraction_update_params` and `succeeded_update_params`), `ai_bulk_extract.rake` (line 60 update only, line 78 `AiApiRequest.create` kept), `create_ai_job_application_summaries` migration.

### F7 (CLEAR) -- `ConsumeAiCredits` rename complete

File renamed to `create_ai_credit_balance_transaction.rb`, class renamed, call sites in `textract_result.rb` and `notify_zero_ai_credits.rb` updated, logger strings updated, spec renamed and class reference updated.

### F8 (CLEAR) -- WebSocket action rename

`AI_CREDITS_EXHAUSTED` -> `AI_SUMMARY_FAILED` in `textract_result.rb`, `WebsocketGlobalChannelHandler.tsx`, type file. `errorMessage` added to payload. Payload type renamed from `AiCreditsExhaustedPayload` to `AiSummaryFailedPayload`.

### F9 (CLEAR) -- `saved_change_to_id?` removed

`textract_result.rb` line 97: `return unless saved_change_to_textract_job_result_text?` (no more `|| saved_change_to_id?`).

### F10 (CLEAR) -- `RoleCategoryGroups` deleted

Zero references. File deleted.

### F11 (CLEAR) -- `AiResumeStructuredData` reconciled

`totalYearsExperience`, `relevantYearsExperience`, `jobTitleRoleCategory` removed. `totalMonthsExperience` added. Optional evaluative fields added. `AiWorkExperience` `roleCategory` and `relevantToJobTitle` removed.

### F12 (CLEAR) -- `ResetAiCredits` stale comment fixed

Round 1 MED1: `reset_ai_credits.rb:4` comment changed from `Organization.process_overdue_ai_credit_resets` to `Safety-net rake task (if applicable)`.

## Verdict: 0 findings. PASS for this angle.
