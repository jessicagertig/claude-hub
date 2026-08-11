# backward-compatibility (always-on check) — Round 1

All consumers of modified code identified and verified:

- **`User.from_omniauth` (breaking signature change, D9-mandated):** repo-wide census at review time (`git grep -n from_omniauth`) → exactly one production call site (`omniauth_callbacks_controller.rb:22`), converted to keyword form in the same commit. Zero positional callers remain; the new specs pin the keyword interface so a future positional caller fails in CI.
- **`useSession.ts` `magicLink`/`register` request functions:** sole callers are `AuthForm.tsx` (via `useMagicLink`) and `SignupForm.tsx` (via `useRegister`) — grep confirmed no other importer. The four new destructured params default to `undefined` for any caller that omits them; the inline type additions are optional fields. Non-breaking.
- **`GoogleSSOButton`:** rendered only by `AuthForm.tsx` (grep). New props optional. Non-breaking.
- **`sanitizeTrackingParams`:** new export; no name collision (census).
- **`sign_up_params` permit growth:** additive; old clients that don't send the params are unaffected (`sign_up_params[<key>]` nil → nil columns, proven by executed specs).
- **`magic_create` JSON responses:** byte-identical (no diff in the response-building code); frontend consumers (`Auth.tsx` `onComplete` reading `needsEmailConfirmation` etc.) unaffected.
- **Confirmation redirect URL:** gained two query params on the success branch. Consumers of the landing: `Auth.tsx` (reads `email_confirmed`, now also `id`/`email` — handles both present and absent), `AuthRegister.tsx`/`Login.tsx` (read `email_confirmed` only; extra params ignored by `queryString.parse` consumers). The `Hire::PagesController#redirect_if_authed` bounce for signed-in users drops the params exactly as it did the old URL. Non-breaking.
- **`allowed_keys` growth in the omniauth setup lambda:** additive whitelist; `partner`/`referral` behavior unchanged.
- **DB:** nullable, default-free columns — no existing row, query, or model behavior changes; no serializer exposes them, so no API consumer sees a contract change.
- **Existing test suites:** full-Jest delta = zero new failures (only the known pre-existing FormCheckbox suite); pre-existing RSpec failure set non-intersecting (see test-coverage.md).

## Findings

No issues found.
