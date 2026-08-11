# code-quality — Round 1

## Verification performed

- **Naming:** `sanitizeTrackingParams`, `sanitizeTrackingValue`, `TRACKING_VALUE_MAX_LENGTH`, `UTM_DATA_MAX_KEYS`, `keysInOccurrenceOrder`, `utmDataKeys`, `trackingParams` — descriptive, consistent with the file's existing helper style. Ruby additions reuse existing local names (`user_params`, `merged_tracking`) and introduce none.
- **Structure:** the helper is placed with the other query-param helper (`standardizeQueryParamsObject`) per the spec's placement analog; the private `sanitizeTrackingValue` and the two constants sit directly above their only consumer. Frontend edits are minimal insertions into existing callbacks/state blocks — no restructuring of working code.
- **Comment quality:** the helper's header comment documents the non-obvious constraint (occurrence order from the raw string because `queryString.parse` v6.1.0 sorts keys) — load-bearing, not noise. The new spec files carry concise intent comments including the `login_intent: 'hire'` routing rationale and the devise-mapping rationale (inherited from the plan, useful to future readers).
- **Readability:** the `magic_create` merge additions mirror the surrounding hash style exactly; the `GoogleSSOButton` inputs replicate the analog's ternary-guard JSX shape; the `Auth.tsx` effect is 8 lines with a bare-return guard.
- **Formatting/linters:** eslint 0 errors (only pre-existing warnings + the spec-bound exhaustive-deps case — see conventions-compliance.md); rubocop clean on every diff line except the D9-inherent `Metrics/ParameterLists` at `user.rb:379`; prettier-compatible formatting throughout (trailing commas, double quotes in TSX/JS, single quotes in Ruby).
- **No dead code, no TODOs, no placeholders** introduced.

## Findings

No issues found.
