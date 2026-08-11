# item1-runplato-defect-fixes — Round 1

Trace: SPEC 1.5 → RunPlatoReviewAllModal.tsx:117-151 (Body, checkbox, Statement)

## Source-accuracy checks (confirmed)
- Current Body first sentence (:117-119): "{candidatesToScoreCount} candidate(s) in this job {doesn't/don't} have a Plato review yet." — the defect target. CONFIRMED.
- Current Statement (:147-150): "The hiring team gets an email with the final count when it's done. Candidates without a resume, or one that's still processing, are skipped." — the two sentences SPEC 1.5 edits. CONFIRMED.
- Button disable `isLoading || candidatesToScoreCount === 0` (:98) — the existing zero-state gate SPEC 1.5 relies on. CONFIRMED.

## Findings
- F1 [LOW] Variable-name mismatch between SPEC 1.5 and approved-decisions "flag A". SPEC 1.5 pins the checked-state first sentence as "{candidatesCount} candidate(s) in this job will be reviewed, including candidates that already have a review." approved-decisions flag A wrote the same sentence with "{candidatesToScoreCount}". When `rescore` is checked, `candidatesToScoreCount === candidatesCount` (RunPlatoReviewAllModal.tsx:40), so the RENDERED number is identical — no behavioral difference. NOT amended (numerically equal; amending risks touching owner-approved copy). Surfaced for Jessica's awareness only.

## Cross-angle note
- The Statement first sentence "The hiring team gets an email with the final count when it's done." is only TRUE after the 1.6 mailer change (whole hiring team, not just the trigger). Verified in item1-mailer-recipients that 1.6 lands the change. Consistent.

## Amendments Applied
- None (F1 is LOW, not amended).

## Rejected as false positives (guardrails)
- "NO leading The" on the all-stages checked sentence — owner-ruled deliberate divergence from per-stage (guardrail 2 / SPEC 1.5). Not a defect.
