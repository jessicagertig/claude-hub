# always-on-checks — Round 1

## Source accuracy

- F1 [LOW] The spec says `ShallowJobApplicationSerializer` eager loads `AiJobApplicationSummaryStatus`. The actual `ShallowJobApplicationSerializer` (app/serializers/api/v1/shallow_job_application_serializer.rb) currently has no AI-related attributes or associations. The controller that uses it (job_applications_controller.rb lines 25, 35) does `.includes(resume_attachment: :blob)` -- no AI includes. The spec correctly identifies this as a MODIFICATION needed, but the phrasing "eager loads this record" describes the future state as if it's current. Minor clarity issue.

- F2 [LOW] The spec references `Api::V1::AiJobApplicationSummarySerializer` for the full serializer. Verified: exists at app/serializers/api/v1/ai_job_application_summary_serializer.rb. Currently exposes `:id, :status, :headline, :summary_text, :structured_data, :job_application_id, :stale, :created_at`. The spec correctly says to add `score_percentage`, `criteria_results`, and `integrated_role_analysis`.

## Test coverage

- F3 [MED] The spec has no test plan section. Per Known Failure Pattern #3 in pipeline CLAUDE.md: "Every spec and implementation plan must state which existing tests need updating and what new test coverage is required." The following existing test files are affected by this change:
  - `spec/models/ai_job_application_summary_spec.rb` -- uses `status: :succeeded` (integer 2), has tests for `destroy_previous_textract_results`
  - `spec/jobs/generate_ai_job_application_summary_job_spec.rb` -- creates summaries with `status: :succeeded`, tests broadcast behavior
  - Any spec files for `Summary::Generate`, `CreateAiSummaryGeneration`, `ValidateAiSummaryGeneration`, `BulkGenerateAiSummariesJob`
  **Fix:** Add a test plan section listing existing tests that need updating and what new test coverage is required for the scoring pipeline, orchestrator, criteria extraction, and new models.

## Backward compatibility

- F4 [LOW] All references to `status_succeeded?`, `status: :succeeded`, `status_failed?`, `status: :failed` on `AiJobApplicationSummary` across the codebase have been identified. There are exactly 3 `status_succeeded?` callers in app code (textract_result.rb:79, generate_ai_job_application_summary_job.rb:51, ai_job_application_summary.rb:39) and 1 `status: :succeeded` query (bulk_generate_ai_summaries_job.rb:89). All use symbol-based references, which resolve correctly with the redesigned enum. The spec's instruction to "find every caller" is correct.

## Full-stack analog completeness

- F5 [LOW] The analog pipeline has: trigger -> validation -> creation -> job -> orchestration -> credit consumption -> notification -> broadcast. The scoring extension adds to the orchestration layer but preserves all other layers. No missing layer.
