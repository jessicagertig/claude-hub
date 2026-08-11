# source-accuracy (always-on) — Round 2

Verified SPEC `file:line` references against the committed worktree (f9ec4a80d).

- `create_ai_summary_generation.rb:36` — gate line, `if active_ai_summary && !job_application.ai_summary_rescore_requested`. ✓
- `create_bulk_ai_summary_generation.rb:45` — pinned gate, string identical. ✓
- `ai_job_application_summaries_controller.rb` — attribute set line 17 before `CreateAiSummaryGeneration.call` (:19); `ai_job_application_summary_params` private method (:43-45). ✓
- `job_application_mailer.rb:19,28-32` — recipient analog (`.actives`, `.includes(:user)`, `.map`→`{name,email}` with first+last `.strip`, `return unless recipients.any?`). New mailer faithfully copies the shape minus the opt-out scope. ✓
- `organization_user.rb:48` — `actives` scope (confirmed via green rspec exercising `job.organization_users.actives`). ✓
- `RunPlatoReviewAllModal.tsx` — `Styled.Statement` / `RescoreCheckbox` styles are the copy source for the per-stage `_Statement`; `candidatesCount` prop defined (:20/:27). ✓
- `CustomQuestionModal/index.js` `Styled.Info` — matches the copied `_Info` block. ✓
- `PlatoTab.tsx:247` — Regenerate gating line. ✓
- `useAiJobApplicationSummary.ts` — local `GenerateParams` (non-exported); `useBulkGenerateAiSummaries.ts` uses separate `BulkGenerateParams`. ✓

All referenced paths, classes, methods, columns, and line anchors resolve to the cited code. The green rspec run confirms `job.organization_users.actives`, `organization_user.user.{first_name,last_name,email}`, and `job_application.ai_summary_rescore_requested` runtime validity.

## Findings
No issues found.
