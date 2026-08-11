# QA MED Findings - Consolidated (attribution, all runs/layers)

**Date:** 2026-07-16 | **Branch:** attribution-work-qa | **For Jessica's review - none of these were fixed during QA (MED = report, do not fix)**

## MED findings (4, deduplicated)

### M1 - SSO session tracking ride is typeless and uncapped server-side (accepted-design consequence)
`config/initializers/omniauth.rb` setup lambda. The JSON signup path gets frontend sanitization; the SSO path stores whatever arrives as request params into `session[:oauth_tracking]` - mistyped params (e.g. `utm_data=plainstring`) store garbage or nil silently, and values are uncapped, so a direct POST to the omniauth request path can overflow the ~4KB session cookie (`ActionDispatch::Cookies::CookieOverflow` -> 500 for that request). SPEC Risk 2 and D3 ("no server-side sanitization") make this an accepted property of the approved design; recorded because the 500 (vs dropped tracking) may be worth a future ruling. (Layer 2 agents A-1 + A-2, merged - same root cause.)

### M2 - Pre-existing magic_create connect-branch crash; new merge keys are dead code there
`app/controllers/api/v1/registrations_controller.rb` lines ~88-97: `login_intent` defaulting to 'connect' with no `organization_slug` evaluates `organization.id` on nil -> NoMethodError. Pre-existing bug, explicitly out of scope (SPEC 9.1 routes tests around it with `login_intent: 'hire'`). The feature's four merge keys added to that branch are correct-but-unreachable until the branch is fixed. (Layer 2 agent A-3; also noted impl-round LOW 5.)

### M3 - Bracket-containing utm_data keys 400 the Google SSO POST
`GoogleSSOButton.tsx` renders `utm_data[<key>]` input names with the captured key verbatim; a crafted query like `?utm_x=1&utm_x%5By%5D=2` produces nested-bracket names that rack 2.2.9 rejects (`Rack::QueryParser::ParameterTypeError` -> 400) on the SSO POST. Crafted-input edge case only; the JSON paths are unaffected. A future hardening could strip bracket characters from utmData keys at capture. (Layer 2 agent B2.)

### M4 - email_verified undercount for signed-in confirmations (spec-documented, needs future decision)
SPEC Risk 7 / 10: confirmations clicked while signed in bounce off /auth server-side (`redirect_if_authed`), so the D12 browser event fires only for signed-out clicks. Decision-bound (never-approved D11 topic); restated here so it is not lost post-merge. (Cross-referenced from SPEC; no QA layer re-flagged it as new.)

## Dispositions (Jessica's review, 2026-07-16 ~12:30 CT)

- **M1: NO CHANGE.** No typing, no cap. The SSO session ride is untyped for `partner`/`referral` today; the new keys follow the existing mechanism as designed (D3). The cookie-overflow 500 on oversized crafted POSTs is acceptable — desirable, even: no legitimate traffic hits the SSO path with oversized params (real users are pre-capped by the frontend sanitizer), and a cap would let abusive requests continue into the OAuth flow instead of failing.
- **M2: LEAVE ALONE.** The connect flow is unused — nobody currently has a `login_intent` of connect, so the pre-existing nil crash in that `magic_create` branch reaches no live traffic. Not fixed in this PR, no separate fix scheduled. The feature's four merge keys stay in the branch (correct, dormant).
- **M4: RESOLVED BY REDESIGN (Decisions 18/19, 2026-07-16).** The `/auth` event mechanism is removed (Decision 12 void — its approval never validly covered the placement); email-verification events move to the Tell-us-about-you page: `organization_owner_email_verified` / `invited_user_email_verified` keyed on `isNewOwner`, firing for all populations including SSO (a confirmed email is the recorded fact, regardless of how it was verified). Requires code changes on the branch — not yet implemented.
- **M3: NO CHANGE.** No bracket-stripping. Real campaign links don't contain bracketed utm keys; the realistic bracket-sender is a bot, and the rack 400 on the SSO POST is an acceptable (desirable) rejection, consistent with the M1 ruling.

## LOW findings (9, deduplicated - no action expected)

1. Omniauth setup lambda also runs on the callback phase and can overwrite request-phase session tracking (omniauth.rb; pre-existing mechanism shared with partner/referral). (A-4)
2. Confirmation redirect carries the user's email in the URL - encoding verified sufficient; PII exposure is spec-directed D12/Risk 6. (A-5)
3. Sanitizer caps value length (255) and key count (10) but not KEY length; a sanitized browser path can still overflow the SSO session cookie in adversarial cases. (B3)
4. sanitizeTrackingParams throws on non-string input and drops utmData for '?'-less input - unreachable from current callers (location.search). (B4 + C3, merged; matches impl-round LOW 4.)
5. decode-uri-component imported directly but not declared in package.json (phantom dependency - resolvable because it is query-string 6.1.0's own dependency; pinning it in package.json would be more robust). Pre-existing CVE note for decode-uri-component 0.2.0 (ReDoS, fixed in 0.2.1) applies to query-string's own usage equally - pre-existing exposure, not introduced by this diff. (B5)
6. Present-but-empty (?id=&email=) or array-valued id/email pass the Auth.tsx guard: identify("NaN")/empty-email possible on forged URLs only. D12-bound; matches impl-round LOWs 1-2. (C1)
7. email_verified re-fires on remount while the confirmation query params persist (same landing, no navigation) - single-landing dedup would need URL cleanup, a new decision. (C2)
8. allowed_keys extension in the omniauth setup lambda has no direct test coverage (the callbacks controller spec seeds the session directly; the lambda itself is untested - consistent with pre-existing partner/referral coverage). (C4)
9. rubocop Metrics/ParameterLists on from_omniauth and the eslint exhaustive-deps warning on the [emailConfirmed] effect - approved baseline (D9 / SPEC 5.6).

## Also recorded (impl phase, pre-QA): IMPL-REVIEW-COMPLETE.md LOWs 1-5. LOW 3 (malformed-percent-encoding key drop) was elevated to HIGH by QA run 1 Layer 1 and FIXED in commit 299cf9465.
