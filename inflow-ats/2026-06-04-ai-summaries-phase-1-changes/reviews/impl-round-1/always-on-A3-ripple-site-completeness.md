# A3 — Ripple-site Completeness for Renames — Round 1

## Findings

- F1 [HIGH] Two spec files have stale references to `auto_generate_ai_summaries_setting` / `effective_auto_generate_ai_summaries_enabled?` / `default_auto_generate_ai_summaries_enabled`:
  - `spec/models/job_ai_settings_spec.rb` — 4 stale enum references + 5 stale method calls
  - `spec/models/textract_result_ai_trigger_spec.rb` — 9 stale enum/settings references
  These files were not listed in the plan's "Files to Modify" or "Files to Rename" tables, meaning the plan itself missed them and the implementation followed the plan faithfully. But they WILL FAIL.

- F2 [MED] `app/interactors/reset_ai_credits.rb:6` / Comment references old method name `Organization.process_overdue_ai_credit_resets`. Should be `Organization.process_ai_credit_resets`.

All other rename ripple sites are clean:
- `AiCreditPacks.*` to `OrganizationAiCreditPurchase.*`: zero stale references (verified via grep)
- `ConsumeAiCredits` to `CreateAiCreditBalanceTransaction`: zero stale references in production code
- `AI_CREDITS_EXHAUSTED`: zero stale references
- `AiCreditsExhaustedPayload`: zero stale references
- Frontend hook/type imports: zero stale references
