# Always-On Checks -- Round 1

## Source Accuracy

### File paths
All 17+ file paths in the plan verified against live source. All exist and contain the referenced content.

### Line numbers
All line numbers independently verified by reading the actual files:
- `ai_job_application_summary.rb`: enum at lines 10-21, callbacks at lines 27-29, guards at lines 50-51 and 60, `update_columns` at line 65 -- ALL CONFIRMED
- `job_application_serializer.rb`: has_one at line 40, method override at lines 42-44 -- CONFIRMED
- `orchestrate.rb` line 72 -- CONFIRMED
- `score_job_application.rb` lines 23, 32, 115, 120, 124 -- ALL CONFIRMED
- `integrate_analysis.rb` lines 59, 64, 68 -- ALL CONFIRMED
- `WebsocketJobChannelHandler.tsx` lines 55-59, 78 -- CONFIRMED
- `WebsocketGlobalChannelHandler.tsx` lines 212-228, 231-241 -- CONFIRMED
- `jobApplication.ts` lines 1, 13 -- CONFIRMED
- `aiJobApplicationSummary.ts` line 3 (status type) -- CONFIRMED
- `PlatoTab.tsx` line 37 -- CONFIRMED
- `JobApplicationActivity.tsx` line 399 -- CONFIRMED
- `PlatoTabEmptyState.tsx` lines 8, 16-17, 39, 106-114 -- CONFIRMED
- Handoff file `/Users/jessica/Projects/genuine-article-images/PlatoLoadingState.tsx` -- EXISTS

### Method/class names
- `AiJobApplicationSummaryShallowSerializer` -- exists, correctly identified
- `AiJobApplicationSummaryStatusSerializer` -- exists, correctly identified
- `JobChannel.broadcast_to` -- confirmed on `BoardWwrListing` line 268
- `status_changed?` vs `saved_change_to_status?` -- correctly distinguished by callback context

### Enum values
- `AiJobApplicationSummary` enum: 10 values (pending through failed) -- CONFIRMED
- `AiJobApplicationSummaryStatus` enum: `none: 0, current: 1, regenerating: 2` -- CONFIRMED
- Plan B.2.1 corrected status union type matches Ruby enum -- CONFIRMED

### Database columns
- `ai_job_application_summary_statuses` table: all columns match serializer exposure -- CONFIRMED from schema.rb

## Backward Compatibility

### `AiJobApplicationSummaryFeedItem.tsx`
- Not imported anywhere (grep zero results). Plan D.1.1 deletes it. CONFIRMED safe.

### `AiJobApplicationSummaryShallowSerializer`
- Only referenced in `job_application_serializer.rb:40`. After A.2.1, zero consumers. Plan D.2.1 verifies this. CONFIRMED.

### `useJobApplication` mutation invalidation
- `useUpdateJobApplication` at line 224 invalidates `["aiJobApplicationSummary"]`. Still correct. No change needed.

### All frontend `aiJobApplicationSummary` references
- All references accounted for: `jobApplication.ts` (removed by B.1), `PlatoTab.tsx` (switched by C.3), `JobApplicationActivity.tsx` (switched by C.4), `WebsocketGlobalChannelHandler.tsx` (invalidation key -- stays), `useJobApplication.ts` (invalidation key -- stays), `useAiJobApplicationSummary.ts` (hook -- stays). No orphaned references.

## Analog Matching

### Serializer swap
- `ShallowJobApplicationSerializer` pattern exactly matched by the new `JobApplicationSerializer` change. CORRECT.

### Broadcast shape
- Analog (`BoardWwrListing#broadcast_event`): `JobChannel.broadcast_to(job, event: event, payload: { ... })`. New: same structure with `job_application.job` as target and `{ jobApplicationId: ... }` as payload. CORRECT.

### WebSocket handler case
- Analog: switch/case with `queryClient.invalidateQueries`. New case matches existing pattern. CORRECT.

### Callback type deviation
- Analog uses `after_update`. New uses `before_update`. Intentional deviation per spec. Known resolved decision. NOT a finding.

## Findings

No issues found.
