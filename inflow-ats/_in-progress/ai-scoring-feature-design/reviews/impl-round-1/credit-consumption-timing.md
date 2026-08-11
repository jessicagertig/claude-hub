# Credit Consumption Timing -- Round 1

## Findings

No issues found.

Credit consumption in `TextractResult#generate_ai_summary_with_credit_flow` (line 75) gates on `status_succeeded?`. `succeeded` is now enum value 7 (full pipeline complete). Credits are only consumed after summary + scoring + integration all complete. The `CreateAiCreditBalanceTransaction` call is unchanged. Reuses `ai_summary_usage_debit: 60` entry type per spec Section 8.
