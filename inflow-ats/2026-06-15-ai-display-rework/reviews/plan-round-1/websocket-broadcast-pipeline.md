# websocket-broadcast-pipeline -- Round 1

## Fact Check

**Plan claim P2: `BoardWwrListing#broadcast_event` at line 267-268**
- Verified: line 267 is `def broadcast_event(event = 'wwr_listing_published')`, line 268 is `JobChannel.broadcast_to(job, event: event, payload: { jobId: job.id, boardWwrListingId: id, wwrSlug: wwr_slug, publishedAt: published_at })`.

**Plan claim P2: `after_update :handle_after_update` at line 9 of `board_wwr_listing.rb`**
- Verified: line 9 is `after_update :handle_after_update`.

**Plan claim P3: `WebsocketJobChannelHandler` existing cases at lines 55-59**
- Verified: lines 55-59 handle `wwr_listing_published` / `wwr_listing_updated` and call `queryClient.invalidateQueries(["jobs", jobId])`.

**Plan claim P4: `WebsocketGlobalChannelHandler` handles `AI_SUMMARY_COMPLETE` at lines 212-228**
- Verified: lines 212-228 match. Invalidates `["jobApplication"]`, `["aiJobApplicationSummary"]`, `["organizationAiCreditBalance"]`.

**Plan claim P4: `AI_SUMMARY_FAILED` at lines 231-241**
- Verified: lines 231-241 match. Invalidates `["jobApplication"]`, `["organizationAiCreditBalance"]` (note: does NOT invalidate `["aiJobApplicationSummary"]`).

**Plan claim P5: existing callback guards at lines 51 and 60 use `saved_change_to_status? && status_succeeded?`**
- Verified: line 51 and line 60 exactly match.

**Plan claim A.1.2: `before_update :broadcast_status_change` callback**
- Verified against spec: spec says `before_update :broadcast_status_change`. Plan step A.1.2 correctly says `before_update`.

**Plan claim A.1.3: guard uses `status_changed?` (not `saved_change_to_status?`)**
- Correct rationale: in a `before_update` callback, the record is not yet saved, so `saved_change_to_status?` would return false. `status_changed?` is the correct guard for `before_update`.

**Plan claim C.1.1: new case after `docx_to_pdf_conversion_complete`**
- Verified: `docx_to_pdf_conversion_complete` is at line 69. The `default:` case is at line 73. New case goes between lines 71 and 73.

**Plan claim C.1.2: `queryClient` already in dependency array at line 78**
- Verified: line 78 is `[refetchJob, queryClient, jobId]`.

**Plan claim: `WebsocketGlobalChannelHandler` uses `queryCache` (named differently from `queryClient`)**
- Verified: line 11 uses `const queryCache = useQueryClient()`. The variable is named `queryCache` but is the same React Query client instance. This is a naming inconsistency between the two handlers but functionally identical. Not a plan issue.

## Completeness

Spec requirements this angle covers:
1. `before_update :broadcast_status_change` callback -- plan A.1.2
2. `BROADCAST_STATUSES` constant -- plan A.1.1
3. Guard: status check + constant inclusion -- plan A.1.3
4. `ap` logging after guards -- plan A.1.3
5. Broadcast via `JobChannel.broadcast_to` -- plan A.1.3
6. New `ai_summary_status_change` case in `WebsocketJobChannelHandler` -- plan C.1.1
7. Invalidates `["aiJobApplicationSummary"]` -- plan C.1.1
8. `GlobalChannel` broadcasts remain unchanged -- plan P4 (no changes section)

All covered.

## Findings

- F1 [HIGH] Plan summary (line 9) says `after_save` callback but task A.1.2 correctly says `before_update`. The summary text is stale/inconsistent with the task definition.
  - **Evidence:** Plan line 9: "a new `after_save` callback on `AiJobApplicationSummary` broadcasts status changes". Plan A.1.2: "Add `before_update :broadcast_status_change` callback".
  - **Fix:** Correct the summary to say `before_update`.

- F2 [HIGH] Plan C.1.1 invalidates `["jobApplication"]` but does not mention it in the description text. The code block shows `queryClient.invalidateQueries(["jobApplication"])` but the prose below says "Invalidates `["jobApplication"]` to refresh `aiJobApplicationSummaryStatus` on the job application" -- this is actually correct, but this invalidation needs careful validation. The `WebsocketGlobalChannelHandler` for `AI_SUMMARY_FAILED` also invalidates `["jobApplication"]` (line 239) but does NOT invalidate `["aiJobApplicationSummary"]`. The plan's new `JobChannel` broadcast for `failed` status will fire the `ai_summary_status_change` event, which invalidates BOTH queries. This is actually an improvement (the global handler misses the summary invalidation on failure). No issue, the plan is correct.
  - Reclassifying to: **Not an issue.** Withdrawn.

## Amendments Applied

- plan.md Summary section line 9: changed `after_save` to `before_update`.
