# Conventions Review — cursor_rules/backend/architecture.md

Scope: `git diff develop...HEAD -- app/` (backend files) at 68e5e6a4e in /Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings
Rules source: cursor_rules/backend/architecture.md ONLY (rules 1-3, request-cycle flow, background-processing key points).

No issues found.

## Placement decisions checked (verdicts with evidence)

- **Zero-criteria guard in validators + model funnel (vs interactor/service)** — CONFORMS. `AiJobCriteria#zero_criteria_failure?` (app/models/ai_job_criteria.rb:16-18) and `Job#zero_criteria_extraction_failure?` (app/models/job.rb:696-698) put the business logic on models ("Model methods contain business logic"). Guards added inside existing validation interactors (app/interactors/validate_ai_summary_generation.rb:30, app/interactors/validate_auto_ai_summary_generation.rb:19, app/interactors/queue_bulk_ai_summary_jobs.rb:19) — interactors are the rule-1 home for validation logic. Model-side guard in `TextractResult#generate_ai_summary_with_credit_flow` (app/models/textract_result.rb:70) is a model instance method, per the background-processing flow.

- **Serializer computed methods delegating to Job model methods** — CONFORMS. `Api::V1::JobAiJobCriteriaSerializer` (app/serializers/api/v1/job_ai_job_criteria_serializer.rb:5-20) delegates every attribute to Job model methods (`latest_succeeded_ai_job_criteria`, `latest_ai_job_criteria`, `zero_criteria_extraction_failure?`); no business logic in the serializer. Matches the Model(s) → Serializer → JSON flow.

- **Broadcast logic living in the job class** — NO VIOLATION of this rules file. Rule 2 prohibits jobs calling **services** directly; `GlobalChannel.broadcast_to` (app/jobs/extract_job_criteria_job.rb:57-61) is an ActionCable channel, not an app/services class, and architecture.md contains no rule on broadcast placement. Structure of `broadcast_completion` (app/jobs/extract_job_criteria_job.rb:39-63: user lookup → status gate → payload build → broadcast) is identical to the direct domain analogs, which also live in job classes: app/jobs/generate_ai_job_application_summary_job.rb:55-81 and app/jobs/bulk_generate_ai_summaries_job.rb:138-199 (`notify_complete`/`notify_failure`). Job still receives IDs only (`perform(ai_job_criteria_id, requesting_organization_user_id = nil)`, app/jobs/extract_job_criteria_job.rb:15), per "Jobs receive IDs."

- **Predicate methods on AiJobCriteria/Job** — CONFORMS. `zero_criteria_failure?` sits on `AiJobCriteria` beside the `ZERO_CRITERIA_*` message constants it interprets (app/models/ai_job_criteria.rb:7-18); `Job#zero_criteria_extraction_failure?` funnels through `latest_ai_job_criteria` (app/models/job.rb:696-698). Services reference the model constants (app/services/ai_job_application_action/scoring/extract_criteria.rb:62,122; app/services/ai_job_application_action/scoring/score_job_application.rb:43) rather than duplicating strings.

- **Rule 1 (controller >15 lines of business logic → interactor)** — CONFORMS. `Api::V1::AiJobCriteriaController#create` (app/controllers/api/v1/ai_job_criteria_controller.rb:12-28) is two guard checks + one model method call + render (~8 lines of business logic); follows the "Model directly (if simple)" path with Pundit `authorize` on both actions (lines 6, 14).

- **Rule 2 (jobs call model instance methods)** — CONFORMS for diff content. `job_application_bulk_job_status.update_columns(status: :failed)` (app/jobs/bulk_generate_ai_summaries_job.rb:63) and `ai_job_criteria.update_columns(...)` (app/jobs/extract_job_criteria_job.rb:10,33) are model instance method calls. No new job→service call added by the diff (the `ExtractCriteria` service call at app/jobs/extract_job_criteria_job.rb:19-21 is pre-existing context, unchanged).

- **Rule 3 (after_create vs after_commit)** — N/A. Diff adds no callbacks.
