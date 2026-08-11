# Plain English Summary + Blast Radius — AI Summary Creation Gaps + docx→Textract Trigger

## Plain English Summary

When a candidate applies, the system is supposed to automatically have its AI ("Plato") read the resume, score the candidate against the job, and show a little summary card. Right now there are six holes in that flow:

1. **The auto-read never starts a review.** When the system is set to auto-review applicants, nothing actually creates the review record up front, so the candidate gets no summary until a person clicks "generate" by hand. This fix creates the review record immediately (in a "still reading the resume" state) so the rest of the pipeline has something to advance.
2. **Word documents get sent to the wrong reader.** The AI text-extraction service only understands PDFs, but for a `.docx` resume the system sends the raw Word file before the Word→PDF conversion finishes, so extraction silently fails and no review is ever produced. This fix makes the Word path wait until the PDF exists before sending it for extraction.
3. **A failed review looks like it's still working (or shows stale results).** There's no "failed" display state, so the card freezes on "generating" or keeps showing an old score. This fix adds a failed state and makes every failure path actually set it (clearing the old score), plus stops a stale review from overwriting good data.
4. **Two mid-pipeline states show no progress.** While the review is waiting on job-criteria extraction or retrying, the card freezes silently. This fix makes those states broadcast progress to the screen and teaches the progress stepper to render them.
5. **A reported "criteria stuck forever" bug.** Criteria extraction is queued for a background worker before the database row that the worker needs has actually been saved, so the worker can run, find nothing, and quit — leaving the criteria stuck "pending" forever, which then blocks all future reviews for that job. This fix moves the queueing to after the save commits.
6. **A lost completion notification.** When criteria finally succeed and waiting reviews resume, the system forgets who originally asked, so a person who manually requested a review never gets the "done" toast. This fix carries the requester through.

The approach is six surgical edits to an existing pipeline (not a new feature), each anchored to an existing in-codebase pattern. Three decisions were pre-approved by the orchestrator on Jessica's behalf: a failed auto-review persists as `failed` rather than being deleted; auto-review success charges one AI credit (same as manual); and the auto-review behavior applies to all auto-generate entry points uniformly.

## Blast Radius Analysis

### W1 — Auto-generate pre-creates a `textract_processing` summary
- **Behavior change:** Auto-generate applications now get a summary record at intake (previously: none until manual). On Textract success a credit is now charged (previously: none). On Textract terminal failure the auto summary persists as `failed` (previously: it was destroyed, or never existed).
- **Code modified:** new interactor `CreateAutoAiSummaryGeneration`; one call added to `JobApplication#enqueue_new_job_application`; `GetResumeTextFromTextractJob.cleanup_orphaned_summary` changes destroy→transition-to-failed.
- **Consumers/downstream affected:** the Textract bridge (`queue_ai_summary_job` if-branch), the credit-consumption path (`generate_ai_summary_with_credit_flow` → `CreateAiCreditBalanceTransaction`), the `destroy_previous_textract_results` cascade (C7), `cleanup_orphaned_summary` (C8), the status-row display.
- **If wrong:** the financial path. A double-charge, a charge on a non-summary, or a cascade-destroy of the in-flight summary would be a billing/data-correctness defect. Scope = AI-summary feature, one workflow; not the whole app.

### W2 — Chain Textract submission to docx conversion
- **Behavior change:** docx resumes no longer submit Textract at intake; Textract is submitted from `DocxToPdfJob` after conversion (success or failure). PDF resumes unchanged.
- **Code modified:** `JobApplication#enqueue_new_job_application` (branch), `DocxToPdfJob#perform` (new enqueue), `JobApplicationsController#update` T2 path (branch).
- **Consumers/downstream affected:** every Textract submit must stay `TEXTRACT_RESUME_PROCESSING`-gated (defense in depth). Recovery actors (`ValidateAiSummaryGeneration`, `QueueBulkAiSummaryJobs`) remain docx-race-exposed (explicitly out of scope).
- **If wrong:** docx resumes silently produce no review (status quo for that subset) or Textract double-submits. Scope = the docx subset of applicants; one workflow.

### W3 — Enqueue criteria extraction AFTER the Job transaction commits
- **Behavior change:** `ExtractJobCriteriaJob` enqueued post-commit instead of inside the `before_update` transaction. Trigger conditions (publish, meaningful description change) and guards (Flipper, 30s debounce, pending poison-guard) must be preserved exactly.
- **Code modified:** `Job` model — relocate `auto_extract_job_criteria`'s effect from the `before_update` chain (`handle_status_changed_to_published`, `handle_description_change`) to `handle_after_update_commit`.
- **Consumers/downstream affected:** the Job update lifecycle (publish, description edit). The out-of-txn callers (`Orchestrate#check_criteria_and_score:80`, `ScoreJobApplication:23/45`) must NOT change.
- **If wrong:** either the incident persists (criteria stuck pending → blocks all reviews for the job), or publish/description-change stops triggering criteria extraction at all. Scope = criteria extraction for a job; can cascade to every applicant on that job (amplifier).

### W4 — Broadcast `awaiting_job_criteria` and `retrying`
- **Behavior change:** transitions into these two states now broadcast to the detail card; the generate-path `retrying` write converts `update_columns`→`.update` so it broadcasts.
- **Code modified:** `AiJobApplicationSummary.BROADCAST_STATUSES`; `Summary::Generate:175` write mechanism; FE `PlatoLoadingState.STATUS_TO_STEP` (+ `PlatoGenerationStatus` union); spec inversion.
- **Consumers/downstream affected:** `WebsocketJobChannelHandler` (detail-view invalidation only — no list storm), `PlatoLoadingState` stepper, the `ai_job_application_summary_spec.rb:57-62` assertion (must invert).
- **If wrong:** the card still freezes (cosmetic) or a TS compile error blocks the FE build. Scope = the detail card; one view. The `.update` conversion at `:175` is in an error/retry path before re-raise — must preserve retry semantics.

### W5 — Status-row `failed` display state + stale guard
- **Behavior change:** a terminal-failed summary drives the status row to a new `failed` enum value (clearing denormalized score/headline/role-analysis and decrementing the counter cache); a stale summary reaching succeeded no longer copies its data onto the row.
- **Code modified:** `AiJobApplicationSummaryStatus` enum (+`failed: 4`, no migration); new `record_failure` choke-point on `AiJobApplicationSummary`; route 6 terminal-failure sites through it; C1 `return if stale?` in `update_summary_status_record`; FE `jobApplication.ts` union (+`"failed"`).
- **Consumers/downstream affected:** counter_culture `ai_job_application_summaries_count` (the new value sits outside `status IN (2,3)`); every `AiJobApplicationSummaryStatus.status` FE consumer (PlatoTab, NavItem, Activity); the existing PlatoTab `failed` branch (175-186) already renders.
- **If wrong:** the counter cache drifts (job-list counts wrong), or the row shows a wrong/stale state, or a payment-area structural change slips in. Scope = AI-summary feature + the job-list count; one workflow + one denormalized count.

### W6 — X3 re-trigger carries the requesting user
- **Behavior change:** `resume_waiting_summaries` passes `requested_by_organization_user_id` so a manually-requested, criteria-resumed summary gets its completion toast.
- **Code modified:** one line in `AiJobCriteria#resume_waiting_summaries`.
- **Consumers/downstream affected:** `GenerateAiJobApplicationSummaryJob.broadcast_completion` (toast). No credit-charging change.
- **If wrong:** a missing toast (cosmetic) or, if it accidentally altered charging, a billing defect. Scope = one notification; smallest blast radius.

**Overall:** No new tables, no migration (W5 is a Rails enum value on an existing integer column). The highest-risk slices are W1 (touches the credit path + the C7/C8 cascade) and W3 (can cascade to all applicants on a job). The financial path (W1 D2 / W6) and the counter-cache (W5) are the two correctness-critical surfaces.
