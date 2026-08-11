# operational-concerns — Round 1

## Verification performed

- **Migrations:** additive nullable columns on `users` and `organizations` — no table rewrite on Postgres (no default), no index build, no lock risk; safe to deploy ahead of code. Applied on dev (schema.rb regenerated at version `2026_07_15_233506`) and test DBs (`db:migrate:status` shows both `up`). No data migration to sequence.
- **Rollout/backward compatibility:** params are additive and optional in both directions — old clients that never send them produce nil columns; the server tolerates their absence at every layer. The `from_omniauth` signature change ships atomically with its sole call site in the same commit.
- **Logging:** the setup lambda's existing `Rails.logger.info("[SSO][request_phase] tracking=...")` now includes the new keys automatically; `identifyUser` gained dev-only `window.logger` on both fire and skip paths (production-disabled by settings) — the exact observability Jessica uses for manual event verification. No noisy new production logging introduced.
- **Error handling:** browser events are fire-and-forget through the null-guarded `trackEvent`/`identifyUser` helpers (posthog-not-loaded → logged skip, no throw). No new exception paths server-side.
- **Performance:** the sanitizer runs once per auth-page mount on a query string; jsonb writes are single-row at signup frequency. The `email_verified` effect fires at most once per landing. Negligible.
- **PostHog event volume:** `user_signed_up_client_side` fires on every successful `magic_login` response including existing-user login-link requests — the approved step-2 semantics (spec Risk 1), an analytics-volume property Jessica has accepted.
- **Session cookie:** up to ~3KB of sanitized tracking on the SSO ride vs the ~4KB ceiling — accepted spec Risk 2.
- **Pre-commit hook:** the commit exists on the branch, implying the hook (Cypress `registration.cy.js` + lint-staged) ran at commit time; this review verified zero `cypress/` diff and ran RSpec/Jest/eslint/rubocop directly, but did not re-run the Cypress suite itself (browser E2E outside review scope). If independent confirmation is wanted, the QA phase covers it.
- **No deployment coupling:** no env vars, no feature flags, no cron/Sidekiq changes, no serializer/API contract changes for existing consumers.

## Findings

No issues found.
