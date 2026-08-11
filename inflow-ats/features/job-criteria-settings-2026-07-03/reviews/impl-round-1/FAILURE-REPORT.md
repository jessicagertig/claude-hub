# Implementation Review — Failure Report

**Round:** 1
**Date:** 2026-07-03

## Issues Requiring Fix

1. **[HIGH] app/javascript/ats/src/views/jobApplications/jobSetup/components/JobCriteriaSection.tsx:148-157** — The Generate/Regenerate section button passes `loading={isInFlight}` (line 151) but not `disabled={isInFlight}`, so it remains clickable while an extraction is in flight.
   - SPEC §4.1 states the mitigation for the deliberately absent pending guard verbatim: "The frontend disables the button once the payload shows an in-flight status; residual double-enqueue is wasteful but harmless."
   - The shared Button component does not block clicks on `loading` — only `disabled` prevents `onClick` (`app/javascript/ats/src/components/shared/Button/index.js:33-37`).
   - Consequence: while the latest row is `pending` (the one in-flight status `extract_job_criteria_immediately` does NOT guard), a user can click the spinner button, confirm the modal, and create a second pending row plus a second paid extraction job.
   - This is the recurrence of pipeline rule 11's motivating failure; the generate-button analog passes both props (`PlatoTab.tsx:239`: `loading={buttonLoading} disabled={buttonLoading}`).
   - **What to change (minimum change, one line):** add `disabled={isInFlight}` to that `Button` in `Styled.ActionRow`. Nothing else.
   - Commit the fix (pre-commit tests must pass; commit outside the sandbox per pipeline rules).

## What NOT To Change

- **Do NOT add a pending guard** to `extract_job_criteria_immediately` — the absence is DECISIONS-verbatim and test-documented ("creates a row anyway, documenting the deliberate absence of a pending guard").
- **Do NOT touch the modal's buttons** — `RegenerateJobCriteriaConfirmModal`'s primary already has both `loading` and `disabled`; its `type="button"`/missing `size="medium"` deviations are LOW and not in scope for this fix.
- **Do NOT change the View criteria button or its rendering conditions** — rendering during in-flight-over-older-success was ADJUDICATED CORRECT (SPEC 8.2 row 4 includes that state by definition).
- **Do NOT change `isInFlight`'s derivation** (`isPayloadStatusInFlight || isFetching`) — D-5 is deliberate; background-refetch loading flicker is an accepted cost (plan R-3).
- **Do NOT remove `ai_job_criteria.reload`** in `ExtractJobCriteriaJob#broadcast_completion` — SPEC §7-verbatim; the Phase 6.5 conventions pass owns that call (plan R-1).
- **Do NOT touch** the 9 failing `on_complete` examples in `bulk_generate_ai_summaries_job_spec.rb` — pre-existing breakage at base, out of this feature's scope.
- **Do NOT act on the LOW findings** (TIERS duplication, `<a>` href, trailing newline, analog button attributes, exhaustion-broadcast test) without a gate ruling — fix agents fix the listed defect only (pipeline rules 10/23).
- **Do NOT re-litigate flags 1-7** (positional job args, third zero-criteria message, failure broadcasts, claim-row fix, optional `job` input, display precedence, kwarg).

## cursor_rules/ Violations

- None at MED+ severity. The single deliberately-deferred item: `ai_job_criteria.reload` (extract_job_criteria_job.rb:45) vs `cursor_rules/backend/_base.md` §8 — SPEC-verbatim, gate-bound to the dedicated conventions pass; not counted this round per the round directive.
- (F1 above violates pipeline rule 11 from `~/claude-hub/inflow-ats/CLAUDE.md` — copy ALL behavioral props from the analog — and SPEC §4.1; it is not a cursor_rules file violation.)
