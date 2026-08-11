# T2 Adversarial Review — pass-6

**Slice:** T2 — Manual resume upload / replacement (internal app). Controller `update` action resume-param path → `SubmitResumeToTextractJob`. Trace stale-marking of any existing `AiJobApplicationSummary` and exactly what happens to the `AiJobApplicationSummaryStatus` row.

**Method:** Re-read all code from scratch. Files opened and traced:
- `app/controllers/api/v1/job_applications_controller.rb:88-127,178-179`
- `app/jobs/submit_resume_to_textract_job.rb:1-14`
- `app/services/submit_resume_to_textract.rb:1-42`
- `app/models/textract_result.rb:1-161`
- `app/interactors/find_or_create_ai_job_application_summary_status.rb:1-47`
- `app/models/ai_job_application_summary.rb:1-98`
- `app/services/ai_job_application_action/orchestrate.rb:1-70`
- `app/models/job_application.rb:28-36,160-171,589-596`
- `app/models/ai_job_application_summary_status.rb:1-26`
- `app/models/job.rb:914` (should_auto_generate_ai_summaries? exists)
- `db/schema.rb:168-179` (status table columns)
- `textract-ai-summary-map-6-6-2026-COPY.md:430,500,621,638,652,658,698` (old-map Gap 7/8/Trigger D references)

**Verdict: clean = true.** Every T2 statement in the candidate map verifies against literal code; no omissions found.

## Verdicts (AGREE)

1. Change-detection is in the controller `update` action, not a model callback (comments at `:109,111`). — AGREE: `job_applications_controller.rb:109` "ActiveRecord does not have a changed/dirty tracker for ActiveStorage attachments", `:111` "no AR callback that accurately detects changes to ActiveStorage attachments".

2. Textract enqueue gated on `temp_params.key?(:resume) && temp_params[:resume].present?` (not mere key presence). — AGREE: `job_applications_controller.rb:110`.

3. Controller-side Flipper gate `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, current_organization)` (`:113-114`); flag OFF → resume replaced (`:107`) but no Textract, no stale-marking, prior summary stays succeeded+non-stale, row stays current. — AGREE: `job_applications_controller.rb:107,113,114`. Distinct from model-side `job_application.rb:167` (`job.organization`).

4. `DocxToPdfJob.perform_later` (`:112`) co-enqueued BEFORE Textract job (`:114`); both `perform_later`, no ordering; `SubmitResumeToTextract` prefers `resume_docx_to_pdf` (`submit_resume_to_textract.rb:15`). — AGREE: `job_applications_controller.rb:112,114`; `submit_resume_to_textract.rb:15`.

5. Old map Gap 7 ("regenerating never set") MAP-WRONG: `regenerating` IS set at `find_or_create_ai_job_application_summary_status.rb:14-15`, guarded on the row's associated summary being `status_succeeded?` (`:12,14`). — AGREE: `:12` `summary = @status_record.ai_job_application_summary`, `:14` `if summary&.status_succeeded?`, `:15` `@status_record.update_columns(status: 'regenerating')`. Old map: `COPY.md:500,638`.

6. Old map Gap 8 / Trigger D ("auto-regen BROKEN") MAP-WRONG: guard is now `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?` (`textract_result.rb:67-68`); stale-succeeded fails `!stale?` so flow continues. — AGREE: `textract_result.rb:67,68`. Old map: `COPY.md:652,658`.

7. `after_commit :create_status_record, on: :create` REMOVED from `AiJobApplicationSummary` (`ai_job_application_summary.rb:29-31`). — AGREE: `:29` `destroy_previous_textract_results`, `:30` `update_summary_status_record`, `:31` `broadcast_status_change`; no `create_status_record`. Old map had it: `COPY.md:500`.

8. Status enum is 4-value `{none:0,initial_summary_pending:1,current:2,regenerating:3}` _prefix:true; NO `regenerating` boolean column; `regenerating` written as enum value 3 via `update_columns` (`find_or_create_…status.rb:15`). — AGREE: `ai_job_application_summary_status.rb:9-14`; `schema.rb:171` `t.integer "status"` (no boolean regenerating); `find_or_create_…status.rb:15`.

9. `update_summary_status_record` sets `status: 'current'` via `.update`, no regenerating column (`ai_job_application_summary.rb:74-80`). — AGREE: `:74` `.update(`, `:76` `status: 'current'`.

10. T2 auto-continuation terminal = STUCK `regenerating` with stale denormalized data; NOT a current→regenerating→current round trip. — AGREE, full chain verified:
    - Prior succeeded staled: `submit_resume_to_textract.rb:18` guard `unless ...where(status: :textract_processing, stale: false).exists?`, `:19` `update_all(stale: true)` (status unchanged, stays succeeded).
    - New result built `in_progress` `:22`; relink `:25-26` only touches `textract_processing` waiting summaries (none here).
    - Bridge else branch: `textract_result.rb:121-123` finds no `textract_processing`/`stale:false` waiting summary → else `:137`; `:138` should_auto_generate gate; `:140` re-validate; `:142` enqueue.
    - `generate_ai_summary_with_credit_flow:68` does NOT return (stale fails `!stale?`).
    - `FindOrCreate` flips row to `regenerating` driven by status row's own `ai_job_application_summary` pointer (`:12,14-15`).
    - `Orchestrate` selects stale-succeeded summary JobApplication-scoped no-stale-filter (`orchestrate.rb:15-16`), hits succeeded branch (`:46-48`), returns; no new summary built.
    - `update_summary_status_record` never fires (`ai_job_application_summary.rb:69` needs a status change to succeeded); row stuck `regenerating` with OLD denormalized data.

11. Auto-gen GATE on the continuation: ON → STUCK regenerating; OFF → bridge returns at `:138`, row NEVER flipped, stays `current` with stale data, prior summary left `stale:true` no further actor. — AGREE: `textract_result.rb:138` `return unless job_application&.job&.should_auto_generate_ai_summaries?`.

12. Else/auto branch enqueues with NO `requesting_organization_user_id` (`textract_result.rb:142`) → no `AI_SUMMARY_COMPLETE` toast for the user who replaced the resume. — AGREE: `:142` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id) if result.success?` (no requesting-user arg).

13. No-resume removal terminal: `SubmitResumeToTextract` returns `'No resume attached'` at `:10` (the `:9` line is the separate `JobApplication not found` guard) BEFORE stale `update_all` (`:18-19`) and BEFORE build (`:22`). — AGREE: `submit_resume_to_textract.rb:9,10,18,19,22`.

14. Guarded-skip stale window: `update_all(stale: true)` is SKIPPED when a non-stale `textract_processing` summary already exists (`:18` `unless` TRUE). — AGREE: `submit_resume_to_textract.rb:18-19`.

15. Waiting-summary relink redirects the bridge in the guarded-skip window: `:25-26` relink onto the new result, bridge selector `:121-123` then finds it and takes the IF branch (`:125`). — AGREE: `submit_resume_to_textract.rb:25,26`; `textract_result.rb:121-123,125`.

16. Rescue-swallow resting state: job rescues StandardError + only `ap` (`submit_resume_to_textract_job.rb:9-11`); service rescues set `@textract_result&.update_columns(textract_job_status: 'failed')` (`:31-40`). New result lands `failed`, no continuation, prior summary left succeeded+stale. — AGREE: `submit_resume_to_textract_job.rb:9,10,11`; `submit_resume_to_textract.rb:31,33,36,39`.

17. `SubmitResumeToTextract` creates NO `AiJobApplicationSummary`, does not call `CreateAiSummaryGeneration`; status row NOT touched by the service (only summary-table write is conditional `update_all(stale: true)`). — AGREE: `submit_resume_to_textract.rb:1-42` (no summary build, no status-row reference; only `:19` `update_all`).

18. Recovery to `current` happens on later MANUAL (S-A) OR BULK (S-B) regen building a fresh `:pending` summary. — AGREE for the T2 cross-reference (verified `update_summary_status_record:74-80` re-points the row unconditionally on a later succeeded transition; the S-A/S-B build interactors are out-of-slice but the recovery writer is the same `:69-80` path).

## Omissions

None. The candidate map covers: the controller change-detection surface, both Flipper sites, the resume-present gate, DocxToPdf co-enqueue ordering, the stale `update_all` and its skip guard, the relink, both bridge branches, the auto-gen gate, the STUCK-regenerating terminal, the auto-gen-OFF terminal, the no-resume removal terminal, the rescue-swallow terminal, the no-toast outcome, and recovery. No T2 write site or branch was found in code that the map fails to mention.

## Record-write sites on this slice (T2)

- `submit_resume_to_textract.rb:19` — `@job_application.ai_job_application_summaries.update_all(stale: true)` — column `stale` — update_all (bypasses callbacks). Conditional on `:18` guard.
- `submit_resume_to_textract.rb:22` — `@job_application.textract_results.build(textract_job_id:, textract_job_status: 'in_progress')` + `:24` `.save` — columns `textract_job_id`, `textract_job_status` — save (callback-firing → bridge after_commit).
- `submit_resume_to_textract.rb:26` — `waiting_summary&.update_columns(textract_result_id: @textract_result.id)` — column `textract_result_id` — update_columns (guarded-skip window only).
- `submit_resume_to_textract.rb:33,39` — `@textract_result&.update_columns(textract_job_status: 'failed')` — column `textract_job_status` — update_columns (rescue paths).
- Downstream (T2 auto-continuation, fired via the bridge): `find_or_create_ai_job_application_summary_status.rb:15` — `@status_record.update_columns(status: 'regenerating')` — column `status` — update_columns (bypasses counter_culture).
