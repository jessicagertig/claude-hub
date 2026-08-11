# reinventing-the-wheel — Round 2 (always-on impl angle)

- `sanitizeTrackingParams`: no existing helper performs query-param sanitization/truncation/occurrence-capping. `standardizeQueryParamsObject` (same file) does something unrelated (wraps values in arrays for filters). The helper correctly REUSES `queryString.parse`/`queryString.extract` rather than hand-rolling a parser; the raw-string key scan exists only because `parse` discards occurrence order (verified in the installed library) — necessary, not reinvention.
- Sanitize-per-value logic (`isArray`/`isString` + `slice`): built on the lodash predicates already imported in `utils.js`.
- Event/identify calls: reuse the existing `trackEvent`/`identifyUser` helpers — no direct `posthog` imports added in components.
- Backend: reuses `sign_up_params`, the `user_params` merge, `build_resource`, the setup-lambda loop, `merged_tracking`, and the `first_or_create` block — zero parallel mechanisms introduced. The `options: {}` permit idiom reused for `utm_data`.
- Tests: reuse the ai-credit controller-spec stubbing pattern and per-file Devise helper opt-in precedent; no new test infrastructure invented.

## Findings

No issues found.
