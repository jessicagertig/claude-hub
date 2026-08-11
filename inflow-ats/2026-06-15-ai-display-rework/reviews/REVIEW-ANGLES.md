# Review Angles -- AI Display Rework

Generated from: REWORK-SPEC.md
Date: 2026-06-15

## Subsystems touched

### Backend -- Models
- `app/models/ai_job_application_summary.rb` -- new `after_save :broadcast_status_change` callback, new `BROADCAST_STATUSES` constant
- `app/models/ai_job_application_summary_status.rb` -- consumed by serializer (no spec changes, but behavior depends on correct denormalization)
- `app/models/job_application.rb` -- `has_one :latest_ai_job_application_summary`, `has_one :ai_job_application_summary_status` (existing associations, serializer change affects what gets loaded)

### Backend -- Serializers
- `app/serializers/api/v1/job_application_serializer.rb` -- remove `has_one :ai_job_application_summary`, add `has_one :ai_job_application_summary_status`
- `app/serializers/api/v1/ai_job_application_summary_shallow_serializer.rb` -- may become unused after serializer swap
- `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb` -- already exists, serves the new lightweight payload
- `app/serializers/api/v1/shallow_job_application_serializer.rb` -- already includes `ai_job_application_summary_status` (list view, no change expected)

### Backend -- Channels
- `app/channels/job_channel.rb` -- receives broadcasts from the new model callback

### Backend -- Services (pipeline status transitions)
- `app/services/ai_job_application_action/orchestrate.rb` -- `update_columns` -> `update` for status transitions
- `app/services/ai_job_application_action/scoring/score_job_application.rb` -- `update_columns` -> `update` for status transitions
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb` -- `update_columns` -> `update` for status transitions

### Frontend -- WebSocket handler
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx` -- new `ai_summary_status_change` case

### Frontend -- Plato components
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx` -- switch data source from `aiJobApplicationSummary` to `aiJobApplicationSummaryStatus`
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoOverviewCallout.tsx` -- five-state logic from summary status
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoGeneratedReviewCallout.tsx` -- reads from summary status, not full summary
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoTabEmptyState.tsx` -- all states use Plato chip icon, remove `DragAndDropResumeUploader`
- `app/javascript/ats/src/views/jobApplications/Plato/JobApplicationTabEmptyState.tsx` -- CTA to navigate to resume tab
- `app/javascript/ats/src/views/jobApplications/Plato/FitIndicator.tsx` -- may consume score from new data source
- `app/javascript/ats/src/views/jobApplications/Plato/ScoringDetail.tsx` -- consumes full summary data
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoSummary.tsx` -- consumes full summary data
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoScoreTag.tsx` -- consumes score data

### Frontend -- Job application views
- `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx` -- switch from `aiJobApplicationSummary?.status` to `aiJobApplicationSummaryStatus.status`
- `app/javascript/ats/src/views/jobApplications/JobApplicationListContainer.tsx` -- already reads from `aiJobApplicationSummaryStatus` (verify consistency)
- `app/javascript/ats/src/views/jobApplications/JobApplicationNavItem.tsx` -- may show Plato indicator from status

### Frontend -- Types
- `app/javascript/shared/types/jobApplication.ts` -- remove `aiJobApplicationSummary`, add `aiJobApplicationSummaryStatus`
- `app/javascript/shared/types/aiJobApplicationSummary.ts` -- `AiJobApplicationSummary` interface stays (used by full query), but shallow interface changes

### Frontend -- Query hooks
- `app/javascript/shared/queryHooks/useAiJobApplicationSummary.ts` -- separate full-data fetch, unchanged in API but consumers change how they obtain the summary ID
- `app/javascript/shared/queryHooks/useJobApplication.ts` -- invalidation of `["aiJobApplicationSummary"]` on generate mutation (line 224)

### Frontend -- Other modified files (on branch)
- `app/javascript/ats/src/components/DragAndDropResumeUploader.tsx`
- `app/javascript/ats/src/components/shared/Accordion.tsx`
- `app/javascript/ats/src/components/shared/NavItem.tsx`
- `app/javascript/ats/src/views/jobApplications/channelMessages/ChannelMessageList.tsx`

### Backend -- Tests
- `spec/models/ai_job_application_summary_spec.rb` -- needs coverage for new `broadcast_status_change` callback
- `spec/models/ai_job_application_summary_status_spec.rb` -- existing, may need updates
- `spec/services/ai_job_application_action/orchestrate_spec.rb` -- tests use `update_columns` in setup; `update` change may trigger callbacks in tests
- `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb` -- same `update_columns` -> `update` concern
- `spec/jobs/generate_ai_job_application_summary_job_spec.rb` -- existing job spec

### Database
- `db/schema.rb` -- modified (denormalized columns already present on `ai_job_application_summary_statuses`)

## Full-stack analog

The **existing AI summary completion pipeline** is the closest analog. It shares the same domain, the same models, and the same frontend components. The rework modifies this pipeline rather than creating a parallel one.

### Analog pipeline trace

**Trigger:** `TextractResult` saved with OCR text
- `app/models/textract_result.rb` -- `after_commit :queue_ai_summary_job` (on create/update)

**Background job:** `GenerateAiJobApplicationSummaryJob`
- `app/jobs/generate_ai_job_application_summary_job.rb` -- calls `TextractResult#generate_ai_summary_with_credit_flow`

**Pipeline orchestration:**
- `app/services/ai_job_application_action/orchestrate.rb` -- multi-stage pipeline, `update_columns(status: ...)` transitions
- `app/services/ai_job_application_action/scoring/score_job_application.rb` -- scoring stage, `update_columns(status: ...)`
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb` -- integration stage, `update_columns(status: ...)`

**Model callbacks on completion:**
- `app/models/ai_job_application_summary.rb` -- `after_commit :create_status_record` (on create), `after_commit :update_summary_status_record` (on update, when succeeded)

**Denormalized status record:**
- `app/models/ai_job_application_summary_status.rb` -- `update_columns` with `score_percentage`, `headline`, `integrated_role_analysis`

**WebSocket broadcast (current -- GlobalChannel):**
- `app/jobs/generate_ai_job_application_summary_job.rb:72` -- `GlobalChannel.broadcast_to(user, action: 'AI_SUMMARY_COMPLETE', ...)`
- `app/models/textract_result.rb:136` -- `GlobalChannel.broadcast_to(user, action: 'AI_SUMMARY_FAILED', ...)`

**Frontend WebSocket handler (current):**
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx:212-229` -- `AI_SUMMARY_COMPLETE` invalidates `["jobApplication"]`, `["aiJobApplicationSummary"]`, `["organizationAiCreditBalance"]`

**Serializers (two tiers):**
- `app/serializers/api/v1/shallow_job_application_serializer.rb` -- list view, includes `ai_job_application_summary_status`
- `app/serializers/api/v1/job_application_serializer.rb` -- detail view, includes `ai_job_application_summary` (shallow)
- `app/serializers/api/v1/ai_job_application_summary_serializer.rb` -- full summary (via separate query)

**Frontend query hooks:**
- `app/javascript/shared/queryHooks/useJobApplication.ts` -- detail fetch, includes shallow summary in response
- `app/javascript/shared/queryHooks/useAiJobApplicationSummary.ts` -- separate full summary fetch

**Frontend consumers:**
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx` -- reads `jobApplication.aiJobApplicationSummary` for status, uses `useAiJobApplicationSummary` for full data
- `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx` -- reads `aiJobApplicationSummary?.status` to decide callout
- `app/javascript/ats/src/views/jobApplications/activities/AiJobApplicationSummaryFeedItem.tsx` -- displays full summary in activity feed

### Secondary analog: JobChannel broadcast pattern

**`BoardWwrListing`** is the only existing model that broadcasts to `JobChannel` from a model callback:
- `app/models/board_wwr_listing.rb:268` -- `JobChannel.broadcast_to(job, event: 'wwr_listing_updated', ...)`
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx:55-59` -- handles event, invalidates `["jobs", jobId]`

This is the structural template for the new `ai_summary_status_change` broadcast.

**Priority rule:** Where the full-stack analog deviates from convention, the analog wins.

## Angles

### serializer-contract

**What this covers:** The data contract between the backend serializers and every frontend consumer that reads job application data, ensuring the type removal/addition is complete and consistent across both tiers (list view via `ShallowJobApplicationSerializer`, detail view via `JobApplicationSerializer`).

**Files across all layers:**
- `app/serializers/api/v1/job_application_serializer.rb` -- the serializer being modified (remove `ai_job_application_summary`, add `ai_job_application_summary_status`)
- `app/serializers/api/v1/shallow_job_application_serializer.rb` -- list serializer (already has `ai_job_application_summary_status`, verify no stale `ai_job_application_summary` reference)
- `app/serializers/api/v1/ai_job_application_summary_shallow_serializer.rb` -- becomes unused by `JobApplicationSerializer`; check if any other serializer still references it
- `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb` -- verify attributes match what frontend expects
- `app/javascript/shared/types/jobApplication.ts` -- TypeScript interface must remove `aiJobApplicationSummary`, add `aiJobApplicationSummaryStatus`
- `app/javascript/shared/types/aiJobApplicationSummary.ts` -- `AiJobApplicationSummary` interface stays for the full query; verify no type expects it on `JobApplication`
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx` -- primary consumer of the detail-view serializer
- `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx` -- reads status to decide which callout to render
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoOverviewCallout.tsx` -- reads status fields
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoGeneratedReviewCallout.tsx` -- reads `headline`, `scorePercentage`, `integratedRoleAnalysis` from status
- `app/javascript/ats/src/views/jobApplications/JobApplicationListContainer.tsx` -- reads `aiJobApplicationSummaryStatus` (already on branch)
- `app/javascript/ats/src/views/jobApplications/activities/AiJobApplicationSummaryFeedItem.tsx` -- currently receives `aiJobApplicationSummary` as a prop from `JobApplicationActivity`; must be rewired or removed

**Analog files for comparison:**
- `app/serializers/api/v1/shallow_job_application_serializer.rb` -- already uses the status serializer pattern; the detail serializer should match

**Convention context:**
- `cursor_rules/backend/serializers.md`
- `cursor_rules/core_critical_rules.md` (rule 7: backend snake_case / frontend camelCase; rule 10: no fabricated fallbacks)
- `cursor_rules/frontend/react_query/react_query_queries.md`

### websocket-broadcast-pipeline

**What this covers:** The new `after_save :broadcast_status_change` callback on `AiJobApplicationSummary`, the `JobChannel` broadcast, the frontend `WebsocketJobChannelHandler` event case, and the interaction with the existing `GlobalChannel` broadcasts for `AI_SUMMARY_COMPLETE`/`AI_SUMMARY_FAILED`. This angle verifies the broadcast fires on the right statuses, reaches the right channel, and the frontend invalidates the right queries.

**Files across all layers:**
- `app/models/ai_job_application_summary.rb` -- new `after_save` callback, `BROADCAST_STATUSES` constant, guard logic
- `app/channels/job_channel.rb` -- receives the broadcast
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx` -- new `ai_summary_status_change` case
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` -- existing `AI_SUMMARY_COMPLETE` and `AI_SUMMARY_FAILED` handlers (interaction: do these still fire? does the new broadcast supplement or replace them?)
- `app/jobs/generate_ai_job_application_summary_job.rb` -- existing `GlobalChannel.broadcast_to` for `AI_SUMMARY_COMPLETE`
- `app/models/textract_result.rb` -- existing `GlobalChannel.broadcast_to` for `AI_SUMMARY_FAILED`
- `spec/models/ai_job_application_summary_spec.rb` -- needs test coverage for new callback

**Analog files for comparison:**
- `app/models/board_wwr_listing.rb` -- the only existing model that broadcasts to `JobChannel` from a callback; structural template for broadcast shape
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx` -- existing event handling pattern (event key, payload shape, invalidation calls)

**Convention context:**
- `cursor_rules/backend/architecture.md` (callback patterns, after_save vs after_commit)
- `cursor_rules/backend/services.md`
- `cursor_rules/frontend/react_query/react_query_mutations_and_cache.md` (invalidation patterns)

### update-columns-to-update-migration

**What this covers:** Switching `update_columns(status: ...)` to `update(status: ...)` in the pipeline services. This is the mechanism that enables the `after_save` callback to fire on intermediate status transitions. The reviewer must verify every `update_columns` call site is converted, understand which callbacks now fire that previously did not, and check for unintended side effects (validation failures, performance impact from callbacks on hot-path status transitions, cascading `after_save` triggers).

**Files across all layers:**
- `app/services/ai_job_application_action/orchestrate.rb` -- 1 `update_columns` call (line 72)
- `app/services/ai_job_application_action/scoring/score_job_application.rb` -- 5 `update_columns` calls (lines 23, 32, 115, 120, 124)
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb` -- 3 `update_columns` calls (lines 59, 64, 68)
- `app/models/ai_job_application_summary.rb` -- existing callbacks: `after_commit :destroy_previous_textract_results` (on update), `after_commit :update_summary_status_record` (on update) -- these now fire on EVERY `update` call, not just the final `succeeded` transition
- `spec/services/ai_job_application_action/orchestrate_spec.rb` -- test setup uses `update_columns`; switching to `update` in app code may change test behavior
- `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb` -- same concern

**Analog files for comparison:**
- `app/models/ai_job_application_summary.rb` -- the model whose callbacks are being activated; review guard clauses on each callback to confirm they filter correctly for intermediate statuses

**Convention context:**
- `cursor_rules/backend/_base.md`
- `cursor_rules/core_critical_rules.md` (rule 11: no bang methods; rule 12: check save/update return values)
- `cursor_rules/backend/services.md`

### frontend-data-source-switchover

**What this covers:** Every frontend component that currently reads `jobApplication.aiJobApplicationSummary` must switch to `jobApplication.aiJobApplicationSummaryStatus` for lightweight status/score/headline data, and use `useAiJobApplicationSummary` only for full structured data on the Plato tab. The reviewer must verify no component still references the removed property, that the five-state logic in `PlatoOverviewCallout` is correctly derived, and that `PlatoGeneratedReviewCallout` reads from the status record (not the full summary).

**Files across all layers:**
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx` -- switch `jobApplication.aiJobApplicationSummary` to `jobApplication.aiJobApplicationSummaryStatus`
- `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx` -- switch status check and callout rendering
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoOverviewCallout.tsx` -- five-state derivation from `aiJobApplicationSummaryStatus` + `hasResume` + credits
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoGeneratedReviewCallout.tsx` -- reads `headline`, `scorePercentage`, `integratedRoleAnalysis` from status
- `app/javascript/ats/src/views/jobApplications/JobApplicationListContainer.tsx` -- already uses `aiJobApplicationSummaryStatus` (verify no residual `aiJobApplicationSummary` references)
- `app/javascript/ats/src/views/jobApplications/JobApplicationNavItem.tsx` -- may show Plato indicator
- `app/javascript/ats/src/views/jobApplications/activities/AiJobApplicationSummaryFeedItem.tsx` -- currently receives `aiJobApplicationSummary` as prop; spec does not mention this file, reviewer must verify it is addressed
- `app/javascript/shared/queryHooks/useAiJobApplicationSummary.ts` -- how the summary ID is obtained changes (from `aiJobApplicationSummary.id` to `aiJobApplicationSummaryStatus.aiJobApplicationSummaryId`)
- `app/javascript/shared/queryHooks/useJobApplication.ts` -- generate mutation invalidation still correct?
- `app/javascript/shared/types/jobApplication.ts` -- type change

**Analog files for comparison:**
- `app/javascript/ats/src/views/jobApplications/JobApplicationListContainer.tsx` -- already consumes `aiJobApplicationSummaryStatus`; pattern for how to read status fields

**Convention context:**
- `cursor_rules/frontend/_base.md`
- `cursor_rules/frontend/components/component_architecture.md`
- `cursor_rules/frontend/react_query/react_query_queries.md`
- `cursor_rules/core_critical_rules.md` (rule 9: never set undefined; rule 10: no fabricated fallbacks)

### empty-state-and-callout-logic

**What this covers:** The five-state logic in `PlatoOverviewCallout`, the `PlatoGeneratedReviewCallout` rendering, the `PlatoTabEmptyState` changes (Plato chip icon, no inline uploading), and the `JobApplicationActivity` routing between callouts. The reviewer must verify all state transitions are covered, no state falls through to an incorrect render, and the removal of `DragAndDropResumeUploader` from the Plato tab does not leave dead imports.

**Files across all layers:**
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoOverviewCallout.tsx` -- five-state branching
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoGeneratedReviewCallout.tsx` -- rendered when status is `current` or `regenerating`
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoTabEmptyState.tsx` -- icon change, remove `DragAndDropResumeUploader`
- `app/javascript/ats/src/views/jobApplications/Plato/JobApplicationTabEmptyState.tsx` -- CTA to resume tab
- `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx` -- routing: `current`/`regenerating` -> `PlatoGeneratedReviewCallout`, everything else -> `PlatoOverviewCallout`
- `app/javascript/ats/src/components/DragAndDropResumeUploader.tsx` -- verify no Plato-tab-specific code remains
- `app/models/ai_job_application_summary_status.rb` -- enum values (`none`, `current`, `regenerating`) that the frontend branches on

**Analog files for comparison:**
- None specific -- this is new UI logic

**Convention context:**
- `cursor_rules/frontend/components/component_architecture.md`
- `cursor_rules/frontend/components/component_size_and_extraction.md`
- `cursor_rules/core_critical_rules.md` (rule 9: never set undefined; rule 10: no fabricated fallbacks)
- `cursor_rules/frontend/ui_styling.md`

### callback-side-effects-and-guards

**What this covers:** The `after_save :broadcast_status_change` callback fires on every `update` call (not just `succeeded`). The `BROADCAST_STATUSES` constant and the two guard clauses (`saved_change_to_status?`, status in `BROADCAST_STATUSES`) must correctly filter which transitions broadcast and which are silent. The reviewer must also verify that existing callbacks (`destroy_previous_textract_results`, `update_summary_status_record`) have adequate guards to prevent firing on intermediate transitions now that `update_columns` is replaced with `update`.

**Files across all layers:**
- `app/models/ai_job_application_summary.rb` -- all three `after_commit`/`after_save` callbacks plus new `broadcast_status_change`
- `app/services/ai_job_application_action/orchestrate.rb` -- calls `update` (was `update_columns`) which now triggers callbacks
- `app/services/ai_job_application_action/scoring/score_job_application.rb` -- same
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb` -- same
- `spec/models/ai_job_application_summary_spec.rb` -- callback test coverage

**Analog files for comparison:**
- `app/models/board_wwr_listing.rb` -- `after_update :handle_after_update` with guards; structural template for how model callbacks gate side effects

**Convention context:**
- `cursor_rules/backend/architecture.md`
- `cursor_rules/backend/_base.md`
- Known failure pattern #16 in `~/claude-hub/inflow-ats/CLAUDE.md` (companion records: create via unconditional owner)
- Known failure pattern #18 in `~/claude-hub/inflow-ats/CLAUDE.md` (denormalized columns: clear ALL when disassociating)

### query-invalidation-coherence

**What this covers:** After this rework, there are two independent invalidation paths: (1) the new `JobChannel` broadcast for `ai_summary_status_change` invalidating `["aiJobApplicationSummary"]` in `WebsocketJobChannelHandler`, and (2) the existing `GlobalChannel` broadcast for `AI_SUMMARY_COMPLETE` invalidating `["jobApplication"]` + `["aiJobApplicationSummary"]` in `WebsocketGlobalChannelHandler`. The reviewer must verify these do not conflict, do not produce redundant fetches that cause UI flicker, and that all query keys used for invalidation match the query keys used in `useAiJobApplicationSummary` and `useJobApplication`.

**Files across all layers:**
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx` -- new invalidation
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` -- existing invalidation (lines 212-229)
- `app/javascript/shared/queryHooks/useAiJobApplicationSummary.ts` -- query key: `["aiJobApplicationSummary", aiJobApplicationSummaryId]`
- `app/javascript/shared/queryHooks/useJobApplication.ts` -- query key: `["jobApplication", jobApplicationId]`; generate mutation invalidation (line 224)
- `app/jobs/generate_ai_job_application_summary_job.rb` -- existing `GlobalChannel` broadcast (does it still fire after the rework?)
- `app/models/ai_job_application_summary.rb` -- new `JobChannel` broadcast

**Analog files for comparison:**
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx` -- existing pattern for `wwr_listing_updated` invalidation
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` -- existing pattern for `AI_SUMMARY_COMPLETE` invalidation

**Convention context:**
- `cursor_rules/frontend/react_query/react_query_queries.md`
- `cursor_rules/frontend/react_query/react_query_mutations_and_cache.md`

## Always-on checks

### Source accuracy
The review agent verifies every file path, class, method, column, route, and component the spec references against the current source. Specific items to verify:
- `AiJobApplicationSummaryStatus` enum values match the spec's state names (`none`, `current`, `regenerating`)
- `ai_job_application_summary_statuses` table columns match what the status serializer exposes (`status`, `score_percentage`, `headline`, `integrated_role_analysis`)
- `BROADCAST_STATUSES` list matches the model's enum values for the statuses named in the spec
- `JobChannel.broadcast_to` method signature matches the broadcast call in the callback
- `useAiJobApplicationSummary` query key matches the invalidation key in `WebsocketJobChannelHandler`

### Test coverage
The review agent checks what existing tests cover the affected code and what new tests the spec should require:
- `spec/models/ai_job_application_summary_spec.rb` -- needs tests for `broadcast_status_change` callback: fires for broadcast statuses, does not fire for `pending`/`awaiting_job_criteria`/`retrying`, does not fire when status unchanged
- `spec/models/ai_job_application_summary_status_spec.rb` -- existing tests sufficient unless model logic changes
- `spec/services/ai_job_application_action/orchestrate_spec.rb` -- `update_columns` -> `update` change means callbacks fire in tests; verify test expectations still hold
- `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb` -- same concern
- No Cypress tests currently reference Plato components (verified: zero matches in `cypress/`)

### Backward compatibility
The review agent identifies all consumers of modified code and verifies they are addressed:
- `AiJobApplicationSummaryFeedItem.tsx` -- currently receives `aiJobApplicationSummary` as a prop from `JobApplicationActivity.tsx`; the spec does not mention this component, but removing `aiJobApplicationSummary` from the serializer will break it unless rewired
- `AiJobApplicationSummaryShallowSerializer` -- currently used by `JobApplicationSerializer`; after removal, verify no other serializer references it
- `useJobApplication` generate mutation -- invalidates `["aiJobApplicationSummary"]` (line 224); verify this still makes sense
- Any other frontend file that reads `jobApplication.aiJobApplicationSummary` (search: `AiJobApplicationSummaryFeedItem`, `PlatoTab`, `JobApplicationActivity`)

### Full-stack analog completeness
The review agent verifies the new feature has a corresponding piece for every layer of the analog pipeline:
- Analog has `GlobalChannel` broadcast from job -> spec adds `JobChannel` broadcast from model callback (different channel, different trigger point -- verify intentional)
- Analog has `after_commit` for `update_summary_status_record` -> spec adds `after_save` for `broadcast_status_change` (different hook type -- verify `after_save` vs `after_commit` is intentional)
- Analog has two-tier serialization (shallow in list, shallow-summary in detail) -> spec moves detail to use the same status record as list (verify the full summary is still accessible via separate query)
- Analog has `WebsocketGlobalChannelHandler` invalidation -> spec adds `WebsocketJobChannelHandler` invalidation (different handler -- verify both are needed or if one replaces the other)

### Analog structural matching
The review agent greps for analog files, reads their parameter interfaces, retry/exhaustion patterns, callback patterns, and error handling shapes, and diffs them against the new code:
- `BoardWwrListing#broadcast_event` method signature and payload shape vs new `broadcast_status_change` method
- `WebsocketJobChannelHandler` existing event case structure (switch/case with `queryClient.invalidateQueries`) vs new case
- `after_commit` (existing callbacks) vs `after_save` (new broadcast callback) -- the analog uses `after_commit`; the spec says `after_save`. The review agent must flag this discrepancy and verify the choice is intentional
- Guard pattern: existing `update_summary_status_record` uses `saved_change_to_status? && status_succeeded?`; new `broadcast_status_change` uses `saved_change_to_status?` then `BROADCAST_STATUSES.include?(status)` -- structurally consistent
