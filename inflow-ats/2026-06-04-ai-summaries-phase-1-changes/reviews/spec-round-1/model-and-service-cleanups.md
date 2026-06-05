# angle-8: model-and-service-cleanups — Round 1

Verified each sub-change against source:

**ApplyAiCreditRefund (Note #3 + #32):**
- Line 16-17: `.order(:created_at).first` confirmed — spec correctly changes to `.last`
- Line 21: `.reload` confirmed on `purchase.organization.organization_ai_credit_balance`
- Line 62: `context.purchase = purchase.reload` confirmed
- Both `.reload` removals are correct per the approved decision reasoning

**Overdue chain removal (Note #27):**
- `OVERDUE_RESET_GRACE` at line 4 of `organization_ai_credit_balance.rb` confirmed
- `period_overdue?` at line 30, `reset_ai_credits_if_overdue` at line 49 confirmed
- `process_overdue_ai_credit_resets` at line 904 of `organization.rb` confirmed
- Rake task call at line 76 of `ai_credits.rake` confirmed

**ResetDailyAiCredits Flipper guard (Note #8):**
- `allocation.nil? || allocation.zero?` guard at line 14 confirmed
- `Flipper.enabled?(:AI_APPLICANT_SUMMARY, ...)` pattern in `validate_ai_summary_generation.rb` line 42 confirmed as analog

**PlanFeatureGate (Notes #31, #37):**
- `DAILY_AI_CREDIT_ALLOCATION = 5` at line 133 confirmed
- `daily_ai_credit_allocation` at line 139 returns `plan_rules[@plan]&.dig(:daily_ai_credit_allocation)` with no fallback — confirmed as the asymmetry
- Line 76 comment "Universal features available to all tier 1 and tier 2 paid plans" confirmed

**Sentry in create_ai_credit_state_if_needed (Note #30):**
- Rescue block at lines 203-206 of `organization.rb` confirmed — has `Rails.logger.error` and `ap` but no `Sentry.capture_exception`

**prompt_text removal (Note #26):**
- `generate.rb` line 67: `prompt_text: extraction_messages.to_json` confirmed
- `generate.rb` lines 168-173: `prompt_text: { extraction: ..., assessment: ..., comparison: ..., summary: ... }.compact.to_json` confirmed
- `ai_bulk_extract.rake` line 62: `prompt_text: extraction_messages.to_json` confirmed (spec says line 63, actual line 62 — minor, not a finding)
- Migration `t.text :prompt_text` at line 11 confirmed

**ConsumeAiCredits rename (Note #12):**
- Class at line 19, 2 logger strings at lines 30/60 confirmed
- `textract_result.rb` line 81: `ConsumeAiCredits.call(...)` confirmed
- `notify_zero_ai_credits.rb` line 8: comment reference confirmed
- Spec files confirmed

**WebSocket rename (Note #34):**
- `broadcast_credits_exhausted` at line 127, action `'AI_CREDITS_EXHAUSTED'` at line 134 of `textract_result.rb` confirmed
- `validate_ai_summary_generation.rb` line 29: error string confirmed

**saved_change_to_id? removal (Note #35):**
- `textract_result.rb` line 97: `saved_change_to_textract_job_result_text? || saved_change_to_id?` confirmed

**RoleCategoryGroups deletion (Note #6B):**
- `role_category_groups.rb` exists, zero references outside its own file confirmed

**AiResumeStructuredData reconciliation (Note #2):**
- Would need to verify against `aiJobApplicationSummary.ts` type definition

No BLOCKER or HIGH findings for this angle.
