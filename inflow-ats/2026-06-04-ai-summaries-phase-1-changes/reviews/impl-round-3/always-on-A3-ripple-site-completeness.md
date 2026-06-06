# Always-On A3: Ripple-Site Completeness -- Round 3

## Comprehensive grep sweep

### `auto_generate_ai_summaries_setting` / `autoGenerateAiSummariesSetting`
- Backend (`app/`, `spec/`, `config/`, `lib/`): **0 hits** (only the rename migration file itself, which is expected)
- Frontend (`app/javascript/`): **0 hits**

### `default_auto_generate_ai_summaries_enabled` / `defaultAutoGenerateAiSummariesEnabled`
- Backend: **0 hits**
- Frontend: **0 hits**

### `effective_auto_generate_ai_summaries_enabled`
- **0 hits**

### `AiCreditPacks`
- **0 hits** in `app/`, `spec/`, `config/`, `lib/`

### `ConsumeAiCredits`
- **0 hits** in `app/`, `spec/`, `config/`, `lib/`

### `AI_CREDITS_EXHAUSTED` / `AiCreditsExhaustedPayload` / `broadcast_credits_exhausted`
- **0 hits**

### `process_overdue_ai_credit_resets` / `reset_ai_credits_if_overdue` / `apply_top_up_checkout` / `period_overdue` / `OVERDUE_RESET_GRACE`
- **0 hits**

### `is_admin?` (potential NoMethodError)
- Only hits in `admin/base_controller.rb` which defines its own `current_user_is_admin?` method (unrelated)
- **0 hits** in AI-related code

### Old credit pack lookup keys (`ai_credits_starter`, `ai_credits_growth`, `ai_credits_scale`)
- **0 hits**

### `RoleCategoryGroups`
- **0 hits**

### `AiCreditSubscription` (old TS type) / `useAiCreditSubscription` / `useSubscribeToAiCreditPack`
- Old hook names: **0 hits** (only `useCancelAiCreditSubscription` and `usePurchaseAiCreditTopUp` remain, correctly defined in the new consolidated file)

## Findings

**No findings.** All renames are complete with zero stale references.
