# Test Coverage — Round 1

## Findings

- F1 [HIGH] Two existing spec files not updated for enum rename. Will fail at runtime:
  - `spec/models/job_ai_settings_spec.rb` — uses `auto_generate_ai_summaries_setting`, `:inherit/:on/:off`, `effective_auto_generate_ai_summaries_enabled?`
  - `spec/models/textract_result_ai_trigger_spec.rb` — uses `default_auto_generate_ai_summaries_enabled`, `auto_generate_ai_summaries_setting`, old enum values
  (Same as angle-4 F1/F2, always-on A2 F1/F2, always-on A3 F1 -- cross-referenced for the test-coverage angle.)

All new test requirements from the spec are met. The gap is in EXISTING tests that reference renamed identifiers but were not listed in the plan.
