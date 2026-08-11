# S-E Adversarial Review — Pass 4

Slice S-E: Textract-processing handoff — the `queue_ai_summary_job` callback finds an existing
`textract_processing` waiting summary and runs it to terminal.

Re-traced from scratch against current code. File chain followed:
`app/models/textract_result.rb:114-144` (queue_ai_summary_job / generate_ai_summary_with_credit_flow)
→ `app/models/job_application.rb:31` (latest_ai_job_application_summary)
→ `app/jobs/generate_ai_job_application_summary_job.rb` (perform / retry_on / broadcast_completion)
→ `app/services/ai_job_application_action/orchestrate.rb`
→ `app/services/ai_job_application_action/summary/generate.rb:30-33,175`
→ `app/services/ai_job_application_action/scoring/integrate_analysis.rb:49-69`
→ `app/models/ai_job_application_summary.rb:23,30,69-98,100-107`

## Verdicts on candidate-map S-E statements (lines 138-148)

1. (139) MAP-WRONG vs old map: S-E enqueues WITH `requesting_organization_user_id =
   ai_summary_waiting_on_textract.requested_by_organization_user_id` (`textract_result.rb:128-131`),
   so `AI_SUMMARY_COMPLETE` broadcasts on completion (`generate_ai_job_application_summary_job.rb:34`,
   action `:72-76`). **AGREE** — `textract_result.rb:128-131` literally passes
   `requesting_organization_user_id: ai_summary_waiting_on_textract.requested_by_organization_user_id`;
   `generate_ai_job_application_summary_job.rb:34` `broadcast_completion(... requesting_organization_user_id) if requesting_organization_user_id`;
   `:72-76` `GlobalChannel.broadcast_to(user, action: 'AI_SUMMARY_COMPLETE', payload: payload)`.

2. (140) The waiting `textract_processing` summary is transitioned `textract_processing → extracting`
   via `.update` in `Summary::Generate` (`generate.rb:31-33`), NOT `update_columns`. **AGREE** —
   `generate.rb:31` guard includes `existing_ai_summary.status_textract_processing?`; `:32`
   `existing_ai_summary.update(status: :extracting) unless existing_ai_summary.status_extracting?`.

3. (141) Waiting-summary selection is `textract_result.rb:121-123`
   `job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).first` —
   JobApplication-scoped, stale:false, `.first` no explicit order. **AGREE** — exact match `:121-123`.

4. (142) Handoff if-branch (`:125`) only reached after `:115` `return unless textract_job_result_text.present?`,
   `:116` `return unless saved_change_to_textract_job_result_text?`, `:119` `return unless organization`.
   **AGREE** — lines 115, 116, 119 read literally as stated; `if ai_summary_waiting_on_textract` at `:125`.

5. (143) `set_initial_summary_pending` sets the status row to `initial_summary_pending` before the pipeline
   (`textract_result.rb:98-108`, `update_columns :104-107`, guarded `:101` `return unless status_record && latest_summary`,
   `:102` `return unless status_record.status_none? || status_record.status_initial_summary_pending?`). **AGREE** —
   method body lines 98-108; `:104-107` `update_columns(ai_job_application_summary_id:..., status: 'initial_summary_pending')`;
   guards at 101 and 102 verbatim. Called from `generate_ai_summary_with_credit_flow:72` `set_initial_summary_pending(status_result) if status_result.success?`.

6. (144) `BROADCAST_STATUSES` (`ai_job_application_summary.rb:23`) omits `awaiting_job_criteria` and
   `retrying`; transition into `awaiting_job_criteria` (`orchestrate.rb:72`) emits no `ai_summary_status_change`.
   **AGREE** — line 23 lists `pending textract_processing extracting summarizing scoring integrating succeeded failed`
   (no `awaiting_job_criteria`, no `retrying`); `broadcast_status_change` returns unless `BROADCAST_STATUSES.include?(status)`
   (`:102`); `orchestrate.rb:72` `@ai_job_application_summary.update(status: :awaiting_job_criteria)`.

7. (145) Handoff terminal: `queue_ai_summary_job` RE-runs `ValidateAiSummaryGeneration` (`:126`) before enqueuing;
   on failure destroys waiting summary + AI_SUMMARY_FAILED broadcast (`:132-135`); on success advances through
   `extracting → summarizing → awaiting_job_criteria → scoring → integrating → succeeded` (terminal `integrate_analysis.rb:49-53`),
   or rests at `awaiting_job_criteria` (`orchestrate.rb:72`, `:80-81`) pending criteria. **AGREE** —
   `:126` ValidateAiSummaryGeneration.call; else block `:133-135` find user / `:134` `.destroy` / `:135` `broadcast_ai_summary_failed`;
   Orchestrate for `status_textract_processing?` hits `run_summary`+`check_criteria_and_score` (`:22-23,26-27`); succeeded
   set at `integrate_analysis.rb:51` (`status: :succeeded`) committed by `.update` at `:53`; rest at `orchestrate.rb:72`/`:80-81`.

8. (146) Status row reaches `current` on handoff success via `update_summary_status_record`
   (`ai_job_application_summary.rb:69-80`, after_commit on: :update, guarded `saved_change_to_status? && status_succeeded?`),
   driven by succeeded transition at `integrate_analysis.rb:53` — same writer as all paths, not S-E-specific. **AGREE** —
   callback registered `:30` `after_commit :update_summary_status_record, on: :update`; guard `:69`; `:74-80` `.update(... status: 'current' ...)`.

9. (147) Retry/exhaustion: `CustomErrorAiSummary` sets waiting summary `:retrying` (`generate.rb:175`, update_columns);
   `retry_on … attempts: 3` (`:13`); exhaustion sets `:failed` (`:19`) and broadcasts completion (`:20`). **AGREE** —
   `generate.rb:175` `ai_summary&.update_columns(status: :retrying, error_message: e&.message)`;
   `generate_ai_job_application_summary_job.rb:13` `retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3`;
   `:19` `ai_summary&.update_columns(status: :failed, error_message: error&.message)`; `:20` `broadcast_completion(...)`.

10. (148) NOTE: `generate_ai_summary_with_credit_flow`'s `:68` early return does NOT fire for the waiting
    `textract_processing` summary (status not succeeded); `job_application.latest_ai_job_application_summary`
    (`job_application.rb:31`, order desc) resolves to it, `status_succeeded?` false. **AGREE** —
    `textract_result.rb:67-68` `latest_ai_summary = job_application.latest_ai_job_application_summary` /
    `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`; `job_application.rb:31`
    `has_one :latest_ai_job_application_summary, -> { order(created_at: :desc) }`. A textract_processing summary
    is not succeeded → guard does not fire.

## Omissions (S-E-specific gaps in the candidate map)

A. IntegrateAnalysis terminal write to the SUMMARY's denormalized columns is via `.update` (callback-firing),
   which is the load-bearing reason the status row reaches `current`. The map's claim 145 cites `:49-53` for the
   terminal but does not state that `integrate_analysis.rb:53` uses `.update` (not `update_columns`) — and that this
   is precisely what fires the `after_commit :update_summary_status_record` in claim 146. The two claims are correct
   individually but the `.update`-fires-callback linkage at `integrate_analysis.rb:53` is not spelled out. Minor.

B. S-E rest-at-`awaiting_job_criteria` status-row desync not stated locally. When the handoff summary rests at
   `awaiting_job_criteria` (claim 145), the status row stays at `initial_summary_pending` (`set_initial_summary_pending`
   already ran at `textract_result.rb:104-107`); `update_summary_status_record` fires only on `status_succeeded?`
   (`ai_job_application_summary.rb:69`), so the row does NOT advance while the summary waits on criteria. The global
   desync claim (map line 162) covers this generally, but the S-E section presents `awaiting_job_criteria` as a clean
   rest without noting the row sits desynced at `initial_summary_pending` until criteria succeeds and the summary
   reaches `succeeded`.

C. The advancing actor out of `awaiting_job_criteria` is not named in the S-E section. `orchestrate.rb:80`
   `extract_job_criteria` only KICKS OFF criteria; the summary is resumed by `AiJobCriteria#resume_waiting_summaries`
   (`ai_job_criteria.rb:17,22-27`, documented in X3), which re-enqueues `GenerateAiJobApplicationSummaryJob`. S-E says
   "pending criteria" but does not name the cross-slice actor that ultimately drives the awaiting summary to terminal.
   Cross-referenced in X3 but not from S-E.

clean = false (all 10 verdicts AGREE, but three S-E-local omissions).
