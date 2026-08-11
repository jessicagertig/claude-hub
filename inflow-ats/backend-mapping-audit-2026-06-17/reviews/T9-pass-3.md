# T9 — Adversarial Review (Pass 3)

**Slice:** T9 — Manual generate when no TextractResult exists: `ValidateAiSummaryGeneration` kicks off Textract. Trace the validate path that initiates Textract and the state the summary is left in.

**Method:** Re-read current code from scratch. Files traced:
`ai_job_application_summaries_controller.rb` → `validate_ai_summary_generation.rb` → `create_ai_summary_generation.rb` → `job_application.rb:589,685` → `submit_resume_to_textract.rb` → `textract_result.rb:114-144` → `generate_ai_job_application_summary_job.rb` → `ai_job_application_summary.rb:10-23,102`.

---

## Candidate map statements (T9 / Trigger 9 sections) and verdicts

### Changelog "Trigger 9 / Trigger A" (lines 98-104)

1. **Map (L99): `ValidateAiSummaryGeneration` adds fail-fast guard `context.fail!(...) unless has_job_description?` (`validate_ai_summary_generation.rb:29`, def at `81-83`: `@job_application.job&.description.present?`).**
   AGREE. `validate_ai_summary_generation.rb:29` is the guard; `:81-83` is `def has_job_description?` / `@job_application.job&.description.present?`.

2. **Map (L100): no-TextractResult branch is now `:38-42` (line-shift from old `:37-41`).**
   AGREE. `:38` `unless @latest_textract_result`, `:39` `SubmitResumeToTextractJob.perform_later(@job_application.id)`, `:40` `context.textract_pending = true`, `:41` `return`, `:42` `end`.

3. **Map (L101): `context.textract_result` assigned unconditionally at `:31-32` (nil on no-TextractResult path), before any branch (`latest_textract_result` def `job_application.rb:686`).**
   AGREE. `:31` `@latest_textract_result = @job_application.latest_textract_result`; `:32` `context.textract_result = @latest_textract_result`. On the no-result path `latest_textract_result` (`job_application.rb:685-687` `textract_results.order(created_at: :desc).first`) is nil, so `context.textract_result` is nil. Both assignments precede the `unless` branch at `:38`.

4. **Map (L103): waiting `textract_processing` summary `CreateAiSummaryGeneration` builds (`:47-51`) carries `requested_by_organization_user_id` (`:50`, sourced from `context.user`).**
   AGREE. `create_ai_summary_generation.rb:47-51` builds with `status: :textract_processing` and `requested_by_organization_user_id: context.user&.current_organization_user&.id` at `:50`.

5. **Map (L103): the bridge threads it into `GenerateAiJobApplicationSummaryJob(requesting_organization_user_id: ...)` at `textract_result.rb:130`, producing the eventual `AI_SUMMARY_COMPLETE` toast.**
   AGREE. `textract_result.rb:128-131` enqueues with `requesting_organization_user_id: ai_summary_waiting_on_textract.requested_by_organization_user_id` (`:130`); `generate_ai_job_application_summary_job.rb:34` calls `broadcast_completion` when `requesting_organization_user_id` present; `:72-76` broadcasts `action: 'AI_SUMMARY_COMPLETE'`.

6. **Map (L103): after Textract succeeds the bridge `if` branch re-validates (`textract_result.rb:126`) and enqueues the job WITH the requesting user, driving the same summary `textract_processing → extracting → … → succeeded`.**
   AGREE (mechanism). `textract_result.rb:121-123` selects `ai_summary_waiting_on_textract` by `where(status: :textract_processing, stale: false).first` (no `textract_result_id` filter, so the relinked waiting summary is found); `:125` `if ai_summary_waiting_on_textract`; `:126` re-runs `ValidateAiSummaryGeneration.call`; `:127-131` enqueues `GenerateAiJobApplicationSummaryJob` with the requesting user on success. The downstream status progression is documented in S-E/handoff slices.

7. **Map (L104) NOTE: on T9, `ValidateAiSummaryGeneration` is invoked WITHOUT a `user:` arg (`ai_job_application_summaries_controller.rb:8-11` passes only `job_application:` and `organization:`); `context.user` is nil inside Validate (immaterial — Validate reads no user); user supplied only to `CreateAiSummaryGeneration` (`:17-21`).**
   AGREE. Controller `:8-11` `ValidateAiSummaryGeneration.call(job_application:, organization:)` — no `user:`. `grep` for `context.user`/`current_user` in `validate_ai_summary_generation.rb` returns nothing, so Validate reads no user. `CreateAiSummaryGeneration.call(... user: current_user)` at controller `:17-21` (`user: current_user` at `:20`).

### Part 1 "Trigger 9" detail (lines 278-282)

8. **Map (L281): after fail-fast guards (incl. NEW `has_job_description?` at `:29`), `context.textract_result` assigned unconditionally at `:31-32`; when `latest_textract_result` is nil (`:38`): `SubmitResumeToTextractJob.perform_later` (`:39`), `context.textract_pending = true` (`:40`), bare `return` (`:41`) → interactor SUCCESS.**
   AGREE. As lines 38-42. `return` with no `context.fail!` = Interactor success.

9. **Map (L282): `CreateAiSummaryGeneration` builds an `AiJobApplicationSummary` `status: :textract_processing`, `textract_result: nil`, carrying `requested_by_organization_user_id` (`:47-51`), no job enqueued.**
   AGREE. `create_ai_summary_generation.rb:47-51` builds with `textract_result: validation_result.textract_result` (which is nil on this path, per #3) and `status: :textract_processing`; the `textract_pending` branch (`:46-58`) saves but does NOT call `GenerateAiJobApplicationSummaryJob` (that is only the non-pending branch at `:71`). `textract_processing` = enum value 1 (`ai_job_application_summary.rb:12`).

10. **Map (L282): `SubmitResumeToTextract` later links `textract_result_id` onto this waiting summary (`submit_resume_to_textract.rb:25-26`).**
    AGREE. `:25` `waiting_summary = @job_application.ai_job_application_summaries.find_by(status: :textract_processing, stale: false, textract_result_id: nil)`; `:26` `waiting_summary&.update_columns(textract_result_id: @textract_result.id)`.

---

## Omissions (for the T9 slice)

- **CreateAiSummaryGeneration active-summary reuse early return on the no-Textract path.** The map's T9 section describes only the build path of the waiting summary. It omits that `CreateAiSummaryGeneration` first looks up an `active_ai_summary` (`create_ai_summary_generation.rb:30-34`, `.where.not(status: :failed).where(stale: false).order(created_at: :desc).first`). If a non-stale non-failed summary exists whose `textract_result_id == job_application.latest_textract_result&.id` (on the no-Textract path that id is nil, so a prior `textract_processing` summary with `textract_result_id: nil` matches), it is REUSED and returned (`:41-44`) with NO new build and NO enqueue. Validate has already submitted Textract (`:39`) regardless. This is a distinct "state the summary is left in" on the T9 path that the map does not record.

- **Pre-validate controller gates.** The map's T9 trace begins at Validate and does not note that `create` is gated by `authorize :ai_job_application_summary, :create?` (`ai_job_application_summaries_controller.rb:6`) and that the job_application is scoped to `current_organization.job_applications` via `exists(...)` (`:5`). Minor; arguably outside the narrow validate-to-Textract slice.

- **Bridge query does not filter on `textract_result_id`.** The map (L103, #6) asserts the bridge `if` branch picks up "the same summary" but does not make explicit WHY relinking in `SubmitResumeToTextract` (`:26`) is not required for the bridge to find it: `textract_result.rb:121-123` filters only `status: :textract_processing, stale: false` (no `textract_result_id`), so the waiting summary is found even before/independent of the relink. Load-bearing for the T9 terminal claim; worth stating.

## Minor citation note (not a dispute)

- Map (L103) says the requesting user is "sourced from `context.user = controller current_user` at `:20`." The substantive sourcing is `create_ai_summary_generation.rb:50` (`context.user&.current_organization_user&.id`). The `:20` reference matches controller line 20 (`user: current_user`) if read as the controller file, but the file is unstated and `create_ai_summary_generation.rb:20` is `job_application = context.job_application`. Ambiguous citation; the `:50` claim it accompanies is correct, so not scored as a dispute.

---

## Verdict

All 10 map statements about the T9 slice AGREE against current code. Omissions list is non-empty (the CreateAiSummaryGeneration active-summary reuse early return is a genuine missing state on this path), so **clean = false**.
