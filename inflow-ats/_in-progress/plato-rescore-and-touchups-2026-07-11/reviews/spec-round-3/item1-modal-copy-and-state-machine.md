# item1-modal-copy-and-state-machine — Round 3

Re-reviewed SPEC 1.1-1.4. Fresh checks: emotion labels (`_RescoreCheckbox`/`_Info`/`_Statement`) follow the file's `ComponentName_StyledName` convention with no collision; per-stage uses `processableCount` (not the all-stages `summaryCount`) so `candidatesToScoreCount = rescore ? candidatesCount : processableCount` is correct; `processableCount ≤ candidatesCount` so "{processableCount} of the {candidatesCount}" reads correctly; info-block ordering ("directly beneath the body copy") is unambiguous.

## Findings
- No new findings. (Round 1 F1 LOW still open.)

## Amendments Applied
- None.
