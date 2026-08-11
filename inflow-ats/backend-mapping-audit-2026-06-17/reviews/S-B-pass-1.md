# S-B — Bulk Generate — Pass 1 Audit

**Angle:** S-B (Bulk generate). QueueBulkAiSummaryJobs -> BulkGenerateAiSummariesJob -> per-candidate generate_ai_summary_with_credit_flow.

## Files traced (chain)

```
app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb:13
  -> app/interactors/queue_bulk_ai_summary_jobs.rb
       -> app/models/job_application.rb:114 (scope with_resume), :115 (scope with_textract_results), :685 (latest_textract_result)
       -> app/models/bulk_ai_summary_job_application.rb (enum status processing/done/failed/deferred)
       -> app/models/ai_job_application_summary_status.rb (enum none/initial_summary_pending/current/regenerating)
  -> app/jobs/bulk_generate_ai_summaries_job.rb
       -> app/interactors/validate_ai_summary_generation.rb
       -> app/interactors/create_bulk_ai_summary_generation.rb
       -> app/models/textract_result.rb:61 generate_ai_summary_with_credit_flow
            -> app/models/job_application.rb:160 find_or_create_ai_job_application_summary_status
                 -> app/interactors/find_or_create_ai_job_application_summary_status.rb
            -> app/models/textract_result.rb:98 set_initial_summary_pending
            -> app/services/ai_job_application_action/orchestrate.rb:9
            -> app/models/ai_job_application_summary.rb:30 update_summary_status_record (after_commit on :update)
```

## Headline finding: the map's S-B model is STALE

The map (Part 2 line 569, Part 7 row B line 696, Part 8) asserts bulk **bypasses `CreateAiSummaryGeneration`** and **never builds an AiJobApplicationSummary row** — "calls `generate_ai_summary_with_credit_flow` directly." That is no longer true. The current bulk path:

1. Has a dedicated controller `Api::V1::BulkAiJobApplicationSummariesController` with `included_/excluded_job_application_ids` + `hiring_stage_id` + `role_fit` server-side resolution (the analog bulk-pattern shape) — the map never documents this controller.
2. Uses a **new interactor `CreateBulkAiSummaryGeneration`** to build the `:pending` AiJobApplicationSummary row before driving generation. The map says no row is built on the bulk path.
3. Writes the denormalized `AiJobApplicationSummaryStatus` row to `initial_summary_pending` (via `set_initial_summary_pending`) and to `current` (via `update_summary_status_record`). The map's status-row enum (`pending..failed`, 10 values) and its claim that `regenerating` is "never set to true" are both wrong for current code.

---

## Claim-by-claim

### 1. Entry controller and param resolution — NEW
**Code:** `bulk_ai_job_application_summaries_controller.rb:13` `QueueBulkAiSummaryJobs.call(organization:, user:, job_application_ids: ids_to_process)`; `:32-46` `resolve_job_application_ids` resolves `included_job_application_ids` OR (`hiring_stage_id` + `role_fit` filter via `apply_role_fit_filter` minus `excluded_job_application_ids`).
**Map:** "Controller bulk_create" only, no param shape (line 696).
**Verdict:** NEW. Controller and server-side select-all resolution undocumented.

### 2. QueueBulkAiSummaryJobs guards — CONFIRMED
**Code:** `queue_bulk_ai_summary_jobs.rb:17` `context.fail!(...) unless Flipper.enabled?(:AI_APPLICANT_SUMMARY, organization)`; `:18` `unless organization.ai_credits_available?`
**Map:** "Validates: Flipper AI_APPLICANT_SUMMARY + credits available" (lines 396, 398).
**Verdict:** CONFIRMED.

### 3. Candidate partition — CHANGED (new `already_summarized_ids` drop)
**Code:** `:22` `ready_ids = scope.with_resume.with_textract_results.distinct.pluck(:id)`; `:23` `pending_textract_ids = scope.with_resume.where.not(id: ready_ids).distinct.pluck(:id)`; `:36-40` drops `already_summarized_ids` (status `:current` on `AiJobApplicationSummaryStatus`) from BOTH `ready_ids` and `input_ids`.
**Map:** ready_ids / pending_textract_ids / no-resume-skipped (lines 397-400). No mention of the `:current` drop.
**Verdict:** CHANGED. The `already_summarized_ids` filter against `AiJobApplicationSummaryStatus.status_current` is new and absent from the map. Candidates already summarized are silently removed from the run AND from the skipped count.

### 4. Textract backfill for resume-but-no-textract — CONFIRMED
**Code:** `:28-30` `pending_textract_ids.each { |id| SubmitResumeToTextractJob.perform_later(id) }`
**Map:** Trigger 8 (lines 136-144) + line 399.
**Verdict:** CONFIRMED. Flipper `TEXTRACT_RESUME_PROCESSING` still NOT checked here (only `AI_APPLICANT_SUMMARY`).

### 5. Race-safe claiming via BulkAiSummaryJobApplication — CONFIRMED (detail CHANGED)
**Code:** `:43-47` drops `already_claimed_ids` (status `:processing`); `:64-75` per-row `BulkAiSummaryJobApplication.create(... status: :processing)` rescuing `ActiveRecord::RecordNotUnique`; `:78-80` re-query owned claims by `bulk_job_id`.
**Map:** "Race-safe claiming via BulkAiSummaryJobApplication with partial unique index" (line 401).
**Verdict:** CONFIRMED at concept level; the per-row create-with-rescue (Rails 6.1 `insert_all` limitation) and re-query are implementation detail the map omits. `BulkAiSummaryJobApplication` enum is `{processing:0, done:1, failed:2, deferred:3}` (`bulk_ai_summary_job_application.rb`) — map never lists this enum.

### 6. Empty working-set early return — NEW
**Code:** `:49-54` if `working_set.empty?` sets `queued_count=0`, `skipped_count=input_ids.size`, `any_textract_pending`, returns without enqueueing.
**Map:** ABSENT.
**Verdict:** NEW.

### 7. Enqueue BulkGenerateAiSummariesJob payload — CHANGED
**Code:** `:82-89` `perform_later('bulk_job_id'=>..., 'user_id'=>..., 'hiring_stage_id'=>..., 'job_id'=>..., 'job_application_ids'=>claimed_ids, 'skipped_count'=>input_ids.size - claimed_ids.size)`.
**Map:** "Enqueues BulkGenerateAiSummariesJob with claimed IDs" (line 402).
**Verdict:** CHANGED. Payload is a hash with bulk_job_id/user_id/hiring_stage_id/job_id/skipped_count — undocumented.

### 8. BulkGenerateAiSummariesJob retry/discard exhaustion — CONFIRMED
**Code:** `bulk_generate_ai_summaries_job.rb:12-16` `discard_on StandardError` -> `update_remaining_statuses_to_failed(payload)` + `notify_failure(payload)`; `:17-21` `retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3` -> same.
**Map:** lines 407-408.
**Verdict:** CONFIRMED. (Note: exhaustion blocks update remaining BulkAiSummaryJobApplication rows, NOT AiJobApplicationSummary rows — see write sites.)

### 9. Per-iteration idempotency guard — CONFIRMED (detail richer)
**Code:** `:48-56` `summary_already_processed` = exists an `ai_job_application_summaries` with `created_at >= job_application_bulk_job_status.created_at` and `status IN (succeeded, failed)`; if so `update_columns(status: :done)` and return.
**Map:** "Uses job-iteration gem for resumable processing" (line 405); credit double-charge guard not described.
**Verdict:** CONFIRMED behavior, map under-documents it.

### 10. textract_pending -> deferred — NEW
**Code:** `:59` `result = ValidateAiSummaryGeneration.call(...)`; `:60` `return unless result.success?`; `:65-68` if `result.textract_pending` then `job_application_bulk_job_status.update_columns(status: :deferred)` and return — no summary built, no credit flow.
**Map:** ABSENT (map's bulk path has no deferred concept; it described filtering pending-textract OUT in the interactor only).
**Verdict:** NEW. Deferred is a distinct terminal-for-this-run state, counted as skipped in notify_complete.

### 11. CreateBulkAiSummaryGeneration builds the row — NEW
**Code:** `:73-78` `CreateBulkAiSummaryGeneration.call(job_application:, validation_result: result, user:)`. Interactor `create_bulk_ai_summary_generation.rb:34-43` finds active non-failed non-stale summary; if its `textract_result_id != job_application.latest_textract_result&.id` marks it `stale: true` via `update_columns` and nils it; `:45-48` returns existing active summary if present; `:50-57` else builds `ai_job_application_summaries.build(textract_result:, status: :pending, requested_by_organization_user_id: user.current_organization_user.id)` and saves.
**Map:** Explicitly says bulk does NOT use CreateAiSummaryGeneration and builds no row (lines 569, 696, 703).
**Verdict:** NEW. Entire interactor is undocumented. Note: it has no textract_processing branch (deferred upstream).

### 12. generate_ai_summary_with_credit_flow — CHANGED (status-row writes + stale guard)
**Code:** `textract_result.rb:67-68` `latest_ai_summary = job_application.latest_ai_job_application_summary; return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`; `:70` `status_result = job_application.find_or_create_ai_job_application_summary_status`; `:72` `set_initial_summary_pending(status_result) if status_result.success?`; `:74` `generate_ai_summary`; `:77-82` fetch latest summary, `return unless ...status_succeeded?`; `:84-85` `CreateAiCreditBalanceTransaction.call(summary:)`, `return unless consume_result.success?`; `:87-88` NotifyZeroAiCredits / NotifyLowAiCredits.
**Map:** lines 257-265 / 569 describe only: orchestrate -> fetch latest -> guard succeeded -> credit -> notify. NO mention of the `latest.stale?` guard (line 68), NO mention of `find_or_create_ai_job_application_summary_status` or `set_initial_summary_pending`.
**Verdict:** CHANGED. (a) Early-return guard is now `status_succeeded? && !stale?` — a non-stale succeeded summary short-circuits (no new generation, no credit), fixing the map's "Gap 8" double-charge for the non-stale case. (b) Status row is driven to `initial_summary_pending` before generation.

### 13. set_initial_summary_pending — NEW status-row write
**Code:** `textract_result.rb:98-108`: only acts if `status_record.status_none? || status_record.status_initial_summary_pending?`; then `update_columns(ai_job_application_summary_id: latest_summary.id, status: 'initial_summary_pending')`.
**Map:** ABSENT — map's status enum doesn't even contain `initial_summary_pending`.
**Verdict:** NEW.

### 14. find_or_create_ai_job_application_summary_status — NEW (regenerating IS set)
**Code:** `find_or_create_ai_job_application_summary_status.rb:11-21`: if status record exists and its summary `status_succeeded?` -> `update_columns(status: 'regenerating')` + `JobChannel ai_summary_status_change` broadcast; `:22-40` else builds record, sets `current` (with denormalized cols) if latest summary succeeded & not stale, else `none`. Rescues `ActiveRecord::RecordNotUnique` by reloading (`:43-44`).
**Map:** Gap 7 (lines 638-648) claims `regenerating` "is never set to true." Map status enum (lines 509-511) lists the 10-value summary enum.
**Verdict:** MAP-WRONG. `regenerating` IS set to true here (line 15) on the bulk regeneration path when a succeeded summary already exists. The status enum is `{none:0, initial_summary_pending:1, current:2, regenerating:3}` (`ai_job_application_summary_status.rb:9-14`), NOT the summary's enum.

### 15. update_summary_status_record -> 'current' + JobChannel broadcast — CHANGED
**Code:** `ai_job_application_summary.rb:69` `return unless saved_change_to_status? && status_succeeded?`; `:71-72` `ai_job_application_summary_status = job_application.ai_job_application_summary_status; return unless ...`; `:74-80` `ai_job_application_summary_status.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)`; `:93-97` `JobChannel.broadcast_to(job, event: 'ai_summary_succeeded', payload: {jobApplicationId, hiringStageId})`.
**Map:** lines 502, 605 say it sets `status: succeeded` (integer 7) via `update_columns`, `regenerating: false`.
**Verdict:** CHANGED. Now sets `status: 'current'` (enum value 2) via **`update` (not update_columns)** — runs validations/counter_culture — and there is no `regenerating: false` column write (that concept folded into the 4-value enum). Also fires a NEW `JobChannel ai_summary_succeeded` broadcast for the stage-list refetch.

### 16. create_status_record callback — REMOVED
**Code:** `grep create_status_record app/` -> no hits. `ai_job_application_summary.rb` has only `destroy_previous_textract_results`, `update_summary_status_record`, `broadcast_status_change` callbacks (`:29-31`).
**Map:** lines 500-501 document `after_commit :create_status_record, on: :create` with a `find_or_create_by` bug.
**Verdict:** REMOVED. Status-record creation moved to `FindOrCreateAiJobApplicationSummaryStatus` interactor, called from `JobApplication#enqueue_new_job_application` (`job_application.rb:170`) and from `generate_ai_summary_with_credit_flow` (`textract_result.rb:70`).

### 17. on_complete tally + notify — CHANGED
**Code:** `:95-121` `on_complete`: counts `succeeded` = AiJobApplicationSummary with `status: :succeeded` and `created_at >= floor_at` (min BulkAiSummaryJobApplication.created_at); `deferred` = BulkAiSummaryJobApplication `status: :deferred`; `failed = ids.size - succeeded - deferred`. If `succeeded.zero? && failed.positive?` -> `notify_failure` else `notify_complete`. `notify_complete` (`:123-146`) broadcasts `AI_SUMMARY_BULK_COMPLETE` (succeededCount/failedCount/skippedCount=skipped_count+deferred/hiringStageLink) + `BulkJobApplicationAiSummaryResultMailer.complete(...).deliver_later`. `notify_failure` (`:148-173`) broadcasts `AI_SUMMARY_BULK_FAILED` + `BulkJobApplicationAiSummaryResultMailer.failed(...).deliver_later`.
**Map:** Part 8 lines 713-714 + lines 409-410.
**Verdict:** CHANGED. Concept confirmed but `deferred` rolled into `skippedCount`, and failed is computed by subtraction (not a row count) — undocumented. Mailer `.deliver_later` present (no Failure Pattern #4 violation).

---

## Per-candidate terminal-state trace (bulk)

For each claimed candidate in `each_iteration`:
- **No JobApplication / no bulk-status row** -> `return` (row stays `:processing`; later swept to `:failed` by `update_remaining_statuses_to_failed` if a retry/discard exhaustion fires). DEAD-END if job neither completes nor exhausts: row left `:processing`.
- **summary_already_processed** -> BulkAiSummaryJobApplication `:done`, return. Terminal.
- **Validation fails** (`result.success?` false) -> `return unless result.success?` at `:60`: row left `:processing`, no AiJobApplicationSummary, no AiJobApplicationSummaryStatus write. **DEAD-END** unless a later exhaustion sweeps it to `:failed`.
- **textract_pending** -> BulkAiSummaryJobApplication `:deferred`, return. Terminal-for-run (will be re-offered next bulk run; backfill textract job was already kicked off in the interactor for the no-textract set).
- **Textract ready branch** -> `CreateBulkAiSummaryGeneration` builds `:pending` AiJobApplicationSummary; `generate_ai_summary_with_credit_flow` drives `Orchestrate` -> summary reaches `:succeeded` (or `:failed`/`:retrying`). On `:succeeded`: `update_summary_status_record` sets status row to `current`; credit consumed; row -> `:done` (`:86`). On `CustomErrorAiSummary`: re-raised (`:87-88`) -> job retry; exhaustion sweeps remaining `:processing` rows to `:failed`. On other StandardError: logged, swallowed (`:89-92`), row left `:processing` -> swept to `:failed` only if a later iteration raises.

**Branch determination (textract ready vs processing):** decided in `BulkGenerateAiSummariesJob#each_iteration:65` via `result.textract_pending` from `ValidateAiSummaryGeneration` (`validate_ai_summary_generation.rb:44-60`). Bulk only ever calls the credit flow on the ready branch; the textract_processing summary status is never created on the bulk path (deferred instead).

## Desync windows (status row vs latest non-stale summary)

1. **initial_summary_pending lingers on failure.** `set_initial_summary_pending` (`textract_result.rb:104`) sets status row `initial_summary_pending`. If the pipeline ends in `:failed`/`:retrying` (not `:succeeded`), `update_summary_status_record` (`ai_job_application_summary.rb:69` `return unless ...status_succeeded?`) never fires. Status row stays `initial_summary_pending` indefinitely while the latest summary is `failed`. No clearing actor.
2. **regenerating lingers on failure.** `FindOrCreateAiJobApplicationSummaryStatus:15` sets `regenerating` when a prior succeeded summary exists and we begin a new run. If the new run fails, nothing resets it; status row stays `regenerating` (still showing the OLD summary's denormalized score/headline) while the new summary is `failed`. Cleared only by a future succeeded run -> `current`.
3. **Validation-fail / swallowed-StandardError candidates:** status row may have been moved to `initial_summary_pending` (line 72 runs before `generate_ai_summary`, but only AFTER validation success in each_iteration — so for the `result.success?`-false candidates the status row is untouched; it is touched only once we reach the credit flow). For the swallowed-StandardError path (`:89-92`) after the credit flow began, status row could be `initial_summary_pending` with a `failed`/incomplete summary — same as window 1.
4. **counter_culture drift:** `ai_job_application_summary_statuses.status IN (2,3)` (current/regenerating) maintains `jobs.ai_job_application_summaries_count` (`ai_job_application_summary_status.rb:7`). `update` (not `update_columns`) at `ai_job_application_summary.rb:74` keeps counter_culture firing; the `update_columns` writes at `textract_result.rb:104` (initial_summary_pending) and `find_or_create...:15` (regenerating) bypass... note `regenerating` IS counted (value 3) but was written via `update_columns`, so the counter is NOT incremented when entering regenerating — potential counter drift surface.

## Dead ends

- `each_iteration` validation-fail (`:60`) and swallowed-StandardError (`:89-92`) leave `BulkAiSummaryJobApplication` at `:processing` with no advancing actor unless a later retry/discard exhaustion sweeps via `update_remaining_statuses_to_failed`. If the batch otherwise completes cleanly (`on_complete` runs, no exhaustion), those rows remain `:processing` permanently and are counted as `failed` by subtraction in `on_complete` but their row status never reflects it.
