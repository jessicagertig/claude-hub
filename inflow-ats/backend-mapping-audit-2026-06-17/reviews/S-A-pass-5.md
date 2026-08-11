# S-A Adversarial Review — Pass 5

Slice S-A: Manual single generate. controller create -> ValidateAiSummaryGeneration -> CreateAiSummaryGeneration -> GenerateAiJobApplicationSummaryJob -> TextractResult#generate_ai_summary_with_credit_flow -> AiJobApplicationAction::Orchestrate.

Files traced (from scratch):
- `app/controllers/api/v1/ai_job_application_summaries_controller.rb:4-28`
- `app/interactors/validate_ai_summary_generation.rb:1-84`
- `app/interactors/create_ai_summary_generation.rb:1-80`
- `app/jobs/generate_ai_job_application_summary_job.rb:1-78`
- `app/models/textract_result.rb:61-144`
- `app/models/ai_job_application_summary.rb:1-90`
- `app/services/ai_job_application_action/orchestrate.rb:1-106`
- `app/models/job_application.rb:685-687`

## Verdicts on map S-A statements

1. Map: new fail-fast guard `context.fail!(...) unless has_job_description?` at `validate_ai_summary_generation.rb:29`, def `81-83` (`@job_application.job&.description.present?`).
   AGREE. validate_ai_summary_generation.rb:29 + :81-83.

2. Map: fail-fast guards precede Textract submit: `:24-25` nil, `:26` flipper AI_APPLICANT_SUMMARY, `:27` has_resume?, `:28` credits_available?, `:29` has_job_description?, before no-result branch reaches `SubmitResumeToTextractJob.perform_later` (`:39`).
   AGREE. validate_ai_summary_generation.rb:24-29 then :38-39. flipper_enabled? def :65-67 (Flipper.enabled?(:AI_APPLICANT_SUMMARY, @organization)).

3. Map: sibling branches: `:38-42` no-result → submit+pending+return; `:44-45` text_ready → pending=false; `:46-57` latest-failed-but-prior-not → resubmit `:55` + pending `:56`; `:52-53` both-failed → fail!; `:58-59` else → pending=true.
   AGREE. All confirmed validate_ai_summary_generation.rb:38-60.

4. Map (CHANGED): no-TextractResult branch is now `:38-42` (was `:37-41`).
   AGREE. validate_ai_summary_generation.rb:38-42.

5. Map (MAP-WRONG): `context.textract_result` assigned unconditionally at `:31-32`; `latest_textract_result` def `job_application.rb:685-687` (`textract_results.order(created_at: :desc).first`).
   AGREE. validate_ai_summary_generation.rb:31-32; job_application.rb:685-687.

6. Map: T9 waiting summary built at create_ai_summary_generation.rb `:47-51`, carries `requested_by_organization_user_id` (`:50`), sourced from `context.user` = controller current_user (`:20`).
   AGREE. create_ai_summary_generation.rb:47-51, :50 `requested_by_organization_user_id: context.user&.current_organization_user&.id`. Controller passes `user: current_user` at ai_job_application_summaries_controller.rb:20.

7. Map: bridge threads it into `GenerateAiJobApplicationSummaryJob(requesting_organization_user_id: ...)` at textract_result.rb:130; bridge if-branch re-validates at `:126`.
   AGREE. textract_result.rb:126-131.

8. Map (REMOVED/NEW): create_status_record callback gone; generate_ai_summary_with_credit_flow calls find_or_create_ai_job_application_summary_status (`:70`) + set_initial_summary_pending (`:72`); executes on later bridge/job run, not validate path.
   AGREE. ai_job_application_summary.rb:29-31 (no create_status_record). textract_result.rb:70,72. The credit flow runs in GenerateAiJobApplicationSummaryJob#perform (generate_ai_job_application_summary_job.rb:32), not in Validate.

9. Map (REUSE sub-case): active_ai_summary lookup `:30-34`; on no-Textract path latest_textract_result nil, prior textract_processing summary with textract_result_id nil → `nil != nil` false → not staled (`:36-39`) → reused+returned (`:41-44`) with no build/enqueue while Validate already submitted Textract (`:39`).
   AGREE. create_ai_summary_generation.rb:30-44; mismatch guard :36 `active_ai_summary.textract_result_id != job_application.latest_textract_result&.id`.

10. Map (FRESH-BUILD sub-case): no prior active summary (`:34` nil) → new :textract_processing summary built+saved (`:47-53`), returned WITHOUT enqueue, waiting for Textract poll/bridge.
    AGREE. create_ai_summary_generation.rb:46-58 (build :47-51, save :53, return :57).

11. Map NOTE: Validate invoked WITHOUT user: arg (controller `:8-11` passes only job_application + organization); context.user nil in Validate; user supplied only to Create (`:17-21`, user: current_user `:20`). Pre-validate gates: authorize `:6`, job_application scoping via exists `:5`.
    AGREE. ai_job_application_summaries_controller.rb:5-11, :17-21. Validate body reads no context.user.

12. Map NOTE (bridge query independence): bridge waiting-summary query filters only status: :textract_processing, stale: false, no textract_result_id filter (`textract_result.rb:121-123`).
    AGREE. textract_result.rb:121-123.

## Disputes
None. Every S-A statement verified against literal code.

## Omissions

O1 — The textract-READY sub-branch (slice sub-branch (i): "summary pending, job enqueued now") is NOT described on the Create side. The S-A bullets (map lines 130, 135-136) describe Validate's `:44-45 textract_text_ready? → textract_pending=false (proceeds into the AI pipeline)` but never state what CreateAiSummaryGeneration does on that path. Actual code: when `validation_result.textract_pending` is false (create_ai_summary_generation.rb:46 false), Create builds a `:pending` summary attached to `validation_result.textract_result` (create_ai_summary_generation.rb:60-64), saves it (`:70`), and enqueues `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: validation_result.textract_result.id, requesting_organization_user_id: context.user.current_organization_user.id)` IMMEDIATELY (`:71-74`). This is the entire point of sub-branch (i) and the map omits the build site, the :pending status write, and the synchronous-enqueue site for the manual ready path.

O2 — Active-summary REUSE on the READY path is undocumented. The map's reuse discussion (lines 135-136) is scoped only to the no-Textract path. On the ready path the same `active_ai_summary` lookup (`:30-34`) and mismatch-stale guard (`:36-39`) run: if a non-stale, non-failed active summary exists whose `textract_result_id` EQUALS `latest_textract_result.id`, it is REUSED and returned at `:41-44` with NO new :pending build and NO job enqueue — even though Validate found Textract ready. If the active summary's textract_result_id mismatches, it is staled (`update_columns(stale: true)`, `:37`) and a fresh :pending summary is built. The map documents neither the ready-path reuse terminal nor the ready-path mismatch-stale write.

O3 — Asymmetric nil-safety on the requesting-user arg is undocumented (minor). The :pending enqueue uses `context.user.current_organization_user.id` WITHOUT safe-nav (create_ai_summary_generation.rb:73), whereas the build uses `context.user&.current_organization_user&.id` with safe-nav (`:50`, `:63`). On the manual S-A path context.user is the authenticated current_user so this does not raise in practice, but it is an unguarded chain distinct from the rest of the method. Not load-bearing for the documented terminals.

## Record-write sites on S-A path (for coverage)
- create_ai_summary_generation.rb:37 — `active_ai_summary.update_columns(stale: true)` — writes `stale` on AiJobApplicationSummary (update_columns). Reachable on BOTH paths when a mismatched active summary exists.
- create_ai_summary_generation.rb:53 — `ai_summary.save` build of :textract_processing summary — writes status (=textract_processing), textract_result_id, requested_by_organization_user_id (insert/save, callback-firing).
- create_ai_summary_generation.rb:70 — `ai_summary.save` build of :pending summary — writes status (=pending), textract_result_id, requested_by_organization_user_id (insert/save).
- textract_result.rb:104-107 — set_initial_summary_pending update_columns on AiJobApplicationSummaryStatus (initial_summary_pending) — fires on the later job run, not the validate path.

clean = false (omissions present).
