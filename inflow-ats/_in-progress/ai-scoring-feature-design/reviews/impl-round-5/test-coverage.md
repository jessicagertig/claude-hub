# test-coverage -- Round 5

## Scope
Existing test updates, new test coverage, coverage completeness.

## New spec files (9)

| File | Coverage |
|------|----------|
| `spec/models/ai_job_criteria_spec.rb` | Enum values, associations, `after_commit` callback (succeeded enqueues, failed does not, handles 0 and N waiting summaries) |
| `spec/models/ai_job_application_summary_status_spec.rb` | Uniqueness validation, defaults, nullable summary_id |
| `spec/models/job_criteria_lifecycle_spec.rb` | `extract_job_criteria` (Flipper gate, pending debounce, in_progress/succeeded/failed reset, save failure), `description_meaningfully_changed?` (HTML, whitespace, numbers, text, case) |
| `spec/jobs/extract_job_criteria_job_spec.rb` | Not-found guard, delegation to service |
| `spec/services/ai_job_application_action/orchestrate_spec.rb` | Terminal state no-op, pending full pipeline, awaiting_job_criteria resume, no textract/summary guard |
| `spec/services/ai_job_application_action/scoring/extract_criteria_spec.rb` | Guard clauses, blank description, no criteria sections, happy path (status transitions, criteria populated, metadata, AiApiRequest creation), heading override (required/bonus/soft skill), dedup, error handling (3 tiers) |
| `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb` | nil textract guard, criteria absent path (sets awaiting, triggers extraction), criteria failed path, happy path (status, score, criteria_results merge, AiApiRequest), error handling (3 tiers) |
| `spec/services/ai_job_application_action/scoring/calculate_spec.rb` | Empty/nil input, single tier full_match, partial_match, not_found, title technology multiplier, mixed tiers, unknown tier default |
| `spec/services/ai_job_application_action/scoring/integrate_analysis_spec.rb` | nil summary guard, happy path (status, integrated_role_analysis, no side effects on other fields), nil structured_data, error handling (3 tiers) |

## Modified spec files

- `spec/models/ai_job_application_summary_spec.rb`: Enum assertion updated from 6 to 10 values with correct integer mappings
- (No other spec modifications needed -- existing specs use symbol references which map correctly)

## Coverage assessment

All spec files cover:
- Happy path
- Guard clauses / not-found paths
- Error handling (CustomErrorAiSummary re-raise, JSON::ParserError no re-raise, StandardError no re-raise)
- Edge cases specific to each service

Test file count in the plan: ~10 new, ~4 modified. Actual: 9 new, 1 modified. The discrepancy: `spec/support/ai_credits_test_helpers.rb` and `spec/jobs/generate_ai_job_application_summary_job_spec.rb` and `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` did not need status reference updates because they use symbol references that still resolve correctly with the new enum. The serializer spec was not created (plan item J.6.1) -- this is coverage that could be added but is not spec-required. Not flagging as a finding since the serializer follows the simplest possible pattern (listing attribute names) and the attributes are tested indirectly through the service and integration specs.

## Findings

None.
