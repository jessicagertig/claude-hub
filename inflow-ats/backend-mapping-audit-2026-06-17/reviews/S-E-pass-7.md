# S-E Adversarial Review — Pass 7

**Slice:** S-E — Textract-processing handoff: the bridge finds an existing `textract_processing` summary and runs it to terminal.
**Candidate map section reviewed:** lines 199-216 (Trigger E — Textract Processing Handoff), with cross-refs to lines 803, 818-820, 825.
**Method:** Re-read all S-E code from scratch. Files traced:
`textract_result.rb` (bridge `queue_ai_summary_job` :114-144, credit flow :61-89, `set_initial_summary_pending` :98-108) → `generate_ai_job_application_summary_job.rb` (:13-46, broadcast :50-77) → `orchestrate.rb` (:9-104) → `generate.rb` (:11-185) → `integrate_analysis.rb` (:11-69) → `ai_job_application_summary.rb` (callbacks :29-31, writer :57-98, BROADCAST_STATUSES :23) → `find_or_create_ai_job_application_summary_status.rb` (:1-47) → `ai_job_criteria.rb` (:17, :21-29) → `validate_ai_summary_generation.rb` (:6-81) → `job_application.rb` (:31 latest assoc, :160-162 status helper) → `db/schema.rb:156` (requested_by column).

## Verdicts

All map statements about S-E AGREE with current code. Every claim verified line-by-line.

- **L200** (AI_SUMMARY_COMPLETE broadcast, requesting user from waiting summary): AGREE — `textract_result.rb:128-131` passes `requesting_organization_user_id: ai_summary_waiting_on_textract.requested_by_organization_user_id`; job broadcasts at `generate_ai_job_application_summary_job.rb:34` → `:50-76` action `AI_SUMMARY_COMPLETE`. Column exists `db/schema.rb:156`.
- **L201** (textract_processing → extracting via `.update`, not update_columns): AGREE — `generate.rb:31-32`, `:32` `existing_ai_summary.update(status: :extracting)`.
- **L202** (waiting-summary selection `where(status: :textract_processing, stale: false).first`, unordered): AGREE — `textract_result.rb:121-123`.
- **L203** (entry guards :115/:116/:119): AGREE — `textract_result.rb:115` `return unless textract_job_result_text.present?`, `:116` `return unless saved_change_to_textract_job_result_text?`, `:119` `return unless organization`.
- **L204** (set_initial_summary_pending guards + update_columns): AGREE — `textract_result.rb:101` `return unless status_record && latest_summary`, `:102` `return unless status_record.status_none? || status_record.status_initial_summary_pending?`, `:104-107` `update_columns`.
- **L205** (BROADCAST_STATUSES omits awaiting_job_criteria + retrying; orchestrate.rb:72 transition emits no broadcast): AGREE — `ai_job_application_summary.rb:23` list; `orchestrate.rb:72` `update(status: :awaiting_job_criteria)`; `broadcast_status_change` gated on `BROADCAST_STATUSES.include?(status)` (`:102`).
- **L206** (re-runs ValidateAiSummaryGeneration :126; on fail destroys waiting summary + AI_SUMMARY_FAILED :132-135; on success advances extracting→…→succeeded terminal at integrate_analysis.rb:49-53, or rests at awaiting_job_criteria orchestrate.rb:72/80-81): AGREE — verified `textract_result.rb:126-135`, `integrate_analysis.rb:49-53`, `orchestrate.rb:72,80-81`.
- **L207** (succeeded terminal write is `.update` callback-firing, integrate_analysis.rb:53): AGREE — `:49-52` build params with `status: :succeeded`, `:53` `@ai_job_application_summary.update(update_params)`.
- **L208** (status row → 'current' via update_summary_status_record, after_commit on:update, guarded saved_change_to_status? && status_succeeded?): AGREE — `ai_job_application_summary.rb:30,69,74-80`.
- **L209** (succeeded .update ALSO fires destroy_previous_textract_results, guards :48/:49, destroy_all older non-succeeded :51-54): AGREE — `ai_job_application_summary.rb:29,47-55`.
- **L210** (succeeded write ALSO broadcasts JobChannel ai_summary_succeeded :93-97): AGREE — `ai_job_application_summary.rb:93-97`.
- **L211** (desync at awaiting_job_criteria rest: row stays initial_summary_pending because writer only fires on status_succeeded?): AGREE — `ai_job_application_summary.rb:69`; row set at `textract_result.rb:104-107`.
- **L212** (resuming actor for awaiting_job_criteria: AiJobCriteria#resume_waiting_summaries re-enqueues on criteria succeeded; orchestrate.rb:80 only kicks off): AGREE — `ai_job_criteria.rb:17,22-28`; `orchestrate.rb:80` `extract_job_criteria`.
- **L213** (retry/exhaustion: generate.rb:175 sets :retrying via update_columns; job retry_on attempts:3 :13; exhaustion :failed :19 + broadcast :20): AGREE — `generate.rb:175`, `generate_ai_job_application_summary_job.rb:13,19,20`.
- **L214** (credit flow :68 early return does NOT fire for textract_processing summary; latest resolves to it): AGREE — `textract_result.rb:67-68`; `job_application.rb:31` `latest_ai_job_application_summary` is `has_one … order(created_at: :desc)`. (Note: map calls it a "method"; it is an association. Description accurate.)
- **L215** (driving chain: generate_ai_summary_with_credit_flow → find_or_create :70 → set_initial_summary_pending :72 → generate_ai_summary→Orchestrate :74/:110-112): AGREE — `textract_result.rb:70,72,74,110-112`; job calls it at `generate_ai_job_application_summary_job.rb:32`.
- **L216** (credit charge on success: :82 passes, :84 CreateAiCreditBalanceTransaction, :87-88 Notify): AGREE — `textract_result.rb:82,84,87,88`.

## Omissions

1. **The pipeline-advancing record is re-selected by Orchestrate's ORDERED `.first`, not the bridge's unordered selection.** The bridge selects the waiting summary via `textract_result.rb:121-123` (`where(status: :textract_processing, stale: false).first`, NO order) only to read `requested_by_organization_user_id` and decide the branch. The job receives `textract_result_id` only (`:129`), never the summary id. `Orchestrate#call` then independently re-selects `@job_application.ai_job_application_summaries.order(created_at: :desc).first` (`orchestrate.rb:15`) — ALL summaries, any status, ordered desc. `Summary::Generate` does the same (`generate.rb:30`). If multiple summaries exist and the latest-by-created_at is NOT the bridge-selected `textract_processing` one, the record advanced differs from the record whose user drove the broadcast. The map (L202) flags the unordered `.first` as "load-bearing" and (L214) asserts latest resolves to the waiting summary, but it does not name that the actual advancing selector is a SEPARATE ordered query in Orchestrate/Generate, nor the divergence window. This is the load-bearing record-identity link for the whole slice.

2. **The X3 resume path (L212) re-enqueues WITHOUT `requesting_organization_user_id`.** `ai_job_criteria.rb:25-27` calls `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: ...)` with no requesting user. So an S-E summary that rested at `awaiting_job_criteria` and is resumed by criteria completion produces NO `AI_SUMMARY_COMPLETE` toast on its eventual success (`generate_ai_job_application_summary_job.rb:34` only broadcasts `if requesting_organization_user_id`). The user who triggered the handoff (whose id WAS preserved into the first enqueue at `textract_result.rb:130`) silently loses the completion toast across the criteria-wait boundary. The S-E section names the resuming actor but not this user/broadcast drop.

## clean
false (all verdicts AGREE, but two omissions).
