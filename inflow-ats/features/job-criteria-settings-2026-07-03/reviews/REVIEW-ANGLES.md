# REVIEW-ANGLES — Job criteria in Plato AI settings

Consumed by BOTH the spec review (Phase 2) and the post-implementation review (Phase 6). All file:line citations are from the worktree at `/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings` (branch `job-criteria-settings`, HEAD `05c9513ef`), verified 2026-07-03 by the Phase 1 agent. Line numbers will drift once implementation lands — re-verify before citing in findings.

Binding inputs for every reviewer: `SPEC.md`, `DECISIONS.md` (wins over design files), `ORCHESTRATION-LOG.md` "Decisions made as human-gate proxy" (flags 1-3, 5-7 already RULED — do not re-litigate the ruling itself; DO verify the implementation honors the ruling), `~/claude-hub/inflow-ats/CLAUDE.md` pipeline rules, `cursor_rules/core_critical_rules.md`.

---

## 1. Subsystems touched

**Backend — new:** `app/controllers/api/v1/ai_job_criteria_controller.rb`, `app/serializers/api/v1/job_ai_job_criteria_serializer.rb`, route `resource :ai_job_criteria` nested in `resources :jobs do` (config/routes.rb:224 block).

**Backend — modified:** `app/models/job.rb` (gating change at 726-743, new `zero_criteria_extraction_failure?` near 688), `app/models/ai_job_criteria.rb` (constants + `zero_criteria_failure?`), `app/models/textract_result.rb` (guard in `generate_ai_summary_with_credit_flow`, :61-91), `app/jobs/extract_job_criteria_job.rb` (signature + 3 broadcast sites), `app/jobs/bulk_generate_ai_summaries_job.rb` (claim-row fix at `each_iteration` :60), `app/interactors/validate_ai_summary_generation.rb` (:29 area), `app/interactors/validate_auto_ai_summary_generation.rb` (:18 area), `app/interactors/queue_bulk_ai_summary_jobs.rb` (new optional `job` input), `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb` (pass `job: @job`, both actions), `app/services/ai_job_application_action/scoring/extract_criteria.rb` (:62, :122 constant substitution), `app/services/ai_job_application_action/scoring/score_job_application.rb` (:43 constant substitution), `config/routes.rb`.

**Frontend — new:** `app/javascript/shared/queryHooks/useAiJobCriteria.ts`, `app/javascript/ats/src/views/jobApplications/jobSetup/JobCriteriaViewModal.tsx`, `app/javascript/ats/src/views/jobApplications/jobSetup/RegenerateJobCriteriaConfirmModal.tsx`, conditionally `jobSetup/components/JobCriteriaSection.tsx` (>400-line extraction; `jobSetup/components/` dir exists).

**Frontend — modified:** `app/javascript/ats/src/views/jobApplications/jobSetup/JobSetupAiSettings.tsx` (currently 83 lines — section, sidebar, modal wiring all land here first), `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` (new case after :248), `app/javascript/shared/types/aiSummaryWebsocketPayloads.ts`.

**Policies:** none new — `JobPolicy#show?` (job_policy.rb:12-14) and `JobPolicy#update_ai_settings?` (:24-26 → `AiJobApplicationSummaryPolicy#can_use_ai_credits?`, ai_job_application_summary_policy.rb:16-18). Verified `can_use_ai_credits?` and `hiring_team_ai_credits_control_enabled?` read only `user`, never `record`, so passing a Job record is safe.

**Migrations:** none (spec section 3 — verified `ai_job_criteria` table already has everything needed).

**Tests — new:** `spec/controllers/api/v1/ai_job_criteria_controller_spec.rb`, `spec/interactors/validate_ai_summary_generation_spec.rb`, `spec/serializers/api/v1/job_ai_job_criteria_serializer_spec.rb`. Verified none of these exist today (harness "check before create" rule satisfied — `spec/interactors/` has `validate_auto_ai_summary_generation_spec.rb` but NOT `validate_ai_summary_generation_spec.rb`).

**Tests — modified (all 8 verified to exist):** `spec/models/job_criteria_lifecycle_spec.rb`, `spec/models/ai_job_criteria_spec.rb`, `spec/jobs/extract_job_criteria_job_spec.rb`, `spec/interactors/validate_auto_ai_summary_generation_spec.rb`, `spec/interactors/queue_bulk_ai_summary_jobs_spec.rb`, `spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb`, `spec/models/textract_result_ai_trigger_spec.rb`, `spec/jobs/bulk_generate_ai_summaries_job_spec.rb`.

---

## 2. Full-stack analog (primary blueprint)

**The manual single AI-summary generation flow.** This is the one end-to-end pipeline in the codebase that does exactly what this feature does — user-triggered async AI work with a fetchable status payload and a backend-triggered WebSocket completion toast:

| Layer | Analog file |
|---|---|
| Confirm modal owning its mutation | `app/javascript/ats/src/views/jobApplications/BulkGenerateAiSummariesConfirmModal.tsx` (`useBulkGenerateAiSummaries` at :43, loading+disabled on primary, `dismissModalWithAnimation(() => onCancel)` at :90, error toast :92-98 modal stays open) |
| Query/mutation hook | `app/javascript/shared/queryHooks/useAiJobApplicationSummary.ts` (query key `["aiJobApplicationSummary", id]`, `enabled:` guard, hook-level `invalidateQueries` in `onSuccess`) |
| Route | `resources :ai_job_application_summaries, only: [:show, :create]` (routes.rb:314); singleton-with-explicit-controller precedent `resource :ai_credits, only: [:show], controller: 'organization_ai_credit_balance'` (routes.rb:189) |
| Controller | `app/controllers/api/v1/ai_job_application_summaries_controller.rb` (`exists` + block, authorize-after-find, validator fail → `render_general_errors([result.error])`, create renders the resource) |
| Validator interactor | `app/interactors/validate_ai_summary_generation.rb` (ordered `context.fail!` chain :24-29) |
| Async job with completion broadcast | `app/jobs/generate_ai_job_application_summary_job.rb` — THE broadcast analog: kwargs `perform(textract_result_id:, requesting_organization_user_id: nil)` (:24), broadcast at end of perform gated on requesting id (:34), in `retry_on` exhaustion block reading `job.arguments.first[:key]` (:13-22), in StandardError rescue (:39-45), private `broadcast_completion` with terminal-status guard (:50-80), auto path (nil id) never broadcasts |
| Channel | `app/channels/global_channel.rb` |
| Frontend handler | `WebsocketGlobalChannelHandler.tsx` `AI_SUMMARY_COMPLETE` case (:216-234) — toast + query invalidations |
| Payload types | `app/javascript/shared/types/aiSummaryWebsocketPayloads.ts` |

**Priority rule:** where this analog does something differently from general convention, the new feature follows the ANALOG. Documented spec deviations from the analog (dedicated-endpoint status instead of parent-serializer status ride-along, SPEC 5.1; positional vs kwargs job args, SPEC flag 4 — DEFERRED, see Angle 3) must each be explicitly adjudicated by the spec review, not waved through.

Secondary analogs for specific layers: `Api::V1::OrganizationAiCreditBalanceController` (singleton show), `RunPlatoAddDescriptionModal.tsx` (CenterModal + statement box + `/jobs/${jobId}/setup/description` link), `OrganizationAiUsage.tsx` (settings-view `LoadingIndicator` treatment :29-31, router-prop navigation :17-19), `AccountTeam.tsx` :441-477/:515-552 (sidebar aside register), `ChannelMessageListItem.tsx` :52-64 (openModal/removeModal), `PlatoMark.tsx` (`PlatoChip`, gradient + inset ring built in, `radius` prop verified :60-66).

---

## 3. Review angles

### Angle 1 — Zero-criteria review guard: entry-point completeness and predicate semantics

**What this covers:** The SPEC 6.1 entry-point table must be INDEPENDENTLY re-traced, not trusted. The Phase 1 trace confirms it is complete today — every production path that creates/starts an AI summary review is one of: `Api::V1::AiJobApplicationSummariesController#create` (:17 `CreateAiSummaryGeneration.call`), `BulkAiJobApplicationSummariesController#create`/`#all_stages` → `QueueBulkAiSummaryJobs` → `BulkGenerateAiSummariesJob#each_iteration` (:59 validate, :74 create, :80 funnel), `JobApplication#enqueue_new_job_application` :175 → `auto_generate_ai_summary_if_enabled` :183-188, `job_applications_controller.rb:118` (resume upload), `TextractResult#queue_ai_summary_job` :116-146 (both branches), `AiJobCriteria#resume_waiting_summaries` :21-30, plus the shared funnel `TextractResult#generate_ai_summary_with_credit_flow` :61-91 and the direct enqueue inside `CreateAiSummaryGeneration` :71 (behind a validator on every calling path — verify this claim). Cypress controllers create no summaries (verified). Re-run the trace greps: `GenerateAiJobApplicationSummaryJob.perform_later|generate_ai_summary_with_credit_flow|CreateAiSummaryGeneration.call|CreateBulkAiSummaryGeneration.call|auto_generate_ai_summary_if_enabled|QueueBulkAiSummaryJobs.call|Orchestrate.new` over `app/ lib/`.

Then verify guard placement and semantics:
- All four guard sites (both validators, `QueueBulkAiSummaryJobs`, the `TextractResult` funnel) present, with the funnel guard ordered BEFORE `extract_job_criteria_if_needed` (currently textract_result.rb:70) so a blocked review does not re-trigger extraction — the spec's ordering rationale is real, check the diff enforces it.
- `AiJobCriteria#zero_criteria_failure?` = `status_failed? && ZERO_CRITERIA_ERROR_MESSAGES.include?(error_message)`. The three messages must EXACTLY match the writer strings: `'No criteria sections found in job description'` (extract_criteria.rb:62), `'No criteria extracted from job description'` (:122), `'Criteria array is empty'` (score_job_application.rb:43). All three writers switch to the constants; a typo or a missed writer silently breaks the guard. Note the writers use `update_columns` — no callbacks, no `updated_at` touch.
- `Job#zero_criteria_extraction_failure?` reads the LATEST row (any status), deliberately NOT latest-terminal — a new pending/in-flight extraction makes the predicate false and reviews start and wait via `awaiting_job_criteria` (score_job_application.rb:21-30, ai_job_criteria.rb:21-30). Reviewers must not "fix" this to latest-terminal.
- Guard error message copy is identical at the ValidateAiSummaryGeneration and QueueBulkAiSummaryJobs sites; ValidateAutoAiSummaryGeneration declines silently by existing convention.
- NOT placed in `Orchestrate`/`ScoreJobApplication`/`CreateAiSummaryGeneration`/`CreateBulkAiSummaryGeneration` — verify the implementation didn't add extras there (scope creep, rule 10).
- Interaction claims of SPEC 6.4: summaries already `awaiting_job_criteria` when zero-criteria lands stay waiting (resume fires only on `succeeded`) — existing behavior, OUT of scope; flag any diff touching `resume_waiting_summaries`.

**Files:** `app/interactors/validate_ai_summary_generation.rb`, `app/interactors/validate_auto_ai_summary_generation.rb`, `app/interactors/queue_bulk_ai_summary_jobs.rb`, `app/models/textract_result.rb`, `app/models/ai_job_criteria.rb`, `app/models/job.rb`, `app/services/ai_job_application_action/scoring/extract_criteria.rb`, `app/services/ai_job_application_action/scoring/score_job_application.rb`, `app/models/job_application.rb` (read-only context), `app/controllers/api/v1/job_applications_controller.rb` (read-only context).
**Analog files:** rule 16 precedent — `FindOrCreateAiJobApplicationSummaryStatus` called from the unconditional entry points; the existing `context.fail!` chains in both validators.
**Convention context:** `cursor_rules/backend/interactors/interactor_patterns_and_structure.md`, `interactor_usage_and_guidelines.md`, `backend/_base.md`, `core_critical_rules.md` rule 8 (bare guards).

### Angle 2 — Bulk claim-row lifecycle fix and QueueBulkAiSummaryJobs signature extension (flags 6 and 7)

**What this covers:** The one shared-infrastructure change (ORCHESTRATION-LOG flag 6, APPROVED but ⚠️ flagged for Jessica's morning review — treat as reviewed scope, verify it stays MINIMAL). Phase 1 verified the spec's premise against the live job: `each_iteration` `return unless result.success?` (bulk_generate_ai_summaries_job.rb:60) leaves the `BulkAiSummaryJobApplication` row `:processing`; nothing else updates it (`update_remaining_statuses_to_failed` fires only on `discard_on`/`retry_on` exhaustion, :12-21, 212-219); `QueueBulkAiSummaryJobs` :45-49 excludes `:processing` rows as already-claimed → permanently un-queueable candidate. The fix must be EXACTLY: mark that row `:failed` and return. Check:
- `update_columns` matches sibling row-writes (:54, :66, :86) and is not inside a transaction (pipeline rule 25).
- `on_complete` counting still correct: `failed = size - done - deferred` (:111) — rows now `:failed` count identically; completion toast still fires for an all-failed batch (`notify_failure` when `succeeded.zero? && failed.positive?`, :117-119).
- No OTHER behavior added to the job (rules 10/20/23 — no new statuses, no enum changes, no rewrites of `notify_*`).
- `QueueBulkAiSummaryJobs` gains context input `job` (flag 7): safe-navigation `context.job&.zero_criteria_extraction_failure?`, existing callers without `job:` unaffected; fail placed after the credits fail (:18). Bulk controller passes `job: @job` in BOTH `create` (:13-17) and `all_stages` (:37-43) — `@job` already exists at :9/:33.
- Spec updates: `queue_bulk_ai_summary_jobs_spec.rb` new zero-criteria context + assertion that job-less calls still pass; `bulk_ai_job_application_summaries_controller_spec.rb` `hash_including` expectation (~:72-77) updated for both actions + 422 path; `bulk_generate_ai_summaries_job_spec.rb` validation-failure iteration → row `:failed`, completion notification still fires.

**Files:** `app/jobs/bulk_generate_ai_summaries_job.rb`, `app/interactors/queue_bulk_ai_summary_jobs.rb`, `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb`, the three spec files above.
**Analog files:** the job's own sibling `update_columns` row-writes (:54, :66, :86) — the fix must look like them.
**Convention context:** `cursor_rules/backend/background_jobs.md`, `backend/interactors/*`, pipeline rules 10, 20, 23, 25.

### Angle 3 — Job gating change, ExtractJobCriteriaJob signature, and the WebSocket broadcast lifecycle

**What this covers:** Backend half of the async-regenerate story.

*Gating change (SPEC 4.1):* current worktree state verified — `job.rb:726-743` still has the OLD form (guards in `_if_needed`). The replacement must match DECISIONS verbatim EXCEPT the approved `requesting_organization_user_id:` kwarg (flag 1, APPROVED). `_immediately` gains `in_progress`/`retrying` guards and the kwarg; `_if_needed` keeps only the `succeeded` guard. Verify: the four `ExtractJobCriteriaJob.perform_later` enqueue sites (`auto_extract_job_criteria` :707/:709, `extract_job_criteria` :723, `_immediately` :732) — only `_immediately`'s passes the new arg; `auto_extract_job_criteria`/`extract_job_criteria` keep their `status_pending?` guard and Flipper gate untouched (they deliberately differ; do not "harmonize"). The documented pending-row double-POST consequence (SPEC 4.1) is per DECISIONS — do not add a pending guard.

*⚠️ MANDATORY SPEC-REVIEW ITEM — FLAG 4, DEFERRED BY THE ORCHESTRATOR (this reviewer cannot skip it):* SPEC section 7 proposes `def perform(ai_job_criteria_id, requesting_organization_user_id = nil)` — optional POSITIONAL. Open `app/jobs/generate_ai_job_application_summary_job.rb` and compare: the analog is KWARGS — `def perform(textract_result_id:, requesting_organization_user_id: nil)` (:24), exhaustion block reads `job.arguments.first[:textract_result_id]` / `job.arguments.first[:requesting_organization_user_id]` (:16, :20). The spec's positional form reads `job.arguments.first` / `job.arguments.second`. The spec's justification is minimal churn at four enqueue sites + existing spec (`extract_job_criteria_job_spec.rb` calls `perform_now(id)` positionally throughout). Per the analog-deviation rule, ALIGN THE SPEC WITH THE ANALOG (kwargs) unless technically blocked; note that in-flight Sidekiq jobs enqueued pre-deploy with the old positional single arg is the strongest technical consideration on each side (kwargs conversion breaks queued `perform_later(id)` payloads at deploy time; optional positional does not). Record the evidence and the decision in the round artifact.

*Broadcast lifecycle — all THREE sites, mirroring the analog structurally (rule 14):*
1. End of `perform`, gated `if requesting_organization_user_id` — unreachable when `CustomErrorAiSummary` propagates (ExtractCriteria sets `:retrying` then re-raises, extract_criteria.rb:143-147; job re-raises :19-22) so no broadcast mid-retry, matching the analog.
2. `retry_on` exhaustion block (extract_job_criteria_job.rb:5-10) — after the existing `update_columns(status: :failed, ...)`; reads args off `job.arguments`; note ActiveJob instance-execs this block so the private helper is callable (the analog does exactly this at :20).
3. StandardError rescue (:23-28) — after the failure write.
- Helper: `OrganizationUser` lookup → `user` → `ai_job_criteria.reload` → terminal-status guard (`status_succeeded? || status_failed?`) → payload (`status`, `jobId`, `jobTitle`, `zeroCriteriaFailure`, conditional `errorMessage`) → `GlobalChannel.broadcast_to(user, action: 'JOB_CRITERIA_EXTRACTION_COMPLETE', ...)`. Diff structurally against the analog's `broadcast_completion` :50-80 — same guard order, same conditional errorMessage shape, camelCase payload keys.
- Auto-path nil id → NEVER broadcasts (all four model-side enqueue paths pass no requesting id). Failure broadcasts are flag 3, APPROVED — do not re-open, but verify the JSON::ParserError path (extract_criteria.rb:148-151: failure write WITHOUT re-raise, perform continues) results in a failed broadcast, which is the behavior the approval depends on.
- `reload` matters: failure writes use `update_columns` on a different in-memory instance (inside ExtractCriteria); verify the implementation actually reloads before the terminal check.

*Tests:* `extract_job_criteria_job_spec.rb` additions must be behavioral (rule 26): broadcast asserted via `GlobalChannel` receiving `broadcast_to` with the action + status; `CustomErrorAiSummary` → `have_enqueued_job` and NO broadcast; no requesting user → no broadcast. `job_criteria_lifecycle_spec.rb` gating additions per SPEC 12.

**Files:** `app/models/job.rb`, `app/jobs/extract_job_criteria_job.rb`, `app/channels/global_channel.rb` (read-only), `app/services/ai_job_application_action/scoring/extract_criteria.rb` (read-only failure-writer context), `spec/jobs/extract_job_criteria_job_spec.rb`, `spec/models/job_criteria_lifecycle_spec.rb`.
**Analog files:** `app/jobs/generate_ai_job_application_summary_job.rb` (whole file), `app/models/textract_result.rb` `broadcast_ai_summary_failed` :148+ (secondary broadcast shape).
**Convention context:** `cursor_rules/backend/background_jobs.md`, `backend/_base.md`, `core_critical_rules.md` rules 8/11/12, pipeline rules 14, 26.

### Angle 4 — API surface: route, controller, serializer payload contract, authorization

**What this covers:**
- Route: singleton `resource :ai_job_criteria, only: [:show, :create], controller: 'ai_job_criteria'` INSIDE the `resources :jobs do` block (:224-268) — verify placement inside the block, generated paths `GET/POST /api/v1/jobs/:job_id/ai_job_criteria`, and that the `controller:` option matches the routes.rb:189 `ai_credits` precedent (also sidesteps the criteria/criterium inflection documented at ai_job_criteria.rb:33-37).
- Controller vs analogs: `exists(current_organization.jobs.where(id: params[:job_id]), ...)` + block, authorize AFTER find with explicit query (`:show?` / `:update_ai_settings?`), `render_one`/`render_general_errors` (application_controller.rb:40/:52/:89), no begin blocks, no bang methods, zero params methods (no body params — compliant with core rule 5), PUT-vs-PATCH n/a. Flipper `AI_APPLICANT_SUMMARY` gate on POST only, message copied from validate_ai_summary_generation.rb:26; blank-description 422 BEFORE calling the model (message register mirrors :29); POST-while-in-flight is a no-op returning the current payload (idempotent). GET deliberately ungated (analog: `GET /ai_credits` is ungated; the whole Plato AI settings tab is behind `FeatureFlipper feature="AI_APPLICANT_SUMMARY"` — JobSetupContainer.tsx:374 — so the UI never shows the section to non-AI orgs).
- Authorization: `show?` = hiring-team-or-admin (job_policy.rb:12-14); `update_ai_settings?` delegates to `AiJobApplicationSummaryPolicy#can_use_ai_credits?` — the exact gate `jobs_controller.rb:163` uses for AI-settings changes. NO new policy methods (verify none added). `can_use_ai_credits?`/`hiring_team_ai_credits_control_enabled?` never touch `record` (verified safe for a Job).
- Serializer payload contract — THE contract the frontend six-state table derives from (see Angle 5): `criteria` from `latest_succeeded_ai_job_criteria&.criteria` (job.rb:692), `extracted_at` from that row's `updated_at` (valid: the ONLY succeeded-status write is `update`, extract_criteria.rb:132-142, which touches `updated_at`; failure writes are `update_columns` and never produce succeeded rows), `status` from `latest_ai_job_criteria&.status` (enum string, nil when no rows), `zero_criteria_failure` via safe-nav (nil/true/false — NO `|| false`, core rule 10). Computation delegated to Job model methods (serializers.md §7); jsonb passed through raw (§1); no id/object dumping (DECISIONS: only what the UI needs). Serializes the JOB — differently-named-Job-serializer family precedent (`AdminJobSerializer` etc.). The documented deviation from the summaries analog (status rides the dedicated endpoint, not the parent serializer) is spec-adjudicated with rationale — verify the implementation didn't ALSO add criteria fields to `Api::V1::JobSerializer`.
- Regenerate-any-job-state requirement (DECISIONS): NO job-status checks anywhere in the new endpoint — grep the controller/model diff for `published`/`draft`/`status` conditions on Job.
- Tests: controller spec covers all six payload states, blank-description 422 + no row, Flipper 422 + no row, in-flight no-op 200 + no new row, draft AND published jobs, authz split (show allowed for hiring-team member, create rejected without AI-credits control). Serializer spec covers the mixed state (failed-zero latest over older succeeded).

**Files:** `config/routes.rb`, `app/controllers/api/v1/ai_job_criteria_controller.rb` (new), `app/serializers/api/v1/job_ai_job_criteria_serializer.rb` (new), `app/policies/job_policy.rb` (read-only), `app/policies/ai_job_application_summary_policy.rb` (read-only), `app/controllers/application_controller.rb` (read-only helpers), `spec/controllers/api/v1/ai_job_criteria_controller_spec.rb`, `spec/serializers/api/v1/job_ai_job_criteria_serializer_spec.rb`.
**Analog files:** `ai_job_application_summaries_controller.rb`, `organization_ai_credit_balance_controller.rb` + serializer + spec, `bulk_ai_job_application_summaries_controller_spec.rb` :25-37 (auth-stub harness).
**Convention context:** `cursor_rules/backend/controllers/controller_patterns_and_crud.md`, `controller_error_handling.md`, `pundit_policies.md`, `backend/serializers.md`, `core_critical_rules.md` rules 1, 5, 6, 8, 10, 11, 12.

### Angle 5 — Frontend display-state derivation, loading states, and the payload contract

**What this covers:** The six-state table (SPEC 8.2) is the frontend's single source of truth and must match the serializer contract from Angle 4 row for row (never-ran / first-run in-flight / succeeded / regenerating-over-success / zero-criteria-failed / other-failed). Specifically:
- Precedence order implemented exactly: isLoading → in-flight statuses (layered over underlying content) → failed+zero → failed-other → criteria-present card → never-ran. Flag 5 (failed latest hides older succeeded card) is APPROVED — verify implemented, not "improved."
- **Loading states are a named recent failure mode (DECISIONS):** (a) initial fetch renders `LoadingIndicator label="Loading..."` inside the section per `OrganizationAiUsage.tsx:29-31`; (b) Generate/Regenerate button `loading` is driven by BACKEND status (`pending`/`in_progress`/`retrying` from the payload), not just mutation state, and therefore survives reload. Verify the `isInFlight` derivation covers the just-POSTed-and-refetching window.
- `status` and `tier` values stay snake_case (`"in_progress"`, `"tier_1"`) — Ruby enum-value exception to core rule 7; keys camelCase (`extractedAt`, `zeroCriteriaFailure`). The `AiJobCriteriaPayload`/`AiJobCriterion` interfaces must match the serializer exactly.
- No fabricated fallbacks (core rule 10 / pipeline rule 13): no `criteria || []`, no `|| 0`, no `??` (frontend/_base.md §1). Explicit conditionals for null criteria.
- **EmptyState has NO action/button prop** (verified: `EmptyState.tsx` props are `title`/`message`/`icon`/`borderless`/`roomy` only, :7-13). The spec's "action row" under empty states must render OUTSIDE the EmptyState component. The spec does not say this explicitly — the plan must place the buttons; reviewers verify the three empty states use standard variant (no `roomy`, no `borderless`) and the action row lives in the section, not hacked into EmptyState.
- Hook file: query key `["aiJobCriteria", jobId]`, `enabled: jobId != undefined`, mutation with hook-level `invalidateQueries` in `onSuccess` — mirror `useAiJobApplicationSummary.ts` / `useBulkGenerateAiSummaries.ts`; interfaces inline; numeric `job.id` in paths.
- Card/section content: `PlatoChip size={36} radius={18}` (PlatoMark.tsx:60-66 — gradient + inset ring built in, do NOT re-style), `distanceInWords(extractedAt)` (time.ts:89-91, adds "ago"), module-level `TIERS` constant filtering on stored `tier_1`-form values (extract_criteria.rb:110-113 — NOT the design bundle's `tier1` keys), Bonus row only when bonus criteria exist, tabular figures, FormSection `intro` prop (verified: `FormSection/index.js` has `intro`, renders `<p>{intro}</p>`) with the lifecycle-explaining copy + description link via `props.history.push` to `/jobs/${passedJob.id}/setup/description` (route form verified at RunPlatoAddDescriptionModal.tsx:32).
- Sidebar glossary via `SettingsContainer` `sidebar` prop (verified :10/:72 — note sidebar is `display: none` below `lg` breakpoint, :196-208; the AccountTeam register is the styling analog, :441-477/:515-552). NOTE: `JobSetupAiSettings` currently does NOT pass `sidebar` and the container renders `hasSidebar` layout differences (Content 50vw at lg, :116-126) — adding the sidebar changes the existing form's layout width; verify the Plato reviews section still renders correctly.
- Existing behavior preserved: dirty tracking, bottom-bar Save, `useUpdateJob` flow (JobSetupAiSettings.tsx:15-80) untouched.
- Component size: if the section pushes `JobSetupAiSettings.tsx` past ~400 lines, extraction to `jobSetup/components/JobCriteriaSection.tsx` per component_size_and_extraction.md (dir exists — verified).
- Styled components: separate components per visual variant (pipeline rule 12 — e.g., tier rows, count-rail rows; NO boolean variant props forwarded to DOM), theme colors only from `theme.ts` (core rule 2), Emotion text utilities standalone (pipeline rule 1 — `${t.text.sm};` never `font-size: ${t.text.sm};`), double quotes.

**Files:** `JobSetupAiSettings.tsx`, `useAiJobCriteria.ts` (new), conditional `components/JobCriteriaSection.tsx`, `EmptyState.tsx` (read-only), `SettingsContainer.tsx` (read-only), `FormSection/index.js` (read-only), `PlatoMark.tsx` (read-only), `time.ts` (read-only).
**Analog files:** `OrganizationAiUsage.tsx`, `AccountTeam.tsx`, `useAiJobApplicationSummary.ts`, `useBulkGenerateAiSummaries.ts`, `PlatoTab.tsx` (existing PlatoChip consumer).
**Convention context:** `cursor_rules/frontend/core_critical_rules.md`, `frontend/_base.md`, `frontend/react_query/react_query_queries.md`, `react_query_mutations_and_cache.md`, `frontend/components/component_size_and_extraction.md`, `component_architecture.md`, `frontend/ui_styling.md`, `frontend/react_hooks.md`, `frontend/boolean_variables_and_naming.md`, pipeline rules 1, 11, 12, 13.

### Angle 6 — Modals: ModalContext frozen-props correctness (rule 22) for BOTH new modals

**What this covers:** `ModalContext` stores the element passed to `openModal()` as frozen state (`setModal(modal)`, ModalContext.tsx:24-34) — every prop is captured at call time forever.
- **RegenerateJobCriteriaConfirmModal:** MUST own its mutation internally (`useRegenerateAiJobCriteria()` inside the modal), exactly like `BulkGenerateAiSummariesConfirmModal` owns `useBulkGenerateAiSummaries` (:43). Internal hook state is live, so `loading={isLoading}` + `disabled={isLoading}` on the primary button work and block double-submits — BOTH behavioral props required (pipeline rule 11; the analog passes both). Reject any design where the parent passes `isLoading`/mutation callbacks as props (that is the exact ai-billing-overhaul H1 failure). On success: `dismissModalWithAnimation(() => onCancel)` (analog :90), NO success toast (completion arrives over WebSocket; section button enters loading via the invalidated payload). On error: warning toast `error?.data?.errors?.general?.[0] || fallback`, `delay: 10000`, modal STAYS open (analog :92-98). `CenterModal` requires `headerTitleText` (CenterModal.tsx:12-24 — verified required prop); statement box mirrors `Styled.Statement` (RunPlatoAddDescriptionModal.tsx:63-83) with `refresh-cw` icon.
- **JobCriteriaViewModal:** display-only, props `{ criteria, onCancel }` — no fetching inside. This IS a frozen-prop consumer: if a regeneration completes while the slide-over is open, its content is stale until closed. Acceptable for a read-only viewer, but the review must consciously accept it (rule 22 pattern 2 alternative — reading live query state inside the modal — was not specced). Verify nothing interactive depends on the frozen criteria. `FullModal` with CUSTOM header: omit `headerTitleText` so the built-in Dismiss header does not render (FullModal.tsx:104-111 — verified conditional), custom sticky h2 + X icon button calling `onCancel`, Esc + backdrop close come free via `onCancel`.
- Section wiring: `openModal(<JobCriteriaViewModal ... onCancel={removeModal} />)` / `openModal(<RegenerateJobCriteriaConfirmModal jobId={...} onCancel={removeModal} />)` per ChannelMessageListItem.tsx:52-64. View button rendered ONLY in the criteria-present state.
- ModalContext/ToastContext files themselves are never edited (core rules "Files You Should Never Edit").

**Files:** `RegenerateJobCriteriaConfirmModal.tsx` (new), `JobCriteriaViewModal.tsx` (new), `JobSetupAiSettings.tsx` (wiring), `ModalContext.tsx` (read-only), `FullModal.tsx` (read-only), `CenterModal.tsx` (read-only).
**Analog files:** `BulkGenerateAiSummariesConfirmModal.tsx`, `RunPlatoAddDescriptionModal.tsx`, `ChannelMessageListItem.tsx`.
**Convention context:** `cursor_rules/frontend/modals/modal_form_and_confirmation_patterns.md`, `modal_state_errors_and_loading.md`, `frontend/contexts/context_usage_and_rules.md`, `context_reference.md`, pipeline rules 11, 22.

### Angle 7 — WebSocket frontend handler, copy rules, and DECIDED-OUT absence verification

**What this covers:**
- Handler case `JOB_CRITERIA_EXTRACTION_COMPLETE` after the `AI_SUMMARY_FAILED` block (WebsocketGlobalChannelHandler.tsx:236-248): three-way toast (succeeded → success; zeroCriteriaFailure → warning zero-found copy; else → warning generic), `delay: 10000`, `queryCache.invalidateQueries(["aiJobCriteria", Number(payload.jobId)])` — the invalidation key MUST exactly match the hook's query key shape `["aiJobCriteria", jobId]` (number). Structural mirror of the `AI_SUMMARY_COMPLETE` case (:216-234); `Number()` cast per `attachExternalResumeComplete` (:153).
- Payload type `JobCriteriaExtractionCompletePayload` added to `aiSummaryWebsocketPayloads.ts` matching the backend broadcast fields exactly (`status`, `jobId`, `jobTitle`, `zeroCriteriaFailure`, optional `errorMessage`); header comment updated to "AI WebSocket broadcasts"; imported in the handler.
- **Copy rules sweep (SPEC 10, binding)** across EVERY new user-facing string — toasts, three empty states, card description, section intro, sidebar glossary, both modals, backend error messages surfaced to users: no em dashes; sentence case; no emoji; "extract" never "read"; "count most/less toward the score" never "weight/heaviest"; static button labels (no interpolated counts); timestamps only in the card description; never "candidates will be rescored". Check the DECISIONS-verbatim strings (empty-state titles/messages, tier leads) match exactly.
- **DECIDED-OUT absence verification (spec review: absent from SPEC; impl review: absent from the diff):** (a) NO guard modals — grep the diff for `guard`, `GuardTitle`, `GuardBody`, `GuardFoot`, ≤5-criteria warnings, 0-criteria popups; (b) NO after-description-update confirm variant or its trigger; (c) NO tier hint sentences in the slide-over (bundle-3 `TierHint` dropped); (d) NO `internal_job_criteria` — grep the ENTIRE diff (backend + frontend) for `internal_job_criteria`; zero occurrences required. Also: design-bundle variable names must NOT leak in (DECISIONS: structure/styles only — check for `tier1`/`tier2`/`tier3` payload keys, bundle variable names).
- Frontend tests: none — DOCUMENTED decision (SPEC 12; single existing component test `Button.test.tsx`, no hook/view test infra). Verify the implementation didn't half-add a test harness.

**Files:** `WebsocketGlobalChannelHandler.tsx`, `aiSummaryWebsocketPayloads.ts`, all new/modified frontend files (copy sweep), the full diff (absence greps).
**Analog files:** `AI_SUMMARY_COMPLETE`/`AI_SUMMARY_FAILED` cases (:216-248), existing payload interfaces in `aiSummaryWebsocketPayloads.ts`.
**Convention context:** `cursor_rules/frontend/core_critical_rules.md` (rule 7 casing at the WS boundary — backend broadcasts camelCase payload keys directly, no api.ts transform on the socket path; verify keys arrive camelCase from the broadcast), SPEC section 10, DECISIONS "Decided OUT" + "Copy rules".

### Angle 8 — cursor_rules compliance (REQUIRED; drives the Phase 6.5 fan-out)

**What this covers:** Every file the spec creates or modifies, checked against the specific cursor_rules files that govern it. The implementation review fans out ONE reviewer per rules file below, scoped to "ONLY these rules," reporting VIOLATIONS + MISSING with file:line evidence.

**Rules-file → diff-file map:**

| cursor_rules file | Files in this diff it governs |
|---|---|
| `core_critical_rules.md` (root) | ALL files. Highest-frequency risks here: rule 1 (no begin blocks — new controller), rule 5 (params methods — new controller has zero, compliant), rule 7 (casing + enum exception — serializer, hook types, WS payload), rule 8 (bare guards — job.rb, textract_result.rb, extract_job_criteria_job.rb), rule 10 (no fabricated fallbacks — serializer safe-nav, hook, handler), rule 11/12 (no bangs outside spec/, check save returns — model, controller, job), variable naming for records (`ai_job_criteria`, `requesting_organization_user`, `job_application_bulk_job_status` — never `row`/`record`/`latest`) |
| `backend/_base.md` | All backend diff files |
| `backend/core_critical_rules.md` | All backend diff files |
| `backend/controllers/controller_patterns_and_crud.md` | `ai_job_criteria_controller.rb`, `bulk_ai_job_application_summaries_controller.rb` |
| `backend/controllers/controller_error_handling.md` | `ai_job_criteria_controller.rb`, `bulk_ai_job_application_summaries_controller.rb` |
| `backend/controllers/pundit_policies.md` | `ai_job_criteria_controller.rb` (authorize-after-find, explicit queries, no new policy methods) |
| `backend/serializers.md` | `job_ai_job_criteria_serializer.rb` (§1 jsonb pass-through, §7 model-level computation) |
| `backend/background_jobs.md` | `extract_job_criteria_job.rb`, `bulk_generate_ai_summaries_job.rb` |
| `backend/interactors/interactor_patterns_and_structure.md` | `validate_ai_summary_generation.rb`, `validate_auto_ai_summary_generation.rb`, `queue_bulk_ai_summary_jobs.rb` |
| `backend/interactors/interactor_usage_and_guidelines.md` | same three interactors |
| `backend/services.md` | `extract_criteria.rb`, `score_job_application.rb` (constant substitutions only — flag anything beyond one-line swaps) |
| `backend/code_style_and_structure.md` | all backend diff files (model methods on `job.rb`, `ai_job_criteria.rb`, `textract_result.rb`) |
| `backend/architecture.md` | placement calls: guard in model vs interactor, serializer off Job, broadcast in job |
| `frontend/core_critical_rules.md` | all frontend diff files |
| `frontend/_base.md` | all frontend diff files (incl. §1 no `??`) |
| `frontend/react_query/react_query_queries.md` | `useAiJobCriteria.ts` (key shape, `enabled` guard) |
| `frontend/react_query/react_query_mutations_and_cache.md` | `useAiJobCriteria.ts` (hook-level onSuccess invalidation), `RegenerateJobCriteriaConfirmModal.tsx` (call-site callbacks) |
| `frontend/modals/modal_form_and_confirmation_patterns.md` | `RegenerateJobCriteriaConfirmModal.tsx`, `JobCriteriaViewModal.tsx` |
| `frontend/modals/modal_state_errors_and_loading.md` | both modals (loading/disabled, error toast, stays-open-on-error) |
| `frontend/components/component_size_and_extraction.md` | `JobSetupAiSettings.tsx` (>400-line extraction call), conditional `JobCriteriaSection.tsx` |
| `frontend/components/component_architecture.md` | new components + section structure |
| `frontend/ui_styling.md` | all new styled components (theme tokens, Emotion patterns) |
| `frontend/react_hooks.md` | `useAiJobCriteria.ts`, hook usage in the section/modals |
| `frontend/boolean_variables_and_naming.md` | `isInFlight`, `zeroCriteriaFailure` and friends |
| `frontend/contexts/context_usage_and_rules.md` + `context_reference.md` | ModalContext/ToastContext consumption in section + modals |

**Explicitly NOT relevant** (do not spawn reviewers): `backend/migrations.md` (no schema change), `cypress/*` (no Cypress changes — documented), `backend/job_board_integration/*`, `backend/public_api_controllers.md`, `public_api_controller_rules.md`, `console_commands.md`, `frontend/forms/*` (no new form inputs; the existing FormSelect flow is untouched — if the implementation adds form-state handling, add `form_state_and_change_handlers.md` + `form_submission_and_mutations.md` back in), `frontend/lists/*` (no lists with sorting/filtering; the tier list in the slide-over is static display), `frontend/reference_patterns.md` (index file — use as pointer only).

**Files:** the complete file inventory in SPEC section 13 (verified against the worktree: all "new" targets confirmed absent today; all "modified" targets confirmed present).

---

## 4. Always-on checks

### Source accuracy
Every file:line citation in SPEC.md was spot-verified by Phase 1 and held (job.rb:726-743 old form present; extract_criteria.rb:62/:122 and score_job_application.rb:43 message strings exact; bulk_generate_ai_summaries_job.rb:60 stuck-claim premise real; routes.rb:189/:224/:314; FullModal/CenterModal/EmptyState/SettingsContainer/FormSection/PlatoChip/distanceInWords props all as claimed; policy delegation safe for Job records). Reviewers must re-verify any citation they lean on — implementation will shift line numbers. The spec review must additionally verify DECISIONS.md is fully honored where not explicitly flagged (flags 1-7 are the ONLY sanctioned deviations; anything else that differs from DECISIONS is a finding).

### Test coverage
Pipeline rule 3: the spec HAS a test plan (SPEC 12) — 3 new spec files (verified not to already exist), 8 modified (verified to exist), frontend "none" with documented reasoning. Impl review verifies: every listed spec exists and asserts BEHAVIOR (rule 26 — no reflection-only retry tests, no assigned-but-unasserted variables; broadcast tests assert `GlobalChannel.broadcast_to` outcomes; ghost tests are BLOCKER). The six serializer states, the three-message truth table, the no-pending-guard documentation test, and the bulk claim-row `:failed` test are the load-bearing cases. Tests must run against COMMITTED code (pipeline rule 15 — run `git diff HEAD` first; worktree was clean at Phase 1).

### Backward compatibility
- `ExtractJobCriteriaJob` signature change: whatever form wins flag 4, already-enqueued Sidekiq payloads (`perform_later(id)`, one positional arg) and the four model enqueue sites must still work at deploy time.
- `extract_job_criteria_immediately` kwarg has default nil — its one existing caller (`extract_job_criteria_if_needed`, job.rb:742) unchanged; `auto_extract_job_criteria`/`extract_job_criteria` untouched (their pending-guard + Flipper semantics preserved).
- `QueueBulkAiSummaryJobs` `job` input optional + safe-nav — existing spec examples without `job:` must still pass.
- `ValidateAiSummaryGeneration`/`ValidateAutoAiSummaryGeneration` gain one fail — all EXISTING callers (single manual, bulk per-record, textract both branches, auto x2) get the new fail; confirm no caller treats a new failure message as unexpected (textract manual-waiting branch destroys the waiting summary and broadcasts `AI_SUMMARY_FAILED` with the message — existing mechanism, textract_result.rb:134-137).
- `aiSummaryWebsocketPayloads.ts` header comment change only — existing interfaces untouched.
- `JobSetupAiSettings.tsx`: existing Plato-reviews FormSection, dirty tracking, Save flow byte-preserved; adding `sidebar` changes SettingsContainer layout at lg — visually verify the existing form.

### Full-stack analog completeness
Walk the analog pipeline layer by layer (section 2 table) and confirm the new feature has a counterpart at EVERY layer: modal-owning-mutation → hook → route → controller → validator/guard → async job → broadcast helper → channel → WS handler case → payload type → query invalidation. A missing layer (e.g., broadcast present but no handler case, or hook invalidation key mismatch) is a HIGH finding.

### Analog structural matching (pipeline rule 14 — signatures, not layers)
Compare at the structural level and flag EVERY deviation (surface all; only flags 1-7 are pre-adjudicated):
- **Parameter interfaces:** `ExtractJobCriteriaJob#perform` args form vs `GenerateAiJobApplicationSummaryJob#perform(textract_result_id:, requesting_organization_user_id: nil)` — FLAG 4, deferred to spec review (Angle 3 carries the mandatory procedure). Controller: no body params vs analog's nested-resource params — justified (no inputs), verify no gratuitous params method appears.
- **Retry/exhaustion patterns:** analog broadcasts from its `retry_on` exhaustion block (:13-22); `ExtractJobCriteriaJob` already HAS the exhaustion block with the failure write (:5-10) — the broadcast must be ADDED there, not only in perform/rescue. Argument-reading style in the exhaustion block must match the signature form chosen.
- **Callback patterns:** no new callbacks specced (`resume_waiting_summaries` untouched; status changes via `update_columns` deliberately skip callbacks). Flag ANY new callback on `AiJobCriteria`/`Job` as unspecced.
- **Error-handling shapes:** `rescue CustomErrorAiSummary => e; raise` re-raise for retry + `rescue StandardError` terminal write + broadcast — must mirror the analog's dual-rescue shape (:35-46); broadcast helper guard ladder (find user → reload → terminal check) in analog order.
- **Serializer/status-pointer deviation** (dedicated endpoint vs parent-serializer ride-along) — spec-adjudicated with written rationale (SPEC 5.1); verify the rationale's premise (criteria status needed ONLY in this tab) still holds in the implemented UI.

---

## 5. Phase-1 trace notes for the spec reviewer (not findings — verify and adjudicate)

1. **EmptyState has no action prop** (EmptyState.tsx:7-13) — the spec's per-state "action row" must live outside the component; spec doesn't say where. Plan should pin this down (Angle 5).
2. **JobCriteriaViewModal frozen `criteria` prop** — stale if regeneration completes while open; consciously accept or move to live-read (Angle 6).
3. **Flag 4 evidence pre-gathered** — analog kwargs at generate_ai_job_application_summary_job.rb:24 with `job.arguments.first[:key]` exhaustion reads (:16, :20); current ExtractJobCriteriaJob spec calls `perform_now(id)` positionally throughout; in-flight-at-deploy queue payloads favor positional, strict analog matching favors kwargs (Angle 3).
4. **Guard-set asymmetry is pre-existing and deliberate:** post-change `_immediately` guards in_progress/retrying but not pending; `auto_extract_job_criteria`/`extract_job_criteria` guard pending but not in_progress/retrying, plus Flipper. DECISIONS verbatim — do not harmonize either direction.
5. **The WS broadcast payload keys are camelCase written directly in Ruby** (`jobId`, `jobTitle`, `zeroCriteriaFailure`) — matches the analog (`candidateFullName`); the socket path has no api.ts case transform. The serializer path DOES transform (`extracted_at` → `extractedAt`). Two different casing mechanisms feeding one frontend — types must match each source's actual wire format.
6. **Section visibility relies on the tab gate** — `FeatureFlipper feature="AI_APPLICANT_SUMMARY"` at JobSetupContainer.tsx:374; the GET endpoint is deliberately ungated. If the spec review wants section-level gating it must say so explicitly; today's story is coherent.
