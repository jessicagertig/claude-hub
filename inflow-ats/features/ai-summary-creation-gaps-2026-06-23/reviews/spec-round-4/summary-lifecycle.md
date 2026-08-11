# summary-lifecycle / state-machine — Round 4

Fresh-eyes re-trace of the full lifecycle (W1 create -> bridge -> succeeded/failed -> status row -> FE) against the amended spec.

## Findings
No issues found.

## Verified this round
- record_failure ordering (summary update_columns -> row .update) is safe: the row write reads the summary id (immutable) and clears denormalized columns; it does not depend on the summary's status field value. CONFIRMED.
- The bridge if-branch-else destroy (`textract_result.rb:134`) remains correctly OUT of the W5 record_failure scope (Textract-success-but-Validate-fails is a pre-generation rejection, not a terminal pipeline failure; candidate falls to noCredits/ready empty state). No D1 conflict (D1 is Textract-terminal-failure only). CONFIRMED.
- All terminal failed-summary writers route through record_failure; broadcast_status_change is before_update only (W1-created textract_processing summary signals via status row). CONFIRMED.
