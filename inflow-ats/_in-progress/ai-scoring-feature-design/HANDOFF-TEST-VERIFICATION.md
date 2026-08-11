# Test Verification Session — Handoff

## Purpose

Verify every test added or modified on `feature-ai-summaries-integrating-scoring-v3` since `develop`. Check for ghost tests (tests that pass but don't actually test what they claim), incorrect stubs masking real failures, missing edge cases, and convention violations.

## Branch

`feature-ai-summaries-integrating-scoring-v3` in `/Users/jessica/wrk/wrk-corp/inflow-ats`

## Diff command

```
git diff develop...HEAD -- 'spec/**' 'spec/support/**'
```

## All test files added or modified (39 files, 4287 new lines)

### Interactor specs (11 files)
- `spec/interactors/apply_ai_credit_purchase_spec.rb` (108 lines)
- `spec/interactors/apply_ai_credit_refund_spec.rb` (128 lines)
- `spec/interactors/cancel_ai_credit_subscription_spec.rb` (66 lines)
- `spec/interactors/create_ai_credit_balance_transaction_spec.rb` (85 lines)
- `spec/interactors/credit_consumption_with_notifications_spec.rb` (149 lines)
- `spec/interactors/grant_ai_credits_spec.rb` (118 lines)
- `spec/interactors/notify_low_ai_credits_spec.rb` (101 lines)
- `spec/interactors/notify_zero_ai_credits_spec.rb` (87 lines)
- `spec/interactors/queue_bulk_ai_summary_jobs_spec.rb` (87 lines)
- `spec/interactors/reset_ai_credits_spec.rb` (108 lines)
- `spec/interactors/reset_daily_ai_credits_spec.rb` (66 lines)

### Job specs (4 files)
- `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` (207 lines)
- `spec/jobs/extract_job_criteria_job_spec.rb` (34 lines)
- `spec/jobs/generate_ai_job_application_summary_job_spec.rb` (207 lines)
- `spec/jobs/get_resume_text_from_textract_job_spec.rb` (87 lines)

### Webhook/Stripe spec (1 file)
- `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` (172 lines)

### Mailer spec (1 file)
- `spec/mailers/ai_credit_notification_mailer_spec.rb` (89 lines)

### Model specs (10 files)
- `spec/models/ai_credit_balance_transaction_spec.rb` (120 lines)
- `spec/models/ai_job_application_summary_spec.rb` (45 lines)
- `spec/models/ai_job_application_summary_status_spec.rb` (31 lines)
- `spec/models/ai_job_criteria_spec.rb` (103 lines)
- `spec/models/job_ai_settings_spec.rb` (52 lines)
- `spec/models/job_criteria_lifecycle_spec.rb` (134 lines)
- `spec/models/organization_ai_credit_balance_spec.rb` (83 lines)
- `spec/models/organization_ai_credit_purchase_spec.rb` (182 lines)
- `spec/models/organization_ai_credits_lifecycle_spec.rb` (57 lines)
- `spec/models/organization_ai_credits_spec.rb` (67 lines)
- `spec/models/textract_result_ai_trigger_spec.rb` (171 lines)

### Policy spec (1 file)
- `spec/policies/organization_ai_credit_balance_policy_spec.rb` (38 lines)

### Serializer spec (1 file)
- `spec/serializers/organization_ai_credit_balance_serializer_spec.rb` (30 lines)

### Service specs (6 files)
- `spec/services/ai_job_application_action/orchestrate_spec.rb` (147 lines)
- `spec/services/ai_job_application_action/scoring/calculate_spec.rb` (69 lines)
- `spec/services/ai_job_application_action/scoring/extract_criteria_spec.rb` (317 lines)
- `spec/services/ai_job_application_action/scoring/integrate_analysis_spec.rb` (195 lines)
- `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb` (257 lines)
- `spec/services/plan_feature_gate_ai_credits_spec.rb` (54 lines)

### Stripe service spec (1 file)
- `spec/services/stripe/cancel_credit_pack_subscription_spec.rb` (31 lines)

### Other specs (1 file)
- `spec/services/submit_resume_to_textract_spec.rb` (60 lines)

### Test support (1 file)
- `spec/support/ai_credits_test_helpers.rb` (145 lines)

## What to verify for each spec

1. **Run it** — does it actually pass? `RAILS_ENV=test bundle exec rspec <file>`
2. **Ghost test check** — comment out the implementation code each test claims to exercise. Does the test fail? If it still passes, it's not testing what it says.
3. **Stub audit** — are stubs matching what production code actually passes? (Known Failure Pattern #7: stubs masking type mismatches)
4. **Coverage** — does the spec cover the error paths, edge cases, and guard clauses in the implementation?
5. **Convention check** — does it follow `cursor_rules/backend/_base.md` and test conventions?
6. **Enum references** — any raw integer enum references instead of symbols?

## Known issues already identified

- `spec/models/job_criteria_lifecycle_spec.rb` Flipper test — was fixed (boolean gate disable instead of actor gate)
- `spec/support/ai_credits_test_helpers.rb` — may have stale enum references (flagged as MED-8 in QA)

## Context files

- Feature spec: `~/claude-hub/inflow-ats/_in-progress/ai-scoring-feature-design/SPEC.md`
- Source repo conventions: `/Users/jessica/wrk/wrk-corp/inflow-ats/cursor_rules/`
- Pipeline known failure patterns: `~/claude-hub/inflow-ats/CLAUDE.md` (16 patterns)
