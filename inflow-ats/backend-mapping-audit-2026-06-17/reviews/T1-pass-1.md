# T1 — New Job Application Created → SubmitResumeToTextractJob → terminal TextractResult

**Slice:** T1
**Trigger:** `JobApplication after_commit :enqueue_new_job_application, on: [:create]`

## Files traced (chain)

`app/models/job_application.rb:45,164-171`
→ `app/interactors/find_or_create_ai_job_application_summary_status.rb` (whole file)
→ `app/jobs/submit_resume_to_textract_job.rb` (whole file)
→ `app/services/submit_resume_to_textract.rb` (whole file)
→ `app/jobs/get_resume_text_from_textract_job.rb` (whole file)
→ `app/services/get_resume_text_from_textract.rb` (whole file)
→ `app/models/textract_result.rb:1-14` (assoc + enum + callback registration)
→ `app/errors/custom_error_textract.rb:3`
Also read for cross-checks: `app/controllers/api/v1/job_applications_controller.rb:105-124` (controller-update Flipper site), `app/models/job_application.rb:83-91` (created_via enum), `app/models/job_application.rb:395-401` (clone created_via), `app/models/ai_job_application_summary_status.rb` (status enum), `app/models/job_application.rb:589` (has_resume).

---

## Behaviors

### B1 — The on-create callback registration

(a) Current code: `app/models/job_application.rb:45` — `after_commit :enqueue_new_job_application, on: [:create]`
(b) Map: line 70 says `app/models/job_application.rb:150-156`; line 68 `JobApplication after_commit(:enqueue_new_job_application, on: :create)`
(c) Verdict: **MAP-WRONG** (line numbers stale: callback is at :45, body at :164-171, not 150-156).
(d) Map text: "Registered at `app/models/job_application.rb:45`; body `enqueue_new_job_application` at lines 164-171."

### B2 — What the callback body enqueues

(a) Current code `app/models/job_application.rb:164-171`:
```
def enqueue_new_job_application
  NewJobApplicationJob.perform_later(id) # calls handle_new_job_application
  DocxToPdfJob.perform_later(id)
  if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)
    SubmitResumeToTextractJob.perform_later(id)
  end
  find_or_create_ai_job_application_summary_status
end
```
(b) Map line 74: "Also enqueues: `NewJobApplicationJob`, `DocxToPdfJob`". Map does NOT mention `find_or_create_ai_job_application_summary_status`.
(c) Verdict: **CHANGED / NEW** — `find_or_create_ai_job_application_summary_status` (line 170) is a new call in the callback, absent from map. This is the unconditional eager-creation of the `AiJobApplicationSummaryStatus` row at job-application creation (per CLAUDE.md rule 16: created via the unconditional owner).
(d) Map text: "`enqueue_new_job_application` enqueues `NewJobApplicationJob.perform_later(id)`, `DocxToPdfJob.perform_later(id)`, then (Flipper-gated) `SubmitResumeToTextractJob.perform_later(id)`, then UNCONDITIONALLY calls `find_or_create_ai_job_application_summary_status` (line 170) → `FindOrCreateAiJobApplicationSummaryStatus.call(job_application: self)`. The status-record creation is NOT gated by the Flipper and runs for every created job_application."

### B3 — Flipper gate TEXTRACT_RESUME_PROCESSING

(a) Current code: `app/models/job_application.rb:167` — `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)`. Only the `SubmitResumeToTextractJob.perform_later(id)` enqueue (line 168) is inside this guard. Scoped to `job.organization`. The ONLY other check in the entire app/ is `app/controllers/api/v1/job_applications_controller.rb:113` (`Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, current_organization)`), gating `SubmitResumeToTextractJob.perform_later(job_application.id)` on the resume-replacement update path. grep of app/ config/ lib/ db/ returns exactly these two sites.
(b) Map lines 72, 666: "Guards: `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)`"; gate table "Checked Where: `enqueue_new_job_application`, controller update."
(c) Verdict: **CONFIRMED**.
(d) Map text: "`TEXTRACT_RESUME_PROCESSING` (Flipper, per-organization). Checked at exactly two sites: `job_application.rb:167` (gates only the `SubmitResumeToTextractJob` enqueue inside `enqueue_new_job_application`) and `job_applications_controller.rb:113` (resume-replacement update). When disabled, only the Textract enqueue is skipped; `NewJobApplicationJob`, `DocxToPdfJob`, and `find_or_create_ai_job_application_summary_status` still run."

### B4 — Job-application creation sources reaching this callback

(a) Current code: `after_commit ... on: [:create]` fires on every JobApplication insert regardless of source. `created_via` enum `app/models/job_application.rb:83-91`: `created_via_manual_add(0)`, `created_via_job_board(1)`, `created_via_api(2)`, `created_via_referral(3)`, `created_via_bulk_manual_add(4)`, `created_via_clone(5)`, `created_via_customer_api_apply(6)`, `created_via_customer_api_import(7)`. Clone path sets `created_via = 'created_via_clone'` at line 400 and attaches the blob (`resume.attach(resume.blob) if has_resume`, line 401), then the cloned record is saved → callback fires.
(b) Map lines 76-83 list: external job board, internal manual, customer API apply, customer API import, CSV bulk import, clone to job.
(c) Verdict: **CONFIRMED / CHANGED** — every `created_via` value triggers the callback (it is `on: :create`, source-agnostic). Map's prose list is incomplete vs the enum: it omits `created_via_api` (2) and `created_via_referral` (3) as named sources, and the map labels CSV as `created_via_bulk_manual_add` implicitly. The behavior (fires for all) is CONFIRMED; the enumeration should be updated to the full 8-value enum.
(d) Map text: "Fires on ANY JobApplication insert (`on: [:create]`), source-agnostic. The `created_via` enum has 8 values (manual_add, job_board, api, referral, bulk_manual_add, clone, customer_api_apply, customer_api_import); all reach this callback. has_resume is what determines whether Textract actually proceeds, not created_via."

### B5 — SubmitResumeToTextract has_resume guard / branch

(a) Current code `app/services/submit_resume_to_textract.rb:9-10`:
```
return 'JobApplication not found' unless @job_application
return 'No resume attached' unless @job_application.has_resume
```
`has_resume` defined at `app/models/job_application.rb:589` (purges corrupted non-DOCUMENT_CONTENT_TYPES files). If no resume, the service returns before creating any TextractResult — so CSV-import / external-URL-only records that have no attached blob at creation never produce a TextractResult on this path.
(b) Map lines 36, 123: "Guard: returns early if job_application not found or has no resume (lines 9-10)"; "Has no resume at creation — Textract exits early."
(c) Verdict: **CONFIRMED**.
(d) Map text: "SubmitResumeToTextract guards `unless @job_application` then `unless @job_application.has_resume` (lines 9-10). No-resume job_applications produce NO TextractResult — terminal: no TextractResult ever created (dead end for Textract on this path until a later trigger attaches a resume and re-submits)."

### B6 — Branch: no usable Textract vs Textract ready (for T1)

(a) For T1 there is never a pre-existing usable TextractResult at create time — the callback is what FIRST submits the resume. `SubmitResumeToTextract` always `build`s a NEW `TextractResult` (`textract_job_status: 'in_progress'`, line 22) and schedules polling. There is no AiJobApplicationSummary in the T1 flow yet (T1 only does Textract + the status-record), so the "summary goes to textract_processing and waits" branch is NOT exercised by T1 itself — the `waiting_summary` lookup at line 25 (`find_by(status: :textract_processing, stale: false, textract_result_id: nil)`) returns nil on a brand-new application and `update_columns` is a no-op via `&.`.
(b) Map line 40: "On save: finds any `AiJobApplicationSummary` with `status: :textract_processing` ... and calls `update_columns(textract_result_id: ...)`".
(c) Verdict: **CONFIRMED** (branch is present; for T1 it is a no-op because no waiting summary exists yet — the textract_processing branch is reached only on Triggers C/D/E, not on a fresh create).
(d) Map text: "On the T1 (new-application) path there is no waiting summary, so `waiting_summary&.update_columns(...)` (lines 25-26) is a no-op. T1 always creates a fresh `in_progress` TextractResult and goes straight to polling."

### B7 — Stale-marking on submit

(a) Current code `app/services/submit_resume_to_textract.rb:18-20`:
```
unless @job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).exists?
  @job_application.ai_job_application_summaries.update_all(stale: true)
end
```
On a fresh T1 application there are zero summaries, so `.exists?` is false → `update_all(stale: true)` runs against an empty relation (no-op).
(b) Map lines 38, 587-589: conditional stale marking via update_all.
(c) Verdict: **CONFIRMED** (no-op for T1 — no summaries exist yet).
(d) Map text: "Stale-marking block (lines 18-20) is a no-op for T1 (no summaries exist on a new application)."

### B8 — TextractResult creation (in_progress) + polling schedule

(a) Current code `app/services/submit_resume_to_textract.rb:22-27`:
```
@textract_result = @job_application.textract_results.build(textract_job_id: textract.job_id, textract_job_status: 'in_progress')
if @textract_result.save
  waiting_summary = ...find_by(status: :textract_processing, stale: false, textract_result_id: nil)
  waiting_summary&.update_columns(textract_result_id: @textract_result.id)
  GetResumeTextFromTextractJob.set(wait: 2.minutes).perform_later(@job_application.id)
```
TextractResult enum confirmed `app/models/textract_result.rb:9-14`: `not_started(0), in_progress(1), succeeded(2), failed(3)`, `_prefix: true`. On save, `after_commit :queue_ai_summary_job, on: [:create, :update]` (textract_result.rb:7) fires — but text is absent at this point so it returns early (handled by slice covering the callback; out of T1 scope).
(b) Map lines 39, 41: "Creates new TextractResult ... status `in_progress`"; "Schedules `GetResumeTextFromTextractJob` with 2-minute delay."
(c) Verdict: **CONFIRMED**.
(d) Map text: "Creates `TextractResult` with `textract_job_status: 'in_progress'` (build+save, line 22). On save schedules `GetResumeTextFromTextractJob.set(wait: 2.minutes).perform_later(job_application.id)`."

### B9 — AWS-submit failure branch

(a) Current code `app/services/submit_resume_to_textract.rb:30-41`: `rescue Aws::Textract::Errors::InvalidS3ObjectException` AND `rescue StandardError` both do `@textract_result&.update_columns(textract_job_status: 'failed')`. Because `@textract_result` is only assigned after the AWS `send_to_textract` call (line 16) succeeds, if the AWS call itself raises, `@textract_result` is nil and `&.` makes the failed-marking a no-op → NO TextractResult exists. The polling job is never scheduled (it's only scheduled inside `if @textract_result.save`).
(b) Map lines 42, 629-630 (Gap 4): "On AWS errors: sets TextractResult status to `failed` via `update_columns`"; Gap 4 notes orphaned summary, but T1 has no summary.
(c) Verdict: **CONFIRMED** (with T1 nuance: no summary to orphan; the failure simply leaves no TextractResult and no scheduled poll).
(d) Map text: "If `send_to_textract` raises, `@textract_result` is nil → `update_columns('failed')` is a no-op via `&.`; no TextractResult is created and no polling job is scheduled. **Dead end for T1: Textract silently does nothing, no record, no retry.**"

### B10 — Terminal TextractResult states (polling)

(a) Current code `app/services/get_resume_text_from_textract.rb`:
- Most-recent TextractResult fetched line 11 (`order(created_at: :desc).first`).
- Self-heal: if `textract_job_id.nil?` (line 14) re-enqueues `SubmitResumeToTextractJob` and returns (line 15-16).
- AWS `succeeded` (line 23): `@textract_result.update(textract_job_status:'succeeded', textract_job_result:, textract_job_result_text:)` (lines 30) — **TERMINAL succeeded**; fires `queue_ai_summary_job` (the bridge). If `update` returns false, logs error, stays `in_progress` (**stuck — no retry, dead end**, map Gap 5).
- AWS `failed` (line 37): `update_columns(textract_job_status: 'failed')` then `raise CustomErrorTextract` → retry.
- else (still processing): `raise CustomErrorTextract` → retry.
- `rescue Aws::Textract::Errors::InvalidJobIdException` (line 45): `update_columns(textract_job_status:'failed', textract_job_id: nil)` — **TERMINAL failed** (no raise → no retry).
Polling job `app/jobs/get_resume_text_from_textract_job.rb:6`: `retry_on CustomErrorTextract, wait: 5.minutes, attempts: 3`. Exhaustion block (lines 6-8) calls `cleanup_orphaned_summary` → finds `textract_processing` summary (none in T1), destroys it, broadcasts `AI_SUMMARY_FAILED`. The failed/stuck TextractResult is left intact.
(b) Map lines 44-61, 575-583: matches.
(c) Verdict: **CONFIRMED**.
(d) Map text: "Terminal TextractResult states reachable from T1: **succeeded** (text saved via `update`, line 30; fires the AI-summary bridge callback); **failed** (AWS-failed branch `update_columns` line 39, or InvalidJobIdException `update_columns` line 47); **stuck in_progress** if AWS `update` fails (line 32-35, no retry — dead end, Gap 5) or AWS stays processing past 3 retries (each retry waits 5 min; total window ≈ 2 + 3×5 = 17 min, then exhaustion runs `cleanup_orphaned_summary` — a no-op for T1 since no summary exists, leaving the in_progress TextractResult with no further actor)."

---

## Desync window (AiJobApplicationSummaryStatus)

T1 creates the `AiJobApplicationSummaryStatus` row eagerly at job-application creation via `find_or_create_ai_job_application_summary_status` (job_application.rb:170). On the T1 fresh-create path, `FindOrCreateAiJobApplicationSummaryStatus` takes the else-branch (no existing record): since there is no `latest_ai_job_application_summary`, it sets `status = 'none'` (interactor line 33) and saves. The denormalized columns (`ai_job_application_summary_id`, `score_percentage`, `headline`, `integrated_role_analysis`) are left nil. This status row then sits at `status_none` while Textract runs and (if auto-generate is on) a summary is later produced by a different slice. **Window:** between T1's status-row creation (`none`) and the eventual `update_summary_status_record`/interactor update when a summary succeeds, the status row reports `none` even though a TextractResult is in_progress and a summary may be mid-pipeline — the list view shows no AI activity during this entire window.

---

## All record-write sites on the T1 slice

| file:line | literal | column(s) | op |
|---|---|---|---|
| app/models/job_application.rb:168 | `SubmitResumeToTextractJob.perform_later(id)` | (enqueue, no write) | enqueue |
| app/interactors/find_or_create_ai_job_application_summary_status.rb:38 | `@status_record.save` (else-branch new record, status 'none' for T1) | AiJobApplicationSummaryStatus: status, job_application_id | save (INSERT) |
| app/interactors/find_or_create_ai_job_application_summary_status.rb:15 | `@status_record.update_columns(status: 'regenerating')` (not hit on T1 fresh create) | AiJobApplicationSummaryStatus.status | update_columns |
| app/services/submit_resume_to_textract.rb:19 | `@job_application.ai_job_application_summaries.update_all(stale: true)` (no-op for T1) | AiJobApplicationSummary.stale | update_all |
| app/services/submit_resume_to_textract.rb:22-23 | `textract_results.build(... 'in_progress').save` | TextractResult: textract_job_id, textract_job_status, job_application_id | save (INSERT) |
| app/services/submit_resume_to_textract.rb:26 | `waiting_summary&.update_columns(textract_result_id: @textract_result.id)` (no-op for T1) | AiJobApplicationSummary.textract_result_id | update_columns |
| app/services/submit_resume_to_textract.rb:33 / :39 | `@textract_result&.update_columns(textract_job_status: 'failed')` | TextractResult.textract_job_status | update_columns |
| app/services/get_resume_text_from_textract.rb:31 | `@textract_result.update(update_textract_params)` | TextractResult: textract_job_status, textract_job_result, textract_job_result_text | update |
| app/services/get_resume_text_from_textract.rb:39 | `@textract_result.update_columns(textract_job_status: 'failed')` | TextractResult.textract_job_status | update_columns |
| app/services/get_resume_text_from_textract.rb:46 | `@textract_result.update_columns(textract_job_status: 'failed', textract_job_id: nil)` | TextractResult: textract_job_status, textract_job_id | update_columns |
