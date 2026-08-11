# S-C pass-3 adversarial review — Auto-generate via TextractResult callback

Slice: TextractResult `after_commit :queue_ai_summary_job`, ELSE (no-waiting-summary) branch — auto-generation gated on `should_auto_generate_ai_summaries?`. Trace setting check → terminal.

## Chain traced (files opened, identifiers read)
- `app/models/textract_result.rb:7` `after_commit :queue_ai_summary_job, on: [:create, :update]`
- `textract_result.rb:114-144` `queue_ai_summary_job` — read both branches
  - guards `:115` `return unless textract_job_result_text.present?`, `:116` `return unless saved_change_to_textract_job_result_text?`, `:119` `return unless organization`
  - waiting-summary lookup `:121-123` `job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).first`
  - ELSE branch `:137-143`: `:138` `return unless job_application&.job&.should_auto_generate_ai_summaries?`; `:140` `ValidateAiSummaryGeneration.call(...)`; `:142` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id) if result.success?`
- setting: `app/models/job.rb:914-922` `should_auto_generate_ai_summaries?` → enum `auto_generate_ai_summaries {default:0,enabled:1,disabled:2} _prefix:true` (`job.rb:159-163`); default branch reads `organization.auto_generate_ai_summaries_enabled` (`job.rb:920`) → `app/models/organization.rb:965-966` `settings&.dig('auto_generate_ai_summaries_enabled')`; job-level column `auto_generate_ai_summaries int default 0` (`db/schema.rb:906`)
- `app/jobs/generate_ai_job_application_summary_job.rb:24-33` `perform` → `:31` `textract_result.generate_ai_summary_with_credit_flow`; `:33` `broadcast_completion ... if requesting_organization_user_id` (nil on auto path → skipped)
- `textract_result.rb:61-89` `generate_ai_summary_with_credit_flow`
  - `:67` `latest_ai_summary = job_application.latest_ai_job_application_summary` (`job_application.rb:31` has_one ordered desc, JobApplication-scoped)
  - `:68` `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?` — nil on no-pre-existing path, does not fire
  - `:70` `find_or_create_ai_job_application_summary_status` → `FindOrCreateAiJobApplicationSummaryStatus` (`job_application.rb:160-162`); on existing `none` row this is a no-op (`find_or_create_ai_job_application_summary_status.rb:11,14` false)
  - `:72` `set_initial_summary_pending` guarded `:101 return unless status_record && latest_summary` — latest_summary nil → returns
  - `:74` `generate_ai_summary` → `:110-112` `Orchestrate.new(textract_result_id: id).call`
  - `:77` `ai_job_application_summary = ai_job_application_summaries.order(created_at: :desc).first` — bare = `self.ai_job_application_summaries` (TextractResult's own has_many, `textract_result.rb:5`), empty on freshly-succeeded result with no summary → nil
  - `:82` `return unless ai_job_application_summary&.status_succeeded?` → returns; `:84` `CreateAiCreditBalanceTransaction` never reached
- `app/services/ai_job_application_action/orchestrate.rb:9-50` `call`
  - `:15` `@ai_job_application_summary = @job_application.ai_job_application_summaries.order(created_at: :desc).first`
  - `:16` `return unless @ai_job_application_summary` — nil on no-pre-existing path → returns before `case`
  - `run_summary` (`:63-66`) → `:64` `Summary::Generate.new(...).generate` — the only first-summary creator (`generate.rb:35` `AiJobApplicationSummary.create(...)`), reachable on this pipeline ONLY via `orchestrate.rb:64` (verified by grep: other caller is `ai_relevance_benchmark.rb:24`, off-path)

## Verdicts on candidate-map S-C statements

All four explicit S-C statements (map lines 107, 108, 109) + the RECONCILIATION (160-161) AGREE with current code.

1. Map :107 "Else-branch validation failure is a SILENT no-op ... enqueue guarded only by `if result.success?` with no else (`textract_result.rb:140-143`). destroy+broadcast only in the `if` branch." — AGREE. `textract_result.rb:142` `... if result.success?` with no else; destroy+broadcast at `:132-135` is inside the `if ai_summary_waiting_on_textract` branch.
2. Map :108 "Else enqueues `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)` with NO `requesting_organization_user_id` (`textract_result.rb:142`); auto path never toasts." — AGREE. `:142` passes only `textract_result_id:`; job `:33` `broadcast_completion ... if requesting_organization_user_id` skipped when nil.
3. Map :109 / RECONCILIATION :160 "No pre-existing summary → `Orchestrate#call` returns at `orchestrate.rb:16` before `run_summary`/`Summary::Generate`; `generate_ai_summary_with_credit_flow` returns at `textract_result.rb:82`; NO-OP dead end: no summary, no credit, no broadcast." — AGREE. `orchestrate.rb:16` `return unless @ai_job_application_summary`; `Summary::Generate` reachable only via `orchestrate.rb:64`; credit-flow `:82` returns; `:84` credit-consumption never reached.
4. Map :138 (Trigger C chain) "Else branch enqueues only if `should_auto_generate_ai_summaries?`" / setting cascade. — AGREE. `textract_result.rb:138`; `job.rb:914-922` cascade verified to org settings dig.

## Omissions
None of substance for S-C. (The `:68` early-return non-firing on the no-pre-existing path is implied by the RECONCILIATION's "no pre-existing summary" framing; the textract-ready precondition `:115` is documented in Part 1.)

## clean = true
