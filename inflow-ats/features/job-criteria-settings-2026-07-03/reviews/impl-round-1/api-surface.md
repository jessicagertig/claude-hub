# Angle 4 — API surface: route, controller, serializer payload contract, authorization — Round 1

## Route

`config/routes.rb:266`: `resource :ai_job_criteria, only: [:show, :create], controller: 'ai_job_criteria'` — inside the `resources :jobs do` block, immediately after `resources :bulk_channel_messages, only: [:create]` (plan D-6 insertion point exact). Singleton `resource` + explicit `controller:` matches the `ai_credits` precedent (routes.rb:189); sidesteps the criteria/criterium inflection. Generates `GET/POST /api/v1/jobs/:job_id/ai_job_criteria` (controller spec exercises both).

## Controller — `app/controllers/api/v1/ai_job_criteria_controller.rb`

SPEC §5.2-verbatim. Verified against helpers and analogs:
- `exists(current_organization.jobs.where(id: params[:job_id]), 'no job found')` + block — same shape as `ai_job_application_summaries_controller.rb:5`; `exists` yields `obj.first` (application_controller.rb:52-60). Org scoping matches every job-nested controller.
- `authorize job, :show?` / `authorize job, :update_ai_settings?` AFTER find, explicit policy queries, NO new policy methods (policies not in diff). `JobPolicy#show?` = hiring-team-or-admin (job_policy.rb:12-14). `update_ai_settings?` → `AiJobApplicationSummaryPolicy.new(user, record).can_use_ai_credits?` — re-verified `can_use_ai_credits?` and `hiring_team_ai_credits_control_enabled?` read only `user`, never `record`; safe for a Job.
- Flipper `AI_APPLICANT_SUMMARY` gate on POST only, message copied from validate_ai_summary_generation.rb; GET deliberately ungated (ai_credits precedent; tab behind FeatureFlipper).
- Blank-description 422 BEFORE calling the model, exact drafted message. `render_general_errors` renders 422 (application_controller.rb:40-42) — controller spec's `:unprocessable_entity` expectations pass.
- POST-while-in-flight no-ops via the model guards and returns the current payload — asserted for both `in_progress` and `retrying` (200, no new row, body reflects in-flight status).
- No begin blocks, no bang methods, zero params methods (no body params — core rule 5 compliant), no `render_many`. NO job-status checks anywhere (grepped controller + model diff for `published`/`draft`/Job-status conditions — none); draft AND published POST tests pass.

## Serializer — `app/serializers/api/v1/job_ai_job_criteria_serializer.rb`

SPEC §5.3-verbatim. Contract verified:
- `criteria`/`extracted_at` from `latest_succeeded_ai_job_criteria` (`&.criteria` / `&.updated_at`); `extracted_at` validity holds — the only succeeded-status write is `update` (extract_criteria.rb:132-142, touches `updated_at`); failure writes are `update_columns` and never produce succeeded rows; succeeded rows always have ≥1 criterion (extract_criteria.rb:121-124 guard), so criteria-present ⟺ extracted_at-present.
- `status` from `latest_ai_job_criteria&.status` (enum string, nil when no rows). `zero_criteria_failure` via `object.zero_criteria_extraction_failure?` — nil/true/false through safe navigation, NO `|| false` (core rule 10 / pipeline rule 13).
- Computation delegated to Job model methods (serializers.md §7); jsonb passed through raw (§1); serializes the JOB per the differently-named-Job-serializer family precedent. `Api::V1::JobSerializer` NOT touched (not in the diff) — the spec-adjudicated dedicated-endpoint deviation held; the implemented UI consumes criteria status only in the settings tab, so the deviation's premise still holds.
- Six-state payload table verified end-to-end by the controller spec (all six `#show` states) and serializer spec (mixed state + never-ran). All pass on committed code.

## Authorization tests

Authz split covered behaviorally: hiring-team `org_user` with `hiring_team_ai_credits_control_enabled => false` — `show` 200, `create` 403. Passing.

## Findings

No issues found.
