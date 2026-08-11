# Approved Decisions — UTM capture + identify

## Decision 1 — where utm params are captured

`AuthForm.tsx` parses `location.search` with `queryString.parse` at component render and holds the values in React component state: `utm_source`, `utm_campaign`, every other query param whose name starts with `utm_`, and `internal_ref` — the same mechanism the existing `referral` state uses in `AuthForm.tsx`.

## Decision 2 — captured values enter the signup request

`AuthForm.tsx` includes in the `magicLink` mutation payload (the `useMagicLink` hook in `useSession.ts`, posting to `/api/v1/magic_login`, handled by `Api::V1::RegistrationsController#magic_create`): `utm_source` and `utm_campaign` as top-level string fields alongside the existing `referral` and `partner` fields, plus `utm_data` — a single object field holding every other captured `utm_*` param keyed by its param name — and `internal_ref` as a top-level string field.

## Decision 3 — server writes the values onto the new User

`Api::V1::RegistrationsController#sign_up_params` additionally permits `utm_source`, `utm_campaign`, and `internal_ref` as plain single-value params, and `utm_data` as an arbitrary-key hash (the `options: {}` permit form from `questions_controller`). `magic_create` merges these four into `user_params` so they are assigned as attributes when the User row is created — values stored raw as sent, no `get_created_via`-style mapping, and a param absent from the request leaves its column nil.

## Decision 4 — sanitization at capture

A new helper in `app/javascript/shared/lib/utils.js` (joining the existing query-param helpers like `standardizeQueryParamsObject`) transforms the captured params before they are set into `AuthForm.tsx` component state: each value truncated to 255 characters; when `queryString.parse` yields an array for a repeated param, the first occurrence kept; at most 10 `utm_*` keys beyond `utm_source`/`utm_campaign` kept in `utm_data`, keeping the first 10 by occurrence order and dropping the rest.

## Decision 5 — how organizations get the values

`Api::V1::OrganizationsController#create` copies `utm_source`, `utm_campaign`, `utm_data`, and `internal_ref` from `current_user` onto the new Organization, the same way that action already copies `created_via` from `current_user`. No re-capture of query params at organization creation.

## Decision 6 — new columns

Two migrations, one per table. On `users` and on `organizations`, identically: `utm_source` string, `utm_campaign` string, `utm_data` jsonb, `internal_ref` string. No defaults, no backfill of existing rows.

## Decision 7 — captured values enter the SSO request

`AuthForm.tsx` passes the captured `utm_source`, `utm_campaign`, `utm_data`, and `internal_ref` to `GoogleSSOButton.tsx` as props, and `GoogleSSOButton.tsx` renders them as hidden form inputs in its POST to `/api/v1/users/auth/google_oauth2` — alongside the existing `referral` and `partner` hidden inputs, rendered only when present, `utm_data` as one hidden input per key using Rails-nested `utm_data[key]` naming.

## Decision 8 — SSO tracking whitelist grows

The omniauth `setup` lambda in `config/initializers/omniauth.rb` adds `utm_source`, `utm_campaign`, `utm_data`, and `internal_ref` to `allowed_keys`, so those params from `GoogleSSOButton.tsx`'s POST ride `session[:oauth_tracking]` to the callback the same way `partner` and `referral` do today.

## Decision 9 — how the values are passed into `from_omniauth`

`User.from_omniauth` converts to keyword arguments throughout, declared in this order: `auth:` and `created_via:` required keywords, then `partner_source:`, `utm_source:`, `utm_campaign:`, `utm_data:`, `internal_ref:`, each defaulting to nil. `Api::V1::Users::OmniauthCallbacksController#google_oauth2` updates to keyword form and supplies the four new values from the merged tracking hash. As part of this change, the implementer searches every tracked file in the repository for `from_omniauth` references and converts every call site found. Assignment of the four happens inside `from_omniauth`'s `first_or_create` block, alongside `created_via` and `partner_source` — set only when the User row is created; an existing user logging in via SSO untouched.

## Decision 10 — password signup path (`/register`) captures the same values

`SignupForm.tsx` captures `utm_source`, `utm_campaign`, other `utm_*` params, and `internal_ref` from `props.location.search` through the same `app/javascript/shared/lib/utils.js` sanitization helper as `AuthForm.tsx`, and includes the four in the `register` mutation payload (the `useRegister` hook in `useSession.ts`, posting to `/sign_up`). No server change beyond Decision 3: `registrations#create` assigns them because they arrive inside `sign_up_params`.

## Decision 12 — email-verification event

The confirmation redirect URL carries the user's id and email. `Auth.tsx`, in the code path that already reads `email_confirmed` from `location.search`, calls `identifyUser({ id, email })` with those values, then `trackEvent("email_verified")`. Fires only on the `email_confirmed=true` landing — the URL only the confirmation redirect produces (`hire/confirmations_controller.rb:18` is its sole producer); magic-link logins never reach it.

## Decision 13 — organization-creation event

`OrganizationForm.tsx`, in the `createOrganization` `onSuccess` callback (where `onComplete(data)` already runs): `trackEvent("organization_created")` fires on every successful creation. No identify call added: the existing `AppAuthRouter` identify effect re-fires with the new organization's properties when `useCreateOrganization` invalidates the `me` and `currentOrganization` queries. (Jessica verifies the effect re-fire in dev via the `identifyUser` `window.logger`.)

## Decision 14 — step 2 event name (email submitted, client side)

The browser event at `magicLink` onSuccess in `AuthForm.tsx` (and at `register` onSuccess in `SignupForm.tsx` for the password path) is named `user_signed_up_client_side`, distinct from the server's `user_signed_up`, which stays untouched as backup.

## Decision 15 — step 4 (logged in) stays server-side

The funnel's logged-in step keeps the existing server `user_logged_in` as its event. No browser login event is added now — a magic-link login lands directly in the app, so no distinct browser moment exists without extra signaling; that complexity is deferred, not declined.

## Decision 16 — profile-name events

`ProfileForm.tsx`, in the `updateMe` `onSuccess` callback, fires one of two events: `organization_owner_user_name_submitted` when the form's existing `isNewOwner` prop is true, `invited_user_name_submitted` otherwise (the `wasInvited` case and the rare neither-true edge both land here). Both plain `trackEvent` calls, no properties.

## Decision 17 — signup-page event deferred

No event fires on `/auth-register` in this PR. A bare page-viewed event only counts arrivals and says nothing about what happened on the page — which button, login instead, nothing at all. The signup page gets instrumented properly (arrival plus in-page interactions) in the marketing-site round, which is queued to follow this work. Until then the funnel's first captured step is `user_signed_up_client_side`.

## Decision 18 — email-verification events on the Tell-us-about-you page (2026-07-16; supersedes Decision 12's event)

The Tell-us-about-you page fires one of two events on mount, keyed on the `isNewOwner` value it already computes: `organization_owner_email_verified` when true, `invited_user_email_verified` otherwise. Fires for everyone who reaches the page — email, Google SSO, and invited signups alike; reaching it requires a confirmed email, which is the fact being recorded.

## Decision 19 — remove the email-verification mechanism from `/auth` (2026-07-16)

Everything Decision 12 placed there is deleted: the `trackEvent("email_verified")` and `identifyUser` calls in `Auth.tsx`, and the `id`/`email` params on the `hire/confirmations_controller.rb` confirmation redirect (it reverts to bare `email_confirmed=true`). Decision 12 is void — its approval never validly covered the `/auth` placement (the page's server-side redirect means confirmers don't land there; the decision text asserted the landing as fact).

## Decision 20 — SSO new-user event fires `user_signed_up` (2026-07-22)

A brand-new Google SSO user currently fires `user_logged_in` instead of `user_signed_up`, because `Api::V1::Users::OmniauthCallbacksController#google_oauth2` selects the event with `user.previously_new_record?`, and `User.from_omniauth` runs `user.update(first_name:, last_name:)` after `first_or_create` — that second save makes `previously_new_record?` return false before the controller reads it. Fix, three edits:

**Edit 1 — declare the temporary attribute.** `app/models/user.rb`, class `User`: add `:new_user_created_via_google_sso` to the `attr_accessor` at line 11 (a temporary, non-persisted attribute holding a boolean value).

**Edit 2 — assign its value.** `app/models/user.rb`, method `self.from_omniauth` (class method, line 379): add `user.new_user_created_via_google_sso = user.previously_new_record?` after the `first_or_create` block ends (line 397) and before `user.update(first_name:, last_name:)` at line 403 — that `update` is a second save and `previously_new_record?` returns the result of the most recent save.

**Edit 3 — evaluate the temporary attribute.** `app/controllers/api/v1/users/omniauth_callbacks_controller.rb`, class `Api::V1::Users::OmniauthCallbacksController`, action `google_oauth2` (line 4), inside the `if user.persisted?` branch (line 32), the ternary on line 35 (`user.previously_new_record? ? 'user_signed_up' : 'user_logged_in'`): replace only the ternary's condition — `user.previously_new_record?` becomes `user.new_user_created_via_google_sso`; both arms unchanged.

Blast radius: `from_omniauth` has one caller (this controller); non-Google sign-ins (`RegistrationsController#create`, `#magic_create`, `Auth::InvitesController`) fire their own `user_signed_up` and never touch it; the `attr_accessor` stays nil for them.

## Decision 21 — SSO owner funnel events, server-side (2026-07-22)

Google SSO users skip the browser onboarding page (Google supplies the name, so `has_completed_profile?` is already true and `AppAuthRouter` routes them straight to org creation), so the client-side `organization_owner_email_verified` (D18) and `organization_owner_user_name_submitted` (D16) never fire for them. Fix: in `Api::V1::Users::OmniauthCallbacksController#google_oauth2`, inside the `if user.persisted?` branch, when `user.new_user_created_via_google_sso` is true (Decision 20), enqueue two events via `PosthogTrackJob`: `organization_owner_email_verified` and `organization_owner_user_name_submitted`. Being server-side through `Posthog::Track`, each is keyed on `distinct_id = user.id` and automatically carries email, organization_id, organization_name, and plan (its default properties).

A fresh SSO signup is always an org owner, so only the owner variants fire — no invited variant, no pending-invite check. Invited users cannot sign up via Google SSO: the invite is accepted only by clicking the invite URL (`Auth::InvitesController#accept` → `register_and_accept`), which creates a password user with no name and routes them to the onboarding page, where the client-side `invited_user_email_verified` / `invited_user_name_submitted` already fire. (Confirmed empirically: production Google users with pending invites are Google signups who happened to have an unaccepted invite, not people who came through an invite via SSO.)

## Decision 22 — SSO funnel events fire via a dedicated ordered job with an explicit base timestamp (2026-07-23; refines Decision 21's implementation)

Problem with the shipped Decision 21 approach (three `PosthogTrackJob` calls): posthog-ruby serializes timestamps to millisecond precision (`utils.rb` `time_in_iso8601(time, fraction_digits = 3)`), and the three near-simultaneous events would collide on the same millisecond (or be scrambled by Sidekiq's non-FIFO scheduling), breaking a strictly-ordered PostHog funnel. Also, computing the timestamp at job-run time risks Sidekiq backlog stamping the events *after* the later client-side `organization_created`.

Fix: a new job `TrackNewSsoOwnerSignupJob` fires the three ordered events for a new SSO owner, calling `POSTHOG_CLIENT.capture` directly (leaving the generic `PosthogTrackJob` and `Posthog::Track` untouched). `Api::V1::Users::OmniauthCallbacksController#google_oauth2` computes `base = Time.current` at the callback and passes it: `TrackNewSsoOwnerSignupJob.perform_later(user.id, base)`. The job fires `user_signed_up` at `base` (property `method: 'google_sso'`), `organization_owner_email_verified` at `base + 0.001`, `organization_owner_user_name_submitted` at `base + 0.002`, each carrying the user's `email`. The 1ms gaps survive millisecond truncation (deterministic order), and anchoring to `base` = signup time guarantees the later `organization_created` can never precede them regardless of Sidekiq delay. Existing SSO users still fire `user_logged_in` via the generic `PosthogTrackJob`.
