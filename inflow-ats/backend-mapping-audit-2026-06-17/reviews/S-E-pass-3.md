# S-E Adversarial Review — Pass 3

**Slice:** S-E — Textract-processing handoff: the `queue_ai_summary_job` after_commit finds an existing `textract_processing` summary and runs it. Trace which record, what advances it, to terminal.

**Method:** Re-read code from scratch. Candidate map section at `backend-flow-map-2026-06-17.md:119-125` ("Trigger E — Textract Processing Handoff (S-E)") plus cross-referenced Part-2 bridge prose.

**Files traced:**
`textract_result.rb:114-144 (queue_ai_summary_job)` → `textract_result.rb:61-89 (generate_ai_summary_with_credit_flow)` → `textract_result.rb:98-108 (set_initial_summary_pending)` → `generate_ai_job_application_summary_job.rb:24-76` → `orchestrate.rb:9-50` → `summary/generate.rb:11-185` → `score_job_application.rb:23-122` → `integrate_analysis.rb:11-69`; plus `ai_job_application_summary.rb:10-23,69-97,100-111` and `job_application.rb:31`.

---

## Verdicts

### Claim 1 (map :120) — MAP-WRONG: old map said "Trigger E User Broadcast: None"; actual S-E enqueues WITH `requesting_organization_user_id = ai_summary_waiting_on_textract.requested_by_organization_user_id` (`textract_result.rb:128-131`), so `AI_SUMMARY_COMPLETE` broadcasts on completion (`generate_ai_job_application_summary_job.rb:34`, action `:72-76`).
**AGREE.** `textract_result.rb:128-131`:
```
GenerateAiJobApplicationSummaryJob.perform_later(
  textract_result_id: id,
  requesting_organization_user_id: ai_summary_waiting_on_textract.requested_by_organization_user_id
)
```
`generate_ai_job_application_summary_job.rb:34`: `broadcast_completion(textract_result, requesting_organization_user_id) if requesting_organization_user_id`; broadcast at `:72-76` `GlobalChannel.broadcast_to(user, action: 'AI_SUMMARY_COMPLETE', payload: payload)`.

### Claim 2 (map :121) — MAP-WRONG: the waiting `textract_processing` summary is transitioned `textract_processing → extracting` via `.update` in `Summary::Generate` (`generate.rb:32`), NOT `update_columns`.
**AGREE.** `summary/generate.rb:31-33`: the existing summary matching `status_textract_processing?` → `:32` `existing_ai_summary.update(status: :extracting) unless existing_ai_summary.status_extracting?`. It is `.update`, not `update_columns`.

### Claim 3 (map :122) — NEW: `set_initial_summary_pending` sets the status row to `initial_summary_pending` before the pipeline runs (`textract_result.rb:98-108`, `update_columns :104-107`, guarded `:102`).
**AGREE.** `textract_result.rb:98` `def set_initial_summary_pending(status_result)`; `:102` `return unless status_record.status_none? || status_record.status_initial_summary_pending?`; `:104-107` `status_record.update_columns(ai_job_application_summary_id: latest_summary.id, status: 'initial_summary_pending')`. Reached from `:72` `set_initial_summary_pending(status_result) if status_result.success?`. Note `:101` also guards `return unless status_record && latest_summary` — see omissions.

### Claim 4 (map :123) — NEW: `BROADCAST_STATUSES` (`ai_job_application_summary.rb:23`) omits `awaiting_job_criteria` and `retrying`; the transition into `awaiting_job_criteria` (`orchestrate.rb:72`) emits no `ai_summary_status_change`.
**AGREE.** `ai_job_application_summary.rb:23`: `BROADCAST_STATUSES = %w[pending textract_processing extracting summarizing scoring integrating succeeded failed].freeze` — `awaiting_job_criteria` and `retrying` absent. `broadcast_status_change` (`:100-102`) returns unless `BROADCAST_STATUSES.include?(status)`. `orchestrate.rb:72` `@ai_job_application_summary.update(status: :awaiting_job_criteria)` therefore emits no `ai_summary_status_change`.

### Claim 5 (map :124) — NEW handoff terminal/resting: on success the run advances the waiting `textract_processing` summary through `extracting → summarizing → awaiting_job_criteria → scoring → integrating → succeeded` (terminal at `integrate_analysis.rb:49-53`), or comes to rest at `awaiting_job_criteria` (`orchestrate.rb:72`) pending criteria.
**AGREE.** Trace: Orchestrate selects latest summary (`orchestrate.rb:15`), `status_textract_processing?` matches case at `:23` → `run_summary` (`:26`) → `Summary::Generate` sets `extracting` (`generate.rb:32`) then `summarizing` (`generate.rb:64-68`). `check_criteria_and_score` (`orchestrate.rb:68`) sets `awaiting_job_criteria` (`:72`); if `ai_job_criteria&.status_succeeded?` → `run_scoring` sets `scoring` (`score_job_application.rb:32`) and `integrating` (`score_job_application.rb:122`) → `run_integration` → `IntegrateAnalysis` sets `succeeded` (`integrate_analysis.rb:49-51` `update_params = { integrated_role_analysis:, status: :succeeded }`, `:53` `@ai_job_application_summary.update(update_params)`). The `awaiting_job_criteria` rest is real: `orchestrate.rb:80` calls `extract_job_criteria` and `:81` `return`, leaving the summary at `awaiting_job_criteria`.

### Claim 6 (map :124, sub) — on validation failure it destroys the already-existing waiting summary + `AI_SUMMARY_FAILED` broadcast (`:132-135`).
**AGREE.** `textract_result.rb:132-135` (the `else` of `if result.success?`): `:133` `requesting_organization_user = OrganizationUser.find_by(id: ai_summary_waiting_on_textract.requested_by_organization_user_id)`; `:134` `ai_summary_waiting_on_textract.destroy`; `:135` `broadcast_ai_summary_failed(requesting_organization_user, result.error)`. The handoff `if` branch re-runs `ValidateAiSummaryGeneration` at `:126`.

### Claim 7 (map :125) — NOTE: `generate_ai_summary_with_credit_flow`'s `:68` early return does NOT fire for the waiting `textract_processing` summary (status not succeeded), so the handoff proceeds past it.
**AGREE.** `textract_result.rb:67-68`: `latest_ai_summary = job_application.latest_ai_job_application_summary` / `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`. `latest_ai_job_application_summary` is `has_one ... -> { order(created_at: :desc) }` (`job_application.rb:31`), which on the handoff path resolves to the waiting `textract_processing` summary; `status_succeeded?` is false → guard does not fire.

---

## Omissions

1. **Which record the bridge selects, and the scope, is not stated.** The waiting summary is chosen at `textract_result.rb:121-123` `job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).first` — JobApplication-scoped, filtered to non-stale `textract_processing`, taking `.first` (no explicit order). The map's S-E section names "an existing textract_processing summary" but never cites this exact selection (`:121-123`) nor the `stale: false` filter, which is load-bearing for which record advances.

2. **`queue_ai_summary_job` entry guards not stated for S-E.** The handoff only runs when `textract_result.rb:115` `return unless textract_job_result_text.present?` and `:116` `return unless saved_change_to_textract_job_result_text?` and `:119` `return unless organization` all pass. The S-E section omits these preconditions; the handoff `if` branch (`:125`) is only reached after them.

3. **`set_initial_summary_pending`'s `latest_summary && status_record` guard (`:101`) is omitted.** Map cites the enum-status guard `:102` but not `:101` `return unless status_record && latest_summary`. On the handoff path `latest_summary` (the waiting summary) is present, so it passes, but the guard is part of the writer's behavior.

4. **The status row is NOT advanced off `initial_summary_pending` to `current` until the summary itself reaches `succeeded`.** On the handoff success path the status row write to `current` happens via `update_summary_status_record` (`ai_job_application_summary.rb:69-80`, `after_commit on: :update`, guarded `saved_change_to_status? && status_succeeded?`), driven by the `succeeded` transition at `integrate_analysis.rb:53`. The S-E section documents `set_initial_summary_pending` (the pre-pipeline write) but never states where/when the status row reaches `current` on this path — i.e., it is the same `succeeded`-triggered writer as every other path, not an S-E-specific write.

5. **Retry/exhaustion terminal for the waiting summary is omitted.** If the pipeline raises `CustomErrorAiSummary`, `Summary::Generate` sets the waiting summary to `:retrying` (`generate.rb:175` `ai_summary&.update_columns(status: :retrying, ...)`) and re-raises; `GenerateAiJobApplicationSummaryJob` `retry_on CustomErrorAiSummary, attempts: 3` (`:13`), and on exhaustion the block sets the summary `:failed` (`:19` `ai_summary&.update_columns(status: :failed, ...)`) and broadcasts completion (`:20`). The S-E section traces only the clean success/rest path, not this exhaustion terminal for the same waiting record.

---

## Conclusion

All 7 explicit map statements for S-E AGREE against current code. However, the section omits five behaviors material to "trace which record, what advances it, to terminal" (the exact waiting-summary selection + `stale: false` filter, the `queue_ai_summary_job` entry guards, the `:101` writer guard, where the status row reaches `current`, and the retry-exhaustion `:failed` terminal). Per default-to-skepticism and the clean rule (clean only if every verdict AGREE AND omissions empty):

**clean = false** (verdicts all AGREE, but omissions non-empty).
