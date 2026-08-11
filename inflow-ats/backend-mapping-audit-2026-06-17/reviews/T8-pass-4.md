# T8 — Bulk AI summary backfill (resume-but-no-Textract): adversarial pass-4

Slice: QueueBulkAiSummaryJobs backfill for the resume-but-no-Textract case. Traced to terminal.

Files opened and traced:
- app/interactors/queue_bulk_ai_summary_jobs.rb
- app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb
- app/controllers/concerns/role_fit_filterable.rb
- app/models/job_application.rb (scopes :with_resume :114, :with_textract_results :115; has_resume :589)
- app/jobs/bulk_generate_ai_summaries_job.rb
- app/interactors/validate_ai_summary_generation.rb
- app/interactors/create_bulk_ai_summary_generation.rb
- app/services/submit_resume_to_textract.rb
- app/jobs/submit_resume_to_textract_job.rb
- app/models/textract_result.rb (generate_ai_summary_with_credit_flow :61-89)

## Verdicts on candidate-map T8 statements

### Map line 92 (controller resolves IDs server-side)
AGREE. bulk_ai_job_application_summaries_controller.rb:32-46 `resolve_job_application_ids`: included branch :34-36, hiring_stage branch :37-42 calls `apply_role_fit_filter(stage.job_applications, p[:role_fit])` :40 minus excluded :41-42. RoleFitFilterable.apply_role_fit_filter at role_fit_filterable.rb:15. Concern is `module RoleFitFilterable` role_fit_filterable.rb:10.

### Map line 93 (with_textract_results is bare joins, no text-presence check)
AGREE. job_application.rb:115 `scope :with_textract_results, -> { joins(:textract_results) }` — bare join, no `textract_job_result_text` filter. Deferral at iteration via `if result.textract_pending` bulk_generate_ai_summaries_job.rb:65-67 (`update_columns(status: :deferred)` :66). textract_pending set when text not ready: validate_ai_summary_generation.rb:59 (`context.textract_pending = true` in the else of `textract_text_ready?` :44 / :73-75).

### Map line 94 (current-status candidates dropped from both ready_ids and input_ids)
AGREE. queue_bulk_ai_summary_jobs.rb:36-40: `already_summarized_ids = AiJobApplicationSummaryStatus.where(job_application_id: ready_ids, status: :current).pluck(:job_application_id)` :36-38; `ready_ids -= already_summarized_ids` :39; `input_ids -= already_summarized_ids` :40.

### Map line 104 (backfill SubmitResumeToTextractJob has NO TEXTRACT_RESUME_PROCESSING gate; AI gate only; candidates not in current run)
AGREE. AI gate: queue_bulk_ai_summary_jobs.rb:17 `context.fail!(...) unless Flipper.enabled?(:AI_APPLICANT_SUMMARY, organization)`. Backfill loop: :28-30 `pending_textract_ids.each do |id| SubmitResumeToTextractJob.perform_later(id) end` — no Flipper check of any kind. Excluded from current run: :23 `pending_textract_ids = scope.with_resume.where.not(id: ready_ids).distinct.pluck(:id)` (resume present, but excluded from ready_ids which required `with_textract_results`).
NOTE (map citation precision): map cites the AI gate as ":17-18". Line 17 is the AI_APPLICANT_SUMMARY gate; line 18 is the separate `ai_credits_available?` gate (`context.fail!(...) unless organization.ai_credits_available?`). Both are present and both block before the backfill loop. The ":17-18" span is therefore accurate as "the gates above the loop" but conflates two distinct gates; not a dispute, the substance (no TEXTRACT_RESUME_PROCESSING gate on the loop) is correct.

### Map line 109 (no-resume candidates silently skipped at :24, counted in skipped_count, no row, no backfill)
AGREE. queue_bulk_ai_summary_jobs.rb:24 comment "Anything in input_ids not captured above has no resume and is just skipped." `ready_ids` :22 and `pending_textract_ids` :23 both require `scope.with_resume`, so a resume-less input id is in neither; it remains in `input_ids` and folds into `skipped_count = input_ids.size - claimed_ids.size` :92. No BulkAiSummaryJobApplication row, no SubmitResumeToTextractJob.

### Map line 111 (bulk reuse: credit-flow :68 early return when CreateBulkAiSummaryGeneration reuses succeeded-non-stale summary)
AGREE. create_bulk_ai_summary_generation.rb:45-48 returns the existing `active_ai_summary` (`.where.not(status: :failed).where(stale: false).order(created_at: :desc).first` :34-38) without building. textract_result.rb:68 `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?` fires for a succeeded-non-stale reused summary → no generate, no credit (credit site CreateAiCreditBalanceTransaction at :84 never reached).

## Terminal trace (resume-but-no-Textract backfill)
SubmitResumeToTextractJob.perform_later(id) (queue_bulk_ai_summary_jobs.rb:29)
 → SubmitResumeToTextractJob#perform (submit_resume_to_textract_job.rb:6-8)
 → SubmitResumeToTextract#submit_resume (submit_resume_to_textract.rb:8).
Candidate came from `with_resume` (job_application.rb:114 `joins(:resume_attachment)`), so `has_resume` (job_application.rb:589, `resume.attached?`) is true → does NOT early-exit at submit_resume_to_textract.rb:10.
 → builds TextractResult `textract_job_status: 'in_progress'` (:22), saves (:24)
 → relinks any waiting textract_processing summary (:25-26) [no-op here: a bulk-backfill candidate has no textract_processing waiting summary]
 → schedules GetResumeTextFromTextractJob (wait 2.minutes) (:27).
TERMINAL of the QueueBulkAiSummaryJobs invocation: candidate now has an in_progress TextractResult and a pending poll job; it is NOT in the current BulkGenerateAiSummariesJob batch (excluded at :23). It becomes "ready" (with_textract_results true) for a LATER bulk run, OR — after the poll succeeds — the TextractResult#queue_ai_summary_job bridge auto-path runs if should_auto_generate_ai_summaries? (out of this slice; reachable). The backfill loop itself has no advancing actor that puts the candidate into the current batch — by design, it primes for the next run.

## OMISSIONS (for the T8 backfill slice)

1. The map never states the COUNTING of resume-but-no-Textract (pending_textract) candidates in the CURRENT run. They are in `input_ids` (they have resumes, came from input) but are excluded from `ready_ids`/`working_set`, so they are NOT in `claimed_ids`, and therefore fold into `skipped_count = input_ids.size - claimed_ids.size` (queue_bulk_ai_summary_jobs.rb:92, and the empty-working-set branch :51 `context.skipped_count = input_ids.size`). The map documents the no-resume case folding into skipped_count (line 109) but never says the SAME is true of the backfilled resume-but-no-Textract candidates — even though they additionally get a SubmitResumeToTextractJob. This is the core T8 case and its counting is undocumented.

2. The map never states that pending_textract (backfill) candidates receive NO BulkAiSummaryJobApplication row in the current run. They are excluded before the create loop (working_set = ready_ids - already_claimed_ids, :47; pending_textract_ids are not in ready_ids). The map calls this out explicitly only for the no-resume case (line 109 "get NO BulkAiSummaryJobApplication row and NO backfill job"); it does not state it for the resume-but-no-Textract case (which gets no row but DOES get a backfill job — the distinguishing fact of T8).

3. The map never states that `any_textract_pending` is set from `pending_textract_ids.any?` (queue_bulk_ai_summary_jobs.rb:52 empty-set branch, and :93 normal branch) and that this flag is exactly what surfaces the resume-but-no-Textract backfill to the user via the controller JSON (`any_textract_pending: result.any_textract_pending`, bulk_ai_job_application_summaries_controller.rb:23). The flag's provenance is the pending_textract (backfill) set — the user-visible signal of the T8 case — and it is undocumented.

4. The map never states the backfill loop has NO idempotency / no de-dup guard: `pending_textract_ids.each { SubmitResumeToTextractJob.perform_later(id) }` (:28-30) enqueues unconditionally for every resume-but-no-Textract candidate every time the bulk endpoint is hit. Two bulk runs in succession (before the first poll lands a TextractResult) enqueue duplicate SubmitResumeToTextractJob for the same candidate; each run builds a NEW in_progress TextractResult (submit_resume_to_textract.rb:22, no find_or_create). No guard against this in the slice.

## clean = false (4 omissions; all verdicts AGREE)
