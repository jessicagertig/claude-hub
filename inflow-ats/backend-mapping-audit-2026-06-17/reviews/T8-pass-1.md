# T8 — Bulk AI Summary Backfill (QueueBulkAiSummaryJobs) — Pass 1

**Angle:** T8
**Audited:** 2026-06-22
**Repo root:** `/Users/jessica/wrk/wrk-corp/inflow-ats`

## File chain traced

`app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb:13`
→ `app/controllers/concerns/role_fit_filterable.rb:15`
→ `app/models/job_application.rb:106-115` (scopes `fit_bands`, `unscored`, `with_resume`, `with_textract_results`)
→ `app/interactors/queue_bulk_ai_summary_jobs.rb` (T8 core)
→ `app/jobs/submit_resume_to_textract_job.rb:6` → `app/services/submit_resume_to_textract.rb:8` (backfill bridge)
→ `app/models/ai_job_application_summary_status.rb:9` (enum)
→ `app/models/bulk_ai_summary_job_application.rb` (enum, status :deferred)
→ `app/jobs/bulk_generate_ai_summaries_job.rb` (terminal worker)
→ `app/interactors/create_bulk_ai_summary_generation.rb` (NEW)
→ `app/interactors/validate_ai_summary_generation.rb:38-60` (textract branch)
→ `app/models/job_application.rb:685` (`latest_textract_result`)
→ `app/models/organization.rb:961` (`ai_credits_available?`)
→ `db/schema.rb:316` (partial unique index)

---

## Behaviors

### B1 — Controller resolves IDs server-side (included OR hiring_stage+excluded+role_fit)
**Code:** `bulk_ai_job_application_summaries_controller.rb:32-46`. `resolve_job_application_ids`: if `included_job_application_ids` present, uses them; else if `hiring_stage_id` present, `apply_role_fit_filter(stage.job_applications, p[:role_fit]).pluck(:id) - excluded`.
**Map says:** ABSENT — old map (Trigger B, lines 392-402) shows `QueueBulkAiSummaryJobs` receiving candidates but never documents `hiring_stage_id`+`included`/`excluded`+`role_fit` server-side resolution. The new `RoleFitFilterable` concern is entirely absent from the map.
**Verdict:** NEW (matches "all bulk actions when filtered, front to backend" commit).

### B2 — Interactor gates: AI_APPLICANT_SUMMARY flipper + ai_credits_available?
**Code:** `queue_bulk_ai_summary_jobs.rb:17-18`. `context.fail!` unless `Flipper.enabled?(:AI_APPLICANT_SUMMARY, organization)`; `context.fail!` unless `organization.ai_credits_available?` (→ `organization.rb:962` `total_ai_credits_remaining.positive?`).
**Map says:** "Validates: Flipper `AI_APPLICANT_SUMMARY` + credits available" (line 396, 667, 669).
**Verdict:** CONFIRMED.

### B3 — ready_ids vs pending_textract_ids partition
**Code:** `queue_bulk_ai_summary_jobs.rb:20-24`. `scope = org.job_applications.where(id: input_ids)`; `ready_ids = scope.with_resume.with_textract_results.distinct.pluck(:id)`; `pending_textract_ids = scope.with_resume.where.not(id: ready_ids).distinct.pluck(:id)`. No-resume IDs fall through silently.
**Map says:** "`ready_ids`: has resume AND has textract results / `pending_textract_ids`: has resume, no textract ... / No resume: silently skipped" (lines 398-400).
**Verdict:** CONFIRMED (structure), but see B4 for the "with_textract_results = text ready" mischaracterization.

### B4 — `with_textract_results` joins a row, does NOT check text presence (MAP-WRONG)
**Code:** `job_application.rb:115` — `scope :with_textract_results, -> { joins(:textract_results) }`. Pure join on the `textract_results` association; no filter on `textract_job_status` or `textract_job_result_text`.
**Map says:** "Bulk generation: `QueueBulkAiSummaryJobs` filters for `with_textract_results` (text already present)" (line 569); Part 7 trigger #8 / Trigger B imply readiness = text present.
**Verdict:** MAP-WRONG. A candidate with an `in_progress` TextractResult (no text yet) is counted as "ready" here. Later, inside `BulkGenerateAiSummariesJob#each_iteration`, `ValidateAiSummaryGeneration#textract_text_ready?` (`validate_ai_summary_generation.rb:74`, `textract_job_result_text.present?`) is false → `textract_pending = true` → the candidate is set to `:deferred` (`bulk_generate_ai_summaries_job.rb:65-68`), NOT processed this run. **Desync window: a row counted into `queued_count`/`ready_ids` can defer at iteration time.**

### B5 — Textract backfill for resume-but-no-textract candidates
**Code:** `queue_bulk_ai_summary_jobs.rb:28-30` — `pending_textract_ids.each { |id| SubmitResumeToTextractJob.perform_later(id) }`. These IDs are NOT added to `working_set` (only `ready_ids` flow forward, line 47).
**Map says:** "Kicks off `SubmitResumeToTextractJob.perform_later(id)` for each ... These candidates are NOT included in the current bulk AI summary run. They'll be ready for a subsequent bulk run after Textract completes" (lines 141-143).
**Verdict:** CONFIRMED. `SubmitResumeToTextractJob.perform(job_application_id)` → `SubmitResumeToTextract#submit_resume` builds a TextractResult `in_progress` (`submit_resume_to_textract.rb:22`) and schedules `GetResumeTextFromTextractJob` (+2 min). **Terminal state for T8's own action: textract_result `in_progress`, handed off to the Textract polling slice. T8 does NOT enqueue any summary for these — they reach a resting state with no summary until a subsequent bulk run OR the textract after_commit auto-generate path (other slices) fires.**

### B6 — Flipper note: TEXTRACT_RESUME_PROCESSING NOT checked before backfill
**Code:** `queue_bulk_ai_summary_jobs.rb:17-18, 28-30` — only `AI_APPLICANT_SUMMARY` + credits gate; `SubmitResumeToTextractJob` is enqueued without a `TEXTRACT_RESUME_PROCESSING` check.
**Map says:** "Note: does NOT check `TEXTRACT_RESUME_PROCESSING` flipper here (only checks `AI_APPLICANT_SUMMARY`)" (line 144); Part 6 table line 666.
**Verdict:** CONFIRMED.

### B7 — Drop already-summarized (status :current) candidates
**Code:** `queue_bulk_ai_summary_jobs.rb:36-40`. `already_summarized_ids = AiJobApplicationSummaryStatus.where(job_application_id: ready_ids, status: :current).pluck(:job_application_id)`; `ready_ids -= already_summarized_ids`; `input_ids -= already_summarized_ids`. Removed from BOTH the working set and `input_ids`, so they are neither processed nor counted as skipped.
**Map says:** ABSENT from map. The old map's `AiJobApplicationSummaryStatus` enum (lines 509-511) lists a 10-value pipeline-mirror enum that has NO `current` value.
**Verdict:** NEW. Depends on the real `AiJobApplicationSummaryStatus` enum `{none:0, initial_summary_pending:1, current:2, regenerating:3}` (`ai_job_application_summary_status.rb:9-14`), which the old map gets entirely wrong (see B11).

### B8 — Cross-batch claim filter + race-safe per-row create
**Code:** `queue_bulk_ai_summary_jobs.rb:43-47` — `already_claimed_ids = BulkAiSummaryJobApplication.where(job_application_id: ready_ids, status: :processing).pluck(:job_application_id)`; `working_set = ready_ids - already_claimed_ids`. Lines 64-75: per-row `BulkAiSummaryJobApplication.create(bulk_job_id:, job_application_id:, status: :processing)` with `rescue ActiveRecord::RecordNotUnique` (treats collision as already-claimed). Lines 78-80 re-query owned claims by `bulk_job_id`.
**Map says:** "Race-safe claiming via `BulkAiSummaryJobApplication` with partial unique index" (line 401).
**Verdict:** CONFIRMED. Partial unique index verified at `db/schema.rb:316` — `unique: true, where: "(status = 0)"` on `job_application_id`.

### B9 — Early-return when working_set empty
**Code:** `queue_bulk_ai_summary_jobs.rb:49-54`. If `working_set.empty?`: `queued_count = 0`, `skipped_count = input_ids.size`, `any_textract_pending = pending_textract_ids.any?`, return (no job enqueued).
**Map says:** ABSENT.
**Verdict:** NEW.

### B10 — Enqueue BulkGenerateAiSummariesJob with hash payload + counts
**Code:** `queue_bulk_ai_summary_jobs.rb:82-93`. `BulkGenerateAiSummariesJob.perform_later('bulk_job_id'=>, 'user_id'=>, 'hiring_stage_id'=>first.hiring_stage_id, 'job_id'=>first.job_id, 'job_application_ids'=>claimed_ids, 'skipped_count'=>input_ids.size - claimed_ids.size)`. Sets `context.queued_count = claimed_ids.size`, `context.skipped_count`, `context.any_textract_pending`.
**Map says:** "Enqueues `BulkGenerateAiSummariesJob` with claimed IDs" (line 402).
**Verdict:** CONFIRMED (structure); the hash-keyed payload + `skipped_count`/`hiring_stage_id`/`job_id`/`user_id` shape is NEW detail absent from the map.

### B11 — AiJobApplicationSummaryStatus enum is 4 values, not 10 (MAP-WRONG)
**Code:** `ai_job_application_summary_status.rb:9-14` — `enum status: { none:0, initial_summary_pending:1, current:2, regenerating:3 }, _prefix: true`.
**Map says:** lines 509-511 list `pending(0) ... failed(9)` (the AiJobApplicationSummary pipeline enum) for this table.
**Verdict:** MAP-WRONG. The T8 interactor relies on `status: :current` (`queue_bulk_ai_summary_jobs.rb:37`); the map's enum would make that query meaningless.

### B12 — BulkAiSummaryJobApplication has a :deferred status
**Code:** `bulk_ai_summary_job_application.rb` — `enum status: { processing: 0, done: 1, failed: 2, deferred: 3 }, _prefix: true`. Used at `bulk_generate_ai_summaries_job.rb:66` (`update_columns(status: :deferred)`) for the textract-pending in-iteration case.
**Map says:** "`BulkAiSummaryJobApplication` with partial unique index" mentioned (line 401) but no enum/`deferred` documented (Part 1 line 407-409 only mentions failed).
**Verdict:** NEW. `deferred` is the in-bulk analog of T8's resume-but-no-usable-text branch.

### B13 — Bulk iteration now goes through CreateBulkAiSummaryGeneration (CHANGED)
**Code:** `bulk_generate_ai_summaries_job.rb:73-80` — `CreateBulkAiSummaryGeneration.call(job_application:, validation_result: result, user:)` THEN `result.textract_result.generate_ai_summary_with_credit_flow`.
**Map says:** "Bulk generate ... NO — calls `generate_ai_summary_with_credit_flow` directly" (lines 569, 696, 703).
**Verdict:** CHANGED. A new interactor `create_bulk_ai_summary_generation.rb` now builds the `AiJobApplicationSummary` row (status `:pending`) before driving generation. Old map's claim that bulk bypasses any Create interactor is stale.

### B14 — Branch logic (resume present, textract not usable) inside the bulk run
**Code:** `bulk_generate_ai_summaries_job.rb:59-68` — `result = ValidateAiSummaryGeneration.call(...)`; `if result.textract_pending` → `update_columns(status: :deferred); return`. `textract_pending` is set true in `validate_ai_summary_generation.rb:40/56/59` whenever `textract_job_result_text` is not present (`:74`), or latest result is nil/failed-but-resubmittable.
**Map says:** Map describes `textract_pending` for the single-send path (lines 223-228) but does not connect it to the bulk `:deferred` outcome.
**Verdict:** NEW (bulk wiring). **This is the T8 branch the prompt asks about: when the bulk-selected candidate has a TextractResult row but no usable text, the summary path does NOT advance — the candidate is deferred and waits; it advances forward into the AI pipeline only when `textract_text_ready?` is true at iteration time.**

---

## Terminal states & dead ends (T8 perspective)

- **pending_textract_ids candidates:** T8 enqueues `SubmitResumeToTextractJob` → TextractResult `in_progress` (`submit_resume_to_textract.rb:22`) → `GetResumeTextFromTextractJob` (+2 min) handles polling (other slice). T8 produces NO summary for them and does NOT re-enqueue a bulk run. Resting state for THIS interactor's action = textract `in_progress`; further advancement depends on the Textract polling/auto-generate slices. If the user never re-runs bulk AND auto-generate is off, these candidates never get a summary from the bulk action (the backfill only readies textract; the map calls this out at lines 142-143 — CONFIRMED).
- **deferred candidates inside the bulk job:** `bulk_ai_summary_job_application.status = :deferred` (`bulk_generate_ai_summaries_job.rb:66`) is a resting state with NO re-trigger inside this job. `on_complete` counts them as `skipped` (`:110`, `:124`). They are not re-driven by T8.
- **already_summarized (status :current) candidates:** dropped entirely (B7) — never claimed, never reported. Resting state = unchanged `current` status row.

## Desync windows

- **DW1 (B4):** `ready_ids`/`queued_count` counts candidates whose TextractResult has no text yet; at iteration they defer. The response's `queued_count` (`queue_bulk_ai_summary_jobs.rb:91`) can exceed the number that actually generate a summary this run.
- **DW2 (B7 vs status table):** The `:current` drop reads `AiJobApplicationSummaryStatus.status` (the denormalized row). If that row is stale relative to the latest non-stale `AiJobApplicationSummary` (the table is denormalized, populated only on summary success per other slices), a candidate could be wrongly dropped (if status row says `current` but the real latest summary is stale/failed) or wrongly re-queued. T8 trusts the denormalized status row as ground truth at `queue_bulk_ai_summary_jobs.rb:37`.

## Record-write sites on the T8 slice

| file:line | literal | column(s) | op |
|---|---|---|---|
| `submit_resume_to_textract.rb:19` | `@job_application.ai_job_application_summaries.update_all(stale: true)` | AiJobApplicationSummary.stale | update_all |
| `submit_resume_to_textract.rb:22-24` | `textract_results.build(textract_job_id:, textract_job_status: 'in_progress')` + `.save` | TextractResult.textract_job_id, textract_job_status, job_application_id | insert (save) |
| `submit_resume_to_textract.rb:26` | `waiting_summary&.update_columns(textract_result_id: @textract_result.id)` | AiJobApplicationSummary.textract_result_id | update_columns |
| `submit_resume_to_textract.rb:33,39` | `@textract_result&.update_columns(textract_job_status: 'failed')` | TextractResult.textract_job_status | update_columns |
| `queue_bulk_ai_summary_jobs.rb:65-69` | `BulkAiSummaryJobApplication.create(bulk_job_id:, job_application_id:, status: :processing)` | BulkAiSummaryJobApplication all cols | insert (create) |
| `create_bulk_ai_summary_generation.rb:39` | `active_ai_summary.update_columns(stale: true)` | AiJobApplicationSummary.stale | update_columns |
| `create_bulk_ai_summary_generation.rb:48-54` | `build(textract_result:, status: :pending, requested_by_organization_user_id:)` + `.save` | AiJobApplicationSummary.textract_result_id, status, requested_by_organization_user_id, job_application_id | insert (save) |
| `bulk_generate_ai_summaries_job.rb:54` | `update_columns(status: :done)` (already-processed guard) | BulkAiSummaryJobApplication.status | update_columns |
| `bulk_generate_ai_summaries_job.rb:66` | `update_columns(status: :deferred)` | BulkAiSummaryJobApplication.status | update_columns |
| `bulk_generate_ai_summaries_job.rb:86` | `update_columns(status: :done)` | BulkAiSummaryJobApplication.status | update_columns |
| `bulk_generate_ai_summaries_job.rb:180` | `update_all(status: 'failed', updated_at: Time.current)` | BulkAiSummaryJobApplication.status | update_all |

(Pipeline writes inside `generate_ai_summary_with_credit_flow` belong to other slices; not re-listed here.)
