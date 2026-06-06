# Backward Compatibility (always-on check) — Impl Round 1

## Findings

- Change 1: adds 2 lines inside existing `if` block. No signature or return changes. No existing callers affected.
- Change 2: changes `retry_on` from no-block to with-block. Behavior change is from "silently discard" to "cleanup and notify". This is strictly additive — no caller sees different behavior.
- Change 3: adds early return guard before existing guard. No external caller changes (private callback).
- `belongs_to :textract_result, optional: true` was a pre-existing change (prerequisite). No new impact from this PR.

No issues found.
