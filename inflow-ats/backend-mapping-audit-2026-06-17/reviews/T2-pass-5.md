# T2 Adversarial Review — pass-5

Slice T2 — Manual resume upload / replacement (internal app). Controller `update` action resume-param path → `SubmitResumeToTextractJob`. Stale-marking of any existing `AiJobApplicationSummary` and the fate of the `AiJobApplicationSummaryStatus` row.

Files re-read from scratch:
- `app/controllers/api/v1/job_applications_controller.rb:88-127` (update action)
- `app/services/submit_resume_to_textract.rb:1-42`
- `app/jobs/submit_resume_to_textract_job.rb:1-14`
- `app/models/textract_result.rb:61-144`
- `app/models/ai_job_application_summary.rb:1-112`
- `app/interactors/find_or_create_ai_job_application_summary_status.rb:1-47`
- `app/services/ai_job_application_action/orchestrate.rb:1-106`
- `app/models/job_application.rb:31-32,45,160-171,589-593`
- `app/models/job.rb:914-922`

## Verdicts on T2 changelog statements (map lines 28-41)

**AGREE** — "change-detection surface is the controller update action, not a model callback" (map:29). Confirmed: the resume-change cascade hangs off `job_applications_controller.rb:110` (`if temp_params.key?(:resume) && temp_params[:resume].present?`), with in-code comments at `:109,111`. No model `after_commit` detects it.

**AGREE** — "controller resume-present gate" `temp_params.key?(:resume) && temp_params[:resume].present?` at `job_applications_controller.rb:110` (map:30). Confirmed literally at `:110`. A blank `:resume` fails `.present?` and the block is skipped.

**AGREE** — "controller-side Flipper gate" `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, current_organization)` wrapping `SubmitResumeToTextractJob.perform_later` at `job_applications_controller.rb:113-114` (map:31). Confirmed: `:113` is the Flipper guard, `:114` the enqueue. Uses `current_organization` (distinct from the model-side `job.organization` at `job_application.rb:167`).

**AGREE** — "DocxToPdfJob co-enqueue ordering" — `DocxToPdfJob.perform_later(job_application.id)` at `job_applications_controller.rb:112` immediately before the Textract job; `SubmitResumeToTextract` prefers `resume_docx_to_pdf` at `submit_resume_to_textract.rb:15` (map:32). Confirmed: `:112` DocxToPdfJob, `:114` Textract; `:15` `@job_application.has_resume_docx_to_pdf ? @job_application.resume_docx_to_pdf : @job_application.resume`.

**AGREE** — `regenerating` IS set at `find_or_create_ai_job_application_summary_status.rb:14-15`, guarded on the row's associated summary being `status_succeeded?` (map:33). Confirmed: `:14` `if summary&.status_succeeded?`, `:15` `@status_record.update_columns(status: 'regenerating')`. The `summary` is the status row's own pointer (`:12` `summary = @status_record.ai_job_application_summary`).

**AGREE** — credit-flow guard is `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?` at `textract_result.rb:67-68` (map:34). Confirmed literally at `:67-68`. A stale-succeeded summary fails `!stale?`, so flow continues.

**AGREE** — `after_commit :create_status_record, on: :create` no longer exists on `AiJobApplicationSummary`; `:29-31` are now `destroy_previous_textract_results` / `update_summary_status_record` / `broadcast_status_change` (map:35). Confirmed at `ai_job_application_summary.rb:29-31`.

**AGREE** — `AiJobApplicationSummaryStatus` writes `regenerating` as the `status` enum value via `update_columns`, no `regenerating` boolean column (map:36). Confirmed: `find_or_create_ai_job_application_summary_status.rb:15` `update_columns(status: 'regenerating')`.

**AGREE** — `update_summary_status_record` sets `status: 'current'` via `.update`, not `update_columns`, writes no `regenerating` column (map:37). Confirmed: `ai_job_application_summary.rb:74-80` `ai_job_application_summary_status.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)`.

**AGREE** — Status-row terminal on the T2 auto-continuation is STUCK `regenerating` with stale denormalized data; the `→ current` recovery does NOT occur on the T2 auto path (map:38). Verified the full chain:
- prior succeeded summary staled by `submit_resume_to_textract.rb:19` `update_all(stale: true)` (status stays `succeeded`);
- new TextractResult success → bridge else/auto branch `textract_result.rb:137` because no `textract_processing`/`stale:false` waiting summary (`:121-123`);
- `generate_ai_summary_with_credit_flow` does NOT early-return at `:68` (stale fails `!stale?`);
- `FindOrCreate` flips row to `regenerating` (`find_or_create_…:14-15`, driven by status-row pointer `:12`);
- `Orchestrate` selects the stale-succeeded summary `orchestrate.rb:15` (`order(created_at: :desc).first`, NO stale filter), `:16` passes, succeeded branch returns `:46-48`;
- no summary status transition → `update_summary_status_record` guard `return unless saved_change_to_status? && status_succeeded?` (`ai_job_application_summary.rb:69`) never advances → row STUCK `regenerating`.
All citations match current code.

**AGREE** — auto-gen GATE on the T2 continuation: auto-gen OFF → bridge else branch returns at `textract_result.rb:138`, row never flipped to `regenerating`, stays `current` stale; auto-gen ON → re-validates `:140`, enqueues at `:142`, lands STUCK `regenerating` (map:39). Confirmed: `:138` `return unless job_application&.job&.should_auto_generate_ai_summaries?`. `should_auto_generate_ai_summaries?` def at `job.rb:914-922`.

**AGREE** — else/auto branch enqueues `GenerateAiJobApplicationSummaryJob` with NO `requesting_organization_user_id` at `textract_result.rb:142`, so the resume-replacing user gets no toast (map:40). Confirmed: `:142` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id) if result.success?` — no requesting-user arg.

**AGREE** — no-resume removal terminal: `has_resume` false → `submit_resume_to_textract.rb:10` returns `'No resume attached'` before the stale `update_all` (`:18-20`) and the build (`:22`) (map:41). Confirmed: `:9` JobApplication-not-found guard, `:10` `return 'No resume attached' unless @job_application.has_resume`. Note: the prose cites `:9-10` for the "No resume attached" return; the precise line is `:10` (`:9` is the not-found guard), a benign over-cite.

## Omissions for T2

1. **T2 changelog (map:38, :41) does not restate that `update_all(stale: true)` is guarded.** The `update_all` at `submit_resume_to_textract.rb:19` is wrapped by `unless @job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).exists?` (`:18`). The changelog bullets cite `:18-19` / `:18-20` and describe the stale-marking as if it always fires in T2. It DOES fire in the documented succeeded-prior scenario (no non-stale `textract_processing` summary exists), so the narrative's conclusion is correct. The guard itself IS documented elsewhere in the map body (`:252`, `:295`, `:547` "conditional update_all", `:652` table). This is a T2-section completeness gap, not a contradiction. Concrete missed window: if a non-stale `textract_processing` summary already exists when the resume is replaced (e.g. a manual generate fired while no usable Textract existed and is still mid-flight), the `unless` is TRUE-skipping and NO summaries are staled by this T2 submit — the prior summaries keep `stale:false`.

2. **Waiting-summary relink behavior on the T2 path is not stated in the T2 section.** `submit_resume_to_textract.rb:25-26` relinks a `find_by(status: :textract_processing, stale: false, textract_result_id: nil)` summary to the new TextractResult after build. In the documented T2 succeeded-prior scenario this is a no-op (no such waiting summary), but in the guarded-skip window above it WOULD relink the in-flight waiting summary to the new TextractResult, which then changes the bridge branch (the `if` waiting-summary branch at `textract_result.rb:125` rather than the else/auto branch). The T2 section narrates only the else/auto branch.

3. **Job-level rescue swallow is not noted for T2.** `SubmitResumeToTextractJob#perform` wraps the service in `rescue StandardError` that only `ap`s (`submit_resume_to_textract_job.rb:9-11`), and `SubmitResumeToTextract` itself rescues `Aws::Textract::Errors::InvalidS3ObjectException` and `StandardError`, setting `@textract_result&.update_columns(textract_job_status: 'failed')` (`submit_resume_to_textract.rb:31-40`). On a Textract submit failure during a T2 replacement, the new TextractResult (if built) lands `failed` and no `queue_ai_summary_job` AI-pipeline continuation occurs; the already-staled prior summary is left `succeeded + stale:true` and the status row stays whatever it was — a no-further-actor resting state not described in the T2 section.

clean = false (omissions present; all explicit map statements AGREE).
