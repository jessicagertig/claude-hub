# S-C Pass-6 Adversarial Review — Auto-generate via TextractResult callback

**Slice:** S-C — `TextractResult after_commit :queue_ai_summary_job` else/auto branch (no waiting summary), gated on `should_auto_generate_ai_summaries?`, to terminal.

**Files re-read from scratch (chain):**
`textract_result.rb:7` (after_commit) → `textract_result.rb:114-144` (`queue_ai_summary_job`) → `:138` `should_auto_generate_ai_summaries?` → `job.rb:914-922` + enum `job.rb:159-163` + `organization.rb:965-967` → `:140` `ValidateAiSummaryGeneration` (`validate_ai_summary_generation.rb:1-84`) → `:142` `GenerateAiJobApplicationSummaryJob` (`generate_ai_job_application_summary_job.rb:11-78`) → `textract_result.rb:61-89` (`generate_ai_summary_with_credit_flow`) → `:67-68` early-exit, `:70` `find_or_create_ai_job_application_summary_status` (`find_or_create_ai_job_application_summary_status.rb:1-47`), `:72` `set_initial_summary_pending` (`textract_result.rb:98-108`), `:74`/`:110-112` `Orchestrate` (`orchestrate.rb:9-50`) → `:16`, `:64` `Summary::Generate` (`summary/generate.rb:30-40`) → terminal credit `textract_result.rb:82-88`. Supporting: `ai_job_application_summary.rb:10-21,30,57-98`; `job_application.rb:31`; `db/schema.rb` ai_job_application_summaries columns.

## Verdicts

All S-C map statements (changelog lines 160-169 + RECONCILIATION 246-251 + body 568) verified AGREE against literal code:

- L161 silent no-op on else-branch validation failure — AGREE. `textract_result.rb:140-143`: `result = ValidateAiSummaryGeneration.call(...)`; `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id) if result.success?` — no else, no destroy, no broadcast. Destroy+broadcast only in the `if` waiting-summary branch (`:132-135`).
- L162 else branch enqueues with NO requesting user → no toast — AGREE. `textract_result.rb:142` passes only `textract_result_id:`; job default `requesting_organization_user_id: nil` (`generate_ai_job_application_summary_job.rb:24`); `:34` broadcast skipped.
- L163-167 / RECONCILIATION terminals #1/#2/#3 — AGREE.
  - #1 no pre-existing summary → `orchestrate.rb:16` `return unless @ai_job_application_summary`; `textract_result.rb:82` `return unless ai_job_application_summary&.status_succeeded?` (`:77` `self.ai_job_application_summaries` empty on the firing result). No summary/credit/broadcast.
  - #2 pre-existing non-succeeded non-waiting → `orchestrate.rb:15` newest selection, `:16` passes, `:22-25` (pending/textract_processing/extracting/retrying) → `run_summary` (`:64`) → `Summary::Generate` advances. Credit conditional: `generate.rb:31-33` reuse branch `existing_ai_summary.update(status: :extracting)` does NOT re-assign `textract_result` (set only on CREATE branch `:35-39`, `textract_result: @textract_result`), so `textract_result.rb:77` (`self.ai_job_application_summaries`, firing-result-scoped via has_many `:5`) is empty when reused summary's `textract_result_id != id` → `:82` returns, no credit. AGREE.
  - #3 prior stale-succeeded → `orchestrate.rb:46-48` succeeded branch returns; `textract_result.rb:77` empty on new result → `:82` returns; no credit; status row stuck `regenerating`. AGREE.
- L168 job-entry early-exit `textract_result.rb:67-68` — AGREE. `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`; `latest_ai_job_application_summary` def `job_application.rb:31` `order(created_at: :desc)`.
- L169 status-row sequence — AGREE. `:70` find_or_create, `:72` set_initial_summary_pending. Terminal #1: find_or_create `:14` false → no write; set_initial_summary_pending `:101` `return unless status_record && latest_summary` (nil). `:102` guard `return unless status_record.status_none? || status_record.status_initial_summary_pending?` blocks write when row is current/regenerating. AGREE.
- L518 / L568 / L667 `should_auto_generate_ai_summaries?` per-job-with-org-fallback, sole caller at `textract_result.rb:138` — AGREE. `job.rb:914-922`; enum `_prefix:true` `job.rb:159-163` (methods are `auto_generate_ai_summaries_enabled?`/`_disabled?`); org fallback `organization.rb:965-967` `settings&.dig('auto_generate_ai_summaries_enabled')`.

Branch-logic checkpoint (textract-ready vs not): S-C reaches the else/auto branch only AFTER `:115` `return unless textract_job_result_text.present?` and `:116` `return unless saved_change_to_textract_job_result_text?` — i.e. the firing result already has text (textract-READY). The no-text wait branch never fires the bridge. Else branch is taken when `:121-123` waiting-summary query (`textract_processing`, `stale:false`, JobApplication-scoped) is nil. Matches map L173/L444/L566.

## Omissions (minor, non-contradicting)

1. The S-C changelog (L160-169) does not co-locate the **status-row → `current` write on terminal #2 success**. When the reused summary reaches `succeeded` via `.update` (pipeline terminal `integrate_analysis.rb:53`), `AiJobApplicationSummary after_commit :update_summary_status_record, on: :update` (`ai_job_application_summary.rb:30,69-80`) writes `status:'current'` + denormalized columns and broadcasts JobChannel `ai_summary_succeeded` (`:93-97`). The write census (L795) does attribute `ai_job_application_summary.rb:74-80` to S-C, so this is a co-location gap, not a contradiction.

2. Terminal #2's status-example list (L165 "latest summary `pending`/`retrying`/`extracting`, or a `stale:true` `textract_processing`") is non-exhaustive: a pre-existing non-stale `summarizing`/`scoring`/`integrating`/`awaiting_job_criteria` summary also passes `orchestrate.rb:16` and advances via its own `case` arm (`:28-45`). (A non-stale `textract_processing` would be routed to the `if` waiting branch / S-E, so the "non-waiting" qualifier correctly excludes it.) Illustrative omission only.

## Conclusion

No DISPUTE. Every S-C map claim is anchored on literal code and verified. Two minor omissions (co-location only; both facts are present elsewhere in the map). clean = false (omissions non-empty).
