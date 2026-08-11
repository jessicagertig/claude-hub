# item1-runplato-defect-fixes — Pass 2

## Pass 1 corrections for this angle
- None.

## Fresh sweep
- `creditSentence` (A2.1) is the current lines 120-132 verbatim, including `shortfall > 0 && candidatesToScoreCount > 0` — SPEC 1.5 says the credit sentence is unchanged; kept. (Per-stage A1.6 uses `shortfall > 0` alone, which is equivalent given states 3/4 guarantee count > 0 — the two modals differ only where each is separately pin-faithful.)
- A2.2 three-way precedence: `rescore ? checked : (candidatesToScoreCount===0 ? zero : else)`. Zero renders only when `!rescore && count===0`; button already disabled via existing `candidatesToScoreCount === 0` in `modalButtons` (unchanged). Correct.
- A2.3 keeps first Statement sentence, replaces second — first sentence becomes true only after B1 lands; A2 and B1 pinned to the same merge (ordering constraint). Cross-angle consistent with item1-mailer-recipients (B1 lands).
- A2.4 confirms no other change; plan edits are limited to Body contents, the Statement span, and the added `creditSentence` const.

## Findings
- No issues found.

## Amendments Applied
- None.
