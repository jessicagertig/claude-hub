# Slice X3 — AiJobCriteria re-trigger — Adversarial Pass 3

Candidate map section reviewed: `backend-flow-map-2026-06-17.md` lines 141-146 ("AiJobCriteria re-trigger (X3)").

Re-read from scratch against current code. Files traced:
`ai_job_criteria.rb:17,21-29` -> `extract_criteria.rb:28,32,62,122,140,146,151,155` -> `job.rb:51,688-704` -> `generate_ai_job_application_summary_job.rb:24-32` -> `textract_result.rb:61-89,110-112` -> `orchestrate.rb:6-49,68-83`.

## Map claim verdicts

### Claim 1 (line 142)
> `resume_waiting_summaries` after_commit `on: [:update]`, guarded `saved_change_to_status? && status_succeeded?` (`ai_job_criteria.rb:17,22`); re-enqueues `GenerateAiJobApplicationSummaryJob(textract_result_id:)` for each `awaiting_job_criteria` summary on the job (no stale filter), no requesting user (`:24-27`).

**AGREE.** `ai_job_criteria.rb:17` `after_commit :resume_waiting_summaries, on: [:update]`; `:22` `return unless saved_change_to_status? && status_succeeded?`; `:24` `job.ai_job_application_summaries.where(status: :awaiting_job_criteria).find_each do |ai_job_application_summary|` (no stale clause); `:25-27` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: ai_job_application_summary.textract_result_id)` — no `requesting_organization_user_id` arg.

### Claim 2 (line 143)
> `succeeded` is the ONLY callback-firing transition: every other `AiJobCriteria` status write uses `update_columns` (no callback). The succeeded write uses `.update` deliberately (`extract_criteria.rb:140`, with the in-code comment to fire the callback).

**AGREE.** All status writes located across `app/`:
- `extract_criteria.rb:28` `update_columns(status: :in_progress)`, `:32/:62/:122` `update_columns(status: :failed,...)`, `:146` `update_columns(status: :retrying)`, `:151/:155` `update_columns(status: :failed,...)` — all `update_columns`.
- `extract_criteria.rb:140` `@ai_job_criteria.update(update_params)` with `status: :succeeded` (`:133`); comment `:138-139` "Use update (not update_columns) to fire the after_commit callback that resumes waiting summaries."
- `job.rb:696` `update_columns(status: :pending,...)` — update_columns (no callback).
- `job.rb:699-700` `AiJobCriteria.new(... status: :pending)` + `.save` — a CREATE, callback is `on: [:update]` only, does not fire.
- `extract_job_criteria_job.rb:9,28` `update_columns(status: :failed,...)`.
- `score_job_application.rb:44` `update_columns(status: :failed,...)`.
Only `extract_criteria.rb:140` is an `.update` on an existing record transitioning to `succeeded`. Claim holds.

### Claim 3 (line 144)
> NEW (dead end) — An `awaiting_job_criteria` summary whose criteria ends `failed` has no advancing actor unless a later Orchestrate/ScoreJobApplication pass re-invokes `job.extract_job_criteria`; the `failed` transition itself never resumes it (all failed writes use `update_columns`).

**AGREE.** `failed` writes (`extract_criteria.rb:32,62,122,151,155`; `extract_job_criteria_job.rb:9,28`; `score_job_application.rb:44`) are all `update_columns` → no `resume_waiting_summaries`. The only actor that re-invokes extraction is `orchestrate.rb:80` `extract_job_criteria unless ai_job_criteria&.status_pending? || ai_job_criteria&.status_in_progress?`, reached only when `check_criteria_and_score` runs again. So a `failed`-criteria awaiting summary rests with no advancing actor from the criteria failure itself.

### Claim 4 (lines 145) — DISPUTE on mechanism
> NEW (nil textract_result_id no-op) — `ai_job_criteria.rb:26` passes `ai_job_application_summary.textract_result_id`, a nullable column. When nil, `GenerateAiJobApplicationSummaryJob` -> `Orchestrate.new(textract_result_id: nil)` -> `orchestrate.rb:6` `TextractResult.find_by(id: nil)` is nil -> `orchestrate.rb:12` `return unless @textract_result`. The re-trigger silently no-ops for that summary.

**DISPUTE.** The TERMINAL (silent no-op) is correct, but the cited mechanism is wrong: the job NEVER reaches `Orchestrate`. `GenerateAiJobApplicationSummaryJob#perform(textract_result_id:, ...)` (`generate_ai_job_application_summary_job.rb:24`) runs `:25` `textract_result = TextractResult.find_by(id: textract_result_id)` then `:30` `return unless textract_result`. With `textract_result_id: nil`, the job returns at `:30`, BEFORE `:32` `textract_result.generate_ai_summary_with_credit_flow`, so `generate_ai_summary` (`textract_result.rb:110-112`) and therefore `Orchestrate.new(...)` are never constructed. Correction: the no-op happens at the job guard `generate_ai_job_application_summary_job.rb:30`, not at `orchestrate.rb:6/:12`.

### Claim 5 (line 146)
> NEW (cross-application fan-out) — `ai_job_criteria.rb:24` uses `job.ai_job_application_summaries`, which is `has_many through: :job_applications` (`job.rb:51`). One criteria `succeeded` re-enqueues a job for EVERY `awaiting_job_criteria` summary across ALL job_applications of the job, not just one (`find_each` batched iteration).

**AGREE.** `job.rb:51` `has_many :ai_job_application_summaries, through: :job_applications`; `ai_job_criteria.rb:24` `.where(status: :awaiting_job_criteria).find_each`. One row's `succeeded` fans out one enqueue per awaiting summary across all the job's applications.

## Omissions

1. **Per-criteria-outcome branch table is incomplete.** The slice prompt asks for the fate of an `awaiting_job_criteria` summary under EACH criteria outcome (succeeded / failed / retrying / pending / in_progress / never-reached). The map only documents `failed` (Claim 3) and the nil-textract no-op (Claim 4). It omits:
   - **succeeded (the firing case):** `resume_waiting_summaries` fires ONLY on criteria `succeeded` (`ai_job_criteria.rb:22`). The re-enqueued job runs `generate_ai_summary_with_credit_flow` (`generate_ai_job_application_summary_job.rb:32`); the awaiting summary is not succeeded so the early-return guard `textract_result.rb:68` does NOT fire; `generate_ai_summary` -> `Orchestrate` -> `orchestrate.rb:35` `status_awaiting_job_criteria?` branch -> `check_criteria_and_score` -> `:76` `ai_job_criteria&.status_succeeded?` true -> `run_scoring` (`:77`) + `run_integration` (`:78`) -> summary advances to `succeeded`. This is the actual advancing path the re-trigger exists to drive — entirely absent from the X3 section.
   - **pending / in_progress / retrying:** these never fire the callback at all (only `succeeded` does), so an awaiting summary is never resumed by them — also unstated.
2. **Credit consumption on the resumed path.** When the resumed awaiting summary reaches `succeeded` via the re-trigger, `generate_ai_summary_with_credit_flow:82` passes and `:84` `CreateAiCreditBalanceTransaction.call(summary: ...)` charges a credit. The X3 section says nothing about the re-trigger leading to a credit charge.
3. **`saved_change_to_status?` is load-bearing for idempotency.** `ai_job_criteria.rb:22` requires `saved_change_to_status?` in addition to `status_succeeded?`. An `.update` on an already-`succeeded` row that does not change `status` (e.g. re-saving same status) would NOT re-fire the fan-out. The map quotes the guard but does not call out that a no-status-change update is a non-firing case.
4. **Stale awaiting summaries are included.** Claim 1 correctly notes "no stale filter," but the X3 section does not state the consequence: a `stale:true` summary still sitting at `awaiting_job_criteria` is ALSO re-enqueued (`ai_job_criteria.rb:24` filters on status only). On the resumed run, `generate_ai_summary_with_credit_flow:67` reads `job_application.latest_ai_job_application_summary` (the newest, possibly a different summary), so the resumed run may operate on a different summary than the one that was enqueued.

## clean
false — Claim 4 is a DISPUTE (wrong mechanism) and there are omissions.
