# S-A — Manual single generate — Pass 1 Verdict

**Angle:** S-A — Manual single generate
**Files traced (chain):**
`app/controllers/api/v1/ai_job_application_summaries_controller.rb:4` (create) →
`app/interactors/validate_ai_summary_generation.rb` →
`app/models/job_application.rb:685` (latest_textract_result) →
`app/interactors/create_ai_summary_generation.rb` →
`app/models/ai_job_application_summary.rb` (associations, callbacks, BROADCAST_STATUSES) →
`app/jobs/generate_ai_job_application_summary_job.rb` →
`app/models/textract_result.rb:61` (generate_ai_summary_with_credit_flow) →
`app/models/job_application.rb:160` (find_or_create_ai_job_application_summary_status) →
`app/interactors/find_or_create_ai_job_application_summary_status.rb` →
`app/services/ai_job_application_action/orchestrate.rb` →
`app/models/ai_job_application_summary_status.rb` (enum)

---

## Entry: controller create

`app/controllers/api/v1/ai_job_application_summaries_controller.rb:4-28`
- `authorize :ai_job_application_summary, :create?` (line 6)
- `ValidateAiSummaryGeneration.call(job_application:, organization: current_organization)` (line 8-11); on failure renders and returns (line 12-15)
- `CreateAiSummaryGeneration.call(job_application:, validation_result:, user: current_user)` (line 17-21)
- renders `result.ai_summary` via `Api::V1::AiJobApplicationSummarySerializer` (line 23)

**Map says:** Trigger A, map lines 379-390 / 695. Lists controller → Validate → Create → Job → Pipeline.
**Verdict:** CONFIRMED (chain shape). Detail corrections below.

---

## ValidateAiSummaryGeneration — NEW guard + branch point for (i)/(ii)

`app/interactors/validate_ai_summary_generation.rb`
- Guards (lines 24-29): job_application present, organization present, `flipper_enabled?` (`Flipper.enabled?(:AI_APPLICANT_SUMMARY, @organization)` line 66), `has_resume?` (line 70 `@job_application.has_resume`), `credits_available?` (line 78 `@organization.ai_credits_available?`), and **NEW** `has_job_description?` (line 81-83 `@job_application.job&.description.present?`), failing with `'This job needs a description before Plato can review candidates. Add one in Job Setup.'`
- `@latest_textract_result = @job_application.latest_textract_result` (line 31); `context.textract_result = @latest_textract_result` (line 32).
- **Branch point** for the no-TextractResult sub-case: line 38 `unless @latest_textract_result` → `SubmitResumeToTextractJob.perform_later(@job_application.id)` (line 39), `context.textract_pending = true` (line 40), `return` (line 41).
- If `textract_text_ready?` (line 44, `@latest_textract_result&.textract_job_result_text.present?` line 74) → `context.textract_pending = false` (line 45) — this is sub-branch (i).
- elsif `textract_job_status_failed?` (line 46): looks up previous textract result (lines 47-50); if that also failed → `context.fail!('Resume processing has failed...')` (line 53); else re-submit textract + `textract_pending = true` (lines 55-56).
- else (in_progress/not_started) → `context.textract_pending = true` (line 59) — sub-branch (ii).

**Map says:** lines 213-229. Lists checks 1-6 but stops at credits/textract. Map check list does NOT include the `has_job_description?` guard.
**Verdict:** CHANGED. NEW guard `has_job_description?` (line 29/81-83) absent from map. Rest CONFIRMED.

---

## CreateAiSummaryGeneration — explicit (i) vs (ii) branch

`app/interactors/create_ai_summary_generation.rb`
- Active-summary lookup (lines 30-34): `where.not(status: :failed).where(stale: false).order(created_at: :desc).first`.
- Stale flip (lines 36-39): if `active_ai_summary.textract_result_id != job_application.latest_textract_result&.id` → `active_ai_summary.update_columns(stale: true)`; set local to nil.
- If still active (lines 41-44): `context.ai_summary = active_ai_summary; return` (silent return, no job).
- **(ii) Textract pending branch — BRANCH POINT line 46** `if validation_result.textract_pending`:
  - builds summary with `textract_result: validation_result.textract_result` (may be nil), `status: :textract_processing`, `requested_by_organization_user_id: context.user&.current_organization_user&.id` (lines 47-51).
  - `ai_summary.save` (line 53); on failure `context.fail!` (line 55). **NO job enqueued** — waits for `TextractResult#queue_ai_summary_job` callback. `return` (line 57).
- **(i) Textract ready branch (lines 60-77):** builds summary `status: :pending`, same `textract_result` + `requested_by_organization_user_id`. On `save` (line 70) → `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: validation_result.textract_result.id, requesting_organization_user_id: context.user.current_organization_user.id)` (lines 71-74). On failure `context.fail!` (line 76).

**Map says:** lines 231-243. "Active summary check (lines 30-44)", "Textract pending path (lines 46-55) ... Does NOT enqueue any job", "Textract ready path (lines 57-74) ... enqueues GenerateAiJobApplicationSummaryJob". Map also asserts (line 644, Gap 7) `regenerating: true` "should be set" at lines 36-38.
**Verdict:** CONFIRMED for the two-path structure and the no-enqueue on pending. The Gap-7 claim is now stale — see status-record section.

---

## GenerateAiJobApplicationSummaryJob

`app/jobs/generate_ai_job_application_summary_job.rb`
- `queue_as :default` (line 12); `retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3` (line 13).
- Retry-exhaustion block (lines 13-22): finds textract_result, `ai_summary.update_columns(status: :failed, error_message: error&.message)` (line 19), `broadcast_completion(...)` with the requesting user id (line 20).
- `perform(textract_result_id:, requesting_organization_user_id: nil)` (line 24): `return unless textract_result` (line 30); `textract_result.generate_ai_summary_with_credit_flow` (line 32); `broadcast_completion(textract_result, requesting_organization_user_id) if requesting_organization_user_id` (line 34).
- rescue `CustomErrorAiSummary` → re-raise (lines 35-38, no broadcast). rescue `StandardError` → mark summary failed via `update_columns` (line 44), broadcast if requesting user (line 45), no re-raise.
- `broadcast_completion` (lines 50-77): GlobalChannel `AI_SUMMARY_COMPLETE`, status `succeeded`/`failed` from `status_succeeded?` (line 61).

**Map says:** lines 245-255, 711. CONFIRMED.
**Verdict:** CONFIRMED.

---

## TextractResult#generate_ai_summary_with_credit_flow — NEW stale guard + NEW status write

`app/models/textract_result.rb:61-89`
- **NEW guard** line 67-68: `latest_ai_summary = job_application.latest_ai_job_application_summary` then `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`. (Map had only a post-pipeline `return unless summary&.status_succeeded?`.)
- **NEW** line 70-72: `status_result = job_application.find_or_create_ai_job_application_summary_status`; `set_initial_summary_pending(status_result) if status_result.success?`.
- `generate_ai_summary` (line 74) → `AiJobApplicationAction::Orchestrate.new(textract_result_id: id).call` (line 111).
- Post-pipeline: `ai_job_application_summary = ai_job_application_summaries.order(created_at: :desc).first` (line 77); `return unless ai_job_application_summary&.status_succeeded?` (line 82).
- `CreateAiCreditBalanceTransaction.call(summary:)` (line 84); `return unless consume_result.success?` (line 85); `NotifyZeroAiCredits` / `NotifyLowAiCredits` (lines 87-88).
- `set_initial_summary_pending` (lines 98-108): guards `status_none? || status_initial_summary_pending?` (line 102); `status_record.update_columns(ai_job_application_summary_id: latest_summary.id, status: 'initial_summary_pending')` (lines 104-107).

**Map says:** lines 257-265. Map lists only post-pipeline credit guard; no stale-aware pre-gate, no status-record write, no `set_initial_summary_pending`.
**Verdict:** CHANGED + NEW. The stale-aware pre-gate (line 68) and the `initial_summary_pending` status write (lines 104-107) are NEW and absent from map.

---

## Orchestrate — terminal pipeline dispatch for (i)

`app/services/ai_job_application_action/orchestrate.rb`
- line 15: `@ai_job_application_summary = @job_application.ai_job_application_summaries.order(created_at: :desc).first` — **does NOT filter by stale** (map line 270 CONFIRMED).
- For S-A (i), summary status is `:pending` → matches line 22 branch → `run_summary` (line 26, → `Summary::Generate ... .generate` line 64) → `check_criteria_and_score` (line 27).
- `check_criteria_and_score` (lines 68-83): `return if status_failed?`; `return unless summary_complete?` (headline+summary_text present, lines 54-57); `@ai_job_application_summary.update(status: :awaiting_job_criteria)` (line 72); if `ai_job_criteria&.status_succeeded?` → `run_scoring` + `run_integration` (lines 77-78); else `job.extract_job_criteria unless criteria pending/in_progress` then `return` (lines 80-81).
- **Terminal states:** path comes to rest at `succeeded` (after run_integration), or at `awaiting_job_criteria` (waiting for the `AiJobCriteria` re-trigger — out of S-A scope), or at `failed` if a stage errored.

**Map says:** lines 267-289. CONFIRMED for line-15 no-stale-filter and the pending dispatch.
**Verdict:** CONFIRMED.

---

## AiJobApplicationSummary callbacks — CHANGED vs map

`app/models/ai_job_application_summary.rb`
- enum (lines 10-21) matches prompt: `pending..failed` with `_prefix: true`. CONFIRMED.
- `BROADCAST_STATUSES = %w[pending textract_processing extracting summarizing scoring integrating succeeded failed]` (line 23) — **excludes `awaiting_job_criteria` AND `retrying`**. CONFIRMED (prompt note).
- **NEW** `before_update :broadcast_status_change` (line 31, 100-111): `return unless status_changed?`; `return unless BROADCAST_STATUSES.include?(status)`; `JobChannel.broadcast_to(job.job, event: 'ai_summary_status_change', ...)`.
- `after_commit :destroy_previous_textract_results, on: :update` (line 29, 47-55): `return unless textract_result`; `return unless saved_change_to_status? && status_succeeded?`; destroys prior non-succeeded textract_results.
- `after_commit :update_summary_status_record, on: :update` (line 30, 57-98): `return unless saved_change_to_status? && status_succeeded?` (line 69); fetches `job_application.ai_job_application_summary_status`, `return unless` present (lines 71-72); **uses `.update`** (line 74) — NOT `update_columns` — setting `ai_job_application_summary_id: id`, `status: 'current'`, `score_percentage`, `headline`, `integrated_role_analysis`. Does NOT set `regenerating`. Then **NEW** `JobChannel.broadcast_to(job.job, event: 'ai_summary_succeeded', ...)` (lines 93-97).
- **`create_status_record` callback is GONE.** No `after_commit :create_status_record, on: :create` exists. Status record is created via `JobApplication#enqueue_new_job_application` → `find_or_create_ai_job_application_summary_status` (job_application.rb:170/160) and via `generate_ai_summary_with_credit_flow` (textract_result.rb:70).

**Map says:** lines 499-502 — claims `create_status_record` `after_commit on: :create` exists with a `find_or_create_by` bug; claims `update_summary_status_record` uses `update_columns` and sets `regenerating: false` and `status` integer 7.
**Verdict:** MAP-WRONG / REMOVED. `create_status_record` REMOVED. `update_summary_status_record` CHANGED to `.update` with `status: 'current'`, no `regenerating`, plus NEW `ai_summary_succeeded` broadcast.

---

## AiJobApplicationSummaryStatus model — enum CHANGED

`app/models/ai_job_application_summary_status.rb`
- enum (lines 9-14): `{none: 0, initial_summary_pending: 1, current: 2, regenerating: 3}`, `_prefix: true`. Matches prompt.
- `validates :job_application_id, uniqueness: true` (line 16).
- `counter_culture` on `job` keyed on status IN (2,3) i.e. current/regenerating (line 7) — NEW.
- band scopes poor/weak/mixed/good/excellent by score_percentage (lines 20-24) — NEW.

**Map says:** lines 504-520 — enum listed as the 10-value summary enum (pending..failed); `regenerating` described as a boolean column "never set to `true`" (Gap 7, lines 638-651).
**Verdict:** MAP-WRONG. `regenerating` is an ENUM STATUS value (3), not a boolean column. It IS set to `regenerating` in `FindOrCreateAiJobApplicationSummaryStatus:15`. Gap 7 is obsolete.

---

## FindOrCreateAiJobApplicationSummaryStatus — the regenerating write

`app/interactors/find_or_create_ai_job_application_summary_status.rb`
- existing record + its summary `status_succeeded?` → `@status_record.update_columns(status: 'regenerating')` (line 15) + `JobChannel` `ai_summary_status_change` broadcast (lines 16-20).
- no record: build; if `latest_ai_job_application_summary&.status_succeeded? && !stale?` → populate `ai_job_application_summary`, `status: 'current'`, denormalized score/headline/integrated_role_analysis (lines 27-32); else `status: 'none'` (line 34); `save` else `fail!` (lines 37-39).
- rescue `ActiveRecord::RecordNotUnique` → reload existing (line 43-44).

**Map says:** ABSENT (interactor not in map; map asserts regenerating never set).
**Verdict:** NEW.

---

## Desync windows (AiJobApplicationSummaryStatus vs latest non-stale summary)

- (ii) textract_processing path: `generate_ai_summary_with_credit_flow` sets status row to `initial_summary_pending` (textract_result.rb:104-107) only if row is `none`/`initial_summary_pending`. If the row is already `current`/`regenerating` (a prior succeeded summary exists), the new in-flight summary does NOT move the status row — display shows old `current` data until the new summary reaches `succeeded` (or `regenerating` was already set by FindOrCreate). Window: from request until `update_summary_status_record` flips it to `current`.
- `update_summary_status_record` only fires `on: :update` when `saved_change_to_status? && status_succeeded?`. A summary that ends in `failed` never updates the status row → status row keeps stale `current`/`regenerating`/`initial_summary_pending` data with no clearing actor on the failure path.
- `broadcast_status_change` skips `awaiting_job_criteria` and `retrying` (BROADCAST_STATUSES) — transitions into those two broadcast nothing; the stage list does not learn the summary advanced/paused.

---

## Branch summary for S-A

- **(i) Textract ready:** ValidateAiSummaryGeneration line 44 `textract_text_ready?` true → `textract_pending = false` → CreateAiSummaryGeneration line 60-74 builds `pending` summary and enqueues `GenerateAiJobApplicationSummaryJob` immediately. Orchestrate enters `status_pending?` branch (orchestrate.rb:22).
- **(ii) Textract pending / none:** ValidateAiSummaryGeneration line 38 (no result → submit textract) or line 59 (in_progress) → `textract_pending = true` → CreateAiSummaryGeneration line 46-57 builds `textract_processing` summary, **NO job**. Waits for `TextractResult#queue_ai_summary_job` (textract_result.rb:114) which, finding the `textract_processing` non-stale summary (lines 121-123), re-validates and enqueues the job (lines 128-131).
