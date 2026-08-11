# Spec Review: State Machine Correctness

**Reviewer angle:** State machine correctness -- 6 states in PlatoTab + 6 states in PlatoOverviewCallout

**Spec file:** `~/claude-hub/inflow-ats/2026-06-11-ai-display/SPEC.md`

## State universe

The full state space is:

| # | Summary exists? | status | hasResume | stale | Notes |
|---|---|---|---|---|---|
| S1 | No | n/a | true | n/a | Can generate |
| S2 | No | n/a | false | n/a | No resume |
| S3 | Yes | succeeded | any | false | Show results |
| S4 | Yes | succeeded | any | true | Stale results |
| S5 | Yes | pending | any | any | Generating |
| S6 | Yes | in_progress | any | any | Generating |
| S7 | Yes | extracted | any | any | Generating |
| S8 | Yes | textract_processing | any | any | Waiting on OCR |
| S9 | Yes | failed | any | any | Error |

"any" means the field's value does not affect which branch is taken (though it may affect content within the branch, e.g. stale banner inside succeeded).

---

## Check A: PlatoTab -- mutual exclusion and exhaustiveness

The spec's PlatoTab state machine (lines 55-62):

| Row | Condition | Maps to |
|---|---|---|
| 1 | `status === "succeeded"` | S3, S4 |
| 2 | `status` is `pending/in_progress/extracted` | S5, S6, S7 |
| 3 | `status === "textract_processing"` | S8 |
| 4 | `status === "failed"` | S9 |
| 5 | No summary AND hasResume truthy | S1 |
| 6 | No summary AND hasResume falsy | S2 |

**Mutual exclusion:** The first 4 rows require a summary to exist (they reference `status`). The last 2 rows require no summary. These two groups are inherently disjoint. Within each group:
- Rows 1-4: the status values are disjoint sets ({succeeded}, {pending, in_progress, extracted}, {textract_processing}, {failed}). No overlap.
- Rows 5-6: hasResume truthy vs falsy. Disjoint.

**Exhaustiveness:** All 9 states (S1-S9) are covered. The union of status values in rows 1-4 is {succeeded, pending, in_progress, extracted, textract_processing, failed} = all 6 enum values.

PASS -- no gaps, no overlaps.

## Check B: PlatoOverviewCallout -- 1:1 mapping to PlatoTab states

The spec's callout table (lines 101-108):

| Row | State | Maps to |
|---|---|---|
| 1 | No summary, has resume | S1 |
| 2 | Succeeded, not stale | S3 |
| 3 | Succeeded, stale | S4 |
| 4 | No resume | S2 |
| 5 | Failed | S9 |
| 6 | Generating (pending/in_progress/extracted/textract_processing) | S5, S6, S7, S8 |

Coverage: S1-S9 all present.

The callout splits succeeded into stale vs not-stale (2 rows) while grouping textract_processing with the generating statuses (1 row). The tab does the opposite: keeps succeeded as 1 row (stale handled internally) but splits textract_processing into its own row. The net count is 6 rows in both tables, covering the same 9 states.

PASS -- no gaps.

## Findings

- **F1 [LOW]** PlatoTab state table / condition ordering implies top-down priority but does not explicitly say so / The spec lists "status === succeeded" first, then the generating statuses, then textract_processing, then failed, then the no-summary cases. If an implementer reads this as a flat switch statement rather than an if/else-if chain, the ordering is irrelevant and everything is fine. But if they read it as "check in order, first match wins," the ordering matters for the no-summary cases: a naive implementer might access `status` on a null summary before reaching rows 5-6. The analog (`AiJobApplicationSummaryFeedItem`) only runs when a summary exists -- the no-summary case is handled at a higher level in `JobApplicationActivity.tsx` (lines 395-404), which renders `AiSummaryState` when no summary exists. The spec merges both levels into a single flat table. **This is fine for an experienced implementer** who will naturally guard on summary existence first, but an explicit note like "Check summary existence first; the status-based conditions only apply when a summary exists" would make the intent unambiguous. / Add a one-line note above the table clarifying the two-level check (summary existence, then status).

- **F2 [MED]** PlatoOverviewCallout state table / "Generate" CTA for no-summary+has-resume could be misread as triggering the mutation / The callout table (line 103) shows CTA = "Generate" for the no-summary+has-resume state. The spec's prose says "Clicking the entire card calls `onOpen()`" (line 110), meaning the card navigates to the Plato tab regardless of state. But the word "Generate" as a CTA label, combined with the spec's detailed generate mutation pattern docs (lines 83-85, 292-296), creates ambiguity: an implementer could reasonably interpret "Generate" as meaning the callout itself should fire the mutation on click, not just navigate. The PlatoTab's "Generate" button (PlatoEmpty) *does* trigger the mutation. The callout's "Generate" label should *not*. This distinction is stated once (line 110: "Clicking the entire card calls `onOpen()`") but contradicted by the CTA label name. / Add an explicit note to the callout table or below it: "All CTA labels are display-only text. The card always navigates to the Plato tab on click; it never triggers the generate mutation directly."

- **F3 [LOW]** PlatoOverviewCallout / callout groups textract_processing with pending/in_progress/extracted into one "Generating" row, but PlatoTab separates textract_processing into its own PlatoProcessing state with distinct copy / This is intentional and correct: the callout is a compact card where the nuance between "waiting for OCR" and "generating" does not matter -- both show "Plato is reading the resume..." The tab has room for the distinction. No fix needed, but noting it for the record to confirm it was a deliberate design choice, not an oversight.

- **F4 [LOW]** PlatoTab / succeeded state shown regardless of hasResume value / If a resume is deleted after a summary was generated (edge case S3/S4 where hasResume could be falsy), the spec shows the succeeded layout. This is consistent with the analog behavior: `AiJobApplicationSummaryFeedItem` renders based purely on status, never checking hasResume. The stale banner (`aiSummary.stale === true`) would likely fire in this scenario because the backend sets stale when the resume changes. The behavior is correct: showing a stale succeeded summary with a regenerate option is more useful than hiding it.

- **F5 [LOW]** PlatoTab / no explicit fallback for unexpected status values / The TypeScript type constrains status to the 6 enum values, so at the type level an unexpected value cannot occur. At runtime, a backend change could introduce a new status. The spec has no explicit fallback row (e.g., "else: show PlatoGenerating as a safe default"). The analog also has no explicit fallback -- it uses an if/else-if chain where the final `else` catches succeeded (and implicitly any unknown status). In the spec's table, unknown statuses would fall through all conditions and render nothing. In practice, the TypeScript constraint and the fact that status changes require backend + frontend coordination make this extremely unlikely. / No fix required, but if you want defense in depth, add a 7th row: "else (defensive fallback)" that renders PlatoGenerating, since a new in-flight status is more likely than a new terminal status.

- **F6 [MED]** PlatoOverviewCallout / "No resume" row (line 106) does not specify whether it checks summary existence / The callout table row 4 says "No resume" with no mention of whether a summary exists. This maps to S2 (no summary, no resume), but what about: summary exists with status=failed AND hasResume=false? Or summary exists with status=textract_processing AND hasResume=false? In the PlatoTab, these are handled by the status-based rows (failed, textract_processing) because status is checked before hasResume. In the callout, the "No resume" row could collide with the "Failed" row (line 107) or the "Generating" row (line 108) if the implementer checks hasResume before status. The spec does not state the priority order for the callout table. The PlatoTab table has a natural priority (status-based rows first, no-summary rows last), but the callout table is presented alphabetically by state, not by priority. / State explicitly that the callout uses the same evaluation order as the tab: check status-based conditions first (when a summary exists), then fall through to the no-summary conditions. Alternatively, rewrite the "No resume" row as "No summary AND no resume" to match the tab's row 6 exactly.

## Summary

| Severity | Count |
|---|---|
| BLOCKER | 0 |
| HIGH | 0 |
| MED | 2 |
| LOW | 4 |

The state machines are logically sound -- all 9 concrete states are covered in both tables with no gaps or overlaps. The two MED findings are about spec clarity that could cause implementer confusion (F2: "Generate" CTA label implying mutation; F6: ambiguous priority in callout table), not logical errors.
