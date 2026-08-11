# T2 — Adversarial Review (pass 4)

Slice: Manual resume upload / replacement (internal app). Controller `update` resume-param path → `SubmitResumeToTextractJob`. Trace stale-marking of any existing `AiJobApplicationSummary` and exactly what happens to the `AiJobApplicationSummaryStatus` row.

Candidate map: `backend-flow-map-2026-06-17.md`, T2 changelog (lines 28-37) plus RECONCILIATION NOTE (lines 186-190).

Code re-read from scratch:
- `app/controllers/api/v1/job_applications_controller.rb:88-127` (update action) + `:107-116` (resume fork)
- `app/services/submit_resume_to_textract.rb:1-42`
- `app/models/textract_result.rb:1-161`
- `app/models/ai_job_application_summary.rb:1-85`
- `app/services/ai_job_application_action/orchestrate.rb:1-50`
- `app/interactors/find_or_create_ai_job_application_summary_status.rb:1-47`
- `app/models/job_application.rb:28-35` (associations), `:589` (`has_resume`)

## Verdicts

### MAP-WRONG (Gap 7 — `regenerating` IS set) — AGREE
`find_or_create_ai_job_application_summary_status.rb:14-15`: `if summary&.status_succeeded?` then `@status_record.update_columns(status: 'regenerating')`. Guard on the row's associated summary (`:12` `summary = @status_record.ai_job_application_summary`) being `status_succeeded?`. AGREE.

### MAP-WRONG (Gap 8 — guard is `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`) — AGREE
`textract_result.rb:67-68`: `latest_ai_summary = job_application.latest_ai_job_application_summary` / `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`. A stale-succeeded summary fails `!stale?`, so the early return does NOT fire. AGREE.

### REMOVED (`after_commit :create_status_record` gone) — AGREE
`ai_job_application_summary.rb:29-31` are `destroy_previous_textract_results`, `update_summary_status_record`, `broadcast_status_change`. No `create_status_record`. AGREE.

### MAP-WRONG (status enum 4-value, no `regenerating` boolean column) — AGREE
`find_or_create_ai_job_application_summary_status.rb:15` writes `status: 'regenerating'` (an enum value via `update_columns`). No boolean column written anywhere. AGREE (enum def itself confirmed in X1/X2 slice; not re-opened here, but every write site on the T2 path treats `regenerating`/`current`/`none` as `status` values).

### MAP-WRONG (`update_summary_status_record` sets `status: 'current'` via `.update`, no `regenerating` column) — AGREE
`ai_job_application_summary.rb:74-80`: `ai_job_application_summary_status.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)`. Uses `.update` (not `update_columns`), writes `'current'` (not `'succeeded'`/7), no `regenerating` column. AGREE.

### CORRECTED (pass-3) — STUCK `regenerating` with stale denormalized data, no `current` recovery on T2 auto path — AGREE
Chain verified:
1. `submit_resume_to_textract.rb:18-19`: `unless @job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).exists?` → `@job_application.ai_job_application_summaries.update_all(stale: true)`. Prior succeeded summary → `stale:true`, status stays `succeeded` (`update_all` bypasses callbacks).
2. New result built `in_progress` at `:22`; relink at `:25-26` targets ONLY `textract_processing, stale:false, textract_result_id:nil` — the stale-succeeded summary does not match.
3. Bridge `textract_result.rb:121-123` waiting query `where(status: :textract_processing, stale: false).first` → nil (prior summary is succeeded+stale) → ELSE branch at `:137`.
4. `:138` gate `should_auto_generate_ai_summaries?`; `:140` re-validate; `:142` enqueue with NO requesting user.
5. In `generate_ai_summary_with_credit_flow`: `:68` does NOT early-return (stale). `:70` `find_or_create_ai_job_application_summary_status` → `FindOrCreate` `:11` row exists, `:12` pointer = old succeeded summary, `:14` true → `:15` flip to `regenerating`.
6. `:72` `set_initial_summary_pending` no-ops: guard `:102` requires `status_none? || status_initial_summary_pending?`, now `regenerating`.
7. `generate_ai_summary` → `Orchestrate` `:15` JobApplication-scoped (no stale filter) selects the stale-succeeded summary, `:16` passes, `:46-48` succeeded branch returns. No new summary.
8. `update_summary_status_record` (`ai_job_application_summary.rb:69`, `after_commit on: :update`, guard `saved_change_to_status? && status_succeeded?`) never fires (no summary updated to succeeded). Row STUCK `regenerating` with OLD denormalized score/headline/analysis.
AGREE.

### NEW (auto-gen GATE on T2 continuation) — AGREE
`textract_result.rb:138` `return unless job_application&.job&.should_auto_generate_ai_summaries?`. ON → re-validate `:140` + enqueue `:142` if `result.success?` → STUCK `regenerating`. OFF → else-branch returns at `:138`; row NEVER flipped to `regenerating` (FindOrCreate is only reached inside the job's `generate_ai_summary_with_credit_flow`, which is never enqueued), stays `current` with now-stale denormalized data; prior summary left `stale:true` with no further actor. AGREE.

### NEW (no requesting user → no toast) — AGREE
`textract_result.rb:142` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)` — no `requesting_organization_user_id`. AGREE.

### NEW (no-resume removal terminal) — AGREE
`submit_resume_to_textract.rb:9-10`: `return 'No resume attached' unless @job_application.has_resume`, BEFORE the stale `update_all` (`:18-19`) and the build (`:22`). `has_resume` at `job_application.rb:589`. AGREE. (Note: on the update action, `SubmitResumeToTextractJob` is only enqueued when `temp_params[:resume].present?` — controller `:110` — so a pure resume removal via the update param path would not even enqueue the job; the no-resume early-return covers the case where the job runs but the attachment is gone.)

## Omissions (for T2)

1. **Controller-side Flipper gate + enqueue conditions not in the T2 section.** The T2 resume-replacement enqueue is `job_applications_controller.rb:113-114`: `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, current_organization)` then `SubmitResumeToTextractJob.perform_later(job_application.id)`. With the flag OFF, the resume IS replaced (`job_application.update(temp_params)` at `:107`) and the new blob is stored, but NO `SubmitResumeToTextractJob` is enqueued at all — so no stale-marking, no new TextractResult, and the prior summary stays `succeeded` (non-stale) with the status row at `current`. This is a distinct, common T2 terminal that the T2 changelog never names. (The site is listed only in the T7 enqueue census, line 85, with no Flipper note and no T2 terminal consequence.)

2. **Enqueue is gated on `temp_params[:resume].present?`, not merely the key.** `job_applications_controller.rb:110` `if temp_params.key?(:resume) && temp_params[:resume].present?`. An update with `resume` key present but blank/nil does NOT enqueue Textract or `DocxToPdfJob`. The map's "if the resume is removed/absent" T2 note (line 37) routes through the in-service `has_resume` early-return, but the more immediate gate is this controller `.present?` check — a resume-clearing update never reaches `SubmitResumeToTextract` at all.

3. **`DocxToPdfJob` co-enqueue ordering.** `job_applications_controller.rb:112` enqueues `DocxToPdfJob.perform_later(job_application.id)` immediately before the Flipper-gated `SubmitResumeToTextractJob`. Both are `perform_later`; `DocxToPdfJob` produces `resume_docx_to_pdf`, which `SubmitResumeToTextract` prefers (`submit_resume_to_textract.rb:15` `@job_application.has_resume_docx_to_pdf ? ... : @job_application.resume`). Because both are async with no ordering guarantee, the Textract submit may run on the raw resume before the docx→pdf conversion lands. Not mentioned in the T2 section.

4. **`update` is the change-detection surface (no AR dirty tracking for ActiveStorage).** `job_applications_controller.rb:109-111` comments document that resume replacement is detected only via `temp_params.key?(:resume) && .present?`, not an AR callback. This is the structural reason the whole T2 Textract/stale/status cascade hangs off the controller param check rather than a model callback — worth a one-line note since every other trigger fires from a model `after_commit`.

## clean
false — all map T2 statements AGREE, but four omissions remain (controller Flipper gate + flag-OFF terminal, the `.present?` enqueue gate, DocxToPdfJob co-enqueue ordering, and the controller-as-change-detector note).
