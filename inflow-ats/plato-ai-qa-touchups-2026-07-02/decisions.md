# Decisions — Plato QA session 2026-07-03

Rulings Jessica actually made, with her wording where it matters. Anything not listed under DECIDED is OPEN and awaits her ruling — nothing in OPEN is agreed, even where a recommendation exists.

## DECIDED

1. **Counter fix shape: helper method, not inline gem call.** `Job#reset_ai_summaries_count` (calls `AiJobApplicationSummaryStatus.counter_culture_fix_counts(where: { jobs: { id: id } })`), invoked from `Job#reset_counters` and from `JobApplication#track_movement` for both the previous and new job on a cross-job move. IMPLEMENTED, uncommitted.

2. **`stale` column has exactly one meaning:** a newer resume exists than the one the summary was generated from. Never set it for any other purpose (explicitly rejected: setting `stale: true` to force a rescore).

3. **`SubmitResumeToTextract` stale write is explicit, not skipped.** On every resume submission, set `stale: true` on all of the candidate's summaries except the waiting row (`status: :textract_processing, stale: false, textract_result_id: nil`). Her ruling: "mark every other one as stale true. Even if they are already stale, true, it can't possibly hurt." IMPLEMENTED, uncommitted.

4. **Latest-record unification.** Every finder that previously located the waiting summary by attributes (`find_by(status: :textract_processing, stale: false)`) now reads `JobApplication#latest_ai_job_application_summary` and verifies its state — the operative summary is defined as newest by `created_at` descending, everywhere. Sites: `SubmitResumeToTextract#submit_resume`, `GetResumeTextFromTextractJob.cleanup_orphaned_summary`, `TextractResult#queue_ai_summary_job`. IMPLEMENTED, uncommitted.

5. **Rescore mechanism: virtual attribute on `JobApplication`,** following the shipped `skip_hiring_stage_message_automation` pattern (2025-03, pre-AI). Not a loose interactor context key. No `stale` writes anywhere in the rescore path.

6. **Interactor context convention:** context carries existing records and/or the full strong-params object (`params: <strong_params>`), never extracted loose scalars. Requiredness is enforced by strong params `require` at the controller boundary — `permit` whitelists only and enforces nothing.

7. **`rescore_requested` is globally required** in `bulk_ai_job_application_summary_params` (both `create` and `all_stages`). The per-stage frontend always sends `rescoreRequested: false` — placed in `BulkGenerateParams` (not defaulted inside the mutation function) because the per-stage rescore feature is being built next; no React state, literal `false` at the call site until then. Frontend part IMPLEMENTED, uncommitted.

8. **Specs are regression detection only** — they tell the author they broke their own code. Never an enforcement mechanism for contracts or code-based rules.

9. **The stashed single-candidate force-regenerate WIP is not precedent.** "Analog" means a working, possibly-reviewed pattern; stashed unreviewed code is neither.

10. **Plato AI feature code is agent-written, not Jessica-written,** and exists in staging only (no production). Existing design choices in it carry no owner authority.

## OPEN — needs Jessica's ruling

1. **Attribute name** — `ai_summary_rescore_requested` was used in the plan without being put to her.
2. **Consequence, NOT accepted:** after a successful rescore, the candidate has two `succeeded, stale: false` rows (the old review and the new one; all readers select the latest). Acceptable?
3. **Consequence, NOT accepted:** `AiJobApplicationSummaryStatus` stays `current` during regeneration (`set_initial_summary_pending` acts only on `none`/`initial_summary_pending`), so the prior review remains visible until the new one succeeds. Acceptable?
4. **Consequence, NOT accepted:** each successful rescore consumes one AI credit per candidate. Acceptable?
5. **done-vs-deferred reporting defect** — `BulkGenerateAiSummariesJob#each_iteration` sets the bulk status row to `:done` unconditionally; `generate_ai_summary_with_credit_flow` returns nothing distinguishing "generated" from "no-op early return." Jessica questioned this directly; never resolved. In scope for the rescore fix, or separate?
6. **`create` action change** — the per-stage action must also pass `params: bulk_ai_job_application_summary_params` because `QueueBulkAiSummaryJobs` will read `context.params`. Forced by the design but never explicitly put to her.
7. **Test scope** — which specs get updated/added was never approved.
8. **Mechanical placements** — where the attribute assignment sits in `each_iteration`; the `require`-then-`permit` structure in the params method; `nil` cast behavior for jobs queued before deploy.
9. **Commit separation** — whether the rescore changes commit separately from the three implemented fixes above.
