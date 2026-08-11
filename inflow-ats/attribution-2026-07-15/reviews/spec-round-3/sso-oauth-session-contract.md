# sso-oauth-session-contract — Round 3

Round-3 sweep. No new findings.

- `redirect_if_authed` relevance to SSO: the SSO form posts to `/api/v1/users/auth/google_oauth2` (omniauth middleware, not `Hire::PagesController`) — no authed bounce in the SSO chain. The form renders inside `AuthForm` on pages a signed-in user bounces off of, which only means signed-in users don't see the button — status quo.
- SSO signups are auto-confirmed (`skip_confirmation!`) and never traverse `confirmations#show` — the Risk 7 coverage boundary does not add any new SSO gap beyond the already-accepted "SSO signups never fire email_verified" (§10).
- Call-site census re-run: `git grep -ln from_omniauth` → 2 files, unchanged.

## Findings

- None.

## Amendments Applied

- None.
