# Plan Review

**Source:** plan.md
**Spec:** SPEC.md
**Verdict: APPROVED**
**Reviewed:** 2026-06-04

## Pass 1 Findings

### Fact Check

Every file path referenced in the plan was verified to exist in the source repo. All class names, method names, enum values, and behavioral claims were verified against the actual source code. Pattern precedent files all exist and match the claimed patterns.

Verified claims (sampling of key items):
- `AiCreditNotificationMailer#admin_recipients` line 62 uses `select(&:is_admin?)` -- confirmed
- `ApplyAiCreditRefund` uses `.order(:created_at).first` on line 17 and `.reload` on lines 21 and 62 -- confirmed
- `OrganizationAiCreditPurchase` has `AiCreditPacks.registered_keys` on line 14, unconditional `amount_cents_paid` presence on line 15, unconditional `currency` presence on line 16, unconditional `stripe_subscription_id` presence on line 19-21 -- confirmed
- `BulkGenerateAiSummariesJob` has `retry_on` before `discard_on` (lines 12 and 19) -- confirmed, retry_on is declared first (first checked = last declared in ActiveJob), so discard_on shadows it. The plan correctly identifies the fix.
- `PlanFeatureGate#daily_ai_credit_allocation` returns bare `plan_rules[@plan]&.dig(:daily_ai_credit_allocation)` with no fallback -- confirmed at line 140
- `PlanFeatureGate` comment on line 76 matches -- confirmed
- `TextractResult#queue_ai_summary_job` has `|| saved_change_to_id?` on line 97 -- confirmed
- `TextractResult#broadcast_credits_exhausted` uses action `'AI_CREDITS_EXHAUSTED'` -- confirmed at line 134
- `ValidateAiSummaryGeneration` line 29 error string is `'Resume processing has failed. Try uploading a different file.'` -- confirmed
- `Organization#process_overdue_ai_credit_resets` exists at line 904 and calls `reset_ai_credits_if_overdue` at line 912 -- confirmed
- `Organization#create_ai_credit_state_if_needed` rescue block at line 203 has `Rails.logger.error` and `ap` but no Sentry -- confirmed
- `Organization#default_auto_generate_ai_summaries_enabled?` at line 947 digs `'default_auto_generate_ai_summaries_enabled'` -- confirmed
- `Job#auto_generate_ai_summaries_setting` enum at line 158 with values inherit/on/off -- confirmed
- `Job#effective_auto_generate_ai_summaries_enabled?` at line 878 uses `auto_generate_ai_summaries_setting_on?`/`_off?` predicates -- confirmed
- `OrganizationAiCreditBalance` has `OVERDUE_RESET_GRACE`, `period_overdue?`, `reset_ai_credits_if_overdue`, `apply_top_up_checkout` -- all confirmed
- Stripe webhook handler: `object.mode == 'payment'` branch at lines 58-61, `raise CustomStripeSubscriptionMissingError` guard at line 204, listing branches below the guard at lines 206-236 -- all confirmed
- `handle_credit_pack_invoice_paid` `else` branch at lines 483-488 calls `ApplyAiCreditPurchase.call` -- confirmed
- All frontend file paths, import names, component names verified
- All spec file paths verified as existing
- Migration files verified as existing with correct timestamps

### Issue Found and Corrected

**C.6 -- `ai_bulk_extract.rake` prompt_text removal (MED, corrected):**

The plan stated: "remove `prompt_text:` from the `summary.update(...)` call (two occurrences at lines 62 and 78)."

Line 62 is inside `summary.update(...)` -- correct to remove (this is `AiJobApplicationSummary#prompt_text`, being removed per Note #26).

Line 78 is inside `AiApiRequest.create(...)` -- this is `AiApiRequest#prompt_text`, a different column on a different table. Note #26 removes `prompt_text` from `AiJobApplicationSummary` only; `AiApiRequest` keeps its `prompt_text` column as the authoritative per-call prompt record. Removing line 78 would silently break the AI API request audit logging.

**Correction applied:** Changed the plan to specify only line 62 and explicitly warn not to remove line 78.

### Completeness

All spec requirements mapped to plan steps:

| Spec requirement | Plan step |
|---|---|
| Note #1 -- mailer is_admin? bug + template renames | C.8 |
| Note #2 -- AiResumeStructuredData reconciliation | H.1 |
| Note #3 -- ApplyAiCreditRefund .last fix | C.5 |
| Note #4 -- top-up webhook + invoice creation | D.2 (purchase_top_up), E |
| Note #5 -- enum/method renames | B.1, C.3 |
| Note #6A -- AiCreditPacks into model | C.1 |
| Note #6B -- RoleCategoryGroups deletion | C.2 |
| Note #8 -- Flipper gate daily credits | C.9 |
| Note #9A -- controllers/policies/hooks | D.1-D.4, H.2 |
| Note #9B-1 -- correct pack IDs | C.1 |
| Note #9B-2 -- prices from Stripe | D.2 (prices action), H.3 |
| Note #9B-5 -- checkout subscription recording | C.1 (validation relaxation), D.2, E |
| Note #12 -- ConsumeAiCredits rename | C.4 |
| Note #13 -- bulk job notifications | G.1, G.2, H.1, H.5 |
| Note #19 -- AI tasks readme | J |
| Note #25 -- retry_on fix (TDD) | A, F |
| Note #26 -- prompt_text removal | B.1, C.6 |
| Note #27 -- overdue check removal | C.7 |
| Note #30 -- Sentry capture | C.11 |
| Note #31 -- PlanFeatureGate fallback | C.10 |
| Note #34 -- WebSocket action rename | C.13, H.1, H.5 |
| Note #35 -- saved_change_to_id? removal | C.12 |
| Note #37 -- comment removal | C.10 |
| Note #16 -- Plato AI container | I.1, I.2 |
| All test requirements | A, K.1-K.3 |

No spec requirement is missing from the plan.

### Safety

- No database safety violations. Migrations use `db:migrate`, `db:rollback`, `db:migrate:status` -- all allowed commands.
- No `.env` modifications.
- Authorization correctly handled: new controllers use existing policy patterns (`is_org_user?` for reads, `BillingPolicy` for billing actions).
- Admin-only gate on AccountPlatoAiContainer via `useAuthorization({ adminOnly: true })`.

### Scope and Ordering

- All steps trace to spec requirements.
- Dependencies correctly sequenced:
  - Migrations (B) before model code (C) -- correct, column must exist before enum references it
  - Model changes (C) before controllers (D) -- correct, controllers call model class methods
  - Controllers (D) before webhook handler changes (E) -- correct, webhook depends on validation relaxation and controller creating purchase at checkout
  - TDD spec (A) before fix (F) -- correct per requirement
  - Fix (F) before notifications (G) -- correct, notifications reference the corrected retry/discard blocks
  - Backend (C-G) before frontend (H-I) -- correct, frontend consumes API
  - Tests (K) last -- correct, all code changes finalized

### Risk Item: `apply_top_up_checkout` Removal Timing

The plan identifies this correctly in its Risks section (#2): `apply_top_up_checkout` is removed in C.7 but its caller (the `mode == 'payment'` branch) isn't removed until Phase E. The plan recommends deferring the method removal to Phase E. The plan also notes this dual listing in both C.7 and E. This is adequate -- the implementing agent should remove `apply_top_up_checkout` only in Phase E, not in C.7.

## Pass 2 Findings

Re-read of each plan step after the C.6 correction.

### Correction Verification

The C.6 step now correctly states: "remove `prompt_text:` from the `summary.update(...)` call at line 62. Do NOT remove the `prompt_text:` at line 78 -- that is inside `AiApiRequest.create`, which keeps its own `prompt_text` column." The correction is accurate. No new inconsistencies introduced.

### Fresh Scrutiny

1. **Phase A claim that "The spec already exists"**: The plan says "The spec already exists with `#each_iteration` and `#on_complete` blocks. Add the retry/discard assertions as new top-level `describe` blocks." Verified -- `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` exists with 95 lines. The plan correctly identifies adding to an existing file, not creating one. However, the Files to Create table at the bottom does NOT list this file (since it already exists), and the Files to Modify table correctly lists it in Phase A. Consistent.

2. **`notify_failure` in class-level blocks**: The plan's Risk #3 correctly notes that `discard_on`/`retry_on` blocks are class-level and receive `|current_job, error|`. The existing `update_remaining_statuses_to_failed` is a `private_class_method` accessed from these blocks. `notify_failure` will need the same pattern. The plan mentions following the existing pattern, which is correct.

3. **`apply_top_up_checkout` dual listing**: Confirmed the plan mentions removal in both C.7 and E, with E being the correct place. The risk section addresses the timing. No issue.

4. **`generate.rb` third `prompt_text` reference (line 315)**: This is inside `AiApiRequest.create` within the service's `record_api_request` method. The plan's C.6 correctly targets only `extraction_update_params` and `succeeded_update_params` -- the two `AiJobApplicationSummary` updates. The `AiApiRequest` creation is untouched. Correct.

5. **Frontend type file rename**: Plan H.1 includes renaming `aiCreditSubscription.ts` to `organizationAiCreditPurchase.ts`. Plan Risk #5 correctly warns about import path updates. Adequate.

6. **`memberPathNames` AI usage removal**: Plan I.2 says "In `memberPathNames`: remove `"/hire/settings/ai-usage": "AI usage"`. Non-admins get no Plato AI tab." Verified against source: line 57 of AccountContainer.tsx shows `...(aiApplicantSummaryEnabled ? { "/hire/settings/ai-usage": "AI usage" } : {})` in the non-admin path. The plan correctly identifies this for removal.

7. **Route format**: The plan's D.3 route definition uses `resource :ai_credits` (singular) and `resource :ai_credit_purchases` (singular). This matches the existing pattern (singleton resources for org-scoped entities). Correct.

8. **All files to delete, rename, create, modify**: Cross-checked the summary tables at the bottom of the plan against the phase-by-phase instructions. All are consistent.

Pass 2 clean. No additional issues found.

## Verdict

**APPROVED.** One minor factual error found and corrected (C.6 `ai_bulk_extract.rake` prompt_text -- plan incorrectly targeted `AiApiRequest.create`'s `prompt_text` for removal in addition to `summary.update`'s). Correction applied directly to plan.md. All other facts verified, all spec requirements covered, dependencies correctly ordered, safety rules respected.
