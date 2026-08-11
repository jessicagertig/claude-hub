# item1-runplato-defect-fixes — Pass 1

Scope: Task A2 (`RunPlatoReviewAllModal.tsx`, SPEC 1.5).

## Fact Check

| Claim (plan) | Verify | Result |
|---|---|---|
| `Styled.Body` contents at lines 117-133 (A2.2) | Read RunPlato | TRUE |
| current credit copy at lines 120-132 lifted verbatim into `creditSentence` (A2.1) | lines 120-132 | TRUE — matches char-for-char incl. `shortfall > 0 && candidatesToScoreCount > 0` |
| Statement span at lines 147-150 (A2.3) | lines 147-150 | TRUE — current 2nd sentence "Candidates without a resume, or one that's still processing, are skipped." |
| `candidatesToScoreCount` / `shortfall` already defined lines 40-41 | lines 40-41 | TRUE |
| checked-state has NO leading "The" | SPEC 1.5 / approved-decisions flag A | owner-ruled divergence — correct, not a defect |

## Completeness (SPEC 1.5)

- Checked-state first sentence → "{candidatesCount} candidate(s) in this job will be reviewed, including candidates that already have a review." + unchanged `creditSentence`. A2.2 checked branch matches (uses `{candidatesCount}`, which equals `candidatesToScoreCount` when checked; SPEC pins `{candidatesCount}`). COVERED.
- Zero-state (unchecked, `candidatesToScoreCount === 0`) → "0 candidates in this job don't have a Plato review yet. Unless you select re-review below, no candidates will be reviewed." numeric 0, no credit sentence. A2.2 zero branch matches; precedence `rescore ? checked : (count===0 ? zero : else)` yields zero only when `!rescore && count===0`. COVERED.
- Else branch keeps today's wording ("… don't have a Plato review yet." + creditSentence). COVERED.
- Statement 2nd sentence → "Candidates without a resume, one that's still processing, or those already part of another bulk operation are skipped." First sentence "The hiring team gets an email with the final count when it's done." kept — made TRUE by B1 mailer change (cross-checked with item1-mailer-recipients: B1 lands). COVERED.
- A2.4 nothing else changes (checkbox/hooks/trackEvent/buttons/styled). Verified plan touches only Body + Statement span + adds `creditSentence` const. COVERED.

## Findings
- No issues found.

## Amendments Applied
- None.
