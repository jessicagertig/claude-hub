# Round 1 — Angle 4: API surface — route, controller, serializer payload contract, authorization

## Verified against source

**Route:**
- Citation line numbers all EXACT: `resource :ai_credits, only: [:show], controller: 'organization_ai_credit_balance'` at routes.rb:189; `resources :jobs do` at :224; `resources :bulk_channel_messages, only: [:create]` at :265; `resources :ai_job_application_summaries, only: [:show, :create]` at :314 ✓.
- Singular `resource :ai_job_criteria, only: [:show, :create], controller: 'ai_job_criteria'` inside the jobs block generates `GET/POST /api/v1/jobs/:job_id/ai_job_criteria` with no `:id` segment — correct for the singleton-payload semantics; explicit `controller:` matches the :189 precedent and sidesteps the criteria/criterium inflection (documented at ai_job_criteria.rb:33-37, verified present) ✓.

**Controller (SPEC 5.2 code re-checked line by line):**
- `exists` + block helper at application_controller.rb:52-60; `render_general_errors` :40; `render_one` :89 ✓.
- `current_organization_user` helper exists (api/v1/base_controller.rb:27) — the POST's `requesting_organization_user_id: current_organization_user.id` is valid ✓.
- Authorize-after-find with explicit query — matches pundit_policies.md and the `jobs_controller.rb` precedent `authorize job, :update_ai_settings? if job_params.key?(:auto_generate_ai_summaries)` (~:162) ✓.
- No begin blocks (core rule 1), no bang methods (rule 11), ZERO params methods (rule 5 — no body params accepted) ✓.
- Flipper gate on POST only; error text identical to validate_ai_summary_generation.rb:26 ✓. Rationale verified: `extract_job_criteria_immediately` has no Flipper gate of its own (job.rb:726-733), unlike `auto_extract_job_criteria`/`extract_job_criteria` (:697, :714) — without the controller gate a non-AI org could trigger paid OpenAI calls ✓.
- Blank-description 422 before the model call; message register mirrors validate_ai_summary_generation.rb:29 ✓.
- POST-while-in-flight: `_immediately`'s new `in_progress`/`retrying` guards no-op; response is the current payload; idempotent ✓.
- `'no job found'` message matches the jobs_controller convention ✓. No hash_id fallback — consistent with all job-nested hooks passing numeric `job.id` ✓.

**Serializer (SPEC 5.3):**
- `Job#latest_succeeded_ai_job_criteria` at job.rb:692 ✓; `latest_ai_job_criteria` at :688 ✓.
- `extracted_at` = succeeded row's `updated_at` — validity re-proven: the ONLY write that produces a succeeded row is the `update` at extract_criteria.rb:132-142 (touches `updated_at`); all failure/progress writes are `update_columns`; a later `'Criteria array is empty'` demotion (score_job_application.rb:43) removes the row from latest-succeeded scope entirely ✓.
- Differently-named-Job-serializer family precedent verified: `admin_job_serializer.rb`, `shallow_job_serializer.rb`, `public_job_serializer.rb` all exist in app/serializers/api/v1/ ✓.
- serializers.md compliance: §1 jsonb pass-through (raw `criteria` array), §2/§3 predicate delegation (`zero_criteria_failure` without `?` delegating to `Job#zero_criteria_extraction_failure?`), §7 computation at model level (all four methods delegate to Job) ✓.
- Documented deviation (status rides the dedicated endpoint, not `Api::V1::JobSerializer`) — spec-adjudicated with rationale; DECISIONS explicitly allows either ("follow the closest AI-scoring analog"); the summaries analog's parent-serializer ride-along exists because summary status is needed on every applicant row, criteria status only in this tab. Rationale holds. Verified the spec does NOT also touch `Api::V1::JobSerializer` (not in section 13) ✓.

**Authorization:**
- `JobPolicy#show?` (job_policy.rb:12-14): hiring-team member (via `user.current_organization_user.jobs`) or org admin ✓.
- `JobPolicy#update_ai_settings?` (:24-26) → `AiJobApplicationSummaryPolicy#can_use_ai_credits?` (ai_job_application_summary_policy.rb:16-18) ✓. Both `can_use_ai_credits?` and `hiring_team_ai_credits_control_enabled?` (:30-32) read only `user` — safe for a Job record ✓. No new policy methods ✓.
- GET ungated by Flipper, like `GET /ai_credits` (organization_ai_credit_balance_controller.rb:4-9 — policy authorize only, no Flipper) ✓.
- **Phase-1 trace note 6 ADJUDICATED:** the tab's FeatureFlipper at JobSetupContainer.tsx (~:374) gates the NAV ITEM only; the `/ai` Route render (~:484-489) is NOT flipper-gated, so a direct URL renders the tab for a non-AI org. The story is still coherent: GET returns the all-null payload (never-ran EmptyState renders), and POST is Flipper-gated in the controller (422 → error toast). No section-level gating required; note the SPEC itself never claims the tab is fully gated (only the angles file's phrasing implied it), so no spec text change needed.

**Regenerate-any-state:** no `published`/`draft`/Job-status conditions anywhere in the spec'd controller/model/serializer code ✓ (DECISIONS requirement honored).

**Tests:** new controller spec + serializer spec targets verified not to exist yet (`spec/controllers/api/v1/` has no ai_job_criteria_controller_spec.rb; `spec/serializers/api/v1/` has only organization_ai_credit_balance_serializer_spec.rb — the cited dir precedent) ✓. Auth-split test premise verified against the two policies ✓.

## Taken on trust from the spec
Nothing load-bearing; all citations re-verified.

## Findings

- F1 [MED] SPEC 5.3 payload-example table, "First extraction running" row: `zeroCriteriaFailure` listed as "null/false". Impossible — when `status` is non-null a latest row exists, so `latest_ai_job_criteria&.zero_criteria_failure?` returns a boolean, never nil. The table is the load-bearing contract the controller/serializer specs and the frontend six-state derivation are written against; an implementer asserting `null` would write a failing (or worse, wrong) test. Fix: cell → `false`.

## Amendments Applied

1. SPEC 5.3 table "First extraction running" row: `zeroCriteriaFailure` cell corrected from "null/false" to "false" (F1). Patched table re-read and verified.
