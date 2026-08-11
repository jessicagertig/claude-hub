# posthog-events-and-identity — Round 2

Re-derived fresh.

## Verified

- **Event names exact, all plain no-property `trackEvent` calls:** `user_signed_up_client_side` (AuthForm `magicLink` onSuccess, SignupForm `register` onSuccess — both before `onComplete`), `organization_created` (OrganizationForm `createOrganization` onSuccess, before `onComplete(data)`), `organization_owner_user_name_submitted` / `invited_user_name_submitted` (ProfileForm `updateMe` onSuccess, keyed on `props.isNewOwner`, else-branch catches `wasInvited` and the neither-true edge — before `props.onComplete()`).
- **Confirmation redirect (`hire/confirmations_controller.rb:18`):** success branch only — `"/auth?email_confirmed=true&id=#{user.id}&email=#{CGI.escape(user.email)}"`; failure branch (line 21) byte-identical to before. `CGI.escape` handles `+`-bearing emails; the new controller spec pins `confirm+test@example.com` → `%2B` encoding, and the '+'-as-space frontend decode in `queryString.parse` reverses it correctly.
- **`Auth.tsx` identify:** second `React.useEffect` with deps `[emailConfirmed]`, bare-return unless true, guard `id != undefined && email != undefined` (house form; both params required — a stale bookmarked `/auth?email_confirmed=true` fires NEITHER call), then `identifyUser({ id: Number(id), email: email as string })` followed by `trackEvent("email_verified")`. `identifyUser` keys on `String(user.id)` → distinct_id identical to the `AppAuthRouter.tsx` identify. Fires once per landing (`emailConfirmed` transitions false→true once, never back). Mechanism is exactly spec §5.6's init-ordering-immune design. `AuthRegister.tsx`/`Login.tsx` unmodified.
- **No identify in `OrganizationForm`:** confirmed absent, per D13 (the `AppAuthRouter` effect re-fires on query invalidation).
- **Server events untouched:** zero `PosthogTrackJob`/`PosthogIdentifyJob` diffs anywhere; `git grep user_signed_up_client_side` → exactly the two frontend callsites; server `'user_signed_up'` strings (registrations_controller.rb:52,190, omniauth_callbacks_controller.rb:35, invites_controller.rb:80) unmodified.
- **`posthog.ts` committed as-is:** the diff is exactly the `identifyUser` `window.logger` addition (fire + skip paths); `trackEvent`'s loggers verified pre-existing at base commit `62dd55867`. No other change.
- Accepted semantics not flagged per REVIEW-ANGLES: shared-form firing for existing users (Risk 1); email in redirect URL (Risk 6/D12); SSO signups getting neither event (§10).

## Findings

- F1 [LOW — recorded in Round 1, decision-bound, no fix required] `Auth.tsx` new effect / hand-crafted confirmation URLs can fire a polluted identify / a forged `/auth?email_confirmed=true&id=abc&email=x` yields `Number("abc")` → `ph.identify("NaN")`; a repeated `id` param parses to an array → same NaN path. The presence-only guard is exactly what D12 + spec §5.6 specify (spec-conformant); independently re-derived this round and it matches Round 1's recorded LOW. Any tightening (numeric-format guard) would be a new decision for Jessica.

No BLOCKER/HIGH/MED findings.
