# operational-concerns — Round 2 (always-on impl angle)

- **Logging:** `window.logger` on both `identifyUser` paths (fire + skip) gives Jessica the dev-verification hook D13/D16 rely on; `trackEvent` loggers pre-existing. Backend: the setup lambda's `Rails.logger.info("[SSO][request_phase] tracking=...")` now includes the new keys automatically (same `tracking_params` hash) — no logging gap.
- **Error handling:** no new failure modes introduced on the happy paths; `sanitizeTrackingParams` guards its only throwing operation (`decodeURIComponent`) with try/catch and `queryString.parse` v6.1.0 uses the non-throwing `decode-uri-component` — a malformed query string cannot crash the auth pages. PostHog helpers keep their not-loaded skip guards, so events degrade silently (with a logged skip) rather than erroring.
- **Performance:** the helper is O(params) string work executed during render of low-traffic auth pages, same cost class as the adjacent `queryString.parse` calls; no queries added to any hot path; org create adds four in-memory attribute copies.
- **Deployment:** both migrations are additive nullable columns — safe online, no lock concerns on `add_column` without default (Postgres), no backfill job to schedule, no rollback hazard (auto-reversible `change`). Feature degrades gracefully pre/post-deploy: absent params were already tolerated (permit-list additions are inert for old clients).
- **Monitoring:** the five event names land in PostHog for funnel assembly; server backup events untouched, so existing dashboards keep working.
- **Session cookie growth (SSO):** sanitized-browser worst case ~3KB against the ~4KB cookie ceiling — accepted spec Risk 2, not re-litigated.

## Findings

No issues found.
