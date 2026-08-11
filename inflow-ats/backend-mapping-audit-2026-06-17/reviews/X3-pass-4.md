# X3 — AiJobCriteria re-trigger — Adversarial Pass 4

Re-audited from scratch against current code. Candidate map section: `backend-flow-map-2026-06-17.md:164-172`.

## Files traced
- `app/models/ai_job_criteria.rb:17,22,24-27`
- `app/jobs/generate_ai_job_application_summary_job.rb:24-32`
- `app/models/textract_result.rb:5,61-89,110-112`
- `app/services/ai_job_application_action/orchestrate.rb:14-16,35-36,68-83,85-104`
- `app/services/ai_job_application_action/scoring/extract_criteria.rb:13-14,28-35,62,122,140-155`
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb:49-53`
- `app/services/ai_job_application_action/scoring/score_job_application.rb:19-48`
- `app/models/job.rb:51,52,688-704`

## Verdicts (each candidate-map statement for X3)

### Map :165 — callback registration + guard + fan-out shape
"`resume_waiting_summaries` after_commit `on: [:update]`, guarded `saved_change_to_status? && status_succeeded?` (`ai_job_criteria.rb:17,22`); re-enqueues `GenerateAiJobApplicationSummaryJob(textract_result_id:)` for each `awaiting_job_criteria` summary on the job (no stale filter), no requesting user (`:24-27`)."
**AGREE.** `ai_job_criteria.rb:17` `after_commit :resume_waiting_summaries, on: [:update]`; `:22` `return unless saved_change_to_status? && status_succeeded?`; `:24` `job.ai_job_application_summaries.where(status: :awaiting_job_criteria).find_each`; `:25-27` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: ai_job_application_summary.textract_result_id)` — only argument is `textract_result_id`, no `requesting_organization_user_id`. No stale filter present.

### Map :166 — succeeded is the only callback-firing transition
"every other `AiJobCriteria` status write uses `update_columns` ... succeeded write uses `.update` deliberately (`extract_criteria.rb:140`)."
**AGREE.** Status writes: `job.rb:696` `update_columns(status: :pending...)`; `job.rb:699-700` `AiJobCriteria.new(...status: :pending)` + `.save` (CREATE, `on: [:update]` won't fire); `extract_job_criteria_job.rb:9,28` `update_columns(status: :failed...)`; `extract_criteria.rb:28` `update_columns(status: :in_progress)`, `:32,:62,:122,:151,:155` `update_columns(status: :failed...)`, `:146` `update_columns(status: :retrying)`; `score_job_application.rb:44` `update_columns(status: :failed...)`. Only `extract_criteria.rb:140` `@ai_job_criteria.update(update_params)` with `status: :succeeded` (`:133`) uses `.update`, comment at `:138-139` "Use update (not update_columns) to fire the after_commit callback that resumes waiting summaries."

### Map :167 — idempotency (saved_change_to_status?)
**AGREE.** `ai_job_criteria.rb:22` `return unless saved_change_to_status? && status_succeeded?`. An `.update` on an already-succeeded row not changing status returns false from `saved_change_to_status?` → no fan-out.

### Map :168 — succeeded-firing advance path (charges credit)
"re-enqueued job runs `generate_ai_summary_with_credit_flow` (`generate_ai_job_application_summary_job.rb:32`); awaiting summary not succeeded so `textract_result.rb:68` guard does not fire; Orchestrate hits `orchestrate.rb:35` `status_awaiting_job_criteria?` → `check_criteria_and_score` → `:76` `ai_job_criteria&.status_succeeded?` true → `run_scoring` (`:77`) + `run_integration` (`:78`) → succeeded; `:82` passes and `:84` `CreateAiCreditBalanceTransaction.call` charges a credit."
**AGREE.** `generate_ai_job_application_summary_job.rb:25` `find_by`, `:30` `return unless textract_result`, `:32` `generate_ai_summary_with_credit_flow`. `textract_result.rb:67` `latest_ai_summary = job_application.latest_ai_job_application_summary`, `:68` `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?` — awaiting summary is not succeeded so guard does not fire. `:74` `generate_ai_summary` → `textract_result.rb:111` `Orchestrate.new(textract_result_id: id).call`. `orchestrate.rb:15` selects latest summary, `:35` `status_awaiting_job_criteria?` → `:36` `check_criteria_and_score`; `:72` sets awaiting, `:74` loads criteria, `:76` true → `:77` `run_scoring` + `:78` `run_integration`; `run_integration` → `IntegrateAnalysis` sets `status: :succeeded` via `.update` (`integrate_analysis.rb:49-53`). Back in flow, `:77` `ai_job_application_summaries.order(created_at: :desc).first` (TextractResult-scoped `self.`); the awaiting summary belongs to this textract_result (re-enqueued with its own `textract_result_id`; association `textract_result.rb:5` `has_many :ai_job_application_summaries`), so it is found, `:82` passes, `:84` charges.

### Map :169 — failed criteria is a dead end
"An `awaiting_job_criteria` summary whose criteria ends `failed` has no advancing actor unless a later Orchestrate/ScoreJobApplication pass re-invokes `job.extract_job_criteria`; the `failed` transition itself never resumes it (all failed writes use `update_columns`)."
**AGREE.** All `failed` writes use `update_columns` (no callback): `extract_criteria.rb:32,62,122,151,155`, `extract_job_criteria_job.rb:9,28`, `score_job_application.rb:44`. Recovery actors that re-invoke extraction: `orchestrate.rb:80` `extract_job_criteria unless ...pending? || ...in_progress?`; `score_job_application.rb:26` and `:46` `@job.extract_job_criteria`. The failed transition itself never re-enqueues a waiting summary.

### Map :170 — nil textract_result_id no-op site
"`ai_job_criteria.rb:26` passes `ai_job_application_summary.textract_result_id`, nullable. When nil, the re-enqueued job no-ops at `generate_ai_job_application_summary_job.rb:30` (`return unless textract_result`), NOT at `orchestrate.rb:6/:12`; `:25` `find_by(id: nil)` nil → `:30` returns BEFORE `:32`."
**AGREE.** `generate_ai_job_application_summary_job.rb:25` `TextractResult.find_by(id: textract_result_id)` → nil for nil id; `:30` `return unless textract_result` fires before `:32`; `Orchestrate.new` never constructed.

### Map :171 — cross-application fan-out
"`ai_job_criteria.rb:24` uses `job.ai_job_application_summaries`, `has_many through: :job_applications` (`job.rb:51`); one criteria succeeded re-enqueues for EVERY `awaiting_job_criteria` summary across ALL job_applications (`find_each`)."
**AGREE.** `job.rb:51` `has_many :ai_job_application_summaries, through: :job_applications`. `ai_job_criteria.rb:24` `job.ai_job_application_summaries.where(status: :awaiting_job_criteria).find_each`.

### Map :172 — stale summaries included in fan-out
"`ai_job_criteria.rb:24` filters status only (no stale filter), so a `stale:true` summary still at `awaiting_job_criteria` is re-enqueued; on the resumed run `generate_ai_summary_with_credit_flow:67` reads `job_application.latest_ai_job_application_summary` (possibly a different, newer summary)."
**AGREE.** `ai_job_criteria.rb:24` has no stale filter. `textract_result.rb:67` `latest_ai_summary = job_application.latest_ai_job_application_summary`.

## Omissions (minor; do not by themselves require map edits, recorded for completeness)
1. **Per-outcome enumeration of pending / in_progress / retrying is implicit, not explicit.** The slice prompt asks what becomes of an `awaiting_job_criteria` summary under EACH criteria outcome. The map states (`:168`) "pending/in_progress/retrying never fire the callback at all" — correct, because those statuses are written via `update_columns` (`extract_criteria.rb:28,146`, plus `job.rb:696` pending) which fires no after_commit, OR (for the initial pending create) via `.save`/`create` which is `on: [:create]` not `on: [:update]`. The "never-reached" outcome (criteria succeeded but no summary is in `awaiting_job_criteria`) is a benign empty `find_each` — not separately documented. These are all consistent with the map; just not itemized outcome-by-outcome.
2. **`check_criteria_and_score:70 return unless summary_complete?` and the redundant `:72 update(status: :awaiting_job_criteria)` are not mentioned** in the `:168` advance-path trace. On the resumed run the summary re-enters `check_criteria_and_score`, which re-guards on `summary_complete?` (`orchestrate.rb:70`, `summary_complete?` def `:54-57`) and re-writes `awaiting_job_criteria` (`:72`) before reaching the `:76` succeeded branch. The map's stated path is accurate; these intermediate steps are simply elided.

## Conclusion
Every candidate-map statement for slice X3 is AGREE against literal code. Omissions are minor elisions (implicit per-outcome enumeration; two intermediate guard/update lines on the advance path), not contradictions and not missing behaviors. clean = false only because the two omissions are recorded; no DISPUTE.
