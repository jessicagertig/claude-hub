# Always-On Checks -- Round 1

## Source Accuracy

### File paths verified
All file paths referenced in the plan exist in the repo:
- `app/models/ai_job_application_summary.rb` -- exists
- `app/models/ai_job_application_summary_status.rb` -- exists
- `app/models/job_application.rb` -- exists
- `app/serializers/api/v1/job_application_serializer.rb` -- exists
- `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb` -- exists
- `app/serializers/api/v1/shallow_job_application_serializer.rb` -- exists
- `app/serializers/api/v1/ai_job_application_summary_shallow_serializer.rb` -- exists
- `app/services/ai_job_application_action/orchestrate.rb` -- exists
- `app/services/ai_job_application_action/scoring/score_job_application.rb` -- exists
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb` -- exists
- `app/models/board_wwr_listing.rb` -- exists
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx` -- exists
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` -- exists
- `app/javascript/shared/types/jobApplication.ts` -- exists
- `app/javascript/shared/types/aiJobApplicationSummary.ts` -- exists
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx` -- exists
- `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx` -- exists
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoOverviewCallout.tsx` -- exists
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoGeneratedReviewCallout.tsx` -- exists
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoTabEmptyState.tsx` -- exists
- `app/javascript/ats/src/views/jobApplications/activities/AiJobApplicationSummaryFeedItem.tsx` -- exists
- `app/javascript/shared/queryHooks/useAiJobApplicationSummary.ts` -- exists
- `app/javascript/shared/queryHooks/useJobApplication.ts` -- exists
- `spec/models/ai_job_application_summary_spec.rb` -- exists

### Class/method names verified
- `AiJobApplicationSummary` model -- confirmed at `ai_job_application_summary.rb:3`
- `AiJobApplicationSummaryStatus` model -- confirmed at `ai_job_application_summary_status.rb:3`
- `JobApplication` model -- confirmed at `job_application.rb:3`
- `Api::V1::JobApplicationSerializer` -- confirmed at `job_application_serializer.rb:3`
- `Api::V1::AiJobApplicationSummaryShallowSerializer` -- confirmed at `ai_job_application_summary_shallow_serializer.rb:3`
- `Api::V1::AiJobApplicationSummaryStatusSerializer` -- confirmed at `ai_job_application_summary_status_serializer.rb:3`
- `Api::V1::ShallowJobApplicationSerializer` -- confirmed at `shallow_job_application_serializer.rb:3`
- `BoardWwrListing#broadcast_event` -- confirmed at `board_wwr_listing.rb:267`
- `JobChannel.broadcast_to` -- used at `board_wwr_listing.rb:268`

### Line numbers verified
All line numbers referenced in the plan have been verified against the actual source files. See individual angle reviews for specific verifications.

### Schema claims verified
- `ai_job_application_summary_statuses` columns: `job_application_id`, `ai_job_application_summary_id`, `status` (integer, default 0), `score_percentage` (decimal), `headline` (string), `integrated_role_analysis` (text), `created_at`, `updated_at`. Unique index on `job_application_id`.
- `AiJobApplicationSummaryStatus` enum: `none: 0, current: 1, regenerating: 2`.
- `AiJobApplicationSummary` enum: `pending: 0, textract_processing: 1, extracting: 2, summarizing: 3, awaiting_job_criteria: 4, scoring: 5, integrating: 6, succeeded: 7, retrying: 8, failed: 9`.

## Backward Compatibility

### Consumers of modified code

1. **`AiJobApplicationSummaryShallowSerializer`** -- currently used only by `JobApplicationSerializer` line 40. After removal, zero consumers. Plan D.2 verifies this. Safe.

2. **`jobApplication.aiJobApplicationSummary` in frontend** -- grep found these consumers:
   - `jobApplication.ts` type definition -- plan B.1 removes it
   - `PlatoTab.tsx` -- plan C.2 switches it
   - `JobApplicationActivity.tsx` -- plan C.3 switches it
   - `JobApplicationListContainer.tsx` -- already uses `aiJobApplicationSummaryStatus` (not `aiJobApplicationSummary`)
   - `AiJobApplicationSummaryFeedItem.tsx` -- plan D.1 deletes the file (confirmed not imported anywhere)
   All consumers addressed.

3. **`useJobApplication` generate mutation** -- line 224 invalidates `["aiJobApplicationSummary"]`. This still makes sense after the rework: when a job application is updated, the full summary query should be refreshed.

4. **`useGenerateAiSummary` mutation** -- invalidates `["jobApplication", variables.jobApplicationId]` and `["organizationAiCreditBalance"]`. Still correct.

## Analog Completeness

The plan covers every layer of the analog pipeline:

| Layer | Analog | Plan |
|-------|--------|------|
| Status transitions | `update_columns` in pipeline services | A.3: switch to `update` |
| Model callbacks on status | `after_commit` guards on succeeded | A.1: `before_update` broadcast + A.3.4 verify existing guards |
| WebSocket broadcast | `GlobalChannel` for `AI_SUMMARY_COMPLETE` | A.1.3: `JobChannel` for intermediate statuses |
| Frontend WS handler | `WebsocketGlobalChannelHandler` | C.1: `WebsocketJobChannelHandler` new case |
| Serializer (list) | `ShallowJobApplicationSerializer` with status | No change needed (already correct) |
| Serializer (detail) | `JobApplicationSerializer` with shallow summary | A.2: swap to status |
| Frontend type | `JobApplication.aiJobApplicationSummary` | B.1: replace with `aiJobApplicationSummaryStatus` |
| Frontend consumers | Read from `aiJobApplicationSummary` | C.2-C.5: switch to `aiJobApplicationSummaryStatus` |
| Full summary query | `useAiJobApplicationSummary` | No change (ID source changes) |

## Analog Structural Matching

### Broadcast method comparison

`BoardWwrListing#broadcast_event`:
```ruby
def broadcast_event(event = 'wwr_listing_published')
  JobChannel.broadcast_to(job, event: event, payload: { jobId: job.id, boardWwrListingId: id, wwrSlug: wwr_slug, publishedAt: published_at })
end
```

Plan's `broadcast_status_change`:
```ruby
JobChannel.broadcast_to(job_application.job, event: 'ai_summary_status_change', payload: { jobApplicationId: job_application.id })
```

- Both use `JobChannel.broadcast_to` with the job as the channel target.
- Both pass `event:` and `payload:` keys.
- The payload shapes differ (WWR has listing-specific fields; summary has `jobApplicationId`). This is correct -- different domain objects.
- The analog accesses `job` directly (model has `belongs_to :job`). The plan accesses `job_application.job` (model has `belongs_to :job_application`, then traverses). Structurally equivalent.

### WebSocket handler case comparison

Existing pattern (lines 55-59):
```tsx
case "wwr_listing_published":
case "wwr_listing_updated":
  queryClient.invalidateQueries(["jobs", jobId]);
  refetchJob();
  return;
```

Plan's new case:
```tsx
case "ai_summary_status_change":
  queryClient.invalidateQueries(["jobApplication"]);
  queryClient.invalidateQueries(["aiJobApplicationSummary"]);
  return;
```

Structural match: both use `queryClient.invalidateQueries(...)` and `return`. The plan's version does not call a refetch function (like `refetchJob()`). This is correct because `invalidateQueries` triggers a refetch automatically for active queries, and the analog's `refetchJob()` is a legacy pattern that predates React Query's automatic refetch on invalidation.

### Callback guard comparison

Existing guards on `after_commit`:
```ruby
return unless saved_change_to_status? && status_succeeded?
```

Plan's guard on `before_update`:
```ruby
return unless status_changed?
return unless BROADCAST_STATUSES.include?(status)
```

Structurally consistent: both use dirty tracking + status value check. The method names differ because `before_update` uses `status_changed?` (pre-save) while `after_commit` uses `saved_change_to_status?` (post-save). Correct.

## Findings

No additional issues found beyond those identified in individual angle reviews.
