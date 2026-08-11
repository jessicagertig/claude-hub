# T2 — Manual Resume Upload / Replacement (Internal App)

**Slice:** Controller `update` action resume-param path → `SubmitResumeToTextractJob`. Focus: stale-marking of existing `AiJobApplicationSummary`, and exactly what happens to the `AiJobApplicationSummaryStatus` row.

## Files traced (chain)

```
app/controllers/api/v1/job_applications_controller.rb:88-127 (update)
  → :resume permitted via app/policies/job_application_policy.rb:33-39 (permitted_attributes)
  → app/jobs/submit_resume_to_textract_job.rb:6-12 (perform)
    → app/services/submit_resume_to_textract.rb:8-41 (submit_resume)
        → app/models/job_application.rb:589 (has_resume guard)
        → app/models/job_application.rb:722 (has_resume_docx_to_pdf — resume selection)
        → TextractResumeParser::Client#send_to_textract (gem-boundary AWS)
        → app/models/ai_job_application_summary.rb (update_all stale; bypasses callbacks)
        → app/jobs/get_resume_text_from_textract_job.rb (+2 min poll — out of slice, summarized)
  ... Textract completes ...
  → app/models/textract_result.rb:114-144 (queue_ai_summary_job after_commit)
    → app/jobs/generate_ai_job_application_summary_job.rb
      → app/models/textract_result.rb:61-89 (generate_ai_summary_with_credit_flow)
          → app/models/textract_result.rb:67-68 (stale/succeeded early-return guard)
          → app/models/job_application.rb:160-161 (find_or_create_ai_job_application_summary_status)
            → app/interactors/find_or_create_ai_job_application_summary_status.rb:6-45
          → app/models/textract_result.rb:98-108 (set_initial_summary_pending)
          → AiJobApplicationAction::Orchestrate (pipeline — out of slice)
          → app/models/ai_job_application_summary.rb:57-94 (update_summary_status_record after_commit on succeeded)
```

## Key finding for T2

`SubmitResumeToTextract#submit_resume` (the resume-replacement service on this path) **does NOT touch the `AiJobApplicationSummaryStatus` row at all.** Its only summary-side write is `update_all(stale: true)` on `ai_job_application_summaries` (the summary table, not the status table). The status row is only mutated LATER, when `generate_ai_summary_with_credit_flow` runs after Textract completes — via `find_or_create_ai_job_application_summary_status` (→ `regenerating`) and the eventual `update_summary_status_record` (→ `current`). The map is badly out of date on the status table.

---

## Behaviors

### B1 — Resume-param detection in controller update

(a) **Code:** `app/controllers/api/v1/job_applications_controller.rb:110` — `if temp_params.key?(:resume) && temp_params[:resume].present?`; line 113-115 — `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, current_organization)` then `SubmitResumeToTextractJob.perform_later(job_application.id)`. Runs only AFTER `if job_application.update(temp_params)` (line 107) succeeds. Also enqueues `DocxToPdfJob.perform_later` (line 112) unconditionally on the resume branch.
(b) **Map:** lines 84-92 / Trigger Matrix row 2 (line 682): "Explicit check: `temp_params.key?(:resume) && temp_params[:resume].present?` (line 106)", "Guards: `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, current_organization)`", "Also enqueues: `DocxToPdfJob`", "Runs AFTER `job_application.update(temp_params)` succeeds (line 103)".
(c) **Verdict:** CONFIRMED (line numbers drifted: check is at 110 not 106; update at 107 not 103).
(d) **Map text:** "`app/controllers/api/v1/job_applications_controller.rb:88` (update). Resume branch entered when `temp_params.key?(:resume) && temp_params[:resume].present?` (line 110), only after `job_application.update(temp_params)` succeeds (line 107). Enqueues `DocxToPdfJob.perform_later` (line 112) unconditionally, and `SubmitResumeToTextractJob.perform_later` (line 114) gated on `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, current_organization)` (line 113)."

### B2 — Conditional stale-marking of existing summaries

(a) **Code:** `app/services/submit_resume_to_textract.rb:18-20`:
```ruby
unless @job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).exists?
  @job_application.ai_job_application_summaries.update_all(stale: true)
end
```
If NO non-stale `textract_processing` summary exists → marks ALL summaries `stale: true` via `update_all` (callback-bypassing, no `updated_at` bump beyond what update_all writes, no `broadcast_status_change`). If such a summary DOES exist → the entire `update_all` is skipped (nothing staled).
(b) **Map:** lines 38, 587-590: "Conditional stale marking (lines 18-20): if NO `textract_processing` + `stale: false` summary exists → marks ALL summaries `stale: true` via `update_all`. If one exists → skips staling entirely."
(c) **Verdict:** CONFIRMED.
(d) **Map text:** Keep as-is. Add explicit note: "`update_all` bypasses AR callbacks — `broadcast_status_change` does NOT fire, so the frontend gets no `ai_summary_status_change` event from this staling. The `AiJobApplicationSummaryStatus` row is NOT touched here."

### B3 — SubmitResumeToTextract does NOT touch the status row

(a) **Code:** `app/services/submit_resume_to_textract.rb` (entire file, lines 8-41) contains zero references to `ai_job_application_summary_status`, `find_or_create_ai_job_application_summary_status`, `FindOrCreateAiJobApplicationSummaryStatus`, or the `status` table. The only writes are: `ai_job_application_summaries.update_all(stale: true)` (line 19), `textract_results.build(...)` + `.save` (lines 22-24), `waiting_summary&.update_columns(textract_result_id:)` (line 26), and on AWS error `@textract_result&.update_columns(textract_job_status: 'failed')` (lines 33, 39).
(b) **Map:** Part 4 "Cascade on Resume Replacement" (lines 585-591) lists stale-marking, new TextractResult, `textract_result_id` update — and does NOT mention the status row in this cascade. So the absence is implicitly consistent, but the map never states it explicitly.
(c) **Verdict:** CONFIRMED (behavior) / map ABSENT on the explicit statement.
(d) **Map text:** Add to the resume-replacement cascade: "`SubmitResumeToTextract` does NOT mutate the `AiJobApplicationSummaryStatus` row. After a resume replacement the status row keeps its prior value (`current` with the old summary's `ai_job_application_summary_id`, `score_percentage`, `headline`, `integrated_role_analysis`) until generation later runs. This is a denormalization desync window — see B6."

### B4 — `waiting_summary` textract_result_id backfill (replacement path rarely hits this)

(a) **Code:** `app/services/submit_resume_to_textract.rb:25-26`: `waiting_summary = @job_application.ai_job_application_summaries.find_by(status: :textract_processing, stale: false, textract_result_id: nil)` then `waiting_summary&.update_columns(textract_result_id: @textract_result.id)`. On a pure resume *replacement* where prior summaries were just staled (B2), there is normally no non-stale `textract_processing` summary, so `waiting_summary` is nil and nothing happens. (This branch primarily serves the manual-generate-with-no-TextractResult handoff, slice T-other.)
(b) **Map:** lines 40, 590: "finds any `AiJobApplicationSummary` with `status: :textract_processing`, `stale: false`, and `textract_result_id: nil` ... `update_columns(textract_result_id: @textract_result.id)`".
(c) **Verdict:** CONFIRMED.
(d) **Map text:** Keep. Note via `update_columns` (callback-bypassing). On the replacement path `waiting_summary` is typically nil.

### B5 — New TextractResult created; old NOT destroyed here

(a) **Code:** `app/services/submit_resume_to_textract.rb:22`: `@textract_result = @job_application.textract_results.build(textract_job_id: textract.job_id, textract_job_status: 'in_progress')`; line 24 `.save`; line 27 `GetResumeTextFromTextractJob.set(wait: 2.minutes).perform_later`. No destroy of prior TextractResults on this path. (Prior non-succeeded TextractResults are destroyed later, by `AiJobApplicationSummary#destroy_previous_textract_results` once the NEW summary reaches `succeeded` — `ai_job_application_summary.rb:47-55`.)
(b) **Map:** lines 39, 591: "Creates new TextractResult with `textract_job_id` ... status `in_progress`"; "Previous TextractResult is NOT destroyed (unlike the old behavior)".
(c) **Verdict:** CONFIRMED.
(d) **Map text:** Keep.

### B6 — Status-row transition happens LATER, post-Textract, via generate_ai_summary_with_credit_flow (NOT in T2's service)

(a) **Code:** After Textract polling writes `textract_job_result_text`, `TextractResult#queue_ai_summary_job` (`textract_result.rb:114-144`) fires (`after_commit on: [:create, :update]`). On the replacement/auto path with no waiting summary it falls to the else branch (line 137) gated on `job_application&.job&.should_auto_generate_ai_summaries?` (line 138). The enqueued `GenerateAiJobApplicationSummaryJob` calls `generate_ai_summary_with_credit_flow` (`textract_result.rb:61-89`):
- Line 67-68: `latest_ai_summary = job_application.latest_ai_job_application_summary; return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`. **After B2 staled the old summary, `stale?` is true, so this guard does NOT short-circuit** — generation proceeds. (This is the fix to old-map Gap 8 / Trigger D "BROKEN".)
- Line 70: `status_result = job_application.find_or_create_ai_job_application_summary_status` → `FindOrCreateAiJobApplicationSummaryStatus` (`find_or_create_ai_job_application_summary_status.rb`). The status row already exists (one-per-job_application). Lines 11-21: `if @status_record` then `summary = @status_record.ai_job_application_summary; if summary&.status_succeeded? then @status_record.update_columns(status: 'regenerating')` and broadcasts `ai_summary_status_change` on `JobChannel`. **This is the moment the status row flips to `regenerating`** — and it is the only place `regenerating` is ever set (`status: 'regenerating'` literal at `find_or_create_ai_job_application_summary_status.rb:15`).
- Line 72: `set_initial_summary_pending(status_result)` (`textract_result.rb:98-108`) only acts when status is `none`/`initial_summary_pending` (line 102 guard) — so for a replacement it does nothing (status is now `regenerating`).
- Eventually, when the NEW summary reaches `succeeded`, `AiJobApplicationSummary#update_summary_status_record` (`ai_job_application_summary.rb:57-94`) runs `update_columns(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:, updated_at:)` (lines 74-81) and broadcasts `ai_summary_succeeded` on `JobChannel` (lines 89-93).
(b) **Map:** Gap 7 (lines 638-651) says `regenerating` "is never set to `true`" / "currently never set to `true` (broken/incomplete implementation)"; Gap 8 (lines 652-658) + Trigger D (line 698) say resume-replacement auto-regen is BROKEN (credit consumed, no new summary); map line 500 claims a `create_status_record` `after_commit on: :create` callback exists; map lines 502-505/509-520 describe the status enum as the 10-value summary enum with a `regenerating` BOOLEAN column; map line 605 says `update_summary_status_record` sets `status: ...['succeeded']` (7) and `regenerating: false`.
(c) **Verdict:** MAP-WRONG / CHANGED on multiple counts:
  - `regenerating` IS set (`find_or_create_ai_job_application_summary_status.rb:15`). Gap 7 is obsolete.
  - Resume-replacement regen is NOT broken: `generate_ai_summary_with_credit_flow` line 68 guard now checks `&& !latest_ai_summary.stale?`, so a staled-succeeded summary does NOT short-circuit. Gap 8 / Trigger D "BROKEN" is obsolete.
  - No `create_status_record` callback exists on `AiJobApplicationSummary` (grep across `app/` returns zero). Map line 500 REMOVED.
  - The status enum is `{none:0, initial_summary_pending:1, current:2, regenerating:3}` (`ai_job_application_summary_status.rb:7-12`), NOT the 10-value summary enum; there is NO `regenerating` boolean column. Map lines 509-520 MAP-WRONG.
  - `update_summary_status_record` sets `status: 'current'` (the enum value 2), not `'succeeded'`/7, and references no `regenerating` column (`ai_job_application_summary.rb:74-81`). Map line 605 MAP-WRONG.
(d) **Map text:** Replace Gap 7 and Gap 8 with: "RESOLVED. `AiJobApplicationSummaryStatus.status` is its own 4-value enum `{none, initial_summary_pending, current, regenerating}` (`ai_job_application_summary_status.rb:7-12`); `regenerating` is an enum value, not a boolean column. On a resume replacement the status row stays at its prior `current` value through `SubmitResumeToTextract` (no status write there) and flips to `regenerating` only when generation runs, at `FindOrCreateAiJobApplicationSummaryStatus` (`find_or_create_ai_job_application_summary_status.rb:14-15`) — guarded on the row's associated summary being `succeeded`. `generate_ai_summary_with_credit_flow` (`textract_result.rb:67-68`) no longer short-circuits on a succeeded-but-stale summary because the guard is `status_succeeded? && !stale?`. On new-summary success the row returns to `current` via `update_summary_status_record` (`ai_job_application_summary.rb:74-81`, literal `status: 'current'`)."

### B7 — Desync window: status row disagrees with latest non-stale summary after replacement

(a) **Code:** Between `SubmitResumeToTextract#submit_resume` staling the old summaries (`submit_resume_to_textract.rb:19`) and the eventual `update_columns(status: 'current', ...)` on the new summary's success (`ai_job_application_summary.rb:74-81`), the `AiJobApplicationSummaryStatus` row holds the OLD summary's denormalized `score_percentage`/`headline`/`integrated_role_analysis`/`ai_job_application_summary_id`. Its `status` is `current` until generation starts (then `regenerating` at `find_or_create_ai_job_application_summary_status.rb:15`). The list view (`shallow_job_application_serializer.rb:23` / `job_application_serializer.rb:40` via `AiJobApplicationSummaryStatusSerializer`) therefore shows stale denormalized fit data for this whole window.
(b) **Map:** ABSENT (map's status-table treatment is wrong, see B6).
(c) **Verdict:** NEW.
(d) **Map text:** Add a "Status-row desync windows" subsection: "After resume replacement, the status row carries the OLD summary's denormalized columns (`score_percentage`, `headline`, `integrated_role_analysis`, `ai_job_application_summary_id`) until the new summary succeeds. Its `status` is `current` from replacement until generation begins, then `regenerating` (set in `FindOrCreateAiJobApplicationSummaryStatus`), then `current` again on success. The denormalized score/headline/analysis are NOT cleared during the window — the list view shows old fit data labeled `regenerating`."

### B8 — AWS-failure path leaves status row untouched (and may orphan)

(a) **Code:** `app/services/submit_resume_to_textract.rb:31-40` — on `Aws::Textract::Errors::InvalidS3ObjectException` or any `StandardError`, `@textract_result&.update_columns(textract_job_status: 'failed')`. No status-row write, no broadcast. If the AWS `send_to_textract` (line 16) itself raises before `@textract_result` is built, even the TextractResult write is skipped (safe-nav `&.`). The status row is never advanced or reverted on this path.
(b) **Map:** Gap 4 (lines 629-630) covers the orphaned `textract_processing` summary but not the status row.
(c) **Verdict:** CONFIRMED (failure handling) / status-row aspect NEW.
(d) **Map text:** Add to Gap 4: "On AWS failure the `AiJobApplicationSummaryStatus` row is not touched — if it was already flipped to `regenerating` by a concurrent generate attempt it stays `regenerating` indefinitely; on a plain replacement it stays `current` with old data."

---

## Branch logic on this path (Textract-not-ready vs ready)

T2's service ALWAYS submits to Textract and creates a NEW `in_progress` `TextractResult` (`submit_resume_to_textract.rb:22`); it never short-circuits on an existing Textract result. The "no usable Textract result → summary waits in `textract_processing`" vs "Textract ready → pipeline proceeds" branch is NOT decided in this service. For the replacement path the AI pipeline only kicks off AFTER the new Textract poll writes `textract_job_result_text` and `queue_ai_summary_job` fires (`textract_result.rb:114-116`). The waiting/ready split is owned by `queue_ai_summary_job` (waiting-summary branch line 125 vs auto-generate else branch line 137) and `generate_ai_summary_with_credit_flow`, not by `SubmitResumeToTextract`.

## Terminal states / dead ends on this slice

- **Happy path:** controller → job → SubmitResumeToTextract (new in_progress TextractResult, old summaries staled, status row untouched) → +2min poll → text saved → `queue_ai_summary_job` → (status row → `regenerating`) → pipeline → new summary `succeeded` → status row → `current` with fresh denormalized data. RESTING: `current`.
- **Dead end (AWS failure, B8):** TextractResult → `failed`, `GetResumeTextFromTextractJob` never enqueued (it's after `.save`), no actor advances the status row. If a generate attempt had set it `regenerating`, it stays `regenerating` with no clearing actor. Also matches map Gap 4.
- **Dead end (auto-generate disabled):** after Textract completes with no waiting `textract_processing` summary, `queue_ai_summary_job` else branch returns unless `should_auto_generate_ai_summaries?` (`textract_result.rb:138`). If disabled, NO generation runs — status row stays `current` with the OLD (now-stale) summary's data; the staled summaries (B2) are never regenerated by this path. Resting at `current`/stale.

---

## Record-write sites found on this slice (file:line, literal, column, update-vs-update_columns)

1. `app/controllers/api/v1/job_applications_controller.rb:107` — `if job_application.update(temp_params)` — JobApplication: various permitted columns incl. `resume` attachment + `last_updated_by_organization_user_id` (line 97) — **update** (full callbacks).
2. `app/services/submit_resume_to_textract.rb:19` — `@job_application.ai_job_application_summaries.update_all(stale: true)` — AiJobApplicationSummary.`stale` — **update_all** (callback-bypassing, conditional on line 18).
3. `app/services/submit_resume_to_textract.rb:24` — `@textract_result.save` (built line 22 with `textract_job_id`, `textract_job_status: 'in_progress'`) — TextractResult.`textract_job_id`, `.textract_job_status` — **save/create** (fires `queue_ai_summary_job` after_commit on: :create — guard `textract_job_result_text.present?` is false here, returns early).
4. `app/services/submit_resume_to_textract.rb:26` — `waiting_summary&.update_columns(textract_result_id: @textract_result.id)` — AiJobApplicationSummary.`textract_result_id` — **update_columns** (typically no-op on replacement path; waiting_summary nil).
5. `app/services/submit_resume_to_textract.rb:33` — `@textract_result&.update_columns(textract_job_status: 'failed')` (InvalidS3ObjectException rescue) — TextractResult.`textract_job_status` — **update_columns**.
6. `app/services/submit_resume_to_textract.rb:39` — `@textract_result&.update_columns(textract_job_status: 'failed')` (StandardError rescue) — TextractResult.`textract_job_status` — **update_columns**.

**Downstream of this slice (post-Textract, fired by the new TextractResult — included for the status-row trace):**
7. `app/interactors/find_or_create_ai_job_application_summary_status.rb:15` — `@status_record.update_columns(status: 'regenerating')` — AiJobApplicationSummaryStatus.`status` — **update_columns** (the ONLY place `regenerating` is set; guarded on associated summary `status_succeeded?`).
8. `app/models/textract_result.rb:104-107` — `status_record.update_columns(ai_job_application_summary_id:, status: 'initial_summary_pending')` — AiJobApplicationSummaryStatus.`ai_job_application_summary_id`, `.status` — **update_columns** (guard line 102: only `none`/`initial_summary_pending`; no-op on replacement).
9. `app/models/ai_job_application_summary.rb:74-81` — `ai_job_application_summary_status.update_columns(ai_job_application_summary_id:, status: 'current', score_percentage:, headline:, integrated_role_analysis:, updated_at:)` — AiJobApplicationSummaryStatus denormalized columns — **update_columns** (fires when new summary reaches `succeeded`; closes the desync window).
