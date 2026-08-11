# Conventions pass — backend core_critical_rules.md

Reviewer scope: `git diff develop...HEAD -- app/models app/controllers app/serializers app/jobs app/interactors app/services config spec` at HEAD 68e5e6a4e, checked against `cursor_rules/backend/core_critical_rules.md` only. (`ai_job_criteria.reload` excluded — owned by backend-base reviewer.)

No issues found.

Rules verified against the diff:

- Rule 1 (controllers: no begin blocks): `app/controllers/api/v1/ai_job_criteria_controller.rb` and the `bulk_ai_job_application_summaries_controller.rb` changes contain no `begin` blocks.
- Rule 3 (ap not pp): `app/jobs/extract_job_criteria_job.rb` uses `ap` throughout; no `pp` anywhere in the diff.
- Rule 4 (PUT not PATCH): `config/routes.rb:266` adds `resource :ai_job_criteria, only: [:show, :create]` — no update/patch routes.
- Rule 5 (one params method per controller): new controller defines zero params methods (reads `params[:job_id]` directly); no new params methods added elsewhere.
- Rule 6 (no render_many): `ai_job_criteria_controller.rb:7,26` use `render_one`.
- Rule 7 (backend snake_case): `app/serializers/api/v1/job_ai_job_criteria_serializer.rb` attributes are snake_case (`criteria`, `extracted_at`, `status`, `zero_criteria_failure`). The camelCase keys in the `GlobalChannel.broadcast_to` payload (`extract_job_criteria_job.rb:49-54` — `jobId`, `jobTitle`, `zeroCriteriaFailure`, `errorMessage`) match the established codebase convention for ActionCable broadcasts, which bypass the API transform layer and hand-camelCase for the frontend (e.g., `app/models/job_resume_export.rb:303` `jobId`/`jobTitle`, `app/models/organization_ai_credit_purchase.rb:165` `organizationId`/`organizationAiCreditPurchaseId`). Not a violation.
- Rule 8 (bare returns in guard clauses): every added `return` is bare — `job.rb` (`return unless description.present?`, `return if latest_ai_job_criteria&.status_in_progress?`, `return if latest_ai_job_criteria&.status_retrying?`, `return unless new_ai_job_criteria.save`), `extract_job_criteria_job.rb#broadcast_completion` (`return unless requesting_organization_user`, `return unless user`, `return unless ai_job_criteria.status_succeeded? || ai_job_criteria.status_failed?`), `textract_result.rb:70` (`return if job_application.job.zero_criteria_extraction_failure?`), `bulk_generate_ai_summaries_job.rb` (bare `return` inside the `unless result.success?` block). Controller `render_general_errors` + bare `return` follows the permitted controller-response form.
- Rule 10 (no bang methods): app-side diff uses only `update_columns`, checked `save`, and `update`; `create!`/`update!` appear only in `spec/` files (explicitly allowed exception).
- Rule 11 (check save/update return values): the only `save` in the diff is guarded (`return unless new_ai_job_criteria.save`, `app/models/job.rb:735`); the new `update_columns` calls (`bulk_generate_ai_summaries_job.rb:63`, `extract_job_criteria_job.rb:10`) follow the same unchecked-`update_columns` form already used in those files and are not `save`/`update`.
- Rules 2/2a/9 (theme colors, window.logger, undefined): no frontend files in this diff scope.
- File naming: `ai_job_criteria_controller.rb`, `job_ai_job_criteria_serializer.rb` conform to snake_case conventions.
- Coding style (single quotes unless interpolating): app-side strings are single-quoted; spec double quotes appear only with interpolation or embedded single quotes.
