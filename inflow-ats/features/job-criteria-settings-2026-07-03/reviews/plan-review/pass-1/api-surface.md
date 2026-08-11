# API surface: route, controller, serializer payload contract, authorization — Pass 1

## Fact Check

| Plan claim | Verified against | Result |
|---|---|---|
| D-6/E.5.1: `resources :jobs do` at routes.rb:224; `resources :bulk_channel_messages, only: [:create]` at :265 | grep -n config/routes.rb | ✓ both exact — D-6 insertion point valid |
| P1: `resource :ai_credits, only: [:show], controller: 'organization_ai_credit_balance'` at routes.rb:189 | sed | ✓ exact — singleton-with-explicit-controller precedent real |
| Summaries route analog `resources :ai_job_application_summaries, only: [:show, :create]` at :314 | sed | ✓ exact |
| Inflection comment at ai_job_criteria.rb:33-37 | Read model | ✓ exact — the `controller:` option sidesteps criteria/criterium |
| E.5.2 helpers: `render_general_errors` :40 (returns 422), `exists` :52-60, `render_one` :89 | Read application_controller.rb | ✓ all exact; `render_general_errors` renders `status: :unprocessable_entity` — R-6's claim verified |
| `current_organization_user` on Api::V1::BaseController:27-29 | Read base controller | ✓ exact (`current_user.current_organization_user`) |
| `JobPolicy#show?` :12-14 (hiring-team-or-admin); `#update_ai_settings?` :24-26 delegating to `AiJobApplicationSummaryPolicy#can_use_ai_credits?` :16-18 | Read both policies | ✓ all exact |
| `can_use_ai_credits?`/`hiring_team_ai_credits_control_enabled?` never read `record` (safe for a Job) | Read ai_job_application_summary_policy.rb:16-18, :30-31 + application_policy.rb `is_org_admin?`/`is_org_user?` :50-56 | ✓ all read only `user` — passing a Job record is safe |
| NO new policy methods | E.5.2 note + C inventory (no policy files listed) | ✓ |
| E.5.2 controller code SPEC-verbatim | Diffed against SPEC 5.2 block | ✓ byte-identical. No begin blocks (core 1), zero params methods (core 5 — no body params), authorize-after-find with explicit queries (pundit_policies.md "authorize AFTER"), Flipper on POST only, blank-description 422 before touching the model, no `hash_id` fallback, numeric path ids (useBulkMessage.ts:23 precedent verified: `` path: `/jobs/${jobId}/bulk_channel_messages` ``) |
| Flipper message copied from validate_ai_summary_generation.rb:26; description-message register mirrors :29 | Read validator | ✓ `'AI summaries are not enabled for this organization.'` byte-identical; :29's register mirrored with "extract criteria" wording |
| GET ungated like `GET /ai_credits` | organization_ai_credit_balance_controller.rb:3-10 | ✓ analog has no Flipper gate |
| POST-while-in-flight no-op via model guards, returns current payload | E.3.1 guards + `render_one` after `extract_job_criteria_immediately` | ✓ idempotent as specced; `job.ai_job_criteria` association not preloaded in the request, so `latest_ai_job_criteria` hits the DB fresh and the response reflects the new/current row |
| E.5.3 serializer SPEC-verbatim | Diffed against SPEC 5.3 block | ✓ byte-identical; no `|| false` (core 10); jsonb raw pass-through (serializers.md §1); model-level computation (§7); attribute name without `?` (§2/§3); serializes the JOB (AdminJobSerializer family precedent — file exists) |
| Six-state payload table carried | Diffed E.5.3 table vs SPEC 5.3 table | ✓ row-identical, including the two "null or [...] (older succeeded)" failure rows |
| No criteria fields added to `Api::V1::JobSerializer` | E.5.3 prohibition + C NOT-touched list | ✓ spec-adjudicated deviation honored |
| No job-status checks (regenerate-any-state) | E.5.2 note + G checklist | ✓ no `published`/`draft`/`status` condition anywhere in E.5 |
| `extracted_at` = latest succeeded row's `updated_at` is valid | extract_criteria.rb succeeded write uses `update` (fires callbacks, touches updated_at — verified :132-142 region); failure writes are `update_columns` | ✓ premise holds |
| New spec files verified absent; serializer spec dir precedent exists | ls | ✓ all three absent; `spec/serializers/api/v1/organization_ai_credit_balance_serializer_spec.rb` present (P18) |

## Completeness (vs SPEC §5, §9, §12)

- SPEC 5.1 route → E.5.1 ✓ (placement, `only:`, `controller:` option)
- SPEC 5.2 controller → E.5.2 ✓ verbatim incl. all four behavior notes
- SPEC 5.3 serializer → E.5.3 ✓ verbatim incl. contract table
- SPEC 9 authorization (show? / update_ai_settings? / org scoping / Flipper-POST-only) → E.5.2 ✓
- SPEC 12 controller spec: six states, create row+enqueue args `[row.id, current_organization_user.id]`, blank-description 422 + NO row, Flipper 422 + no row, in-flight no-op 200 + no new row, draft AND published, authz split (show allowed / create rejected) → E.5.4.1 ✓ every item present
- SPEC 12 serializer spec: mixed state → E.5.4.2 ✓ (plus never-ran case — within the six-state contract, not scope creep)

## Findings

No issues found.

## Amendments Applied

None.
