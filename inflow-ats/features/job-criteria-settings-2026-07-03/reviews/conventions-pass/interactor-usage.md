# Conventions review — interactor usage (cursor_rules/backend/interactors/interactor_usage_and_guidelines.md)

Worktree: /Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings (HEAD 68e5e6a4e)
Diff: `git diff develop...HEAD` — validate_ai_summary_generation.rb, validate_auto_ai_summary_generation.rb, queue_bulk_ai_summary_jobs.rb, textract_result.rb, bulk_ai_job_application_summaries_controller.rb

## Findings

- F1 [LOW] app/interactors/queue_bulk_ai_summary_jobs.rb:19 / rule: "Pass All Dependencies via Context" / The new guard reads the `job` context input with safe navigation (`context.job&.zero_criteria_extraction_failure?`), treating a functionally required dependency as optional. Both callers (bulk_ai_job_application_summaries_controller.rb:17 and :43) pass `job:` unconditionally and non-nil (`current_organization.jobs.find(...)` raises on miss), and the sibling interactor ValidateAiSummaryGeneration fails explicitly (`context.fail!(error: 'Job application not found')`, validate_ai_summary_generation.rb:24) when a required context input is missing. If a caller omits `job`, this guard silently no-ops instead of failing loudly. / evidence: `context.fail!(error: 'No scoring criteria were found...') if context.job&.zero_criteria_extraction_failure?` / fix: read `context.job` without `&.` (or add an explicit `context.fail!` nil-check for `job`) so a missing dependency surfaces instead of silently skipping the check.

## Checked and compliant (no finding)

- How interactors are called: both controller call sites pass all dependencies via context keywords (`organization:`, `user:`, `job_application_ids:`, `job:`, `params:`) per the "From Controllers" pattern (bulk_ai_job_application_summaries_controller.rb:13-19, 39-46). No globals/session/instance-variable access added inside any interactor.
- Result handling: both controller actions use `result.success?` / `render_general_errors([result.error])`, matching the documented pattern exactly (bulk_ai_job_application_summaries_controller.rb:21-29, 48-56). Diff does not alter result handling.
- Error messages with context: the new `context.fail!` messages (validate_ai_summary_generation.rb:30, validate_auto_ai_summary_generation.rb:19, queue_bulk_ai_summary_jobs.rb:19) state what is wrong and the remediation. The failing condition is boolean (`zero_criteria_extraction_failure?`, defined at app/models/job.rb:696) — there is no current value to interpolate.
- Return Meaningful Objects: failure path returns via `context.fail!(error:)`; no new success outputs required by the guard.
- Model change (app/models/textract_result.rb:70): a one-line simple state check (`return if job_application.job.zero_criteria_extraction_failure?`) — the rules file assigns simple state checks to model level; no interactor delegation required.
