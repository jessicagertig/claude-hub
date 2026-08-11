# Textract & AI Summary Flows — Code Map

**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`
**Scope:** Every code path for Textract resume processing and AI applicant summary generation, from trigger to the record states each path produces. `file:line` are current code positions, verified across multiple trace passes.

This is a reference for working in the code: it describes what the code does and how the four records move between states. State-machine resting/terminal properties are stated as neutral graph facts (a state is "resting" when no further actor advances it within a given path); they are not findings.

---

## Overview

Two flows are described, and they are connected:

- **Textract resume processing** extracts text from a resume via AWS Textract and records it on a `TextractResult`.
- **AI applicant summary generation** consumes that text through a multi-stage AI pipeline (4 summary calls + 1-5 scoring calls + 1 display call + 1 integration call) to produce an `AiJobApplicationSummary`.

The bridge between them is `TextractResult#queue_ai_summary_job`, an `after_commit on: [:create, :update]` callback (`textract_result.rb:7`). When a `TextractResult` is updated with extracted text, this callback either advances an already-waiting summary or enqueues an auto-generation job, depending on the job_application's current summary state. See **The bridge**.

A fourth record, `AiJobApplicationSummaryStatus`, is a 4-value display-state record (`none`/`initial_summary_pending`/`current`/`regenerating`) owned one-per-`JobApplication`. It backs the job-applications list fit indicator and the detail-view Plato card. It is created and advanced by the `FindOrCreateAiJobApplicationSummaryStatus` interactor, the `TextractResult#set_initial_summary_pending` helper, and the `AiJobApplicationSummary#update_summary_status_record` callback. See **AiJobApplicationSummaryStatus**.

---

## Data models

### TextractResult
**File:** `app/models/textract_result.rb`

```
belongs_to :job_application
has_many :ai_job_application_summaries, inverse_of: :textract_result, dependent: :destroy   (textract_result.rb:5)
after_commit :queue_ai_summary_job, on: [:create, :update]                                  (textract_result.rb:7)

enum textract_job_status: { not_started: 0, in_progress: 1, succeeded: 2, failed: 3 }, _prefix: true
Columns: textract_job_id, textract_job_status, textract_job_result (jsonb),
         textract_job_result_text, job_application_id
```

`JobApplication has_many :textract_results, dependent: :destroy`. A job_application may have multiple `TextractResult` records; "one effective" result is maintained by staling summaries and by `destroy_previous_textract_results`.

Scope distinction (load-bearing for the auto/handoff paths):
- `self.ai_job_application_summaries` (the `TextractResult`'s own `has_many`, read at `textract_result.rb:77`) is scoped to one result and is empty on a freshly built result.
- `job_application.ai_job_application_summaries` (read at `orchestrate.rb:15`) spans all of the job_application's results.

### AiJobApplicationSummary
**File:** `app/models/ai_job_application_summary.rb`

```
belongs_to :job_application
belongs_to :textract_result, optional: true
has_many :ai_api_requests, as: :requestable
has_one :ai_job_application_summary_status                                                   (:8)

enum status: { pending:0, textract_processing:1, extracting:2, summarizing:3,
               awaiting_job_criteria:4, scoring:5, integrating:6, succeeded:7,
               retrying:8, failed:9 }, _prefix: true
BROADCAST_STATUSES = %w[pending textract_processing extracting summarizing scoring integrating succeeded failed]
   (:23 — omits awaiting_job_criteria and retrying)

Columns: structured_data, headline, summary_text, score_percentage, criteria_results,
         integrated_role_analysis, status, error_message, stale (boolean default false),
         job_application_id, textract_result_id (nullable), requested_by_organization_user_id
```

**Callbacks:**
- `after_commit :destroy_previous_textract_results, on: :update` (`:29`) — on a `→succeeded` transition (guard `:48` `return unless textract_result`, `:49` `saved_change_to_status? && status_succeeded?`), `destroy_all`s the job_application's earlier non-succeeded `TextractResult` records older than the firing result (`:47-55`, `:51-54`).
- `after_commit :update_summary_status_record, on: :update` (`:30`) — method def at `:57` (`ap` debug lines `:58-67`); guard `:69` `saved_change_to_status? && status_succeeded?`; early return if the status row does not exist (`:72`); writes `ai_job_application_summary_status.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)` (`:74-80`); then broadcasts JobChannel `ai_summary_succeeded` (`:93-97`). Uses `.update` (validations, callbacks, counter_culture fire). Writes `ai_job_application_summary_id: id` unconditionally, re-pointing the status row regardless of its prior pointer. Registered `on: :update` only; a summary created already-`succeeded` would not fire it — the pipeline reaches `succeeded` via `.update`, never via create.
- `before_update :broadcast_status_change` (`:31`) — JobChannel `ai_summary_status_change`, only for `BROADCAST_STATUSES` (`:100-102` `return unless included`).

There is no `create_status_record` callback on this model.

### AiJobApplicationSummaryStatus
**File:** `app/models/ai_job_application_summary_status.rb`; migration `db/migrate/20260611120001_create_ai_job_application_summary_statuses.rb`; schema `db/schema.rb:168-179`

```
belongs_to :job_application
belongs_to :ai_job_application_summary, optional: true

enum status: { none: 0, initial_summary_pending: 1, current: 2, regenerating: 3 }, _prefix: true   # 4 values
Columns: job_application_id (null:false), ai_job_application_summary_id (nullable),
         status (int default 0 null:false), score_percentage (decimal),
         headline (string), integrated_role_analysis (text), timestamps
   # `regenerating` is status value 3 — there is no separate `regenerating` boolean column

validates :job_application_id, uniqueness: true   # one row per job_application
```

`counter_culture [:job_application, :job]` (`:7`) rolls into `jobs.ai_job_application_summaries_count`, counting status rows where `status IN (2,3)` (current/regenerating). The literal has two halves: a `column_name` proc that makes a row contribute only while `current`/`regenerating`, and a `column_names` clause `['ai_job_application_summary_statuses.status IN (?)', [2, 3]]`. The backing column `jobs.ai_job_application_summaries_count` is present in committed `db/schema.rb:907` (schema version `2026_06_22_182504`, added by `20260622182504_add_ai_summary_and_criteria_columns_to_jobs.rb`, which also adds `ai_job_criteria_generations_count` `:908` and `internal_job_criteria` `:909`). `counter_culture` is this model's sole callback-bearing behavior; it has no own `after_`/`before_` callbacks.

Scopes: role-fit bands `poor`/`weak`/`mixed`/`good`/`excellent` on `score_percentage` (`:20-24`).

DB indexes (`db/schema.rb`):
- `idx_ai_summary_statuses_on_job_application_id` (`unique:true`, `:178`) — backs the uniqueness validation and the `ActiveRecord::RecordNotUnique` rescue at `find_or_create_ai_job_application_summary_status.rb:43-44`.
- `idx_ai_summary_statuses_on_summary_id` on `ai_job_application_summary_id` (`:177`).

Associations on this row: it is the target of two `has_one`s — from `JobApplication` (`has_one :ai_job_application_summary_status`, no `dependent:` option; relies on the migration FK for delete behavior) and from `AiJobApplicationSummary` (`:8`). `update_summary_status_record` reaches the row via `job_application.ai_job_application_summary_status` (`:71`), not via `self.ai_job_application_summary_status`. `JobApplication#find_or_create_ai_job_application_summary_status` (`:160-162`) wraps the interactor.

### AiJobCriteria
**File:** `app/models/ai_job_criteria.rb`

```
belongs_to :job
enum status: { pending:0, in_progress:1, succeeded:2, failed:3, retrying:4 }
Columns: criteria (jsonb), status, metadata, error_message, job_id
after_commit :resume_waiting_summaries, on: [:update]   (:17; guard :22 saved_change_to_status? && status_succeeded?)
```

`succeeded` is the only status transition that fires the callback. The `succeeded` write uses `.update` deliberately (`extract_criteria.rb:132-140`, with an in-code comment to fire the callback); every other `AiJobCriteria` status write uses `update_columns`. `resume_waiting_summaries` re-enqueues `GenerateAiJobApplicationSummaryJob(textract_result_id:)` for each `awaiting_job_criteria` summary on the job, with no requesting user. See **AiJobCriteria re-trigger** for the full behavior.

`JobApplication` AI-related associations:
```
has_many :ai_job_application_summaries, dependent: :destroy
has_one :latest_ai_job_application_summary, -> { order(created_at: :desc) }   (:31)
has_one :ai_job_application_summary_status   (no dependent: option)
```

---

## Triggers T1-T9

Each trigger drives one entry path. Several share the `JobApplication after_commit :enqueue_new_job_application, on: [:create]` callback (registration `job_application.rb:45`; body `:164-171`), which enqueues `NewJobApplicationJob` (`:165`) and `DocxToPdfJob` (`:166`), then a `TEXTRACT_RESUME_PROCESSING`-gated (scoped to `job.organization`, `:167`) `SubmitResumeToTextractJob.perform_later(id)` (`:168`), then unconditionally `find_or_create_ai_job_application_summary_status` (`:170`). `DocxToPdfJob` produces `resume_docx_to_pdf`, which `SubmitResumeToTextract` prefers (`submit_resume_to_textract.rb:15`); both are `perform_later` with no ordering guarantee, so the Textract submit may run on the raw resume before the conversion lands.

The `TEXTRACT_RESUME_PROCESSING` Flipper flag is checked at exactly two app sites: `job_application.rb:167` (model callback — T1/T3/T4/T5/T6) and `job_applications_controller.rb:113` (controller `update` — T2). When the flag is OFF on a model-side path, `enqueue_new_job_application` does not enqueue `SubmitResumeToTextractJob`, so the in-service `has_resume` early-return at `submit_resume_to_textract.rb:10` is not reached at all; the outcome (no `TextractResult`) is reached by a different mechanism than the flag-ON no-resume case.

### Submission service: `SubmitResumeToTextract#submit_resume`
**File:** `app/services/submit_resume_to_textract.rb` (service class `SubmitResumeToTextract`, method `#submit_resume`; called by `SubmitResumeToTextractJob#perform` at `submit_resume_to_textract_job.rb:7-8`)

1. Guards: `return 'JobApplication not found' unless @job_application` (`:9`); `return 'No resume attached' unless @job_application.has_resume` (`:10`). When `has_resume` is false, the service returns before the build at `:22`, so no `TextractResult` is created.
2. Selects the resume file (`resume_docx_to_pdf` if available, else `resume`) and calls AWS Textract (`:15-16`).
3. Conditional stale-marking (`:18-20`): `unless @job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).exists?` → `@job_application.ai_job_application_summaries.update_all(stale: true)`. `update_all` bypasses callbacks and sets only `stale`; status is unchanged. When a non-stale `textract_processing` summary already exists, the `unless` is true and the `update_all` is skipped (the prior summaries keep `stale: false`).
4. Builds a new `TextractResult` with `textract_job_status: 'in_progress'` and saves (`:22-24`). The new result has zero associated summaries at this point.
5. On save: `waiting_summary = ...find_by(status: :textract_processing, stale: false, textract_result_id: nil)`; `waiting_summary&.update_columns(textract_result_id: @textract_result.id)` (`:25-26`) — relinks a `textract_processing` waiting summary onto the new result. This has no effect when there is no such waiting summary (fresh-create / replacement / clone / apply / import); a prior `succeeded` summary is not relinked.
6. Schedules `GetResumeTextFromTextractJob.set(wait: 2.minutes).perform_later(@job_application.id)` (`:27`), inside the `if @textract_result.save` block.
7. AWS errors: rescues `Aws::Textract::Errors::InvalidS3ObjectException` and `StandardError`, calling `@textract_result&.update_columns(textract_job_status: 'failed')` (`:31-40`, writes at `:33,:39`). When `parser.send_to_textract` (`:16`) raises before `@textract_result` is assigned, the `&.` makes this write have no effect, so no `TextractResult` is created and no poll job is scheduled. `SubmitResumeToTextractJob#perform` separately rescues `StandardError` and only `ap`s (`submit_resume_to_textract_job.rb:9-11`), so there is no job retry.

### Polling service: `GetResumeTextFromTextract#parse_resume_text`
**File:** `app/services/get_resume_text_from_textract.rb`

1. Finds the most recent `TextractResult` (`order(created_at: :desc).first`, `:11`).
2. Self-healing: when `textract_job_id` is nil, re-enqueues `SubmitResumeToTextractJob` and returns (`:14-17`).
3. Polls AWS (`:19-20`).
4. On success: `@textract_result.update(textract_job_status: <downcased AWS status>, textract_job_result:, textract_job_result_text:)` (`:24-29,:31`). This is the sole `.update` (callback-firing) write on `TextractResult`, and the only site writing both `textract_job_status` and `textract_job_result_text` in one call; its `saved_change_to_textract_job_result_text?` is what the bridge checks (`textract_result.rb:116`). It fires `after_commit :queue_ai_summary_job`.
5. AWS-failed: `update_columns(textract_job_status: 'failed')` (`:40`) then `raise CustomErrorTextract` (`:41`) → retry.
6. Other/still-processing: `raise CustomErrorTextract` without marking failed (else branch, `:44`) → retry.
7. `InvalidJobIdException`: `update_columns(textract_job_status: 'failed', textract_job_id: nil)` (`:46-47`), no raise. The result lands `failed` and `textract_job_id` is nil, so a subsequent poll re-enters the self-healing re-submit at `:14-17`.

### Polling job: `GetResumeTextFromTextractJob`
**File:** `app/jobs/get_resume_text_from_textract_job.rb`

Queue `:default`. `retry_on CustomErrorTextract, wait: 5.minutes, attempts: 3` (with the 2-minute initial delay, ~17 min total window). On retry exhaustion, `cleanup_orphaned_summary` (`:6-8`, def `:10-23`) finds the `textract_processing`/`stale:false` waiting summary (if any), destroys it, and broadcasts `AI_SUMMARY_FAILED` via `TextractResult#broadcast_ai_summary_failed`; it returns at `:16` (no write) when there is no such waiting summary. A `failed`/`in_progress` `TextractResult` is left intact.

### T1 — New Job Application Created
**Chain:** `JobApplication after_commit(:enqueue_new_job_application, on: [:create])` → `SubmitResumeToTextractJob`. Registration `job_application.rb:45`; body `:164-171`.

Fires on any new job_application insert, source-agnostic. `created_via` has 8 values (`created_via_manual_add:0, created_via_job_board:1, created_via_api:2, created_via_referral:3, created_via_bulk_manual_add:4, created_via_clone:5, created_via_customer_api_apply:6, created_via_customer_api_import:7`; `job_application.rb:83-91`); all 8 reach the callback (no `insert_all` bypass; public controllers assign `params[:created_via]` at `api/v1/public/jobs_controller.rb:38`). `enqueue_new_job_application` dereferences `job.organization` at `:167` to scope the Flipper check; a job_application always `belongs_to :job`.

- The status row is created unconditionally at `:170` (status `'none'` on a fresh app), not Flipper-gated.
- A `TextractResult` (`in_progress`) is created only when a resume is present at creation. With no resume, `SubmitResumeToTextract` returns `'No resume attached'` (`submit_resume_to_textract.rb:10`) and creates no `TextractResult` (status row remains `'none'`).
- On the poll path, a `TextractResult` with `textract_job_id` nil re-enqueues `SubmitResumeToTextractJob` (`get_resume_text_from_textract.rb:14-17`).

### T2 — Manual Resume Upload/Replacement (Internal)
**Chain:** Controller `update` action (param change-detection) → `SubmitResumeToTextractJob`. **File:** `app/controllers/api/v1/job_applications_controller.rb:107-116`.

The change-detection surface is the controller `update` action, not a model `after_commit`: ActiveRecord has no dirty-tracking for ActiveStorage attachments, so the controller detects the resume change in code (comments `:109,:111`). This is structurally unlike the other triggers, which fire off model callbacks.

After `if job_application.update(temp_params)` (`:107`): `if temp_params.key?(:resume) && temp_params[:resume].present?` (`:110`, requires `:resume` present and non-blank) → `DocxToPdfJob.perform_later(job_application.id)` (`:112`), then `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, current_organization)` (`:113`) → `SubmitResumeToTextractJob.perform_later(job_application.id)` (`:114`). This action creates no `AiJobApplicationSummary` and does not call `CreateAiSummaryGeneration`; the status row is not touched by `SubmitResumeToTextract` (its only summary-table write is the conditional `update_all(stale: true)` at `submit_resume_to_textract.rb:18-19`; status-row references in this path are only `.includes` preloads at controller `:27/:38/:56`).

Entry forks before any `TextractResult`:
- Blank/absent `:resume` → the `:110` gate is false; no `DocxToPdfJob`, no Textract job. The resume update (if any) stands; the in-service `has_resume` check is never reached.
- Flag OFF (`:113`) → the resume is replaced (`:107`) but no Textract job is enqueued: no stale-marking, no new `TextractResult`; the prior summary stays `succeeded`+non-stale and the status row stays `current`.
- Resume removed/absent such that `has_resume` is false → reachable only when the controller passes a non-blank `:resume` whose attachment still yields `has_resume` false; `SubmitResumeToTextract` returns `'No resume attached'` (`submit_resume_to_textract.rb:10`) before the stale `update_all` (`:18-19`) and before the build (`:22`), so no stale-marking and no `TextractResult`.
- Replacement submit failure → the new `TextractResult` lands `failed`; the already-staled prior summary is left `succeeded + stale:true`; the status row is unchanged.

Continuation after the replacement `TextractResult` succeeds (flag ON at the controller): the prior `succeeded` summary was staled (`update_all(stale: true)`, status stays `succeeded`), so the bridge finds no `textract_processing`/`stale:false` waiting summary (`textract_result.rb:121-123`) and takes the else/auto branch (`:137`). This branch runs only when `job.should_auto_generate_ai_summaries?` is true (`:138`):
- **Auto-gen ON** → bridge re-validates (`:140`) and enqueues `GenerateAiJobApplicationSummaryJob` with no requesting user (`:142`). `generate_ai_summary_with_credit_flow` does not early-return at `:68` (a stale-succeeded summary fails `!stale?`); `FindOrCreate` updates the status row to `regenerating` (`find_or_create_ai_job_application_summary_status.rb:14-15`, driven by the status row's own denormalized `ai_job_application_summary` pointer at `:12`); `Orchestrate` selects the stale-succeeded summary (`orchestrate.rb:15-16`, JobApplication-scoped, no stale filter) and the `succeeded` branch returns (`:46-48`). No new summary is created, so `update_summary_status_record` does not fire; the status row remains `regenerating` with the old denormalized score/headline/analysis (the `:15` write is status-only). No credit is charged (`textract_result.rb:77` is empty on the new result → `:82` returns before `:84`); no `AI_SUMMARY_COMPLETE` toast (no requesting user). This is the same path as Trigger D.
- **Auto-gen OFF** (post-Textract) → the bridge else branch returns at `:138`; the status row is not updated, stays `current` with now-stale denormalized data; the prior summary is left `stale:true`.

The status row returns to `current` on a later manual (T9/S-A) or bulk (S-B) regeneration that builds a fresh `:pending` summary (both `CreateAiSummaryGeneration` and `CreateBulkAiSummaryGeneration` filter `where(stale: false)`, excluding the stale-succeeded summary; the bulk pre-filter drops only `:current` rows, so a `regenerating` candidate is processed).

Guarded-skip window: if a non-stale `textract_processing` summary already exists when the resume is replaced (e.g. a manual generate fired while no usable Textract existed and is still mid-flight), the `unless` guard at `submit_resume_to_textract.rb:18` is true and the `update_all` is skipped — the prior summaries keep `stale: false`. In that window, the waiting-summary relink (`:25-26`) relinks the in-flight waiting summary onto the new `TextractResult`, and when the new result succeeds the bridge selector (`textract_result.rb:121-123`) finds that waiting summary and takes the `if` waiting-summary branch (`:125`) instead of the else/auto branch.

### T3 — Clone Job Application to Another Job
**Chain:** `PUT /api/v1/job_applications/:id/clone_to_job` (`config/routes.rb:282`) → `clone_to_job` (`job_applications_controller.rb:132-145`) → `clone_to_job_at_hiring_stage` (`job_application.rb:387`).

The controller authorizes the source job (`job_application.job`'s `clone_to_job?` policy, `job_policy.rb:50` `on_hiring_team?`) at `job_applications_controller.rb:134`.

`dup` (`job_application.rb:391`, def `:387-412`) copies attributes only — it does not copy `has_many :textract_results` (`:28`) or `ai_job_application_summaries`, so the clone has zero `TextractResult` and zero summaries at creation. The clone re-extracts from scratch:
- `resume.blob` is re-attached conditionally: `job_application.resume.attach(resume.blob) if has_resume` (`:401`); `additional_files` blobs are re-attached when present (`:403-407`); `created_via = 'created_via_clone'` (`:400`); `clone_of_job_application_id` set (`:399`).
- The controller `.save` (`:139`) fires `after_commit :enqueue_new_job_application` (`job_application.rb:45`), which on a resume-bearing clone (flag ON) builds a new `in_progress` `TextractResult` by sending the re-attached blob to AWS (`submit_resume_to_textract.rb:16,22`, no `find_or_create`) and creates the status row `'none'` (`job_application.rb:167-170`). The original's `textract_job_result_text` is not carried over.
- On the clone submit, `update_all(stale: true)` (`submit_resume_to_textract.rb:18-19`) and the waiting-summary relink (`:25-26`) have no effect (the clone has zero summaries and no `textract_processing` waiting summary).

The clone deterministically takes the else (auto-gen) branch of `queue_ai_summary_job` (`textract_result.rb:137`), never the waiting-summary `if` branch (`:125`), because no `textract_processing` waiting summary is copied to the clone. The else branch enqueues only when both `should_auto_generate_ai_summaries?` (`:138`) and `ValidateAiSummaryGeneration` `result.success?` (`:140-142`) hold; enqueued with no requesting user (`:142`).

Resume-bearing clone outcomes (flag ON): new `in_progress` `TextractResult` → poll via `GetResumeTextFromTextractJob.set(wait: 2.minutes)` (`submit_resume_to_textract.rb:27`) → on success the else branch runs. **Auto-gen OFF** → returns at `:138`, leaving a `succeeded` `TextractResult` with no summary and the status row at `'none'`. **Auto-gen ON** → enqueues with no requesting user (`:142`); with no pre-existing summary this reaches the auto-path no-pre-existing-summary outcome (`Orchestrate#call` returns at `orchestrate.rb:16`; `generate_ai_summary_with_credit_flow` returns at `textract_result.rb:82`): no summary, no credit, no broadcast (see **The AI pipeline**, auto branch case 1).

Other clone entry outcomes:
- No-resume original → `job_application.rb:401` re-attaches nothing and `SubmitResumeToTextract` returns `'No resume attached'` (`submit_resume_to_textract.rb:10`): no `TextractResult`, no poll, no AI pipeline; status row `'none'`.
- Flag OFF, resume-bearing clone → the shared `:167-168` gate skips the submit; the resume is re-attached but no `TextractResult` is produced; status row `'none'`.
- Candidate already in target job → `clone_to_job_at_hiring_stage` adds a `:taken` error (`job_application.rb:393`); the controller guard `new_job_application.errors.empty? && new_job_application.save` (`:139`) short-circuits: no save, no `after_commit`, no status row, no `TextractResult`, no record persisted.

`complete_cloning` (after_create, `:414-437`) copies only `question_responses` (`:430-435`); channel/message cloning is commented out (`:420-428`); it does not touch Textract or AI summaries. The `CloneJobApplication` interactor (`app/interactors/clone_job_application.rb`) has zero callers and is not on any route; it calls an undefined `job_application.clone_to_job` and an undefined local `new_job_id` (`:22`).

### T4 — Customer API Apply
**Chain:** `POST /v1/hire/job_applications/apply` (`config/routes.rb:501`) → `def apply` (`api_public/v1/hire/job_applications_controller.rb:62`) → `CustomerApi::ValidateJobApplicationApply` → `CustomerApi::CreateJobApplication` → `CustomerApi::CompleteJobApplication`, all inside one `ActiveRecord::Base.transaction` (controller `:68-77`).

`created_via: :created_via_customer_api_apply` (controller `:66`; enum value 6, `job_application.rb:90`). The resume is base64-decoded in `ValidateJobApplicationApply` (`:77`, `context.decoded_resume = decoded` `:91`) and attached via `StringIO.new(context.decoded_resume)` in `CreateJobApplication` (`attach_resume`, `create_job_application.rb:70-78,:74`).

The save that fires `after_commit :enqueue_new_job_application` is inside `CreateJobApplication`, not after `CompleteJobApplication`:
- New candidate: `build_new_candidate` (`:43-60`) builds the candidate with `created_via: :created_via_customer_api` (`:47`; candidate enum value 4, `candidate.rb:106`); `save_new_candidate` → `candidate.save` (`:19`/`:62-68`, `.save` `:63`).
- Existing candidate: `build_application_for_existing_candidate` (`:28-41`) attaches the resume (`:36`) then persists via `job.candidates.push(candidate)` (`:40`) — not a `candidate.save`.

`CompleteJobApplication` only adds question responses (`:6-9`) and sends the confirmation email; it never saves the candidate. The `after_commit` fires on outer-transaction commit (controller `:77`). Textract fires only via this shared `after_commit`; none of the three interactors triggers it directly. There is no synchronous textract-ready branch on apply — the resume is freshly attached, so no `TextractResult` pre-exists; the AI pipeline is reachable only later when polling succeeds and `queue_ai_summary_job` fires (`textract_result.rb:114`).

- Status row created `'none'` (`job_application.rb:170`); no `AiJobApplicationSummary` created.
- `update_all(stale: true)` (`submit_resume_to_textract.rb:18-20`) and the waiting-summary relink (`:25-26`) have no effect (fresh apply has zero summaries, no `textract_processing` summary).
- No-resume apply → `ValidateJobApplicationApply` requires a resume only when `job_settings['resume'] == 'required'` (`validate_job_application_apply.rb:36-38`); a resume-less apply passes validation, then `SubmitResumeToTextract` returns `'No resume attached'` (`submit_resume_to_textract.rb:10`): no `TextractResult`, no poll job.
- Flag OFF, resume-present apply → the shared `:167-169` gate skips the submit; a resume is attached but no `TextractResult` is produced.
- Resume-present apply (flag ON) that reaches `succeeded` with auto-gen ON and no pre-existing summary reaches the auto-path no-pre-existing-summary outcome (see **The AI pipeline**, auto branch case 1): no summary, no credit, no broadcast.

`CreateJobApplication` and the apply validations reject on: duplicate application (`ValidateJobApplicationApply#check_duplicate`, `validate_job_application_apply.rb:63-70`; HTTP 409, controller `:81-88`); missing/oversized resume and base64-decode/metadata errors (`#validate_resume`, `:77-89`, `file_too_large` at `:80-85`); content-type/`invalid_file_type` (via `resolve_file_metadata`, `:88` → `CustomerApiFileValidation#resolve_file_metadata`, `customer_api_file_validation.rb:116-127`) — the resume and content-type rejections return HTTP 422; question-response validation errors — non-belonging/format/required-but-blank/missing-required (`#validate_question_responses`, `:96-132`, `:106-151`); missing/non-boolean `send_candidate_confirmation_email` (`#validate_required_fields`, `:40-44`; import's `validate_required_fields` checks only `first_name`/`email`, `validate_job_application_import.rb:29-34`); existing-candidate invalidity (`CreateJobApplication#build_application_for_existing_candidate`, `create_job_application.rb:38`); new-candidate save failure (`#save_new_candidate`, `:62-67`); and a `CompleteJobApplication` question-response save failure (`complete_job_application.rb:25-29`). On any of these the interactor calls `context.fail!`/`raise ActiveRecord::Rollback` (controller `:70`/`:73`/`:76`); the create is unwound and, because the `after_commit` fires only on outer commit, no record, status row, or `TextractResult` is produced. (Apply uniquely both validates question responses here and processes them via `CompleteJobApplication`; import rejects them — see T5.)

### T5 — Customer API Import
**Chain:** `POST /v1/hire/job_applications/import` (`config/routes.rb:502`) → `CustomerApi::ValidateJobApplicationImport` (`:104`) + `CustomerApi::CreateJobApplication` (`:107`), inside one `ActiveRecord::Base.transaction` (`api_public/v1/hire/job_applications_controller.rb:103-109`). Import does not call `CompleteJobApplication` (contrast apply `:75`).

`created_via: :created_via_customer_api_import` (controller `:101`; enum 7, `job_application.rb:91`). For an existing candidate, `CreateJobApplication` persists via `job.candidates.push(candidate)` (`create_job_application.rb:40`); the new-candidate branch uses `save_new_candidate` → `candidate.save` (`:62-68`). Both branches fire the same `on: [:create]` after_commit; the Textract behavior is identical to apply (it fires from the shared callback on creation), though the interactor chain differs.

- Status row created `'none'` on every import (`job_application.rb:170`).
- `enqueue_new_job_application` enqueues `NewJobApplicationJob` (`:165`) and `DocxToPdfJob` (`:166`) before the gated `SubmitResumeToTextractJob` (`:168`). `update_all(stale: true)` (`submit_resume_to_textract.rb:18-20`) and the waiting-summary relink (`:25-26`) have no effect on a fresh import.
- Resume is optional (`validate_job_application_import.rb:62-63`): no resume → `SubmitResumeToTextract` returns `'No resume attached'` (`submit_resume_to_textract.rb:10`): no `TextractResult`, no poll job.
- Flag OFF, resume-present import → the shared `:167-169` gate skips the submit; no `TextractResult`.
- Resume-present import (flag ON) that reaches `succeeded` with auto-gen ON and no pre-existing summary reaches the auto-path no-pre-existing-summary outcome (see **The AI pipeline**, auto branch case 1).

On the resume-present (flag ON) path, the `in_progress` `TextractResult` is advanced by `GetResumeTextFromTextractJob` (`get_resume_text_from_textract_job.rb:25` → `GetResumeTextFromTextract#parse_resume_text`, `retry_on CustomErrorTextract` `:6`): `succeeded` via `.update` (`get_resume_text_from_textract.rb:24-29,:31`, fires the bridge); AWS-`failed` via `update_columns` (`:40`) + `raise CustomErrorTextract` (`:41`); `InvalidJobIdException` via `update_columns(... textract_job_id: nil)` (`:46-47`, no raise, re-enters self-healing at `:14-17`); the self-healing nil-`textract_job_id` re-submit (`:14-17`). After 3 exhausted retries, `cleanup_orphaned_summary` (`get_resume_text_from_textract_job.rb:6-8`, def `:10-23`) returns at `:16` (no waiting summary) on a fresh import.

`ValidateJobApplicationImport` and the shared `CreateJobApplication` reject on: duplicate application (`#check_duplicate`, `validate_job_application_import.rb:44-60`, `:55-59`); question responses present (`#reject_question_responses`, `:21-27` — import rejects question responses entirely, an import-vs-apply divergence); oversized/malformed resume and decode/metadata errors (`#validate_resume`, `:62-83`, `file_too_large` at `:69-75`); content-type errors — `content_type_mismatch` when decoded bytes match no supported format (`customer_api_file_validation.rb:116-119`) and `invalid_file_type` when the resolved content type is not in `RESUME_CONTENT_TYPES` (`:123-127`), via `resolve_file_metadata` (`:77`); existing-candidate invalidity (`CreateJobApplication#build_application_for_existing_candidate`, `create_job_application.rb:38`); new-candidate save failure (`#save_new_candidate`, `:62-67`). On any of these the interactor calls `context.fail!` and the controller `raise ActiveRecord::Rollback` at `:105`/`:108`; the create is unwound on the outer transaction and no record, status row, or `TextractResult` is produced.

### T6 — CSV Bulk Import
**Chain:** `Api::V1::JobCsvImportController#create` (`job_csv_import_controller.rb:4`) → `ImportJobCandidatesFromCsvJob` → `CreateCandidateJobApplication` → `candidate.save` → `after_commit`.

The controller (`job_csv_import_controller.rb:4`) does `authorize job, :on_hiring_team?` (`:6`), `ValidateJobCsvImport.call(file:, job:, hiring_stage_id:)` (`:8`, bad-request render on failure `:10-14`), then `ImportJobCandidatesFromCsvJob.perform_later(organization_user_id:, job_id:, hiring_stage_id:, csv_records:)` (`:16-17`).

`ImportJobCandidatesFromCsvJob` (`:14-22`) sets `external_resume_status: record['Resume URL'].nil? ? nil : :pending` (`:21`):
- **Present-URL row** stores `external_resume_url` + `external_resume_status: :pending`, with no file at creation, so `SubmitResumeToTextract` exits at `has_resume` false (`submit_resume_to_textract.rb:10`, `job_application.rb:589-590`): no `TextractResult`. Status row created `'none'` (`:170`). The submit runs only when `enqueue_new_job_application` enqueued it (gated on `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)`, `:167`); when OFF, the early-exit is not reached but the outcome (no `TextractResult`) is the same.
- **No-URL row** has `external_resume_status` nil and `external_resume_url` nil, so `should_attach_external_resume_url?` (`:709-710`, requires `external_resume_status_pending?`) is false and both `attach_external_resume_url` (`:642`) and the controller `show` enqueue (`:59`) have no effect: no resume and no Textract.

`created_via`: candidate `:created_via_manual_add` (`:17`, applied only to a newly built candidate — an existing candidate is reused via `create_candidate_job_application.rb:14-20` without applying `candidate_data`); job_application `:created_via_bulk_manual_add` (`:20`). `assign_attributes(job_application_data)` at `create_candidate_job_application.rb:22` applies to both candidate branches, so `external_resume_url`, `external_resume_status: :pending`, and `created_via_bulk_manual_add` are applied to an existing candidate's job_application too — the present-URL outcome is identical for new and existing candidates. On the new-candidate branch, `CreateCandidateJobApplication` retrieves the job_application via `@candidate.job_applications.first` (`create_candidate_job_application.rb:19`), the auto-built join from `@job.candidates.build` (`:18`; `job.candidates` is `through: :job_applications`, `job.rb:38`); this does not affect the Textract outcome.

The "no file at creation" property is key-dependent: `CreateCandidateJobApplication` has an `attach_resume_url` path (`:24`, body `:34-37`, downloads the URL and `@job_application.resume.attach(io:..., filename: 'resume.pdf')` when the download is `application/pdf`) that would attach a file at creation if a `resume_url:` key were passed. The CSV job passes no `resume_url:` key (`import_job_candidates_from_csv_job.rb:14-22` passes only `job:`/`candidate_data:`/`job_application_data:`), so `@resume_url` is nil and `:24` skips the attach. If `resume_url:` were passed, a file would attach at creation and a `TextractResult` would be created.

Per-row rejection and batch behavior: `CreateCandidateJobApplication` calls `context.fail!(error: @job_application) unless @job_application.valid?` (`:26`) and `context.fail!(error: @candidate) unless @candidate.save` (`:27`); a failing row creates no job_application, status row, or `TextractResult`. The CSV job swallows the per-row failure (`import_job_candidates_from_csv_job.rb:23-24`, `ap` only) and continues the loop — one failing row does not abort the batch (a divergence from the single-transaction rollback of T4/T5). A mid-loop raise is caught by the whole-job `rescue StandardError` (`:28-31`, log and swallow), which aborts the remaining rows while already-created rows keep their `'none'` status and no-`TextractResult` outcome.

A later controller `show` advances a present-URL row's resume but not its Textract — see T7.

### T7 — External Resume URL Attachment (Lazy Download)
**Chain:** Controller `show` → `JobApplication::AttachExternalResumeUrlJob` → `attach_external_resume_url`. Job `app/jobs/job_application/attach_external_resume_url_job.rb:3` (`class JobApplication::AttachExternalResumeUrlJob`); model method `job_application.rb:641-657`; condition `should_attach_external_resume_url?` (`:709-711`: `external_resume_status_pending? && !has_resume`; enum `external_resume_status {pending:0, uploaded:1, error:2} _prefix:true` at `:94-98`).

Controller enqueue: `JobApplication::AttachExternalResumeUrlJob.perform_later(organization_user_id: current_organization_user.id, job_application_id: params[:id])` (`job_applications_controller.rb:58`) `if @job_application.should_attach_external_resume_url?` (`:59`). The record was located via `current_organization.job_applications.includes(:ai_job_application_summary_status).find_by(id_or_hash_id(params[:id]))` (`:56`), but the enqueue forwards the raw `params[:id]`, not the resolved record id. The job calls `JobApplication.find(job_application_id)` (`attach_external_resume_url_job.rb:8`); `JobApplication.find` resolves by primary-key id only, so when `params[:id]` is a `hash_id` (not a numeric id), `find` raises `ActiveRecord::RecordNotFound`, caught by the job's `rescue StandardError` (`:13`), and the attach does not run.

Job signature `perform(job_application_id:, organization_user_id:)` (`:6`); `organization_user_id` resolves the broadcast target via `OrganizationUser.find(organization_user_id)` (`:7`) → `@organization_user.user` (`:11`). `should_attach_external_resume_url?` is checked twice — at enqueue (`:59`) and inside `attach_external_resume_url` (`:642`); a stale enqueue has no effect.

`attach_external_resume_url` (`:641-657`):
- PDF → `resume.attach(io:..., filename: 'resume.pdf')` + `update_column(:external_resume_status, :uploaded)` (`:647-649`).
- Non-PDF content type, or a rescued `StandardError` → `update_column(:external_resume_status, :error)` (`:651`/`:654`).
- All writes use `update_column` (no callbacks).

The job broadcasts `attachExternalResumeComplete`; the frontend handler invalidates only the `jobApplication` query (`attach_external_resume_url_job.rb:11-12`, `WebsocketGlobalChannelHandler.tsx:152-154`).

Textract is not triggered after lazy attachment: `update_column` (`:649/:651/:654`) bypasses callbacks, the attach path calls no submit enqueuer, and none of the `SubmitResumeToTextractJob` enqueue sites runs on the read path. (The create-only `enqueue_new_job_application` at `:45,:168` fired at insert, before any resume existed.) After `:uploaded`, the record has `has_resume == true` but `external_resume_status` is no longer `pending`, so a later `show` does not re-enqueue (`should_attach_external_resume_url?` requires `external_resume_status_pending?`, `:710`). `:error` is likewise a state that no read-path actor retries. A separate trigger (manual generate, bulk backfill, resume replacement) is what reaches Textract for such a row.

`JobApplication::AttachExternalResumeUrlJob#perform` wraps its whole body in `rescue StandardError` that only `ap`s (`:13-16`); there is no `retry_on` (`ApplicationJob` is empty). When `OrganizationUser.find` / `JobApplication.find` or the model method raises before its own rescue, the job neither retries nor broadcasts `attachExternalResumeComplete`, so the frontend does not invalidate.

`SubmitResumeToTextractJob.perform_later` enqueue sites (6 app-code + 2 rake):
- `job_application.rb:168` (shared create callback)
- `validate_ai_summary_generation.rb:39` (no `TextractResult`)
- `validate_ai_summary_generation.rb:55` (latest `TextractResult` failed, a prior did not)
- `queue_bulk_ai_summary_jobs.rb:29` (bulk backfill)
- `job_applications_controller.rb:114` (controller update — T2)
- `get_resume_text_from_textract.rb:15` (self-healing re-submit)
- `lib/tasks/housekeeping_tasks.rake:409` and `:445` (backfill/replay)

For a freshly `:uploaded` row with no `TextractResult`, the direct Textract re-entry on a manual generate is `validate_ai_summary_generation.rb:38-39` (`unless @latest_textract_result` → submit), with `has_resume?` passing at `:27` (true post-upload). The `:55` site fires only when the latest `TextractResult` exists and is `textract_job_status_failed?` with a non-failed/absent prior — the route for rows that already have a failed prior result; the two rake sites cover backfill/replay.

### T8 — Bulk AI Summary Generation (Textract Backfill)
**Chain:** `QueueBulkAiSummaryJobs` → `SubmitResumeToTextractJob` for resume-but-no-`TextractResult` candidates. **File:** `app/interactors/queue_bulk_ai_summary_jobs.rb:28-30`. (The full bulk AI summary flow is T8/S-B; this section covers the Textract-backfill aspect that defines T8.)

`ready_ids = scope.with_resume.with_textract_results.distinct.pluck(:id)` (`:22`); `pending_textract_ids = scope.with_resume.where.not(id: ready_ids).distinct.pluck(:id)` (`:23`); `pending_textract_ids.each { |id| SubmitResumeToTextractJob.perform_later(id) }` (`:28-30`). These candidates are not in the current bulk run. The backfill loop does not check `TEXTRACT_RESUME_PROCESSING` (the interactor's pre-flight gates are `:17` `AI_APPLICANT_SUMMARY` and `:18` `ai_credits_available?` only); it has no de-dup/idempotency guard and enqueues every time the endpoint is hit, and `SubmitResumeToTextract` builds a new `in_progress` `TextractResult` each time (`submit_resume_to_textract.rb:22`, no `find_or_create`), so two runs before the first poll lands produce duplicate jobs and `TextractResult` records for the same candidate.

`with_textract_results` is a bare `joins(:textract_results)` (`job_application.rb:115`); since a job_application `has_many :textract_results`, the join multiplies rows per candidate and the `.distinct` (`:22-23`) dedups `ready_ids`/`pending_textract_ids`. Consequence: a candidate may have multiple `TextractResult` records, and a candidate whose single prior `TextractResult` is `failed` is already in `ready_ids` (the bare join matches the failed result), so it is not in `pending_textract_ids`, is not re-backfilled, and goes straight to the working set to defer/process on that failed result at iteration time (`bulk_generate_ai_summaries_job.rb:65-67`).

In the current run these candidates are in `input_ids` but excluded from `ready_ids`/`working_set`/`claimed_ids` (`working_set = ready_ids - already_claimed_ids` `:47`, and `pending_textract_ids` are not in `ready_ids`); they fold into `skipped_count` (`input_ids.size - claimed_ids.size`, `:88`/`:92`; empty-set branch `:51`), receive no `BulkAiSummaryJobApplication` row, and are signaled via `context.any_textract_pending = pending_textract_ids.any?` (`:52`/`:93`) → controller JSON (`bulk_ai_job_application_summaries_controller.rb:23`). They become processable on a subsequent bulk run (when they are in `ready_ids`).

Backfill-submit outcomes:
- When the backfill `SubmitResumeToTextractJob` runs and its `TextractResult` succeeds, the bridge takes the else/auto branch (`textract_result.rb:137`, no waiting summary). **Auto-gen OFF** → returns at `:138`; succeeded `TextractResult`, no summary, status row stays `'none'`. **Auto-gen ON** → enqueues with no requesting user (`:142`); with no pre-existing summary this reaches the auto-path no-pre-existing-summary outcome (`Orchestrate#call` returns at `orchestrate.rb:16`; `generate_ai_summary_with_credit_flow` returns at `textract_result.rb:82`): no summary, no credit, no broadcast. In both auto-gen states the backfill alone produces no summary.
- Backfill-submit failure: `parser.send_to_textract` (`submit_resume_to_textract.rb:16`) runs before the build (`:22`); when it raises, the rescue (`:31-40`) operates on a still-nil `@textract_result` (the `&.` write has no effect) → no `TextractResult` created. The candidate stays resume-but-no-`TextractResult`; the job wrapper (`submit_resume_to_textract_job.rb:9-11`) rescues `StandardError` and only `ap`s (no job retry). A subsequent bulk run's backfill is what retries.

Bulk-path no-resume candidates (`input_ids` not captured into `ready_ids` or `pending_textract_ids`, both of which require `with_resume`) are skipped (`:24` comment), counted in `skipped_count`, and receive no `BulkAiSummaryJobApplication` row and no backfill job.

### T9 — Manual AI Summary Generation
**Chain:** `POST .../ai_job_application_summaries` → `ValidateAiSummaryGeneration` → `CreateAiSummaryGeneration` (and, on the no-`TextractResult` path, `SubmitResumeToTextractJob`). **File:** `app/interactors/validate_ai_summary_generation.rb`.

Pre-validate controller gates: `authorize :ai_job_application_summary, :create?` (`ai_job_application_summaries_controller.rb:6`) and job_application scoping to `current_organization.job_applications` via `exists(...)` (`:5`). `ValidateAiSummaryGeneration` is invoked without a `user:` argument (controller `:8-11` passes only `job_application:` and `organization:`), so `context.user` is nil inside Validate (which reads no user); the user is supplied to `CreateAiSummaryGeneration` (`:17-21`, `user: current_user` at `:20`).

`ValidateAiSummaryGeneration` runs fail-fast guards before the no-result branch reaches `SubmitResumeToTextractJob.perform_later` (`:39`): `:24-25` nil guards (job application / organization), `:26` `flipper_enabled?(AI_APPLICANT_SUMMARY)`, `:27` `unless has_resume?`, `:28` `unless credits_available?`, `:29` `unless has_job_description?` (def `:81-83`, `@job_application.job&.description.present?`; error message "This job needs a description before Plato can review candidates. Add one in Job Setup."). A manual generate reaches the Textract submit only when all pass.

`context.textract_result` is assigned unconditionally at `:31-32` (nil on the no-`TextractResult` path; `latest_textract_result` def `job_application.rb:685-687`, `textract_results.order(created_at: :desc).first`, nil when none). Sibling branches off the same entry:
- `:38-42` `unless @latest_textract_result` → `SubmitResumeToTextractJob.perform_later` (`:39`) + `textract_pending=true` (`:40`) + bare `return` (`:41`) → interactor success.
- `:44-45` `textract_text_ready?` → `textract_pending=false` (proceeds into the AI pipeline).
- `:46-57` latest `failed` but a prior not failed → re-submit Textract (`:55`) + `textract_pending=true` (`:56`).
- `:52-53` both failed → `context.fail!`.
- `:58-59` else (in_progress/not_started) → `textract_pending=true`.

`CreateAiSummaryGeneration` first looks up `active_ai_summary` (`:30-34`, `.where.not(status: :failed).where(stale: false).order(created_at: :desc).first`). If its `textract_result_id != latest_textract_result&.id`, it is staled via `update_columns(stale: true)` (`:37`) and treated as none (`:36-39`); a matching active summary is reused and returned (`:41-44`). Then at `:46` (`if validation_result.textract_pending`):

**No-`TextractResult` path (textract_pending true).** `job_application.latest_textract_result` is nil during this synchronous run (the submit at `validate_ai_summary_generation.rb:39` is async and `submit_resume_to_textract.rb:22` builds the `in_progress` `TextractResult` only when that job later runs), so:
- Reuse sub-case: a prior `textract_processing` summary with `textract_result_id: nil` matches the mismatch guard as equal (`nil != nil` is false) and is not staled (`:36-39`); it is reused and returned (`:41-44`) with no new build and no enqueue.
- Fresh-build sub-case: when no prior active summary exists, a new `:textract_processing` summary is built and saved (`:47-53`), carrying `requested_by_organization_user_id` (`:50`, `context.user&.current_organization_user&.id`, safe-nav), and returned without enqueuing any job.

Either way the summary is left waiting for the Textract poll/bridge, while Validate has already submitted Textract. When the async `SubmitResumeToTextractJob` runs, the stale guard `unless ...where(status: :textract_processing, stale: false).exists?` (`submit_resume_to_textract.rb:18`) is true for the just-built/reused waiting summary, so the `update_all(stale: true)` (`:19`) is skipped — the waiting summary survives as `textract_processing`/`stale:false` and is later relinked via `submit_resume_to_textract.rb:25-26`. The bridge waiting-summary query filters only `status: :textract_processing, stale: false` (no `textract_result_id` filter, `textract_result.rb:121-123`), so the summary is found independent of the relink. After Textract succeeds the bridge `if` branch re-validates (`:126`) and enqueues `GenerateAiJobApplicationSummaryJob(requesting_organization_user_id: ...)` at `:130`, driving the same summary `textract_processing → extracting → … → succeeded` and producing the `AI_SUMMARY_COMPLETE` toast.

**Textract-ready path (textract_pending false).** `CreateAiSummaryGeneration` takes the `:46` else arm: builds a `:pending` summary (`:60-64`), saves it (`:70`), and immediately enqueues `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: validation_result.textract_result.id, requesting_organization_user_id: context.user.current_organization_user.id)` (`:71-74`). The `:73` requesting-user read uses no safe-nav, unlike the two build sites at `:50`/`:63`; on the authenticated S-A path `context.user` is always present. The `active_ai_summary` lookup and mismatch-stale guard (`:30-39`) run before the `:46` branch, so on the ready path a non-stale non-failed active summary whose `textract_result_id == latest_textract_result.id` is reused and returned at `:41-44` with no new build and no enqueue, and a mismatched active summary is staled (`:37`) then a fresh `:pending` built. The enqueued run then drives the same `Orchestrate` pipeline as S-E and can come to rest at `awaiting_job_criteria` (`orchestrate.rb:72,80-81`) with the status row at `initial_summary_pending` and no broadcast (see **The AI pipeline** and **State-transition tables**).

`generate_ai_summary_with_credit_flow` calls `find_or_create_ai_job_application_summary_status` (`:70`) and `set_initial_summary_pending` (`:72`) before the pipeline; these execute on the later bridge/job run, not on the T9 validate path itself.

---

## The bridge — `TextractResult#queue_ai_summary_job`

**File:** `app/models/textract_result.rb:114-144`. Fired by the `after_commit on: [:create, :update]` (`:7`) when `GetResumeTextFromTextract` `.update`s the result with text.

Entry guards: `return unless textract_job_result_text.present?` (`:115`); `return unless saved_change_to_textract_job_result_text?` (`:116`); `return unless organization` (`:119`).

Branch selector: `ai_job_application_summaries.where(status: :textract_processing, stale: false).first` (`:121-123`, JobApplication-scoped, no `textract_result_id` filter, no explicit order). This selection is read only to obtain `requested_by_organization_user_id` and to choose the branch; the job receives `textract_result_id` only (`:129`), never a summary id. The advancing record is re-selected independently by an ordered query (`Orchestrate#call` `orchestrate.rb:15` and `Summary::Generate` `generate.rb:30`, both `order(created_at: :desc).first`). When the latest-by-`created_at` summary is not the `textract_processing` one this selector found, the record that advances differs from the one whose `requested_by_organization_user_id` drove the branch decision.

- **`if` waiting-summary branch (handoff — S-C/S-E):** re-validates with `ValidateAiSummaryGeneration` (`:126`); on success, enqueues the job with `requesting_organization_user_id = ai_summary_waiting_on_textract.requested_by_organization_user_id` (`:127-131`); on validation failure, destroys the waiting summary (`:134`) and broadcasts `AI_SUMMARY_FAILED` (`:132-135`).
- **`else` auto-generate branch (S-C/S-D):** `return unless should_auto_generate_ai_summaries?` (`:138`); re-validates (`:140`); enqueues the job with no `requesting_organization_user_id` `if result.success?` (`:142`); a validation failure has no failure handler (no destroy, no broadcast). The else-branch re-validation can fail on any of `validate_ai_summary_generation.rb:24-29` (nil job_application/organization, flipper-disabled `AI_APPLICANT_SUMMARY`, no-resume, credits-exhausted, missing-job-description).

The downstream outcome of the else branch depends on the pre-existing summary; the three cases are described under **The AI pipeline**, auto branch.

---

## The AI pipeline — Orchestrate → Summary → Scoring → Integration

### Driving method: `TextractResult#generate_ai_summary_with_credit_flow`
**File:** `app/models/textract_result.rb:61-89`. Invoked by `GenerateAiJobApplicationSummaryJob#perform` (`generate_ai_job_application_summary_job.rb:32`).

1. `latest_ai_summary = job_application.latest_ai_job_application_summary`; `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?` (`:67-68`).
2. `status_result = job_application.find_or_create_ai_job_application_summary_status` (`:70`); `set_initial_summary_pending(status_result) if status_result.success?` (`:72`).
3. `generate_ai_summary` → `Orchestrate.new(textract_result_id: id).call` (`:74`, def `:110-111`).
4. `ai_job_application_summary = ai_job_application_summaries.order(created_at: :desc).first` (`:77` — `self.ai_job_application_summaries`, scoped to this result, empty on a freshly built result); `return unless ai_job_application_summary&.status_succeeded?` (`:82`).
5. `CreateAiCreditBalanceTransaction.call(summary:)` (`:84` — the only credit-consumption site in `app/`, `CREDIT_COST = 1`, immutable ledger); `return unless consume_result.success?`; then `NotifyZeroAiCredits` / `NotifyLowAiCredits` (`:87-88`).

The `:68` early return short-circuits before `:70`, so `find_or_create_ai_job_application_summary_status` at `:70` runs on every generation except when a succeeded-and-non-stale latest summary already exists. (The other caller, `job_application.rb:170`, is unconditional — it is not inside the `:167-169` Flipper guard, and fires on `on: [:create]`.)

### Generation job: `GenerateAiJobApplicationSummaryJob`
**File:** `app/jobs/generate_ai_job_application_summary_job.rb`

Queue `:default`; `retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3` (`:13`). `perform(textract_result_id:, requesting_organization_user_id: nil)` (`:24`): `textract_result = TextractResult.find_by(id: textract_result_id)` (`:25`); `return unless textract_result` (`:30` — a nil-id re-enqueue from X3 returns here, before `Orchestrate` is constructed); `textract_result.generate_ai_summary_with_credit_flow` (`:32`); `broadcast_completion(...) if requesting_organization_user_id` (`:34`) → `AI_SUMMARY_COMPLETE`. The retry-exhaustion block writes `ai_summary&.update_columns(status: :failed, error_message:)` (`:19`) and broadcasts completion (`:20`); the `StandardError` rescue (`:44`) also writes `:failed`. This job writes `:failed` only and never `:retrying`.

### Orchestrator: `AiJobApplicationAction::Orchestrate`
**File:** `app/services/ai_job_application_action/orchestrate.rb`

`@textract_result = TextractResult.find_by(id: textract_result_id)` (`:6`); `return unless @textract_result` (`:12`). `@ai_job_application_summary = @job_application.ai_job_application_summaries.order(created_at: :desc).first` (`:15`, JobApplication-scoped, no stale filter — the newest summary across all of the job_application's results); `return unless @ai_job_application_summary` (`:16`).

Dispatch on summary status:
```
pending / textract_processing / extracting / retrying → run_summary → check_criteria_and_score
summarizing (incomplete)                              → run_summary → check_criteria_and_score
summarizing (complete)                                → check_criteria_and_score
awaiting_job_criteria                                 → check_criteria_and_score   (:35)
scoring (no criteria_results)                         → run_scoring → run_integration
scoring (has criteria_results)                        → run_integration
integrating                                           → run_integration
succeeded / failed                                    → return   (:46-48)
```

`check_criteria_and_score` (`:68-83`): `return if status_failed?`; `return unless summary_complete?` (`:70`); `update(status: :awaiting_job_criteria)` (`:72`); if `ai_job_criteria&.status_succeeded?` (`:76`) → `run_scoring` (`:77`) + `run_integration` (`:78`); else `job.extract_job_criteria unless criteria pending/in_progress` (`:80`); return. `extract_job_criteria` only kicks off criteria; it does not advance the summary.

### Stages
- **Stage 1 Summary** (`summary/generate.rb`): reuses an existing `pending/textract_processing/extracting/retrying` summary via `.update(status: :extracting) unless status_extracting?` (`:31-33`, reuse branch `:30-33`) or creates one via `AiJobApplicationSummary.create(status: :extracting)` (`:35-39`) — the sole first-summary creator. On reuse it does not re-assign `textract_result` (`textract_result: @textract_result` is set only on the create path `:37`). 4 OpenAI calls; `extracting → summarizing` (`:64-68`, write `:68`); error paths `retrying`/`failed` via `update_columns` (`:175/:180/:184`).
- **Stage 2 Scoring** (`scoring/score_job_application.rb`): secondary criteria guard; `update(status: :awaiting_job_criteria)` at `:23,:45`; `update(status: :scoring)` at `:32`; 1-5 Gemini scoring calls + 1 display call; final `.update(score_percentage:, criteria_results:, status: :integrating)` (`:119-124`, write `:124`). On a criteria-empty failure it writes `ai_job_criteria` `failed` (`:44`), resets the summary to `awaiting_job_criteria` (`:45`), then calls `@job.extract_job_criteria` (`:46`).
- **Stage 3 Integration** (`scoring/integrate_analysis.rb`): 1 OpenAI call; `.update(integrated_role_analysis:, status: :succeeded)` (`:49-53`, write `:53`) — the sole transition to summary `succeeded`, and a `.update` (callback-firing) write. This `.update` is what fires `after_commit :update_summary_status_record` (taking the status row to `current`) and `after_commit :destroy_previous_textract_results`.

### Auto-generate setting
`Job#should_auto_generate_ai_summaries?` (`job.rb:914-922`): per-job enum `auto_generate_ai_summaries {default, enabled, disabled}` _prefix:true (enum `job.rb:159-163`); `enabled?` → true, `disabled?` → false, `default` → falls through to `organization.auto_generate_ai_summaries_enabled` (`org.rb:965-967`, `settings&.dig('auto_generate_ai_summaries_enabled')`, seeded false). Read only at the bridge else branch (`textract_result.rb:138`, sole caller per grep).

### Auto branch (else) — three downstream cases
The bridge else branch (`textract_result.rb:137-142`) and the manual paths share the `Orchestrate#call` early return (`orchestrate.rb:16`) and the `generate_ai_summary_with_credit_flow` succeeded-fetch (`textract_result.rb:82`). The else path's outcome depends on the pre-existing summary:

1. **No pre-existing summary.** `Orchestrate#call` returns at `orchestrate.rb:16` (`@ai_job_application_summary` nil), before `run_summary` → `Summary::Generate` (the sole first-summary creator, reached only from `run_summary` at `:64`) runs. `generate_ai_summary_with_credit_flow` then returns at `textract_result.rb:82` (`self.ai_job_application_summaries` empty on the new result). No summary, no credit, no broadcast.
2. **Pre-existing non-succeeded, non-waiting summary** (latest `pending`/`retrying`/`extracting`, a `stale:true` `textract_processing`, or a non-stale `summarizing`/`scoring`/`integrating`/`awaiting_job_criteria`). The else branch runs (no `textract_processing`+`stale:false` waiting summary); `Orchestrate` selects that summary (`:15`), `:16` passes, and the `case` advances it through `run_summary` → `Summary::Generate` (and the rest) to `succeeded`. A credit is charged only when the reused summary's `textract_result_id` matches the firing result: `:82` reads `:77` (`self.ai_job_application_summaries`, firing-result-scoped), and `Summary::Generate` reuse (`generate.rb:31-33`) keeps the reused summary's original `textract_result_id` (it re-assigns `textract_result` only on the create path `:37`). When that id matches the firing result, `:84` charges a credit; when it does not, the summary reaches `succeeded` but `:77` is empty and `:82` returns before `:84`. On `succeeded`, `update_summary_status_record` writes the status row to `current` + denormalized columns and broadcasts `ai_summary_succeeded` (`ai_job_application_summary.rb:69-80,:93-97`).
3. **Prior succeeded-but-stale summary** (the S-D / T2 auto-continuation; resume replacement is the user-facing form). `:16` passes on the stale-succeeded summary (via the JobApplication-scoped `:15` query), the `succeeded` branch returns (`orchestrate.rb:46-48`), and `generate_ai_summary_with_credit_flow` re-fetches via `textract_result.rb:77` (TextractResult-scoped, empty on the new result), so `:82` returns before `:84`. No new summary, no credit. The status row is set to `regenerating` (`find_or_create_ai_job_application_summary_status.rb:14-15`) and remains there with the old denormalized data; `update_summary_status_record` does not fire because no summary reaches `succeeded`. With auto-gen OFF the bridge returns at `:138` and the row is not updated (stays `current` with stale data). The `regenerating` transition emits a JobChannel `ai_summary_status_change` broadcast (`:16-20`). See **State-transition tables** and **AiJobApplicationSummaryStatus** for the row-state detail; the manual (S-A) or bulk (S-B) regeneration that recovers the row to `current` is described under T2.

The scope difference between `orchestrate.rb:15` (JobApplication-scoped, picks up the old stale-succeeded summary) and `textract_result.rb:77` (TextractResult-scoped, empty on the new result) is what makes case 3 charge no credit.

### S-D auto-gen-ON validation-failure rest
On the S-D auto path with auto-gen ON, the bridge else branch re-runs `ValidateAiSummaryGeneration` (`textract_result.rb:140`) and enqueues only `if result.success?` (`:142`). When validation fails (credits-exhausted `validate_ai_summary_generation.rb:28`, or missing-job-description `:29`, both reachable in S-D), no job is enqueued, so `find_or_create_ai_job_application_summary_status` (`:70`) does not run, the status row is not updated to `regenerating` (stays `current` with stale data), and the prior summary stays `succeeded + stale:true`. On the auto-gen-ON path that does enqueue, `find_or_create` updates the row to `regenerating` first (`:70`), then `set_initial_summary_pending` (`:72`) runs against the `:102` guard — because the row is `regenerating`, the guard fails and `:104-107` does not execute, so the row keeps its old denormalized pointer/score/headline/analysis.

### AiJobCriteria re-trigger (X3)
**File:** `app/models/ai_job_criteria.rb`. `after_commit :resume_waiting_summaries, on: [:update]` (`:17`); `return unless saved_change_to_status? && status_succeeded?` (`:22`).

When criteria reaches `succeeded`: `job.ai_job_application_summaries.where(status: :awaiting_job_criteria).find_each { enqueue GenerateAiJobApplicationSummaryJob(textract_result_id:) }` (`:24-27`, no stale filter, no requesting user). `job.ai_job_application_summaries` is `has_many through: :job_applications` (`job.rb:51`), so one criteria `succeeded` re-enqueues a job for every `awaiting_job_criteria` summary across all job_applications of the job (`find_each` batched). `:22` also requires `saved_change_to_status?`, so an `.update` on an already-`succeeded` row that does not change status does not re-fire. A `succeeded` firing with zero `awaiting_job_criteria` summaries iterates nothing (`:24`).

The re-enqueued job carries only `textract_result_id:` (a nullable column), not a summary id:
- When `textract_result_id` is nil, the job returns at `generate_ai_job_application_summary_job.rb:30` (`return unless textract_result`), before `Orchestrate` is constructed (`generate_ai_job_application_summary_job.rb:25` `TextractResult.find_by(id:)` is nil).
- The advancing record is re-selected by an ordered query, not the awaiting summary: `generate_ai_summary_with_credit_flow:67` reads `job_application.latest_ai_job_application_summary` and `Orchestrate#call` re-selects `@job_application.ai_job_application_summaries.order(created_at: :desc).first` (`orchestrate.rb:15`) — the newest summary. When the awaiting summary is the newest, it advances via the `:35` `status_awaiting_job_criteria?` branch → `check_criteria_and_score` (re-executing `:70` `return unless summary_complete?` and the redundant `:72` `update(status: :awaiting_job_criteria)`) → `:76` true → `run_scoring`/`run_integration` → `succeeded`; on `succeeded`, `generate_ai_summary_with_credit_flow:82` passes and `:84` charges a credit. When a different newer succeeded-and-non-stale summary exists, the `textract_result.rb:68` guard (`succeeded && !stale?`) returns and the awaiting row is not advanced on this run. Stale awaiting summaries are included in the fan-out (no stale filter, `:24`); the same newest-summary re-selection applies.
- Because the re-enqueue passes no `requesting_organization_user_id`, on reaching `succeeded` `generate_ai_job_application_summary_job.rb:34` (`broadcast_completion ... if requesting_organization_user_id`) is skipped — no `AI_SUMMARY_COMPLETE` toast. A summary that rested at `awaiting_job_criteria` after S-E and is resumed here loses the requesting user that was preserved into the first enqueue (`textract_result.rb:130`).

Criteria status writers: `pending` (create) `job.rb:699-700` / `pending` (reset) `job.rb:696` `update_columns`; `in_progress` `extract_criteria.rb:28` `update_columns`; `succeeded` `extract_criteria.rb:132-140` `.update` (fires the callback); `retrying` `extract_criteria.rb:146` `update_columns` then re-raise (`:147`); `failed` `extract_criteria.rb:32,62,122,151,155` / `score_job_application.rb:44` / `extract_job_criteria_job.rb:9,28` `update_columns`. `retrying` triggers `ExtractJobCriteriaJob`'s `retry_on CustomErrorAiSummary, attempts: 3` (`extract_job_criteria_job.rb:5`), which re-runs `ExtractCriteria` and can reach `succeeded` (firing the fan-out) or exhaust to `failed` (`:9`). A `failed` criteria does not fire `resume_waiting_summaries`; an `awaiting_job_criteria` summary depending on it is advanced only when a later `Orchestrate`/`ScoreJobApplication` pass re-invokes `extract_job_criteria` (e.g. `score_job_application.rb:46`) toward a future `succeeded`. `summary_text` and `headline` are already persisted on the summary by the time it rests at `awaiting_job_criteria`.

### AI credits
`organization.ai_credits_available?` is the pre-flight on all validation paths. `CreateAiCreditBalanceTransaction` (`textract_result.rb:84`) consumes 1 credit on success against an immutable ledger; `NotifyZeroAiCredits`/`NotifyLowAiCredits` follow.

### Bulk AI summary flow (T8 / S-B)
**Controller:** `BulkAiJobApplicationSummariesController#create` resolves IDs server-side: `included_job_application_ids`, or (`hiring_stage_id` + role-fit filter via `apply_role_fit_filter` − `excluded_job_application_ids`) (`bulk_ai_job_application_summaries_controller.rb:32-46`). `RoleFitFilterable#apply_role_fit_filter` (`concerns/role_fit_filterable.rb:10,:15`).

**`QueueBulkAiSummaryJobs`** (claim phase):
- Reads `status: :current` rows and drops those candidates from both `ready_ids` and `input_ids` (`queue_bulk_ai_summary_jobs.rb:36-40`: `ready_ids -= already_summarized_ids` `:39`, `input_ids -= already_summarized_ids` `:40`); they are never processed and never counted skipped.
- `already_claimed_ids` pre-filter (`:43-47`) removes candidates already in another batch's `:processing` row before the create loop. A `rescue ActiveRecord::RecordNotUnique` (`:70-75`) logs and skips on a concurrent-insert race; the candidate is excluded from `claimed_ids` (re-query `:78-80`) and folds into `skipped_count` (`:88`).
- Empty-working-set: when `working_set.empty?` (`:49-54`) the interactor returns counts (`queued_count=0`, `skipped_count=input_ids.size`, `any_textract_pending`) and enqueues no `BulkGenerateAiSummariesJob`, so `on_complete` does not run and no `AI_SUMMARY_BULK_COMPLETE`/`_FAILED` broadcast or mailer is produced; the only signal is the synchronous controller JSON (`bulk_ai_job_application_summaries_controller.rb:20-24`).
- Otherwise enqueues `BulkGenerateAiSummariesJob` with a payload hash (`bulk_job_id/user_id/hiring_stage_id/job_id/job_application_ids/skipped_count`, `:82-89`; counts `:91-93`).

**`BulkAiSummaryJobApplication`** enum `{processing:0, done:1, failed:2, deferred:3}` _prefix:true.

**`BulkGenerateAiSummariesJob`** (job-iteration), per-candidate `each_iteration` order: idempotency guard (`:48-56`, a succeeded/failed summary created after the claim row exists → `update_columns(status: :done)` `:54`, skip) → `return unless result.success?` validation gate (`:60`) → `textract_pending → update_columns(status: :deferred)` (`:65-67`) → else `CreateBulkAiSummaryGeneration` (builds the `:pending` summary) (`:74`) → `generate_ai_summary_with_credit_flow` (`:80`) → `update_columns(status: :done)` (`:86`). A non-`CustomErrorAiSummary` error in `each_iteration` is rescued (`:89-92`, `ap`, no re-raise, no row update).

`with_textract_results` is a bare `joins(:textract_results)` (`job_application.rb:115`); it does not check `textract_job_result_text`. A candidate with an `in_progress` (no-text) `TextractResult` counts as ready in the join and then defers at iteration time (`:65-67`).

`CreateBulkAiSummaryGeneration` (`create_bulk_ai_summary_generation.rb`) builds the `:pending` summary (`:50-54`) before `generate_ai_summary_with_credit_flow` (`:80`), so `latest_ai_job_application_summary` is non-nil and `set_initial_summary_pending` (`textract_result.rb:100-107`) succeeds for the bulk path. Its reuse query is `.where.not(status: :failed).where(stale: false)` (`:34-38`), so a candidate's reuse summary is any non-failed non-stale active summary. Before the `:45-48` reuse return, the STALE-REBUILD step at `:40-43` runs: `if active_ai_summary && active_ai_summary.textract_result_id != job_application.latest_textract_result&.id` → `update_columns(stale: true)` (`:41`, a record write site on the bulk path) + `active_ai_summary = nil` (`:42`), falling through to the fresh `:pending` build at `:50-54`. So an active summary tied to a non-latest `TextractResult` is staled and discarded; the `:45-48` "return regardless of status" applies only to an active summary whose `textract_result_id` matches `latest_textract_result`. When a matched active summary is reused, the credit-flow `:68` early return fires only if it is succeeded-and-non-stale.

`on_complete`: uses `floor_at = bulk_job_statuses.minimum(:created_at)` (`:104`) and counts `succeeded` only where `created_at >= floor_at` (`:108`); folds `deferred` into `skippedCount` (`:124` `skipped = ... + deferred`); computes `failed = job_application_ids.size - succeeded - deferred` (`:111`); mailer uses `.deliver_later` (`:144/:171`). `on_complete` does not call `update_remaining_statuses_to_failed`. When `succeeded.zero? && failed.positive?` (`:113-114`), `on_complete` calls `notify_failure` (broadcasts `AI_SUMMARY_BULK_FAILED` + failure mailer) without updating any `:processing` row.

Whole-batch failure: `discard_on StandardError` (`:12-16`) and `retry_on CustomErrorAiSummary` exhaustion (`:17-21`) both call `update_remaining_statuses_to_failed` (`:178-180`, updates remaining `:processing` rows to `:failed`) and `notify_failure`.

`ValidateAiSummaryGeneration` fail conditions (each yields `result.success?` false, so `each_iteration`'s `return unless result.success?` at `:60` returns without touching the `BulkAiSummaryJobApplication` row; the candidate is counted `failed` by subtraction at `:111`): flipper-disabled `AI_APPLICANT_SUMMARY` (`:26`), no-resume (`:27`), nil `job_application` (`:24`), nil `organization` (`:25`), credits-exhausted (`:28`), missing-job-description (`:29`).

Bulk-success status-row writes: on the bulk credit flow, `set_initial_summary_pending` writes the row to `initial_summary_pending` + `ai_job_application_summary_id` via `update_columns` (`textract_result.rb:104-107`), reached at `:72`, only when the row is `none`/`initial_summary_pending` (`:102`). On the summary reaching `succeeded`, `update_summary_status_record` (`ai_job_application_summary.rb:30,69-80`) writes the row to `current` + denormalized columns via `.update` and broadcasts `ai_summary_succeeded` (`:93-97`, invalidates `['jobApplicationsForStage', hiringStageId]`).

---

## State-transition tables

For each record: every status value, every transition with its writer (`file:line` + literal where the input gives it) and precondition, the trigger path(s) that reach it, whether it is a resting state, and what advances out of it. "Resting" is a neutral state-graph property; "no actor advances it within this path" is a transition-graph fact.

### TextractResult.textract_job_status — `{not_started:0, in_progress:1, succeeded:2, failed:3}` _prefix:true

| To-state | Writer (file:line + literal) | Precondition | Reached by | Resting? / advancing actor |
|---|---|---|---|---|
| `in_progress` | `submit_resume_to_textract.rb:22` `textract_results.build(..., textract_job_status: 'in_progress')` (saved `:24`) | AWS submit succeeded, `has_resume` true | T1,T2,T3,T4,T5,T8 backfill,T9 | non-resting → `GetResumeTextFromTextractJob` (+2 min) |
| `succeeded` | `get_resume_text_from_textract.rb:31` `@textract_result.update({textract_job_status: textract_job.job_status.downcase, ... textract_job_result_text:})` | AWS poll returns succeeded with text | all Textract triggers | resting (terminal) → fires `queue_ai_summary_job` bridge |
| `failed` (AWS-failed) | `get_resume_text_from_textract.rb:40` `update_columns(textract_job_status: 'failed')` then raise (`:41`) | AWS poll returns failed | all | non-resting → retry (≤3) then `cleanup_orphaned_summary` |
| `failed` (InvalidJobId) | `get_resume_text_from_textract.rb:47` `update_columns(textract_job_status: 'failed', textract_job_id: nil)` | `InvalidJobIdException`, no raise | all | resting; `textract_job_id` nil → a later poll re-enters self-healing re-submit (`:14-17`) |
| `failed` (submit rescue) | `submit_resume_to_textract.rb:33,39` `@textract_result&.update_columns(textract_job_status: 'failed')` | AWS submit rescue, `@textract_result` already built | all | resting (terminal failed) |
| `not_started` (0) | never written by app code | — | — | enum default, never set |

Additional `in_progress` resting cases (no actor advances within the same path):
- `get_resume_text_from_textract.rb:31` `.update` returns false → stays `in_progress`, no text, bridge does not fire; the AWS call succeeded so there is no retry.
- AWS still processing past 3 retries: the else branch raises `CustomErrorTextract` without marking failed (`:44`); after exhaustion `cleanup_orphaned_summary` runs (no effect without a waiting summary) and the result stays `in_progress`.
- No `TextractResult` is created when `has_resume` is false (`submit_resume_to_textract.rb:10`) or AWS raises before `@textract_result` is assigned (the `&.` write has no effect). This is reached at the entry of T1 (no resume at creation), T2 (resume removal), T3 (resume-less original), T4/T5/T6 (no resume), and T9 (AWS-submit failure), and whenever `TEXTRACT_RESUME_PROCESSING` is OFF on T1/T2/T3/T4/T5/T6 (`job_application.rb:167`; `job_applications_controller.rb:113` for T2).

### AiJobApplicationSummary.status — `{pending:0 … failed:9}` _prefix:true

| To-state | Writer (file:line + literal) | Precondition | Reached by | Resting? / advancing actor |
|---|---|---|---|---|
| `pending` | `create_ai_summary_generation.rb:60-70` / `create_bulk_ai_summary_generation.rb:50-57` `build(status: :pending)` | textract ready | A, B | non-resting → `GenerateAiJobApplicationSummaryJob` |
| `textract_processing` | `create_ai_summary_generation.rb:47-53` `build(status: :textract_processing)` (carries `requested_by_organization_user_id` `:50`) | textract_pending (incl. nil `TextractResult`) | A (T9), E | non-resting → `queue_ai_summary_job` bridge / `SubmitResumeToTextract` relink. A `textract_processing`/nil-`textract_result_id` summary after an AWS-submit failure (T9) has no poll job and the bridge does not fire until a later submit; a reused `textract_processing`/nil summary on the no-Textract path advances when the just-submitted Textract succeeds and the bridge re-validates. |
| `extracting` | `summary/generate.rb:32` `existing_ai_summary.update(status: :extracting)` (reuse) or `:35-39` `AiJobApplicationSummary.create(status: :extracting)` (new) | `Orchestrate run_summary` (reached when a non-succeeded/non-nil summary exists; auto branch case 2) | A,B,C (case 2),E,X3 resume | non-resting → `Summary::Generate` calls |
| `summarizing` | `summary/generate.rb:64-68` `ai_summary.update({status: :summarizing, structured_data:})` | extraction call ok | all pipeline | non-resting |
| `awaiting_job_criteria` | `orchestrate.rb:72` `update(status: :awaiting_job_criteria)`; also `score_job_application.rb:23,45` | summary complete, criteria not succeeded | all pipeline | resting → advanced by `AiJobCriteria#resume_waiting_summaries` (on criteria `succeeded`, when this summary is the newest) or a later `Orchestrate`/`ScoreJobApplication` pass re-invoking `extract_job_criteria`. When criteria end `failed` (written via `update_columns`, no callback) `resume_waiting_summaries` does not fire; the summary remains at `awaiting_job_criteria` until such a later pass. `summary_text`/`headline` already persisted. |
| `scoring` | `score_job_application.rb:32` `update(status: :scoring)` | criteria succeeded | all pipeline | non-resting |
| `integrating` | `score_job_application.rb:119-124` `update({... status: :integrating})` | scoring ok | all pipeline | non-resting |
| `succeeded` | `integrate_analysis.rb:49-53` `update({integrated_role_analysis:, status: :succeeded})` | integration call ok | all pipeline | resting (terminal) → fires `update_summary_status_record`, `destroy_previous_textract_results` |
| `retrying` | `summary/generate.rb:175`, `score_job_application.rb:130`, `integrate_analysis.rb:59` `update_columns(status: :retrying)` | `CustomErrorAiSummary` | all pipeline | non-resting → `retry_on` (≤3) |
| `failed` | `generate_…job.rb:19,44` `update_columns(status: :failed)`; `summary/generate.rb:180,184`; `score_job_application.rb:135,139`; `integrate_analysis.rb:64,68` | parse/StandardError or retry-exhaustion | all pipeline | resting (terminal) → no actor updates the status row on a summary `failed` |

`GenerateAiJobApplicationSummaryJob` is a `failed`-only writer (`:19,44`); the `retrying` writers are the three pipeline services above. The `extracting` write attributed to C is auto branch case 2; on case 1 and case 3, `Orchestrate` returns at `:16` or `:46-48` and `extracting` is never written.

### AiJobApplicationSummaryStatus.status — `{none:0, initial_summary_pending:1, current:2, regenerating:3}` _prefix:true

| To-state | Writer (file:line + literal) | Precondition | Reached by | Resting? / advancing actor |
|---|---|---|---|---|
| `none` | `find_or_create_…status.rb:34,37` `@status_record.status = 'none'` … `save` | no existing row; latest summary not succeeded-and-fresh | T1,T3,T4,T5,T6 (every create with no current review) | resting → `set_initial_summary_pending` (→initial_summary_pending) or `update_summary_status_record` (→current) |
| `current` (create-path) | `find_or_create_…status.rb:28-32,37` `@status_record.status = 'current'` … `save` | no existing row; latest summary succeeded & `!stale?` | status-row creation when a fresh succeeded summary already exists | resting → `regenerating` on next generation |
| `initial_summary_pending` | `textract_result.rb:104-107` `status_record.update_columns(ai_job_application_summary_id: latest_summary.id, status: 'initial_summary_pending')` (bypasses counter_culture) | row currently `none`/`initial_summary_pending` (`:102`); status_record + latest summary exist (`:101`) | A,B,C (case 2),E | resting → `current` on summary success; stays here if the summary ends `failed`/`retrying` (`update_summary_status_record` fires only on `status_succeeded?`, `ai_job_application_summary.rb:69`), or rests here while a summary waits at `awaiting_job_criteria` |
| `regenerating` | `find_or_create_…status.rb:14-15` `@status_record.update_columns(status: 'regenerating')` (status-only; denormalized columns not changed; bypasses counter_culture) + `ai_summary_status_change` broadcast (`:16-20`) | existing row whose associated summary (`@status_record.ai_job_application_summary`, `:12`) `status_succeeded?` | A manual regen, D auto regen, T2 auto-continuation, B bulk regen | resting → `current` when a new summary reaches `succeeded`. On the S-D/T2 auto path with auto-gen ON, `Orchestrate` selects the stale-succeeded summary and its `succeeded` branch returns without advancing, so no new summary reaches `succeeded`; the row remains `regenerating` with the old denormalized data, and no credit is charged (`textract_result.rb:77` empty on the new result → `:82` returns before `:84`). With auto-gen OFF the row is not updated (stays `current` with stale data). |
| `current` (success-path) | `ai_job_application_summary.rb:74-80` `ai_job_application_summary_status.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)` (`.update`, fires counter_culture) | summary `saved_change_to_status? && status_succeeded?` (`:69`) | all pipeline success | resting (displayable terminal) |

When the row exists but its associated summary is not `status_succeeded?` (`find_or_create_…status.rb:14` false), `FindOrCreate` performs no write — only `context.ai_job_application_summary_status = @status_record` (`:42`). This is the common case while a row sits at `none`/`initial_summary_pending`/`regenerating`.

counter_culture: the `.update`/save writers (success-path `current`, create-path) fire it; the two `update_columns` writers (`regenerating`, `initial_summary_pending`) bypass it. Within `current`↔`regenerating` (both counted, `status IN (2,3)`) the bypass leaves the count unchanged. The column `jobs.ai_job_application_summaries_count` is present in committed `db/schema.rb:907`. There is no `failed` value in this enum; when a summary ends `failed`/`retrying` no writer moves the row off `initial_summary_pending`/`regenerating`. When no row exists, `update_summary_status_record` returns early (`:72`) and a summary can succeed for a job_application whose row was never created (the serializer then emits null and the list shows no fit indicator).

### AiJobCriteria.status — `{pending:0, in_progress:1, succeeded:2, failed:3, retrying:4}`

| To-state | Writer (file:line + literal) | Precondition | Callback? | Resting? / advancing actor |
|---|---|---|---|---|
| `pending` (create) | `job.rb:699-700` `AiJobCriteria.new(job:, status: :pending)` … save | first extraction | none (on:create) | non-resting → `ExtractJobCriteriaJob` |
| `pending` (reset) | `job.rb:696` `existing_ai_job_criteria.update_columns(status: :pending, error_message: nil)` | re-extract | none | non-resting → `ExtractJobCriteriaJob` (+2 min) |
| `in_progress` | `extract_criteria.rb:28` `update_columns(status: :in_progress)` | extraction running | none | non-resting |
| `succeeded` | `extract_criteria.rb:132-140` `@ai_job_criteria.update({status: :succeeded, criteria:, metadata:})` | extraction produced criteria | fires `resume_waiting_summaries` | resting (terminal) → resumes all `awaiting_job_criteria` summaries across the job's job_applications (nil `textract_result_id` re-enqueue returns at `generate_…job.rb:30`) |
| `retrying` | `extract_criteria.rb:146` `update_columns(status: :retrying)` then re-raise (`:147`) | `CustomErrorAiSummary` | none | non-resting → `ExtractJobCriteriaJob` `retry_on … attempts: 3` (`extract_job_criteria_job.rb:5`) re-runs `ExtractCriteria` → `succeeded` (fires `resume_waiting_summaries`) or exhaustion → `failed` (`:9`). The only `AiJobCriteria` status with a built-in re-driving actor. |
| `failed` | `extract_criteria.rb:32,62,122,151,155`; `score_job_application.rb:44`; `extract_job_criteria_job.rb:9,28` `update_columns(status: :failed, error_message:)` | blank/empty/parse/StandardError/exhaustion | none | resting (terminal) → does not resume waiting summaries; an `awaiting_job_criteria` summary depending on it advances only when a later `Orchestrate`/`ScoreJobApplication` pass re-invokes `extract_job_criteria` (e.g. `score_job_application.rb:46`) toward a future `succeeded` |

---

## AiJobApplicationSummaryStatus — dedicated section

(Data model, indexes, and associations are in **Data models**. The full transition table is in **State-transition tables**.)

### Lifecycle ownership
The row is owned one-per-`JobApplication` by `JobApplication` (summaries come and go; this row persists). It is created and advanced by:
- **`FindOrCreateAiJobApplicationSummaryStatus`** — called from `JobApplication#enqueue_new_job_application` (`:170`, every create, unconditional — not inside the `:167-169` Flipper guard, on `on: [:create]` at `job_application.rb:45`) and from `TextractResult#generate_ai_summary_with_credit_flow` (`:70`, every generation except when the `:68` early return fires for a succeeded-and-non-stale latest summary). On a concurrent-insert race it rescues `ActiveRecord::RecordNotUnique` (`:43-44`) and returns `job_application.reload.ai_job_application_summary_status` (the reason the unique index does not crash parallel creators). The create-path can `context.fail!` on save failure (`:37-38`), which makes the caller skip `set_initial_summary_pending` (`textract_result.rb:72` guards on success), leaving the row uncreated and the initial_summary_pending step skipped in that generation.
- **`TextractResult#set_initial_summary_pending`** (`:98-108`, `update_columns` `:104-107`, guarded `:101` `return unless status_record && latest_summary` and `:102` `return unless status_none? || status_initial_summary_pending?`).
- **`AiJobApplicationSummary#update_summary_status_record`** (def `:57-98`; `ap` debug `:58-67`; guard `:69` `saved_change_to_status? && status_succeeded?`; on summary success).

### Every transition (in words)
- **`none`** on create when there is no current review.
- **`current` (create-path)** when a fresh succeeded summary already exists at row-creation time (a stale-guarded copy of its denormalized fields).
- **`none` → `initial_summary_pending`** via `set_initial_summary_pending` when a generation begins (guard `:101`/`:102`; `update_columns`, bypasses counter_culture).
- **(existing succeeded) → `regenerating`** via `FindOrCreate` when a new generation starts on a row whose associated summary (the row's denormalized `ai_job_application_summary` pointer, `:12`) is succeeded; status-only `update_columns(status: 'regenerating')` (`:15`), which keeps the old `score_percentage`/`headline`/`integrated_role_analysis`/`ai_job_application_summary_id`; broadcasts `ai_summary_status_change` (`:16-20`). This status-only write is why the row keeps the prior review's denormalized data while the new pipeline runs (or while it remains `regenerating` on the S-D/T2 auto path).
- **`initial_summary_pending`/`regenerating` → `current`** via `update_summary_status_record` when the new summary reaches `succeeded`; copies `score_percentage`/`headline`/`integrated_role_analysis` and re-points `ai_job_application_summary_id` unconditionally (`:75`); `.update` fires counter_culture; broadcasts `ai_summary_succeeded`. This is the sole writer that reconciles a previously-`regenerating` (stale-pointer) row back to `current`.
- **Pass-through (no write)** when the row exists and its associated summary is not succeeded (the common in-flight case): `FindOrCreate` writes nothing.

### Every reader
- **Serializer:** `Api::V1::AiJobApplicationSummaryStatusSerializer` — attributes block `:4-6` (`id, ai_job_application_summary_id, status, score_percentage, headline, integrated_role_analysis, updated_at, published_at_timestamp`); `published_at_timestamp` method `:8-10` (`= object.updated_at.to_i`). Embedded via `has_one :ai_job_application_summary_status` in `ShallowJobApplicationSerializer` (`:23-24`, infinite list) and `JobApplicationSerializer` (`:40-41`, detail). The controller preloads `.includes(:ai_job_application_summary_status)` at index/list (`job_applications_controller.rb:27,38`) and show (`:56`).
- **Bulk (server):** `QueueBulkAiSummaryJobs` reads `status: :current` to drop already-summarized candidates (`:36-40`).
- **counter_culture:** rolls `current`+`regenerating` rows into `jobs.ai_job_application_summaries_count` (column present in committed schema, `db/schema.rb:907`).
- **Maintenance reader (count-repair):** `lib/tasks/recurring_tasks.rake:79` `AiJobApplicationSummaryStatus.counter_culture_fix_counts` periodically recomputes `jobs.ai_job_application_summaries_count` from the status rows (alongside `Job` `:76`, `ChannelMessage` `:77`, `OrganizationUser` `:78`), reconciling any difference left by the two `update_columns` writers that bypass counter_culture.
- **Filtering:** `JobApplication.fit_bands` (via the band scopes) and `JobApplication.unscored` (null `score_percentage`) read this table (`job_application.rb:106-113`).
- **Frontend (infinite list):** `JobApplicationListContainer.tsx:220` maps `jobApplicationsForStage` and renders `JobApplicationNavItem` (`:226`) with `summaryStatus={jobApplication.aiJobApplicationSummaryStatus?.status}` (`:235`) and `summaryScorePercentage={jobApplication.aiJobApplicationSummaryStatus?.scorePercentage}` (`:236`); `JobApplicationNavItem` receives only scalar props (`summaryStatus: string|null`, `summaryScorePercentage: number|null`, `:17-18`) and renders the Harvey-ball fit indicator only when status is `current`/`regenerating` and `scorePercentage != null` (`JobApplicationNavItem.tsx:26-29`). The container is the list reader of `status` + `score_percentage`.
- **Frontend (detail — PlatoTab):** `PlatoTab.tsx` is the primary detail-view status consumer. It branches the entire Plato card on `summaryStatus?.status` (read at `:42`; used at `:50,:52,:151,:154,:187,:210,:218` — `:187` `if ((!statusValue || statusValue === "none") && !jobApplication.hasResume)` gates the no-resume empty state), keys the heavy summary fetch off `summaryStatus?.aiJobApplicationSummaryId` (`:46`, no fallback; downstream gate `useAiJobApplicationSummary.ts:45` `enabled: aiJobApplicationSummaryId != undefined`), and reads `summaryStatus?.updatedAt` (`:130`). It uses display-only fallbacks `summaryStatus?.headline || ''` (`:127`) and `summaryStatus?.scorePercentage || 0` (`:129`), substituting `''`/`0` for absent denormalized data on the detail card (the serializer sends null).
- **Frontend (detail — Activity):** `JobApplicationActivity.tsx:79-91` builds a `platoReview` feed entry, gated on status `current`/`regenerating` (`:80-83`), rendering `publishedAtTimestamp` (`:87`), `headline` (`:88`), `integratedRoleAnalysis` (`:89`), `scorePercentage` (`:90`), `updatedAt` (`:91`). `publishedAtTimestamp` is sent by the serializer (`:6`) and read here but is not declared on the TS interface (`jobApplication.ts:1-9`) — untyped runtime access.
- **Frontend (bulk):** `bulkAiSummaryCount.ts` subtracts `status === 'current'` rows from the bulk-run estimate (`:37-41`, subtracted at `:46`).
- **Frontend (present, no callers):** `Plato/PlatoOverviewCallout.tsx` types `summaryStatusValue` as the 4-value status union (`:13`) and branches in `deriveCalloutStatus` (`:40-47`) on `current`/`regenerating` (→ null/hidden), `initial_summary_pending` (→ `'generating'`), `none`/null (→ `'ask'`/`'noResume'`). It has zero callers (`grep -rn PlatoOverviewCallout app/javascript` returns only its own file; `grep -rn summaryStatusValue` returns nothing outside it), so it produces no live display. (Two same-named files exist; both have no callers.)
- **Websocket (JobChannel):** `WebsocketJobChannelHandler.tsx` — `ai_summary_status_change` invalidates the single-summary + single-job-application queries (`:73-76`), not the infinite list; `ai_summary_succeeded` invalidates `['jobApplicationsForStage', hiringStageId]` (`:77-81`).
- **Websocket (GlobalChannel):** `WebsocketGlobalChannelHandler.tsx` — `AI_SUMMARY_COMPLETE` (`:227`), `AI_SUMMARY_FAILED` (`:241`), `AI_SUMMARY_BULK_FAILED` (`:253`), `AI_SUMMARY_BULK_COMPLETE` (`:281`) all call `invalidateQueries("jobApplicationsForStage")`; react-query prefix matching invalidates the stage-keyed list query (`['jobApplicationsForStage', stageId, roleFit]`, list key `useJobApplication.ts:185`).
- **No optimistic-UI write:** no query hook in `app/javascript/shared/queryHooks/` writes `aiJobApplicationSummaryStatus` via `setQueryData`/`onMutate`; `useJobApplication.ts:229` `setQueryData` runs in `onSuccess` with full server data. All FE status display is server-truth via query invalidation.
- **TS interface:** `AiJobApplicationSummaryStatus.status` is the 4-value union (`jobApplication.ts:4`, file `app/javascript/shared/types/jobApplication.ts`).

### Windows where the row differs from the latest summary
The row reflects display state and is updated only on specific transitions; these are the windows in which the row's value differs from the job_application's latest non-stale `AiJobApplicationSummary`, stated factually:
1. **Pipeline in flight:** during `extracting…integrating`, the row sits at `initial_summary_pending` (set before the pipeline) and changes to `current` on success (`update_summary_status_record` fires only on `status_succeeded?`). The S-E rest at `awaiting_job_criteria` is included: the row stays `initial_summary_pending` while the summary waits on criteria.
2. **Summary ends `failed`/`retrying`:** `update_summary_status_record` does not fire, so the row stays at `initial_summary_pending` or `regenerating` (no `failed` value exists in the enum).
3. **Regeneration:** `FindOrCreate` sets `regenerating` via a status-only `update_columns` (`:15`) without changing `score_percentage`/`headline`/`integrated_role_analysis`/`ai_job_application_summary_id`, so the row reflects the prior review's data while the new pipeline runs.
4. **S-D / T2 auto-continuation:** with auto-gen ON, `Orchestrate` selects the stale-succeeded summary and its `succeeded` branch returns without advancing, so the new summary does not reach `succeeded` and the row stays `regenerating` with the prior data; no credit is charged. With auto-gen OFF the row is not updated and stays `current` with the prior data.
5. **List vs per-status events:** the infinite list ignores `ai_summary_status_change` and is refreshed by terminal/completion events (`ai_summary_succeeded` plus GlobalChannel `AI_SUMMARY_COMPLETE`/`_FAILED`/`_BULK_COMPLETE`/`_BULK_FAILED`), so intermediate pipeline statuses are not reflected on the list.
6. **No row:** a summary can succeed for a job_application whose row was never created (`update_summary_status_record` early-returns at `:72`); the serializer emits null and the list shows no indicator.
7. **`current` pointing at a stale summary:** `update_summary_status_record` has no stale guard; it copies the succeeding summary's denormalized fields onto the row even when that summary is stale relative to a newer `TextractResult`.
8. **counter_culture bypass:** the `regenerating` and `initial_summary_pending` transitions (via `update_columns`) skip counter_culture; the `current` (success-path) and create-path writes (via `.update`/`save`) fire it. Within `current`↔`regenerating` (both counted) the count is unaffected. The maintenance reader (`recurring_tasks.rake:79`) periodically recomputes the count.

---

## Frontend consumers

(See **AiJobApplicationSummaryStatus → Every reader** for the per-site detail. Summary of serializers, hooks, components, and websocket handlers.)

- **Serializers:** `Api::V1::AiJobApplicationSummaryStatusSerializer` (attributes `:4-6`, `published_at_timestamp` method `:8-10`); embedded in `ShallowJobApplicationSerializer` (`:23-24`, list) and `JobApplicationSerializer` (`:40-41`, detail).
- **Hooks:** `useJobApplication.ts` (list key `:185`; `setQueryData` in `onSuccess` `:229`); `useAiJobApplicationSummary.ts:45` (`enabled` gate on the summary id).
- **Components:** `JobApplicationListContainer.tsx` (`:220,:226,:235,:236`) → `JobApplicationNavItem.tsx` (props `:17-18`, Harvey ball `:26-29`); `PlatoTab.tsx` (`:42,:46,:50,:52,:127,:129,:130,:151,:154,:187,:210,:218`); `JobApplicationActivity.tsx:79-91`; `bulkAiSummaryCount.ts:37-41,:46`; `Plato/PlatoOverviewCallout.tsx` (`:13,:40-47`, no callers).
- **Websocket handlers:** `WebsocketJobChannelHandler.tsx` (`ai_summary_status_change` `:73-76`, `ai_summary_succeeded` `:77-81`); `WebsocketGlobalChannelHandler.tsx` (`AI_SUMMARY_COMPLETE` `:227`, `AI_SUMMARY_FAILED` `:241`, `AI_SUMMARY_BULK_FAILED` `:253`, `AI_SUMMARY_BULK_COMPLETE` `:281`, `attachExternalResumeComplete` `:152-154`).

### WebSocket actions

| Action | Broadcast from | Channel | Frontend handler |
|---|---|---|---|
| `AI_SUMMARY_COMPLETE` | `GenerateAiJobApplicationSummaryJob#broadcast_completion` (only if requesting user) | GlobalChannel | toast; invalidates `jobApplicationsForStage` (`:227`) |
| `AI_SUMMARY_FAILED` | `TextractResult#broadcast_ai_summary_failed` | GlobalChannel | warning toast; invalidates `jobApplicationsForStage` (`:241`) |
| `AI_SUMMARY_BULK_COMPLETE` / `_FAILED` | `BulkGenerateAiSummariesJob#notify_complete/#notify_failure` (whole-batch and normal-path `succeeded.zero? && failed.positive?` `:113-114`) | GlobalChannel | toast + invalidate `jobApplicationsForStage` (`:281`/`:253`); mailer `.deliver_later` |
| `ai_summary_status_change` | `find_or_create_ai_job_application_summary_status.rb:16-20`; `ai_job_application_summary.rb:107` (`broadcast_status_change`) | JobChannel | invalidates `['aiJobApplicationSummary', id]` + `['jobApplication', id]` (not the list) |
| `ai_summary_succeeded` | `ai_job_application_summary.rb:93-97` (after status row → current) | JobChannel | invalidates `['jobApplicationsForStage', hiringStageId]` |
| `attachExternalResumeComplete` | `attach_external_resume_url_job.rb:11` | GlobalChannel | invalidates `['jobApplication', id]` |

The infinite list is refreshed by terminal/completion events (JobChannel `ai_summary_succeeded` plus the GlobalChannel `AI_SUMMARY_*` events, all of which invalidate `jobApplicationsForStage` and match the stage-keyed list query by react-query prefix); it does not respond to the per-status `ai_summary_status_change` event.

---

## Feature gates

| Gate | Type | Scope | Checked where |
|---|---|---|---|
| `TEXTRACT_RESUME_PROCESSING` | Flipper | Per-organization | `job_application.rb:167` (`enqueue_new_job_application`, model-side: T1/T3/T4/T5/T6); `job_applications_controller.rb:113` (update, controller-side: T2). Not in `QueueBulkAiSummaryJobs` or `ValidateAiSummaryGeneration` |
| `AI_APPLICANT_SUMMARY` | Flipper | Per-organization | `ValidateAiSummaryGeneration`, `QueueBulkAiSummaryJobs` |
| `ai_credits_available?` | Balance | Per-organization | `ValidateAiSummaryGeneration`, `QueueBulkAiSummaryJobs` |
| `should_auto_generate_ai_summaries?` | Setting | Per-job (org fallback) | Bridge else branch only (`textract_result.rb:138`) |
| `has_job_description?` | Guard | Per-job | `ValidateAiSummaryGeneration:29` |
| `can_use_ai_credits?` | Policy | Per-user role | `AiJobApplicationSummaryPolicy` (controller auth) |
| Controller create gate (S-A) | exists/authorize | Per-job-application + per-user | `ai_job_application_summaries_controller.rb:5` (404 scope) + `:6` `authorize :ai_job_application_summary, :create?` |

---

## Trigger matrix

### Textract triggers
| # | Action | Entry point | Resume source | Flipper gate | Status row | Notes |
|---|---|---|---|---|---|---|
| 1 | New job app | `after_commit :enqueue_new_job_application` (`:45/164-171`) | Attached at creation | TEXTRACT_RESUME_PROCESSING (model `:167`) | created `'none'` | All 8 created_via; no resume → no `TextractResult` |
| 2 | Manual resume upload/replace | Controller update (`:107-116`, param change-detection) | Form upload | TEXTRACT_RESUME_PROCESSING (controller `:113`) | untouched by submit; staled via `update_all` | No summary created here; blank `:resume` → no Textract job (gate `:110`); flag OFF at controller → resume replaced, no Textract job; auto-continuation (auto-gen ON) → status row `regenerating`, no credit, no toast; auto-gen OFF (post-Textract) → row stays `current` with stale data; resume removal → no `TextractResult` |
| 3 | Clone | `clone_to_job` (`:132-145`) → save → after_commit | Conditional blob copy (`if has_resume`) | TEXTRACT_RESUME_PROCESSING (model `:167`) | created `'none'` | Fresh independent `TextractResult`; no-resume original → none; candidate-already-in-target → no save, no record |
| 4 | Customer API apply | `apply` (`:62`) → 3 interactors in one transaction | Base64 (required only if job_settings) | TEXTRACT_RESUME_PROCESSING (model `:167`) | created `'none'` | Save fires inside `CreateJobApplication`; no summary created; resume-less → no `TextractResult`; flag OFF → resume attached, no `TextractResult` |
| 5 | Customer API import | `import` (`:104,107`) → 2 interactors | Base64 (optional) | TEXTRACT_RESUME_PROCESSING (model `:167`) | created `'none'` | Omits `CompleteJobApplication`; no-resume → no `TextractResult`; flag OFF → no `TextractResult`; duplicate/question_responses/oversized-resume → rollback, no record |
| 6 | CSV import | `ImportJobCandidatesFromCsvJob` (`:14-22`) | External URL (conditional `:pending`/`nil`) | TEXTRACT_RESUME_PROCESSING (model `:167`) | created `'none'` | `has_resume` false → Textract exits early (only when flag ON); no `TextractResult` even after later attach (T7) |
| 7 | External URL attach | Controller show → `JobApplication::AttachExternalResumeUrlJob` (`:641-657`) | Downloaded | N/A | unchanged | Textract not triggered; `:uploaded`/`:error` are resting; no retry on error |
| 8 | Bulk backfill | `QueueBulkAiSummaryJobs` (`:23,28-30`) | Already attached | Not checked | unchanged | resume-but-no-textract; not in current run; no de-dup guard; signaled via `any_textract_pending` |
| 9 | Manual generate, no `TextractResult` | `ValidateAiSummaryGeneration` (`:38-42`) | Already attached | AI_APPLICANT_SUMMARY | via generate flow | No-Textract path: submits Textract + builds/reuses a `textract_processing` summary (carries requesting user). Ready path: builds `:pending` summary + immediately enqueues `GenerateAiJobApplicationSummaryJob` (`create_ai_summary_generation.rb:60-74`, requesting-user arg without safe-nav at `:73`); an active non-stale summary on the firing result is reused without build/enqueue (`:41-44`), a mismatched one is staled (`:37`) |

### AI summary triggers
| # | Action | Entry point | Create interactor | Auto-gen check | User broadcast | Credits |
|---|---|---|---|---|---|---|
| A | Manual single | Controller create | `CreateAiSummaryGeneration` | No | AI_SUMMARY_COMPLETE | 1 on success |
| B | Bulk | `BulkAiJobApplicationSummariesController#create` → `QueueBulkAiSummaryJobs` → `BulkGenerateAiSummariesJob` | `CreateBulkAiSummaryGeneration` | No | AI_SUMMARY_BULK_COMPLETE / _FAILED (also normal-path _FAILED when succeeded=0; none if empty working set) | 1 per success |
| C | Auto-generate (callback else) | `TextractResult` after_commit | none (enqueues job directly) | Yes (and validate.success?) | None (no requesting user) | No summary, no credit if none pre-exists (case 1); a pre-existing non-succeeded summary advances (case 2) and charges only if its `textract_result_id` matches the firing result; no credit if prior stale-succeeded (case 3 = S-D) |
| D | Resume-replacement auto-regen | Bridge else after new result | none | Yes (and validate.success?) | None | No credit (`self.ai_job_application_summaries` empty on new result); no new summary; status row `regenerating` (auto-gen ON) or `current` with stale data (OFF) |
| E | Textract handoff (callback if) | `TextractResult` after_commit, waiting summary | none (summary already exists) | No | AI_SUMMARY_COMPLETE (requesting user threaded) | 1 on success |

---

## Write-site coverage (X0 census)

The X0 write-site census, as a factual list. Every X0 `app/` write site is owned by at least one trigger/structural path. Grouped by target table.

**TextractResult** — `submit_resume_to_textract.rb:22/33/39`, `get_resume_text_from_textract.rb:31/40/47`: T1,T2,T3,T4,T5,T8,T9,S-D,S-E,S-C (submit/poll chain). `get_resume_text_from_textract.rb:31` is the sole `.update` (callback-firing) write and the only site writing both `textract_job_status` and `textract_job_result_text` in one call (its `saved_change_to_textract_job_result_text?` triggers the bridge); all others use `update_columns`.

**AiJobApplicationSummary (status + stale + key columns)** — `create_ai_summary_generation.rb:37/47-53/60-70`: S-A,T9. `create_bulk_ai_summary_generation.rb:41` (`update_columns(stale: true)`, the STALE-REBUILD discard of a textract-mismatched active summary) `/50-57`: S-B,T8. `summary/generate.rb:32/35-39/64-68/175/180/184`: S-A,S-B,S-C (case 2),S-E,X3. `orchestrate.rb:72`: S-A,S-E,X3. `score_job_application.rb:23/32/45/119-124/130/135/139`: S-A,S-E,X3. `integrate_analysis.rb:49-53/59/64/68`: S-A,S-E,X3. `generate_…job.rb:19/44`: S-A,S-C,S-E (both write `:failed`, never `:retrying`). `submit_resume_to_textract.rb:19` (stale `update_all`): T1,T2,T3,T4,T5,T8. `submit_resume_to_textract.rb:26` (`waiting_summary&.update_columns(textract_result_id: @textract_result.id)`, the waiting-summary relink): T9,S-E,S-A.

**AiJobApplicationSummaryStatus** — `find_or_create_…status.rb:15/25-37`: T1,T3,T4,T5,T6,S-A,S-B,S-D,X1,X2. `textract_result.rb:104-107` (`set_initial_summary_pending`): S-A,S-B,S-C,S-D,S-E,X1,X2. `ai_job_application_summary.rb:74-80` (`update_summary_status_record`): S-A,S-C,S-E,X1,X2.

**AiJobCriteria** — `job.rb:696/699`, `extract_criteria.rb:28/32/62/122/132-140/146/151/155`, `score_job_application.rb:44`, `extract_job_criteria_job.rb:9/28`: X3. Only the `:succeeded` write (`extract_criteria.rb:132-140`) uses `.update` to fire the callback; all others `update_columns`.

**BulkAiSummaryJobApplication** — `queue_bulk_ai_summary_jobs.rb:65-69`, `bulk_generate_ai_summaries_job.rb:54/66/86/178-180`: T8,S-B.

**JobApplication / external_resume_status / resume attachment** — `job_application.rb:399/400/401/648/649/651/654`, `job_applications_controller.rb:107/139`, `import_job_candidates_from_csv_job.rb:20-21`: T2,T3,T6,T7. Outside the X0 AI/Textract-record scope but covered by the trigger slices.

**Record-destroy sites adjacent to the four records** (outside the "writes a status/key column" scope, cross-referenced): `textract_result.rb:134` `ai_summary_waiting_on_textract.destroy` (bridge validation-fail branch) — S-E/C bridge. `ai_job_application_summary.rb:47-54` `destroy_previous_textract_results` (`destroy_all` of prior non-succeeded `TextractResult` records on a summary `→succeeded`) — S-A/S-E/X3. `get_resume_text_from_textract_job.rb` `cleanup_orphaned_summary` destroys the `textract_processing` summary on retry-exhaustion.

Every X0 `app/`/`lib` production write site is owned by ≥1 trigger/structural path. No bang enum methods write any of the four records (grep returned only `invites_controller.rb:105` on the out-of-scope `Invite` model).

**Rake-layer write sites** (outside the trigger/structural paths):
- `lib/tasks/ai_bulk_extract.rake` writes `AiJobApplicationSummary.status` at `:34-38` `AiJobApplicationSummary.create(status: :in_progress)` (`:in_progress` is not a value in the current 10-value enum), `:59-62` `summary.update(status: :extracted)` (`:extracted` is not a value), `:89` `summary&.update(status: :failed)`. Reachable only via the rake task; the first two assign enum values not present in the current 10-value `AiJobApplicationSummary` enum, which raises `ArgumentError` at runtime (Rails enum setter on an unknown value).
- `lib/tasks/housekeeping_tasks.rake:409` and `:445` enqueue `SubmitResumeToTextractJob` (backfill/replay).

**Items the slices flagged but did not trace to terminal:** `NewJobApplicationJob` and `DocxToPdfJob` (enqueued by `enqueue_new_job_application`, out of the Textract/AI scope); `RoleFitFilterable#apply_role_fit_filter` (bulk controller, module body not opened); the bulk result mailer bodies `BulkJobApplicationAiSummaryResultMailer.complete/.failed` (both use `.deliver_later`).

---

## Changes since the 2026-06-15 map

Plain statements of what the current code does where it differs from the prior `textract-ai-summary-map-6-6-2026` map (the body above reflects current code; this list highlights the deltas):

- The `enqueue_new_job_application` callback is registered at `job_application.rb:45` (body `:164-171`) and unconditionally calls `find_or_create_ai_job_application_summary_status` (`:170`), creating the `AiJobApplicationSummaryStatus` row (`'none'`) for every created job_application, not Flipper-gated. All 8 `created_via` values reach it.
- `AiJobApplicationSummaryStatus` is a 4-value status enum (`none`/`initial_summary_pending`/`current`/`regenerating`), not a 10-value pipeline mirror. `regenerating` is status value 3; there is no `regenerating` boolean column. The `after_commit :create_status_record` callback no longer exists on `AiJobApplicationSummary`; row creation moved to `FindOrCreateAiJobApplicationSummaryStatus`.
- `update_summary_status_record` sets `status: 'current'` (value 2) via `.update` and writes no `regenerating` column (`ai_job_application_summary.rb:74-80`). The `regenerating` change is written via `update_columns` (`find_or_create_ai_job_application_summary_status.rb:15`).
- T2's change-detection surface is the controller `update` action, not a model callback. The Textract enqueue is gated on `temp_params.key?(:resume) && temp_params[:resume].present?` (`:110`) and, separately, on a controller-side `TEXTRACT_RESUME_PROCESSING` check (`:113`).
- On the T2/S-D resume-replacement auto-continuation, the status row reaches `regenerating` and (with auto-gen ON) remains there with the prior denormalized data; no credit is charged. (The prior map's "charges 1 credit for the old summary" does not hold: `textract_result.rb:77` is TextractResult-scoped and empty on the new result, so `:82` returns before `:84`.) The manual (S-A) or bulk (S-B) regeneration that builds a fresh `:pending` summary recovers the row to `current`.
- The clone action is `clone_to_job` at `job_applications_controller.rb:132-145` (route `config/routes.rb:282`); `dup` copies attributes only and the clone creates a fresh `TextractResult` by re-submitting the conditionally re-attached `resume.blob`. The `CloneJobApplication` interactor has no callers.
- The customer-API apply save that fires the create callback is inside `CreateJobApplication`, not after `CompleteJobApplication`. Import omits `CompleteJobApplication`.
- CSV import sets `external_resume_status` conditionally (`:pending` only for a present Resume URL, else nil); the present-URL row has no file at creation and remains a no-`TextractResult` row even after a later `show` attaches the file via `update_column` (which bypasses callbacks).
- `with_textract_results` is a bare `joins(:textract_results)` (`job_application.rb:115`) — it does not check `textract_job_result_text`; a no-text `TextractResult` counts as ready and defers at iteration time. The bulk worker routes through the new `CreateBulkAiSummaryGeneration` interactor before `generate_ai_summary_with_credit_flow`.
- T7's job is the namespaced `JobApplication::AttachExternalResumeUrlJob`; `attach_external_resume_url` is at `job_application.rb:641-657`. It has `:uploaded` and `:error` outcomes (the prior map documented only `:uploaded`); after attachment Textract is not triggered.
- `SubmitResumeToTextractJob.perform_later` has 6 app-code enqueue sites plus 2 rake sites (the prior map's list omitted `validate_ai_summary_generation.rb:55` and both rake sites).
- S-E enqueues the handoff job with the requesting user (`textract_result.rb:128-131`), so `AI_SUMMARY_COMPLETE` broadcasts on completion (the prior map said S-E had no user broadcast). The waiting `textract_processing → extracting` transition is via `.update` (`generate.rb:31-33`).
- `ValidateAiSummaryGeneration` adds the `has_job_description?` fail-fast guard (`:29`). The no-`TextractResult` branch is at `:38-42` (the new guard shifted the lines from the prior map's `:37-41`); `context.textract_result` is assigned unconditionally at `:31-32`.
- The bridge else (auto-generate) branch has three downstream cases (no pre-existing summary → no summary/no credit; pre-existing non-succeeded → advances, charges conditionally on the `textract_result_id` match; prior stale-succeeded → no credit), not a single uniform outcome.
