# Adversarial Review — Slice S-A (Manual single generate) — Pass 3

**Angle:** S-A
**Verdict:** clean = true (every checked statement AGREE; no material omissions)

## Trace chain (re-traced from scratch)
`api/v1/ai_job_application_summaries_controller.rb:8,17`
→ `validate_ai_summary_generation.rb:1-84`
→ `create_ai_summary_generation.rb:1-80`
→ `generate_ai_job_application_summary_job.rb:24-46`
→ `textract_result.rb:61-89` (`generate_ai_summary_with_credit_flow`) → `:110-112` (`generate_ai_summary`)
→ `ai_job_application_action/orchestrate.rb:5-50`
supporting: `job_application.rb:31-32` (associations), `:160-162` (`find_or_create_ai_job_application_summary_status`), `:685-687` (`latest_textract_result`); `ai_job_application_summary.rb:21-31` (enum/BROADCAST_STATUSES/callbacks); `user.rb:38` (`current_organization_user` optional).

## Branch point (the slice's required file:line)
- Determinant computed in `ValidateAiSummaryGeneration`:
  - Textract ready: `textract_text_ready?` true → `context.textract_pending = false` (`validate_ai_summary_generation.rb:44-45`).
  - Textract absent: `unless @latest_textract_result` → `SubmitResumeToTextractJob.perform_later` + `context.textract_pending = true` + bare `return` (`:38-42`).
  - in_progress/not_started → `context.textract_pending = true` (`:58-59`).
- Actual fork that creates summary + enqueues-or-not is `create_ai_summary_generation.rb:46` (`if validation_result.textract_pending`):
  - (i) ready (false) → `:pending` summary (`:60-64`), on `save` (`:70`) enqueue `GenerateAiJobApplicationSummaryJob(textract_result_id, requesting_organization_user_id)` (`:71-74`).
  - (ii) pending (true) → `:textract_processing` summary, NO job, bare `return` (`:46-58`).

## Per-claim verdicts — all AGREE
- Validate fail-fast guard `has_job_description?` (`:29`, def `:81-83`, exact error string) — AGREE.
- `context.textract_result` assigned unconditionally (`:31-32`), nil on no-textract path — AGREE.
- No-textract branch `:38-42` (line shift from old map's :37-41) — AGREE.
- Validate invoked WITHOUT `user:` (controller `:8-11`); user only to Create (`:17-21`); `context.user` nil in Validate but unread — AGREE.
- Create active-summary lookup `.where.not(status: :failed).where(stale: false)...first` (`:30-34`); stale-on-mismatch (`:36-38`); reuse-existing (`:41-44`) — AGREE.
- textract_processing arm build (`:47-51`), user via `context.user&.current_organization_user&.id` (`:50`), `return` `:57` — AGREE.
- pending arm build (`:60-64`), enqueue on save `:70`, user via `context.user.current_organization_user.id` (`:73`, NO safe-nav; asymmetry vs `:50`/`:63` real — `current_organization_user` is `optional: true`, `user.rb:38`) — AGREE.
- Job calls `generate_ai_summary_with_credit_flow` (`:32`); `broadcast_completion ... if requesting_organization_user_id` (`:34`); `failed`-only writer at `:19` and `:44`, never `:retrying` — AGREE.
- `generate_ai_summary_with_credit_flow`: `:68` succeeded&&!stale early return; `:70-72` find_or_create + set_initial_summary_pending; `:74` generate; `:77` TextractResult-scoped fetch; `:82` return unless succeeded; `:84` credit — AGREE.
- `generate_ai_summary` → `Orchestrate.new(textract_result_id: id).call` (`:110-112`) — AGREE.
- Orchestrate `:6` find_by, `:12` return unless, `:15` JobApplication-scoped no-stale-filter, `:16` return unless, dispatch `:21-49` (succeeded/failed → return `:46-48`) — AGREE.
- `create_status_record` callback REMOVED; `set_initial_summary_pending` runs on the job run, not the validate path (`textract_result.rb:70-72`); summary callbacks `:29-31`; BROADCAST_STATUSES `:23` omits awaiting_job_criteria + retrying — AGREE.

## Omissions
None material to S-A. (The `current_organization_user.id` NoMethodError-if-nil note at `:73` is present in the map's Part 2 detail and is code-accurate; not an omission.)

## Conclusion
clean = true.
