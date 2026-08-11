# sso-oauth-session-contract — Round 2

Round-2 sweep of the SSO chain against the amended spec. No new findings.

- `GoogleSSOButton` consumer census: exactly one render site (`AuthForm.tsx:120`) — the optional new Props require no other parent changes; absent props render no inputs (backward-safe).
- Setup-lambda callback-phase re-run re-confirmed harmless: `if tracking_params.any?` guards the session write, and Google's callback params contain none of the six allowed keys — `session[:oauth_tracking]` set in the request phase survives to `session.delete` in the callback.
- The §5.3 per-key guard amendment (round 1) re-read against the analog: identical form to the `referral`/`partner` guards; the stated JSON/SSO degenerate-value divergence is the analog's own existing behavior (empty `referral` is likewise dropped from the form but sendable via JSON).
- `from_omniauth` keyword order, required/optional split, block-only assignment, and post-block behavior: byte-consistent with D9 and the live method (user.rb:379).
- Call-site census re-run this round: `git grep -ln from_omniauth` → `app/models/user.rb`, `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` — unchanged.

## Findings

- None.

## Amendments Applied

- None.
