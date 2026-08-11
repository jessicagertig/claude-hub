# S-E Adversarial Review — pass 6

**Slice:** S-E — Textract-processing handoff: the `queue_ai_summary_job` callback finds an existing `textract_processing` summary and runs it to terminal.
**Method:** Re-read current code from scratch; refuted each map statement in the "Trigger E — Textract Processing Handoff (S-E)" section (candidate map lines 183-198) against literal code.

## Files traced
- `app/models/textract_result.rb:7,61-89,98-108,110-112,114-144`
- `app/jobs/generate_ai_job_application_summary_job.rb:11-78`
- `app/services/ai_job_application_action/orchestrate.rb:9-50,54-104`
- `app/services/ai_job_application_action/summary/generate.rb:11-185`
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb:11-69`
- `app/services/ai_job_application_action/scoring/score_job_application.rb:23,32,117-124`
- `app/models/ai_job_application_summary.rb:8,10-23,29-31,57-98,100-111`
- `app/interactors/find_or_create_ai_job_application_summary_status.rb:6-45`
- `app/models/ai_job_criteria.rb:7-29`
- `app/models/job_application.rb:31,32`
- `db/schema.rb:147-156` (`requested_by_organization_user_id` column)
- Old map `textract-ai-summary-map-6-6-2026-COPY.md:437-441,699`

## Verdicts (per map statement)

1. **(L184) S-E enqueues WITH `requesting_organization_user_id = ai_summary_waiting_on_textract.requested_by_organization_user_id` (`textract_result.rb:128-131`); AI_SUMMARY_COMPLETE broadcasts on completion (`generate_ai_job_application_summary_job.rb:34`, action `:72-76`).** — AGREE. `textract_result.rb:128-131` literal; `requested_by_organization_user_id` column exists `schema.rb:156`; job `:34` `broadcast_completion(... requesting_organization_user_id) if requesting_organization_user_id`; action `:72-76` `GlobalChannel.broadcast_to(... action: 'AI_SUMMARY_COMPLETE' ...)`. Old map (L699) said "User Broadcast: None" — MAP-WRONG claim is correct.

2. **(L185) Waiting summary transitioned `textract_processing → extracting` via `.update` in `Summary::Generate` (`generate.rb:31-33`), NOT `update_columns`.** — AGREE. Exact write is `generate.rb:32` `existing_ai_summary.update(status: :extracting) unless existing_ai_summary.status_extracting?` (`.update`, callback-firing). Range `:31-33` brackets the `if`/assign; the literal transition write is `:32`. Substantively correct.

3. **(L186) Selection is `textract_result.rb:121-123` `job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).first` — JobApplication-scoped, stale:false, `.first` no explicit order.** — AGREE. Literal at `:121-123`. No `.order`; `.first` picks DB-default order when multiple non-stale `textract_processing` summaries exist.

4. **(L187) `if`-branch (`:125`) only reached after `:115` `return unless textract_job_result_text.present?`, `:116` `return unless saved_change_to_textract_job_result_text?`, `:119` `return unless organization`.** — AGREE. Literal at `textract_result.rb:115,116,119`.

5. **(L188) `set_initial_summary_pending` sets row to `initial_summary_pending` before pipeline (`:104-107` update_columns), guarded `:101` `return unless status_record && latest_summary` AND `:102` `return unless status_none? || status_initial_summary_pending?`.** — AGREE. Literal at `textract_result.rb:101,102,104-107`.

6. **(L189) `BROADCAST_STATUSES` (`ai_job_application_summary.rb:23`) omits `awaiting_job_criteria` and `retrying`; transition into `awaiting_job_criteria` (`orchestrate.rb:72`) emits no `ai_summary_status_change`.** — AGREE. `ai_job_application_summary.rb:23` literal excludes both; `broadcast_status_change` `:102` `return unless BROADCAST_STATUSES.include?(status)`; `orchestrate.rb:72` `@ai_job_application_summary.update(status: :awaiting_job_criteria)`.

7. **(L190) Handoff re-runs `ValidateAiSummaryGeneration` (`:126`); on failure destroys waiting summary + AI_SUMMARY_FAILED (`:132-135`); on success advances `extracting → summarizing → awaiting_job_criteria → scoring → integrating → succeeded` (terminal `integrate_analysis.rb:49-53`) or rests at `awaiting_job_criteria` (`orchestrate.rb:72,80-81`).** — AGREE. `textract_result.rb:126,132-135` literal. Chain verified: Generate `:32/65/102→summarizing/169`; Orchestrate `check_criteria_and_score:72` awaiting; ScoreJobApplication `:32` scoring, `:122` integrating; IntegrateAnalysis `:49-53` succeeded. Rest path `orchestrate.rb:80-81`.

8. **(L191) `succeeded` terminal write is `.update` (callback-firing) `integrate_analysis.rb:53`; this fires `after_commit :update_summary_status_record`.** — AGREE. `integrate_analysis.rb:49-53` `update(integrated_role_analysis:, status: :succeeded)`; `ai_job_application_summary.rb:30` `after_commit :update_summary_status_record, on: :update`.

9. **(L192) Status row reaches `'current'` via `update_summary_status_record` (`ai_job_application_summary.rb:69-80`, guarded `saved_change_to_status? && status_succeeded?`), driven by succeeded at `integrate_analysis.rb:53`.** — AGREE. `:69` guard, `:74-80` `.update(... status: 'current' ...)`.

10. **(L193) At `awaiting_job_criteria` rest the row stays `initial_summary_pending` because `update_summary_status_record` fires only on `status_succeeded?` (`:69`) — desync window.** — AGREE. `:69` guard confirms; no other writer advances the row at criteria rest.

11. **(L194) Resuming actor is `AiJobCriteria#resume_waiting_summaries` (`ai_job_criteria.rb:17,22-27`), re-enqueues `GenerateAiJobApplicationSummaryJob` when criteria succeeds; `orchestrate.rb:80` only kicks off criteria.** — AGREE. `ai_job_criteria.rb:17` `after_commit :resume_waiting_summaries, on: [:update]`; `:22` guard `saved_change_to_status? && status_succeeded?`; `:24-27` re-enqueue. `orchestrate.rb:80` `extract_job_criteria`.

12. **(L195) `CustomErrorAiSummary` sets waiting summary `:retrying` (`generate.rb:175` update_columns); `retry_on … attempts: 3` (`:13`); exhaustion sets `:failed` (`:19`) and broadcasts completion (`:20`).** — AGREE. `generate.rb:175` `update_columns(status: :retrying ...)`; job `:13` `retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3`; `:19` `update_columns(status: :failed ...)`; `:20` `broadcast_completion(...)`. (Note also IntegrateAnalysis/ScoreJobApplication set `:retrying` on `CustomErrorAiSummary` — `integrate_analysis.rb:59`, `score_job_application.rb:130` — same retry surface; map's `generate.rb:175` example is one of three.)

13. **(L196) `:68` early return does NOT fire for the waiting `textract_processing` summary (not succeeded); `latest_ai_job_application_summary` (`job_application.rb:31`, order desc) resolves to it, `status_succeeded?` false.** — AGREE. `textract_result.rb:67-68` `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`; waiting summary is `textract_processing` → false → does not fire. `job_application.rb:31` `has_one :latest_ai_job_application_summary, -> { order(created_at: :desc) }`. (Map calls it a "method"; it is actually a `has_one` association — immaterial, line and ordering cited correctly.)

14. **(L197) S-E driven by `TextractResult#generate_ai_summary_with_credit_flow` (`generate_ai_job_application_summary_job.rb:32`) → `find_or_create_ai_job_application_summary_status` (`:70`), `set_initial_summary_pending` (`:72`), `generate_ai_summary` → `Orchestrate` (`:74`, def `:110-112`).** — AGREE. Job `:32` `textract_result.generate_ai_summary_with_credit_flow`; method body `:70,72,74`; `:110-112` `def generate_ai_summary … Orchestrate.new(textract_result_id: id).call`.

15. **(L198) S-E success charges a credit: `textract_result.rb:82` passes → `:84` `CreateAiCreditBalanceTransaction.call`, then `:87-88` Notify.** — AGREE. `:82` `return unless ai_job_application_summary&.status_succeeded?`; `:84` charge; `:87-88` `NotifyZeroAiCredits`/`NotifyLowAiCredits`. On the direct S-E path the waiting summary belongs to the firing TextractResult (relinked via `submit_resume_to_textract.rb:25-26`), so `:77` `ai_job_application_summaries.order(created_at: :desc).first` is non-empty → credit charges.

## Omissions (S-E section)

- **Co-firing `destroy_previous_textract_results` on the S-E terminal write.** The same succeeded `.update` (`integrate_analysis.rb:53`) that fires `update_summary_status_record` ALSO fires `after_commit :destroy_previous_textract_results, on: :update` (`ai_job_application_summary.rb:29,47-55`), which destroys prior non-succeeded TextractResults older than this result. Real side effect of the S-E terminal write; not named in the S-E section. (Minor — TextractResult cleanup, cross-slice.)
- **`ai_summary_succeeded` JobChannel broadcast on S-E success.** `update_summary_status_record` also broadcasts `JobChannel … event: 'ai_summary_succeeded'` (`ai_job_application_summary.rb:93-97`) after flipping the row to `current`. This is the user-visible stage-list refetch signal on the S-E happy path. The S-E section names the `current` flip (L192) but not this broadcast (it is documented for bulk at L137 / F1, not co-located in S-E). (Minor.)

## Conclusion
All 15 S-E map statements AGREE against literal current code. Two minor omissions (co-firing `destroy_previous_textract_results`; `ai_summary_succeeded` JobChannel broadcast on success) are real but cross-referenced elsewhere in the map. Because omissions is non-empty, clean = false.
