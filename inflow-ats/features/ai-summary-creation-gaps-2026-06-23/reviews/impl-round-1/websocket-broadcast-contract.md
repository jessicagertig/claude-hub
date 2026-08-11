# websocket-broadcast contract (W4) — Round 1

Traced: `ai_job_application_summary.rb` BROADCAST_STATUSES `:23` + `broadcast_status_change:127-138` → `generate.rb:175` (retrying writer) → `WebsocketJobChannelHandler.tsx:73-76` → `PlatoTab.tsx:157-174` → `PlatoLoadingState.tsx` STATUS_TO_STEP/union.

## Findings

W4 end-to-end is correct:
- `awaiting_job_criteria` and `retrying` added to `BROADCAST_STATUSES` (now all 10 enum values).
- `generate.rb:175` converted `update_columns(status: :retrying, ...)` → `.update(status: :retrying, error_message: e&.message)` — preserves `error_message` and `&.` safe-nav, matching the two analog retrying writers (`score_job_application.rb:129`, `integrate_analysis.rb:59`, both already `.update`). The unchecked return is consistent with the analogs (rescue-path best-effort before `raise`) — not flagged. `extract_criteria.rb:146` (on `AiJobCriteria`) correctly left untouched.
- FE: `PlatoLoadingState.tsx` adds both statuses to the `PlatoGenerationStatus` union AND `STATUS_TO_STEP` (`awaiting_job_criteria→2`, `retrying→3`). Keys match the union exactly (no TS error). `PlatoTab.tsx:163,166` already routes both to `PlatoLoadingState`. Enum values stay snake_case (rule 7-exception).
- Detail-view-only invalidation confirmed (`WebsocketJobChannelHandler.tsx:73-76`) — no list refetch storm.

Spec ripple handled: the `ai_job_application_summary_spec.rb` broadcast loop was redesigned (move-off via `:extracting` before the stub; `allow`/`have_received` to tolerate the extra `ai_summary_succeeded` broadcast on the `:succeeded` case) and the `%w[awaiting_job_criteria retrying] "does not broadcast"` block was deleted (not inverted). Suite passes.

LOW: the spec adds the broadcast-loop coverage for the two new statuses but does NOT add the explicit "`generate.rb`'s retrying path broadcasts" integration test the plan called for (TP-5.3). The unit-level loop covers the BROADCAST_STATUSES membership; the generate.rb `.update` conversion itself is exercised only indirectly. See `test-coverage.md` (LOW).

No correctness issues.
