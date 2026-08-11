# T2 — Manual Resume Upload / Replacement (internal) — Adversarial Pass 3

Slice: controller `update` resume-param path → `SubmitResumeToTextractJob`; stale-marking of any existing `AiJobApplicationSummary`; what happens to the `AiJobApplicationSummaryStatus` row.

Code re-read from scratch (files opened):
- `app/controllers/api/v1/job_applications_controller.rb:85-126` (update action)
- `app/jobs/submit_resume_to_textract_job.rb:1-14`
- `app/services/submit_resume_to_textract.rb:1-42`
- `app/interactors/find_or_create_ai_job_application_summary_status.rb:1-47`
- `app/models/ai_job_application_summary.rb:20-112`
- `app/models/textract_result.rb:61-144`
- `app/services/ai_job_application_action/orchestrate.rb:1-106`
- `app/models/job_application.rb:29-32, 160, 589`

## Verdicts

### AGREE

1. Map line 227-228 / 555: "Chain: Controller update action → SubmitResumeToTextractJob; File `job_applications_controller.rb:107-115`. After `if job_application.update(temp_params)` (107): `if temp_params.key?(:resume) && temp_params[:resume].present?` → `DocxToPdfJob.perform_later`, then `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, current_organization)` → `SubmitResumeToTextractJob.perform_later` (113)."
   - AGREE. `job_applications_controller.rb:107` `if job_application.update(temp_params)`; `:110` `if temp_params.key?(:resume) && temp_params[:resume].present?`; `:112` `DocxToPdfJob.perform_later(job_application.id)`; `:113` `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, current_organization)`; `:114` `SubmitResumeToTextractJob.perform_later(job_application.id)`.

2. Map line 229: "Creates NO `AiJobApplicationSummary` and does NOT call `CreateAiSummaryGeneration` directly."
   - AGREE. The update action (88-126) contains no `CreateAiSummaryGeneration` and no `AiJobApplicationSummary` create; only `DocxToPdfJob` and `SubmitResumeToTextractJob` enqueues. `SubmitResumeToTextract` (1-42) creates no summary either.

3. Map line 230 / 555: "The status row is NOT touched by `SubmitResumeToTextract`; its only summary-table write is the conditional `update_all(stale: true)`."
   - AGREE. `submit_resume_to_textract.rb:18-19` `unless ...where(status: :textract_processing, stale: false).exists?` → `@job_application.ai_job_application_summaries.update_all(stale: true)`. No reference to `ai_job_application_summary_status` anywhere in `submit_resume_to_textract.rb`, `submit_resume_to_textract_job.rb`, or the controller update path (grep confirmed; controller status-row refs are only `.includes(...)` preloads at `:27,38,56`, which are index/show, not update).

4. Map line 191 (Part 1 submission detail): conditional stale-marking `update_all` sets only `stale`, status unchanged; skipped if a non-stale textract_processing summary exists.
   - AGREE. `submit_resume_to_textract.rb:18-19`. `update_all(stale: true)` writes only the `stale` column; `update_all` bypasses callbacks so `update_summary_status_record` does NOT fire from this write.

5. Map line 29: "MAP-WRONG (old Gap 7): `regenerating` IS set, at `find_or_create_ai_job_application_summary_status.rb:14-15`, guarded on the row's associated summary being `status_succeeded?`."
   - AGREE. `:14` `if summary&.status_succeeded?`; `:15` `@status_record.update_columns(status: 'regenerating')`.

6. Map line 30: "guard is now `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?` (`textract_result.rb:67-68`). A staled-succeeded summary no longer short-circuits the credit flow's early return."
   - AGREE. `textract_result.rb:67` `latest_ai_summary = job_application.latest_ai_job_application_summary`; `:68` `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`. A stale summary fails `!stale?`, so no early return.

7. Map line 31: "`after_commit :create_status_record, on: :create` no longer exists on `AiJobApplicationSummary`."
   - AGREE. `ai_job_application_summary.rb:29-31` lists `destroy_previous_textract_results`, `update_summary_status_record`, `broadcast_status_change`. No `create_status_record`.

8. Map line 32: "`AiJobApplicationSummaryStatus` has its own 4-value status enum and NO `regenerating` boolean column."
   - AGREE (re-verified for T2 relevance via the FindOrCreate/credit-flow writers; status enum value `regenerating` written via `update_columns(status: 'regenerating')` at `find_or_create_ai_job_application_summary_status.rb:15`, a status value not a boolean).

9. Map line 33: "`update_summary_status_record` sets `status: 'current'` (enum value 2) via `.update`, NOT `'succeeded'`/integer-7 via `update_columns`, and writes no `regenerating` column."
   - AGREE. `ai_job_application_summary.rb:74-80` `ai_job_application_summary_status.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)`.

### DISPUTE

10. Map line 34 (T2 DIVERGENCE CHANGELOG, the NEW desync-window bullet): "Status-row denormalized-column desync window during replacement (status flips `current` → `regenerating` → `current`; denormalized score/headline/analysis never cleared during the window)."
    - DISPUTE. The `→ current` recovery does NOT occur on the T2 auto path (resume replacement with auto-gen on). Trace: after the new TextractResult succeeds, `queue_ai_summary_job` takes the `else` auto branch (`textract_result.rb:137` — no `textract_processing` waiting summary exists because the prior summary is `succeeded`+`stale`). `generate_ai_summary_with_credit_flow` does NOT early-return at `:68` (latest summary is stale-succeeded, fails `!stale?`), then `find_or_create_ai_job_application_summary_status` (`:70`) flips the row to `regenerating` (`find_or_create_ai_job_application_summary_status.rb:14-15`). Then `Orchestrate#call` selects the stale-succeeded summary (`orchestrate.rb:15`, `order(created_at: :desc).first`, no stale filter), `:16` passes, the `case` hits `status_succeeded?` and `return`s (`orchestrate.rb:46-48`). NO new summary is created, so `update_summary_status_record` never fires (`ai_job_application_summary.rb:69` requires `saved_change_to_status? && status_succeeded?` on a summary update that never happens). The row is STUCK at `regenerating`, never reset to `current`.
    - This contradicts the map's OWN correct findings elsewhere: line 116 ("set to `'regenerating'` ... and is NEVER reset to `'current'`"), 5.3 dead-end line 517 ("Stuck `regenerating` (D auto-regen) ... never reset to `current`"), Part 7 row D line 570 ("status row stuck `regenerating`"), desync window 4 line 652.
    - Correction: replace the `current → regenerating → current` phrasing in the line-34 bullet with: "status flips `current` → `regenerating` and (on the auto/resume-replacement path with auto-gen ON) STAYS `regenerating` indefinitely — `Orchestrate` no-ops on the stale-succeeded summary (`orchestrate.rb:46-48`) so no new summary reaches `succeeded` and `update_summary_status_record` never fires to reset to `current`; the denormalized `score_percentage`/`headline`/`integrated_role_analysis`/`ai_job_application_summary_id` are never cleared and continue showing the OLD review. The `→ current` recovery happens ONLY on a subsequent MANUAL regeneration (T9/S-A), which builds a fresh `:pending` summary that can reach `succeeded`." (If auto-gen is OFF, the bridge `else` branch returns at `textract_result.rb:138` and the row is never even flipped to `regenerating` — it stays `current` with stale data.)

## Omissions (for the T2 slice)

O1. The T2 DIVERGENCE CHANGELOG (lines 28-35) and Part 7 row 2 (line 555) omit the auto-gen GATE on the T2 continuation. After the replacement TextractResult succeeds, whether the status row is touched at all depends on `job.should_auto_generate_ai_summaries?` (`textract_result.rb:138`, in the bridge `else` branch). Auto-gen OFF → bridge returns at `:138`, row stays `current` with now-stale denormalized data and is never flipped to `regenerating`; the stale-succeeded summary is left `stale:true` with no further actor. This OFF terminal is a distinct T2 resting state not stated in the T2 changelog. (The map covers the auto path under Trigger D but never states that T2's own status-row outcome forks on the auto-gen gate.)

O2. The T2 changelog does not state that the `else`/auto branch enqueues `GenerateAiJobApplicationSummaryJob` with NO `requesting_organization_user_id` (`textract_result.rb:142`), so the user who replaced the resume gets NO `AI_SUMMARY_COMPLETE` toast even when auto-gen runs. (Documented for Trigger C at line 108 but not cross-referenced from T2, where it is the user-visible outcome of a manual action.)

O3. The T2 changelog does not name the no-resume fork at the T2 entry: if the update clears/omits the resume such that `has_resume` is false, `SubmitResumeToTextract` returns `'No resume attached'` (`submit_resume_to_textract.rb:10`) before the stale `update_all` (`:18-19`) and before the build (`:22`) — so on a resume *removal* no stale-marking and no TextractResult occur. The T2 path is only meaningful when `temp_params[:resume].present?` (controller `:110`), so a present resume is guaranteed by the guard; still, the dependency of stale-marking on `has_resume` being true at submit time is unstated.

## clean = false (one DISPUTE at map line 34; three omissions)
