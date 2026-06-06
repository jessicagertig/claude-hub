# Angle 8: Model and Service Cleanups -- Round 3

## Files reviewed

- `app/interactors/apply_ai_credit_refund.rb`
- `app/models/organization_ai_credit_balance.rb`
- `app/models/organization.rb`
- `lib/tasks/ai_credits.rake`
- `app/interactors/reset_daily_ai_credits.rb`
- `app/services/plan_feature_gate.rb`
- `config/initializers/01_variables.rb`
- `app/models/textract_result.rb`
- `app/interactors/validate_ai_summary_generation.rb`
- `app/interactors/create_ai_credit_balance_transaction.rb` (renamed)
- `app/interactors/notify_zero_ai_credits.rb`
- `app/services/ai_job_application_action/summary/generate.rb`
- `lib/tasks/ai_bulk_extract.rake`
- `app/javascript/shared/types/aiJobApplicationSummary.ts`

## Findings

**No new findings.**

All changes match spec:
- `ApplyAiCreditRefund`: `.order(:created_at).last` (was `.first`), both `.reload` calls removed
- `OrganizationAiCreditBalance`: `OVERDUE_RESET_GRACE`, `period_overdue?`, `reset_ai_credits_if_overdue`, `apply_top_up_checkout` removed
- `Organization`: `process_overdue_ai_credit_resets` renamed to `process_ai_credit_resets`, uses `reset_ai_credits` directly, `Sentry.capture_exception(e)` added to `create_ai_credit_state_if_needed`, `auto_generate_ai_summaries_enabled` method (no `?`) with correct settings key, `add_default_settings` uses new key
- `ai_credits.rake`: calls `Organization.process_ai_credit_resets`
- `ResetDailyAiCredits`: Flipper guard added after allocation guard
- `PlanFeatureGate`: `DAILY_AI_CREDIT_ALLOCATION = Variables::AI_DAILY_CREDIT_ALLOCATION`, fallback `|| DAILY_AI_CREDIT_ALLOCATION` added, comment removed
- `01_variables.rb`: `AI_DAILY_CREDIT_ALLOCATION = ENV['AI_DAILY_CREDIT_ALLOCATION']&.to_i || 5`
- `TextractResult`: `broadcast_credits_exhausted` renamed to `broadcast_ai_summary_failed` with `validation_error` param, `AI_SUMMARY_FAILED` action, `errorMessage` in payload, `saved_change_to_id?` removed, `ConsumeAiCredits` renamed to `CreateAiCreditBalanceTransaction`, `should_auto_generate_ai_summaries?` called
- `ValidateAiSummaryGeneration`: error string updated (added "resume")
- `generate.rb`: `prompt_text` removed from both `extraction_update_params` and `succeeded_update_params`
- `ai_bulk_extract.rake`: `prompt_text` removed from `summary.update` but kept in `AiApiRequest.create` (correct)
- `AiResumeStructuredData`: removed `totalYearsExperience`, `relevantYearsExperience`, `jobTitleRoleCategory`; added `totalMonthsExperience`, optional evaluative fields; `AiWorkExperience` removed `roleCategory`, `relevantToJobTitle`
- `RoleCategoryGroups` deleted, zero stale references
- `CreateAiCreditBalanceTransaction` is exact rename of `ConsumeAiCredits` with updated logger strings
