# S-B (Bulk generate) — Adversarial Review, Pass 6

Re-audited from scratch against current code. Files read:
- `app/interactors/queue_bulk_ai_summary_jobs.rb`
- `app/jobs/bulk_generate_ai_summaries_job.rb`
- `app/interactors/create_bulk_ai_summary_generation.rb`
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb`
- `app/controllers/concerns/role_fit_filterable.rb`
- `app/interactors/validate_ai_summary_generation.rb`
- `app/interactors/find_or_create_ai_job_application_summary_status.rb`
- `app/models/textract_result.rb`
- `app/models/ai_job_application_summary.rb`
- `app/models/bulk_ai_summary_job_application.rb`
- `app/models/job_application.rb` (scopes, latest_*, find_or_create_*)
- `app/services/ai_job_application_action/orchestrate.rb`

Every map claim for S-B verified AGREE. One omission and one path-citation discrepancy noted below.

## Verdicts

All AGREE. Key confirmations:

- L116 `with_textract_results` bare join — `job_application.rb:115` `scope :with_textract_results, -> { joins(:textract_results) }`. AGREE. Deferral at `bulk_generate_ai_summaries_job.rb:65-67`. AGREE.
- L117 `:current` dropped from ready_ids AND input_ids — `queue_bulk_ai_summary_jobs.rb:36-40`. AGREE.
- L118-119 empty-working-set early return + no async actor — `:49-54`. AGREE.
- L120 payload hash — `:82-89`. AGREE.
- L121 BulkAiSummaryJobApplication enum `{processing:0,done:1,failed:2,deferred:3}` _prefix:true — `bulk_ai_summary_job_application.rb:10`. AGREE.
- L122 routes through CreateBulkAiSummaryGeneration before credit flow — `bulk_generate_ai_summaries_job.rb:74-80`. AGREE.
- L123 idempotency guard succeeded/failed → :done — `:48-56` (query `:48-51`, set `:54`). AGREE.
- L124-125 on_complete folding / floor_at / failed-by-subtraction / .deliver_later — `:104,108,111,124,144,171`. AGREE.
- L126 normal-path notify_failure (succeeded.zero? && failed.positive?) WITHOUT flipping :processing rows — `:113-114`. AGREE.
- L127 backfill not gated by TEXTRACT_RESUME_PROCESSING; pre-flight gates AI_APPLICANT_SUMMARY `:17` + ai_credits_available? `:18` — AGREE.
- L128 no backfill de-dup guard; new TextractResult each time — `:28-30`, submit builds new. AGREE.
- L129 each_iteration guard order — `:48-56 → :60 → :65-67 → :74 → :80 → :86`. AGREE.
- L130 validation-failure dead end (:processing, counted failed-by-subtraction) — `:60`. AGREE.
- L131 each_iteration rescue dead end — `:89-92`. AGREE.
- L132 whole-batch discard_on flips rows + notify_failure — `:12-16`, `update_remaining_statuses_to_failed` `:178-180`. AGREE.
- L133-134 pending_textract / no-resume counting + no row. AGREE.
- L135 claim-race + RecordNotUnique rescue — `:43-47`, `:70-75`, re-query `:78-80`. AGREE.
- L136 bulk-success terminal: update_summary_status_record writes status 'current' + denormalized cols via .update guarded saved_change_to_status? && status_succeeded? — `ai_job_application_summary.rb:30,69,74-80`. set_initial_summary_pending writes 'initial_summary_pending' via update_columns `textract_result.rb:104-107`, reached `:72`, guarded `:102`. AGREE.
- L137 bulk-success broadcast JobChannel ai_summary_succeeded — `ai_job_application_summary.rb:93-97`. AGREE.
- L138 full ValidateAiSummaryGeneration fail list — `validate_ai_summary_generation.rb:24-29` (nil JA `:24`, nil org `:25`, flipper `:26`, resume `:27`, credits `:28`, job desc `:29`). AGREE.
- L139 CreateBulkAiSummaryGeneration builds :pending BEFORE credit flow → latest non-nil → set_initial_summary_pending succeeds — `create_bulk_ai_summary_generation.rb:50-57`, `bulk_generate_ai_summaries_job.rb:74,80`. AGREE.
- L140 reuse query `.where.not(status: :failed).where(stale: false)` reuses ANY non-failed non-stale; credit `:68` early return only when reused succeeded-non-stale — `create_bulk_ai_summary_generation.rb:34-48`, `textract_result.rb:68`. AGREE.
- L693 (matrix) 1 credit per success — `textract_result.rb:82-84`. AGREE.

## Omissions

1. **`already_summarized_ids` pre-filter only protects against `:current` status rows, not against an in-flight bulk that produced a still-advancing succeeded summary in the SAME run.** Adequately covered by the per-iteration idempotency guard (L123); not a true gap, but the interaction (cross-run `:current` drop at `queue_bulk_ai_summary_jobs.rb:36-40` vs in-run guard at `bulk_generate_ai_summaries_job.rb:48-56`) is two distinct dedup mechanisms and the map documents both. Not an omission after re-reading. (Withdrawn.)

2. **Path discrepancy (minor, not S-B-specific):** the map cites `orchestrate.rb` without directory; the file is at `app/services/ai_job_application_action/orchestrate.rb`, not `app/interactors/`. The bulk credit flow's `Orchestrate#call` selects `@job_application.ai_job_application_summaries.order(created_at: :desc).first` (`orchestrate.rb:15`) — JobApplication-scoped, no stale filter — confirming the bulk-built `:pending` summary is the one advanced. The map's line numbers (`:15-16`, `:46-48`) are correct for this file. Flagged as a path-precision omission since the map nowhere states the `app/services/...` directory for Orchestrate.

## Conclusion

clean = false (solely due to the Orchestrate file-path omission #2; every behavioral verdict for S-B is AGREE).
