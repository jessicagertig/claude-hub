# Spec Review Complete

**Final verdict: READY FOR PLANNING**

## Plain English Summary

This feature lets a hiring manager score every candidate in a job in one click, instead of going stage by stage. A "Run Plato" card sits at the bottom of the sidebar on the job's candidate view. Clicking it opens a confirmation dialog — or, if the job has no description or no candidates yet, an explanatory dialog. Once confirmed, the system queues every candidate for AI scoring (or rescoring if the user opts in), sends an email when it finishes, and shows a toast notification. The backend reuses the existing bulk-scoring pipeline with a `kind` flag to distinguish stage-level from job-level runs.

## Blast Radius Analysis

- **`QueueBulkAiSummaryJobs`** — adds two optional context params. Existing callers pass neither, so existing behavior unchanged. If wrong: single-stage scoring could silently skip the `:current` filter.
- **`BulkGenerateAiSummariesJob`** — adds branching in `notify_complete`/`notify_failure` on a new payload key. Existing payloads have no `kind` key. If wrong: email goes to wrong mailer.
- **`Api::V1::JobSerializer`** — two new attributes. Additive. If wrong: frontend gets wrong count or auto-gen flag.
- **`config/routes.rb`** — one collection route added. If wrong: 404 on the new endpoint.
- **Frontend modals** — all new components. If wrong: modal fails to open or double-clicks queue duplicates.
- **`JobStagesContainer`** — renders a new component in the sidebar. If wrong: sidebar layout breaks.

## Round Summary

| Round | Verdict | BLOCKER | HIGH | MED | LOW | Amendments |
|---|---|---|---|---|---|---|
| 1 | FAIL | 0 | 1 | 5 | 1 | 9 |
| 2 | PASS | 0 | 0 | 0 | 0 | 0 |
| 3 | PASS | 0 | 0 | 0 | 0 | 0 |

**Two consecutive clean passes achieved.** The spec is ready for the planning phase.

## Key Amendments from Round 1

1. Specified association path `@job.job_applications.pluck(:id)` for resolving all-stages candidates
2. Replaced code literal with descriptive text for `kind` default
3. Added `FormContainer` with errors for credit validation in `RunPlatoReviewAllModal`
4. Added toast message pattern details
5. Added `disabled` prop alongside `loading` per known failure pattern #11
6. Corrected `notify_failure` line range
7. Specified CTA placement "after second `Styled.List`" and noted `Styled.Sidebar` needs flex column
8. Added explicit `.deliver_later` requirement per known failure pattern #4
9. Added full test requirements section per known failure pattern #3

## Open Questions for Jessica

None.
