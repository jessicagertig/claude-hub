# Spec Review — COMPLETE

**Feature:** AI Summary Creation Gaps + docx→Textract Trigger
**Repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats` (branch `ai-summary-creation-gaps`, HEAD `7831b7d16` — un-drifted across the entire review)
**Date:** 2026-06-23
**Rounds run:** 8 (terminated on two consecutive full passes: Round 7 + Round 8)

## FINAL VERDICT: READY FOR PLANNING

The spec survived two consecutive adversarial reviews (Rounds 7 + 8) across all 9 angles with zero MED+ findings and zero amendments. All 8 prior rounds' findings were resolved in-line. No BLOCKER, no escalation. Repo did not drift during the review.

---

## Plain English Summary (updated)

When a candidate applies, the system should automatically have its AI ("Plato") read the resume, score the candidate against the job, and show a summary card. Six holes in that flow are fixed: (1) auto-review now actually creates the review record up front (in a "reading the resume" state) so the pipeline has something to advance; (2) Word-document resumes now wait for the Word→PDF conversion before being sent for text-extraction (the extractor is PDF-only); (3) a failed review now shows a real "failed" state instead of freezing on "generating" or showing a stale score, and every failure path drives that state through one shared method that also clears the old score and corrects the job-list count; (4) two mid-pipeline states now broadcast progress to the screen and the progress stepper renders them; (5) the "criteria stuck forever" incident is fixed by moving the criteria-extraction job enqueue to AFTER the database commit (so the background worker can't run before the row it needs exists); (6) a lost completion notification is restored by carrying the original requester through the criteria-resume path.

Six surgical edits to an existing pipeline, each anchored to an existing in-codebase pattern. No new tables, no migration (one Rails enum gains a value on an existing integer column). Three pre-approved decisions: failed auto-reviews persist as `failed` (not deleted); auto-review success charges one credit (like manual); the auto behavior applies to all auto-generate entry points.

## Blast Radius (updated)

Unchanged in shape from the pre-review analysis (see `reviews/PLAIN-ENGLISH-SUMMARY.md` for the full per-workstream detail). The amendments did not expand scope; they hardened the existing six workstreams. Highest-risk slices remain W1 (credit path + C7/C8 cascade) and W3 (can cascade to all applicants on a job). Correctness-critical surfaces: the credit charge (W1 D2/W6) and the counter-cache (W5). The review tightened these with explicit test pins (exactly-one-credit / zero-on-failure) and complete failure-site routing.

Key amendments that changed the implementation surface (none changed user-facing scope):
- W1/C8 now routes the auto-failure write through the W5 `record_failure` choke-point (without it, the auto-failed summary would not render a failed state).
- W2 adds a `resume_is_docx` guard on the DocxToPdfJob Textract enqueue (without it, PDFs would double-submit to Textract).
- W3 uses `previous_changes` (string keys) / `saved_change_to_*` in after_commit, must fire irrespective of `skip_update_callback`, and rewrites the description-meaningful-change check (dirty tracking is reset post-commit).
- W4 extends the `PlatoGenerationStatus` TS union (not just the step map) and preserves `error_message` on the retrying conversion.
- W5 routes all 6 terminal-failure sites (incl. C8) through `record_failure`, passing each site's existing error_message verbatim.
- Test-ripples flagged: W6 breaks `ai_job_criteria_spec.rb:62`'s `.with` matcher; C8 breaks `get_resume_text_from_textract_job_spec.rb`'s destroy assertions; W4 breaks `ai_job_application_summary_spec.rb`'s broadcast `.each` move-off helper + requires deleting the `:57-62` block.

---

## Per-round summary

| Round | Verdict | BLOCKER | HIGH | MED | LOW | Notes |
|---|---|---|---|---|---|---|
| 1 | FAIL | 0 | 4 | 10 | 6 | C8/record_failure reconciliation (HIGH); PDF double-submit (HIGH); W3 description dirty-tracking + skip_update_callback (2 HIGH); + 10 MED across all angles. All amended. |
| 2 | FAIL | 0 | 1 | 0 | 0 | Caught a self-introduced defect: W3 used SYMBOL keys for `previous_changes` (string-keyed). Fixed. |
| 3 | FAIL | 0 | 0 | 0 | 1 | LOW consistency cleanup (residual symbol-notation label in W3 fallback). |
| 4 | PASS | 0 | 0 | 0 | 0 | First clean pass. D1/D2/D3 + deferred scope re-verified. |
| 5 | FAIL | 0 | 0 | 2 | 0 | Test-ripples: W6 breaks `ai_job_criteria_spec.rb:62` `.with`; C8 breaks `get_resume_text_from_textract_job_spec.rb` destroy assertions (file was missing from test plan). Amended. |
| 6 | FAIL | 0 | 0 | 1 | 0 | Test-ripple: W4 breaks `ai_job_application_summary_spec.rb` broadcast `.each` move-off (no non-broadcasting status left) + `:57-62` must be deleted not inverted. Exhaustive ripple sweep completed. |
| 7 | PASS | 0 | 0 | 0 | 0 | Clean. Final status-writer accounting confirms completeness. |
| 8 | PASS | 0 | 0 | 0 | 0 | Clean. FE compile surfaces re-verified; no repo drift. TWO CONSECUTIVE PASSES (R7+R8). |

Totals across the review: 4 HIGH, 13 MED, 7 LOW — all resolved. 0 BLOCKER.

---

## Open questions for Jessica

None block planning. Two FYI items (already decided in-spec, surfaced for awareness):

1. **Bridge if-branch-else destroy (textract_result.rb:134) vs D1.** When Textract SUCCEEDS but `ValidateAiSummaryGeneration` then fails (e.g. credits run out between intake and Textract completion), the auto summary is DESTROYED (existing manual behavior), not persisted as `failed`. This is a DIFFERENT path from C8 (Textract terminal failure) and is intentionally left as-is — the candidate correctly falls to the "noCredits"/"ready" empty state. If you'd prefer this edge to also persist-as-failed, it's a small follow-up (out of current scope).

2. **`CreateAiCreditBalanceTransaction` has no per-summary idempotency guard** (pre-existing; identical for the manual path). The auto path's single-charge is protected only by the `generate_ai_summary_with_credit_flow:68` early-return. The spec pins this at the integration-test level (exactly-one-credit). If you ever see double-charges, the durable fix is a per-summary uniqueness guard on the transaction — but that's pre-existing scope, not introduced here.

## Deferred items (confirmed out of scope, unchanged)
issue-6 sweeper/reaper + extract_criteria early-return-to-failed; issue-3 regenerating-column-clear + Solution 3 (S-D/T2 credit); DELTA-1 (latest_succeeded freshness); C3 (bulk backfill idempotency); C5 (defensive bridge-selector order); C6 (dead ai_bulk_extract.rake); the docx-race-exposed recovery actors (validate/queue_bulk).
