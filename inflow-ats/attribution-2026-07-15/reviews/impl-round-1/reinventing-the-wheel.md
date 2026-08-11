# reinventing-the-wheel — Round 1

## Verification performed

- **`sanitizeTrackingParams`:** pre-implementation census confirmed nothing equivalent existed (`git grep sanitizeTrackingParams` at base → zero; the only adjacent helper, `standardizeQueryParamsObject`, camelizes an already-parsed object and cannot provide occurrence-order capping or truncation). The helper deliberately REUSES the installed `query-string` (already a repo dependency, imported in the same components) for parsing/extraction rather than hand-rolling a query parser — only the raw-string key scan is new, and that exists precisely because the library's `parse` discards occurrence order (verified in v6.1.0 source). Correctly scoped new code.
- **PostHog:** reuses the existing `trackEvent`/`identifyUser` helpers from `@shared/lib/posthog` at every event site — no direct `posthog.capture`/`posthog.identify` calls, no new wrapper.
- **Wire transform:** relies on the existing `apiPost`/`allKeysToSnake` pipeline; nothing re-implemented.
- **SSO threading:** reuses the existing `setup`-lambda whitelist + `session[:oauth_tracking]` ride + `merged_tracking` recovery verbatim — only the key list grew.
- **URL encoding:** `CGI.escape` (stdlib) rather than a hand-rolled encoder.
- **Tests:** reuse the suite's established stubbing pattern (`allow(controller).to receive(...)`), `Devise::Test::ControllerHelpers`, and the ActiveJob around-block precedent from `bulk_ai_job_application_summaries_controller_spec.rb`; `OmniAuth::AuthHash` for auth stubs.
- **No duplicate columns:** the schema's only other `utm_*` columns are on `ahoy_visits` (unrelated visit-tracking gem table) — no overlap with per-user/org attribution, untouched.

## Findings

No issues found.
