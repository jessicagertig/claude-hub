# analog-structural-matching — Round 1

Structural manifest diff of each new/changed unit vs its named analog.

## W1 `CreateAutoAiSummaryGeneration` vs `CreateAiSummaryGeneration` + `CreateBulkAiSummaryGeneration`
- SAME: `include Interactor`; reuse-guard (`where.not(status: :failed).where(stale: false).order(created_at: :desc).first` + stale-relink check); `.build(status: :textract_processing, requested_by_organization_user_id: ...)`; save-via-return-value (`context.fail! unless ai_summary.save`); NO job enqueue (matches the bulk sibling).
- DIFFERENT (spec-mandated, not flagged): `requested_by_organization_user_id: nil`; no `textract_result` set; four precondition guards inlined (option a) instead of calling `ValidateAiSummaryGeneration` (which would double-submit). Per REVIEW-ANGLES "deviations the spec REQUIRES."
- EXTRA: none. MISSING: none.

## W3 after_commit enqueue vs `handle_after_update_commit:495-515`
- SAME: `after_commit ... on: [:update]`; detection via the saved-change/`previous_changes` post-commit API. Uses `saved_change_to_*` (cleaner than the analog's string-keyed `previous_changes`, and avoids the latent symbol-key bug at `handle_visible_change:542`).
- DIFFERENT (justified): dedicated separate callback rather than appending into `handle_after_update_commit` — REQUIRED to bypass the `:496 skip_update_callback` early-return (W3.3). EXTRA: none beyond the spec'd helpers (`description_saved_change_is_meaningful?`, `sanitize_for_compare` — the latter is a pure refactor extraction also used by the retained `description_meaningfully_changed?`).

## W5 `record_failure` vs `update_summary_status_record:82-125`
- SAME: status-row `.update` with the identical denormalized column set (`ai_job_application_summary_id`, `status`, `score_percentage`, `headline`, `integrated_role_analysis`); `return unless ai_job_application_summary_status`; log-on-failure (not raise). DIFFERENT (spec-mandated): summary side uses `update_columns` (rescue-path re-entrancy) — not flagged. EXTRA/MISSING: none.

## W2 chain vs `submit_resume_to_textract.rb:27`
- SAME: chain the follow-on job from after the current step, gated. No deviation.

## W6 re-enqueue vs `textract_result.rb:128-131` / `create_ai_summary_generation.rb` generation-job call
- SAME: `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id:, requesting_organization_user_id:)`. No deviation.

## Findings
No structural mismatch. No EXTRA file/method the analog never had (the new interactor IS the third sibling; `record_failure` is the spec'd choke-point). No issues found.
