# Angle 4 — API surface: route, controller, serializer contract, authorization — Round 3

- Route: `resource :ai_job_criteria, only: [:show, :create], controller: 'ai_job_criteria'` inside the `resources :jobs do` block (routes.rb:266) — singleton + explicit controller per the `ai_credits` precedent; paths `GET/POST /api/v1/jobs/:job_id/ai_job_criteria`.
- Controller: `exists(current_organization.jobs.where(id: params[:job_id]), 'no job found')` + block; authorize AFTER find with explicit queries (`:show?` / `:update_ai_settings?`); `render_one`/`render_general_errors`; no begin blocks; no bang methods; ZERO params methods (no body params — core rule 5 compliant); Flipper `AI_APPLICANT_SUMMARY` on POST only, message copied from the validator; blank-description 422 BEFORE the model call; POST-while-in-flight no-ops via the model guards and returns the current payload. No job-status (draft/published) conditions anywhere in the new endpoint — regenerate-any-state honored and spec-tested on draft AND published.
- `current_organization_user` verified defined on `Api::V1::BaseController:27`.
- Authorization: no new policy methods (job_policy.rb untouched by the diff); `update_ai_settings?` → `can_use_ai_credits?` delegation unchanged; controller spec proves the split (hiring-team org_user with `hiring_team_ai_credits_control_enabled` false: show 200, create 403).
- Serializer contract — walked each of the six states through the ACTUAL code this round, then through the wire: `render_one` uses `root: nil` (application_controller.rb:90) so the payload is the four attributes bare; `apiGet` runs `allKeysToCamel` (structure.js:39-70 — deep, arrays included, KEYS only) so `extracted_at`→`extractedAt`, `zero_criteria_failure`→`zeroCriteriaFailure`, criteria element `source_heading`→`sourceHeading`, while VALUES (`"in_progress"`, `"tier_1"`) pass through untouched. All six rows of the SPEC 5.3 table reproduce from `latest_succeeded_ai_job_criteria`/`latest_ai_job_criteria`/`zero_criteria_extraction_failure?` exactly as specced; `nil` (never `|| false`) for the never-ran row (safe-nav chain, core rule 10).
- No criteria fields leaked into `Api::V1::JobSerializer` (grep clean; file untouched).
- Tests: controller spec covers all six payload states + create side effects (row + enqueue args) + blank-description/Flipper 422s with no row + in_progress AND retrying no-ops + draft/published + authz split; serializer spec covers all-nil and the mixed failed-zero-over-older-success state. All pass in the independent suite run.

## Findings

No issues found.
