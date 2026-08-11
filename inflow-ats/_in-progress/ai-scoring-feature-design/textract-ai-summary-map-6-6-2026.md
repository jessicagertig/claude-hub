# Textract & AI Summary Flows — Complete Code Trace

**Last updated:** 2026-06-15
**Branch:** `feature-ai-summaries-integrating-scoring-v4`
**Reflects:** All Phase 1 changes + No TextractResult Path Fix + Scoring/Orchestration + AiJobApplicationSummaryStatus denormalized columns

## Overview

This document traces every code path for both Textract resume processing and AI applicant summary generation, from trigger to final result. Both flows are interconnected: Textract extracts text from resumes, and AI summaries consume that text through a multi-stage AI pipeline (4 summary calls + 1-5 scoring calls + 1 display call + 1 integration call). The bridge between them is the `TextractResult#queue_ai_summary_job` after_commit callback.

---

## Part 1: Textract Resume Processing Flow

### Core Service Chain

Every Textract trigger follows this chain:

```
[Trigger] → SubmitResumeToTextractJob → SubmitResumeToTextract#submit_resume
  → AWS Textract API (async job created)
  → TextractResult record created (status: in_progress)
  → If textract_processing summary exists with nil textract_result_id:
      update its textract_result_id to the new TextractResult
  → GetResumeTextFromTextractJob (scheduled +2 min)
    → GetResumeTextFromTextract#parse_resume_text
      → AWS Textract API (poll for result)
      → TextractResult updated with extracted text (status: succeeded)
      → On retry exhaustion: orphaned textract_processing summary destroyed,
        AI_SUMMARY_FAILED broadcast to requesting user
```

### Submission: `SubmitResumeToTextract#submit_resume`
**File:** `app/services/submit_resume_to_textract.rb`

1. Guard: returns early if job_application not found or has no resume (lines 9-10)
2. Selects resume file: uses `resume_docx_to_pdf` if available, otherwise `resume` (line 15). Calls AWS Textract via `TextractResumeParser::Client#send_to_textract` (line 16)
3. Conditional stale marking (lines 18-20): if NO `textract_processing` + `stale: false` summary exists → marks ALL summaries `stale: true` via `update_all`. If one exists → skips staling entirely.
4. Creates new TextractResult with `textract_job_id` from AWS and status `in_progress` (line 22)
5. On save: finds any `AiJobApplicationSummary` with `status: :textract_processing`, `stale: false`, and `textract_result_id: nil` on the job application, and calls `update_columns(textract_result_id: @textract_result.id)` on it (lines 25-26)
6. Schedules `GetResumeTextFromTextractJob` with 2-minute delay (line 27)
7. On AWS errors: sets TextractResult status to `failed` via `update_columns` (lines 31-40)

### Polling: `GetResumeTextFromTextract#parse_resume_text`
**File:** `app/services/get_resume_text_from_textract.rb`

1. Finds the most recent TextractResult for the job_application via `order(created_at: :desc).first` (line 11)
2. Self-healing: if `textract_job_id` is nil on the TextractResult (lines 14-17), re-submits to Textract via `SubmitResumeToTextractJob.perform_later` and returns early
3. Polls AWS via `TextractResumeParser::Client#get_text` (line 20)
3. If `succeeded`: uses `update` to save status, full JSON result, and extracted text (lines 19-23)
   - This triggers `after_commit :queue_ai_summary_job` on TextractResult, which bridges to AI summary generation
4. If `failed` or still processing: raises `CustomErrorTextract` to trigger retry (lines 25-31)
5. On `InvalidJobIdException`: marks as failed via `update_columns` (lines 33-35)

### Polling Job: `GetResumeTextFromTextractJob`
**File:** `app/jobs/get_resume_text_from_textract_job.rb`

- Queue: `:default`
- Retry: `CustomErrorTextract`, wait 5 minutes, max 3 attempts
- Total polling window: up to ~17 minutes (2 min initial delay + 3 × 5 min retries)
- **On retry exhaustion:** calls `cleanup_orphaned_summary` class method — finds `textract_processing` summary on the job application, destroys it, broadcasts `AI_SUMMARY_FAILED` via `TextractResult#broadcast_ai_summary_failed` to the requesting user. Leaves the failed TextractResult intact as an audit trail.

---

### Trigger Points (All 8)

#### Trigger 1: New Job Application Created
**Chain:** `JobApplication after_commit(:enqueue_new_job_application, on: :create)` → `SubmitResumeToTextractJob`

**File:** `app/models/job_application.rb:150-156`
- Fires on ANY new job_application creation (all sources)
- Guards: `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)`
- Guards: `has_resume` (checked inside SubmitResumeToTextract)
- Also enqueues: `NewJobApplicationJob`, `DocxToPdfJob`

**Sources that create job_applications (all fire this callback):**
- External job board candidate submission
- Internal manual creation
- Customer API apply (`POST /v1/hire/job_applications/apply`)
- Customer API import (`POST /v1/hire/job_applications/import`)
- CSV bulk import
- Clone to job

#### Trigger 2: Manual Resume Upload/Replacement (Internal)
**Chain:** Controller update action → `SubmitResumeToTextractJob`

**File:** `app/controllers/api/v1/job_applications_controller.rb:84-123`
- Explicit check: `temp_params.key?(:resume) && temp_params[:resume].present?` (line 106)
- Reason: ActiveStorage doesn't support ActiveRecord dirty tracking
- Guards: `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, current_organization)`
- Also enqueues: `DocxToPdfJob`
- Runs AFTER `job_application.update(temp_params)` succeeds (line 103)

#### Trigger 3: Clone Job Application to Another Job
**Chain:** Controller clone action → `job_application.save` → `after_commit(:enqueue_new_job_application)`

**File:** `app/controllers/api/v1/job_applications_controller.rb:128-141`
- `clone_to_job_at_hiring_stage` builds a dup with `resume.attach(resume.blob)` (copies blob reference)
- Controller calls `.save` → fires the `after_commit :enqueue_new_job_application` callback
- Textract processes the cloned job_application's resume independently

#### Trigger 4: Customer API — Apply
**Chain:** Interactor creates candidate + job_application → `candidate.save` → `after_commit` on job_application

**Files:**
- `app/controllers/api_public/v1/hire/job_applications_controller.rb:62-94` (apply action)
- `app/interactors/customer_api/create_job_application.rb` (builds and saves)
- Resume from `decoded_resume` parameter (base64 decoded, attached via StringIO)
- `created_via: 'created_via_customer_api_apply'`

#### Trigger 5: Customer API — Import
**Chain:** Same as Apply, different endpoint

**File:** `app/controllers/api_public/v1/hire/job_applications_controller.rb:97-126`
- Same interactor chain as Apply
- `created_via: 'created_via_customer_api_import'`

#### Trigger 6: CSV Bulk Import
**Chain:** CSV upload → `ImportJobCandidatesFromCsvJob` → `CreateCandidateJobApplication` → `candidate.save` → `after_commit`

- Resume source: `external_resume_url` stored on job_application, NOT immediately attached
- `external_resume_status: :pending` — resume not yet downloaded
- Textract fires on job_application creation, but `has_resume` is false → SubmitResumeToTextract returns early
- Resume gets attached later via Trigger 7

#### Trigger 7: External Resume URL Attachment (Lazy Download)
**Chain:** Controller show action → `AttachExternalResumeUrlJob` → `attach_external_resume_url`

**File:** `app/models/job_application.rb:626-642`
- Condition: `external_resume_status_pending? && !has_resume`
- Downloads resume from URL, attaches as `resume.pdf`
- Uses `update_column(:external_resume_status, :uploaded)` — no callbacks
- **TEXTRACT IS NOT TRIGGERED** after this attachment
- Gap: candidates from CSV import with external URLs never get Textract processing automatically

#### Trigger 8: Bulk AI Summary Generation (Textract Backfill)
**Chain:** `QueueBulkAiSummaryJobs` interactor → `SubmitResumeToTextractJob` for resume-but-no-textract candidates

**File:** `app/interactors/queue_bulk_ai_summary_jobs.rb:22-30`
- Filters: `with_resume` but NOT `with_textract_results`
- Kicks off `SubmitResumeToTextractJob.perform_later(id)` for each
- These candidates are NOT included in the current bulk AI summary run
- They'll be ready for a subsequent bulk run after Textract completes
- Note: does NOT check `TEXTRACT_RESUME_PROCESSING` flipper here (only checks `AI_APPLICANT_SUMMARY`)

#### Trigger 9: Manual AI Summary Generation with No TextractResult
**Chain:** User clicks "Generate" → `ValidateAiSummaryGeneration` → `SubmitResumeToTextractJob`

**File:** `app/interactors/validate_ai_summary_generation.rb:37-41`
- When `@job_application.latest_textract_result` is nil (resume exists but never submitted to Textract)
- Calls `SubmitResumeToTextractJob.perform_later(@job_application.id)`
- Sets `context.textract_pending = true` and returns (validation succeeds)
- `CreateAiSummaryGeneration` then creates an `AiJobApplicationSummary` with `status: :textract_processing` and `textract_result_id: nil`
- `SubmitResumeToTextract` (when the job runs) updates `textract_result_id` on this summary after creating the TextractResult
- Frontend shows "Resume is being processed. Summary will generate automatically."

---

### Textract Data Model

**TextractResult** (`app/models/textract_result.rb`)
```
belongs_to :job_application
has_many :ai_job_application_summaries, inverse_of: :textract_result, dependent: :destroy

Status enum: not_started(0), in_progress(1), succeeded(2), failed(3)

Columns: textract_job_id, textract_job_status, textract_job_result (jsonb),
         textract_job_result_text (extracted plain text), job_application_id
```

**JobApplication** (`app/models/job_application.rb:28`)
```
has_many :textract_results, dependent: :destroy
```
- Model supports multiple TextractResults per job_application
- "One per job_application" is enforced only by `SubmitResumeToTextract` marking previous summaries as stale

---

## Part 2: AI Summary Generation Flow

### Core Pipeline Chain

**Manual/bulk triggers** follow this chain:

```
[Trigger] → ValidateAiSummaryGeneration → CreateAiSummaryGeneration
  → AiJobApplicationSummary record created (status: pending or textract_processing)
  → GenerateAiJobApplicationSummaryJob
    → TextractResult#generate_ai_summary_with_credit_flow
      → AiJobApplicationAction::Orchestrate#call
        → Summary::Generate#generate (4 AI calls: extraction, assessment, comparison, summary)
        → Scoring::ScoreJobApplication#score (1-5 scoring calls + 1 display call)
        → Scoring::IntegrateAnalysis#integrate (1 integration call)
      → CreateAiCreditBalanceTransaction (1 credit on success)
      → NotifyZeroAiCredits / NotifyLowAiCredits
```

**Auto-generation triggers** (TextractResult callback) skip `CreateAiSummaryGeneration`:

```
TextractResult after_commit :queue_ai_summary_job
  → ValidateAiSummaryGeneration (no CreateAiSummaryGeneration)
  → GenerateAiJobApplicationSummaryJob
    → TextractResult#generate_ai_summary_with_credit_flow
      → AiJobApplicationAction::Orchestrate#call
        → (same pipeline as above)
      → CreateAiCreditBalanceTransaction (1 credit on success)
      → NotifyZeroAiCredits / NotifyLowAiCredits
```

### Validation: `ValidateAiSummaryGeneration`
**File:** `app/interactors/validate_ai_summary_generation.rb`

Checks in order (fails fast):
1. Job application exists
2. Organization exists
3. Flipper gate: `AI_APPLICANT_SUMMARY` enabled for organization
4. Resume uploaded: `job_application.has_resume`
5. Credits available: `organization.ai_credits_available?`
6. TextractResult exists: finds latest by `created_at DESC`
   - **If nil:** kicks off `SubmitResumeToTextractJob.perform_later(@job_application.id)`, sets `context.textract_pending = true`, returns (validation succeeds)
   - If text present: `context.textract_pending = false`
   - If failed (both current and previous failed): error "Resume processing has failed. Try uploading a different resume file."
   - If failed (only current): kicks off `SubmitResumeToTextractJob`, sets `context.textract_pending = true`
   - Otherwise (in_progress/not_started): `context.textract_pending = true`

Outputs: `context.textract_result` (may be nil), `context.textract_pending`

### Creation: `CreateAiSummaryGeneration`
**File:** `app/interactors/create_ai_summary_generation.rb`

1. **Active summary check** (lines 30-44): looks for existing non-failed, non-stale summary
   - If found and textract_result_id differs from current latest: marks stale, proceeds
   - If found and current: returns it silently (no new generation)

2. **Textract pending path** (lines 46-55): creates summary with `textract_processing` status
   - Sets `textract_result: validation_result.textract_result` (may be nil for the no-TextractResult path)
   - Does NOT enqueue any job — relies on TextractResult callback to trigger generation later

3. **Textract ready path** (lines 57-74): creates summary with `pending` status
   - Immediately enqueues `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id, user_id)`

### Generation Job: `GenerateAiJobApplicationSummaryJob`
**File:** `app/jobs/generate_ai_job_application_summary_job.rb`

- Queue: `:default`
- Retry: `CustomErrorAiSummary`, wait 2 minutes, max 3 attempts
- Parameters: `textract_result_id:`, `requesting_organization_user_id:` (nil for auto-generation)
- Calls `textract_result.generate_ai_summary_with_credit_flow` (line 32)
- If `requesting_organization_user_id` provided AND no exception: broadcasts `AI_SUMMARY_COMPLETE` to user's GlobalChannel (line 34)
- On `CustomErrorAiSummary`: re-raises for retry, does NOT broadcast (line 35-38). Broadcast only fires in the retry-exhaustion block (line 20) after all attempts fail.
- On `StandardError`: marks summary `failed`, broadcasts completion if `requesting_organization_user_id` provided, does NOT re-raise (line 39-46)
- Retry exhaustion block: marks summary `failed`, broadcasts completion (line 13-22)

### Orchestration: `TextractResult#generate_ai_summary_with_credit_flow`
**File:** `app/models/textract_result.rb:61-82`

1. Calls `generate_ai_summary` → `AiJobApplicationAction::Orchestrate.new(textract_result_id: id).call`
2. Fetches latest AI summary: `ai_job_application_summaries.order(created_at: :desc).first`
3. Guard: `return unless summary&.status_succeeded?`
4. Calls `CreateAiCreditBalanceTransaction.call(summary: summary)` — 1 credit
5. Guard: `return unless consume_result.success?` — if credit transaction fails, notifications are skipped
6. Calls `NotifyZeroAiCredits.call` and `NotifyLowAiCredits.call`

### Orchestrator: `AiJobApplicationAction::Orchestrate`
**File:** `app/services/ai_job_application_action/orchestrate.rb`

Central dispatcher. Finds the latest AiJobApplicationSummary for the job_application (line 15: `order(created_at: :desc).first` — **does NOT filter by stale**), reads its status, and dispatches to the appropriate stage:

```
pending / textract_processing / extracting / retrying → run_summary → check_criteria_and_score
summarizing (incomplete)                               → run_summary → check_criteria_and_score
summarizing (complete)                                 → check_criteria_and_score
awaiting_job_criteria                                  → check_criteria_and_score
scoring (no criteria_results)                          → run_scoring → run_integration
scoring (has criteria_results)                         → run_integration
integrating                                            → run_integration
succeeded / failed                                     → return (no-op)
```

**`run_summary`** → `Summary::Generate.new(textract_result_id:).generate` + reload
**`check_criteria_and_score`** → guards on failed/incomplete, sets `awaiting_job_criteria`, checks `AiJobCriteria`:
  - If criteria succeeded → `run_scoring` → `run_integration`
  - If criteria pending/in_progress → return (waits for `AiJobCriteria` callback to re-trigger)
  - If criteria blank, failed, or retrying → `job.extract_job_criteria` → return (triggers extraction unless criteria is pending or in_progress)
**`run_scoring`** → `Scoring::ScoreJobApplication.new(...).score` + reload
**`run_integration`** → guards on `status_failed?` and `criteria_results.present?` (skips silently if either fails) → `Scoring::IntegrateAnalysis.new(...).integrate`

### Stage 1 — Summary: `AiJobApplicationAction::Summary::Generate#generate`
**File:** `app/services/ai_job_application_action/summary/generate.rb`

**Pre-pipeline logic** (lines 30-40):
- Finds latest AiJobApplicationSummary for the job_application: `order(created_at: :desc).first`
- If existing with status `pending`, `textract_processing`, `extracting`, or `retrying`: reuses it (transitions to `extracting` via `update_columns`)
- Otherwise: creates new AiJobApplicationSummary with `extracting` status and `textract_result: @textract_result`

**Status transitions within this stage:** `pending/textract_processing → extracting → summarizing`

**Call 1 — Extraction** (OpenAI)
- Prompt: `AiJobApplicationAction::Summary::Prompts::ResumeStructuredData`
- Input: raw resume text + job title
- Output: work_experience, education, skills, certifications (structured JSON)
- Calculates `total_months_experience` from work_experience entries
- Updates summary: status → `summarizing`, stores structured_data

**Call 2 — Assessment** (OpenAI)
- Prompt: `AiJobApplicationAction::Summary::Prompts::ResumeAssessment`
- Input: anonymized data via `AnonymizeForAi`
- Output: primary_domain, secondary_domain, career_narrative, key_skills, standout_accomplishments, experience_classifications
- Calculates `months_by_domain` using interval merging
- Only runs if `work_experiences.present?`

**Call 3 — Comparison** (OpenAI)
- Prompt: `AiJobApplicationAction::Summary::Prompts::ResumeComparison`
- Input: months_by_domain, key_skills, career_narrative, job_title, stated_experience
- Output: applicable_experience, gaps, overlap_summary
- Only runs if `job_title.present? && months_by_domain.present?`

**Call 4 — Summary** (OpenAI)
- Prompt: `AiJobApplicationAction::Summary::Prompts::ResumeSummary`
- Input: distilled outputs from Calls 2 & 3 (no raw resume text)
- Output: headline, summary (text), role_analysis, applicable_experience, gaps, overlap_summary
- Final update: stores headline, summary_text, merged structured_data (does NOT set status — Orchestrate continues to scoring)

**Error handling (same pattern in all stages):**
- `CustomErrorAiSummary`: status → `retrying`, re-raises (triggers job retry)
- `JSON::ParserError`: status → `failed`, does NOT re-raise
- `StandardError`: status → `failed`, does NOT re-raise

**Each AI call creates an `AiApiRequest` record** with: organization_id, call_type, provider, model, input_tokens, output_tokens, cost, response_body

### Stage 2 — Scoring: `AiJobApplicationAction::Scoring::ScoreJobApplication#score`
**File:** `app/services/ai_job_application_action/scoring/score_job_application.rb`

**Pre-scoring:** Has a secondary criteria guard (lines 22-30) that checks `AiJobCriteria` — if not succeeded, sets `awaiting_job_criteria` and triggers `job.extract_job_criteria` if needed. This is a safety check redundant with `Orchestrate#check_criteria_and_score` (which performs the primary criteria check and dispatch). In normal flow, Orchestrate has already verified criteria succeeded before calling `run_scoring`.

**Status transitions within this stage:** `awaiting_job_criteria → scoring → integrating`

**Call 5 — Scoring** (Gemini)
- Prompt: `AiJobApplicationAction::Scoring::Prompts::JobApplicationScoring`
- Input: criteria (from `AiJobCriteria`) + resume text
- Output: per-criterion scores with tier, score (met/partially_met/not_met), reasoning
- Calculates `score_percentage` via `Scoring::Calculate.compute`
- **Boundary check:** if score within 5 points of 40, 60, or 80 → runs 4 MORE scoring calls, takes median. Total: 1-5 scoring calls.

**Call 6 — Display** (Gemini)
- Prompt: `AiJobApplicationAction::Scoring::Prompts::ScoringDisplay`
- Input: criteria_results from selected scoring run
- Output: per-criterion `display_sentence`
- Merges display sentences into criteria_results

**Final update:** `score_percentage`, `criteria_results`, status → `integrating`

### Stage 3 — Integration: `AiJobApplicationAction::Scoring::IntegrateAnalysis#integrate`
**File:** `app/services/ai_job_application_action/scoring/integrate_analysis.rb`

**Call 7 — Integrated Analysis** (OpenAI)
- Prompt: `AiJobApplicationAction::Scoring::Prompts::IntegratedAnalysis`
- Input: role_analysis, applicable_experience, gaps, overlap_summary, career_narrative, key_skills, standout_accomplishments, criteria_results, score_percentage
- Output: `integrated_role_analysis`

**Final update:** `integrated_role_analysis`, status → `succeeded`

### AiJobCriteria Re-trigger Mechanism
**File:** `app/models/ai_job_criteria.rb`

When `AiJobCriteria` transitions to `succeeded` (after_commit on update):
- `resume_waiting_summaries` callback fires
- Finds all `AiJobApplicationSummary` records with `status: :awaiting_job_criteria` for the job
- Enqueues `GenerateAiJobApplicationSummaryJob` for each (by `textract_result_id`)
- Orchestrate picks up where it left off (`awaiting_job_criteria` → `check_criteria_and_score` → `run_scoring`)

---

### Trigger Points (All 5)

#### Trigger A: Manual Single Generation (User Clicks "Generate")
**Chain:** Controller → Validate → Create → Job → Pipeline

**File:** `app/controllers/api/v1/ai_job_application_summaries_controller.rb`
```
POST /api/v1/job_applications/:id/ai_job_application_summaries
```
- Authorization: `AiJobApplicationSummaryPolicy#create?` → `can_use_ai_credits?`
- If textract ready: creates summary with `pending`, enqueues job immediately
- If textract pending (including no TextractResult): creates summary with `textract_processing`, no job enqueued
- If active summary exists: returns it silently (no regeneration)
- On completion: broadcasts `AI_SUMMARY_COMPLETE` to user via GlobalChannel

#### Trigger B: Bulk Generation (User Selects Multiple Candidates)
**Chain:** Controller → QueueBulkAiSummaryJobs → BulkGenerateAiSummariesJob → Per-candidate pipeline

**QueueBulkAiSummaryJobs** (`app/interactors/queue_bulk_ai_summary_jobs.rb`):
1. Validates: Flipper `AI_APPLICANT_SUMMARY` + credits available
2. Filters candidates into:
   - `ready_ids`: has resume AND has textract results
   - `pending_textract_ids`: has resume, no textract → kicks off `SubmitResumeToTextractJob` for each
   - No resume: silently skipped
3. Race-safe claiming via `BulkAiSummaryJobApplication` with partial unique index
4. Enqueues `BulkGenerateAiSummariesJob` with claimed IDs

**BulkGenerateAiSummariesJob** (`app/jobs/bulk_generate_ai_summaries_job.rb`):
- Uses job-iteration gem for resumable processing
- Max runtime: 10 minutes per iteration window
- `discard_on StandardError` with exhaustion block: marks remaining as failed, calls `notify_failure`
- `retry_on CustomErrorAiSummary` with exhaustion block: same cleanup
- On complete: broadcasts `AI_SUMMARY_BULK_COMPLETE` or calls `notify_failure` if all failed
- Notification mailer: `BulkJobApplicationAiSummaryResultMailer` with `.deliver_later`

#### Trigger C: Auto-Generation via TextractResult Callback
**Chain:** TextractResult after_commit → Validate → Job → Pipeline

**File:** `app/models/textract_result.rb:95-125`

Fires `after_commit :queue_ai_summary_job` on create or update.

**Guards:**
1. `textract_job_result_text.present?` — text must exist
2. `saved_change_to_textract_job_result_text?` — must be the triggering change
3. Organization must exist

**Two paths:**
- **Existing `textract_processing` summary found**: validates, enqueues `GenerateAiJobApplicationSummaryJob`
  - On validation failure: destroys summary, broadcasts `AI_SUMMARY_FAILED`
- **No existing summary + auto-generate enabled**: validates, enqueues job
  - Checks `job.should_auto_generate_ai_summaries?`

#### Trigger D: Resume Replacement → Auto-Regeneration — **BROKEN (see Gap 8)**
When a resume is replaced:
1. `SubmitResumeToTextract` marks non-`textract_processing` summaries as stale
2. Creates new TextractResult with `in_progress`
3. After Textract completes, callback auto-generates if setting is on
4. **BUG:** `Orchestrate` finds the stale succeeded summary (doesn't filter by `stale`), hits `succeeded` → returns. No new summary generated. `generate_ai_summary_with_credit_flow` then consumes a credit for the old summary.

#### Trigger E: Textract Processing Handoff
When user requests generation but Textract isn't done (or doesn't exist):
1. `CreateAiSummaryGeneration` creates summary with `textract_processing` status (may have nil `textract_result_id`)
2. `SubmitResumeToTextract` updates `textract_result_id` on the summary after creating the TextractResult
3. When Textract completes, callback finds this summary and triggers generation

---

### Auto-Generate Settings

**Resolution hierarchy:**
1. Per-job: `job.auto_generate_ai_summaries` enum → `default(0)`, `enabled(1)`, `disabled(2)` (with `_prefix: true`)
2. If `default`: falls through to org default
3. Per-org: `organization.settings['auto_generate_ai_summaries_enabled']` (boolean, default false)

**Method:** `Job#should_auto_generate_ai_summaries?` (`app/models/job.rb:875-883`)

**Checked at:** TextractResult callback only (auto-generation path). Manual and bulk triggers bypass this.

---

### AI Credits System

**Pre-flight:** `organization.ai_credits_available?` checked during validation (all paths)

**Consumption:** `CreateAiCreditBalanceTransaction` interactor (`app/interactors/create_ai_credit_balance_transaction.rb`)
- Cost: 1 credit per successful summary (CREDIT_COST = 1)
- Bucket priority: daily → monthly → addon_subscription → addon
- Creates immutable `AiCreditBalanceTransaction` ledger entry
- entry_type: `ai_summary_usage_debit`
- `counter_culture` maintains cached balance counters

**Notifications:** Run after consumption
- `NotifyZeroAiCredits`: sends email when balance hits zero (deduplicated via flag)
- `NotifyLowAiCredits`: sends email when balance drops below threshold (configurable per-org)

**Ledger:** `AiCreditBalanceTransaction` is INSERT-ONLY (`before_update` and `before_destroy` raise `ReadOnlyRecord`)

**Mailer:** `AiCreditNotificationMailer` — uses `select(&:is_admin)` for recipients (not `is_admin?`), templates `'user-ai-credit-balance-low'` and `'user-ai-credit-balance-zero'`

---

### AI Summary Data Model

**AiJobApplicationSummary** (`app/models/ai_job_application_summary.rb`)
```
belongs_to :job_application
belongs_to :textract_result, optional: true
has_many :ai_api_requests, as: :requestable
has_one :ai_job_application_summary_status

Status enum: pending(0), textract_processing(1), extracting(2), summarizing(3),
             awaiting_job_criteria(4), scoring(5), integrating(6), succeeded(7),
             retrying(8), failed(9)

Columns: structured_data (jsonb), headline, summary_text, score_percentage,
         criteria_results (jsonb), integrated_role_analysis,
         status, error_message, stale (boolean, default false),
         job_application_id, textract_result_id (nullable),
         requested_by_organization_user_id
```

**Callbacks:**
- `after_commit :create_status_record, on: :create` — `AiJobApplicationSummaryStatus.find_or_create_by(job_application:)` with `regenerating: false`. **BUG: uses `find_or_create_by` instead of hand-rolled find-then-act. On regeneration (record already exists), the block never executes — `regenerating` is never set to `true`.**
- `after_commit :destroy_previous_textract_results, on: :update` — when status changes to `succeeded`, destroys TextractResult records with `created_at` earlier than the summary's `textract_result`. Guards with `return unless textract_result` for nil safety.
- `after_commit :update_summary_status_record, on: :update` — when status changes to `succeeded`, updates `AiJobApplicationSummaryStatus` with denormalized columns: `ai_job_application_summary_id`, `regenerating: false`, `status`, `score_percentage`, `headline`, `integrated_role_analysis`. Uses `update_columns` (skips callbacks/validations).

**AiJobApplicationSummaryStatus** (`app/models/ai_job_application_summary_status.rb`)
```
belongs_to :job_application
belongs_to :ai_job_application_summary, optional: true

Status enum: pending(0), textract_processing(1), extracting(2), summarizing(3),
             awaiting_job_criteria(4), scoring(5), integrating(6), succeeded(7),
             retrying(8), failed(9)

Columns: regenerating (boolean, default false, not null),
         status, score_percentage, headline, integrated_role_analysis,
         ai_job_application_summary_id (nullable), job_application_id

Uniqueness: validates :job_application_id, uniqueness: true
```

One status record per job_application. Denormalized columns populated only when an associated summary reaches `succeeded`. `regenerating` is intended to signal "a completed review exists and a replacement is being generated" — **currently never set to `true` (broken/incomplete implementation).**

**AiJobCriteria** (`app/models/ai_job_criteria.rb`)
```
belongs_to :job
has_many :ai_api_requests, as: :requestable

Status enum: pending(0), in_progress(1), succeeded(2), failed(3), retrying(4)

Columns: criteria (jsonb), status, job_id
```

One per job. Extracted from job description via `Job#extract_job_criteria`. `after_commit :resume_waiting_summaries, on: :update` — when status changes to `succeeded`, enqueues `GenerateAiJobApplicationSummaryJob` for every `awaiting_job_criteria` summary on the job. **Note:** re-trigger fires WITHOUT `requesting_organization_user_id`, so no `AI_SUMMARY_COMPLETE` broadcast fires when criteria-triggered resumption completes — the user who originally triggered generation won't get a completion toast.

**JobApplication associations:**
```
has_many :ai_job_application_summaries, dependent: :destroy
has_one :latest_ai_job_application_summary, -> { order(created_at: :desc) }
has_one :ai_job_application_summary_status
```

---

## Part 3: The Bridge — How Textract Completion Triggers AI Summary

### Flow

```
Textract polling succeeds
  → GetResumeTextFromTextract calls update() on TextractResult
  → after_commit :queue_ai_summary_job fires
  → Callback checks for existing textract_processing summary OR auto-generate setting
  → Enqueues GenerateAiJobApplicationSummaryJob
```

### Callback-Dependent Paths (Triggers C, D, E)

1. **Auto-generation on new job application**: TextractResult created with `in_progress` → callback fires but text not present yet → returns early (correct). Textract polling completes → `update` saves text → callback fires again → text present + `saved_change_to_textract_job_result_text?` is true → checks auto-generate setting → enqueues job if enabled.

2. **Manual generation when Textract still processing**: `CreateAiSummaryGeneration` creates summary with `textract_processing` status. Textract polling completes → callback fires → finds the `textract_processing` summary → validates → enqueues job.

3. **Manual generation when no TextractResult exists**: `ValidateAiSummaryGeneration` kicks off `SubmitResumeToTextractJob`, creates summary with `textract_processing` and nil `textract_result_id`. `SubmitResumeToTextract` creates the TextractResult, updates `textract_result_id` on the summary. Textract polling completes → callback fires → same as #2.

4. **Auto-regeneration on resume replacement**: Existing summaries marked stale → new TextractResult created with `in_progress` → same as #1.

### Callback-Independent Paths (Triggers A, B)

1. **Manual generation when Textract already complete**: User clicks "Generate" → ValidateAiSummaryGeneration finds text ready → CreateAiSummaryGeneration creates `pending` summary → job enqueued immediately. Callback not involved.

2. **Bulk generation**: `QueueBulkAiSummaryJobs` filters for `with_textract_results` (text already present) → BulkGenerateAiSummariesJob iterates → per-candidate `ValidateAiSummaryGeneration` → `result.textract_result.generate_ai_summary_with_credit_flow` → Orchestrate. Does NOT go through `CreateAiSummaryGeneration`. Callback not involved.

---

## Part 4: Cleanup and Failure Handling

### Retry Exhaustion: GetResumeTextFromTextractJob

When Textract polling fails 3 times (exhausts `retry_on CustomErrorTextract`):
1. `cleanup_orphaned_summary` class method fires
2. Finds `textract_processing` summary on the job application (if any)
3. Extracts `requested_by_organization_user_id` from the summary
4. Destroys the summary
5. Broadcasts `AI_SUMMARY_FAILED` via `TextractResult#broadcast_ai_summary_failed` to the requesting user
6. Failed TextractResult remains as audit trail

### Cascade on Resume Replacement

When `SubmitResumeToTextract#submit_resume` marks existing summaries as stale (lines 18-20):
- Conditional: if NO `textract_processing` + `stale: false` summary exists → ALL summaries are marked `stale: true` via `update_all`
- If a `textract_processing` + `stale: false` summary DOES exist → NOTHING is marked stale (the entire `update_all` is skipped)
- New TextractResult is created; `textract_result_id` updated on waiting summary
- Previous TextractResult is NOT destroyed (unlike the old behavior)

### Cascade on Summary Success

When an `AiJobApplicationSummary` transitions to `succeeded` (via `update` in `IntegrateAnalysis#integrate`):
- `destroy_previous_textract_results` callback fires
  - Guards: `return unless textract_result` (nil safety for optional association)
  - Guards: `saved_change_to_status? && status_succeeded?`
  - Destroys TextractResult records with `created_at` before the summary's TextractResult **that have NOT succeeded** (`.where.not(textract_job_status: :succeeded)`) — succeeded prior TextractResults are preserved
  - This cascades via `dependent: :destroy` to destroy their associated `AiJobApplicationSummary` records and `AiApiRequest` records
- `update_summary_status_record` callback fires
  - Guards: `saved_change_to_status? && status_succeeded?`
  - Finds `job_application.ai_job_application_summary_status`
  - Guards: `return unless ai_job_application_summary_status` — silently returns if no status record exists
  - Updates via `update_columns`: `ai_job_application_summary_id: id`, `regenerating: false`, `status: AiJobApplicationSummaryStatus.statuses['succeeded']` (integer 7), `score_percentage`, `headline`, `integrated_role_analysis`

---

## Part 5: Gaps and Edge Cases

### Gap 1: External Resume URL → No Textract
Candidates imported via CSV with `external_resume_url`:
- Resume downloaded lazily when user views job application (`AttachExternalResumeUrlJob`)
- Uses `update_column` — no callbacks fire
- Textract NOT triggered after attachment
- Workarounds: bulk AI summary flow (Trigger 8) catches resume-but-no-textract; manual generation (Trigger 9/A) now kicks off Textract automatically

### Gap 2: Stale Summary Detection — PARTIALLY ADDRESSED
The `stale` boolean column now exists on `AiJobApplicationSummary`. `SubmitResumeToTextract` marks existing non-`textract_processing` summaries as `stale: true` when a new resume is submitted (line 18-20). `CreateAiSummaryGeneration` also marks the active summary stale when `textract_result_id` differs from latest (line 37). The frontend shows a stale banner: "The resume has changed since this review was generated. Regenerate to update."

**Remaining gap:** `AiJobApplicationSummaryStatus.regenerating` is never set to `true`. The frontend cannot distinguish "stale but idle" from "stale and regeneration in progress." See Gap 7.

### Gap 3: Active Summary Silent Return
`CreateAiSummaryGeneration` returns existing active summaries silently. The UI cannot distinguish:
- "Already generating" (in pipeline)
- "Already succeeded" (previously completed)
- "Succeeded but stale" (resume replaced since generation)

### Gap 4: SubmitResumeToTextract AWS Failure Orphans Summary
If `SubmitResumeToTextract#submit_resume` fails at the AWS call (lines 31-40), no TextractResult is created. A `textract_processing` summary with nil `textract_result_id` is orphaned. `GetResumeTextFromTextractJob` never runs (it's enqueued after TextractResult save), so the retry exhaustion cleanup in Change 2 never fires. The user sees "Resume is being processed" indefinitely.

### Gap 5: TextractResult Update Failure After Successful AWS Poll
AWS Textract returns `succeeded` with extracted text, but the `@textract_result.update()` call in `GetResumeTextFromTextract` could fail. The TextractResult stays `in_progress` with no text, and the `after_commit` callback never fires. The job doesn't retry because the AWS call itself succeeded. The `textract_processing` summary is stuck.

### Gap 6: No Persistent Failure Indication After Page Reload
If `GetResumeTextFromTextractJob` exhaustion destroys the summary and broadcasts `AI_SUMMARY_FAILED`, the user must be connected via WebSocket to see it. If they reload the page after the summary is destroyed, there's no summary record at all — no error message, no indication anything was attempted.

### Gap 7: `regenerating` Is Never Set to `true`

`AiJobApplicationSummaryStatus.regenerating` exists but is only ever set to `false` — on status record creation and on summary success. It is never set to `true`. The intent: when a user has a completed review and a replacement is being generated (resume replaced → new pipeline run), `regenerating: true` signals the frontend to show "Regenerating..." while keeping the old review visible.

**Where it should be set to `true`:** At the moment we know "a succeeded summary exists for this job_application and we're about to generate a replacement." This moment differs by trigger path:

- **Manual regeneration (Trigger A):** In `CreateAiSummaryGeneration` at lines 36-38, when the active summary is found with a different `textract_result_id` and is marked `stale: true`.
- **Auto-regeneration (Trigger D):** In `queue_ai_summary_job` else branch (textract_result.rb:118-123), after `should_auto_generate_ai_summaries?` passes and validation succeeds, before enqueuing the job. Must check: does this job_application have a stale, succeeded summary?
- **Bulk regeneration (Trigger B):** In `BulkGenerateAiSummariesJob#each_iteration` (bulk_generate_ai_summaries_job.rb:31-74), after validation succeeds, before calling `generate_ai_summary_with_credit_flow`. Must check same condition.

**Where it is set back to `false`:** Already handled in `AiJobApplicationSummary#update_summary_status_record` (line 69) — fires when the new summary reaches `succeeded`.

**`create_status_record` callback is misplaced:** It currently lives on `AiJobApplicationSummary` as an `after_commit on: :create`. The status record belongs to `job_application`, not to any particular summary. Summaries are created and destroyed; the status record persists. This callback should be refactored — see proposal.

### Gap 8: Orchestrate Returns No-Op for Stale Succeeded Summaries

`Orchestrate#call` (orchestrate.rb:15) finds the latest summary via `order(created_at: :desc).first` — **does NOT filter by `stale`**. On the auto-regeneration path (Trigger D), the latest summary is the stale succeeded one. Orchestrate hits the `succeeded` branch (line 46-48) and returns immediately. No new summary is ever created.

Then `generate_ai_summary_with_credit_flow` (textract_result.rb:70-77) fetches the same stale succeeded summary, passes the `status_succeeded?` guard, and calls `CreateAiCreditBalanceTransaction` — consuming a credit for the OLD summary without generating anything new.

**This means Trigger D (auto-regeneration on resume replacement) is broken.** The auto path enqueues the job, but the pipeline finds the old succeeded summary and does nothing except consume a credit.

---

## Part 6: Feature Gates Summary

| Gate | Type | Scope | Checked Where |
|------|------|-------|---------------|
| `TEXTRACT_RESUME_PROCESSING` | Flipper | Per-organization | `enqueue_new_job_application`, controller update. NOT checked by QueueBulkAiSummaryJobs or ValidateAiSummaryGeneration |
| `AI_APPLICANT_SUMMARY` | Flipper | Per-organization | ValidateAiSummaryGeneration, QueueBulkAiSummaryJobs |
| `AI_DAILY_CREDITS` | Flipper | Per-organization | `ResetDailyAiCredits` interactor |
| `ai_credits_available?` | Balance check | Per-organization | ValidateAiSummaryGeneration, QueueBulkAiSummaryJobs, TextractResult callback |
| `should_auto_generate_ai_summaries?` | Setting | Per-job (with org fallback) | TextractResult callback only |
| `can_use_ai_credits?` | Policy | Per-user role | AiJobApplicationSummaryPolicy (controller auth) |

---

## Part 7: Complete Trigger Matrix

### Textract Triggers

| # | Action | Entry Point | Resume Source | Flipper Gate | Notes |
|---|--------|-------------|---------------|-------------|-------|
| 1 | New job app created | `after_commit :enqueue_new_job_application` | Attached at creation | TEXTRACT_RESUME_PROCESSING | Fires for all creation sources |
| 2 | Manual resume upload | Controller update action | Form upload | TEXTRACT_RESUME_PROCESSING | Explicit param check (no dirty tracking) |
| 3 | Clone to job | Controller clone → save → after_commit | Blob copy from original | TEXTRACT_RESUME_PROCESSING | Independent TextractResult for clone |
| 4 | Customer API apply | Interactor → candidate.save → after_commit | Base64 decoded | TEXTRACT_RESUME_PROCESSING | |
| 5 | Customer API import | Same as apply | Base64 decoded | TEXTRACT_RESUME_PROCESSING | |
| 6 | CSV import | Job → interactor → candidate.save → after_commit | External URL (not yet attached) | TEXTRACT_RESUME_PROCESSING | Has no resume at creation — Textract exits early |
| 7 | External URL attachment | Controller show → AttachExternalResumeUrlJob | Downloaded from URL | N/A | **Textract NOT triggered** |
| 8 | Bulk AI summary backfill | QueueBulkAiSummaryJobs | Already attached | Not checked | For resume-but-no-textract candidates |
| 9 | Manual generate with no TextractResult | ValidateAiSummaryGeneration | Already attached | AI_APPLICANT_SUMMARY | Kicks off Textract + creates textract_processing summary |

### AI Summary Triggers

| # | Action | Entry Point | CreateAiSummaryGeneration? | Auto-Generate Check | User Broadcast | Credits |
|---|--------|-------------|---------------------------|--------------------|--------------------|---------|
| A | Manual single generate | Controller create | YES | No | AI_SUMMARY_COMPLETE | 1 on success |
| B | Bulk generate | Controller bulk_create → BulkGenerateAiSummariesJob | NO — calls `generate_ai_summary_with_credit_flow` directly | No | AI_SUMMARY_BULK_COMPLETE / AI_SUMMARY_BULK_FAILED | 1 per success |
| C | Auto-generate (callback) | TextractResult after_commit | NO — enqueues job directly | Yes | None | 1 on success |
| D | Resume replacement auto-regen | Textract callback after new result | NO — enqueues job directly | Yes | None | **BROKEN — credit consumed, no new summary (Gap 8)** |
| E | Textract processing handoff | Textract callback finds textract_processing summary | NO — summary already exists | No (already requested) | None | 1 on success |

Triggers C, D, E depend on the `TextractResult#queue_ai_summary_job` after_commit callback firing when Textract polling completes.

**Key architectural gap:** Only Trigger A goes through `CreateAiSummaryGeneration`. Triggers B, C, D, E bypass it entirely. Any logic placed only in `CreateAiSummaryGeneration` (stale detection, status record management, regenerating flag) does not apply to auto/bulk paths.

---

## Part 8: WebSocket Actions

| Action | Broadcast From | Payload | Frontend Handler |
|--------|---------------|---------|-----------------|
| `AI_SUMMARY_COMPLETE` | `GenerateAiJobApplicationSummaryJob#broadcast_completion` | `status`, `candidateFullName`, `jobApplicationLink`, `errorMessage` (if failed) | `WebsocketGlobalChannelHandler` — toast |
| `AI_SUMMARY_FAILED` | `TextractResult#broadcast_ai_summary_failed` | `candidateFullName`, `jobApplicationLink`, `errorMessage` | `WebsocketGlobalChannelHandler` — warning toast |
| `AI_SUMMARY_BULK_COMPLETE` | `BulkGenerateAiSummariesJob#notify_complete` | `succeededCount`, `failedCount`, `skippedCount`, `hiringStageLink` | `WebsocketGlobalChannelHandler` — toast + invalidate queries. Also sends `BulkJobApplicationAiSummaryResultMailer.complete` email. |
| `AI_SUMMARY_BULK_FAILED` | `BulkGenerateAiSummariesJob#notify_failure` | `jobTitle`, `message` | `WebsocketGlobalChannelHandler` — warning toast. Also sends `BulkJobApplicationAiSummaryResultMailer.failed` email. Fires when `succeeded == 0`. |
