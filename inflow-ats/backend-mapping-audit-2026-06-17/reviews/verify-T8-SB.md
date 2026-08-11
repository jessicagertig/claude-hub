# Verify T8-SB — Trigger 8 / S-B (bulk AI summary + Textract backfill)

**Verdict: CLEAN**

## Files checked
- OLD: `/Users/jessica/claude-hub/inflow-ats/backend-mapping-audit-2026-06-17/backend-flow-map-2026-06-17.md` — changelog lines 136-167; Part sections 432-438, 478-490, 515-517; matrix rows (lane 8 / lane B / broadcast row) ~735-754; write census ~847; Part-3 batch-failure ~625-626.
- NEW: `/Users/jessica/claude-hub/inflow-ats/backend-mapping-audit-2026-06-22-neutral.md` — T8 section 282-295; bulk flow 412-435; bridge 325-336; pipeline auto-branch 385-395; state tables 443-482; matrix 565/600/607/654; write census 622/626.

## CHECK 1 — Fact preservation
Every load-bearing OLD fact for T8/S-B confirmed present in NEW:

- Controller server-side ID resolution `:32-46`; `RoleFitFilterable#apply_role_fit_filter` `concerns/role_fit_filterable.rb:10,:15` → NEW 413.
- `with_textract_results` bare `joins(:textract_results)` `job_application.rb:115`, no text check; in_progress no-text counts ready then defers `:65-67` → NEW 287, 425.
- `.distinct` is the multi-TextractResult dedup; single-FAILED-result candidate already in `ready_ids`, not re-backfilled `:22-23` → NEW 287.
- `:current` rows dropped from BOTH `ready_ids` and `input_ids` `:36-40` (`:39`,`:40`); never processed/never counted skipped → NEW 416.
- Empty-working-set early return `:49-54` (queued_count=0 / skipped=input_ids.size / any_textract_pending); no async actor, only controller JSON `:20-24` → NEW 418.
- Backfill loop no Flipper (`:17`/`:18` gates only), no de-dup, builds new in_progress each time `submit_resume_to_textract.rb:22` → NEW 285.
- Backfill-submit FAILURE terminal (`:16` before `:22`, `&.` no-op, no TextractResult, job-wrapper rescue no retry) → NEW 293.
- Backfilled-candidate post-Textract terminals (auto-gen OFF/ON → orchestrate `:16` / credit-flow `:82`) → NEW 292.
- `BulkAiSummaryJobApplication` enum `{processing:0,done:1,failed:2,deferred:3}` _prefix:true → NEW 421.
- `each_iteration` order: idempotency `:48-56`/`:54` → `:60` validation gate → deferred `:65-67` → CreateBulkAiSummaryGeneration `:74` → credit-flow `:80` → done `:86`; rescue `:89-92` no re-raise/no row update → NEW 423.
- CreateBulkAiSummaryGeneration builds `:pending` before credit-flow; STALE-REBUILD `:40-43`/`:41`/`:42`; reuse `:45-48` only on matched textract_result_id; reuse query `.where.not(status: :failed).where(stale: false)` `:34-38`; credit-flow `:68` early-return only if succeeded-non-stale → NEW 427.
- `on_complete` floor_at `:104` + succeeded only `created_at >= floor_at` `:108`; deferred folded into skipped `:124`; failed by subtraction `:111`; mailer `.deliver_later` `:144/:171` → NEW 429.
- Normal-path notify_failure terminal `:113-114` (succeeded.zero? && failed.positive? → AI_SUMMARY_BULK_FAILED + mailer, no update_remaining_statuses_to_failed) → NEW 429.
- Whole-batch failure path: discard_on `:12-16` + retry_on `:17-21` → update_remaining_statuses_to_failed `:178-180` + notify_failure → NEW 431.
- Full ValidateAiSummaryGeneration fail list `:24-29` → `:60` returns without touching row, counted failed `:111` → NEW 433.
- Bulk-success status-row writes: set_initial_summary_pending `textract_result.rb:104-107` reached `:72` guard `:102`; update_summary_status_record → current `ai_job_application_summary.rb:69-80`; ai_summary_succeeded broadcast `:93-97` invalidating `['jobApplicationsForStage', hiringStageId]` → NEW 435.
- Claim-race + pre-filter: already_claimed_ids `:43-47`; RecordNotUnique `:70-75`; re-query `:78-80`; folds skipped `:88` → NEW 417.
- Payload hash `:82-89`, counts `:91-93` → NEW 419.
- Resume-but-no-Textract counting + no row + any_textract_pending signal `:52`/`:93` → controller JSON `:23` → NEW 289.
- No-resume bulk candidates skipped `:24`, counted skipped, no row, no backfill → NEW 295.
- Write census `BulkAiSummaryJobApplication` `queue_bulk_ai_summary_jobs.rb:65-69`, `bulk_generate_ai_summaries_job.rb:54/66/86/178-180` → NEW 626.
- Matrix lane 8 / lane B / broadcast row → NEW 600 / 607 / 565.

No DROPPED facts, no ALTERED facts (all file:line citations identical between OLD and NEW).

### Borderline (judged preserved)
OLD states explicitly (lines 153/154/161/626) that a per-row validation-failure or non-CustomError rescue leaves the bulk row **resting at `:processing`** (OLD words: "stuck", "stays :processing permanently", "per-row dead end"). NEW does not state that composite resting value in one place, but every premise is explicitly present and the value follows necessarily: the claim loop creates the row `:processing` (`queue_bulk_ai_summary_jobs.rb:65-69`, NEW 626); the validation-failure path returns "without touching the row" (NEW 433); the rescue is "no row update" (NEW 423); `on_complete` does not flip any `:processing` row (NEW 429). De-duplication of the explicitly-derivable composite is permitted, and the OLD framing words ("stuck"/"dead end"/"permanently") are exactly what the reframe was tasked to remove. Not flagged as a drop.

## CHECK 2 — Neutrality
No banned vocab or framing in the NEW T8/S-B text. The only `orphan*` token in NEW is the allowed method name `cleanup_orphaned_summary`. "never"/"only"/"stays"/"skipped" usages are neutral state-graph/code-behavior descriptions ("never processed and never counted skipped", "without flipping any `:processing` row", "stays `'none'`"). OLD's "silently skipped" (line 157) was de-framed to "skipped" (NEW 295) with the `:24` citation preserved. No prescriptive "should" (only method names `should_auto_generate_ai_summaries?` / `should_attach_external_resume_url?`). No "dead end", "stuck", "broken", "no-op", "silently", "hazard", "fails to", "gap", "problem", "defect", "wrong", "matters", "concerning", "MAP-WRONG".

## Conclusion
CLEAN — all T8/S-B facts and citations preserved; NEW text fully neutral.
