# Always-On Checks -- Round 2

## Source Accuracy

All file paths, class names, method names, columns, and line numbers verified in Round 1 remain correct. No new source claims introduced by Round 1 amendments.

Round 2 amendments:
- P5 corrected guard method reference: verified that `status_changed?` is the correct method for `before_update` callbacks.
- Files to Create or Modify section corrected: lines 71-72 now say "all `update_columns` calls", matching the A.3 decision.
- E.1.5 corrected: now correctly states `before_update` only fires on update.

## Backward Compatibility

No changes from Round 1. All consumers verified.

## Analog Completeness

No changes from Round 1. All layers covered.

## Analog Structural Matching

No changes from Round 1. Guard pattern now correctly documented in P5 (uses `status_changed?` for `before_update`, vs `saved_change_to_status?` for `after_commit`).

## Findings

No additional issues found.
