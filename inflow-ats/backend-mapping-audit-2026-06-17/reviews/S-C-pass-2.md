# S-C Pass 2 — Adversarial Review of backend-flow-map-2026-06-17.md

**Slice:** S-C — Auto-generate via TextractResult `after_commit :queue_ai_summary_job`, else (auto) branch.
**Method:** Re-read all relevant code from scratch; attempted to refute each map statement against literal code.
**Verdict summary:** Every S-C statement AGREES with current code. No omissions found. clean = true.

## Files traced
- `app/models/textract_result.rb:7` (callback reg) → `:114-144` (`queue_ai_summary_job`) → else branch `:137-143`
- `:138` `should_auto_generate_ai_summaries?` → `app/models/job.rb:914-922` → enum `job.rb:159-163` → `app/models/organization.rb:965-967`
- `:140` `ValidateAiSummaryGeneration.call` → `app/interactors/validate_ai_summary_generation.rb:1-84`
- `:142` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id:)` → `app/jobs/generate_ai_job_application_summary_job.rb:24,32,34,50-77`
- `:32` job → `textract_result.rb:61-89` (`generate_ai_summary_with_credit_flow`) → `:74` `generate_ai_summary` → `:110-112` → `app/services/ai_job_application_action/orchestrate.rb:9-50` (`:15-16` return) → `:64` `run_summary` → `app/services/ai_job_application_action/summary/generate.rb:30-40` (sole first-summary creator at `:35`)
- Creation-site census: `create_ai_summary_generation.rb:47,60`, `create_bulk_ai_summary_generation.rb:50`, `summary/generate.rb:35` (only 4 sites; only `:35` reachable from auto path, and only past Orchestrate `:16`)
- `latest_ai_job_application_summary` → `app/models/job_application.rb:31`

## Verdicts (AGREE)

1. **Else branch is the auto path, taken when no non-stale textract_processing summary exists.** AGREE. `textract_result.rb:121-123` selects `.where(status: :textract_processing, stale: false).first`; nil → `else` at `:137`.

2. **Else branch gated solely on `should_auto_generate_ai_summaries?` (`:138`).** AGREE. `return unless job_application&.job&.should_auto_generate_ai_summaries?` (`textract_result.rb:138`). Setting cascade verified: `job.rb:915` `auto_generate_ai_summaries_enabled?` → true; `:917` `..._disabled?` → false; else `organization.auto_generate_ai_summaries_enabled` (`org.rb:965-966`, `settings&.dig('auto_generate_ai_summaries_enabled')`, seeded false at `org.rb:1274`). Enum `{default:0, enabled:1, disabled:2} _prefix:true` (`job.rb:159-163`).

3. **Else branch enqueues with NO `requesting_organization_user_id`; never toasts.** AGREE. `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)` (`textract_result.rb:142`); job default `requesting_organization_user_id: nil` (`generate_ai_job_application_summary_job.rb:24`); `broadcast_completion(...) if requesting_organization_user_id` (`:34`) → never fires.

4. **Enqueue guarded only by `if result.success?` with NO else; validation failure is a silent no-op (no destroy, no AI_SUMMARY_FAILED).** AGREE. `GenerateAiJobApplicationSummaryJob.perform_later(...) if result.success?` (`textract_result.rb:142`). The destroy + broadcast path (`:132-136`) lives only inside the `if ai_summary_waiting_on_textract` branch's inner else.

5. **No-pre-existing-summary path is a NO-OP dead end (no summary, no credit, no broadcast).** AGREE.
   - `generate_ai_summary_with_credit_flow`: `latest_ai_summary` nil (`textract_result.rb:67`); guard `:68` not triggered (nil); `find_or_create...` `:70`; `set_initial_summary_pending` returns (`latest_summary` nil, `:101`); `generate_ai_summary` `:74`.
   - `Orchestrate#call`: `@ai_job_application_summary = ...order(created_at: :desc).first` nil (`orchestrate.rb:15`); `return unless @ai_job_application_summary` (`:16`) → returns BEFORE `run_summary`/`Summary::Generate`.
   - `Summary::Generate` (`generate.rb:35`) is the ONLY first-summary creator reachable on the auto path, and it is gated behind Orchestrate `:16`. Confirmed by census: the other three creation sites (`create_ai_summary_generation.rb:47,60`; `create_bulk_ai_summary_generation.rb:50`) are manual/bulk only.
   - Back in credit flow: `ai_job_application_summary = ai_job_application_summaries.order(...).first` (TextractResult's own association, `:77`) → nil on fresh path; `return unless ...status_succeeded?` (`:82`) → returns. No credit.

6. **RECONCILIATION (S-C vs S-D): two reachable states of the same `:16`/`:82` code.** AGREE. S-C (no summary) returns at `orchestrate.rb:16` then `textract_result.rb:82`. (S-D is out of this slice but the reconciliation's S-C half is correct.)

7. **Part 7 row C: "1 on success — but NO-OP if no summary pre-exists."** AGREE. When a non-textract_processing summary DOES pre-exist (e.g. `pending`/`scoring`/etc.), the else branch is still taken (selector only matches non-stale textract_processing) and Orchestrate `:15` picks it up and can advance it to `succeeded`, charging 1 credit at `:84`. The "NO-OP if no summary pre-exists" qualifier is exactly correct.

8. **Part 3 bridge guards: `textract_job_result_text.present?`, `saved_change_to_textract_job_result_text?`, organization present.** AGREE. `textract_result.rb:115,116,118-119`.

9. **Feature-gate table: `should_auto_generate_ai_summaries?` checked at "TextractResult callback else branch only (`textract_result.rb:138`)."** AGREE — exact line and sole call site.

## Omissions
None. The S-C behavior is fully covered: branch selection, setting cascade, no-requesting-user enqueue, silent-no-op-on-validation-failure, the no-op dead end, and the conditional credit-on-success are all present and accurately anchored.

(Minor note, not an omission: the silent no-op at `:142` can be caused by the NEW `has_job_description?` guard at `validate_ai_summary_generation.rb:29` failing on the auto path; the map's general "validation failure is a silent no-op" statement already covers this, and the new guard is documented separately in the changelog/feature-gate table.)

## Record-write sites on the S-C path
- `generate_ai_job_application_summary_job.rb:19` `ai_summary&.update_columns(status: :failed, error_message:)` — AiJobApplicationSummary.status — update_columns — (retry exhaustion; only when a summary exists)
- `generate_ai_job_application_summary_job.rb:44` `ai_summary&.update_columns(status: :failed, error_message:)` — AiJobApplicationSummary.status — update_columns — (StandardError rescue; only when a summary exists)
- `textract_result.rb:104-107` set_initial_summary_pending `status_record.update_columns(ai_job_application_summary_id:, status: 'initial_summary_pending')` — AiJobApplicationSummaryStatus — update_columns — (only when a latest_summary exists; skipped on the no-summary auto path)
- On the pure no-pre-existing-summary auto path: ZERO record writes (the defining dead-end property).

clean = true
