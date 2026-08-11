# T2 Adversarial Review — Pass 2

**Slice:** T2 — Manual resume upload / replacement (internal app). Controller update action resume-param path → `SubmitResumeToTextractJob`. Stale-marking of existing `AiJobApplicationSummary`; what happens to the `AiJobApplicationSummaryStatus` row.

**Method:** Re-read code from scratch. Files opened:
- `app/controllers/api/v1/job_applications_controller.rb:95-127`
- `app/services/submit_resume_to_textract.rb` (full)
- `app/models/ai_job_application_summary.rb` (full)
- `app/models/textract_result.rb` (full)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` (full)
- `app/services/ai_job_application_action/orchestrate.rb` (full)
- `app/models/job_application.rb:29-32, 40-49, 158-171`
- `app/models/ai_job_application_summary_status.rb` (full)

## Verdicts

### V1 — Controller update resume path location & gate
**Map (line 186, 493):** "After `if job_application.update(temp_params)` (line 107): `if temp_params.key?(:resume) && temp_params[:resume].present?` → `DocxToPdfJob.perform_later`, then `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, current_organization)` → `SubmitResumeToTextractJob.perform_later` (line 113)."
**AGREE** — `job_applications_controller.rb:107` `if job_application.update(temp_params)`; `:110` `if temp_params.key?(:resume) && temp_params[:resume].present?`; `:112` `DocxToPdfJob.perform_later(job_application.id)`; `:113` `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, current_organization)`; `:114` `SubmitResumeToTextractJob.perform_later(job_application.id)`.

### V2 — No summary created on the update path
**Map (line 187):** "Creates NO `AiJobApplicationSummary` and does NOT call `CreateAiSummaryGeneration` directly."
**AGREE** — Controller block `job_applications_controller.rb:107-116` only enqueues `DocxToPdfJob` and `SubmitResumeToTextractJob`. `SubmitResumeToTextract#submit_resume` writes only `TextractResult` + the conditional `update_all(stale: true)` on summaries; it never builds an `AiJobApplicationSummary`.

### V3 — Conditional stale-marking
**Map (line 151, 188):** "Conditional stale-marking (lines 18-20): `unless @job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).exists?` → `@job_application.ai_job_application_summaries.update_all(stale: true)`."
**AGREE** — `submit_resume_to_textract.rb:18` `unless @job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).exists?`; `:19` `@job_application.ai_job_application_summaries.update_all(stale: true)`. Note: map's coverage census (line 590) cites the `update_all` at `:19` and the build at `:22` — both confirmed against current code.

### V4 — Status row NOT touched by SubmitResumeToTextract
**Map (line 188, 493):** "The status row is NOT touched by `SubmitResumeToTextract`; its only summary-table write is the conditional `update_all(stale: true)`."
**AGREE** — `submit_resume_to_textract.rb` (full file, 42 lines) contains no reference to `ai_job_application_summary_status`, `find_or_create_ai_job_application_summary_status`, or the FindOrCreate interactor. Writes are: summaries `update_all(stale:)` (`:19`), `textract_results.build` (`:22`)+save, `waiting_summary.update_columns(textract_result_id:)` (`:26`), failure `update_columns(textract_job_status: 'failed')` (`:33,39`).

### V5 — Update path does not re-create/touch the status row via callback
**Map (line 493):** matrix row 2 "Status row: untouched by submit; staled via update_all."
**AGREE** — `enqueue_new_job_application` (the only callback that calls `find_or_create_ai_job_application_summary_status`, `job_application.rb:170`) is registered `after_commit ... on: [:create]` (`job_application.rb:45`). The T2 path is an UPDATE, so this callback does not fire. No status-row write occurs in the controller update block or in `SubmitResumeToTextract`.

### V6 — `regenerating` IS set; guard is the row's associated summary being succeeded
**Map (line 27):** "`regenerating` IS set, at `find_or_create_ai_job_application_summary_status.rb:14-15`, guarded on the row's associated summary being `status_succeeded?`."
**AGREE** — `find_or_create_ai_job_application_summary_status.rb:12` `summary = @status_record.ai_job_application_summary`; `:14` `if summary&.status_succeeded?`; `:15` `@status_record.update_columns(status: 'regenerating')`. The guard is the STATUS ROW's denormalized FK target (`ai_job_application_summary`), not `latest_ai_job_application_summary`. Map wording "the row's associated summary" is precise.

### V7 — `update_summary_status_record` writes `current` via `.update`, status enum value (not integer-7/`update_columns`)
**Map (line 31):** "`update_summary_status_record` sets `status: 'current'` (enum value 2) via `.update`, NOT `'succeeded'`/integer-7 via `update_columns`, and writes no `regenerating` column."
**AGREE** — `ai_job_application_summary.rb:74` `if ai_job_application_summary_status.update(`; `:75` `ai_job_application_summary_id: id,`; `:76` `status: 'current',`; `:77-79` `score_percentage:`, `headline:`, `integrated_role_analysis:`. Guard `:69` `return unless saved_change_to_status? && status_succeeded?`; early-return on no row `:72` `return unless ai_job_application_summary_status`. No `regenerating` column written.

### V8 — `create_status_record` after_commit removed from AiJobApplicationSummary
**Map (line 29):** "`after_commit :create_status_record, on: :create` no longer exists on `AiJobApplicationSummary`."
**AGREE** — `ai_job_application_summary.rb:29-31` callbacks are `destroy_previous_textract_results` (`:29`), `update_summary_status_record` (`:30`), `broadcast_status_change` (`:31`). No `create_status_record` anywhere in the file.

### V9 — Status enum has no `regenerating` boolean; 4-value enum
**Map (line 30):** "`AiJobApplicationSummaryStatus` has its own 4-value status enum and NO `regenerating` boolean column."
**AGREE** — `ai_job_application_summary_status.rb:9-14` `enum status: { none: 0, initial_summary_pending: 1, current: 2, regenerating: 3 }, _prefix: true`. No boolean column. `validates :job_application_id, uniqueness: true` (`:16`).

### V10 — Desync window: current → regenerating → current, denormalized cols never cleared
**Map (line 32):** "Status-row denormalized-column desync window during replacement (status flips `current` → `regenerating` → `current`; denormalized score/headline/analysis never cleared during the window)."
**AGREE** — On T2 replacement, the prior succeeded summary is staled (`submit_resume_to_textract.rb:19`) but stays `status_succeeded?`; later `generate_ai_summary_with_credit_flow` → `find_or_create...rb:14` flips the row to `regenerating` via `update_columns(status: 'regenerating')` (`:15`) WITHOUT touching `score_percentage`/`headline`/`integrated_role_analysis`/`ai_job_application_summary_id`. The eventual `current` reset (`ai_job_application_summary.rb:74-80`) overwrites them only on a NEW summary success. Old denormalized data persists throughout the window. Confirmed against code.

### V11 — Replacement guard no longer short-circuits the staled-succeeded case
**Map (line 28):** "The `generate_ai_summary_with_credit_flow` guard is now `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?` (`textract_result.rb:67-68`). A staled-succeeded summary no longer short-circuits the credit flow's early return."
**AGREE** — `textract_result.rb:67` `latest_ai_summary = job_application.latest_ai_job_application_summary`; `:68` `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`. After T2's `update_all(stale: true)`, the latest is `succeeded && stale` → `!stale?` is false → the guard does NOT return → flow proceeds. Confirmed.

### V12 — D dead-end: stuck `regenerating`, 1 credit burned, no new summary
**Map (lines 86-87, 508):** auto path: latest summary is stale-succeeded; `Orchestrate#call` selects it (no stale filter, `orchestrate.rb:15`), hits the `succeeded` branch (`:46-48`) and returns; no new summary; `generate_ai_summary_with_credit_flow` re-fetches it, passes `status_succeeded?` (`:82`), charges 1 credit (`:84`); status row left `regenerating`, never reset to `current`.
**AGREE** — Chain verified: `orchestrate.rb:15` `@ai_job_application_summary = @job_application.ai_job_application_summaries.order(created_at: :desc).first` (no stale filter); `:46-48` `when ...status_succeeded?, ...status_failed? \n return`; `textract_result.rb:77` `ai_job_application_summary = ai_job_application_summaries.order(created_at: :desc).first`; `:82` `return unless ai_job_application_summary&.status_succeeded?` (passes for the stale-succeeded one); `:84` `CreateAiCreditBalanceTransaction.call(summary: ai_job_application_summary)`. Reset path `ai_job_application_summary.rb:69` requires `saved_change_to_status? && status_succeeded?` on a summary update — never occurs because no new summary runs. Row stuck `regenerating`. Confirmed.

### V13 — `latest_ai_job_application_summary` has no stale filter
**Map (line 86, implicit; line 316 for Orchestrate):** S-D reasoning depends on `latest` = `order(created_at: :desc)` with no stale filter.
**AGREE** — `job_application.rb:31` `has_one :latest_ai_job_application_summary, -> { order(created_at: :desc) }, class_name: 'AiJobApplicationSummary'`. No stale filter. Confirmed.

## Omissions

None material to T2. The map's T2 coverage (controller path, stale-marking, status-row untouched-by-submit, the deferred `regenerating` flip via the auto path, the D dead-end, the desync window) is complete and accurate. Minor observations that are present and correct in the map:
- The `regenerating` flip and credit burn happen on the LATER auto path (`queue_ai_summary_job` else branch → `generate_ai_summary_with_credit_flow`), not synchronously in the T2 controller action. The map correctly separates the synchronous controller/submit writes (Trigger 2 prose) from the deferred auto-regen consequences (Trigger D / S-D). No misattribution found.
- `queue_ai_summary_job` (`textract_result.rb:114-144`) for a T2 replacement on a job_application with no `textract_processing` waiting summary takes the ELSE branch (`:137`), gated on `should_auto_generate_ai_summaries?` (`:138`) — i.e., the D auto-regen only fires when auto-gen is enabled. The map captures this in Trigger D ("Textract callback else").

## Conclusion
Every map statement about the T2 slice is AGREE; no omissions. clean = true.
