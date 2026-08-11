# pipeline-status-lifecycle — Round 2

## Findings

- F1 [MED] Ambiguity in `summarizing` status semantics. The enum defines `summarizing: 4` as "summary pipeline Calls 2-4" (an in-progress state). The amendment says `Summary::Generate`'s "final successful status should be `summarizing` or equivalent." If `summarizing` is set AFTER Calls 2-4 complete, it functions as a completion marker -- but its name and description imply "in progress." The resume point for `summarizing` says "re-run Summary::Generate (Calls 2-4 are idempotent)" -- this treats `summarizing` as in-progress. The orchestrator uses `summarizing` to mean "summary phase done, advance to scoring." Both readings coexist but create ambiguity for the implementing agent. **Fix:** Clarify in the enum description and the amendment: `Summary::Generate` sets `summarizing` BEFORE running Calls 2-4 (making it an in-progress state); when all 4 calls complete, `Summary::Generate` leaves the status at `summarizing`; the orchestrator interprets `summarizing` with populated summary fields as "summary complete, advance to scoring."

- F2 [LOW] The resume point for `extracting` says "re-run Summary::Generate from the beginning." This means if Call 1 partially completed (e.g., `structured_data` was partially written), it gets overwritten on retry. This is fine since the spec states "Call 1 is idempotent -- it overwrites structured_data." No issue.

No other new findings. Round 1 amendments resolved the HIGH findings cleanly.
