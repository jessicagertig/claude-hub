# API surface: route, controller, serializer, authorization — Pass 2

## Pass 1 corrections in this angle's scope
None were required.

## Fresh scrutiny
- Re-read E.5 in the amended plan: unchanged; no new inconsistencies from the Pass 1 amendment.
- Fresh check: route generation for a singular `resource` nested under `resources :jobs` — `GET/POST /api/v1/jobs/:job_id/ai_job_criteria` with no `:id` segment; `params[:job_id]` is what both actions read ✓ consistent with the controller code.
- Fresh check: `Api::V1::AiJobCriteriaController` naming vs the `controller: 'ai_job_criteria'` option — resolves inside the api/v1 namespace exactly like the routes.rb:189 `ai_credits` precedent ✓.
- Fresh check: the create action calls `job.extract_job_criteria_immediately(requesting_organization_user_id: current_organization_user.id)` — E.3 lands before E.5 in the sequential order, so the kwarg exists when this compiles ✓ (dependency implicitly satisfied; §L's stated chain E.1→E.5 sequential covers it).
- Fresh check: `render_one(job, Api::V1::JobAiJobCriteriaSerializer)` after the no-op in-flight POST — `job.ai_job_criteria` association is not preloaded in the request lifecycle, so `latest_ai_job_criteria` queries fresh and the 200 body reflects the current in-flight row, as E.5.4.1's "body reflects in-flight status" example asserts ✓.
- Fresh check: authz split test feasibility — the P17 harness makes the org user an org_admin; the split test needs an org_user hiring-team member with `hiring_team_ai_credits_control_enabled` off; `JobPolicy#show?` passes via `user.current_organization_user.jobs` membership while `can_use_ai_credits?` fails ✓ constructible with the same helpers.

## Completeness re-sweep (SPEC §5/§9/§12)
All present: route + placement, controller verbatim (Flipper POST-only, blank-description 422, idempotent in-flight no-op, render-the-resource), serializer verbatim + six-state contract, authorization section fully carried, controller/serializer specs covering every SPEC 12 item including draft AND published jobs and the authz split. Nothing dropped.

## Findings
No new issues found.

## Amendments Applied
None.
