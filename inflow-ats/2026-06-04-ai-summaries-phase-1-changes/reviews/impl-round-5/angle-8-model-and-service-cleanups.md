# angle-8: model-and-service-cleanups — Round 5

## Findings

No issues found. All cleanup items verified:

- `ApplyAiCreditRefund`: `.order(:created_at).last` correctly replaces `.first`. Both `.reload` calls removed.
- Overdue chain removed: `OVERDUE_RESET_GRACE`, `period_overdue?`, `reset_ai_credits_if_overdue`, `apply_top_up_checkout` all gone from `organization_ai_credit_balance.rb`. `process_ai_credit_resets` correctly renames from `process_overdue_ai_credit_resets`.
- `ResetDailyAiCredits`: Flipper guard `Flipper.enabled?(:AI_DAILY_CREDITS, organization)` added after the allocation nil/zero check.
- `PlanFeatureGate`: `DAILY_AI_CREDIT_ALLOCATION = Variables::AI_DAILY_CREDIT_ALLOCATION` uses the env var. `daily_ai_credit_allocation` method has `|| DAILY_AI_CREDIT_ALLOCATION` fallback. Comment removed.
- `create_ai_credit_state_if_needed`: `Sentry.capture_exception(e)` added to rescue block.
- `prompt_text`: Removed from summary update params in `generate.rb`. Correctly retained in `AiApiRequest.create` calls in both `generate.rb` and `ai_bulk_extract.rake`.
- `ConsumeAiCredits` renamed to `CreateAiCreditBalanceTransaction`. Zero stale references.
- `saved_change_to_id?` removed from `textract_result.rb`.
- `broadcast_credits_exhausted` renamed to `broadcast_ai_summary_failed` with `errorMessage` in payload. Zero stale references.
- `AI_CREDITS_EXHAUSTED` renamed to `AI_SUMMARY_FAILED`. Zero stale references.
- `AiCreditPacks` references all replaced with `OrganizationAiCreditPurchase`. Zero stale references.
- `RoleCategoryGroups` deleted. File gone.
- `AiResumeStructuredData` type reconciled: phantom fields removed, `totalMonthsExperience` added, optional evaluative fields added with `?`.
