# analog-structural-matching — Round 1

Built a structural manifest for each new/changed unit vs its named analog (hub CLAUDE.md "match STRUCTURE not PROCESS"; pipeline #14/#16). SAME / DIFFERENT(justified) / EXTRA / MISSING per row.

## W1 — CreateAutoAiSummaryGeneration vs CreateAiSummaryGeneration (+ Bulk)
| element | single analog | NEW (per spec) | verdict |
|---|---|---|---|
| `include Interactor` | yes | yes (3rd sibling) | SAME |
| context inputs | job_application, validation_result, user | job_application only | DIFFERENT (justified: no user, builds guards inline) |
| reuse-guard active lookup (`where.not(status::failed).where(stale:false).order(created_at::desc).first`) | `:30-34` | spec line 27 "mirror :30-44" | SAME |
| reuse-guard stale-relink (`:36-39`) | present | included via :30-44 (dead at intake, live on clone) | SAME (analog wins) |
| build status `:textract_processing` | textract_pending branch `:47-53` | yes (line 28) | SAME |
| build `textract_result:` | set `:48` | NOT set (line 28) | DIFFERENT (spec-mandated: no TextractResult at intake — do NOT flag) |
| build `requested_by_organization_user_id:` | `context.user&...&.id :50` | `nil` (line 28) | DIFFERENT (spec-mandated: no requesting user — do NOT flag) |
| save via return-value | `:53-56` | yes (line 28) | SAME |
| enqueue job | NO (textract_pending branch) | NO (line 28) | SAME |
| precondition guards | via ValidateAiSummaryGeneration | 4 guards inline, NOT Validate | DIFFERENT (spec-mandated: Validate double-submits — do NOT flag) |
No EXTRA file/method; no MISSING layer. The three DIFFERENT rows are the spec-mandated deviations REVIEW-ANGLES angle 7 lists as do-not-flag. STRUCTURALLY SOUND.

## Findings

- **F1 [MED]** -- W3 after-commit mechanism should match the analog's `previous_changes` pattern (option b), not introduce a new instance-flag mechanism (option a) as the PREFERRED path. The analog `handle_after_update_commit` (`job.rb:491-511`) detects what changed purely via `previous_changes.keys & fields` (`:501,:507`) -- no instance flags. The criteria-enqueue angle's Round-1 amendment PREFERRED option (a) (capture decision in before_update into an instance flag). Per pipeline #14 (callback patterns -- follow the analogous `after_commit`) and REVIEW-ANGLES angle 7 ("must use the `previous_changes`-driven `after_commit` pattern ... not a new mechanism"), option (b) is the analog-matching approach. It is viable AND correct provided the description-meaningful-change check is rewritten to read `previous_changes[:description]&.first`/`&.last` (which post-commit holds `[old,new]`) instead of `description_was`, and publish is detected via `previous_changes.key?(:status) && published?`. Fix: reword the W3 change to make option (b) (`previous_changes`, analog-matching) the primary, with option (a) as an acceptable fallback only if the plan finds the rewrite too error-prone (and noting (a) introduces a mechanism the analog lacks). Keep both correctness requirements from the criteria angle (description rewrite under (b); skip_update_callback non-gating; only the call relocates). APPLIED (reconciles the criteria-enqueue angle amendment with analog-structural).

## Verified-correct (no change)
- W3 vs analog: post-commit `.save`-then-enqueue ordering matches the analog's post-commit enqueue; not touching the out-of-txn `orchestrate.rb:80`/`score_job_application.rb:23,45` callers. CONFIRMED.
- W5 `record_failure` vs `update_summary_status_record` (`:74-80`): same row `.update` shape, same denormalized-column set (cleared instead of set), `return unless ai_job_application_summary_status` guard mirrored. Summary-side `update_columns` is the spec-mandated deviation (rescue re-entrancy) -- do NOT flag. STRUCTURALLY SOUND. CONFIRMED.
- W2 chain vs `submit_resume_to_textract.rb:27`: same "chain the next step" shape; the deviation (runs after a rescued method, not inside a save-success guard) is justified (Textract must be attempted even on conversion failure). CONFIRMED.
- W6 re-enqueue vs bridge if-branch (`textract_result.rb:128-131`): W6 adds `requesting_organization_user_id:` to match the analog's `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id:, requesting_organization_user_id:)` shape. Pure structural alignment. CONFIRMED.
- No EXTRA files/methods beyond spec across all workstreams; no new payment-area method (W1/W6). No unspec'd migration/job/sweeper. CONFIRMED (no BLOCKER).

## Amendments Applied
- SPEC.md W3 (line 72): make option (b) (`previous_changes`, matching the `handle_after_update_commit` analog) the PRIMARY mechanism; option (a) (instance flag) a fallback noting it deviates from the analog. Retain the description-rewrite-under-(b) and skip_update_callback-non-gating requirements.
