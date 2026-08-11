# Conventions Pass — backend/code_style_and_structure.md

Reviewed: `git diff develop...HEAD -- app/models app/controllers app/serializers app/jobs app/interactors app/services` at HEAD 68e5e6a4e in /Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings
Rules file: cursor_rules/backend/code_style_and_structure.md (only)

## Findings

- F1 [MED] app/jobs/bulk_generate_ai_summaries_job.rb:62-65 / "Error Handling Actions — Logging: Always log errors with context" + "Jobs — Log errors and sometimes update status or trigger retry" / New failure branch marks the row failed but never logs the error; `result.error` (the interactor's failure message, e.g. the new zero-criteria message) is discarded with no log entry / Evidence: `unless result.success?` → `job_application_bulk_job_status.update_columns(status: :failed)` → `return` — no `Rails.logger.error` or `ap`, while sibling failure paths in the same job do log (line 95 `Rails.logger.error "BulkGenerateAiSummariesJob iteration failed for job_application #{job_application_id}: #{e.message}"`, line 132) / Fix: log the validation failure with context before returning, e.g. `Rails.logger.error "BulkGenerateAiSummariesJob validation failed for job_application #{job_application_id}: #{result.error}"`

## Checked and clean (per this rules file only)

- File & directory structure: new controller `app/controllers/api/v1/ai_job_criteria_controller.rb` (snake_case_controller.rb), new serializer `app/serializers/api/v1/job_ai_job_criteria_serializer.rb` (resource_name_serializer.rb in app/serializers/api/v1/); no new service files; no 'service' in any touched service filename.
- Interactors: all three new `context.fail!` calls (queue_bulk_ai_summary_jobs.rb:19, validate_ai_summary_generation.rb:30, validate_auto_ai_summary_generation.rb:19) return error messages — conforms.
- Jobs error handling, extract_job_criteria_job.rb: exhaustion block and `rescue StandardError` both log (`ap` / `Rails.logger.error`), update status + error_message via `update_columns`, and now broadcast completion — conforms, including "Broadcast/Notification: Trigger notifications for critical errors."
- Rescue usage: no new rescue blocks added; existing rescues targeted with specific handling — no blanket rescue introduced.
- Model design: `AiJobCriteria#zero_criteria_failure?` and `Job#zero_criteria_extraction_failure?` are instance methods for entity-specific logic; constants frozen; no association/validation changes.
- Method return patterns: all new/modified guard clauses (`Job#extract_job_criteria_immediately`, `Job#extract_job_criteria_if_needed`, `TextractResult` line 70, `ExtractJobCriteriaJob#broadcast_completion`) are early exits without values; no guard clause returns a value; serializer and predicate methods use implicit return.
- Fallback returns: no fabricated fallback values in new code (serializer uses `&.` and returns nil).

## Re-verification (post 9ed954142)

Re-verified at HEAD 9ed954142 in /Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings. Scope: shipped code for F1 + all backend hunks of `git show 9ed954142` (app/jobs/bulk_generate_ai_summaries_job.rb, app/jobs/extract_job_criteria_job.rb, spec/jobs/bulk_generate_ai_summaries_job_spec.rb), checked against cursor_rules/backend/code_style_and_structure.md only.

- F1 [MED] — **RESOLVED.** app/jobs/bulk_generate_ai_summaries_job.rb:63 (shipped code at HEAD) now logs before marking the row failed: `Rails.logger.error "BulkGenerateAiSummariesJob validation failed for job_application #{job_application_id}: #{result.error}"`, immediately followed by `job_application_bulk_job_status.update_columns(status: :failed)` and `return`. Satisfies "Logging: Always log errors with context" (job class, job_application_id, interactor error message) and "Jobs — Log errors and sometimes update status." Matches the fix proposed in F1 verbatim.

Fix-commit backend hunks re-checked against this rules file:

- app/jobs/bulk_generate_ai_summaries_job.rb (+1 line): the log line only. No new rescue, no guard-clause-returning-a-value, no fallback value — conforms.
- app/jobs/extract_job_criteria_job.rb (broadcast_completion): `ai_job_criteria.reload` replaced with `ai_job_criteria = AiJobCriteria.find_by(id: ai_job_criteria.id)` plus `return unless ai_job_criteria` (lines 46-47). Guard clause is an early exit without a value — conforms to "Use guard clauses only for early exits without values" / "Never use guard clauses to return a value." No rescue added; no fallback fabricated (method contract requires no return value). Conforms.
- spec/jobs/bulk_generate_ai_summaries_job_spec.rb: `validation_result` double gained `error: 'validation failed'` so the new log line has a message to interpolate. Spec files are outside this rules file's scope ("all Ruby/Rails files in `app/`"); noted for completeness, nothing to flag.

New findings: none (0).

Verdict: F1 RESOLVED, 0 new findings.
