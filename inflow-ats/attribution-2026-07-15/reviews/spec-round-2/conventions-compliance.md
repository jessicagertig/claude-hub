# conventions-compliance — Round 2

This round's conventions file: `cursor_rules/frontend/react_hooks.md` (read in full).

## react_hooks.md vs the spec

- Multiple-separate-useState preference vs the capture state: §5.2 leaves single-object vs per-field to the plan; the file itself allows combining "truly related" fields, and the four tracking values are one concern captured once with no setter — either shape complies. No spec change needed.
- "State synced with props always uses useEffect with proper guards": n/a — the capture state is deliberately never re-synced (values never re-captured), matching the `referral` analog's no-sync shape (its invite-driven `setReferral` is a distinct existing flow the spec does not touch).
- The §5.6 two-effect mechanism: deps array `[emailConfirmed]` is correct and guarded (bare return unless true) — consistent with the file's guard guidance and core rule 8's bare-return style.
- Setter naming/boolean naming: no new state names are mandated by the spec beyond analog shapes; `emailConfirmed` already exists.
- "Don't initialize state from props that may be undefined on mount": the capture initializes from `location.search`, which is synchronously available — n/a.

## Findings

- None.

## Amendments Applied

- None.
