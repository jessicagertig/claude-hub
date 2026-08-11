# source-accuracy (always-on) — Round 1

Verified SPEC `file:line` references against the committed worktree.

- `create_ai_summary_generation.rb:36` — gate line, now `if active_ai_summary && !job_application.ai_summary_rescore_requested`. ✓
- `create_bulk_ai_summary_generation.rb:45` — pinned gate string, identical. ✓
- `bulk_ai_job_application_summaries_controller.rb:77-86` — `require(...).require(:rescore_requested)` pattern source. ✓ (mirrored)
- `BulkGenerateAiSummariesConfirmModal.tsx` pre-commit `:74` was `rescoreRequested: false` (confirmed via `f9ec4a80d~1`); now `rescoreRequested: rescore` (:77 post-commit). ✓
- `organization_user.rb:48` — `scope :actives, -> { where(is_active: true) }`. ✓
- `job_application_mailer.rb:19,28-32` — recipient analog (`actives`, `.map`→`{name,email}`, `return unless recipients.any?`). ✓
- `job_application.rb:11` — `attribute :ai_summary_rescore_requested, :boolean, default: false`. ✓
- `CustomQuestionModal/index.js` `Styled.Info` (:254-273) + usage (:192-199) — matches the copied block. ✓
- `RunPlatoReviewAllModal.tsx` `Styled.Statement` styles + `RescoreCheckbox` — match the per-stage copies. ✓
- `FormCheckbox/index.tsx` contract (`name/label/checked/onChange/disabled?/description?`) — matches usage. ✓
- `PlatoTab.tsx:247` — Regenerate gating line. ✓

All referenced paths, classes, methods, columns, and line anchors resolve. The green rspec run implicitly confirms `job.organization_users.actives`, `organization_user.user.{first_name,last_name,email}`, and `job_application.ai_summary_rescore_requested` runtime validity.

## Findings
No issues found.
