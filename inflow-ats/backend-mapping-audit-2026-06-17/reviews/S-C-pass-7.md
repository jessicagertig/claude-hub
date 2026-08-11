# S-C Adversarial Review — pass-7

Slice S-C: Auto-generate via `TextractResult after_commit :queue_ai_summary_job`, else (auto) branch — fires when there is NO waiting `textract_processing`/`stale:false` summary AND `should_auto_generate_ai_summaries?` is true. Trace setting check → terminal.

Code re-read from scratch:
- `app/models/textract_result.rb` (`:7` callback, `:61-89` credit flow, `:98-108` set_initial_summary_pending, `:114-144` queue_ai_summary_job)
- `app/models/job.rb` (`:159-163` enum, `:914-922` should_auto_generate_ai_summaries?)
- `app/models/organization.rb` (`:965-967` org fallback, `:1274` seed false)
- `app/jobs/generate_ai_job_application_summary_job.rb`
- `app/services/ai_job_application_action/orchestrate.rb`
- `app/services/ai_job_application_action/summary/generate.rb` (`:30-40` reuse vs create)
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb` (`:49-53`)
- `app/models/ai_job_application_summary.rb` (`:30` callback, `:69-98` update_summary_status_record)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb`
- `app/interactors/validate_ai_summary_generation.rb` (`:24-29` fail conditions)
- `app/models/job_application.rb` (`:31` latest_ai_job_application_summary, `:160-171`)
- `app/services/get_resume_text_from_textract.rb` (`:31` firing `.update`)

## Verdicts

All S-C statements AGREE against literal code. Details:

1. Else-branch validation failure is a SILENT no-op (`textract_result.rb:140-142`, `if result.success?` with no else). AGREE.
2. Else branch enqueues `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)` with NO requesting user (`textract_result.rb:142`); `generate_ai_job_application_summary_job.rb:34` skips `broadcast_completion` when nil → no toast. AGREE.
3. Three terminals (#1 no-op no-summary; #2 advance+conditional-credit; #3 stale-succeeded no-op). AGREE — `orchestrate.rb:16` (nil return), `:46-48` (succeeded return), `textract_result.rb:77/:82/:84` (firing-result-scoped credit). Terminal #2 credit precondition: reuse path `generate.rb:31-33` does not re-assign `textract_result`; CREATE-only at `:37` — verified.
4. Terminal #2 status examples non-exhaustive; non-stale `summarizing`/`scoring`/`integrating`/`awaiting_job_criteria` also pass `orchestrate.rb:16` (case arms `:28-45`). AGREE.
5. Terminal #2 success status-row write via `update_summary_status_record` (`ai_job_application_summary.rb:30,69-80`) + `ai_summary_succeeded` broadcast (`:93-97`), driven by `integrate_analysis.rb:53` `.update(status: :succeeded)`. AGREE.
6. S-C job-entry early-exit guard `generate_ai_summary_with_credit_flow:67-68` (`return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`). AGREE.
7. S-C job-entry status-row sequence: `find_or_create` (`:70`) + `set_initial_summary_pending` (`:72`) before Orchestrate; terminal #1 both no-op (`find_or_create.rb:14` false; `textract_result.rb:101` latest_summary nil); `:102` guard blocks write when row is `current`/`regenerating`. AGREE.
8. Setting check: `should_auto_generate_ai_summaries?` (`job.rb:914-922`), per-job enum `_prefix:true` (`:159-163`), org fallback `organization.auto_generate_ai_summaries_enabled` (`org.rb:965-967`, `settings&.dig(...)`, seeded false `:1274`), sole caller `textract_result.rb:138` (map line 541). AGREE.
9. RECONCILIATION (lines 269-274): #1/#3 no-op dead ends; #2 credit-charging-conditional success. AGREE.

## Omissions

1. **Entry guards not co-located in the S-C subsection.** The S-C trigger path runs `queue_ai_summary_job` entry guards BEFORE reaching the else branch: `:115` `return unless textract_job_result_text.present?`, `:116` `return unless saved_change_to_textract_job_result_text?`, `:119` `return unless organization`. The S-C subsection (map lines 172-183) does not restate these; they are documented at line 203 (labeled under S-E) and line 589 (Part body). Soft omission — present in the document, not in the S-C subsection. The waiting-summary-vs-else branch selector `:121-123` is likewise documented under S-E (line 202) / line 589, not in the S-C subsection.

2. **`ValidateAiSummaryGeneration` side-effect on the S-C else-branch re-validation is not noted.** `textract_result.rb:140` re-runs `ValidateAiSummaryGeneration`; if `@latest_textract_result` were absent it would enqueue `SubmitResumeToTextractJob` (`validate_ai_summary_generation.rb:38-39`). On the S-C path the firing TextractResult IS the latest (it just succeeded), so `:38` does not fire and `textract_text_ready?` is true — benign — but the re-validation's full fail-condition list (`:24-29`: nil job_application/org, flipper-disabled, no-resume, credits-exhausted, missing-job-description) that silently no-ops the else branch is enumerated only under S-A/S-B, not the S-C subsection. Minor.

These are co-location omissions, not factual errors. clean=false on omission grounds.
