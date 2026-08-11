# Conventions Pass — Failure Report (fix batch 1)

**Date:** 2026-07-03
**Source:** 25-reviewer fan-out (one per cursor_rules file), reviews/conventions-pass/
**Totals:** 0 BLOCKER / 0 HIGH / 10 MED / ~20 LOW
**Orchestrator adjudication:** 8 MED to fix (below), 2 MED ruled no-fix (see "Ruled, do not touch"), LOWs non-blocking (reported at completion).

## Issues Requiring Fix

1. [MED] `app/jobs/extract_job_criteria_job.rb:46` — replace `ai_job_criteria.reload` in `broadcast_completion` with a fresh read per backend/_base.md §8 (plan R-1 pre-agreed this pass owns the ruling). Compliant pattern: re-fetch the record (`ai_job_criteria = AiJobCriteria.find_by(id: ai_job_criteria.id)` then `return unless ai_job_criteria`) before the terminal-status guard. Keep behavior identical: fresh status/error_message read before deciding to broadcast. Also update the broadcast test if it stubs/depends on reload (behavioral assertions must still pass).
2. [MED] `app/jobs/bulk_generate_ai_summaries_job.rb:62-65` — the validation-failure branch must log before returning, matching the sibling pattern at :95: `Rails.logger.error "BulkGenerateAiSummariesJob validation failed for job_application #{job_application_id}: #{result.error}"`.
3. [MED] `app/javascript/ats/src/views/jobApplications/jobSetup/JobSetupAiSettings.tsx:74-105` — replace the three hand-written sidebar tier blocks with data-driven rendering (map over a tier-metadata array). Do it by creating ONE shared tier-metadata constant (icon, key, label, glossary lead + rest text) in a sensible shared location next to these components, consumed by BOTH `JobSetupAiSettings.tsx` (sidebar) and `JobCriteriaSection.tsx` (replacing its local `TIERS`) — this also resolves the round-1 LOW about `TIERS` duplication (JobCriteriaViewModal.tsx may consume it too if it has its own copy). Copy strings stay EXACTLY as they are today (copy rules binding; no wording changes).
4. [MED] `app/javascript/ats/src/views/jobApplications/jobSetup/components/JobCriteriaSection.tsx:31-33, 62-74` — handle the query error state: destructure `isError` from `useAiJobCriteria`; when `isError`, render the existing failure-style `EmptyState` presentation with copy: title `"Could not load job criteria"`, message `"Something went wrong while loading job criteria. Refresh the page to try again."` (sentence case, no em dashes), NO action-row buttons for this state (a Generate button against unknown server state is the exact bug being fixed). Priority: after `isLoading`, before the payload-driven states.
5. [MED] `JobCriteriaViewModal.tsx:99` `border-radius: 5px` → `${t.rounded.sm};`; `JobCriteriaViewModal.tsx:140` + `JobCriteriaSection.tsx:200` `border-radius: 7px` → `${t.rounded.md};` (standalone utilities).
6. [MED] Raw font-sizes → standalone typeScale utilities (pipeline rule 1 — NEVER inside a `font-size:` property): `JobCriteriaViewModal.tsx:127` + `JobCriteriaSection.tsx:175` → `${t.text.sm};`; `JobCriteriaViewModal.tsx:163,168` → `${t.text.xs};`; `JobSetupAiSettings.tsx:149` → `${t.text.base};`; `JobSetupAiSettings.tsx:177` → `${t.text.sm};`. Where the surrounding block also sets line-height/weight, verify the utility's included declarations don't conflict (utilities are complete declarations).
7. [MED] `JobCriteriaSection.tsx:267` `font-weight: 450` → `${t.text.medium};`.
8. [MED] Focus states (ui_styling rule 6): `JobCriteriaViewModal.tsx` CloseButton and `JobCriteriaSection.tsx` SectionIntro `a` — add `&:focus` ring per the rule's example: `&:focus { outline: none; box-shadow: 0 0 0 2px ${t.dark ? t.color.gray[500] : t.color.gray[300]}; }`.

After fixes: run affected specs (`spec/jobs/extract_job_criteria_job_spec.rb`, `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` — the 9 pre-existing on_complete failures stay, everything else green), `tsc --noEmit`, `eslint` on changed frontend files. Commit per the commit rules (detached/background, ≥20min tolerance, never --no-verify).

## Ruled, DO NOT touch (orchestrator adjudications)

- `ai_job_criteria_controller.rb#create` rendering the current payload without an interactor/result branch: SPEC 5.2-adjudicated idempotent design (blank-description 422 precedes; in-flight no-op returns current payload by design; `new_ai_job_criteria.save` has no realistic failure mode — status has a default and no other validations). Do not add an interactor or rescue.
- `RegenerateJobCriteriaConfirmModal` owning its mutation: adjudicated rule-22 pattern from the `BulkGenerateAiSummariesConfirmModal` domain analog (frozen-props hazard makes parent-owned mutations the known ai-billing-overhaul H1 failure). Do not convert to `ConfirmationModal`/parent-owned.
- Everything in IMPL-REVIEW-COMPLETE.md's closed findings; the optional-positional job signature (flag 4); enum-value snake_case on the frontend.

## SPEC amendment rider (apply as part of this batch)

- SPEC.md §7: change the `broadcast_completion` sketch's `ai_job_criteria.reload` line to the fresh-read form (fix 1) with a one-line note "(amended post-conventions-pass per backend/_base.md §8; plan R-1)". Search SPEC.md for any other `reload` references in that section and update them too (stale-reference rule).
