# Angle 8: Model and Service Cleanups -- Round 4

## Fresh adversarial focus areas

1. **`ApplyAiCreditRefund` query direction fix.** `.order(:created_at).last` selects the most recent credit row. This is correct per spec: "selects oldest credit row" was the bug; the fix selects the most recent. Wait -- let me re-read the spec. Note #3 says: "On the `original_credit_row` query, change `.order(:created_at).first` to `.order(:created_at).last`." The name `original_credit_row` suggests the "first" (oldest) credit row, but the spec explicitly says change to `.last`. This is the spec's instruction and the code follows it. Correct per spec.

2. **`PlanFeatureGate#daily_ai_credit_allocation` fallback.** `plan_rules[@plan]&.dig(:daily_ai_credit_allocation) || DAILY_AI_CREDIT_ALLOCATION`. If the plan has no `:daily_ai_credit_allocation` rule (or `dig` returns nil), falls back to the constant. The constant is `Variables::AI_DAILY_CREDIT_ALLOCATION` which is `ENV['AI_DAILY_CREDIT_ALLOCATION']&.to_i || 5`. Correct.

3. **`broadcast_ai_summary_failed` default error message.** `validation_error || 'AI summary generation failed'`. If `validation_error` is nil (no error string passed), uses generic message. The caller in `queue_ai_summary_job` passes `result.error` from `ValidateAiSummaryGeneration`. The other caller (from `generate_ai_summary_with_credit_flow`) passes the validation error. Correct.

4. **`reset_ai_credits.rb` comment update.** Changed reference from `process_overdue_ai_credit_resets` to `Safety-net rake task (if applicable)`. Non-specific but accurate. Correct.

5. **`prompt_text` removal.** Verified remaining `prompt_text` references are in `AiApiRequest.create` calls (which has its own `prompt_text` column). Correct.

## Findings

**No findings.**
