# AI Display Rework Spec

**Date:** 2026-06-15
**Branch:** `ai-frontend-work`

---

## Core Change

Stop embedding the full `AiJobApplicationSummary` in the job application serializer. Use two separate data sources:

1. **`AiJobApplicationSummaryStatus`** — lightweight record on the job application. Denormalized. Used by the overview feed and anywhere that needs quick "does a summary exist / what's the score."
2. **`useAiJobApplicationSummary`** — separate React Query call. Full structured data. Used only by the Plato tab.

---

## Backend

### Job application serializer
- Remove `aiJobApplicationSummary` association/attributes
- Add `aiJobApplicationSummaryStatus` with: `status` (none/current/regenerating), `scorePercentage`, `headline`, `integratedRoleAnalysis`
  - Analog: `ShallowJobApplicationSerializer` (`app/serializers/api/v1/shallow_job_application_serializer.rb`) already includes `ai_job_application_summary_status`

### Pipeline status transitions
- Switch `update_columns(status: ...)` to `update(status: ...)` in:
  - `orchestrate.rb`
  - `scoring/score_job_application.rb`
  - `scoring/integrate_analysis.rb`
- This allows model callbacks to fire on status changes

### Websocket broadcasts via model callback
- `before_update :broadcast_status_change` on `AiJobApplicationSummary`
  - Analog: `before_update :handle_before_update` on `Job` (`app/models/job.rb:60`) and `Organization` (`app/models/organization.rb:57`)
- `BROADCAST_STATUSES` constant: `%w[textract_processing extracting summarizing scoring integrating succeeded failed]`
- Guard: `return unless saved_change_to_status?` then `return unless BROADCAST_STATUSES.include?(status)`
- `ap` logging after both guards for lifecycle tracking
- Broadcasts `JobChannel.broadcast_to(job_application.job, event: 'ai_summary_status_change', payload: { jobApplicationId: job_application.id })`
  - Analog: `JobChannel.broadcast_to(job, event: 'wwr_listing_published', ...)` on `BoardWwrListing` (`app/models/board_wwr_listing.rb:268`)
  - Frontend analog: `WebsocketJobChannelHandler.tsx:55-59` handles `wwr_listing_published`/`wwr_listing_updated` with `queryClient.invalidateQueries`
- Skips: `pending`, `awaiting_job_criteria`, `retrying`

---

## Frontend

### WebsocketJobChannelHandler.tsx
- New case `ai_summary_status_change` → `queryClient.invalidateQueries(["aiJobApplicationSummary"])`
  - Analog: existing cases `wwr_listing_published`/`wwr_listing_updated` → `queryClient.invalidateQueries(["jobs", jobId])` (lines 55-59)

### PlatoTab.tsx
- Stop reading status from `jobApplication.aiJobApplicationSummary`
- Use `jobApplication.aiJobApplicationSummaryStatus` to determine: is there a current summary? Is it regenerating?
- `useAiJobApplicationSummary` fires on render (no succeeded gate) — provides pipeline status + full data (gate removal already done)
- Pipeline status from the summary record drives `PlatoLoadingState` (replaces shimmer)

### PlatoLoadingState.tsx (NEW — in `Plato/`)
- 4-step checklist loader, driven by live pipeline status from `useAiJobApplicationSummary`
- Steps: "Processing the resume" → "Analyzing the candidate" → "Scoring against the role" → "Finalizing the review"
- Status-to-step mapping:
  - `textract_processing` → step 0 ("Processing the resume")
  - `extracting`, `summarizing` → step 1 ("Analyzing the candidate")
  - `scoring` → step 2 ("Scoring against the role")
  - `integrating` → step 3 ("Finalizing the review")
- Monotonic: active step only advances (Math.max), never regresses
- Unknown/unmapped statuses (e.g. `retrying`, `awaiting_job_criteria`) are ignored — checklist holds its last step
- Styled to match `JobApplicationTabEmptyState` container (same border, padding, alignment — reads as one family)
- Handoff file: `/Users/jessica/Projects/genuine-article-images/PlatoLoadingState.tsx` — must be audited for codebase compliance before use

### PlatoOverviewCallout.tsx (overview feed — no summary exists)
Five states derived from `jobApplication.aiJobApplicationSummaryStatus` + `hasResume` + credit balance:

1. `current` → render `PlatoGeneratedReviewCallout` instead
2. `regenerating` → render `PlatoGeneratedReviewCallout` with refreshing indicator
3. No record/`none` + has resume → "Ask Plato to review this candidate"
4. No record/`none` + no resume → "Plato needs a resume"

No `processing`, `failed`, or `noCredits` states in overview. Those only exist on the Plato tab. No credit balance hook in `JobApplicationActivity`.

### PlatoGeneratedReviewCallout.tsx (overview feed — summary exists)
- Read `headline`, `scorePercentage`, `integratedRoleAnalysis` from `jobApplication.aiJobApplicationSummaryStatus`
- Not from the full summary record
- CTA only is clickable (already done)

### JobApplicationActivity.tsx
- Switch on `aiJobApplicationSummaryStatus.status` instead of `aiJobApplicationSummary?.status`
- `current` or `regenerating` → `PlatoGeneratedReviewCallout`
- Everything else → `PlatoOverviewCallout`

### Job application frontend type
- Remove `aiJobApplicationSummary` from the type
- Add `aiJobApplicationSummaryStatus` with: `status`, `scorePercentage`, `headline`, `integratedRoleAnalysis`

---

### Delete AiJobApplicationSummaryFeedItem
- Delete `app/javascript/ats/src/views/jobApplications/activities/AiJobApplicationSummaryFeedItem.tsx` — dead code, not imported anywhere

### PlatoTabEmptyState
- All states use Plato chip icon (`icon: "plato"`) — no more `file-text` or other icons
- noResume: stop rendering `DragAndDropResumeUploader`, use `JobApplicationTabEmptyState` with CTA to navigate to resume tab
- No inline uploading from the Plato tab

---

## Not in this rework

- Per-status generating UI labels (separate design task — depends on this rework)
- AI settings redesign (already implemented separately above)
- Filtering by fit band
- Sorting
