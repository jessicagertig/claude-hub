# T9 — Adversarial Review (pass 4)

**Slice:** T9 — Manual generate when no TextractResult exists: `ValidateAiSummaryGeneration` kicks off Textract. Trace the validate path that initiates Textract and the state the summary is left in.

**Candidate map:** `backend-flow-map-2026-06-17.md`, primarily the section "Trigger 9 / Trigger A — Manual Single Generation (T9, S-A)" (lines 113-121).

Files traced this pass (from scratch):
- `app/controllers/api/v1/ai_job_application_summaries_controller.rb` (create action :4-28)
- `app/interactors/validate_ai_summary_generation.rb` (:6-83)
- `app/interactors/create_ai_summary_generation.rb` (:19-78)
- `app/models/textract_result.rb` (:114-144 bridge)
- `app/models/job_application.rb` (:28-32 associations, :685-687 `latest_textract_result`)
- `app/models/ai_job_application_summary.rb` (:10-23 enum + BROADCAST_STATUSES)
- `app/models/user.rb:38` (`belongs_to :current_organization_user`)

Chain: `ai_job_application_summaries_controller.rb:8 → validate_ai_summary_generation.rb:38-42 → create_ai_summary_generation.rb:30-58 → textract_result.rb:121-131`.

---

## Verdicts

### Claim (map :114) — Validate adds fail-fast guard `context.fail!(...) unless has_job_description?` at `:29`, def at `:81-83` = `@job_application.job&.description.present?`. Error: "This job needs a description before Plato can review candidates. Add one in Job Setup."
**AGREE.** `validate_ai_summary_generation.rb:29` literal: `context.fail!(error: 'This job needs a description before Plato can review candidates. Add one in Job Setup.') unless has_job_description?`. Def at `:81-83`: `def has_job_description? / @job_application.job&.description.present? / end`. Error string matches exactly.

### Claim (map :115) — No-TextractResult branch is now at `:38-42` (shifted from old `:37-41`).
**AGREE.** `validate_ai_summary_generation.rb:38-42`: `unless @latest_textract_result` / `SubmitResumeToTextractJob.perform_later(@job_application.id)` (:39) / `context.textract_pending = true` (:40) / `return` (:41) / `end` (:42).

### Claim (map :116) — `context.textract_result` assigned unconditionally at `:31-32` (nil on no-TextractResult path), before any branch. `latest_textract_result` def `job_application.rb:685-687`, `textract_results.order(created_at: :desc).first`, nil when none.
**AGREE.** `validate_ai_summary_generation.rb:31` `@latest_textract_result = @job_application.latest_textract_result`; `:32` `context.textract_result = @latest_textract_result`. Both run before the `unless @latest_textract_result` branch at `:38`. `job_application.rb:685-687`: `def latest_textract_result / textract_results.order(created_at: :desc).first / end` — nil when no results.

### Claim (map :117) — `create_status_record` callback gone; `generate_ai_summary_with_credit_flow` now calls `find_or_create_ai_job_application_summary_status` + `set_initial_summary_pending` before the pipeline (`textract_result.rb:70-72`); executes on later bridge/job run, NOT on the T9 validate path.
**AGREE (T9-relevant portion).** `ai_job_application_summary.rb:29-31` shows only `destroy_previous_textract_results`, `update_summary_status_record`, `broadcast_status_change` — no `create_status_record`. On the T9 validate path proper, neither `find_or_create_ai_job_application_summary_status` nor `set_initial_summary_pending` is reached: the T9 controller path is `ValidateAiSummaryGeneration` then `CreateAiSummaryGeneration`; `generate_ai_summary_with_credit_flow` is reached only later via the bridge/job. (The `:70-72` line numbers are outside the T9 slice's traced range; the qualifier "executes on the later bridge/job run, not on the T9 validate path itself" is correct and is the load-bearing T9 claim.)

### Claim (map :118) — The waiting `textract_processing` summary `CreateAiSummaryGeneration` builds (`:47-51`) carries `requested_by_organization_user_id` (`:50`, sourced from `context.user = controller current_user` at `:20`). Bridge threads it into `GenerateAiJobApplicationSummaryJob(requesting_organization_user_id: ...)` at `textract_result.rb:130`, producing the eventual `AI_SUMMARY_COMPLETE` toast. After Textract succeeds, the bridge `if` branch re-validates (`textract_result.rb:126`) and enqueues the job WITH the requesting user.
**AGREE.** `create_ai_summary_generation.rb:46-51`: build with `status: :textract_processing` (:49) and `requested_by_organization_user_id: context.user&.current_organization_user&.id` (:50). `context.user` is `current_user` per controller `:20` (`user: current_user`). `user.rb:38` `belongs_to :current_organization_user` confirms `.current_organization_user.id` resolves. Bridge: `textract_result.rb:121-123` selects `ai_summary_waiting_on_textract`; `:125` `if ai_summary_waiting_on_textract`; `:126` `result = ValidateAiSummaryGeneration.call(...)`; `:128-131` enqueues `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id, requesting_organization_user_id: ai_summary_waiting_on_textract.requested_by_organization_user_id)`. (Map line 130 cite is correct.)

### Claim (map :119) — Active-summary reuse on the no-Textract path. Before building the waiting summary, `CreateAiSummaryGeneration` looks up `active_ai_summary` (`:30-34`, `.where.not(status: :failed).where(stale: false).order(created_at: :desc).first`). On no-Textract path `job_application.latest_textract_result` is nil, so a prior `textract_processing` summary with `textract_result_id: nil` matches the mismatch guard as equal (`nil != nil` is false) and is NOT staled (`:36-39`); it is REUSED and returned (`:41-44`) with NO new build and NO enqueue — while `ValidateAiSummaryGeneration` has ALREADY submitted Textract (`:39`).
**AGREE.** `create_ai_summary_generation.rb:30-34`: `active_ai_summary = job_application.ai_job_application_summaries.where.not(status: :failed).where(stale: false).order(created_at: :desc).first`. `:36` `if active_ai_summary && active_ai_summary.textract_result_id != job_application.latest_textract_result&.id`. On the no-Textract path `latest_textract_result` is nil; a prior `textract_processing` summary with `textract_result_id: nil` gives `nil != nil` = false → guard body (`:37-38` stale + nil-out) skipped → `:41` `if active_ai_summary` → `:42` `context.ai_summary = active_ai_summary` → `:43` `return`. No `.build`, no `GenerateAiJobApplicationSummaryJob.perform_later`. And `validate_ai_summary_generation.rb:39` already enqueued `SubmitResumeToTextractJob`. Claim is correctly scoped to the `textract_result_id: nil` prior-summary case; a prior `textract_processing` summary with a non-nil (old) `textract_result_id` would instead be staled at `:37` (`non_nil != nil` true). The map states the `nil` precondition explicitly, so the claim is accurate.

### Claim (map :120) — On manual T9, `ValidateAiSummaryGeneration` invoked WITHOUT a `user:` arg (`controller :8-11` passes only `job_application:` and `organization:`), so `context.user` is nil inside Validate (immaterial — Validate reads no user); user supplied only to `CreateAiSummaryGeneration` (`:17-21`, `user: current_user` at `:20`). Pre-validate gates: `authorize :ai_job_application_summary, :create?` (`:6`) and scoping to `current_organization.job_applications` via `exists(...)` (`:5`).
**AGREE.** `ai_job_application_summaries_controller.rb:8-11`: `ValidateAiSummaryGeneration.call(job_application: job_application, organization: current_organization)` — no `user:`. `:17-21`: `CreateAiSummaryGeneration.call(job_application:, validation_result:, user: current_user)` with `user: current_user` at `:20`. Validate body reads `context.job_application`/`context.organization` only (never `context.user`), confirming "immaterial." `:6` `authorize :ai_job_application_summary, :create?`; `:5` `exists(current_organization.job_applications.where(id: params[:job_application_id]), 'Job application not found')`.

### Claim (map :121) — Bridge waiting-summary query filters only `status: :textract_processing, stale: false` with no `textract_result_id` filter (`textract_result.rb:121-123`), so the waiting summary is found independent of the relink at `submit_resume_to_textract.rb:26`.
**AGREE (T9-relevant portion).** `textract_result.rb:121-123`: `job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).first` — no `textract_result_id` predicate. The waiting summary is selectable regardless of whether its `textract_result_id` was relinked. (The `submit_resume_to_textract.rb:26` cite is outside the traced T9 range, but the load-bearing assertion — "no textract_result_id filter on the bridge query" — is verified.)

---

## Omissions (T9 things the map does not state for this slice)

1. **Textract-already-ready and textract-failed branches of the same Validate method are not part of the T9 section.** T9 scope is "no TextractResult exists," but `validate_ai_summary_generation.rb` has three other branches off the SAME entry: `:44-45` `textract_text_ready?` → `context.textract_pending = false` (advances directly into the AI pipeline build of a `:pending` summary at `create_ai_summary_generation.rb:60-74`), `:46-57` latest-failed-but-prior-not → re-submits Textract (`:55`) and sets `textract_pending = true`, and `:52-53` both-failed → `context.fail!` dead end. The map's T9 section documents only the no-result branch. The branch-logic requirement of this audit ("state which branch your path takes") is satisfied for the no-result path but the sibling branches that a "manual generate" click could also hit are not enumerated in the T9 section. (Minor: they belong more to S-A/S-E; noting for completeness.)

2. **The `textract_pending`-true build path's terminal state (fresh app, no prior summary) is not spelled out in T9.** When NO prior active summary exists on the no-Textract path (`active_ai_summary` nil at `create_ai_summary_generation.rb:34`), the code builds a NEW `:textract_processing` summary (`:47-51`) and saves it (`:53`), returning WITHOUT enqueuing any job (the `:46-58` block has no `perform_later`). The summary is left at `textract_processing` waiting for the Textract poll → bridge to advance it. The map's :119 covers only the REUSE sub-case ("prior `textract_processing` summary ... is REUSED"); it does not state the fresh-build sub-case where a brand-new `textract_processing` summary is created and left waiting. Both are valid T9 terminal states for "no TextractResult exists."

3. **No-resume / no-credit / no-job-description fail-fast exits of Validate are not noted as T9 terminals.** `validate_ai_summary_generation.rb:27` (`unless has_resume?`), `:28` (`unless credits_available?`), `:29` (`unless has_job_description?`), `:26` (flipper), `:24-25` (nil guards) all `context.fail!` BEFORE the `:38` no-result branch, so a manual generate with no resume never reaches `SubmitResumeToTextractJob.perform_later` at `:39`. The map's T9 section lists the `has_job_description?` guard (:114) but does not note that these guards short-circuit ahead of the Textract-submit branch — relevant because the slice's framing ("kicks off Textract") only holds once these pass.

---

## Conclusion

Every map statement about T9 verified as AGREE against literal code. Three omissions noted (sibling Validate branches, the fresh-build `textract_processing` terminal not just the reuse sub-case, and the fail-fast guards that precede the Textract submit). Because omissions is non-empty, **clean = false**.
