# S-C Adversarial Review — Pass 5

**Slice:** S-C — Auto-generate via `TextractResult after_commit :queue_ai_summary_job`, firing the else (auto-generate) branch when there is NO `textract_processing`+`stale:false` waiting summary and `should_auto_generate_ai_summaries?` is on. Trace the setting check and path to terminal.

**Candidate map:** `backend-flow-map-2026-06-17.md` (Trigger C / S-C section lines 140-149; RECONCILIATION lines 218-223; Auto-Generate Settings line 489-490; bridge else-branch line 540; setting gate line 639).

**Method:** Re-read from scratch. Files opened and traced:
`textract_result.rb:7,61-144` → `find_or_create_ai_job_application_summary_status.rb:1-47` → `job.rb:159-163,914-922` → `organization.rb:965-967` → `validate_ai_summary_generation.rb:1-84` → `orchestrate.rb:1-107` → `summary/generate.rb:1-70` (+ grep `textract_result` references) → `generate_ai_job_application_summary_job.rb:1-78` → grep callers of `Summary::Generate` and `should_auto_generate_ai_summaries?`.

---

## Verdicts

### AGREE — `after_commit :queue_ai_summary_job, on: [:create, :update]`
`textract_result.rb:7` literal: `after_commit :queue_ai_summary_job, on: [:create, :update]`. Map lines 377, 10 — AGREE.

### AGREE — Entry guards before the branch selector
`:115` `return unless textract_job_result_text.present?`; `:116` `return unless saved_change_to_textract_job_result_text?`; `:118-119` `organization = job_application&.job&.organization` / `return unless organization`. Map lines 166, 538 — AGREE.

### AGREE — Branch selector / else condition
`:121-123` `ai_summary_waiting_on_textract = job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).first` — JobApplication-scoped, no `textract_result_id` filter, no explicit order. `:125` `if ai_summary_waiting_on_textract` / `:137` `else`. Map lines 538, 153, 540 — AGREE.

### AGREE — Setting check `should_auto_generate_ai_summaries?` at `:138`, sole caller
`:138` `return unless job_application&.job&.should_auto_generate_ai_summaries?`. grep confirms `textract_result.rb:138` is the ONLY caller in `app/`+`lib/`. `job.rb:914-922`: `auto_generate_ai_summaries_enabled?` → true; `_disabled?` → false; else → `organization.auto_generate_ai_summaries_enabled` (`org.rb:965-967` `settings&.dig('auto_generate_ai_summaries_enabled')`). Enum `job.rb:159-163` `{default:0,enabled:1,disabled:2} _prefix:true`. Map lines 489-490, 639 — AGREE.

### AGREE — Else-branch re-validation + enqueue with NO requesting user
`:140` `result = ValidateAiSummaryGeneration.call(job_application:, organization:)`; `:142` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id) if result.success?` — no `requesting_organization_user_id`. Map lines 142, 540 — AGREE.

### AGREE — Else-branch validation failure is a SILENT no-op
`:142` is guarded by `if result.success?` with NO `else`. The destroy+`AI_SUMMARY_FAILED` broadcast (`:132-135`) exists ONLY in the IF (waiting-summary) branch. Map line 141 — AGREE.

### AGREE — Auto path never toasts the user
`generate_ai_job_application_summary_job.rb:24` `requesting_organization_user_id: nil` default; `:34` `broadcast_completion(...) if requesting_organization_user_id` → nil short-circuits. Map line 142 — AGREE.

### AGREE — Job-entry early-exit guard at `:68`
`textract_result.rb:67` `latest_ai_summary = job_application.latest_ai_job_application_summary` (`job_application.rb:31` `order(created_at: :desc)`); `:68` `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`. Map line 148 cites `:67-68` — AGREE (the literal `return if` is on `:68`; map's range `:67-68` covers the read + return).

### AGREE — Job-entry status-row sequence (find_or_create then set_initial_summary_pending) BEFORE Orchestrate
`:70` `status_result = job_application.find_or_create_ai_job_application_summary_status`; `:72` `set_initial_summary_pending(status_result) if status_result.success?`; `:74` `generate_ai_summary` (`:111` `Orchestrate.new(...).call`). Map line 149 — AGREE.
Terminal #1 no-op of both: `find_or_create` — row exists (`:11`), `summary` nil (`:12`), `:14` `summary&.status_succeeded?` false → no write. `set_initial_summary_pending` `:100` `latest_summary` nil → `:101` `return unless status_record && latest_summary`. AGREE.

### AGREE — Terminal #1: no pre-existing summary → NO-OP dead end
`orchestrate.rb:15` `@ai_job_application_summary = @job_application.ai_job_application_summaries.order(created_at: :desc).first`; `:16` `return unless @ai_job_application_summary` returns BEFORE any `run_summary`/`Summary::Generate` (`:64`). Back in `generate_ai_summary_with_credit_flow`, `:77` `ai_job_application_summaries.order(...).first` (`self.` = THIS TextractResult-scoped) is empty on the new result → `:82` `return unless ai_job_application_summary&.status_succeeded?` returns. No summary, no credit (`:84` `CreateAiCreditBalanceTransaction` not reached), no broadcast. Map lines 144, 220, RECONCILIATION — AGREE.

### AGREE — `Summary::Generate` is the sole first-summary creator and (in the pipeline) reached only from `run_summary`
`generate.rb:35-39` `AiJobApplicationSummary.create(... status: :extracting)` is the only summary-create in the pipeline. grep: `.generate` is invoked from `orchestrate.rb:64` only in `app/`; other refs are `ai_relevance_benchmark.rb` and two rake tasks (out of the S-C path). Map line 144/220 — AGREE.

### AGREE — Terminal #3 (stale-succeeded / S-D overlap): no-op for credit
`orchestrate.rb:15` JobApplication-scoped picks the stale-succeeded summary; `:16` passes; `:46-48` `succeeded`/`failed` → `return`. `generate_ai_summary_with_credit_flow:77` `self.ai_job_application_summaries` empty on the NEW result → `:82` returns; `:84` not reached, no credit. Map lines 146, 222 — AGREE (scope distinction `orchestrate.rb:15` JobApplication-scoped vs `textract_result.rb:77` TextractResult-scoped is real and load-bearing).

### AGREE (with stated precondition flagged below) — Terminal #2: pre-existing NON-succeeded NON-waiting summary advances
`orchestrate.rb:15` selects it; `:16` passes; `:22-25` (`pending`/`textract_processing`/`extracting`/`retrying`) → `run_summary` (`:64`) → `Summary::Generate` reuse path `:31-33` (`existing_ai_summary.update(status: :extracting)`) advances toward `succeeded`. The ADVANCE is verified. Map lines 145, 221 — AGREE on the advance.
See OMISSION #1 for the credit-charge precondition the map does not state.

---

## Omissions

### Omission #1 — Terminal #2 "charges a credit" omits the same-TextractResult association precondition for `:77`/`:82`
Map lines 145/221 state terminal #2 "advances `extracting → … → succeeded`; `textract_result.rb:84` charges a credit on success." The credit at `:84` is gated by `:82` `return unless ai_job_application_summary&.status_succeeded?`, where `ai_job_application_summary` comes from `:77` `ai_job_application_summaries.order(created_at: :desc).first` — `self.ai_job_application_summaries`, scoped to the FIRING TextractResult (`textract_result.rb:5` `has_many`). On the REUSE path, `summary/generate.rb:31-33` does NOT re-assign `textract_result` to the reused summary (`textract_result: @textract_result` is set only on the CREATE path `:37`). So the reused succeeded summary keeps its ORIGINAL `textract_result_id`. If that id differs from the firing result's id, `:77` is empty and `:82` returns — NO credit, despite the summary having reached `succeeded`. The map states "charges a credit" unconditionally for terminal #2; it should note the credit fires only when the reused summary is already associated with the firing TextractResult. (The advance to `succeeded` is unaffected; only the credit consumption carries this precondition.)

### Omission #2 — `set_initial_summary_pending` guard `:102` can BLOCK the write in terminal #2 when the row is already `current`/`regenerating`
Map line 149 says terminal #2 "writes `initial_summary_pending`." The write at `:104-107` is gated by `:102` `return unless status_record.status_none? || status_record.status_initial_summary_pending?`. If the status row is already `current` (a prior succeeded review exists) or `regenerating`, `set_initial_summary_pending` returns WITHOUT writing. The map qualifies this implicitly ("row `none`/`initial_summary_pending`") but does not state that a `current`/`regenerating` row blocks the write — which is the common state when terminal #2 arises after a prior completed review. Minor precision omission.

---

## Conclusion
Every explicit S-C statement in the candidate map is AGREE against current code. Two omissions found (both precision gaps on terminal #2 — the credit-charge association precondition and the `set_initial_summary_pending` guard-block case). Because omissions is non-empty, **clean = false**.
