# AI Display Rework -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

---

## Summary

This rework decouples the full `AiJobApplicationSummary` record from the job application serializer payload. The detail-view serializer (`JobApplicationSerializer`) currently embeds a shallow summary via `AiJobApplicationSummaryShallowSerializer`; that gets replaced with `AiJobApplicationSummaryStatus` -- the same lightweight denormalized record the list-view serializer already uses. Full summary data stays accessible only through the separate `useAiJobApplicationSummary` React Query hook, used exclusively by the Plato tab. To make intermediate pipeline statuses visible in real time, `update_columns` calls in three pipeline services switch to `update`, and a new `before_update` callback on `AiJobApplicationSummary` broadcasts status changes over `JobChannel`. The frontend `WebsocketJobChannelHandler` picks up the new event and invalidates the appropriate query. All frontend consumers switch from `jobApplication.aiJobApplicationSummary` to `jobApplication.aiJobApplicationSummaryStatus`. A new `PlatoLoadingState` component replaces the shimmer animation in the Plato tab with a 4-step checklist loader driven by the live pipeline status.

---

## Pattern Precedents

### P1. Serializer association swap (list vs. detail)

`ShallowJobApplicationSerializer` already includes `ai_job_application_summary_status` with `AiJobApplicationSummaryStatusSerializer` -- the exact same pattern the detail serializer will adopt.

- **File:** `app/serializers/api/v1/shallow_job_application_serializer.rb` lines 18-19
- **File:** `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb` lines 3-6

### P2. JobChannel broadcast from model callback

`BoardWwrListing#broadcast_event` broadcasts to `JobChannel` from a model method called by `after_update :handle_after_update`. This is the only existing model that broadcasts to `JobChannel` from a callback.

- **File:** `app/models/board_wwr_listing.rb` line 267-268 (`broadcast_event` method: `JobChannel.broadcast_to(job, event: event, payload: { ... })`)
- **File:** `app/models/board_wwr_listing.rb` line 9 (`after_update :handle_after_update`)

### P3. WebsocketJobChannelHandler event case

Existing event cases `wwr_listing_published` / `wwr_listing_updated` invalidate queries via `queryClient.invalidateQueries`. The new `ai_summary_status_change` case follows the same structure.

- **File:** `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx` lines 55-59

### P4. GlobalChannel AI broadcast (existing supplementary pattern)

`WebsocketGlobalChannelHandler` handles `AI_SUMMARY_COMPLETE` and `AI_SUMMARY_FAILED` with toast notifications and query invalidation. These broadcasts remain; the new `JobChannel` broadcast supplements (does not replace) them for intermediate status visibility.

- **File:** `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` lines 212-228 (`AI_SUMMARY_COMPLETE`)
- **File:** `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` lines 231-241 (`AI_SUMMARY_FAILED`)

### P5. Existing callback guard pattern on AiJobApplicationSummary

Both `destroy_previous_textract_results` and `update_summary_status_record` use `saved_change_to_status? && status_succeeded?` as guards (correct for `after_commit`). The new `broadcast_status_change` uses `status_changed?` (correct for `before_update`, where changes are not yet saved) followed by a `BROADCAST_STATUSES.include?(status)` check.

- **File:** `app/models/ai_job_application_summary.rb` line 51 (`return unless saved_change_to_status? && status_succeeded?`)
- **File:** `app/models/ai_job_application_summary.rb` line 60 (same pattern)

### P6. Frontend status consumption from aiJobApplicationSummaryStatus (already on branch)

`JobApplicationListContainer` already reads from `aiJobApplicationSummaryStatus` to pass props to `JobApplicationNavItem`. This is the target pattern for all frontend consumers.

- **File:** `app/javascript/ats/src/views/jobApplications/JobApplicationListContainer.tsx` lines 222-223
- **File:** `app/javascript/ats/src/views/jobApplications/JobApplicationNavItem.tsx` lines 20-28

### P7. update_columns to update migration (same codebase precedent)

`summary/generate.rb` already uses `update` (not `update_columns`) for its main data updates (lines 68, 102, 129, 169), while using `update_columns` only for error/retry paths. The spec calls for the same split in `orchestrate.rb`, `score_job_application.rb`, and `integrate_analysis.rb`.

- **File:** `app/services/ai_job_application_action/summary/generate.rb` lines 68, 102, 129, 169 (happy path uses `update`)
- **File:** `app/services/ai_job_application_action/summary/generate.rb` lines 175, 180, 184 (rescue paths use `update_columns`)

### P8. PlatoTabEmptyState container pattern (loading state family)

`PlatoTabEmptyState` renders `JobApplicationTabEmptyState` inside a container with a consistent border, padding, and centering pattern. `PlatoLoadingState` must mirror this container style so empty, loading, and review states read as one visual family.

- **File:** `app/javascript/ats/src/views/jobApplications/Plato/PlatoTabEmptyState.tsx`
- **File:** `app/javascript/ats/src/views/jobApplications/Plato/JobApplicationTabEmptyState.tsx`

---

## Files to Create or Modify

### Backend -- Modified
1. `app/models/ai_job_application_summary.rb` -- add callback + constant
2. `app/serializers/api/v1/job_application_serializer.rb` -- swap association
3. `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb` -- add `updated_at` attribute
4. `app/services/ai_job_application_action/orchestrate.rb` -- `update_columns` to `update`
5. `app/services/ai_job_application_action/scoring/score_job_application.rb` -- `update_columns` to `update` (all `update_columns` calls)
6. `app/services/ai_job_application_action/scoring/integrate_analysis.rb` -- `update_columns` to `update` (all `update_columns` calls)

### Backend -- No changes (verified)
- `app/models/ai_job_application_summary_status.rb` -- no spec changes needed
- `app/serializers/api/v1/shallow_job_application_serializer.rb` -- already correct
- `app/channels/job_channel.rb` -- receives broadcast; no code changes needed

### Frontend -- Created
7. `app/javascript/ats/src/views/jobApplications/Plato/PlatoLoadingState.tsx` -- 4-step checklist loader

### Frontend -- Modified
8. `app/javascript/shared/types/jobApplication.ts` -- remove `aiJobApplicationSummary`, add `aiJobApplicationSummaryStatus`
9. `app/javascript/shared/types/aiJobApplicationSummary.ts` -- update `AiJobApplicationSummary` status enum values
10. `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx` -- add `ai_summary_status_change` case
11. `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx` -- switch data source, render `PlatoLoadingState` instead of shimmer
12. `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx` -- switch data source
13. `app/javascript/ats/src/views/jobApplications/Plato/PlatoOverviewCallout.tsx` -- four-state logic from `aiJobApplicationSummaryStatus`
14. `app/javascript/ats/src/views/jobApplications/Plato/PlatoGeneratedReviewCallout.tsx` -- read from status record (verify props are already correct; no change if already receiving props from parent)
15. `app/javascript/ats/src/views/jobApplications/Plato/PlatoTabEmptyState.tsx` -- all icons to `"plato"`, remove `DragAndDropResumeUploader`

### Frontend -- Deleted
16. `app/javascript/ats/src/views/jobApplications/activities/AiJobApplicationSummaryFeedItem.tsx` -- confirmed not imported anywhere

### Tests -- Modified
17. `spec/models/ai_job_application_summary_spec.rb` -- add `broadcast_status_change` callback tests

### Tests -- Verified (no changes unless tests break)
- `spec/services/ai_job_application_action/orchestrate_spec.rb`
- `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb`
- `spec/services/ai_job_application_action/scoring/integrate_analysis_spec.rb`

---

## Implementation Tasks

### Phase A: Backend Changes

#### A.1 Model callback: `broadcast_status_change` on `AiJobApplicationSummary`
*Tags: `cursor_rules/backend/architecture.md`, `cursor_rules/backend/_base.md`*

- [ ] A.1.1 Add `BROADCAST_STATUSES` constant to `app/models/ai_job_application_summary.rb`
  - Value: `%w[textract_processing extracting summarizing scoring integrating succeeded failed]`
  - Location: after the `enum status:` block, before `validates`
  - Excluded statuses: `pending`, `awaiting_job_criteria`, `retrying` (per spec)

- [ ] A.1.2 Add `before_update :broadcast_status_change` callback
  - Location: after the existing `after_commit` lines (line 29)
  - `before_update` fires before the DB write for optimistic broadcast. The only column changing is status -- no validation to fail. Codebase precedent: `before_update :handle_before_update` on `Job` (job.rb:60) and `Organization` (organization.rb:57).

- [ ] A.1.3 Implement `broadcast_status_change` private method
  - Guard 1: `return unless status_changed?` (NOT `saved_change_to_status?` -- this is `before_update`, record is not saved yet; `status_changed?` checks the dirty attribute)
  - Guard 2: `return unless BROADCAST_STATUSES.include?(status)`
  - `ap` log after both guards pass: `ap "[AiJobApplicationSummary] broadcast_status_change"` and `ap status`
  - Broadcast wrapped in rescue:
    ```ruby
    JobChannel.broadcast_to(job_application.job, event: 'ai_summary_status_change', payload: { jobApplicationId: job_application.id })
    rescue StandardError => e
      Rails.logger.error(e)
      ap e
    ```
  - The rescue is critical: `before_update` runs inside the ActiveRecord transaction. An unrescued exception from `JobChannel.broadcast_to` would abort the `update` and prevent the status from persisting. The rescue ensures broadcast failures are logged but never block status transitions (especially critical in rescue paths where `failed`/`retrying` status must persist).
  - Analog: `BoardWwrListing#broadcast_event` at `app/models/board_wwr_listing.rb:267-268`

#### A.2 Serializer swap on `JobApplicationSerializer`
*Tags: `cursor_rules/backend/serializers.md`*

- [ ] A.2.1 Remove `has_one :ai_job_application_summary, serializer: Api::V1::AiJobApplicationSummaryShallowSerializer` (line 40)
- [ ] A.2.2 Remove the `def ai_job_application_summary` method override (lines 42-44)
- [ ] A.2.3 Add `has_one :ai_job_application_summary_status, serializer: Api::V1::AiJobApplicationSummaryStatusSerializer`
  - Match the pattern in `ShallowJobApplicationSerializer` (lines 18-19)
  - The `JobApplication` model already has `has_one :ai_job_application_summary_status` (line 31 of `job_application.rb`), so no custom method override is needed

#### A.3 Add `updated_at` to `AiJobApplicationSummaryStatusSerializer`
*Tags: `cursor_rules/backend/serializers.md`*

- [ ] A.3.1 Add `:updated_at` to the `attributes` line in `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb`
  - Current: `attributes :id, :ai_job_application_summary_id, :status, :score_percentage, :headline, :integrated_role_analysis`
  - New: `attributes :id, :ai_job_application_summary_id, :status, :score_percentage, :headline, :integrated_role_analysis, :updated_at`
  - This is needed so the frontend can use `updatedAt` as a proxy for when the latest successful summary landed (used by `PlatoGeneratedReviewCallout` for the `generatedAgo` display).

- [ ] A.3.2 Add `updated_at: Time.current` to `update_summary_status_record` in `app/models/ai_job_application_summary.rb`
  - `update_summary_status_record` (line 65) uses `update_columns`, which bypasses ActiveRecord and does NOT set `updated_at`. Without this fix, the `updatedAt` exposed by the serializer will reflect the status record's creation time (or last `update` call), not when the latest successful summary was denormalized.
  - Add `updated_at: Time.current` to the `update_columns` hash at line 65:
    ```ruby
    ai_job_application_summary_status.update_columns(
      ai_job_application_summary_id: id,
      status: 'current',
      score_percentage: score_percentage,
      headline: headline,
      integrated_role_analysis: integrated_role_analysis,
      updated_at: Time.current
    )
    ```
  - This is the minimal change. Switching to `update` would also work but fires callbacks on the status record (currently none, so safe but unnecessary overhead).

#### A.4 Pipeline `update_columns` to `update` migration
*Tags: `cursor_rules/backend/services.md`, `cursor_rules/core_critical_rules.md` (rules 11, 12)*

**Scope:** Convert ALL `update_columns` calls in the three named files to `update`. This includes rescue-path calls. The `broadcast_status_change` callback fires for `failed` (which IS in `BROADCAST_STATUSES`), so rescue-path conversions are intentional -- the frontend should know about failures in real time. For `retrying`, the callback fires but the guard rejects it (not in `BROADCAST_STATUSES`). For `awaiting_job_criteria`, same -- guard rejects. This is clean.

`update` in a rescue block means potential validation failures during error handling. The `AiJobApplicationSummary` model only has `validates :status, presence: true`, which will always pass since we are setting status to a valid enum value. Safe to convert.

**Important:** `summary/generate.rb` is NOT in the spec's list. It already mixes `update` and `update_columns`. Leave it as-is.

- [ ] A.4.1 `orchestrate.rb` -- convert 1 `update_columns` call
  - Line 72: `@ai_job_application_summary.update_columns(status: :awaiting_job_criteria)` -> `@ai_job_application_summary.update(status: :awaiting_job_criteria)`
  - Note: `awaiting_job_criteria` is NOT in `BROADCAST_STATUSES`. The callback will fire but the guard rejects it. No broadcast. This is intentional per spec.

- [ ] A.4.2 `score_job_application.rb` -- convert 5 `update_columns` calls
  - Line 23: `update_columns(status: :awaiting_job_criteria)` -> `update(status: :awaiting_job_criteria)`
  - Line 32: `update_columns(status: :scoring)` -> `update(status: :scoring)` -- this one IS broadcast
  - Line 115 (rescue): `update_columns(status: :retrying, error_message: ...)` -> `update(status: :retrying, error_message: ...)` -- NOT broadcast (retrying excluded)
  - Line 120 (rescue): `update_columns(status: :failed, ...)` -> `update(status: :failed, ...)` -- IS broadcast
  - Line 124 (rescue): `update_columns(status: :failed, ...)` -> `update(status: :failed, ...)` -- IS broadcast

- [ ] A.4.3 `integrate_analysis.rb` -- convert 3 `update_columns` calls
  - Line 59 (rescue): `update_columns(status: :retrying, ...)` -> `update(status: :retrying, ...)`
  - Line 64 (rescue): `update_columns(status: :failed, ...)` -> `update(status: :failed, ...)`
  - Line 68 (rescue): `update_columns(status: :failed, ...)` -> `update(status: :failed, ...)`

- [ ] A.4.4 Verify existing callbacks have adequate guards for intermediate statuses
  - `destroy_previous_textract_results`: guarded by `saved_change_to_status? && status_succeeded?` -- only fires on `succeeded`. Safe.
  - `update_summary_status_record`: guarded by `saved_change_to_status? && status_succeeded?` -- only fires on `succeeded`. Safe.
  - `create_status_record`: `on: :create` only. Not affected by `update`. Safe.
  - **Conclusion:** No guard changes needed on existing callbacks.

---

### Phase B: Frontend Type Updates

#### B.1 Update `jobApplication.ts` type
*Tags: `cursor_rules/core_critical_rules.md` (rule 7: backend snake_case / frontend camelCase)*

- [ ] B.1.1 Remove `import { AiJobApplicationSummary } from "@shared/types/aiJobApplicationSummary";` (line 1)
- [ ] B.1.2 Remove `aiJobApplicationSummary: AiJobApplicationSummary | null;` from `JobApplication` interface (line 13)
- [ ] B.1.3 Add `AiJobApplicationSummaryStatus` interface to `jobApplication.ts` (or import from a separate file)
  ```
  export interface AiJobApplicationSummaryStatus {
    id: number;
    aiJobApplicationSummaryId: number | null;
    status: "none" | "current" | "regenerating";
    scorePercentage: number | null;
    headline: string | null;
    integratedRoleAnalysis: string | null;
    updatedAt: string | null;
  }
  ```
  - Fields match `AiJobApplicationSummaryStatusSerializer` attributes: `id`, `ai_job_application_summary_id`, `status`, `score_percentage`, `headline`, `integrated_role_analysis`, `updated_at`
  - Status enum values are Ruby enum values, so they stay snake_case per rule 7 exception -- but `none`, `current`, `regenerating` have no underscores, so no concern
- [ ] B.1.4 Add `aiJobApplicationSummaryStatus: AiJobApplicationSummaryStatus | null;` to `JobApplication` interface

#### B.2 Update `aiJobApplicationSummary.ts` type
*Tags: `cursor_rules/core_critical_rules.md` (rule 7)*

- [ ] B.2.1 Update `AiJobApplicationSummary` status union type to match current enum values
  - Current (stale): `"pending" | "in_progress" | "extracted" | "succeeded" | "failed" | "textract_processing"`
  - Correct: `"pending" | "textract_processing" | "extracting" | "summarizing" | "awaiting_job_criteria" | "scoring" | "integrating" | "succeeded" | "retrying" | "failed"`
  - These match the Ruby enum at `app/models/ai_job_application_summary.rb` lines 11-21

---

### Phase C: Frontend Component Switchover

#### C.1 `WebsocketJobChannelHandler.tsx` -- add `ai_summary_status_change` event
*Tags: `cursor_rules/frontend/react_query/react_query_mutations_and_cache.md`*

- [ ] C.1.1 Add new case in the `switch (data.event)` block in `handleJobMessage`
  - After the existing `docx_to_pdf_conversion_complete` case (before `default`)
  - Pattern: match `wwr_listing_published` / `wwr_listing_updated` case structure
  ```
  case "ai_summary_status_change":
    queryClient.invalidateQueries(["jobApplication"]);
    queryClient.invalidateQueries(["aiJobApplicationSummary"]);
    return;
  ```
  - Invalidates `["jobApplication"]` to refresh `aiJobApplicationSummaryStatus` on the job application
  - Invalidates `["aiJobApplicationSummary"]` to refresh the full summary data on the Plato tab
  - Note: the `AI_SUMMARY_COMPLETE` handler on `WebsocketGlobalChannelHandler` also invalidates these same keys plus `["organizationAiCreditBalance"]`. The new broadcast supplements the global one for intermediate statuses. The global one handles final `succeeded`/`failed` with toast notifications. Both can fire for `succeeded` -- React Query deduplicates identical query invalidations.

- [ ] C.1.2 Add `queryClient` to the `handleJobMessage` `useCallback` dependency array if not already present
  - Already present (line 78: `[refetchJob, queryClient, jobId]`). No change needed.

#### C.2 `PlatoLoadingState.tsx` -- new component (4-step checklist loader)
*Tags: `cursor_rules/frontend/ui_styling.md`, `cursor_rules/core_critical_rules.md` (rules 2, 9, 11)*

The handoff file at `/Users/jessica/Projects/genuine-article-images/PlatoLoadingState.tsx` is a design reference, NOT production code. It must be audited and rewritten to match codebase standards. Create the production file at `app/javascript/ats/src/views/jobApplications/Plato/PlatoLoadingState.tsx`.

**Codebase compliance fixes required on the handoff file:**

- [ ] C.2.1 Remove all JSDoc comments and inline comments
  - The handoff has a 34-line JSDoc block (lines 8-35), inline comments on nearly every line of the component body, and a `/* Styled Components */` banner. Remove all JSDoc and inline comments. Keep only the `/* Styled Components ======= */` banner (codebase convention per `cursor_rules/frontend/ui_styling.md`).

- [ ] C.2.2 Fix all theme destructuring: `const t = props.theme` -> `const t: any = props.theme`
  - 8 instances (lines 118, 143, 152, 164, 183, 202, 213, 234 in the handoff file). Every styled component callback must use `const t: any = props.theme;` per `cursor_rules/frontend/ui_styling.md`.

- [ ] C.2.3 Replace nullish coalescing `??` with `||`
  - Line 76: `const [active, setActive] = React.useState<number>(target ?? 1);` -> `const [active, setActive] = React.useState<number>(target != null ? target : 1);`
  - `??` is forbidden (CLAUDE.md rule 11, Babel does not support it). For this specific case, `target` can be `0` (a valid step index), so `||` would incorrectly treat `0` as falsy. Use `target != null ? target : 1` instead.

- [ ] C.2.4 Verify all theme colors/mixins exist in `app/javascript/ats/styles/theme.ts`
  - `t.color.gray[100]` -- exists (line 7 of theme.ts)
  - `t.color.gray[200]` -- exists (line 9)
  - `t.color.gray[300]` -- exists (line 10)
  - `t.color.gray[400]` -- exists (line 11)
  - `t.color.gray[500]` -- exists (line 12)
  - `t.color.gray[600]` -- exists (line 13)
  - `t.color.black` -- exists (line 18)
  - `t.text.h5` -- exists (line 292)
  - `t.text.sm` -- exists (verified in ui_styling.md)
  - `t.text.xs` -- exists (verified in ui_styling.md)
  - `t.text.medium` -- used in existing codebase (e.g., `PlatoOverviewCallout.tsx` line 166). Verify it exists.
  - `t.spacing[1]`, `[2]`, `[3]` -- exist (theme.ts lines 61-63)
  - `t.px(6)`, `t.py(10)`, `t.rounded.md` -- exist (verified via ui_styling.md)
  - `t.mt(1)`, `t.mb(1)`, `t.mb(2)`, `t.mt(3)`, `t.mb(1)`, `t.mt(4)` -- exist (utility functions)
  - All colors and mixins verified present.

- [ ] C.2.5 Verify no deliberate `undefined` usage (rule 9)
  - The handoff file does not deliberately set `undefined`. The `status` prop is typed `status?: string` (optional), which means it can be `undefined` naturally. No violation.

- [ ] C.2.6 Match existing Styled component patterns
  - The handoff already uses the correct `let Styled: any; Styled = {};` pattern
  - The handoff already uses `styled.div((props: any) => { ... })` pattern
  - Labels are present and follow the `PlatoLoadingState_ElementName` convention
  - Dark mode variants are provided

**Component behavior summary (for implementing agent):**

- Receives `status?: string` prop (the live pipeline status from `useAiJobApplicationSummary`)
- Exports `PlatoGenerationStatus` type: `"textract_processing" | "extracting" | "summarizing" | "scoring" | "integrating"`
- Exports `STATUS_TO_STEP` constant mapping statuses to step indices 0-3
- 4 steps: "Processing the resume" (0), "Analyzing the candidate" (1), "Scoring against the role" (2), "Finalizing the review" (3)
- Active step is monotonic via `React.useState` + `React.useEffect` with `Math.max` -- never regresses
- Unknown/unmapped statuses (e.g., `retrying`, `awaiting_job_criteria`) are ignored -- checklist holds its last step
- Default active step is 1 (when no status maps, starts at "Analyzing" since Textract may have already completed)
- Step states: `done` (check icon), `active` (spinner), `todo` (empty circle)
- Imports `Icon` (for check mark) and `PlatoChip` (for header icon)
- Container mirrors `PlatoTabEmptyState` / `JobApplicationTabEmptyState` styling

#### C.3 `PlatoTab.tsx` -- switch data source and render `PlatoLoadingState`
*Tags: `cursor_rules/frontend/components/component_architecture.md`, `cursor_rules/frontend/react_query/react_query_queries.md`*

- [ ] C.3.1 Replace `const aiSummary = jobApplication.aiJobApplicationSummary;` (line 37) with reading from `aiJobApplicationSummaryStatus`
  - `const summaryStatus = jobApplication.aiJobApplicationSummaryStatus;`
  - `const statusValue = summaryStatus?.status;`

- [ ] C.3.2 Update `useAiJobApplicationSummary` call to get the summary ID from the status record
  - Old: `aiJobApplicationSummaryId: aiSummary?.id`
  - New: `aiJobApplicationSummaryId: summaryStatus?.aiJobApplicationSummaryId`

- [ ] C.3.3 Update all status checks throughout the component
  - `summaryExists` logic: change from `aiSummary != null` to checking `statusValue` is `"current"` or `"regenerating"` (meaning a summary exists or is being regenerated)
  - `status === "succeeded"` checks become `statusValue === "current"` (the `current` status on the status record means the summary succeeded and is current)
  - Processing status checks: the Plato tab shows generating UI when the `useAiJobApplicationSummary` hook returns a record with a non-`succeeded` status. The full summary record's status drives the generating UI, not the status record's status.
  - `renderSucceeded`: read `headline`, `scorePercentage`, `integratedRoleAnalysis` from `summaryStatus` for the `PlatoSummaryData` fields that come from it. Read `structuredData`, `criteriaResults` from `fullSummary`.
  - `renderHeaderRight`: check `statusValue === "current"` instead of `status === "succeeded"`. Check `aiSummary.stale` -- but `stale` is NOT on `AiJobApplicationSummaryStatus`. It is on the full summary record. For stale check, use `fullSummary?.stale`.

- [ ] C.3.4 Replace shimmer/`renderGenerating()` with `PlatoLoadingState`
  - Import `PlatoLoadingState` from `./Plato/PlatoLoadingState`
  - When a summary record exists (via `useAiJobApplicationSummary`) but is not `succeeded`, render `<PlatoLoadingState status={fullSummary?.status} />` instead of the shimmer animation
  - The `status` prop is the full summary record's pipeline status (e.g., `textract_processing`, `extracting`, `summarizing`, `scoring`, `integrating`), NOT the status record's `status` (which is `none`/`current`/`regenerating`)

- [ ] C.3.5 Update `generatedAgo` to use `updatedAt` from the status record
  - Old: `distanceInWords(jobApplication.aiJobApplicationSummary.createdAt)`
  - New: `distanceInWords(summaryStatus?.updatedAt)` -- the status record's `updatedAt` reflects when the latest successful summary landed (the `update_summary_status_record` callback writes denormalized fields on success, updating the timestamp)

- [ ] C.3.6 Update `hasContent` variable to use `statusValue`
  - If `statusValue` is `"current"` or `"regenerating"`, there is content. Also if the full summary is loading/has pipeline status.

#### C.4 `JobApplicationActivity.tsx` -- switch data source
*Tags: `cursor_rules/frontend/components/component_architecture.md`*

- [ ] C.4.1 Replace `jobApplication.aiJobApplicationSummary?.status === "succeeded"` (line 399) with `jobApplication.aiJobApplicationSummaryStatus?.status === "current" || jobApplication.aiJobApplicationSummaryStatus?.status === "regenerating"`
  - When status is `current` or `regenerating`, render `PlatoGeneratedReviewCallout`
  - Everything else renders `PlatoOverviewCallout`

- [ ] C.4.2 Update `PlatoGeneratedReviewCallout` props
  - Old: reads `headline`, `integratedRoleAnalysis`, `scorePercentage`, `createdAt` from `jobApplication.aiJobApplicationSummary`
  - New: reads `headline`, `integratedRoleAnalysis`, `scorePercentage` from `jobApplication.aiJobApplicationSummaryStatus`
  - `generatedAgo`: use `distanceInWords(jobApplication.aiJobApplicationSummaryStatus?.updatedAt)` -- the status record's `updatedAt` is a proxy for when the latest successful summary landed (see A.3)

- [ ] C.4.3 Update `PlatoOverviewCallout` props
  - Old: `summaryStatus={jobApplication.aiJobApplicationSummary?.status}`
  - New: derive from `jobApplication.aiJobApplicationSummaryStatus` -- see C.5
  - **No credit balance hook in `JobApplicationActivity`.** The overview no longer has a `noCredits` state.

- [ ] C.4.4 Remove dead import of `AiJobApplicationSummaryFeedItem` if present
  - Confirmed: `AiJobApplicationSummaryFeedItem` is NOT imported in `JobApplicationActivity.tsx`. No cleanup needed.

#### C.5 `PlatoOverviewCallout.tsx` -- four-state logic
*Tags: `cursor_rules/frontend/components/component_architecture.md`, `cursor_rules/core_critical_rules.md` (rules 9, 10)*

The overview callout has **four** states, not five. The `noCredits` state is dropped from the overview -- credit-related states only exist on the Plato tab.

- [ ] C.5.1 Update `PlatoOverviewCalloutProps` interface
  - Old: `summaryStatus?: string | null`
  - New: receive the status record's `status` field: `summaryStatusValue?: "none" | "current" | "regenerating" | null` + `hasResume?: boolean`
  - Remove any credit-related props

- [ ] C.5.2 Rewrite `deriveCalloutStatus` to use the four-state logic from spec
  1. `summaryStatusValue === "current"` -> return `null` (do not render; `PlatoGeneratedReviewCallout` renders instead)
  2. `summaryStatusValue === "regenerating"` -> return `null` (same; `PlatoGeneratedReviewCallout` renders with refreshing indicator)
  3. `(!summaryStatusValue || summaryStatusValue === "none") && hasResume` -> `"ask"`
  4. `(!summaryStatusValue || summaryStatusValue === "none") && !hasResume` -> `"noResume"`
  - No `processing`, `failed`, or `noCredits` states in overview. Those only exist on the Plato tab.
  - Remove the `PROCESSING_STATUSES` constant and existing processing/failed derivation.

- [ ] C.5.3 Remove `noCredits` from `PLATO_CALLOUT_STATES` and `PlatoCalloutStatus`
  - Remove the `noCredits` entry from `PLATO_CALLOUT_STATES`
  - Remove `"noCredits"` from the `PlatoCalloutStatus` type

- [ ] C.5.4 Remove `processing` and `failed` from `PLATO_CALLOUT_STATES` and `PlatoCalloutStatus`
  - Remove `"processing"` and `"failed"` entries from `PLATO_CALLOUT_STATES`
  - Remove `"processing"` and `"failed"` from the `PlatoCalloutStatus` type
  - Final `PlatoCalloutStatus`: `"ask" | "noResume"`

- [ ] C.5.5 Remove the `inlineLink` rendering logic
  - With `noCredits` removed, the `inlineLink` pattern (used for the "AI billing" link) is dead code. Remove the `inlineLink` field from `PlatoEmptyStateConfig`, the `{link}` interpolation in the render, and the `Styled.InlineLink` styled component.

- [ ] C.5.6 Remove credit-related props (`linkHref`) from `PlatoOverviewCalloutProps`
  - `linkHref` was used by the `noCredits` inline link. No longer needed.

#### C.6 `PlatoGeneratedReviewCallout.tsx` -- verify props
*Tags: `cursor_rules/frontend/components/component_architecture.md`*

- [ ] C.6.1 Verify the component's props interface
  - Currently accepts: `headline`, `roleFit`, `scorePct`, `generatedAgo`, `onClick`
  - These are passed as props from the parent, so the component itself may not need changes
  - The PARENT (`JobApplicationActivity`) changes what it passes (C.4.2)
  - `generatedAgo` continues to be a string prop -- the parent computes it from `distanceInWords(summaryStatus?.updatedAt)` instead of `distanceInWords(aiJobApplicationSummary.createdAt)`

#### C.7 `PlatoTabEmptyState.tsx` -- icon and uploader changes
*Tags: `cursor_rules/frontend/components/component_architecture.md`*

- [ ] C.7.1 Change `processing` icon from `"file-text"` to `"plato"` in `PLATO_EMPTY_STATES`
  - Line 39: `icon: "file-text"` -> `icon: "plato"`

- [ ] C.7.2 Replace the `noResume` branch (lines 106-115)
  - Old: renders `DragAndDropResumeUploader` directly
  - New: render `JobApplicationTabEmptyState` with CTA to navigate to resume tab
  - ```
    if (props.status === "noResume") {
      return (
        <JobApplicationTabEmptyState
          icon="plato"
          title="Plato needs a resume"
          message="Upload a resume on the resume tab, then come back to generate a review."
          buttonLabel="Go to resume tab"
          onClick={props.onClick}
          roomy
        />
      );
    }
    ```
  - The `onClick` for the CTA should navigate to the resume tab. This needs to be passed from `PlatoTab`.

- [ ] C.7.3 Remove `DragAndDropResumeUploader` import (line 8)

- [ ] C.7.4 Remove `onCompleteDirectUpload` and `onStartDirectUpload` from `PlatoTabEmptyStateProps` interface (lines 16-17)

- [ ] C.7.5 Update `PlatoTab.tsx` to pass resume-tab navigation as `onClick` for the `noResume` state
  - The `noResume` empty state CTA should navigate the user to the resume tab
  - Pattern: use `history.push` to navigate to the resume sub-route

---

### Phase D: Dead Code Cleanup

#### D.1 Delete `AiJobApplicationSummaryFeedItem.tsx`
- [ ] D.1.1 Delete `app/javascript/ats/src/views/jobApplications/activities/AiJobApplicationSummaryFeedItem.tsx`
  - Confirmed: not imported anywhere in the codebase (grep returned zero results outside the file itself)

#### D.2 Verify `AiJobApplicationSummaryShallowSerializer` is dead
- [ ] D.2.1 Grep for `AiJobApplicationSummaryShallowSerializer` after removing it from `JobApplicationSerializer`
  - Currently referenced ONLY in `job_application_serializer.rb` line 40
  - After A.2.1 removes that reference, the serializer file has zero consumers
  - Do NOT delete the file in this rework (separate cleanup task). It is safe to leave as dead code.

---

### Phase E: Test Plan

#### E.1 Update `spec/models/ai_job_application_summary_spec.rb`
*Tags: `cursor_rules/backend/_base.md`*

- [ ] E.1.1 Add `describe '#broadcast_status_change'` context
- [ ] E.1.2 Test: fires broadcast for each status in `BROADCAST_STATUSES`
  - Create a summary in `pending` status, then `update(status: :extracting)` (which is in `BROADCAST_STATUSES`)
  - Expect `JobChannel` to receive `broadcast_to` with the correct event and payload
  - Note: Known failure pattern #19 -- `create_credit_test_job_application` triggers `enqueue_new_job_application` which creates the status record. Use the factory-created record directly.

- [ ] E.1.3 Test: does NOT fire broadcast for `pending`, `awaiting_job_criteria`, `retrying`
  - Create summary, update to `awaiting_job_criteria`
  - Expect `JobChannel` NOT to receive `broadcast_to`

- [ ] E.1.4 Test: does NOT fire broadcast when status is unchanged
  - Create summary with status `extracting`, update a non-status attribute
  - Expect `JobChannel` NOT to receive `broadcast_to`

- [ ] E.1.5 Test: does NOT fire broadcast on create (only on update)
  - The callback is `before_update`, which by definition only fires on update, never on create. Creating a new summary triggers only `create_status_record` (`after_commit on: :create`). Verify that creating a summary does not call `broadcast_status_change`.

#### E.2 Verify existing service specs still pass
- [ ] E.2.1 Run `spec/services/ai_job_application_action/orchestrate_spec.rb`
  - The `update_columns` -> `update` change means callbacks now fire during tests
  - Callbacks require `job_application.job` to exist (for `JobChannel.broadcast_to`). Test fixtures likely already set this up. Verify.
  - If `JobChannel.broadcast_to` raises in test (e.g., no ActionCable test adapter), stub it or use `allow(JobChannel).to receive(:broadcast_to)`

- [ ] E.2.2 Run `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb`
  - Same callback concern as E.2.1

- [ ] E.2.3 Run `spec/services/ai_job_application_action/scoring/integrate_analysis_spec.rb`
  - Same callback concern as E.2.1

---

## Resolved Questions

1. **~~`after_save` vs `after_commit` for `broadcast_status_change`~~** RESOLVED
   - Spec says `before_update`. Confirmed by user. Optimistic broadcast -- fires before DB write. Codebase precedent: `before_update` on `Job` and `Organization`.

2. **~~`generatedAgo` prop on `PlatoGeneratedReviewCallout` in the overview~~** RESOLVED
   - Use `updatedAt` from the `AiJobApplicationSummaryStatus` record as a proxy. The status record's `updated_at` reflects when the latest successful summary landed (the `update_summary_status_record` callback writes denormalized fields on success, updating the timestamp). Add `updated_at` to `AiJobApplicationSummaryStatusSerializer` (task A.3). No need to add `created_at` of the summary to the status serializer.

3. **~~Credit balance in `PlatoOverviewCallout`~~** RESOLVED
   - The overview callout has **four** states, not five. Drop `noCredits` from the overview. No credit balance hook in `JobApplicationActivity`. Credit-related states (`noCredits`) only exist on the Plato tab via `PlatoTabEmptyState`. The overview never needs to know about credits.

4. **Rescue-path `update_columns` -> `update` decision** RESOLVED
   - Convert ALL `update_columns` calls in the three named files, including rescue paths. The `broadcast_status_change` callback fires for `failed` (which IS in `BROADCAST_STATUSES`), enabling real-time failure visibility. The broadcast is wrapped in its own rescue inside `broadcast_status_change`, so broadcast failures never mask pipeline errors.

---

## Risks

1. **Callback side effects during pipeline execution:** Switching to `update` fires ALL `after_commit on: :update` callbacks on every status transition, not just `succeeded`. The existing guards (`saved_change_to_status? && status_succeeded?`) on `destroy_previous_textract_results` and `update_summary_status_record` correctly filter these out. Verified safe.

2. **Double invalidation for `succeeded`:** When the pipeline completes, both the new `JobChannel` broadcast (`ai_summary_status_change`) and the existing `GlobalChannel` broadcast (`AI_SUMMARY_COMPLETE`) fire. Both invalidate `["aiJobApplicationSummary"]` and `["jobApplication"]`. React Query deduplicates, so the actual refetch only happens once per key per tick. No UI flicker expected.

3. **Test instability from `update` in rescue blocks:** If `update` fails validation in a rescue block (unlikely -- only `validates :status, presence: true`), the status will not persist AND the original error still re-raises (for `CustomErrorAiSummary`) or falls through (for other rescues). Monitor test runs.

4. **`PlatoLoadingState` default step:** When no status is mapped (e.g., component first renders before any websocket broadcast arrives), the default active step is 1 ("Analyzing the candidate"). This assumes Textract has already completed (common case for resumes that were already parsed). If Textract is the first step, the first broadcast with `textract_processing` will set active to 0 -- but `Math.max(1, 0)` means it stays at 1, visually skipping the "Processing the resume" step. This is only an issue if the component mounts after the pipeline starts but before the first broadcast. In practice, the `useAiJobApplicationSummary` query should return the current status on mount, so the initial render will have the correct status. Monitor in QA.

---

## Estimated Scope

| Area | Files | Effort |
|------|-------|--------|
| Backend model callback | 1 | Small -- ~15 lines new code |
| Backend serializer swap | 1 | Trivial -- remove 4 lines, add 2 |
| Backend status serializer + `updated_at` fix | 1 | Trivial -- add 1 attribute + 1 line in model |
| Backend `update_columns` -> `update` | 3 | Small -- mechanical find-replace, 9 call sites |
| Frontend types | 2 | Small -- type definition changes |
| Frontend websocket handler | 1 | Trivial -- add 1 case |
| Frontend new component (`PlatoLoadingState`) | 1 | Medium -- new component from handoff, compliance audit |
| Frontend component switchover | 5 | Medium -- logic rewiring across 5 components |
| Dead code cleanup | 1 | Trivial -- file deletion |
| RSpec tests | 1 | Small -- 4-5 new test cases |
| **Total** | **17 files** | **~3-4 hours implementation** |

---

## Commit Strategy

Following unit-level commits per the memory rule:

1. Backend: model callback + serializer swap + status serializer `updated_at` + `update_columns` migration (one commit -- all backend, all interdependent)
2. Frontend types (one commit)
3. Frontend websocket handler + `PlatoLoadingState` component + component switchover (one commit -- all depend on types being correct)
4. Dead code cleanup (one commit)
5. RSpec tests (can be in commit 1 alongside backend changes)
