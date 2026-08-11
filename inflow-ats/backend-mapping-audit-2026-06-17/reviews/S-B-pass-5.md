# S-B (Bulk generate) — Adversarial review, pass 5

Re-audited from scratch against current code. Files read:
- `app/interactors/queue_bulk_ai_summary_jobs.rb`
- `app/jobs/bulk_generate_ai_summaries_job.rb`
- `app/interactors/create_bulk_ai_summary_generation.rb`
- `app/models/textract_result.rb` (generate_ai_summary_with_credit_flow, set_initial_summary_pending)
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb`
- `app/controllers/concerns/role_fit_filterable.rb`
- `app/interactors/validate_ai_summary_generation.rb`
- `app/models/bulk_ai_summary_job_application.rb`
- `app/models/ai_job_application_summary.rb` (update_summary_status_record)
- `app/models/job_application.rb` (scopes, associations)
- `db/schema.rb` (partial unique index)

## Verdicts

All map statements for S-B (changelog lines 103-125) verified AGREE against literal code, EXCEPT one imprecision (DISPUTE) on CreateBulkAiSummaryGeneration reuse scope.

### AGREE (representative anchors)
- Controller server-side ID resolution `:32-46`; RoleFitFilterable `:10`/`:15`. CONFIRMED.
- `with_textract_results` bare `joins(:textract_results)` at `job_application.rb:115`; no text check. CONFIRMED.
- `:current` status candidates dropped from ready_ids+input_ids `queue_bulk_ai_summary_jobs.rb:36-40`. CONFIRMED.
- Empty-working-set early return `:49-54`. CONFIRMED.
- Payload hash enqueue `:82-89`; counts `:91-93`. CONFIRMED.
- `BulkAiSummaryJobApplication` enum `{processing:0,done:1,failed:2,deferred:3}` _prefix `bulk_ai_summary_job_application.rb:10`. CONFIRMED.
- Bulk routes through `CreateBulkAiSummaryGeneration` before credit flow `bulk_generate_ai_summaries_job.rb:74-80`. CONFIRMED.
- Idempotency guard `:48-56`, `update_columns(status: :done)` `:54`. CONFIRMED.
- `on_complete` folds deferred into skipped; failed by subtraction `:111`; skipped `:124`; mailer `.deliver_later` `:144/:171`. CONFIRMED.
- counting floor `:104`, `created_at >= floor_at` `:108`. CONFIRMED.
- normal-path notify_failure terminal `:113-114`, no update_remaining_statuses_to_failed. CONFIRMED.
- each_iteration guard order `:48-56 → :60 → :65-67 → :74 → :80 → :86`. CONFIRMED.
- validation-failure dead end leaves row `:processing` (`:60` returns; update_remaining only from discard/retry `:12-16`/`:17-21`). CONFIRMED.
- each_iteration rescue dead end `:89-92`. CONFIRMED.
- whole-batch failure `discard_on` `:12-16`, update_remaining `:178-180`. CONFIRMED.
- pending_textract counting `:23`, backfill `:28-30`, no idempotency guard. CONFIRMED.
- claim-race pre-filter `:43-47`, RecordNotUnique rescue `:70-75`, re-query `:78-80`. CONFIRMED. Partial unique index `db/schema.rb:288` `unique where (status=0)`.
- credit-flow `:68` early return text matches exactly. CONFIRMED.

### DISPUTE
**Map line 125** — "CreateBulkAiSummaryGeneration reuses an existing succeeded-non-stale active summary (`create_bulk_ai_summary_generation.rb:45-48`)".
The reuse query at `create_bulk_ai_summary_generation.rb:34-38` is
`.where.not(status: :failed).where(stale: false).order(created_at: :desc).first` — it reuses ANY non-failed, non-stale summary (pending, extracting, summarizing, scoring, integrating, succeeded), NOT specifically a succeeded one. The reuse block `:45-48` returns that record regardless of whether it is succeeded.
The downstream `:68` early-return claim is still correct (it fires only when the latest summary is succeeded-non-stale), but the characterization of the reuse itself as "succeeded-non-stale" understates the query. When reuse returns a non-succeeded active summary, the `:68` early return does NOT fire and generation proceeds on the reused row.
Correction: "CreateBulkAiSummaryGeneration reuses the latest non-failed, non-stale summary of ANY status (`:34-38`, `:45-48`). The credit-flow `:68` early return then fires only when that reused (or otherwise latest) summary is `status_succeeded?` and not stale."

## Omissions

1. **Terminal status-row write to `current` on bulk success is not stated.** The S-B section traces the status row being READ (`:current` drop at `queue_bulk_ai_summary_jobs.rb:36-40`) and references `set_initial_summary_pending`, but never states that a successfully-generated bulk candidate's `AiJobApplicationSummaryStatus` row terminates at `status: 'current'` via `AiJobApplicationSummary` `after_commit :update_summary_status_record, on: :update` (`ai_job_application_summary.rb:30`), writing `status: 'current'`, `ai_job_application_summary_id`, `score_percentage`, `headline`, `integrated_role_analysis` via `.update` at `ai_job_application_summary.rb:74-80`, guarded by `saved_change_to_status? && status_succeeded?` (`:69`). This is THE terminal status-row write for the happy bulk path and the prompt requires every status-row write be reported.

2. **`set_initial_summary_pending` status-row write during bulk not stated as a write.** Map line 125 says set_initial_summary_pending "succeeds for bulk" but does not state it WRITES the status row to `status: 'initial_summary_pending'` + `ai_job_application_summary_id` via `update_columns` (`textract_result.rb:104-107`), reached from the bulk credit flow at `textract_result.rb:72`. Only fires when the row is `none`/`initial_summary_pending` (`:102`).

3. **`update_summary_status_record` also broadcasts `ai_summary_succeeded` on the JobChannel** (`ai_job_application_summary.rb:93-97`) after flipping the status row to `current` — fires on the bulk success path too. Not mentioned for S-B.

4. **ValidateAiSummaryGeneration fail conditions list is incomplete.** Map line 119 lists "credits exhausted, missing job description, or both-textract-failed" as the mid-run validation failures that leave the bulk row `:processing`. The interactor also fails on flipper-disabled (`validate_ai_summary_generation.rb:26`), no-resume (`:27`), nil job_application (`:24`), nil organization (`:25`) — any of these also yield `result.success? == false` and the same `:processing` dead end via `bulk_generate_ai_summaries_job.rb:60`. (Map phrasing is illustrative, not labeled exhaustive, but the enumeration omits reachable causes.)

clean = false
