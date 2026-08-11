# T6 — CSV Bulk Import (external_resume_url, no resume file at creation): Textract Trace to Terminal

**Slice:** T6 — CSV bulk import. Trace what happens regarding Textract for imported rows, to a terminal state.

**Files traced (chain):**
`app/jobs/import_job_candidates_from_csv_job.rb:14` → `app/interactors/create_candidate_job_application.rb:6-37` → `app/models/job_application.rb:45` (`after_commit :enqueue_new_job_application`) → `app/models/job_application.rb:164-171` → `app/services/submit_resume_to_textract.rb:8-10` (EARLY EXIT) → `app/interactors/find_or_create_ai_job_application_summary_status.rb:6-45` → (separately, on later page view) `app/controllers/api/v1/job_applications_controller.rb:56-59` → `app/jobs/job_application/attach_external_resume_url_job.rb:9` → `app/models/job_application.rb:641-657` (`attach_external_resume_url`) → `app/models/job_application.rb:709-711` (`should_attach_external_resume_url?`).

---

## Behavior 1 — CSV import builds job_application with external_resume_url + external_resume_status: pending, NO resume file attached

**Current code:**
`app/jobs/import_job_candidates_from_csv_job.rb:14-22`:
```ruby
result = CreateCandidateJobApplication.call(
  job: job,
  candidate_data: { ... },
  job_application_data: { last_updated_by_organization_user_id: organization_user_id, hiring_stage_id: hiring_stage_id,
                          external_resume_url: record['Resume URL'], created_via: :created_via_bulk_manual_add,
                          external_resume_status: record['Resume URL'].nil? ? nil : :pending, source: record['Source'] },
)
```
Note: `CreateCandidateJobApplication.call` is invoked **without** a `resume_url:` key. In `create_candidate_job_application.rb:10` `@resume_url = context.resume_url` is therefore `nil`, so `create_candidate_job_application.rb:24` `attach_resume_url unless @resume_url.blank?` is SKIPPED. No file is attached at creation. `external_resume_url` is stored on the row; `external_resume_status` is set to `:pending` when a Resume URL is present (else nil).

**Map says:** Trigger 6 / Part 7 row 6 (lines 118-124, 686): "Resume source: `external_resume_url` stored on job_application, NOT immediately attached / `external_resume_status: :pending` — resume not yet downloaded / Textract fires on job_application creation, but `has_resume` is false → SubmitResumeToTextract returns early."

**Verdict:** CONFIRMED.

**Map text to write:** keep as-is. Add anchor: set in `ImportJobCandidatesFromCsvJob#perform` at `import_job_candidates_from_csv_job.rb:20-21` (`external_resume_url: record['Resume URL']`, `external_resume_status: record['Resume URL'].nil? ? nil : :pending`); `CreateCandidateJobApplication` is called without `resume_url:`, so its `attach_resume_url` (`create_candidate_job_application.rb:34-37`) never runs — no file at creation.

---

## Behavior 2 — Creation fires after_commit :enqueue_new_job_application, which enqueues SubmitResumeToTextractJob (flipper-gated) and find_or_create_ai_job_application_summary_status

**Current code:**
`create_candidate_job_application.rb:27` `context.fail!(error: @candidate) unless @candidate.save` saves the candidate (building the job_application). On the job_application, `app/models/job_application.rb:45` `after_commit :enqueue_new_job_application, on: [:create]` fires.

`app/models/job_application.rb:164-171`:
```ruby
def enqueue_new_job_application
  NewJobApplicationJob.perform_later(id)
  DocxToPdfJob.perform_later(id)
  if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)
    SubmitResumeToTextractJob.perform_later(id)
  end
  find_or_create_ai_job_application_summary_status
end
```
So a CSV-imported row enqueues `SubmitResumeToTextractJob` (if `TEXTRACT_RESUME_PROCESSING` enabled), plus `NewJobApplicationJob`, `DocxToPdfJob`, and calls `find_or_create_ai_job_application_summary_status`.

**Map says:** lines 67-83 (Trigger 1) "Fires on ANY new job_application creation (all sources)... Also enqueues: NewJobApplicationJob, DocxToPdfJob." Lists "CSV bulk import" among sources.

**Verdict:** CHANGED. The map's `enqueue_new_job_application` description (lines 67-83) omits the `find_or_create_ai_job_application_summary_status` call at `job_application.rb:170`. The map nowhere documents that creation of ANY job_application (including CSV-imported rows) eagerly creates the `AiJobApplicationSummaryStatus` row.

**Map text to write:** In Trigger 1, add: `enqueue_new_job_application` (`job_application.rb:164-171`) also calls `find_or_create_ai_job_application_summary_status` (`job_application.rb:160-162` → `FindOrCreateAiJobApplicationSummaryStatus`), which eagerly creates the one-per-job_application status row for every newly created job_application, CSV-imported rows included.

---

## Behavior 3 — SubmitResumeToTextract exits early because has_resume is false (no TextractResult ever created for the imported row at this stage)

**Current code:**
`app/services/submit_resume_to_textract.rb:8-10`:
```ruby
def submit_resume
  return 'JobApplication not found' unless @job_application
  return 'No resume attached' unless @job_application.has_resume
```
For a CSV-imported row, no resume is attached (Behavior 1), so `has_resume` (`job_application.rb:589-602`, `resume.attached?`) is false. `submit_resume` returns `'No resume attached'` at line 10 BEFORE building any TextractResult (`submit_resume_to_textract.rb:22` never reached). No `TextractResult` row is created. `textract_job_status` enum is untouched (no record). No `GetResumeTextFromTextractJob` is scheduled (`submit_resume_to_textract.rb:27` not reached).

**Map says:** line 123 / 686: "Textract fires on job_application creation, but `has_resume` is false → SubmitResumeToTextract returns early."

**Verdict:** CONFIRMED.

**Map text to write:** keep. Add anchor: early return at `submit_resume_to_textract.rb:10` (`return 'No resume attached' unless @job_application.has_resume`); the TextractResult build at `submit_resume_to_textract.rb:22` is never reached, so NO TextractResult is created for the CSV-imported row.

---

## Behavior 4 — The eagerly-created AiJobApplicationSummaryStatus row for the imported candidate is status: 'none'

**Current code:**
`app/interactors/find_or_create_ai_job_application_summary_status.rb:22-35` (else branch — no pre-existing status record, which is the case for a brand-new CSV row):
```ruby
latest_ai_job_application_summary = job_application.latest_ai_job_application_summary
@status_record = job_application.build_ai_job_application_summary_status
if latest_ai_job_application_summary&.status_succeeded? && !latest_ai_job_application_summary.stale?
  ...
else
  @status_record.status = 'none'
end
```
A CSV-imported candidate has no `AiJobApplicationSummary` yet, so `latest_ai_job_application_summary` is nil → `status = 'none'` (`find_or_create_ai_job_application_summary_status.rb:34`). The status enum (`app/models/ai_job_application_summary_status.rb:9-13`) is `{none: 0, initial_summary_pending: 1, current: 2, regenerating: 3}`. The row is saved at line 37 with denormalized columns (`ai_job_application_summary_id`, `score_percentage`, `headline`, `integrated_role_analysis`) all nil.

**Map says:** ABSENT from map. The map's AiJobApplicationSummaryStatus enum (lines 509-516) is documented WRONG as `{pending, textract_processing, extracting, summarizing, awaiting_job_criteria, scoring, integrating, succeeded, retrying, failed}` (that is the AiJobApplicationSummary enum, not this table's). The map never states the status row is created at job_application creation, nor that CSV rows land at `none`.

**Verdict:** MAP-WRONG (enum) + NEW (the `none` row creation on CSV import is undocumented).

**Map text to write:** Correct the AiJobApplicationSummaryStatus enum to `{none: 0, initial_summary_pending: 1, current: 2, regenerating: 3}` (`ai_job_application_summary_status.rb:9-13`). Add: for a CSV-imported row (no resume, no summary), `FindOrCreateAiJobApplicationSummaryStatus` creates the status row with `status: 'none'` and all denormalized columns nil (`find_or_create_ai_job_application_summary_status.rb:25,34,37`).

---

## Behavior 5 — Lazy resume download on page view (AttachExternalResumeUrlJob); Textract is NOT triggered after attachment

**Current code:**
`app/controllers/api/v1/job_applications_controller.rb:56-59` (show action):
```ruby
if @job_application = current_organization.job_applications.includes(:ai_job_application_summary_status).find_by(id_or_hash_id(params[:id]))
  authorize @job_application
  JobApplication::AttachExternalResumeUrlJob.perform_later(organization_user_id: current_organization_user.id,
                                                           job_application_id: params[:id]) if @job_application.should_attach_external_resume_url?
```
`should_attach_external_resume_url?` (`job_application.rb:709-711`): `external_resume_status_pending? && !has_resume` — true for the CSV-imported pending row.

`app/jobs/job_application/attach_external_resume_url_job.rb:9` calls `@job_application.attach_external_resume_url`.

`app/models/job_application.rb:641-657`:
```ruby
def attach_external_resume_url
  return unless should_attach_external_resume_url?
  begin
    downloaded_resume = URI.open(external_resume_url)
    if downloaded_resume.content_type == 'application/pdf'
      resume.attach(io: downloaded_resume, filename: 'resume.pdf')
      update_column(:external_resume_status, :uploaded)
    else
      update_column(:external_resume_status, :error)
    end
  rescue StandardError => e
    update_column(:external_resume_status, :error)
    Rails.logger.error e
  end
end
```
The resume is attached and `external_resume_status` set to `uploaded` (PDF) or `error` (non-PDF / exception) via `update_column` (`job_application.rb:649,651,654`) — which skips validations AND callbacks. There is NO `SubmitResumeToTextractJob` enqueued anywhere in this path. `attach_external_resume_url_job.rb` only broadcasts `attachExternalResumeComplete` (line 11-12). **Textract is NOT triggered after the resume is attached.**

**Map says:** lines 126-134 (Trigger 7) and Gap 1 (lines 611-616): "Uses `update_column(:external_resume_status, :uploaded)` — no callbacks / TEXTRACT IS NOT TRIGGERED after this attachment / Gap: candidates from CSV import with external URLs never get Textract processing automatically." Part 7 row 7 (line 687): "Textract NOT triggered."

**Verdict:** CONFIRMED. (Minor: map line 132 cites only the `:uploaded` update_column path; the code also has a `:error` branch at `job_application.rb:651,654` — both use `update_column`, both skip callbacks, neither triggers Textract.)

**Map text to write:** keep Trigger 7 / Gap 1. Add: the job is enqueued only from the controller `show` action (`job_applications_controller.rb:58-59`) when `should_attach_external_resume_url?` (`job_application.rb:709-711`: `external_resume_status_pending? && !has_resume`). `attach_external_resume_url` (`job_application.rb:641-657`) sets `external_resume_status` to `:uploaded` (PDF), or `:error` (non-PDF content type or rescued StandardError), all via `update_column` — callbacks skipped, no Textract enqueued in any branch.

---

## TERMINAL STATE for the T6 slice (Textract)

For a CSV-imported row, regarding Textract there are TWO terminal resting points, and BOTH are dead ends with respect to Textract:

1. **At creation (T6 entry):** `enqueue_new_job_application` → `SubmitResumeToTextractJob` → `SubmitResumeToTextract#submit_resume` returns `'No resume attached'` at `submit_resume_to_textract.rb:10`. **Terminal:** no TextractResult exists. No actor re-enqueues Textract. The `AiJobApplicationSummaryStatus` row rests at `status: 'none'`. **DEAD END** — there is NO Textract record and no advancing actor.

2. **After lazy download (page view):** `AttachExternalResumeUrlJob` attaches the resume and sets `external_resume_status` to `:uploaded`/`:error` via `update_column` (`job_application.rb:649,651,654`). `update_column` fires NO callbacks. **Terminal:** the row now `has_resume` but still has NO TextractResult, and no code path enqueues `SubmitResumeToTextractJob` after the attach. **DEAD END for Textract** — the resume sits attached with no OCR.

The only ways Textract is ever run for such a row are OUT-OF-SLICE backfills not on the T6 import path: bulk AI summary (`QueueBulkAiSummaryJobs`, map Trigger 8) which kicks Textract for `with_resume` but no `with_textract_results`, or manual generate (`ValidateAiSummaryGeneration`, map Trigger 9) which kicks Textract when `latest_textract_result` is nil. Neither is automatic; both require a separate user/bulk action.

---

## Branch taken on this slice (the textract_processing vs textract-ready branch)

T6 never enters the AI-pipeline branch selection, because no `AiJobApplicationSummary` is created on the import path. The summary status row is `none` (not `textract_processing`). The "go to textract_processing and wait" vs "Textract ready, move into AI pipeline" branch (which lives in `ValidateAiSummaryGeneration` / `CreateAiSummaryGeneration` and the `TextractResult` callback) is only reached if a separate trigger (manual generate Trigger 9 / A, or bulk Trigger 8 / B) is later invoked on the imported candidate. On the pure T6 import path, neither branch is taken.

---

## Write sites found on the T6 slice

| File:line | Literal | Column(s) | update vs update_columns |
|---|---|---|---|
| `app/jobs/import_job_candidates_from_csv_job.rb:20-21` | `external_resume_url: record['Resume URL']`, `external_resume_status: record['Resume URL'].nil? ? nil : :pending` (assigned into `job_application_data`) | `external_resume_url`, `external_resume_status` (+ candidate/job_application attrs) | via `@candidate.save` (`create_candidate_job_application.rb:27`) — full `save`, fires callbacks |
| `app/interactors/find_or_create_ai_job_application_summary_status.rb:25,34,37` | `@status_record = job_application.build_ai_job_application_summary_status`; `@status_record.status = 'none'`; `@status_record.save` | `AiJobApplicationSummaryStatus`: `status` (='none'), `job_application_id`; denormalized cols left nil | `save` (validations run) |
| `app/models/job_application.rb:648` | `resume.attach(io: downloaded_resume, filename: 'resume.pdf')` | ActiveStorage `resume` attachment | `attach` (ActiveStorage; no AR dirty callback) |
| `app/models/job_application.rb:649` | `update_column(:external_resume_status, :uploaded)` | `external_resume_status` | **update_column** (no callbacks/validations) |
| `app/models/job_application.rb:651` | `update_column(:external_resume_status, :error)` | `external_resume_status` | **update_column** |
| `app/models/job_application.rb:654` | `update_column(:external_resume_status, :error)` | `external_resume_status` | **update_column** |

No `TextractResult` write site exists on the T6 slice (the build at `submit_resume_to_textract.rb:22` is never reached for imported rows).
