# Spec Review — Round 1 Verdict
**Date:** 2026-06-05

## Plain English Summary

When someone tries to generate an AI summary for a job application that has a resume but whose resume has never been processed by Amazon Textract, the system currently gives a dead-end error. This fix makes three small changes so the system instead kicks off Textract processing, creates a placeholder summary saying "processing," and when Textract finishes, automatically generates the real summary. The three changes handle: (1) linking the placeholder summary to the Textract result once it exists, (2) cleaning up if Textract permanently fails after retries, and (3) preventing a crash when a summary has no Textract result linked.

## Blast Radius Analysis

- **What existing behavior changes:** Only the "no TextractResult" error path. All other AI summary paths are unaffected.
- **What existing code needs to be modified:** 3 files (service, job, model). Each change is 1-5 lines.
- **If this is wrong, what breaks:** Change 1 wrong = summary stays with nil textract_result_id, but Textract callback still finds it by status query (degraded but functional). Change 2 wrong = exhaustion cleanup doesn't fire, summary orphaned (pre-existing behavior). Change 3 wrong = NoMethodError crash on nil textract_result (narrow — only when summary reaches succeeded with nil FK, which Change 1 prevents).

## Counts
- BLOCKER: 0
- HIGH: 0
- MED: 3 (all outside the 3 spec changes — pre-existing design gaps)
- INFO: 6

## MED findings (outside spec scope, report only)
- async-timing F1: `SubmitResumeToTextract` AWS failure orphans the `textract_processing` summary
- cascade-and-cleanup F3: Resume re-upload could repurpose a stale `textract_processing` summary from a different user action
- notification-and-user-feedback F2: After exhaustion cleanup destroys the summary, page reload shows no indication anything was attempted

## Amendments Applied
None — all MED findings are outside the 3 spec changes per scope rules.

## Verdict: PASS
