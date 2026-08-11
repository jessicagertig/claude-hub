# Orchestrator grounding notes — verified against LIVE code 2026-06-23

These are facts I (orchestrator) verified by reading live source in `/Users/jessica/wrk/wrk-corp/inflow-ats` on branch `ai-summary-creation-gaps`, to ground the exploration findings and the spec. Every line has a `file:line`. Where the 2026-06-22 map disagrees with live code, **live code wins** and the divergence is noted.

## Environment / harness
- Branch confirmed `ai-summary-creation-gaps`; `db/schema.rb` + 16 spec files modified (expected, uncommitted). Never stage/commit `db/schema.rb`.
- Test harness WORKS: `bundle exec rspec` runs (test DB migrated). Pre-loaded criteria specs all PASS:
  - `spec/models/ai_job_criteria_spec.rb` → 6 examples, 0 failures.
  - `spec/jobs/extract_job_criteria_job_spec.rb` + `spec/services/ai_job_application_action/scoring/extract_criteria_spec.rb` + `.../orchestrate_spec.rb` + `.../scoring/score_job_application_spec.rb` → 54 examples, 0 failures.
  - (Run with `dangerouslyDisableSandbox: true` so it can reach local Postgres test DB. The `ap` debug noise is the documented `update_summary_status_record` debug lines.)

## Issue 5/6 — AiJobCriteria cardinality: MAP IS STALE
- LIVE: `Job has_many :ai_job_criteria, class_name: 'AiJobCriteria'` (`app/models/job.rb:52`). Map described singular `job.ai_job_criteria` — STALE.
- New readers: `Job#latest_ai_job_criteria` = `ai_job_criteria.order(created_at: :desc).first` (`job.rb:688-690`); `Job#latest_succeeded_ai_job_criteria` = `ai_job_criteria.status_succeeded.order(created_at: :desc).first` (`job.rb:692-694`).
- `AiJobCriteria` model unchanged: still `belongs_to :job` (`ai_job_criteria.rb:4`); `resume_waiting_summaries` iterates `job.ai_job_application_summaries` (summaries, not criteria) (`ai_job_criteria.rb:21-29`).
- `Job#extract_job_criteria` (`job.rb:713-723`) and `Job#auto_extract_job_criteria` (`job.rb:696-711`): BOTH guard `return if existing_ai_job_criteria&.status_pending?` (existing = `latest_ai_job_criteria`), then build a NEW `ai_job_criteria.new(status: :pending)` + enqueue `ExtractJobCriteriaJob`. ⇒ each extraction is a NEW record (no in-place overwrite). The `has_many` refactor structurally PREVENTS the old has_one overwrite.
- App-code criteria readers all updated to `latest_*` (no stale singular `job.ai_job_criteria` reader left in app/): `orchestrate.rb:74` `job.latest_ai_job_criteria`; `score_job_application.rb:19` `@job.latest_ai_job_criteria`.

### Issue 5↔6 ROOT-CAUSE insight (the incident is likely STUCK-PENDING, not overwrite)
- `orchestrate.rb` `check_criteria_and_score` (`:68-83`): `:72` `update(status: :awaiting_job_criteria)`; `:74` reads `latest_ai_job_criteria` (NEWEST, ANY status — NOT latest_succeeded); `:76` if `&.status_succeeded?` → score+integrate; `:80` else `job.extract_job_criteria UNLESS latest &.status_pending? || &.status_in_progress?`.
- A stuck-`pending` latest criteria ⇒ `:80` guard skips re-extract ⇒ summary rests at `awaiting_job_criteria`; criteria never reaches `succeeded` ⇒ `resume_waiting_summaries` never fires; manual re-trigger `extract_job_criteria` also no-ops (its own pending guard). PERMANENT stuck. This is a **poison-pending** mechanism, orthogonal to `has_many`.
- `ExtractJobCriteriaJob` (`extract_job_criteria_job.rb`): `retry_on CustomErrorAiSummary attempts:3`; exhaustion writes `update_columns(status: :failed)` (`:9`). So a RUNNING job leaves pending. "Stuck pending" requires the job to NOT run / NOT reach `ExtractCriteria` `:28` `update_columns(:in_progress)`.
- Candidate secondary issue: `orchestrate.rb:74` uses `latest_ai_job_criteria` not `latest_succeeded_ai_job_criteria`; a newer FAILED criteria masks an older SUCCEEDED one → re-extract instead of scoring on the good criteria. To confirm with agents.

## Issue 1 — no summary created on auto-gen before Textract resolves
- CONFIRMED no path pre-creates a summary on auto entry. `enqueue_new_job_application` (`job_application.rb:164-171`) creates only the STATUS ROW (`find_or_create_ai_job_application_summary_status`, `:170`), not a summary.
- The bridge `queue_ai_summary_job` (`textract_result.rb:114-144`) fires only AFTER Textract text lands (`:115-116`). Else/auto branch (`:137-143`): no pre-existing summary ⇒ `Orchestrate#call` returns at `orchestrate.rb:16` ⇒ no summary; `generate_ai_summary_with_credit_flow` returns at `textract_result.rb:82`. No summary/credit/broadcast.
- ANALOG (`create_ai_summary_generation.rb:46-58`): textract_pending path builds `status: :textract_processing` summary, `requested_by_organization_user_id: context.user&.current_organization_user&.id`, NO enqueue (waits for bridge).
- FIX shape: build a `textract_processing` summary on the auto-gen entry (no requesting user), gated on `should_auto_generate_ai_summaries?` + AI_APPLICANT_SUMMARY + credits + has_job_description + has_resume. Then when Textract resolves, the bridge's waiting-summary `if` branch (`textract_result.rb:121-135`, finds `textract_processing`/`stale:false`) advances it → summary + credit (no toast, no requesting user). If Textract FAILS, the summary rests at `textract_processing` (Jessica's intended state).
- DOUBLE-SUBMIT caution: do NOT route auto entry through `ValidateAiSummaryGeneration` (it submits Textract at `validate_ai_summary_generation.rb:39`) because `enqueue_new_job_application:168` already submits. Build the summary directly, apply guards separately.
- SIDE-EFFECT to handle: `cleanup_orphaned_summary` (`get_resume_text_from_textract_job.rb`, retry exhaustion) DESTROYS the `textract_processing`/`stale:false` summary on AWS-fail exhaustion → would re-create the "no summary" state. Spec must decide whether that destroy is desired vs leaving a `textract_processing` (or failed) summary.

## Issue 2 — docx→Textract ordering
- `enqueue_new_job_application` (`job_application.rb:165-169`): `DocxToPdfJob.perform_later` + (flag-gated) `SubmitResumeToTextractJob.perform_later` — both async, NO ordering.
- `DocxToPdfJob#perform` → `handle_possible_docx_resume` (`job_application.rb:733-751`): `return unless resume_is_docx`; ConvertApi; attach `resume_docx_to_pdf`; broadcast JobChannel `docx_to_pdf_conversion_complete` (`:746`). Does NOT trigger Textract after attach.
- `SubmitResumeToTextract#submit_resume:15`: `resume_for_textract = has_resume_docx_to_pdf ? resume_docx_to_pdf : resume` — falls back to RAW docx if conversion not yet attached → Textract gets docx → fails (Textract PDF-only).
- Helpers: `resume_is_docx` (`job_application.rb:697-701`, docx/msword content types), `resume_is_pdf` (`:693-694`), `has_resume_docx_to_pdf = resume_is_docx && resume_docx_to_pdf.attached?` (`:722-723`).
- FIX shape: in `enqueue_new_job_application`, branch on `resume_is_docx` → enqueue ONLY DocxToPdfJob (always, viewer needs it); else (PDF) → direct `SubmitResumeToTextractJob` (flag-gated). After conversion attaches in DocxToPdfJob/`handle_possible_docx_resume`, enqueue `SubmitResumeToTextractJob` (flag-gated). SAME fix on T2 controller path (`job_applications_controller.rb:110-114`).
- Open: conversion-failure path (`handle_possible_docx_resume` rescues + logs) → Textract never fires for a docx whose conversion failed. Compare to today; note self-healing re-submit (`get_resume_text_from_textract.rb:14-17`) does not help (no TextractResult yet).

## Issue 3 — status row stuck initial_summary_pending / regenerating with stale data
- `AiJobApplicationSummaryStatus` enum has NO `failed` value ({none, initial_summary_pending, current, regenerating}).
- `update_summary_status_record` (`ai_job_application_summary.rb:57-98`): `after_commit on: :update`; guard `:69` `saved_change_to_status? && status_succeeded?`. ⇒ summary ending `failed`/`retrying` never updates the row. No stale guard at `:74` (issue-7 candidate).
- `regenerating` set via status-only `update_columns` (`find_or_create_ai_job_application_summary_status.rb:15`) — keeps old `score_percentage`/`headline`/`integrated_role_analysis`/pointer.
- Later-resolved rule: a later S-A (manual) / S-B (bulk) regeneration recovers the row to `current` (map T2 173-177). So "stuck until user manually regenerates" UX gap vs "stuck forever" — distinguish per window.

## Issue 4 — no UI signal while awaiting_job_criteria / criteria pending / retrying
- `BROADCAST_STATUSES` (`ai_job_application_summary.rb:23`) OMITS `awaiting_job_criteria` and `retrying`. `broadcast_status_change` is `before_update` only (`:100-102`). ⇒ transitions into those states broadcast nothing.
- A summary CREATED at `textract_processing` (issue-1 fix) fires NO broadcast (before_update, not before_create) ⇒ issue-1's signal flows via the STATUS ROW (`set_initial_summary_pending`), not the summary broadcast. Issue 1↔4.
- The infinite list responds to terminal/completion events only (not `ai_summary_status_change`).

## Conventions captured (for spec/plan/impl)
- No bang methods in app/ (OK in spec/ + `app/controllers/cypress/`); always check save/update return values.
- Bare `return` (no falsy values; error strings OK). Method-level rescue, never class/module. `=> e`/`=> exc`. Rescue specific classes. Single quotes unless interpolating.
- No `reload` in app/ (orchestrate.rb has a documented deviation); match variable names to model names (`ai_job_application_summary`, `textract_result`, `ai_job_criteria`).
- Frontend camelCase, backend snake_case, enum values stay snake_case. No `??`, no fabricated fallbacks (`|| 0` etc.), never deliberately set `undefined`.
- Commit (optional this session) via `nvm use && git commit` OUTSIDE sandbox; never `--no-verify`; never rewrite tests to pass. Cypress tests read-only unless spec calls for change.
- LIFECYCLE: Phase 0 spec → 1 angles → 2 spec review → 3 plan → 4 plan review → 5 impl → 6 impl-review loop (2 clean) → 7 harden. STOP before Phase 8. inflow-ats prompt overrides exist for every phase at `~/claude-hub/inflow-ats/features/`.
