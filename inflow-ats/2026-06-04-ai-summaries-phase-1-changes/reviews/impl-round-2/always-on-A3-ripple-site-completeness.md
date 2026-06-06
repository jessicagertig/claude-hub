# Always-On A3: Ripple-Site Completeness -- Round 2

## Checks

### Rename 1: `auto_generate_ai_summaries_setting` -> `auto_generate_ai_summaries`
PARTIAL PASS -- All `app/` and most `spec/` files updated. One stale reference remains in `spec/models/organization_ai_credits_lifecycle_spec.rb:44` for the settings key `default_auto_generate_ai_summaries_enabled` (reported as HIGH in angle-4 F3).

### Rename 2: `AiCreditPacks.*` -> `OrganizationAiCreditPurchase.*`
PASS -- `grep` returns zero results for `AiCreditPacks` across all Ruby and TypeScript files.

### Rename 3: `ConsumeAiCredits` -> `CreateAiCreditBalanceTransaction`
PASS -- `grep` returns zero results for `ConsumeAiCredits` across all files.

### Additional renames verified:
- `AI_CREDITS_EXHAUSTED` -> `AI_SUMMARY_FAILED`: zero stale references
- `AiCreditsExhaustedPayload` -> `AiSummaryFailedPayload`: zero stale references
- `broadcast_credits_exhausted` -> `broadcast_ai_summary_failed`: zero stale references
- `effective_auto_generate_ai_summaries_enabled?` -> `should_auto_generate_ai_summaries?`: zero stale references
- `process_overdue_ai_credit_resets` -> `process_ai_credit_resets`: zero stale references
- `reset_ai_credits_if_overdue`: zero stale references
- `apply_top_up_checkout`: zero stale references
- `period_overdue?`: zero stale references

## Verdict: 1 HIGH carried from angle-4. FAIL.
