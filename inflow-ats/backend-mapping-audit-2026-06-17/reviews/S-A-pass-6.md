# S-A Adversarial Review — Pass 6

**Slice:** S-A — Manual single generate. controller create → ValidateAiSummaryGeneration → CreateAiSummaryGeneration → GenerateAiJobApplicationSummaryJob → AiJobApplicationAction::Orchestrate.
**Method:** Re-read all S-A code from scratch; attempted to refute every map statement about S-A against literal code.

## Files opened and traced

- `app/controllers/api/v1/ai_job_application_summaries_controller.rb`
- `app/interactors/validate_ai_summary_generation.rb`
- `app/interactors/create_ai_summary_generation.rb`
- `app/jobs/generate_ai_job_application_summary_job.rb`
- `app/services/ai_job_application_action/orchestrate.rb`  ← NOTE: lives under `app/services/`, NOT `app/interactors/`
- `app/models/textract_result.rb`
- `app/models/job_application.rb` (lines 29-34, 160-171, 685-687)
- `db/schema.rb` (ai_job_application_summaries cols)
- `config/routes.rb:302`

## Verdicts (all AGREE)

Every S-A line citation in the candidate map matches the current code exactly:

- Controller `:5` exists-scope, `:6` authorize, `:8-11` Validate call (job_application+organization only, no user), `:17-21` Create call, `:20` `user: current_user`. ✓
- Route `ai_job_application_summaries, only: [:show, :create]` at `config/routes.rb:302`. ✓
- Validate fail-fast `:24` (job app nil), `:25` (org nil), `:26` flipper AI_APPLICANT_SUMMARY, `:27` has_resume?, `:28` credits_available?, `:29` has_job_description? (def `:81-83` `@job_application.job&.description.present?`). ✓
- `context.textract_result` assigned unconditionally `:31-32` (`latest_textract_result` def at `job_application.rb:685-687`). ✓
- Branch fork in Validate: `:38-42` no-result (submit `:39`, pending=true `:40`, return `:41`); `:44-45` text-ready (pending=false); `:46-57` latest-failed-but-prior-not (resubmit `:55`, pending=true `:56`); `:52-53` both-failed `fail!`; `:58-59` else pending=true. ✓
- `textract_text_ready?` def `:73-75`. ✓
- Create active-summary lookup `:30-34`; mismatch-stale guard `:36-39`; reuse return `:41-44`; branch point `:46`; textract_processing build `:47-51` (`:50` `requested_by_organization_user_id` via `context.user&.current_organization_user&.id`), save `:53`, fail! `:55`, return `:57`. ✓
- Ready-path `:pending` build `:60-64`, save `:70`, enqueue `:71-74` (`textract_result_id: validation_result.textract_result.id`, `requesting_organization_user_id: context.user.current_organization_user.id` — NO safe-nav at `:73`, vs safe-nav at `:50`/`:63`). ✓
- Generation job `:13` retry_on; `:24` perform sig; `:30` return unless textract_result; `:32` generate_ai_summary_with_credit_flow; `:34` broadcast_completion if requesting_organization_user_id; failed-only writers `:19` and `:44`. ✓
- `generate_ai_summary_with_credit_flow`: early-return `:67-68`; find_or_create + set_initial_summary_pending `:70-72`; self-scoped `:77`; return unless succeeded `:82`; credit `:84`. ✓
- Bridge `queue_ai_summary_job` (after_commit `:7`, def `:114`): waiting query `:121-123`; if `:125`; re-validate `:126`; enqueue with requesting user `:128-130` (`requested_by_organization_user_id` at `:130`); else auto `:138` (should_auto_generate), `:140` validate, `:142` enqueue no requesting user. ✓
- Orchestrate selection `:15` (JobApplication-scoped, no stale filter), return unless `:16`; succeeded/failed return `:46-48`; awaiting_job_criteria write `:72`. ✓
- No-Textract nil-match logic confirmed: on no-Textract path `latest_textract_result` is nil; a prior `textract_processing` summary built at `:48` with `validation_result.textract_result` (nil) has `textract_result_id: nil`; `:36` `nil != nil` is false → not staled → reused. ✓
- Asymmetric nil-safety `:73` (no safe-nav) vs `:50`/`:63` (safe-nav). ✓

## Branch point (per prompt requirement)

Both sub-branches are determined by `context.textract_pending`, set in `ValidateAiSummaryGeneration` (`:40`/`:45`/`:56`/`:59`) and consumed at the single dispatch in `CreateAiSummaryGeneration` `:46` (`if validation_result.textract_pending`):
- (i) Textract ready → `textract_pending=false` (validate `:45`) → Create `:46` else arm → `:pending` summary built `:60-64`, `GenerateAiJobApplicationSummaryJob` enqueued NOW `:71-74`.
- (ii) Textract pending → `textract_pending=true` → Create `:46` if arm → `:textract_processing` summary `:47-53`, NO job; waits for `TextractResult#queue_ai_summary_job` bridge (`:114`, waiting query `:121-123`, enqueue `:128-130`).

## Omissions

None material to S-A. Every S-A statement, terminal, and sub-branch is documented with correct citations. The ready-path AI_SUMMARY_COMPLETE broadcast is covered via the Part 7 matrix (line 692) and is structurally implied by `:73` supplying the requesting user + job `:34` broadcast.

## Result

clean = true. Every verdict AGREE; omissions empty.
