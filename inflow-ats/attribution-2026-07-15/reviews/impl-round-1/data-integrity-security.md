# data-integrity-security — Round 1

## Verification performed

- **Mass assignment:** the four User values enter only through `sign_up_params` (permitted scalars + scoped `utm_data: {}` hash-permit) or the `from_omniauth` keywords; the Organization values are NEVER request-derived — `organization_params` unmodified, values copied from `current_user` only. The anti-tamper spec (unpermitted `utm_source: 'attacker'` in the org-create body ignored) executed green.
- **Authorization surface unchanged:** `/magic_login`, `/sign_up`, omniauth paths remain unauthenticated by design (Devise scope `api_v1_user`); `organizations#create` keeps `authorize @organization`; `confirmations#show` stays token-authenticated via `User.confirm_by_token`. No new endpoints, no policy diffs.
- **Injection:** values land in columns via ActiveRecord parameter binding; jsonb assignment goes through AR type casting; no string-interpolated SQL anywhere in the diff. The redirect URL interpolates `user.id` (integer) and `CGI.escape(user.email)` (encoded) — no header/URL injection vector (a stored email cannot contain CR/LF post-Devise-validation, and escape neutralizes delimiters).
- **Data consistency:** nil-for-absent proven at every layer by the executed specs (columns nil, `utm_data` nil not `{}`); creation-time-only semantics proven (existing users untouched on both magic-link and SSO paths); org copy is a same-transaction attribute set before the existing save flow.
- **Accepted-by-design properties (NOT re-litigated, per REVIEW-ANGLES/spec Risks 2, 4, 6):** no server-side sanitization — direct API callers can store >255-char values and arbitrary `utm_data` shapes (raw-as-sent is D3); cookie-session overflow on a direct unsanitized POST to the omniauth request path; user email in the confirmation redirect URL (HTTPS, first-party, D12).

## Findings

- F1 [LOW] informational, inherent to the approved D12 browser-side design, no fix proposed / anyone can visit `/auth?email_confirmed=true&id=<any>&email=<any>` and cause their browser to fire `identifyUser` + `email_verified` with forged values into PostHog — analytics pollution only, no auth or data impact (client-side `posthog.identify` is spoofable from any console regardless of this feature). The spec's both-params guard targets stale bookmarks, not adversarial URLs, and the mechanism is decision-bound. Recorded so the property is a documented decision artifact, not an oversight.
