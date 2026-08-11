# Conventions pass: controller_patterns_and_crud.md

Scope: `git diff develop...HEAD` (HEAD 68e5e6a4e) for `app/controllers/api/v1/ai_job_criteria_controller.rb`, `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb`, `config/routes.rb`. Rules file: `cursor_rules/backend/controllers/controller_patterns_and_crud.md` only.

No issues found.

Checks performed (all compliant):

- **Routes / HTTP verbs (put not patch):** `config/routes.rb:266` adds `resource :ai_job_criteria, only: [:show, :create]` — GET + POST only, no update route, so the put-vs-patch rule is not implicated.
- **Always authorize:** `ai_job_criteria_controller.rb:6` (`authorize job, :show?`) and `:13` (`authorize job, :update_ai_settings?`) — both new actions authorize.
- **`exists` helper:** `ai_job_criteria_controller.rb:5` and `:12` both wrap the job lookup in `exists(current_organization.jobs.where(id: params[:job_id]), 'no job found')`, matching the rules' pattern.
- **Render helpers from the approved list:** `render_one` (`:7`, `:26`) and `render_general_errors` (`:16`, `:21`) only; no `render_many`.
- **Early returns with guard clauses:** `:15-18` (Flipper gate) and `:20-23` (blank description) follow the rules' feature-gate example exactly (`render_general_errors([...])` then `return`).
- **One params definition per controller:** `ai_job_criteria_controller.rb` defines no param methods (no body params are consumed — compliant by absence). `bulk_ai_job_application_summaries_controller.rb` still has exactly one params method, `bulk_ai_job_application_summary_params` (`:77-86`); the diff adds only `job: @job` to the two `QueueBulkAiSummaryJobs.call` invocations (`:17`, `:43`), and `@job` is assigned earlier in each action (`:9`, `:35`).
- **Delegate business logic / controllers orchestrate:** `create` orchestrates only — authorize, two guards, one call to `Job#extract_job_criteria_immediately` (`app/models/job.rb:730-739`, a 9-line guard-and-enqueue method that enqueues `ExtractJobCriteriaJob`), then `render_one`. Consistent with the rules' own standard-CRUD examples that call model methods directly.
