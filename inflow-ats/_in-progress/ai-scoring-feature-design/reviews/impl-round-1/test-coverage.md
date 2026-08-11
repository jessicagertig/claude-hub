# Test Coverage -- Round 1

## Findings

- F7 [HIGH] Missing spec files per plan Phase J: The plan specifies 14 spec files (new + modified). The implementation has only the following:
  - `spec/models/ai_job_criteria_spec.rb` -- present
  - `spec/models/ai_job_application_summary_status_spec.rb` -- present
  - `spec/models/ai_job_application_summary_spec.rb` -- modified (present)
  - `spec/models/job_criteria_lifecycle_spec.rb` -- present
  - `spec/jobs/extract_job_criteria_job_spec.rb` -- present
  - `spec/services/ai_job_application_action/orchestrate_spec.rb` -- present
  - `spec/services/ai_job_application_action/scoring/calculate_spec.rb` -- present
  
  **Missing:**
  - `spec/services/ai_job_application_action/scoring/extract_criteria_spec.rb` -- NOT PRESENT. The most complex new service with 2 AI calls, heading override, dedup, and error handling has no tests.
  - `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb` -- NOT PRESENT. Scoring service with criteria check, 2 AI calls, merge logic has no tests.
  - `spec/services/ai_job_application_action/scoring/integrate_analysis_spec.rb` -- NOT PRESENT. Integration service with AI call and terminal status transition has no tests.
  - `spec/serializers/ai_job_application_summary_serializer_spec.rb` -- NOT PRESENT. New serializer attributes untested.
  - `spec/jobs/generate_ai_job_application_summary_job_spec.rb` -- NOT MODIFIED for the new exhaustion block behavior (the exhaustion block is new code that sets `failed` status and broadcasts).
  - `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` -- NOT MODIFIED (plan says it should be checked for enum reference updates).
  
  **Recommended fix:** Create the three missing service specs. The three services (`ExtractCriteria`, `ScoreJobApplication`, `IntegrateAnalysis`) are the core business logic of the feature and have zero test coverage.

- F8 [MED] `spec/support/ai_credits_test_helpers.rb` -- not checked or updated per plan Phase C.8.4. The plan says to verify `status: :succeeded` references work with the new enum. Since the helper uses symbols (not integers), this should work, but it was not verified.
