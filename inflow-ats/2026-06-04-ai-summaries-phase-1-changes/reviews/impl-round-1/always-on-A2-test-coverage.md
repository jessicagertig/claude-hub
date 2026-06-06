# A2 — Test Coverage — Round 1

## Findings

- F1 [HIGH] `spec/models/job_ai_settings_spec.rb` / NOT UPDATED. Uses old enum name `auto_generate_ai_summaries_setting`, old values (`:inherit`, `:on`, `:off`), and old method name `effective_auto_generate_ai_summaries_enabled?`. This spec will FAIL after the rename. This is a ripple site that was missed -- see angle-4 F1.

- F2 [HIGH] `spec/models/textract_result_ai_trigger_spec.rb` / NOT UPDATED. Uses old settings key `default_auto_generate_ai_summaries_enabled`, old enum name `auto_generate_ai_summaries_setting`, and old enum values. This spec will FAIL after the rename. This is a ripple site that was missed -- see angle-4 F2.

All other test coverage requirements are met:
- Mailer spec covers `admin_recipients`, `low_credits`, `zero_credits`
- Bulk job spec covers retry/discard ordering and notification assertions
- Mailer stubs use `instance_double(ActionMailer::MessageDelivery)` with `.deliver_later` verification
- Renamed spec files reflect new class names internally
- `spec/models/organization_ai_credit_purchase_spec.rb` has `CREDIT_PACKS_BY_LOOKUP_KEY` coverage
