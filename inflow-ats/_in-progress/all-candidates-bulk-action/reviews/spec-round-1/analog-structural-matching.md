# Analog Structural Matching — Round 1

## Findings

### Controller parameter interface
- Existing `create`: `params.require(:bulk_ai_job_application_summary).permit(:job_id, :hiring_stage_id, included_job_application_ids: [], excluded_job_application_ids: [], role_fit: [])` (controller:48-54)
- New `all_stages`: same `params.require(:bulk_ai_job_application_summary)` top-level key. Same params method with `rescore_requested` added. ✅ Matches.

### Controller response shape
- Existing `create` returns `{ queued_count:, skipped_count:, any_textract_pending: }` (controller:20-23)
- Spec says `all_stages` returns "Same shape as the existing `create` action". ✅ Matches.

### Controller error handling
- Existing `create`: `render_general_errors([result.error])` (controller:26)
- Spec says `all_stages`: "Render the same response shape as `create`". Implicitly includes error handling. ✅ Acceptable.

### Interactor context reads
- Existing: `context.organization`, `context.user`, `context.job_application_ids` (interactor:13-15)
- New: adds `context.kind` and `context.rescore_requested`. Both are additive, existing callers unaffected. ✅ Matches.

### Job payload shape
- Existing: `bulk_job_id`, `user_id`, `hiring_stage_id`, `job_id`, `job_application_ids`, `skipped_count` (interactor:82-89)
- New: adds `kind`. For all-stages, `hiring_stage_id` will be from `first.hiring_stage_id` — first candidate's stage. The `notify_complete` branching ignores `hiring_stage_id` when `kind` is `"all_stages"`. ✅ Matches.

### Mailer method signatures
- Existing `complete`: `(user_id, job_id, succeeded_count, failed_count, skipped_count, hiring_stage_id)` with `User.find`, `Job.find`, `Emails::SendTemplateEmail.new(message_params).send` (mailer:4-28)
- New `complete`: `(user_id, job_id, succeeded_count, failed_count, skipped_count)` — same minus `hiring_stage_id`. Must follow same `User.find`, `Job.find`, `Emails::SendTemplateEmail` pattern. Spec says "following the structure of" the analog. ✅ Matches.

### Mailer `.deliver_later`
- Existing: chained at job:144 and job:171
- Spec now explicitly states `.deliver_later` required per known failure pattern #4 (added in this round). ✅ Matches.

### Modal behavioral props
- Analog `BulkGenerateAiSummariesConfirmModal`: `loading={isLoading}` and `disabled={isLoading || processableCount === 0}` on Button (modal:136-137)
- Spec says "Review all" primary button with loading state". Must also include `disabled` prop per known failure pattern #11. The spec mentions loading but not disabled explicitly.

- F1 [MED] Spec "RunPlatoReviewAllModal" Actions section says "Review all" primary button with loading state" but does not mention `disabled` prop. Per known failure pattern #11 and the analog at BulkGenerateAiSummariesConfirmModal:137, the button must be disabled while loading (and when `candidatesToScoreCount === 0`). Add explicit mention.

## Amendments Applied

- Spec "RunPlatoReviewAllModal" section: changed "Review all" primary button with loading state" to "Review all" primary button with `loading` and `disabled` props (disabled when loading or when `candidatesToScoreCount` is 0), following `BulkGenerateAiSummariesConfirmModal` and known failure pattern #11"
