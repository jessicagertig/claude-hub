# Adversarial Review — Slice S-E (pass 5)

**Slice:** S-E — Textract-processing handoff: the callback finds an existing `textract_processing` summary and runs it; trace which record advances and to which terminal.

**Method:** Re-read all cited code from scratch. Candidate map section = lines 162–175 of `backend-flow-map-2026-06-17.md` (plus cross-cited lines).

Files traced:
`app/models/textract_result.rb` → `app/jobs/generate_ai_job_application_summary_job.rb` → `app/models/ai_job_application_summary.rb` → `app/services/ai_job_application_action/orchestrate.rb` → `app/services/ai_job_application_action/summary/generate.rb` → `app/services/ai_job_application_action/scoring/score_job_application.rb` → `app/services/ai_job_application_action/scoring/integrate_analysis.rb` → `app/models/job_application.rb` → `app/models/ai_job_criteria.rb` → `db/schema.rb`

---

## Verdicts

### L163 — S-E enqueues WITH requesting user → AI_SUMMARY_COMPLETE broadcasts
AGREE. `textract_result.rb:128-131` enqueues `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id, requesting_organization_user_id: ai_summary_waiting_on_textract.requested_by_organization_user_id)`. Job `:34` `broadcast_completion(...) if requesting_organization_user_id`; action `AI_SUMMARY_COMPLETE` built `:65-76`. Column `requested_by_organization_user_id` exists (`db/schema.rb:156`).

### L164 — waiting summary transitioned textract_processing → extracting via `.update` (not update_columns)
AGREE. `generate.rb:31-33`: reuse branch matches `status_textract_processing?` and runs `existing_ai_summary.update(status: :extracting) unless existing_ai_summary.status_extracting?` — `.update`, callback-firing.

### L165 — waiting-summary selection `where(status: :textract_processing, stale: false).first`, JA-scoped, no order
AGREE. `textract_result.rb:121-123` literal: `job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).first`.

### L166 — handoff `if` branch reached only after :115 text-present, :116 saved_change, :119 organization guards
AGREE. `textract_result.rb:115` `return unless textract_job_result_text.present?`; `:116` `return unless saved_change_to_textract_job_result_text?`; `:118-119` `organization = ...; return unless organization`. `if` at `:125`.

### L167 — set_initial_summary_pending guards (:101 status_record&&latest_summary, :102 none?/initial_summary_pending?), update_columns :104-107
AGREE. `textract_result.rb:101` `return unless status_record && latest_summary`; `:102` `return unless status_record.status_none? || status_record.status_initial_summary_pending?`; `:104-107` `status_record.update_columns(ai_job_application_summary_id:, status: 'initial_summary_pending')`.

### L168 — BROADCAST_STATUSES omits awaiting_job_criteria & retrying; into-awaiting (orchestrate.rb:72) emits no ai_summary_status_change
AGREE. `ai_job_application_summary.rb:23` BROADCAST_STATUSES = pending/textract_processing/extracting/summarizing/scoring/integrating/succeeded/failed (no awaiting_job_criteria, no retrying). `broadcast_status_change` `:102` `return unless BROADCAST_STATUSES.include?(status)`; event `ai_summary_status_change` `:107`. orchestrate.rb:72 sets `awaiting_job_criteria`, not in list → no broadcast.

### L169 — re-runs ValidateAiSummaryGeneration (:126); fail → destroy waiting summary + AI_SUMMARY_FAILED (:132-135); success → extracting→summarizing→awaiting_job_criteria→scoring→integrating→succeeded (terminal integrate_analysis.rb:49-53) OR rests at awaiting_job_criteria (orchestrate.rb:72, :80-81)
AGREE. `textract_result.rb:126` `ValidateAiSummaryGeneration.call(...)`; `:132-135` else branch destroys + broadcasts. Status sequence confirmed: extracting `generate.rb:38`/`:32`; summarizing `generate.rb:65`; awaiting_job_criteria `orchestrate.rb:72` / `score_job_application.rb:23,45`; scoring `score_job_application.rb:32`; integrating `score_job_application.rb:122`; succeeded `integrate_analysis.rb:51` (in `update_params` :49-52, applied :53). Rest at awaiting via `orchestrate.rb:72` then `:80` extract_job_criteria + `:81` return.

### L170 — succeeded terminal write is `.update` (integrate_analysis.rb:53), firing after_commit update_summary_status_record
AGREE. `integrate_analysis.rb:53` `unless @ai_job_application_summary.update(update_params)` where update_params (`:49-52`) = `{integrated_role_analysis:, status: :succeeded}`. `.update` is callback-firing; `ai_job_application_summary.rb:30` `after_commit :update_summary_status_record, on: :update`.

### L171 — status row → 'current' via update_summary_status_record, after_commit on:update, guarded saved_change_to_status? && status_succeeded?, driven by succeeded at integrate_analysis.rb:53
AGREE. `ai_job_application_summary.rb:30` registration; `:69` `return unless saved_change_to_status? && status_succeeded?`; `:74-80` `.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)`.

### L172 — awaiting_job_criteria rest: row stays initial_summary_pending (set textract_result.rb:104-107); writer fires only on status_succeeded? (ai_job_application_summary.rb:69)
AGREE. set at `textract_result.rb:104-107`; writer guard `ai_job_application_summary.rb:69` requires `status_succeeded?`; awaiting_job_criteria ≠ succeeded → no flip.

### L173 — orchestrate.rb:80 only kicks off criteria; resumed by AiJobCriteria#resume_waiting_summaries (ai_job_criteria.rb:17,22-27)
AGREE. `orchestrate.rb:80` `...extract_job_criteria unless ...status_pending? || ...status_in_progress?`; `:81` return. `ai_job_criteria.rb:17` `after_commit :resume_waiting_summaries, on: [:update]`; `:22` guard `saved_change_to_status? && status_succeeded?`; `:24-27` re-enqueues `GenerateAiJobApplicationSummaryJob(textract_result_id:)` for each `awaiting_job_criteria` summary, no requesting user.

### L174 — CustomErrorAiSummary → :retrying (generate.rb:175 update_columns); retry_on attempts:3 (:13); exhaustion → :failed (:19) + broadcast (:20)
AGREE. `generate.rb:175` `ai_summary&.update_columns(status: :retrying, error_message: e&.message)`. Job `:13` `retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3`; `:19` `ai_summary&.update_columns(status: :failed, error_message: error&.message)`; `:20` `broadcast_completion(...)`.

### L175 — :68 early return does NOT fire for the waiting textract_processing summary; latest_ai_job_application_summary (job_application.rb:31, order created_at desc) resolves to it, status_succeeded? false
AGREE. `textract_result.rb:67-68` `latest_ai_summary = job_application.latest_ai_job_application_summary; return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`. `job_application.rb:31` `has_one :latest_ai_job_application_summary, -> { order(created_at: :desc) }`. Waiting summary status is textract_processing → not succeeded → guard skipped.

---

## Omissions

1. **Credit charge on S-E success not stated in the S-E section.** The S-E job execution path runs through `generate_ai_summary_with_credit_flow`, not `Orchestrate` directly. On the waiting summary reaching `succeeded`, `textract_result.rb:82` `return unless ai_job_application_summary&.status_succeeded?` passes and `:84` `CreateAiCreditBalanceTransaction.call(summary: ...)` charges a credit (then `:87-88` NotifyZeroAiCredits / NotifyLowAiCredits). The map states this credit charge explicitly for the X3 resumed path (L198) but the S-E section (L162-175) never names the credit consumption as part of the S-E terminal, even though "trace to terminal" is the slice's mandate. Material to the lifecycle.

2. **S-E entry is `generate_ai_summary_with_credit_flow`, not `Orchestrate` directly.** The enqueued `GenerateAiJobApplicationSummaryJob#perform` calls `textract_result.generate_ai_summary_with_credit_flow` (`generate_ai_job_application_summary_job.rb:32`), which itself invokes `find_or_create_ai_job_application_summary_status` (`textract_result.rb:70`), `set_initial_summary_pending` (`:72`), then `generate_ai_summary` → `Orchestrate` (`:74`/`:110-112`). The S-E section names set_initial_summary_pending (L167) but does not state the method that drives the whole S-E run, leaving the actor chain implicit.

---

## Conclusion

Every map statement about S-E verifies against current code (all AGREE). Two omissions noted (credit charge on success; the `generate_ai_summary_with_credit_flow` entry as the driving actor). `clean = false` because omissions is non-empty.
