# UI-polishes — Open Items

Open items raised in session `0616c160` (branch UI-polishes, ~6 hrs, ended 2026-06-18 08:06).
Problem statements only. To be worked one at a time. No fixes applied yet.

Line/timestamp references point into the session transcript
`~/.claude/projects/-Users-jessica-wrk-wrk-corp-inflow-ats/0616c160-2748-43ee-a847-23032f1178a7.jsonl`.

---

## 1. Harvey balls do not update after AI summary generation

**Problem:** Harvey balls (fit indicators) in the candidate list do not refresh after an AI summary finishes generating.

**Anchors:**
- Committed fix attempt: `a01317b01` — `ai_summary_succeeded` broadcast + invalidation in `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx`.
- Symptom still reported after the commit: L2265 / L2298 / L2353 (07:43).

**Root cause (found this session):** The full record→broadcast→invalidate→refetch→serializer chain is intact. The defect was the invalidation scope: `ai_summary_succeeded` fired `queryClient.invalidateQueries("jobApplicationsForStage")` — a bare-string prefix match that invalidates **every** stage's list. Confirmed in React Query devtools refetching all stages; the active stage's refetch is delayed behind the others.

**Fix applied (uncommitted):**
- `app/models/ai_job_application_summary.rb` — `ai_summary_succeeded` payload now includes `hiringStageId: job_application.hiring_stage_id`.
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx` — `invalidateQueries(["jobApplicationsForStage", data.payload.hiringStageId])` (targets only that stage; `roleFit` is the 3rd key element so the 2-element key prefix-matches both filtered and unfiltered variants).

**Status:** Fix applied. Verify in devtools that only the candidate's own stage refetches on succeeded.

---

## 2. False "Plato couldn't analyze {X}" failure toast on non-terminal states

**Problem:** A terminal-failure toast fires for AI summary runs that are still in flight.

**Anchors:**
- `app/jobs/generate_ai_job_application_summary_job.rb:34` — `broadcast_completion` fires on a non-terminal state.
- `app/jobs/generate_ai_job_application_summary_job.rb:61` — collapses any non-`succeeded` snapshot (e.g. `awaiting_job_criteria`, `retrying`) to `'failed'`.
- Raised: L1273 / L1296; diagnosed L1319 / L1357 (06:32–06:36). Fix explicitly not written.

**Open sub-question flagged in session:** whether the criteria-resume path re-broadcasts a success toast — i.e. whether suppressing the false-failure toast would also suppress the legitimate success toast.

**Status:** OPEN. Hold until map rewrite + test audit complete (status-flow territory).

---

## 3. Single-generate on an already-bulk-queued candidate — possible double-charge

**Problem:** Enqueueing a summary on the backend does not update front-end state, so a candidate already queued via bulk can have single Generate clicked again. Whether the credit flow double-charges in this case was never determined.

**Anchors:**
- Raised: L2241. Trace abandoned mid-flight (L2353, item 3).

**Status:** OPEN. Hold until map rewrite + test audit complete. Jessica leans toward this not being a real issue.

---

## 4. PlatoTab flashes "No resume" empty state before full record loads

**Problem:** When PlatoTab renders on shallow job application data, it flashes the `noResume` empty state even for candidates that do have a resume.

**Anchors:**
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx:187` — `(!statusValue || statusValue === "none") && !jobApplication.hasResume`.
- `app/serializers/api/v1/shallow_job_application_serializer.rb` — omits `has_resume`.
- `app/serializers/api/v1/job_application_serializer.rb:18` — includes `has_resume`.

**Constraint (Jessica):** `has_resume` must NOT be added to the shallow serializer — doing so would eager-load resume attachments and defeat the point of the shallow serializer.

**Direction (Jessica):** Handle via a dedicated fetching/loading boolean produced by the React Query hook (not by inferring loading from `hasResume` being undefined). While fetching, show the standard loading state; only render the `noResume` empty state once loading has resolved and there is genuinely no resume.

**Status:** OPEN. Not yet implemented.

---

## 5. Pre-confirm modal count + bulk-generate credit check use the unfiltered total

**Problem:** After a fit filter is applied with Select All, the move toast was corrected to the filtered count (93→11), but two other spots still use `currentStage.jobApplicationsCount` (the unfiltered total):
1. The pre-confirm modal text ("Move/Message/Generate N candidates") still shows the unfiltered count.
2. The bulk-generate credit-shortfall check uses the unfiltered count and can falsely warn "out of credits".

**Anchors:**
- `candidatesCount = currentStage.jobApplicationsCount` (frontend, the count source feeding the modal + credit check).
- Raised: L2132 (07:22). Noted as needing the filtered total surfaced to the frontend — "more work than tonight."

**Status:** OPEN. To handle (Jessica confirmed).

---

## 6. Mixed fail + defer batch reports "total failure"

**Problem:** In a bulk AI summary batch where some applicants fail and the rest defer (e.g. `succeeded=0, deferred=1, failed=1`), the result hits the `succeeded.zero? && failed.positive?` branch and reports total failure.

**Anchors:**
- `succeeded.zero? && failed.positive?` branch in the bulk-summary completion path.
- Raised as a judgment call: L1235 (06:27). The session proposed routing to `notify_complete` whenever `deferred.positive?`.

**Decision (Jessica):** From the user's perspective, zero summaries generated = total failure — skipped items + failed items = nothing actually changed. Do NOT route a zero-succeeded batch to a success/complete notification. The proposed `deferred.positive?` guard is rejected. Messaging should report total failure whenever zero summaries were generated.

**Status:** OPEN. Disposition decided; wording/implementation pending (sits in the same status-flow as the map work).

---

## 7. AI summary status indicator on null / loading state

**Problem:** As originally observed: after a deploy, what PlatoTab renders when `aiJobApplicationSummaryStatus` is null / the summary query is still loading was flagged as wrong. The exact current symptom has not been re-characterized and is not yet fully understood.

**Anchors:**
- Raised: L411 (03:17).
- The committed per-candidate scoping fix `9688ce1c1` addressed the per-candidate `showPlatoLoading` bleed, not this item.

**Status:** OPEN. Needs to be stated precisely with Jessica before any work — not yet characterized.

---

## 8. Bulk generate: exclude already-summarized + accurate processed count

**Confirmed behavior:** A candidate whose latest summary is succeeded (`AiJobApplicationSummaryStatus.status == 'current'`) must never be queued or counted. Since `'current'` stays set even when the summary goes stale, this covers succeeded-stale too — bulk does NOT regenerate stale ones; stale regeneration is a separate explicit action later (resume replacement is rare). `regenerating` candidates are out of scope here (still open — see below).

**Bug found this session (current count math):** Today an already-succeeded candidate gets a `BulkAiSummaryJobApplication` row (`processing`), is iterated, skipped from generation, marked `done` — but `on_complete` counts `succeeded` only from summaries created `>= floor_at`, so its old summary isn't counted and `failed = claimed - succeeded - deferred` reports it as **failed**. (`done` currently means "iteration ran without raising," not "succeeded".)

**Fix applied (uncommitted):**
- `app/interactors/queue_bulk_ai_summary_jobs.rb` — drop `'current'` candidates from both `ready_ids` and `input_ids` before claiming, so they get no row and are NOT counted as skipped (never offered → nothing to report).
- `app/jobs/bulk_generate_ai_summaries_job.rb` — removed the wrong "next bulk run picks it up" comment; `deferred` = "not processed this run, not a failure".

> ⚠️ UNREVIEWED: the changes below were built from decisions discussed in session, but Jessica has not reviewed the code. Treat as draft; expect feedback. Not gospel.

**Built this session (uncommitted) — accurate processed count:**
- **new** `app/javascript/shared/lib/bulkAiSummaryCount.ts` — `bulkSummaryProcessableCount({ jobApplications, itemIdsSet, itemIdsSetType, selectionCount, selectableCount })` → `{ count, isExact }`. `count` = selection minus loaded rows whose `aiJobApplicationSummaryStatus.status === 'current'`. `isExact` = `itemIdsSetType === 'included'` OR `jobApplications.length >= selectableCount` (whole stage loaded).
- `app/javascript/ats/src/views/jobApplications/JobStageMenu.tsx` — computes `processableSummaryCount` + `isProcessableCountExact`, passes both to the modal.
- `app/javascript/ats/src/views/jobApplications/BulkGenerateAiSummariesConfirmModal.tsx` — credits/shortfall + headline number use `processableCount`; three instruction states (no selection / nothing to generate / generate-N); exact vs caveat text (caveat on not-fully-loaded Select-All); Generate disabled when `processableCount === 0`.
- Confirmation toast already reads `data.queuedCount` (exact, from the mutation response) — no change needed.

Detection facts used: `useChecklist` `itemIdsSetType` is `"included"` (exact selected IDs, all loaded since you can only check loaded rows) vs `"excluded"` (select-all-minus-deselected; spans unloaded rows). Total available = `meta.count` (`selectableCount`). Prod page size = 50, one page preloaded.

**Open exploration (next session, same branch) — make the pre-confirm count exact for not-fully-loaded Select-All.** Today the modal shows "up to N" with a caveat in that case (the unloaded rows' statuses are unknown client-side). To make it exact, the backend would compute the true processable count for the selection (all-in-stage matching role-fit, minus `current`) and return it — same `current` signal as the enqueue exclusion in `QueueBulkAiSummaryJobs`, so the modal number matches what actually runs. This is the "additional exploration regarding the count" to scope next.

**Still open:** `regenerating` candidate in a selection — its latest summary is the in-flight pending row, so it'd still get a row and could collide with the single-send regen. Separate decision.

---

## Process

- Work these one at a time, with Jessica, confirming each before any code change.
- Items 1, 2, 3 (and the wording of 6) sit in the AI-summary-status record flow being remapped by the in-progress map rewrite + test audit — hold until that lands.
