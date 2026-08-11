# code-quality — Round 2 (always-on impl angle)

- Naming: `sanitizeTrackingParams`/`sanitizeTrackingValue`/`TRACKING_VALUE_MAX_LENGTH`/`UTM_DATA_MAX_KEYS`/`keysInOccurrenceOrder`/`utmDataKeys` — descriptive, house-style; `trackingParams` state mirrors the analog register of `referral`/`partner`. Spec variables (`user`, `organization`, `existing_user`, `omniauth_user`) carry their model names.
- Structure: the helper is a pure function with a small extracted per-value sanitizer; the occurrence-order comment explains WHY (parse alphabetizes) — load-bearing, not noise. Controller edits are minimal insertions into existing structures; no method rewrites.
- Readability: the JSX hidden-input block follows the existing tracking-inputs comment section; the `Auth.tsx` effect is guard-first and six lines long.
- Convention adherence: delegated to the 19-file conventions fan-out (see conventions-compliance.md) — zero findings; rubocop/eslint over the changed files show no new diff-line offenses beyond the two known accepted baselines (ParameterLists on `from_omniauth`; exhaustive-deps on the `[emailConfirmed]` effect).
- One style observation, not a defect: the try/catch around `decodeURIComponent` uses `catch (e)` with `e` unused — the codebase has no lint rule against unused catch bindings and eslint reports nothing here.

## Findings

No issues found.
