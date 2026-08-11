# X3 — AiJobCriteria re-trigger — Adversarial Review (pass-7)

Slice scope: `AiJobCriteria#resume_waiting_summaries` — fire condition, precondition, what it re-enqueues, and the fate of an `awaiting_job_criteria` summary under each criteria outcome.

Re-read from scratch. Files traced:
- `app/models/ai_job_criteria.rb:1-31`
- `app/models/job.rb:51-52, 688-704`
- `app/models/job_application.rb:29, 31`
- `app/jobs/generate_ai_job_application_summary_job.rb:24-46`
- `app/services/ai_job_application_action/orchestrate.rb:5-104`
- `app/models/textract_result.rb:61-108`
- `app/services/ai_job_application_action/scoring/extract_criteria.rb:28-156`
- `app/jobs/extract_job_criteria_job.rb:5-29`
- `app/services/ai_job_application_action/scoring/score_job_application.rb:19-126`
- `app/models/ai_job_application_summary.rb:23, 29-31, 69, 100-107`
- `db/schema.rb:147-179`

## Verdicts (every X3 map statement)

### Map line 240
"`resume_waiting_summaries` after_commit `on: [:update]`, guarded `saved_change_to_status? && status_succeeded?` (`ai_job_criteria.rb:17,22`); re-enqueues `GenerateAiJobApplicationSummaryJob(textract_result_id:)` for each `awaiting_job_criteria` summary on the job (no stale filter), no requesting user (`:24-27`)."
AGREE — `ai_job_criteria.rb:17` `after_commit :resume_waiting_summaries, on: [:update]`; `:22` `return unless saved_change_to_status? && status_succeeded?`; `:24` `job.ai_job_application_summaries.where(status: :awaiting_job_criteria).find_each`; `:25-27` enqueues with only `textract_result_id:` (no requesting user, no stale filter).

### Map line 241
"`succeeded` is the ONLY callback-firing transition: every other `AiJobCriteria` status write uses `update_columns`. The succeeded write uses `.update` (`extract_criteria.rb:132-140`, in-code comment)."
AGREE — succeeded `.update` at `extract_criteria.rb:140` (params `:132-136`), comment `:138-139`. All other AiJobCriteria writes use `update_columns`: `extract_criteria.rb:28,32,62,122,146,151,155`; `job.rb:696`; `score_job_application.rb:44`; `extract_job_criteria_job.rb:9,28`. The `new`+`save` at `job.rb:699-700` is `on: :update`-immune (creation, not update).

### Map line 242 (idempotency)
"`ai_job_criteria.rb:22` also requires `saved_change_to_status?`, so an `.update` on an already-`succeeded` row not changing status would NOT re-fire."
AGREE — `:22` `return unless saved_change_to_status? && status_succeeded?`.

### Map line 243 (succeeded-firing advance path)
"re-enqueued job runs `generate_ai_summary_with_credit_flow` (`generate_ai_job_application_summary_job.rb:32`); awaiting summary not succeeded so `textract_result.rb:68` guard does not fire; Orchestrate hits `:35` awaiting branch → `check_criteria_and_score`, re-executes `:70` and redundant `:72`, then `:76` true → `run_scoring`(`:77`)+`run_integration`(`:78`) → succeeded; `:82` passes, `:84` charges a credit. pending/in_progress/retrying never fire the callback."
AGREE — `generate_ai_job_application_summary_job.rb:32` calls `generate_ai_summary_with_credit_flow`; `textract_result.rb:68` `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?` (awaiting summary not succeeded → no return when it is newest); `orchestrate.rb:35` `when @ai_job_application_summary.status_awaiting_job_criteria?` → `:36` `check_criteria_and_score`; `:69` failed guard, `:70` `return unless summary_complete?`, `:72` `update(status: :awaiting_job_criteria)`, `:74` criteria, `:76` `if ai_job_criteria&.status_succeeded?` → `:77 run_scoring` + `:78 run_integration`; credit at `textract_result.rb:82,84`.

### Map line 244 (failed dead end)
"An `awaiting_job_criteria` summary whose criteria ends `failed` has no advancing actor unless a later Orchestrate/ScoreJobApplication pass re-invokes `job.extract_job_criteria`; the `failed` transition itself never resumes it (all failed writes use `update_columns`)."
AGREE — failed writes `extract_criteria.rb:32,62,122,151,155`, `score_job_application.rb:44`, `extract_job_criteria_job.rb:9,28` all `update_columns` (no callback). Re-invocation routes: `orchestrate.rb:80` and `score_job_application.rb:46` both call `extract_job_criteria`.

### Map line 245 (`retrying` write + re-driving actor)
"`extract_criteria.rb:146` `update_columns(status: :retrying)` then `raise`(`:147`) triggers `ExtractJobCriteriaJob` `retry_on CustomErrorAiSummary, attempts: 3`(`extract_job_criteria_job.rb:5`) → re-runs ExtractCriteria → succeeded (fires resume) OR exhaust → failed (`:9`). retrying is the ONLY AiJobCriteria status with a built-in re-driving actor."
AGREE — `extract_criteria.rb:146` `@ai_job_criteria&.update_columns(status: :retrying)`, `:147` `raise`; `extract_job_criteria_job.rb:5` `retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3`, exhaustion `:9` `update_columns(status: :failed, ...)`.

### Map line 246 (`score_job_application.rb:46` loop-closing re-trigger)
"On criteria-empty failure, ScoreJobApplication writes `ai_job_criteria` failed (`:44`), resets summary to `awaiting_job_criteria`(`:45`), then `@job.extract_job_criteria`(`:46`)."
AGREE — `score_job_application.rb:44` `ai_job_criteria.update_columns(status: :failed, error_message: 'Criteria array is empty')`, `:45` `@ai_job_application_summary.update(status: :awaiting_job_criteria)`, `:46` `@job.extract_job_criteria`.

### Map line 248 (benign empty fan-out)
"criteria succeeded with ZERO awaiting summaries → `find_each`(`ai_job_criteria.rb:24`) iterates nothing — benign no-op."
AGREE — `:24` `where(status: :awaiting_job_criteria).find_each` over an empty relation is a no-op.

### Map line 249 (nil textract_result_id no-op site)
"`ai_job_criteria.rb:26` passes nullable `textract_result_id`; when nil the re-enqueued job no-ops at `generate_ai_job_application_summary_job.rb:30` (`return unless textract_result`), NOT at orchestrate; `:25 find_by` → nil → `:30` returns before `:32`, Orchestrate never constructed."
AGREE — `textract_result_id` nullable (`db/schema.rb:149`, no `null: false`); `generate_ai_job_application_summary_job.rb:25` `TextractResult.find_by(id: textract_result_id)`, `:30` `return unless textract_result` precedes `:32`.

### Map line 250 (cross-application fan-out)
"`ai_job_criteria.rb:24` uses `job.ai_job_application_summaries` = `has_many through: :job_applications`(`job.rb:51`) → re-enqueues for EVERY awaiting summary across ALL job_applications of the job."
AGREE — `job.rb:51` `has_many :ai_job_application_summaries, through: :job_applications`.

### Map line 251 (stale summaries included)
"`ai_job_criteria.rb:24` filters status only (no stale filter), so a `stale:true` awaiting summary is re-enqueued; resumed run `generate_ai_summary_with_credit_flow:67` reads `job_application.latest_ai_job_application_summary` (possibly a newer summary)."
AGREE — `:24` filters `status: :awaiting_job_criteria` only; `textract_result.rb:67` `latest_ai_summary = job_application.latest_ai_job_application_summary`; `job_application.rb:31` `has_one :latest_ai_job_application_summary, -> { order(created_at: :desc) }`.

### Map line 252 (newest-summary re-selection = advance-vs-dead-end)
"Re-enqueue carries ONLY `textract_result_id:`; credit-flow reads `latest_ai_job_application_summary`(`textract_result.rb:67`) and Orchestrate re-selects `order(created_at: :desc).first`(`orchestrate.rb:15`) — NEWEST, not the awaiting one. Fork: awaiting-is-newest advances; a DIFFERENT newer succeeded-non-stale summary makes `textract_result.rb:68` return → awaiting row stranded (silent dead end)."
AGREE — `orchestrate.rb:15` `@ai_job_application_summary = @job_application.ai_job_application_summaries.order(created_at: :desc).first`; `textract_result.rb:68` returns when newest is `status_succeeded? && !stale?`.

### Map line 253 (no completion toast on resumed succeeded run)
"re-enqueue passes no `requesting_organization_user_id`(`ai_job_criteria.rb:25-27`); on succeeded `generate_ai_job_application_summary_job.rb:34` (`... if requesting_organization_user_id`) is skipped — NO toast."
AGREE — `ai_job_criteria.rb:25-27` passes only `textract_result_id:`; `generate_ai_job_application_summary_job.rb:34` `broadcast_completion(...) if requesting_organization_user_id` (nil → skipped). The job's `perform` default is `requesting_organization_user_id: nil` (`:24`).

### Part 7 / 5.4 / census restatements
Map `:534-536`, `:570-575`, `:632`, `:634`, `:645`, `:668-679`, `:821`: AGREE — all `file:line` re-verified above. The 5.4 succeeded row "RESTING (terminal) → resumes all awaiting_job_criteria summaries" and the `retrying` row "ONLY status with a built-in re-driving actor" both hold. Census `:821` enumeration of AiJobCriteria write sites matches the read code exactly (`job.rb:696/699`, `extract_criteria.rb:28/32/62/122/132-140/146/151/155`, `score_job_application.rb:44`, `extract_job_criteria_job.rb:9/28`).

### Related awaiting-rest claims (S-E lines that bear on X3's resumed actor)
Map `:205` (`BROADCAST_STATUSES` omits `awaiting_job_criteria`/`retrying`): AGREE — `ai_job_application_summary.rb:23`.
Map `:211` (status row stays `initial_summary_pending` at the awaiting rest because `update_summary_status_record` fires only on succeeded): AGREE — `ai_job_application_summary.rb:69` `return unless saved_change_to_status? && status_succeeded?`; set at `textract_result.rb:104-107`.
Map `:212` (awaiting summary resumed to terminal by `AiJobCriteria#resume_waiting_summaries`): AGREE.

## Omissions
None for the X3 slice. Every branch (succeeded / failed / retrying / pending / in_progress / never-reached / nil-textract / cross-application / stale / newer-succeeded / empty fan-out / no-toast / credit-charge) is documented with accurate `file:line`.

## Conclusion
clean = true. Every X3 statement verified AGREE against current code; no omissions.
