# item1-runplato-defect-fixes — Round 2

Independent re-verification of `RunPlatoReviewAllModal.tsx` against SPEC 1.5.

- `creditSentence` extracted above `return`, lifted verbatim from the prior credit copy (`shortfall > 0 && candidatesToScoreCount > 0` variant / normal variant) — SPEC says credit sentence unchanged. ✓
- Checked branch: "{candidatesCount} candidate{candidatesCount === 1 ? "" : "s"} in this job will be reviewed, including candidates that already have a review. {creditSentence}" — NO leading "The" (owner-ruled divergence from per-stage). `candidatesCount` is a defined prop (line 20/27). ✓
- Zero branch (`!rescore && candidatesToScoreCount === 0`): "0 candidates in this job don't have a Plato review yet. Unless you select re-review below, no candidates will be reviewed." Numeric `0`, no credit sentence; button stays disabled via existing `candidatesToScoreCount === 0` in `modalButtons` (unchanged). ✓
- Else branch: today's exact wording ("{candidatesToScoreCount} candidate(s) in this job {doesn't/don't} have a Plato review yet. {creditSentence}"). ✓
- Statement second sentence: "Candidates without a resume, one that's still processing, or those already part of another bulk operation are skipped." First sentence "The hiring team gets an email with the final count when it's done." kept verbatim — made TRUE by the 1.6 mailer change (cross-verified in item1-mailer-recipients). ✓
- Nothing else changed: checkbox, hooks, trackEvent, button props, styled components all intact (diff confined to the credit-sentence extraction, three-way body node, and Statement second sentence). ✓

## Findings
No issues found.
