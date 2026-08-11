# status-row display-state & denormalization (W5 + C1) — Round 1

Traced: `ai_job_application_summary.rb#record_failure:52-68` + `update_summary_status_record:82-125` → `ai_job_application_summary_status.rb` enum/counter_culture → all terminal-failure sites → FE `jobApplication.ts:4`, `PlatoTab.tsx`, `PlatoOverviewCallout.tsx`, `JobApplicationNavItem.tsx`, `JobApplicationActivity.tsx`.

## Findings

W5 + C1 are correct:
- `failed: 4` added to `AiJobApplicationSummaryStatus` enum (existing integer column; no migration; schema confirms `status` is `t.integer default 0`).
- counter_culture proc/`column_names` count only `status IN (2,3)`; `record_failure`'s status-row `.update` (current/regenerating → failed) decrements `jobs.ai_job_application_summaries_count` correctly. Summary schema confirms `error_message`/`stale` columns exist; status-row schema confirms `score_percentage`/`headline`/`integrated_role_analysis` columns exist — all cleared to `nil` per pipeline #18.
- `record_failure` mirrors `update_summary_status_record`'s `.update`-on-the-row shape, `return unless ai_job_application_summary_status` guard, logs (not raises) on `.update` failure. No bang, no fabricated fallback.
- All 8 summary-failed sites route through `record_failure` (grep-verified). Other-model `status: :failed` writes correctly untouched.
- C1 `return if stale?` at top of `update_summary_status_record`.
- FE: `jobApplication.ts:4` union gains `"failed"`; `PlatoOverviewCallout.tsx:13` inline union gains `"failed"` (the plan's W5.6.6 ripple) and falls through `deriveCalloutStatus` to `"ask"`. PlatoTab `failed` branch (`:175-186`) already renders for the auto-failed case (status row points at the failed summary → full-summary fetch enabled). NavItem/Activity gate on current/regenerating — `failed` correctly shows no fit indicator / no activity entry. No exhaustive switch breaks (grep-verified — only `||`/`===` chains and a fall-through).

No correctness issues. **`record_failure` itself has ZERO test coverage** (no `record_failure` reference anywhere in `spec/`) — see `test-coverage.md` (HIGH).
