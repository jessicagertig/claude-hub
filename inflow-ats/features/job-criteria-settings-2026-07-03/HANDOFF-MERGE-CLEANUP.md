# Handoff — job-criteria post-merge cleanup + guard decision (2026-07-09)

**Worktree:** `/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings`, branch `job-criteria-settings-qa`, HEAD `0956bcd4a` "Merge in develop" (Jessica committed the develop merge). Tree clean. **DO NOT COMMIT anything — leave all cleanup uncommitted for Jessica's review.**

**Feature status:** QA APPROVED (all 5 layers, qa-run-3, `reviews/QA-COMPLETE.md`). Feature is done; this handoff is only about a post-merge cleanup + a scope decision.

## Merge resolutions Jessica already made (committed in 0956bcd4a)
- `bulk_generate_ai_summaries_job.rb`: kept OURS — validation-failure → `Rails.logger.error` + `update_columns(status: :failed)` + return (not develop's `:deferred`).
- `extract_criteria.rb`: took DEVELOP's — literal error strings + `@ai_job_criteria.fail_waiting_summaries` on each failure path (:33/:64/:125).
- `ai_job_criteria.rb`: auto-merged — has BOTH our `ZERO_CRITERIA_*` constants + `zero_criteria_failure?` guard AND develop's `fail_waiting_summaries`.
- Jessica wants `fail_waiting_summaries` KEPT.

## The open decision (Jessica leaning toward REMOVING the review guard)
Jessica is questioning whether our zero-criteria REVIEW-BLOCKING guard was in scope. She says: she doesn't remember it in spec, she's already improved that process elsewhere, she does NOT want a "don't-start-a-doomed-review" guard right now, and it's adding confusion. She has NOT given a final remove/keep decision. She also earlier said "just include them all" re the duplicate string lists, then pivoted to "leave it the way develop has it."

**Provenance (for honesty, not to argue):** the guard WAS SPEC §6 — feature requirement #4, "no new AI summary reviews may start while the job's latest extraction found zero criteria." It traces to a requirement Jessica set early in this feature. She is free to drop it now.

## KEY TECHNICAL MAP — answer to "is that the only guard you were using it in?": NO. `AiJobCriteria#zero_criteria_failure?` has TWO distinct consumers:

**A. The review-blocking guard (what she may remove) — via `Job#zero_criteria_extraction_failure?` (job.rb:697):**
- `ValidateAiSummaryGeneration` (context.fail! when zero-criteria)
- `ValidateAutoAiSummaryGeneration` (same)
- `QueueBulkAiSummaryJobs` (bulk fail-fast)
- `TextractResult#generate_ai_summary_with_credit_flow` (funnel guard, before `extract_job_criteria_if_needed`)

**B. The FRONTEND flag `zeroCriteriaFailure` (MUST STAY — it's the feature's "No criteria found" empty-state UI):**
- `app/jobs/extract_job_criteria_job.rb:55` — WebSocket broadcast payload `zeroCriteriaFailure: ai_job_criteria.zero_criteria_failure?`
- `app/serializers/api/v1/job_ai_job_criteria_serializer.rb` — the `zeroCriteriaFailure` serializer attribute (via `Job#zero_criteria_extraction_failure?`)
- Frontend consumes it: `useAiJobCriteria.ts:14`, `JobCriteriaSection.tsx:75` (the zero-found empty state).

**So if Jessica removes the review guard:** delete the guard calls in the 4 sites in (A) ONLY. KEEP `zero_criteria_failure?`, `zero_criteria_extraction_failure?`, the constants, and everything in (B) — the frontend flag/empty-state is core feature and unrelated to the review-blocking decision.

## Duplicate magic-string mess (the "extra constants" Jessica dislikes)
Same strings live in 3 places: `AiJobCriteria` `ZERO_CRITERIA_*` constants (+ `ZERO_CRITERIA_ERROR_MESSAGES` guard list); `AiJobApplicationSummary::JOB_CRITERIA_ERROR_MESSAGES` (develop, literals; powers `failed_due_to_no_job_criteria?` → serialized to frontend); `extract_criteria.rb` literal writers.
- Guard list = [no-sections, none-extracted, empty-array]. Summary list = [blank-description, no-sections, none-extracted]. Deliberately different subsets.
- Develop's parallel system (KEEP): `fail_waiting_summaries`, `failed_due_to_no_job_criteria?`, `JOB_CRITERIA_ERROR_MESSAGES`.
- Cleanup, IF Jessica wants it: one source of truth for the strings. But ~15 spec files reference `AiJobCriteria::ZERO_CRITERIA_NONE_EXTRACTED_ERROR_MESSAGE` / `ZERO_CRITERIA_ERROR_MESSAGES` (spec/models/ai_job_criteria_spec.rb, textract_result_ai_trigger_spec, extract_job_criteria_job_spec, job_ai_job_criteria_serializer_spec, bulk_generate_ai_summaries_job_spec, ai_job_criteria_controller_spec, queue_bulk_ai_summary_jobs_spec, validate_auto_ai_summary_generation_spec, validate_ai_summary_generation_spec, bulk_ai_job_application_summaries_controller_spec). Renaming the constants ripples into all of them — keep constant NAMES to avoid it.

## Next session
1. Get Jessica's final decision: (a) REMOVE the review-blocking guard (sites in A) — yes/no? (b) duplicate-strings cleanup — do it, or leave as develop has it?
2. Read `cursor_rules/core_critical_rules.md` + relevant area files BEFORE editing (her standing rule). AI-related files don't count as convention analogs.
3. Make minimal, uncommitted edits. Do not break the ~15 specs referencing the constants. **Do not commit.**
