# test-coverage — Implementation Review Round 2

## Files reviewed

- `spec/services/ai_job_application_action/scoring/extract_criteria_spec.rb` (15 examples)
- `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb` (12 examples)
- `spec/services/ai_job_application_action/scoring/integrate_analysis_spec.rb` (10 examples)
- `spec/services/ai_job_application_action/orchestrate_spec.rb`
- `spec/services/ai_job_application_action/scoring/calculate_spec.rb` (8 examples)
- `spec/models/ai_job_application_summary_spec.rb`
- `spec/models/ai_job_application_summary_status_spec.rb`
- `spec/models/ai_job_criteria_spec.rb`
- `spec/models/job_criteria_lifecycle_spec.rb`
- `spec/jobs/extract_job_criteria_job_spec.rb`
- `spec/jobs/generate_ai_job_application_summary_job_spec.rb`

## Findings

No findings at HIGH or MED level.

### Round 1 F7 resolution

The three missing spec files from Round 1 F7 have been created by the fix agent. Coverage assessment:

**`extract_criteria_spec.rb` (15 examples):**
- Guard clauses (nil ai_job_criteria, blank description, no criteria sections)
- Happy path (status transition, criteria population, metadata, AiApiRequest creation)
- Status progression (in_progress before calls)
- Heading tier override (required -> tier_1, bonus -> tier_3, soft skill skip)
- Deduplication (duplicate filter, raw/final counts)
- Error handling (CustomErrorAiSummary -> failed + re-raise, JSON::ParserError -> failed, StandardError -> failed)

**`score_job_application_spec.rb` (12 examples):**
- Guard clause (nil textract_result)
- Criteria absent paths (no AiJobCriteria -> awaiting_job_criteria, in_progress AiJobCriteria -> awaiting_job_criteria)
- Extract trigger (triggers extract_job_criteria when no criteria or failed criteria)
- Happy path (status transition, score_percentage, criteria_results merge, AiApiRequest creation)
- Error handling (CustomErrorAiSummary -> retrying + re-raise, JSON::ParserError -> failed, StandardError -> failed)

**`integrate_analysis_spec.rb` (10 examples):**
- Guard clause (nil summary)
- Happy path (status transition, integrated_role_analysis, no modification of score/criteria/structured_data, AiApiRequest creation)
- Nil structured_data handling
- Error handling (CustomErrorAiSummary -> retrying + re-raise, JSON::ParserError -> failed, StandardError -> failed)

### Test quality assessment

- **Stubs are appropriate:** `AiClient` stubbed via `instance_double`, which enforces the interface. `AiClient.calculate_cost` stubbed. No stubs that mask type mismatches (Known Failure Pattern #7).
- **No fabricated fallback values in tests** (Known Failure Pattern #13).
- **Bang methods in specs are acceptable** (core_critical_rules #10 exception).
- **Error handling correctly distinguishes `failed` vs `retrying`:** `ExtractCriteria` sets `failed` on `CustomErrorAiSummary` (AiJobCriteria has no `retrying` status). `ScoreJobApplication` and `IntegrateAnalysis` set `retrying` on `CustomErrorAiSummary` (AiJobApplicationSummary has `retrying` status). Tests verify the correct status for each.

### Round 1 F8 status (ai_credits_test_helpers.rb enum compatibility)

This was MED in Round 1, not a fix requirement. The test helpers use `create_credit_test_*` factories that don't directly reference AiJobApplicationSummary enum values. The new specs use these helpers successfully. No enum incompatibility observed.
