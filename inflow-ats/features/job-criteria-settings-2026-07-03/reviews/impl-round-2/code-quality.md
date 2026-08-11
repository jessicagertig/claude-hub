# Code Quality (always-on) — Round 2

Delta since round 1: one fix line + merge resolution. Both reviewed; round-1 positives stand (files otherwise byte-identical).

- Fix line `disabled={isInFlight}` — consistent with the adjacent prop style and the analog.
- Merge resolution in the bulk controller reads cleanly (`job: @job,` above `params:`; consistent ordering in both actions).
- Merge-authored spec code follows each file's local conventions; the `textract_result_ai_trigger_spec.rb` comment is accurate and appropriately placed on the `before` block it explains.

## Findings (LOW carryovers from round 1 — still open, not re-opened as new; listed for tracking)

- F1 [LOW — NOTED, NOT COUNTED per round directive] extract_job_criteria_job.rb:46 `ai_job_criteria.reload` vs backend/_base.md §8 — SPEC-verbatim; owned by the Phase 6.5 conventions pass (plan R-1).
- F2 [LOW — carryover] `TIERS` constant still duplicated in `JobCriteriaViewModal.tsx` and `components/JobCriteriaSection.tsx`.
- F3 [LOW — carryover] `JobCriteriaSection.tsx:43` description link is `<a onClick>` without `href` (a11y nit; behavior correct).
- F4 [LOW — carryover] `aiSummaryWebsocketPayloads.ts` still ends without a trailing newline.
- F5 [LOW — carryover] `RegenerateJobCriteriaConfirmModal.tsx` primary-button attribute deviations vs the analog (`type="button"`, no `size="medium"`, no `className="submit-button"`) — cosmetic, both behavioral props present.

No MED+ findings. No new LOW findings this round.
