# Layer 1 Diff-to-Spec — Shared context (read first)

You are a Layer 1 diff-to-spec reviewer in the Phase 8 QA lifecycle for the inflow-ats "Plato re-score" feature.

## The ONE diff you review
`reviews/feature-diff-run3.patch` in the working dir below — this is `git diff f8815555a..HEAD`: feature commit f9ec4a80d PLUS QA fix commits 970b0f4b2 (qa-run-1 l1-7-001) and cca9222a5 (qa-run-2 l1-3-001) and the ONLY thing under QA. The branch's `git diff develop...HEAD` ALSO contains an unrelated prior commit (`f8815555a`, "Job criteria in Plato AI settings") touching JobCriteriaSection.tsx, extract_job_criteria_job.rb, ai_job_criteria_controller.rb, job.rb, etc. Those files are NOT this feature. If you see references to job-criteria / ExtractJobCriteria / AiJobCriteria, that is the OTHER feature — do not review it, do not flag it. Review ONLY the 11 files in feature-diff-run3.patch:
- app/controllers/api/v1/ai_job_application_summaries_controller.rb
- app/interactors/create_ai_summary_generation.rb
- app/javascript/ats/src/views/jobApplications/AiSummaryState.tsx (DELETED)
- app/javascript/ats/src/views/jobApplications/BulkGenerateAiSummariesConfirmModal.tsx
- app/javascript/ats/src/views/jobApplications/PlatoTab.tsx
- app/javascript/ats/src/views/jobApplications/RunPlatoReviewAllModal.tsx
- app/javascript/shared/queryHooks/useAiJobApplicationSummary.ts
- app/mailers/bulk_all_stages_ai_summary_result_mailer.rb
- spec/controllers/api/v1/ai_job_application_summaries_controller_spec.rb (NEW)
- spec/interactors/create_ai_summary_generation_spec.rb (NEW)
- spec/mailers/bulk_all_stages_ai_summary_result_mailer_spec.rb (extended)

Plus the polymer-mail template diff `reviews/polymer-mail-diff.patch` (SPEC 1.6 — the two all-stages .mjml greeting deletions).

## Files
- Working dir: /Users/jessica/claude-hub/inflow-ats/_in-progress/plato-rescore-and-touchups-2026-07-11/
- SPEC: <working dir>/SPEC.md  (source of truth for requirements)
- Owner rulings: <working dir>/approved-decisions.md
- Feature diff: <working dir>/reviews/feature-diff-run3.patch
- Polymer-mail diff: <working dir>/reviews/polymer-mail-diff.patch
- Worktree (read CURRENT source here if needed): /Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings
- Pinned analog sources live in the worktree (RunPlatoReviewAllModal.tsx, CustomQuestionModal/index.js, create_bulk_ai_summary_generation.rb, bulk_ai_job_application_summaries_controller.rb, job_application_mailer.rb, organization_user.rb)

## Layer 1 severity rule
Every finding is HIGH. The diff either matches the spec or it doesn't. No "close enough", no "functionally equivalent", no "minor deviation". If SPEC says X and code does Y, that is a finding — even if Y works.
Two directions to check: (1) every spec requirement assigned to you has corresponding code in the diff; (2) every change in the diff within your area traces back to a spec requirement — report EXTRA/unspecced changes with full scope (every new method/line, not one symptom).

## BINDING SCOPE GUARDRAILS (a reviewer who violates these produces a FALSE finding)
1. **Item 2 interactors are NOT a whole-file analog.** `CreateBulkAiSummaryGeneration` supplies exactly ONE copied behavior to `CreateAiSummaryGeneration`: the gate condition `&& !job_application.ai_summary_rescore_requested`. Do NOT diff the two interactors wholesale. Do NOT flag the bulk interactor's staleness-refresh block, its missing textract_pending branch, or its enqueue behavior as things the single-send interactor should adopt. Single-send keeps all its own existing behavior; only the one gate condition changes.
2. **Item 1 analog patterns are pinned verbatim in SPEC.md.** Verify the implementation against the SPEC's pinned strings/styles/file:line refs — NOT against your own independent reading of RunPlatoReviewAllModal.tsx. Where SPEC deliberately diverges per-stage copy from all-stages (leading "The" on the checked sentence — SPEC 1.2 state 4 vs 1.5), that divergence is OWNER-RULED, not a defect.
3. **No frontend tests.** Owner ruled frontend coverage is not wanted. Do NOT raise a finding demanding React/Cypress tests. Backend specs only.
4. **Explicitly-untouched items are out of scope (SPEC 1.8):** the per-stage no-selection branch copy, BulkJobApplicationAiSummaryResultMailer recipients, the "job" query-invalidation difference between the two bulk hooks, posthog trackEvent names/payloads, and the entire backend enqueue path. Do not flag these as gaps.
Priority rule: where a pinned analog or owner decision conflicts with a general convention, the pin/decision wins — note it, do not flag it.
Owner-sanctioned divergences (do NOT flag): per-stage checked sentence leading "The"; mailer omits the receives_new_job_application_emails preference scope; per-stage modal adds an overestimate info block the all-stages analog lacks; single-send interactor does not gain the bulk staleness block / textract_pending / enqueue.

## Output
Write your findings JSON to: <working dir>/reviews/qa-run-3/layer-1-diff-to-spec/round-1/agent-{N}.json
Format:
{"layer":"diff-to-spec","round":1,"agent_index":N,"focus":"<your area>","findings":[{"id":"l1-<N>-001","severity":"HIGH","title":"...","spec_requirement":"...","file":"...","evidence":"...","recommendation":"..."}],"spec_coverage":{"assigned_requirements":[...],"implemented":[...],"missing":[...]}}
If you find nothing, write findings: [] and list every assigned requirement under implemented. Return a short summary as your final message: findings count by area + coverage.

## RUN 2 ADDENDUM — fix history you must verify
qa-run-1 round-1 found l1-7-001 (HIGH): in spec/controllers/api/v1/ai_job_application_summaries_controller_spec.rb, the "rejects a request without rescore_requested" test posted `ai_job_application_summary: {}` — the OUTER `params.require(:ai_job_application_summary)` raised first, so the test could not fail if the inner `.require(:rescore_requested)` were removed (tautological, core rule 26). Fix commit 970b0f4b2 changed the posted payload to a non-empty hash missing only `rescore_requested`. Verify: (1) the fix is present and correct in the committed diff; (2) the fix is MINIMAL — exactly that one test's payload changed, nothing else in the fix commit; (3) the test is now genuinely falsifiable (outer require passes, only inner raises). Read qa-run-1/FAILURE-REPORT.md for full detail if needed.

## RUN 3 ADDENDUM — second fix to verify
qa-run-2 round-1 found l1-3-001 (HIGH): the interactor spec's false-path example omitted the bulk analog's count-invariance assertion (SPEC 2.8 pins "the same assertion pairs" as create_bulk_ai_summary_generation_spec.rb:96-112). Fix commit cca9222a5 wraps the false-path example's existing nested expect in an outer `expect { ... }.not_to change { job_application.ai_job_application_summaries.count }` (nested form because RSpec rejects `.not_to matcher.and matcher` with NegationUnsupportedError). Verify: fix present, minimal (git show cca9222a5 — one spec file, +5/-3, only that example), assertions preserved (nothing removed/reworded), and the resulting example genuinely matches the analog's assertion pair. Both prior fixes (970b0f4b2, cca9222a5) are in scope for your diff-to-spec trace.
