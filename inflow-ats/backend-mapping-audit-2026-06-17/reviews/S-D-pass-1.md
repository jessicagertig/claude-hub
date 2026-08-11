# S-D — Resume-replacement re-generation — Audit Pass 1

**Angle:** S-D
**Scope:** A prior summary already exists for the job_application and a new resume/Textract result arrives. Which AiJobApplicationSummary record each step operates on, every status it passes through, where it comes to rest.

## Files traced (chains)

Auto-regen path:
`job_applications_controller.rb:107-116` (resume replace) → `SubmitResumeToTextractJob` → `submit_resume_to_textract.rb:18-27` → `textract_result.rb:114-144 queue_ai_summary_job` → `job.rb:914 should_auto_generate_ai_summaries?` → `GenerateAiJobApplicationSummaryJob:24-34` → `textract_result.rb:61-89 generate_ai_summary_with_credit_flow` → `find_or_create_ai_job_application_summary_status.rb:11-21` → `orchestrate.rb:15,46-48` (→ never reaches `summary/generate.rb`) → `create_ai_credit_balance_transaction.rb`

Manual-regen variant:
`ai_job_application_summaries_controller.rb:4-28` → `validate_ai_summary_generation.rb:31-60` → `create_ai_summary_generation.rb:30-77` → `GenerateAiJobApplicationSummaryJob` → `orchestrate.rb:15,22-27` → `summary/generate.rb:30-40`

Models read: `ai_job_application_summary.rb`, `ai_job_application_summary_status.rb`, `ai_job_criteria.rb`, `job_application.rb:31,160,685`

---

## The two S-D sub-paths

### Path 1 — AUTO regen on resume replacement (Trigger D, auto-generate ON)

1. **Resume replaced** via `PATCH /api/v1/job_applications/:id` — `job_applications_controller.rb:110-115`: on `temp_params.key?(:resume) && present?`, enqueues `DocxToPdfJob` and (if `TEXTRACT_RESUME_PROCESSING`) `SubmitResumeToTextractJob`. **This action does NOT call `CreateAiSummaryGeneration`** — no new summary row is created here.
2. **`submit_resume_to_textract.rb:18-20`**: `unless ...where(status: :textract_processing, stale: false).exists?` → for a prior *succeeded* summary none exists → `ai_job_application_summaries.update_all(stale: true)` marks the OLD succeeded summary `stale: true`.
3. **`:22`** builds new TextractResult `in_progress`. **`:25-26`** finds `textract_processing, stale:false, textract_result_id:nil` → none → no `update_columns`.
4. Textract poll completes (out of slice) → `update` on TextractResult writes `textract_job_result_text` → `after_commit :queue_ai_summary_job` (`textract_result.rb:7,114`).
5. **`textract_result.rb:121-123`**: `where(status: :textract_processing, stale: false).first` → none (old summary is `succeeded`+`stale`) → **else branch `:137`**.
6. **`:138`** `return unless ...should_auto_generate_ai_summaries?`. If ON → `:140` validate → `:142` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: <NEW>)` — **no `requesting_organization_user_id`**.
7. Job `:32` → `generate_ai_summary_with_credit_flow`.
   - **`:67-68`** `latest_ai_summary` = OLD stale-succeeded; `status_succeeded?(true) && !stale?(false)` → `false` → **NOT early-returned**.
   - **`:70`** `find_or_create_ai_job_application_summary_status` → status row exists, its summary `status_succeeded?` → **`:15` sets status row `regenerating`** + broadcasts `ai_summary_status_change`.
   - **`:72`** `set_initial_summary_pending` → row is now `regenerating`, `:102` guard returns (no-op).
   - **`:74`** `generate_ai_summary` → `Orchestrate.new(textract_result_id: <NEW>).call`.
8. **`orchestrate.rb:15`** `ai_job_application_summaries.order(created_at: :desc).first` — **does NOT filter `stale`** → selects OLD stale-succeeded. **`:46-48`** `status_succeeded?` → `return`. **`run_summary` / `summary/generate.rb` never called. NO new summary created.**
9. Back in `generate_ai_summary_with_credit_flow` **`:77`** latest = still OLD stale-succeeded; **`:82`** `status_succeeded?` → true → NOT returned; **`:84`** `CreateAiCreditBalanceTransaction.call(summary: <OLD stale-succeeded>)` — **charges 1 credit for the OLD summary**. No idempotency guard in `create_ai_credit_balance_transaction.rb` ties the charge to staleness.

**Terminal state:** Old stale-succeeded summary unchanged. Status row left at `regenerating` (the `update_summary_status_record` callback that resets it to `current` fires only on a summary `:update`→`succeeded`, which never happens because no new summary runs). **Dead end: status row stuck `regenerating`, a credit consumed, no new summary.** This is the same Gap-8 behavior the map flags — the new `:67-68` guard does NOT close it for the stale-succeeded case (it only short-circuits the succeeded-AND-fresh "nothing to do" case).

### Path 2 — MANUAL regen on resume replacement (Trigger A), Textract for new resume already ready

1. User clicks Generate → `ai_job_application_summaries_controller.rb:8` `ValidateAiSummaryGeneration`. `:44` `textract_text_ready?` true → `:45` `textract_pending=false`.
2. `CreateAiSummaryGeneration.rb:30-34` `active_ai_summary` = newest non-failed `where(stale: false)`. Old summary was marked `stale:true` by step 2 of Path 1's resume replacement, so it is **excluded** → `active_ai_summary = nil`.
3. `:36-39` skipped (active is nil). `:60-74` builds **NEW `pending` summary**, saves, enqueues `GenerateAiJobApplicationSummaryJob(textract_result_id:<NEW>, requesting_organization_user_id:)`.
4. Orchestrate `:15` latest = NEW `pending` → `:22 status_pending?` → `run_summary` → `summary/generate.rb:30-40` reuses the pending row (`:32` → `extracting`) and runs the real 4-call pipeline. **Works: new summary generated.**

So S-D diverges by trigger: **MANUAL regen produces a fresh summary; AUTO regen no-ops and burns a credit.**

---

## Claim-by-claim verdicts

(see structured output)

## Record-write sites on this slice

(see structured output write_sites)
