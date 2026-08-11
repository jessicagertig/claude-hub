# Impl round 1 — reinventing-the-wheel

- **Cookie reading:** the codebase's existing cookie reader is `useCookieValue` — a React hook with the known `cookie.split("=")[1]` value-truncation defect. Not using it here is the SANCTIONED deviation (no-Jest ruling 2026-07-16 + the defect must not be inherited; also a hook cannot be called from a plain helper function). The replacement is two small module-private functions inside `utils.js`, not a new module/util file — minimal, and placed in the analog's own capture location. Not reinvention.
- **Value sanitization:** reuses `sanitizeTrackingValue` via a defaulted `maxLength` param rather than a parallel function — the right reuse; first-of-array and surrogate-safe logic not duplicated.
- **Wire transform:** relies on the existing `allKeysToSnake` pipeline; no bespoke serialization added.
- **SSO ride:** reuses the existing hidden-input → setup-lambda → `session[:oauth_tracking]` mechanism; no new session plumbing.
- **Parse logic:** the `_gcl_aw` split-dot-last parse was MOVED (with its comments) rather than re-derived; no second copy remains anywhere (`_gcl_aw` grep under `app/javascript/ats/` is clean).
- No new dependencies, components, hooks, services, jobs, routes, policies, or serializers.

## Findings

None. 0 BLOCKER / 0 HIGH / 0 MED / 0 LOW.
