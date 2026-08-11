# Next-session starter prompt — bulk AI summary count

Branch: UI-polishes (staying on it; nothing committed).

⚠️ IMPORTANT — UNREVIEWED WORK: The changes described below were built in a prior session based on decisions discussed there, but **I (Jessica) have NOT reviewed the actual code changes.** Treat them as a draft, not as correct. I will very likely give feedback and change things. Do NOT assume any of it is right, final, or "the way it should be." Re-examine the diffs critically with me; surface anything questionable rather than building on top of it as if settled.

## What this is about
Refining the **bulk Generate AI Summaries** flow so the candidate count shown is accurate — already-reviewed candidates (those with a `current` `AiJobApplicationSummaryStatus`, i.e. a succeeded non-stale summary) are excluded because bulk skips them.

## Read first
- `~/claude-hub/inflow-ats/_in-progress/ui-polishes-open-items.md` — item #8 has the full state, decisions, and anchors. Item #1 (Harvey balls) is also relevant context.

## Uncommitted changes on the branch (all UNREVIEWED)
Backend:
- `app/interactors/queue_bulk_ai_summary_jobs.rb` — drops candidates with a `current` AiJobApplicationSummaryStatus from both `ready_ids` and `input_ids` (no row created, not counted as skipped).
- `app/jobs/bulk_generate_ai_summaries_job.rb` — comment-only: removed a wrong "next bulk run picks it up" claim about `deferred`.
- `app/models/ai_job_application_summary.rb` + `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx` — Harvey-ball fix (item #1): `ai_summary_succeeded` payload carries `hiringStageId`; handler invalidates only `["jobApplicationsForStage", hiringStageId]` instead of all stages. Plus comment renames (dropped "companion").

Frontend (the count work):
- **new** `app/javascript/shared/lib/bulkAiSummaryCount.ts` — `bulkSummaryProcessableCount(...)` → `{ count, isExact }`.
- `app/javascript/ats/src/views/jobApplications/JobStageMenu.tsx` — computes + passes `processableCount`/`isProcessableCountExact`.
- `app/javascript/ats/src/views/jobApplications/BulkGenerateAiSummariesConfirmModal.tsx` — count/credits use `processableCount`; three instruction states; exact-vs-caveat text; Generate disabled when count is 0.

## Open exploration for this session
Make the pre-confirm modal count **exact even for a not-fully-loaded Select-All** (today it shows "up to N" with a caveat because unloaded rows' statuses aren't on the client). Likely: backend computes the true processable count for the selection (all-in-stage matching the role-fit filter, minus `current`) and returns it, using the same `current` signal as the `QueueBulkAiSummaryJobs` exclusion so the displayed number matches what actually runs.

## Still open / not decided
- `regenerating` candidate in a selection — its latest summary is the in-flight pending row, so it'd still get a row and could collide with a single-send regen. Separate decision.

## Working rules for this session
- Use the `investigating-before-answering` skill before proposing anything; trace the actual code (comments in this codebase are often AI-written and wrong — don't trust them).
- Confirm before making edits. Don't commit unless asked.
- Use exact identifiers (e.g. `AiJobApplicationSummaryStatus`, never "companion").
