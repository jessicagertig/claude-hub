# QA Run 1 — Layer 1 (Diff-to-Spec) — Round 1 Summary

**Diff reviewed:** commit `f9ec4a80d` (`git show`), 11 files, +333/-315, plus polymer-mail template diff (2 `.mjml` greeting deletions).
**Agents:** 10, all completed. **Findings: 1 HIGH.**

## Coverage

Every SPEC requirement (1.1-1.8, 2.1-2.8) was traced to committed code by at least two independent agents. Agent 10 walked every hunk of the diff and traced each to a SPEC requirement — no unspecced changes, no missing implementations, exactly 11 files. All SPEC-cited file:line references verified in the worktree (two blocks moved lines because this diff added lines above them — code identical).

Cleared during review (not findings):
- RunPlatoReviewAllModal creditSentence const extraction — byte-identical copy content, minimal mechanism for the SPEC 1.5 three-branch restructure.
- Mailer .includes(:user) — part of the pinned recipient-analog chain, correctly retained.
- Controller spec located at spec/controllers/api/v1/ (not spec/requests/) — matches the bulk analog and codebase convention; SPEC 2.8 pins no directory. (The orchestrator's shared-context file list mislabeled it.)
- Owner-sanctioned divergences (per-stage leading "The", mailer preference-scope omission, overestimate info block, single-send interactor keeping its own behavior) — all confirmed sanctioned, none flagged.

## Finding

### l1-7-001 (HIGH) — Controller spec rejection test not falsifiable (core rule 26)
spec/controllers/api/v1/ai_job_application_summaries_controller_spec.rb, Test 1 ("rejects a request without rescore_requested"): posts ai_job_application_summary: {}. The empty hash makes the OUTER params.require(:ai_job_application_summary) raise before the inner .require(:rescore_requested) is ever evaluated. Deleting the inner require (the exact code the test guards) leaves the test green — tautological, zero coverage of the SPEC 2.2 boundary requirement.

**Fix:** post a non-empty ai_job_application_summary payload missing only rescore_requested, so only the inner .require(:rescore_requested) can raise.

## Gate decision

1 HIGH -> fix loop. FAILURE-REPORT.md written; fix agent dispatched; restart from Layer 1 in qa-run-2/ after the fix is committed.
