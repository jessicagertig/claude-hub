# T8 — Bulk AI summary backfill (QueueBulkAiSummaryJobs, resume-but-no-Textract) — Pass 6 Adversarial Review

**Verdict: clean = false** (every map claim AGREE, but one terminal-trace omission).

## Files traced (chain)
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb` → `app/controllers/concerns/role_fit_filterable.rb`
- `app/interactors/queue_bulk_ai_summary_jobs.rb` → `app/models/job_application.rb:114-115` (`with_resume`, `with_textract_results`) → `app/services/submit_resume_to_textract.rb` → `app/jobs/submit_resume_to_textract_job.rb`
- `app/jobs/bulk_generate_ai_summaries_job.rb` → `app/models/bulk_ai_summary_job_application.rb` → `app/interactors/validate_ai_summary_generation.rb` → `app/interactors/create_bulk_ai_summary_generation.rb` → `app/models/textract_result.rb` (`generate_ai_summary_with_credit_flow` :61-89, `set_initial_summary_pending` :98-108, `queue_ai_summary_job` :114-144, callback :7) → `app/models/ai_job_application_summary.rb` (:29-31, `update_summary_status_record` :57-98) → `app/services/ai_job_application_action/orchestrate.rb`
- `config/routes.rb:199`

## Per-claim verdicts (map lines 115-141)

| # | Map claim | Verdict | Anchor |
|---|---|---|---|
|115| Controller resolves IDs server-side: included OR (hiring_stage_id + role_fit − excluded); RoleFitFilterable new | AGREE | controller :32-46; role_fit_filterable.rb:10 module, :15 `apply_role_fit_filter` |
|116| `with_textract_results` = bare `joins(:textract_results)`, no text check; in_progress counts ready, DEFERS at iteration | AGREE | job_application.rb:115; bulk_generate_ai_summaries_job.rb:65-67, :66 `update_columns(status: :deferred)` |
|117| `:current` status rows dropped from BOTH ready_ids and input_ids | AGREE | queue_bulk_ai_summary_jobs.rb:36-40 (:39, :40) |
|118| Empty-working-set early return: queued=0, skipped=input_ids.size, any_textract_pending | AGREE | queue_bulk_ai_summary_jobs.rb:49-54 |
|119| Empty-set terminal: no BulkGenerateAiSummariesJob, no on_complete, no toast/mailer; only sync JSON | AGREE | returns :49-54 before enqueue :82; controller :20-24 |
|120| BulkGenerateAiSummariesJob enqueued with payload HASH | AGREE | queue_bulk_ai_summary_jobs.rb:82-89, counts :91-93 |
|121| BulkAiSummaryJobApplication enum {processing:0,done:1,failed:2,deferred:3} _prefix; :deferred at :66 | AGREE | bulk_ai_summary_job_application.rb:10; bulk_generate_ai_summaries_job.rb:66 |
|122| Bulk routes through CreateBulkAiSummaryGeneration before generate_ai_summary_with_credit_flow | AGREE | bulk_generate_ai_summaries_job.rb:74 then :80 |
|123| Per-iteration idempotency guard → :done, skip | AGREE | bulk_generate_ai_summaries_job.rb:48-56, :54 `update_columns(status: :done)` |
|124| on_complete folds deferred into skipped; failed by subtraction; mailer .deliver_later | AGREE | :111, :124, :144, :171 |
|125| counting floor `floor_at = bulk_job_statuses.minimum(:created_at)`; succeeded where created_at>=floor | AGREE | :104, :108 |
|126| Normal-path notify_failure terminal; WITHOUT update_remaining_statuses_to_failed | AGREE | :113-114; on_complete never calls update_remaining_statuses_to_failed |
|127| Backfill SubmitResumeToTextractJob does NOT check TEXTRACT_RESUME_PROCESSING; gates :17 AI_APPLICANT_SUMMARY, :18 ai_credits_available?; loop :28-30 gated by neither; not in run via :23 | AGREE | queue_bulk_ai_summary_jobs.rb:17,18,23,28-30; service has no flipper |
|128| No backfill idempotency/de-dup; SubmitResumeToTextract builds NEW in_progress each time, no find_or_create | AGREE | queue_bulk_ai_summary_jobs.rb:28-30 unconditional; submit_resume_to_textract.rb:22 `.build` |
|129| each_iteration guard order :48-56 → :60 → :65-67 → :74 → :80 → :86 | AGREE | bulk_generate_ai_summaries_job.rb |
|130| `return unless result.success?` :60; update_remaining only from discard_on/retry_on; counted failed by subtraction :111 | AGREE | :60, :12-16, :17-21, :111 |
|131| each_iteration rescue :89-92 logs, no re-raise, no row update | AGREE | :89-92 |
|132| Whole-batch failure: discard_on :12-16 → update_remaining_statuses_to_failed :178-180 + notify_failure | AGREE | :12-16, :178-180 |
|133| pending_textract_ids :23, backfill :28-30, not in ready/working/claimed but in input_ids → skipped_count :88/:92/:51; no row :47; signal any_textract_pending :52/:93; controller JSON :23 | AGREE | all lines confirmed; :39-40 subtraction cannot remove pending_textract_ids (computed from ready_ids only) |
|134| no-resume candidates not in ready/pending (both with_resume :22-23); silently skipped :24; counted skipped, no row, no backfill | AGREE | :22, :23, :24 |
|135| already_claimed_ids pre-filter :43-47; rescue RecordNotUnique :70-75; re-query :78-80; folds into skipped :88 | AGREE | confirmed |
|136| bulk-success status-row write: update_summary_status_record :74-80 via .update, guarded :69; earlier set_initial_summary_pending :104-107 via update_columns, reached :72, guarded :102 | AGREE | ai_job_application_summary.rb:30,69,74-80; textract_result.rb:72,102,104-107 |
|137| update_summary_status_record broadcasts JobChannel ai_summary_succeeded :93-97 | AGREE | ai_job_application_summary.rb:93-97 |
|138| Full ValidateAiSummaryGeneration fail list: credits :28, job-desc :29, both-textract-failed :52-53, flipper :26, no-resume :27, nil ja :24, nil org :25 → :60 dead end, counted failed :111 | AGREE | validate_ai_summary_generation.rb:24-29,52-53 |
|139| CreateBulkAiSummaryGeneration builds :pending :74 before credit flow :80; latest non-nil; set_initial_summary_pending succeeds for bulk | AGREE | bulk_generate_ai_summaries_job.rb:74,80; create_bulk_ai_summary_generation.rb:50-52 |
|140| Reuse query .where.not(status: :failed).where(stale: false) :34-38, returns regardless :45-48; credit :68 early-return only when reused active is succeeded+non-stale | AGREE | create_bulk_ai_summary_generation.rb:34-38,45-48; textract_result.rb:68 |
|141| (Trigger 9, out of T8 scope but adjacent) | n/a | not a T8 claim |

## Omissions (T8-specific)

**O1 — Backfilled-candidate terminal AFTER its Textract lands is not traced in the T8 section.**
The slice mandate is "trace to terminal." The map's T8 section (lines 127/128/133) documents the backfill ENQUEUE (`queue_bulk_ai_summary_jobs.rb:28-30`) and says the candidates are "ready for the next bulk run," but never states what happens when the backfill `SubmitResumeToTextractJob` actually runs and its TextractResult succeeds. Traced terminal:

- `SubmitResumeToTextract#submit_resume` builds an `in_progress` TextractResult (`submit_resume_to_textract.rb:22`) and schedules `GetResumeTextFromTextractJob` (`:27`).
- On Textract success the bridge `after_commit :queue_ai_summary_job` fires (`textract_result.rb:7`, body :114-144).
- The bulk-backfill candidate has NO `textract_processing`/`stale:false` waiting summary (the bulk path created none for these candidates — they were excluded from the working set), so the waiting-summary query (`textract_result.rb:121-123`) returns nil and the bridge takes the **else/auto branch** (`:137`).
- That branch is gated on `job_application&.job&.should_auto_generate_ai_summaries?` (`textract_result.rb:138`):
  - **Auto-gen OFF** → returns at `:138`; the candidate now has a succeeded TextractResult but NO AiJobApplicationSummary and the status row stays `none`. No summary is ever produced from the backfill alone.
  - **Auto-gen ON** → enqueues `GenerateAiJobApplicationSummaryJob` with NO requesting user (`:142`), which lands in the S-C **no-pre-existing-summary NO-OP dead end**: `Orchestrate#call` returns at `orchestrate.rb:16` (`return unless @ai_job_application_summary`) because the backfill candidate has no summary row → no summary, no credit, no broadcast; status row stays `none`.
- Net: in BOTH auto-gen states the backfill alone produces NO summary. The candidate only becomes processable on a SUBSEQUENT bulk run (when `with_textract_results` now matches the freshly-succeeded TextractResult and `CreateBulkAiSummaryGeneration` builds the `:pending` summary). The map's "ready for the next bulk run" is correct but omits that the auto-path bridge will NOT self-generate a summary for these candidates in the interim — a load-bearing terminal for the T8 slice.

(The map covers the S-C no-op generically under Trigger C and cross-references it, but does not co-locate this as the T8 backfill terminal, which the slice's "trace to terminal" mandate requires.)
