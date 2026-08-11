# Conventions pass — cursor_rules/backend/background_jobs.md

Diff: `git diff develop...HEAD -- app/jobs/extract_job_criteria_job.rb app/jobs/bulk_generate_ai_summaries_job.rb` (HEAD 68e5e6a4e)

No issues found.

Rule-by-rule check of the changed lines:

- 0a Naming: no new or renamed job files in the diff — N/A.
- 0b When to use jobs: no new job/enqueue introduced — N/A.
- Rule 1 (Pass IDs, not objects): new `perform` parameter `requesting_organization_user_id` (extract_job_criteria_job.rb:15) is an ID — compliant. `broadcast_completion(ai_job_criteria, ...)` passes an object, but to a private instance helper, not as a job argument — outside rule 1's scope. (Optional-positional signature excluded per adjudicated flag 4.)
- Rule 2 (find_by with guard clauses): `OrganizationUser.find_by(id: requesting_organization_user_id)` + `return unless` (extract_job_criteria_job.rb:40-41); `AiJobCriteria.find_by(id: job.arguments.first)` + `if ai_job_criteria` (extract_job_criteria_job.rb:8-9) — compliant.
- Rule 3 (Jobs orchestrate): `broadcast_completion` builds a payload and calls `GlobalChannel.broadcast_to` — the same pattern as the rules file's own sanctioned codebase example (`ExportJobCandidatesToCsvJob`). `job_application_bulk_job_status.update_columns(status: :failed)` (bulk_generate_ai_summaries_job.rb:63) matches the identical pre-existing status writes at lines 56, 71, 91 of the same method — compliant.
- Rule 4 (rescue StandardError at method level): `perform` retains `rescue StandardError` (extract_job_criteria_job.rb:28); the added `broadcast_completion` call at line 23 is inside its coverage — compliant.
- Rule 5 (after_commit over after_save): no callback changes in the diff — N/A.
- Rule 6 (deliver_later): N/A to the diff.
- Logging (rescue blocks need both `ap` and `Rails.logger.error`): the modified `rescue StandardError` block (extract_job_criteria_job.rb:28-34) has both. The `retry_on` exhaustion block and the `rescue CustomErrorAiSummary` block use `ap` only, but those logging lines are unchanged context present on develop — not part of this diff.

Excluded per instructions: `ai_job_criteria.reload` (backend-base reviewer) and the optional-positional `perform` signature (adjudicated flag 4 — Sidekiq payload compatibility).
