# X3 — AiJobCriteria Re-trigger (`resume_waiting_summaries`) — Pass 1

## Files traced (chain)

`app/models/ai_job_criteria.rb:17,21-29` (callback)
→ `app/jobs/generate_ai_job_application_summary_job.rb:24-34` (re-enqueued job, auto path)
→ `app/models/textract_result.rb:61-89` (`generate_ai_summary_with_credit_flow`)
→ `app/models/textract_result.rb:110-112` (`generate_ai_summary`)
→ `app/services/ai_job_application_action/orchestrate.rb:35-36,68-83` (`awaiting_job_criteria` case → `check_criteria_and_score`)
→ `app/services/ai_job_application_action/scoring/score_job_application.rb:19-48` (`run_scoring` target, secondary criteria guard)
→ `app/models/job.rb:688-704` (`extract_job_criteria`)
→ `app/jobs/extract_job_criteria_job.rb:5-29`
→ `app/services/ai_job_application_action/scoring/extract_criteria.rb:28,32,62,122,140,146,151,155` (status write sites)

Supporting reads:
- `app/models/ai_job_application_summary.rb:10-23` (enum + `BROADCAST_STATUSES`)
- `app/models/job_application.rb:31` (`latest_ai_job_application_summary` has_one)
- `app/models/job.rb:51-52` (`has_many :ai_job_application_summaries, through: :job_applications`; `has_one :ai_job_criteria`)
- `db/schema.rb:159` (`criteria_results` jsonb column)
- `spec/models/ai_job_criteria_spec.rb:37-94` (corroborates precondition + failed no-op)

---

## The re-trigger itself

`ai_job_criteria.rb:17`: `after_commit :resume_waiting_summaries, on: [:update]`
`ai_job_criteria.rb:22`: `return unless saved_change_to_status? && status_succeeded?`

**Precondition (exact):** the callback fires on every `update` commit, but the body returns immediately unless BOTH (a) the `status` column changed in this save (`saved_change_to_status?`) AND (b) the new value is `succeeded` (`status_succeeded?`). No other status value advances any summary.

**What it re-enqueues** (`ai_job_criteria.rb:24-28`):
```ruby
job.ai_job_application_summaries.where(status: :awaiting_job_criteria).find_each do |ai_job_application_summary|
  GenerateAiJobApplicationSummaryJob.perform_later(
    textract_result_id: ai_job_application_summary.textract_result_id
  )
end
```
- Scope is `job.ai_job_application_summaries` = `has_many :ai_job_application_summaries, through: :job_applications` (`job.rb:51`) — every summary across every job_application on the job.
- Filtered to `status: :awaiting_job_criteria` only. Summaries in any other status are NOT re-enqueued by this callback.
- `requesting_organization_user_id` is NOT passed → auto-generation path → `GenerateAiJobApplicationSummaryJob` fires NO `AI_SUMMARY_COMPLETE` broadcast when this resumed run finishes (`generate_ai_job_application_summary_job.rb:34` gates the broadcast on `if requesting_organization_user_id`).
- `find_each` (not `each`) — batched 1000-at-a-time iteration; irrelevant to correctness, noted for fidelity.

**Note on stale:** the `where(status: :awaiting_job_criteria)` filter does NOT exclude `stale: true` summaries. A stale summary sitting in `awaiting_job_criteria` would also be re-enqueued. (No filter on `stale` at `ai_job_criteria.rb:24`.)

---

## CRITICAL: which AiJobCriteria status transitions can actually fire the callback

The callback only fires when `status` is written via a method that runs `after_commit` (i.e. `update`/`save`/`update!`), NOT `update_columns`. Survey of every status write to `AiJobCriteria`:

| Write site | New status | Mechanism | Fires callback? |
|---|---|---|---|
| `extract_criteria.rb:28` | `in_progress` | `update_columns` | NO |
| `extract_criteria.rb:32` | `failed` (blank desc) | `update_columns` | NO |
| `extract_criteria.rb:62` | `failed` (no criteria sections) | `update_columns` | NO |
| `extract_criteria.rb:122` | `failed` (no criteria extracted) | `update_columns` | NO |
| `extract_criteria.rb:140` | **`succeeded`** | **`update`** | **YES** |
| `extract_criteria.rb:146` | `retrying` | `update_columns` | NO |
| `extract_criteria.rb:151` | `failed` (JSON parse) | `update_columns` | NO |
| `extract_criteria.rb:155` | `failed` (StandardError) | `update_columns` | NO |
| `score_job_application.rb:44` | `failed` (criteria array empty) | `update_columns` | NO |
| `extract_job_criteria_job.rb:9` | `failed` (retries exhausted) | `update_columns` | NO |
| `extract_job_criteria_job.rb:28` | `failed` (StandardError) | `update_columns` | NO |
| `job.rb:696` | `pending` (re-extract reset) | `update_columns` | NO |

**The ONLY status transition that reaches the re-trigger is `succeeded` at `extract_criteria.rb:140`.** The code comment at `extract_criteria.rb:138-139` is explicit: "Use update (not update_columns) to fire the after_commit callback that resumes waiting summaries." This means the precondition `saved_change_to_status? && status_succeeded?` is doubly enforced: the only callback-firing write IS the succeeded write, so the guard can never be reached with a non-succeeded status.

---

## Fate of an `awaiting_job_criteria` summary under EACH criteria outcome

A summary lands in `awaiting_job_criteria` from `orchestrate.rb:72` (`check_criteria_and_score` sets it before checking criteria) or `score_job_application.rb:23,45`. Once it is `awaiting_job_criteria`, its only advancing actor is the re-enqueued `GenerateAiJobApplicationSummaryJob` driven by this callback. Per criteria outcome:

### succeeded (`extract_criteria.rb:140`)
- Callback fires (only here) → `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id:)`.
- Job runs `generate_ai_summary_with_credit_flow` → guard `textract_result.rb:68` `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?` — passes through since the awaiting summary is NOT succeeded.
- `generate_ai_summary` → `Orchestrate#call`. Summary is `awaiting_job_criteria` → `orchestrate.rb:35-36` → `check_criteria_and_score`.
- `check_criteria_and_score`: `orchestrate.rb:70` `return unless summary_complete?` (headline + summary_text present from the earlier summary stage); `orchestrate.rb:72` sets `awaiting_job_criteria` (no-op); `orchestrate.rb:74` re-fetches `ai_job_criteria`; `orchestrate.rb:76` `ai_job_criteria&.status_succeeded?` is TRUE → `run_scoring` then `run_integration`.
- `run_scoring` → `ScoreJobApplication.score`: `score_job_application.rb:22` criteria IS succeeded → `score_job_application.rb:32` `update(status: :scoring)` → scoring runs → `score_job_application.rb:122-124` `update(status: :integrating ...)`.
- `run_integration` → `IntegrateAnalysis` → `integrate_analysis.rb:51-53` `update(status: :succeeded ...)`. **Terminal: succeeded.** The summary's own `update_summary_status_record` after_commit then refreshes `AiJobApplicationSummaryStatus` to `current` (`ai_job_application_summary.rb:69-98`).

### failed (any of the failed write sites)
- All `failed` writes use `update_columns` → callback does NOT fire → no `GenerateAiJobApplicationSummaryJob` enqueued by this mechanism.
- **The awaiting summary is NOT advanced by the criteria callback.** It is rescued, however, by a separate path: when criteria is failed/blank, `orchestrate.rb:80` and `score_job_application.rb:25-26` call `job.extract_job_criteria`, which (`job.rb:695-697`) resets the SAME `AiJobCriteria` to `pending` via `update_columns` and re-enqueues `ExtractJobCriteriaJob` (2-minute wait). That re-extraction can later reach `succeeded` → callback → resume. So `failed` is NOT a permanent dead-end FOR THE SUMMARY as long as a subsequent `check_criteria_and_score` or `run_scoring` pass re-triggers extraction. But `failed` produces NO callback on its own.
- **Dead-end window:** if criteria ends `failed` and nothing re-invokes Orchestrate/ScoreJobApplication for that job_application (no further summary job runs), the `awaiting_job_criteria` summary rests with no advancing actor. The callback will never fire for a `failed` transition.

### retrying (`extract_criteria.rb:146`)
- `update_columns(status: :retrying)` → callback does NOT fire. The `retrying` write happens in the `rescue CustomErrorAiSummary` block right before `raise` (`extract_criteria.rb:146-147`), so the job re-raises and Sidekiq/`retry_on CustomErrorAiSummary` (`extract_job_criteria_job.rb:5`) re-runs `ExtractCriteria` after 2 minutes. On a later attempt it may reach `succeeded` (→ callback → resume) or exhaust retries → `update_columns(status: :failed)` (`extract_job_criteria_job.rb:9`, no callback).
- **While criteria is `retrying`, the awaiting summary is NOT advanced** — `retrying` never fires the callback. Advancement waits for an eventual `succeeded`.

### pending (`job.rb:696,699`)
- `pending` is set via `update_columns` (`job.rb:696`) or `AiJobCriteria.new(..., status: :pending).save` (`job.rb:699-700`). The `.save` of a NEW record commits `on: :create`, but the callback is `on: [:update]` only (`ai_job_criteria.rb:17`) → does NOT fire on create. The `update_columns` reset also does not fire it.
- **`pending` never advances the awaiting summary.** It is the holding state while `ExtractJobCriteriaJob` is queued/running.

### in_progress (`extract_criteria.rb:28`)
- `update_columns(status: :in_progress)` → callback does NOT fire. Holding state while extraction is mid-flight.
- **`in_progress` never advances the awaiting summary.**

### never-reached (criteria record absent)
- If `job.ai_job_criteria` is nil, `orchestrate.rb:80` (`unless ai_job_criteria&.status_pending? || ai_job_criteria&.status_in_progress?` → nil → both false → unless-false → runs) calls `job.extract_job_criteria`, which CREATES the record (`job.rb:699`) and enqueues extraction. The summary stays `awaiting_job_criteria` until that extraction reaches `succeeded`. Until a criteria record exists and succeeds, no callback fires. Same in `score_job_application.rb:22-27` (criteria blank → `extract_job_criteria`).

**Summary:** the awaiting summary is advanced to `succeeded` ONLY when criteria reaches `succeeded` (via `update` at `extract_criteria.rb:140`). Every other criteria state (pending/in_progress/retrying/failed) leaves the summary parked in `awaiting_job_criteria`; recovery from failed depends on a re-extraction (kicked by `extract_job_criteria` from Orchestrate/ScoreJobApplication) eventually succeeding.

---

## Desync window (AiJobApplicationSummaryStatus)

When this callback re-enqueues and the resumed pipeline drives the summary `awaiting_job_criteria → scoring → integrating → succeeded`, none of the intermediate transitions update `AiJobApplicationSummaryStatus` — only the final `succeeded` does, via `ai_job_application_summary.rb:57-98` (`update_summary_status_record`, gated on `status_succeeded?`). `awaiting_job_criteria` is also excluded from `BROADCAST_STATUSES` (`ai_job_application_summary.rb:23`), so the entry into `awaiting_job_criteria` broadcasts nothing. The status row sits at `initial_summary_pending` (set in `textract_result.rb:104-107`) until the summary finally succeeds. If criteria never succeeds, the status row never advances to `current`.

---

## Map comparison + verdicts

### Map §"AiJobCriteria Re-trigger Mechanism" (lines 366-373)
- Line 369 "When AiJobCriteria transitions to succeeded (after_commit on update)" — CONFIRMED (`ai_job_criteria.rb:17,22`).
- Line 370 "resume_waiting_summaries callback fires" — CONFIRMED.
- Line 371 "Finds all AiJobApplicationSummary records with status: :awaiting_job_criteria for the job" — CONFIRMED (`ai_job_criteria.rb:24`), with the clarification that "for the job" = through job_applications, and that `stale` is NOT filtered.
- Line 372 "Enqueues GenerateAiJobApplicationSummaryJob for each (by textract_result_id)" — CONFIRMED (`ai_job_criteria.rb:25-27`). MAP-INCOMPLETE: omits that no `requesting_organization_user_id` is passed (auto path / no completion broadcast). The note IS present at map line 532, but not in this section.
- Line 373 "Orchestrate picks up where it left off (awaiting_job_criteria → check_criteria_and_score → run_scoring)" — CONFIRMED (`orchestrate.rb:35-36`).

### Map line 287 ("If criteria blank, failed, or retrying → job.extract_job_criteria")
- CONFIRMED against `orchestrate.rb:80`: `extract_job_criteria unless ai_job_criteria&.status_pending? || ai_job_criteria&.status_in_progress?`. The unless-guard means extraction runs for blank/failed/retrying/succeeded-not-taken states (succeeded is already handled by the `if` branch at line 76, so in the else it's blank/failed/retrying).

### Map line 532 (Reference Tables — AiJobCriteria)
- "re-trigger fires WITHOUT requesting_organization_user_id, so no AI_SUMMARY_COMPLETE broadcast" — CONFIRMED (`ai_job_criteria.rb:25-27` vs `generate_ai_job_application_summary_job.rb:34`).

### NEW (not in map): the update-vs-update_columns gating
The map nowhere states that `succeeded` is the ONLY callback-firing criteria transition because every other status write uses `update_columns`. This is the load-bearing reason the precondition can never be reached with a non-succeeded status, and the reason `retrying`/`failed`/`pending`/`in_progress` cannot advance the awaiting summary. Add to map.

---

## Map text to write

Replace map lines 366-373 with:

> ### AiJobCriteria Re-trigger Mechanism
> **File:** `app/models/ai_job_criteria.rb:17,21-29`
>
> `after_commit :resume_waiting_summaries, on: [:update]`. Body: `return unless saved_change_to_status? && status_succeeded?` (line 22). Fires ONLY when the `status` column changes to `succeeded` in an `update`/`save` call.
>
> **Why only `succeeded`:** every other AiJobCriteria status write uses `update_columns` (which skips callbacks): `in_progress` (`extract_criteria.rb:28`), all `failed` writes (`extract_criteria.rb:32,62,122,151,155`; `score_job_application.rb:44`; `extract_job_criteria_job.rb:9,28`), `retrying` (`extract_criteria.rb:146`), and `pending` reset (`job.rb:696`). The single `succeeded` transition uses `update` deliberately (`extract_criteria.rb:138-140`) to fire this callback. New-record `pending` (`job.rb:699` `.save`) commits `on: :create`, not `:update`, so it does not fire either.
>
> **What fires:** `job.ai_job_application_summaries.where(status: :awaiting_job_criteria).find_each` (across all job_applications via the `through: :job_applications` association; `stale` is NOT filtered) → `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id:)`. No `requesting_organization_user_id` is passed → auto path → NO `AI_SUMMARY_COMPLETE` completion broadcast (`generate_ai_job_application_summary_job.rb:34`).
>
> **Resumption path:** job → `generate_ai_summary_with_credit_flow` (`textract_result.rb:61`; the succeeded-and-fresh early return at line 68 passes through because the awaiting summary is not succeeded) → `Orchestrate#call`; summary is `awaiting_job_criteria` → `check_criteria_and_score` (`orchestrate.rb:35-36,68-83`); criteria now `succeeded` → `run_scoring` → `run_integration` → `scoring → integrating → succeeded`.
>
> **Fate of an `awaiting_job_criteria` summary per criteria outcome:**
> - **succeeded** → callback fires → summary driven to `succeeded` (terminal); `AiJobApplicationSummaryStatus` then refreshed to `current`.
> - **failed** → `update_columns`, no callback; summary parked. Recovery only if a later `check_criteria_and_score`/`ScoreJobApplication` pass calls `job.extract_job_criteria` (`orchestrate.rb:80`, `score_job_application.rb:25-26`), resetting criteria to `pending` and re-extracting toward an eventual `succeeded`. With no such re-invocation, the summary is a dead-end at `awaiting_job_criteria`.
> - **retrying** → `update_columns`, no callback; `ExtractCriteria` re-raises and `retry_on` re-runs after 2 min; summary parked until an eventual `succeeded` or exhaustion-to-`failed`.
> - **pending / in_progress** → `update_columns` / create, no callback; holding states; summary parked.
> - **never-reached (no criteria record)** → `extract_job_criteria` creates one and enqueues extraction; summary parked until it succeeds.

---

## Record-write sites found on this slice

All AiJobCriteria status writes (the trigger source):

| file:line | literal | column | mechanism |
|---|---|---|---|
| `extract_criteria.rb:28` | `@ai_job_criteria.update_columns(status: :in_progress)` | status | update_columns |
| `extract_criteria.rb:32` | `@ai_job_criteria.update_columns(status: :failed, error_message: 'Job description is blank')` | status, error_message | update_columns |
| `extract_criteria.rb:62` | `@ai_job_criteria.update_columns(status: :failed, error_message: 'No criteria sections found in job description')` | status, error_message | update_columns |
| `extract_criteria.rb:122` | `@ai_job_criteria.update_columns(status: :failed, error_message: 'No criteria extracted from job description')` | status, error_message | update_columns |
| `extract_criteria.rb:140` | `@ai_job_criteria.update(status: :succeeded, criteria: non_duplicates, metadata: metadata)` (via `update_params`) | status, criteria, metadata | **update (FIRES callback)** |
| `extract_criteria.rb:146` | `@ai_job_criteria&.update_columns(status: :retrying)` | status | update_columns |
| `extract_criteria.rb:151` | `@ai_job_criteria&.update_columns(status: :failed, error_message: "Failed to parse AI response: ...")` | status, error_message | update_columns |
| `extract_criteria.rb:155` | `@ai_job_criteria&.update_columns(status: :failed, error_message: e&.message)` | status, error_message | update_columns |
| `score_job_application.rb:44` | `ai_job_criteria.update_columns(status: :failed, error_message: 'Criteria array is empty')` | status, error_message | update_columns |
| `extract_job_criteria_job.rb:9` | `ai_job_criteria&.update_columns(status: :failed, error_message: error&.message)` | status, error_message | update_columns |
| `extract_job_criteria_job.rb:28` | `ai_job_criteria&.update_columns(status: :failed, error_message: e&.message)` | status, error_message | update_columns |
| `job.rb:696` | `existing_ai_job_criteria.update_columns(status: :pending, error_message: nil)` | status, error_message | update_columns |
| `job.rb:699-700` | `self.ai_job_criteria = AiJobCriteria.new(job: self, status: :pending); ... ai_job_criteria.save` | status (create) | save (on: :create — callback is on :update, does not fire) |

AiJobApplicationSummary writes downstream of the resume (terminal states for the awaiting summary):

| file:line | literal | column | mechanism |
|---|---|---|---|
| `score_job_application.rb:32` | `@ai_job_application_summary.update(status: :scoring)` | status | update |
| `score_job_application.rb:122-124` | `@ai_job_application_summary.update(status: :integrating, ...)` | status (+ scoring cols) | update |
| `integrate_analysis.rb:51-53` | `@ai_job_application_summary.update(status: :succeeded, ...)` | status (+ integration cols) | update |
| `score_job_application.rb:23,45` | `@ai_job_application_summary.update(status: :awaiting_job_criteria)` | status | update (secondary guard; re-park) |
| `orchestrate.rb:72` | `@ai_job_application_summary.update(status: :awaiting_job_criteria)` | status | update (initial park) |

No write to `AiJobCriteria` other than `status`/`error_message`/`criteria`/`metadata` was found on this slice.
