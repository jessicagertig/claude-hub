# PLAN — attribution on PostHog events, and last-touch capture at organization creation

Repo `/Users/jessica/wrk/wrk-corp/inflow-ats`, branch `attribution-work-qa`.
Line numbers are as of the branch at the time of writing.

## Why

Attribution is captured onto `users` at signup and copied to `organizations` at org creation, but it
never reaches PostHog except on subscription conversion events. So the signup funnel cannot be
segmented by campaign, and a person who drops off has no source recorded anywhere PostHog can see.

Separately, attribution is captured exactly once, at mount in `AuthForm.tsx:40-41` and
`SignupForm.tsx:25-26`. Someone who arrives from one platform, leaves, and is brought back by a
different platform's retargeting has only the first platform recorded. The organization form is the
one post-signup screen every path reaches — SSO skips email confirmation and name entry entirely —
so it is the only place a return campaign can be observed.

Result wanted: **user row is first-touch and immutable, organization row is last-touch.** Comparing
them per field names the platform that brought someone in and the platform that closed them, including
when those are different companies.

## Decisions already made

- `$set_once`, not `$set` — first-touch attribution must not be overwritten.
- Attribution goes on `user_signed_up` and `organization_owner_signed_up` only. Nothing on
  `invited_user_signed_up` (covered, since `user_signed_up` fires for every signup including invited),
  nothing on `user_logged_in` (login is not acquisition), nothing on the email-verified or
  name-submitted events (the components have no access to the values and exposing them on a serializer
  is not wanted).
- User row: fill fields that are nil, never overwrite. Organization row: fresh value wins, user's value
  is the fallback.
- `update`, not `update_columns` — all three `User` update callbacks are inert for an attribution-only
  write (`check_for_corporate_email` returns unless `email` changed; `after_update_callback` is guarded
  on `confirmed_at`/`first_name`/`last_name`; `send_pending_devise_notifications` iterates an empty
  array), so there is nothing to skip.
- Full `if`/`else`, not a modifier form.

## Tasks

### T1 — `User#attribution_properties`

`app/models/user.rb`. Returns the thirteen values, `.compact`ed so nils never reach PostHog:

`utm_source`, `utm_campaign`, `utm_data`, `internal_ref`, `adroll_click_id`, `google_click_id`,
`adroll_first_party_cookie`, `ga_client_id`, `ga_session_id`, `fbclid`, `fbp`, `fbc`, `li_fat_id`.

Analog: `SubscriptionEvent#posthog_properties` — model method returning a PostHog hash ending in
`.compact`.

### T2 — attribution on `user_signed_up`

Four call sites. Each gets the hash twice: as `'$set_once'` and as plain event properties, merged
alongside the existing `method:` property.

- `app/controllers/api/v1/registrations_controller.rb:52` — `method: 'email'`
- `app/controllers/api/v1/registrations_controller.rb:210` — `method: 'magic_link'`
- `app/controllers/auth/invites_controller.rb:80` — `method: 'invite'`
- `app/jobs/track_new_sso_owner_signup_job.rb:11` — `method: 'google_sso'`. Note this one calls
  `POSTHOG_CLIENT.capture` directly through its private `capture` helper, not `PosthogTrackJob`, so
  there is no `deep_symbolize_keys`; pass `'$set_once'` as a string key.

### T3 — attribution on `organization_owner_signed_up`

Event properties only — it already carries `'$set_once' => { originally_signed_up_as_owner: true }`,
and `user_signed_up` fires alongside it and has already set the attribution on the person.

- `registrations_controller.rb:54` — `method: 'email'`
- `registrations_controller.rb:211` — `method: 'magic_link'`
- `track_new_sso_owner_signup_job.rb:12` — `method: 'google_sso'`

### T4 — capture at the organization form

`app/javascript/ats/src/views/sessions/components/OrganizationForm.tsx`.

Import `adPlatformCookies` from `@shared/lib/utils` and capture once at mount:

```tsx
const [adPlatformValues] = React.useState(adPlatformCookies());
```

Only cookies are available at this point — URL params are long gone — so this yields seven values:
`gaClientId`, `gaSessionId`, `googleFirstPartyCookie`, `fbp`, `fbc`, `linkedinFirstPartyCookie`,
`adrollFirstPartyCookie`.

Used twice:

- as properties on the existing `trackEvent("organization_created")` call
- added to the `createOrganization` payload alongside `{ name, heardAboutUsFrom }`

### T5 — permit the seven

`app/controllers/api/v1/organizations_controller.rb`, `organization_params` at :127-128.

Permit `:ga_client_id`, `:ga_session_id`, `:google_click_id`, `:fbp`, `:fbc`, `:li_fat_id`,
`:adroll_first_party_cookie`.

This reverses the permit closure this PR made for `:google_click_id` and `:adroll_first_party_cookie`.
That is deliberate — the earlier change stopped the browser *replacing* organization attribution; this
one lets it *supplement* it via a fallback. Say so in the PR description so a reviewer does not read it
as an undo.

### T6 — per-field fallback on the organization

Replace the thirteen unconditional assignments at `organizations_controller.rb:32-44` with a per-field
fallback: submitted value if present, else `current_user`'s, else nil.

Analog: `SubscriptionEvent#attribution_value(owner_value, organization_value)` — the house form for
"this if present, else that, else nil" as a full if/elsif/else.

The six fields with no cookie source — `utm_source`, `utm_campaign`, `utm_data`, `internal_ref`,
`adroll_click_id`, `fbclid` — always fall through to `current_user`.

### T7 — fill the user's nil fields

Inside the `if @organization.save` success branch, after the existing owner setup at :50-52.

Build a hash of only the fields where `current_user`'s value is nil and a submitted value is present.
If that hash is empty, do nothing. Otherwise `update` and handle failure in the house form:

```ruby
updated = current_user.update(attribution_to_fill)
if updated
  # nothing further
else
  Rails.logger.error "..."
  ap current_user.errors
end
```

Never overwrite a non-nil value on the user.

### T8 — rescue

Already done. `organizations_controller.rb#create` has a method-level `rescue StandardError` following
`cursor_rules/backend/controllers/controller_error_handling.md:111-119` —
`Sentry.capture_exception`, `ap`, `Rails.logger.error`, `render_general_errors`. Without it a raise
returned a 500, and `OrganizationForm`'s `onError` does `setErrors(response.data.errors)`, which is
absent on a 500 — so the user saw nothing at all and would click again, creating a second organization
since the `current_user.organization.nil?` guard at :28 is commented out.

## Verification

Manual, driving the real app with Playwright against the dev server on `app.lvh.me:5007`. Rule 0a
forbids RSpec specs; this is the manual exercise it asks for. Procedure proven today:

1. Navigate to `http://app.lvh.me:5007/`, set cookies via `document.cookie` with `domain=.lvh.me`
2. Navigate to `/auth-register` with query params, submit the email
3. Read the user's `confirmation_token` with `rails runner`, visit
   `/email_confirmation?confirmation_token=<token>`
4. Submit first and last name, then the organization name
5. Read the user and organization rows with `rails runner` and compare

Cases:

- **cookies + params** — params win for `google_click_id`, `li_fat_id`, `fbclid`; cookies supply `fbp`,
  `fbc`, `ga_client_id`, `ga_session_id`, `adroll_first_party_cookie`
- **cookies only** — UTM fields nil, cookie fallbacks populate
- **params only** — `fbp` and `fbc` nil
- **new: cross-platform return** — sign up with one platform's cookies, then clear and set a different
  platform's before the organization form. Organization must diverge from the user on exactly the
  swapped fields; the user's already-populated fields must be unchanged; the user's previously-nil
  fields must now hold the new platform's values.

Between cases the browser context must be cleared — `browser_close` does not clear it, and the Rails
session cookie is httpOnly so `document.cookie` cannot remove it. Use `/logout`.

Also confirm in PostHog that `user_signed_up` carries the attribution as event properties and that the
person has them set.

## Open

Whether this ships in PR #3075 or a follow-up, given T5 reverses a permit closure that PR made.
