# Slice X3 — AiJobCriteria re-trigger — Adversarial Pass 2

**Scope:** `resume_waiting_summaries` precondition, what it re-enqueues, and the fate of an `awaiting_job_criteria` summary under each criteria outcome.

**Files read this pass (chain):**
- `app/models/ai_job_criteria.rb` (full)
- `app/services/ai_job_application_action/scoring/extract_criteria.rb` (full)
- `app/jobs/extract_job_criteria_job.rb` (full)
- `app/services/ai_job_application_action/orchestrate.rb` (full)
- `app/services/ai_job_application_action/scoring/score_job_application.rb:1-70`
- `app/models/job.rb:51-52, 688-712`

---

## Verdicts on candidate-map X3 statements

### 1. CHANGELOG :107 — "`resume_waiting_summaries` after_commit `on: [:update]`, guarded `saved_change_to_status? && status_succeeded?` (`ai_job_criteria.rb:17,22`); re-enqueues `GenerateAiJobApplicationSummaryJob(textract_result_id:)` for each `awaiting_job_criteria` summary on the job (no stale filter), no requesting user."
**AGREE.**
- `ai_job_criteria.rb:17` `after_commit :resume_waiting_summaries, on: [:update]`
- `ai_job_criteria.rb:22` `return unless saved_change_to_status? && status_succeeded?`
- `ai_job_criteria.rb:24` `job.ai_job_application_summaries.where(status: :awaiting_job_criteria).find_each do |ai_job_application_summary|` — no `stale:` predicate.
- `ai_job_criteria.rb:25-27` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: ai_job_application_summary.textract_result_id)` — no `requesting_organization_user_id`.
- `job.rb:51` `has_many :ai_job_application_summaries, through: :job_applications` confirms "summaries on the job" is job-wide across all its job_applications.

### 2. CHANGELOG :108 — "`succeeded` is the ONLY callback-firing transition: every other `AiJobCriteria` status write uses `update_columns` (no callback). The succeeded write uses `.update` deliberately (`extract_criteria.rb:140`, with the in-code comment to fire the callback)."
**AGREE.**
- `extract_criteria.rb:140` `unless @ai_job_criteria.update(update_params)` (params include `status: :succeeded`, `:132-136`); preceded by comment `:138-139` "Use update (not update_columns) to fire the after_commit callback that resumes waiting summaries".
- All other status writes are `update_columns`: `extract_criteria.rb:28` (`:in_progress`), `:32` (`:failed`), `:62` (`:failed`), `:122` (`:failed`), `:146` (`:retrying`), `:151` (`:failed`), `:155` (`:failed`); `extract_job_criteria_job.rb:9` (`:failed`, exhaustion), `:28` (`:failed`, StandardError); `score_job_application.rb:44` (`:failed`); `job.rb:696` (`:pending` reset). Note `job.rb:699` creates with `:pending` via `AiJobCriteria.new` (`on: [:update]` callback does not fire on create).
- Caveat (not a dispute): the callback is `on: [:update]` AND additionally guarded by `status_succeeded?`. Even if some future code reached `succeeded` via `update_columns`, no callback would fire. The map's phrasing "succeeded is the ONLY callback-firing transition" is accurate for the current code.

### 3. CHANGELOG :109 / 5.2 dead-end :440 / 5.4 dead-end :470 — "An `awaiting_job_criteria` summary whose criteria ends `failed` has no advancing actor unless a later Orchestrate/ScoreJobApplication pass re-invokes `job.extract_job_criteria`; the `failed` transition itself never resumes it."
**AGREE.**
- Failed writes (enumerated in verdict 2) are all `update_columns` → `resume_waiting_summaries` never fires. The summary stays `awaiting_job_criteria`.
- Re-advancement is only possible if criteria is driven back to `succeeded`. The actors that re-invoke extraction toward a future succeeded: `orchestrate.rb:80` `@ai_job_application_summary.job_application.job.extract_job_criteria unless ai_job_criteria&.status_pending? || ai_job_criteria&.status_in_progress?` (fires for a `failed` criteria), and `score_job_application.rb:26` `@job.extract_job_criteria` (when blank or `status_failed?`) and `:46`. But none of these run on their own — they require a NEW Orchestrate/ScoreJobApplication pass to be triggered for that summary. The `failed` criteria transition does not itself enqueue anything. Confirmed dead end.

### 4. Part 2 :335-339 — "AiJobCriteria Re-trigger Mechanism" block.
**AGREE** with all four bullets; same line citations verified as in verdicts 1-2.

### 5. 5.4 table :466 — "`succeeded` … Writer `extract_criteria.rb:132-140` `@ai_job_criteria.update({status: :succeeded, criteria:, metadata:})` … **fires `resume_waiting_summaries`** … RESTING (terminal) → resumes all `awaiting_job_criteria` summaries"
**AGREE.** `extract_criteria.rb:132-140`; `update_params` hash is `{status: :succeeded, criteria: non_duplicates, metadata: metadata}`. Fires the callback.

### 6. 5.4 table :467 — "`retrying` Writer `extract_criteria.rb:146` `update_columns(status: :retrying)` then re-raise"
**AGREE.** `extract_criteria.rb:146` `@ai_job_criteria&.update_columns(status: :retrying)`, `:147` `raise`. No callback; an `awaiting_job_criteria` summary is NOT resumed by a `retrying` transition (retry will re-run `ExtractJobCriteriaJob` toward a future succeeded/failed).

### 7. 5.4 table :468 — "`failed` Writer `extract_criteria.rb:32,62,122,151,155`; `score_job_application.rb:44`; `extract_job_criteria_job.rb:9,28` `update_columns(status: :failed, error_message:)`"
**AGREE.** Each cited line is a `update_columns(status: :failed, ...)`. Note `extract_criteria.rb:32` message is `'Job description is blank'`, `:62` `'No criteria sections found in job description'`, `:122` `'No criteria extracted from job description'`, `:151` JSON-parse, `:155` StandardError; `score_job_application.rb:44` `'Criteria array is empty'`; job lines are exhaustion/StandardError. All `update_columns`, no callback. Confirmed.

### 8. 5.4 table :463-464 — `pending` (create) `job.rb:699-700`; `pending` (reset) `job.rb:696`.
**AGREE.** `job.rb:699` `self.ai_job_criteria = AiJobCriteria.new(job: self, status: :pending)`, `:700` `return unless ai_job_criteria.save`; `job.rb:696` `existing_ai_job_criteria.update_columns(status: :pending, error_message: nil)`. Reset uses `update_columns` (no callback) — correct, and the callback is `on: [:update]` so even a `.update` here would not resume (guard requires `status_succeeded?`).

### 9. 5.2 table :432 — "`awaiting_job_criteria` … RESTING → advanced ONLY by `AiJobCriteria#resume_waiting_summaries` (succeeded) or a later Orchestrate pass calling `extract_job_criteria`"
**AGREE.** Consistent with `ai_job_criteria.rb:22-27` and `orchestrate.rb:80` / `score_job_application.rb:26,46`.

### 10. Per-outcome fate of an `awaiting_job_criteria` summary (slice requirement — verifying the map covers each branch):
- **succeeded** → `resume_waiting_summaries` fires (`:22`), re-enqueues `GenerateAiJobApplicationSummaryJob(textract_result_id:)` (`:25-27`). Re-entry hits `orchestrate.rb:35-36` (`status_awaiting_job_criteria?` → `check_criteria_and_score`), which at `:76` sees `ai_job_criteria&.status_succeeded?` true → `run_scoring` + `run_integration`. AGREE the map describes this.
- **failed** → no callback; dead end unless re-invoked. AGREE (verdict 3).
- **retrying** → no callback; retry pass will re-run extraction. The summary stays `awaiting_job_criteria` in the interim. AGREE.
- **pending / in_progress** → these are not `update`-to-`succeeded` transitions; `resume_waiting_summaries` guard (`status_succeeded?`) is false even when the callback fires (e.g., `in_progress` is `update_columns` anyway). Summary stays `awaiting_job_criteria`, waiting for the in-flight extraction to terminate. AGREE — and the map's general framing (advanced ONLY on succeeded) covers these.
- **never-reached** (criteria never created/extracted) → `orchestrate.rb:80` only enqueues extraction `unless pending/in_progress`; if extraction was never triggered for this job, the summary sits at `awaiting_job_criteria`. Covered by the dead-end framing.

---

## Omissions (map does not state, for the X3 slice)

1. **Re-enqueue with a nil `textract_result_id`.** `ai_job_criteria.rb:26` passes `ai_job_application_summary.textract_result_id`, which is a NULLABLE column (`AiJobApplicationSummary.textract_result_id` is nullable per the candidate map's own data-model block, :363). An `awaiting_job_criteria` summary created on the no-TextractResult path (`textract_processing` summary that later advanced without a linked result) could carry `textract_result_id: nil`. `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: nil)` → `Orchestrate.new(textract_result_id: nil)` → `orchestrate.rb:6` `TextractResult.find_by(id: nil)` returns nil → `orchestrate.rb:12` `return unless @textract_result` → the re-enqueue is a silent no-op for that summary. The map's X3 section does not flag this nil-textract_result_id edge; it presents the re-enqueue as unconditionally resuming. (Whether a real `awaiting_job_criteria` summary can have nil `textract_result_id` depends on upstream linking, but the re-trigger code does not guard it.)

2. **`resume_waiting_summaries` is job-wide, not per-job_application.** `job.ai_job_application_summaries` is `has_many ... through: :job_applications` (`job.rb:51`). One criteria `succeeded` re-enqueues a job for EVERY `awaiting_job_criteria` summary across ALL job_applications of that job. The map says "for each awaiting_job_criteria summary on the job" (:107) which is technically correct but does not surface the fan-out-across-all-applications scale implication. Minor.

3. **`find_each` batching.** `ai_job_criteria.rb:24` uses `find_each` (batched, 1000 default). Not behaviorally load-bearing for the trace; noted for completeness, not a defect.

---

## Clean determination
Verdicts: all AGREE. Omissions: non-empty (items 1-2 are substantive). Therefore **clean = false**.
