# Adversarial Review — Slice X3 (AiJobCriteria re-trigger / resume_waiting_summaries) — Pass 6

**Reviewed against:** `/Users/jessica/claude-hub/inflow-ats/backend-mapping-audit-2026-06-17/backend-flow-map-2026-06-17.md`
**Code re-read from scratch.** Trace chain:
`ai_job_criteria.rb:17,21-29` → `job.rb:51` (`has_many :ai_job_application_summaries, through: :job_applications`) → `generate_ai_job_application_summary_job.rb:24-34` → `textract_result.rb:61-89` (`generate_ai_summary_with_credit_flow`) → `textract_result.rb:110-112` (`generate_ai_summary` → Orchestrate) → `orchestrate.rb:9-50,68-104` → `score_job_application.rb`, `integrate_analysis.rb:51-53` → `extract_criteria.rb:132-156` (succeeded `.update` `:140`, all-other `update_columns`) → `extract_job_criteria_job.rb:5-29` → `job.rb:688-703` (`extract_job_criteria`).

## Verdicts on candidate-map X3 statements

### Map :221 / :511-512 — callback registration + guard + fan-out shape
> "`resume_waiting_summaries` after_commit `on: [:update]`, guarded `saved_change_to_status? && status_succeeded?` (`ai_job_criteria.rb:17,22`); re-enqueues `GenerateAiJobApplicationSummaryJob(textract_result_id:)` for each `awaiting_job_criteria` summary on the job (no stale filter), no requesting user (`:24-27`)."

**AGREE.** `ai_job_criteria.rb:17` `after_commit :resume_waiting_summaries, on: [:update]`; `:22` `return unless saved_change_to_status? && status_succeeded?`; `:24` `job.ai_job_application_summaries.where(status: :awaiting_job_criteria).find_each do |...|`; `:25-27` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: ai_job_application_summary.textract_result_id)` — no `where(stale:)`, no `requesting_organization_user_id`.

### Map :222 / :796 — succeeded is the only callback-firing transition
> "`succeeded` is the ONLY callback-firing transition: every other `AiJobCriteria` status write uses `update_columns`. The succeeded write uses `.update` deliberately (`extract_criteria.rb:132-140`)."

**AGREE.** A codebase-wide grep for non-`update_columns` `.update` on `ai_job_criteria` returns exactly one hit: `extract_criteria.rb:140` `unless @ai_job_criteria.update(update_params)` (params `:132-136`, in-code comment `:138-139`). All other writes use `update_columns`: `job.rb:696` (pending reset), `extract_criteria.rb:28` (in_progress), `:32/:62/:122/:151/:155` (failed/parse), `:146` (retrying), `score_job_application.rb:44` (failed), `extract_job_criteria_job.rb:9/:28` (failed). `job.rb:699-700` is a create (`AiJobCriteria.new(... status: :pending)` + save), `on:[:update]` does not fire.

### Map :223 — idempotency via saved_change_to_status?
> "`ai_job_criteria.rb:22` also requires `saved_change_to_status?`, so an `.update` on an already-`succeeded` row that does not change status would NOT re-fire the fan-out."

**AGREE.** `:22` `return unless saved_change_to_status? && status_succeeded?`. `saved_change_to_status?` is Rails dirty-tracking (framework boundary); false when status unchanged.

### Map :224 / :513 — succeeded-firing advance path (charges credit, awaiting-is-newest)
> "the re-enqueued `GenerateAiJobApplicationSummaryJob` runs `generate_ai_summary_with_credit_flow` (`generate_ai_job_application_summary_job.rb:32`); the awaiting summary is not succeeded so the `textract_result.rb:68` guard does not fire; `Orchestrate` hits the `orchestrate.rb:35` `status_awaiting_job_criteria?` branch → `check_criteria_and_score` ... re-executes `:70` ... and the redundant `:72` ... before reaching `:76` ... true → `run_scoring` (`:77`) + `run_integration` (`:78`) → succeeded ... `:82` passes and `:84` `CreateAiCreditBalanceTransaction.call` charges a credit."

**AGREE (for the awaiting-is-newest fork, which line 230/231 scopes it to).** Verified: `generate_ai_job_application_summary_job.rb:32` calls `generate_ai_summary_with_credit_flow`; `textract_result.rb:67-68` reads `latest_ai_job_application_summary` and `return if status_succeeded? && !stale?`; Orchestrate `:14-15` selects newest, `:35` `status_awaiting_job_criteria?` → `check_criteria_and_score` (`:68`): `:69` not-failed, `:70` `return unless summary_complete?` (passes — headline+summary_text present), `:72` `update(status: :awaiting_job_criteria)`, `:74-76` `ai_job_criteria&.status_succeeded?` now true → `:77` run_scoring + `:78` run_integration → `integrate_analysis.rb:51,53` `.update(status: :succeeded)`; back in credit flow `textract_result.rb:77` (TextractResult-scoped on the firing result, which IS the awaiting summary's own textract_result via the `:26` re-enqueue arg) finds the now-succeeded summary, `:82` passes, `:84` `CreateAiCreditBalanceTransaction.call`. **Caveat (already captured at :230):** the phrase "the awaiting summary is not succeeded so the `:68` guard does not fire" conflates the awaiting summary with `latest_ai_job_application_summary`; `:68` reads the NEWEST summary. The statement is correct only because in this fork awaiting==newest. Line :230 explicitly corrects the general framing, so the map as a whole is accurate; flagged here for completeness, not a standalone DISPUTE.

### Map :225 / :622 / :656 — failed-criteria dead end
> "An `awaiting_job_criteria` summary whose criteria ends `failed` has no advancing actor unless a later Orchestrate/ScoreJobApplication pass re-invokes `job.extract_job_criteria`; the `failed` transition itself never resumes it (all failed writes use `update_columns`)."

**AGREE.** All `failed` writes are `update_columns` (cited above) → no `after_commit` → no `resume_waiting_summaries`. `score_job_application.rb:46` and orchestrate `:80` are the re-invocation paths that can lead to a later succeeded.

### Map :226 — benign empty fan-out
> "When criteria reaches `succeeded` with ZERO `awaiting_job_criteria` summaries on the job, the `find_each` at `ai_job_criteria.rb:24` iterates nothing — a benign no-op."

**AGREE.** `:24` `where(status: :awaiting_job_criteria).find_each` — empty relation iterates nothing.

### Map :227 / :512 — nil textract_result_id no-op site
> "`ai_job_criteria.rb:26` passes `ai_job_application_summary.textract_result_id`, a nullable column. When nil, the re-enqueued job no-ops at `generate_ai_job_application_summary_job.rb:30` (`return unless textract_result`), NOT at `orchestrate.rb:6/:12`. `:25` `TextractResult.find_by(id: textract_result_id)` is nil → `:30` returns BEFORE `:32` ... so `Orchestrate.new` is never constructed."

**AGREE.** Schema `db/schema.rb:149` `t.bigint "textract_result_id"` (nullable, no `null:false`). `generate_ai_job_application_summary_job.rb:25` `find_by(id: nil)` → nil → `:30` `return unless textract_result` before `:32`. Orchestrate not constructed.

### Map :228 / :512 — cross-application fan-out
> "`ai_job_criteria.rb:24` uses `job.ai_job_application_summaries`, which is `has_many through: :job_applications` (`job.rb:51`). One criteria `succeeded` re-enqueues a job for EVERY `awaiting_job_criteria` summary across ALL job_applications of the job."

**AGREE.** `job.rb:51` `has_many :ai_job_application_summaries, through: :job_applications`; `find_each` (`:24`) batches across all matching rows job-wide.

### Map :229 — stale summaries included in fan-out
> "`ai_job_criteria.rb:24` filters on `status` only (no stale filter), so a `stale:true` summary still at `awaiting_job_criteria` is re-enqueued; on the resumed run `generate_ai_summary_with_credit_flow:67` reads `job_application.latest_ai_job_application_summary` (possibly a different, newer summary)."

**AGREE.** `:24` query has no `stale` predicate. `textract_result.rb:67` reads `latest_ai_job_application_summary` (`job_application.rb:31` `has_one ... -> { order(created_at: :desc) }`).

### Map :230 / :513 — newest-summary re-selection is the advance-vs-dead-end mechanism
> "The re-enqueued job carries ONLY `textract_result_id:` ... `generate_ai_summary_with_credit_flow` ... reads `job_application.latest_ai_job_application_summary` (`textract_result.rb:67`) and `Orchestrate#call` re-selects `...order(created_at: :desc).first` (`orchestrate.rb:15`) — the NEWEST summary, not the awaiting one. Fork: awaiting-is-newest → advances; a DIFFERENT newer succeeded-and-non-stale → `textract_result.rb:68` guard returns → awaiting row never advanced (silent dead end)."

**AGREE.** `ai_job_criteria.rb:25-27` carries only `textract_result_id`. `textract_result.rb:67` reads `latest_ai_job_application_summary`; orchestrate `:15` `@job_application.ai_job_application_summaries.order(created_at: :desc).first`. Guard `:68` `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?` returns on a newer succeeded-non-stale summary — awaiting row stranded.

### Map :231 / :513 — no completion toast on the resumed run
> "Because the re-enqueue passes no `requesting_organization_user_id` (`ai_job_criteria.rb:25-27`), on reaching `succeeded` `generate_ai_job_application_summary_job.rb:34` (`broadcast_completion ... if requesting_organization_user_id`) is skipped — NO `AI_SUMMARY_COMPLETE` toast."

**AGREE.** `:34` `broadcast_completion(textract_result, requesting_organization_user_id) if requesting_organization_user_id`; param defaults nil at `:24` and is unset by the re-enqueue. No broadcast.

### Map :194 — resuming actor for awaiting_job_criteria
> "An `awaiting_job_criteria` summary is resumed to terminal by `AiJobCriteria#resume_waiting_summaries` (`ai_job_criteria.rb:17,22-27`), which re-enqueues `GenerateAiJobApplicationSummaryJob` when the criteria reaches `succeeded`."

**AGREE.** Consistent with `:17,22-27` above.

### Map :649-654 — AiJobCriteria.status state table
> pending(create) `job.rb:699-700`; pending(reset) `job.rb:696`; succeeded `extract_criteria.rb:132-140` fires `resume_waiting_summaries`; failed `extract_criteria.rb:32,62,122,151,155; score_job_application.rb:44; extract_job_criteria_job.rb:9,28` `update_columns`.

**AGREE.** Every cited write verified at the cited line (see :222 verdict). `retrying` (`extract_criteria.rb:146`, `update_columns`) is implied by the "every other write is update_columns" framing.

## Omissions (X3)

1. **`retrying` status write + retry actor not enumerated in the X3 changelog.** The map's X3 changelog (`:224`) states "`pending`/`in_progress`/`retrying` never fire the callback at all" but never names the `retrying` write site (`extract_criteria.rb:146` `@ai_job_criteria&.update_columns(status: :retrying)` followed by `raise` at `:147`) nor its advancing actor (`ExtractJobCriteriaJob` `retry_on CustomErrorAiSummary, attempts: 3` at `extract_job_criteria_job.rb:5`, which re-runs `ExtractCriteria` and can reach `succeeded` → fire the callback, or exhaust to `failed` via `:9` `update_columns` → dead end for awaiting summaries). This is the only AiJobCriteria status with a built-in re-driving actor; its omission leaves the retrying→succeeded resume path undocumented for the slice. (The state table `:654` folds retrying writes into "failed/update_columns" prose and does not give retrying its own row.)

2. **`score_job_application.rb:46` re-invocation of `extract_job_criteria` after a criteria-empty failure not tied to the X3 resume.** `:43-47`: on `criteria.blank?`, the code writes `ai_job_criteria` `failed` (`:44`), sets the summary back to `awaiting_job_criteria` (`:45`), then calls `@job.extract_job_criteria` (`:46`). This is a concrete in-pipeline path that can drive a failed criteria back toward a future `succeeded` (and thus a later `resume_waiting_summaries` fan-out). The X3 dead-end note (`:225`) abstractly references "a later ScoreJobApplication pass" but does not cite this specific `:46` re-trigger site that closes the loop.

3. **The map's `:224` reasoning ("the awaiting summary is not succeeded so the `:68` guard does not fire") is imprecise standalone.** `textract_result.rb:68` reads `latest_ai_job_application_summary` (newest), not the awaiting summary. Correct only because awaiting==newest in that fork. Reconciled by `:230`, but `:224` itself should cross-reference `:230` so a reader of the X3 changelog does not take the conflation at face value.

## Conclusion
All candidate-map X3 statements AGREE with current code. Three omissions identified (retrying write/actor not enumerated for the slice; `score_job_application.rb:46` re-trigger site uncited; `:224` reasoning imprecision uncross-referenced). Because omissions is non-empty, **clean = false**.
