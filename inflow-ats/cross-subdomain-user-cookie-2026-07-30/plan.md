# Plan: cross-subdomain hire app user ID cookie

**Repo/worktree:** `/Users/jessica/wrk/wrk-corp/inflow-ats.cross-subdomain-user-cookie`
**Branch:** `cross-subdomain-user-cookie` (base `develop`)
**Investigation backing this plan:** `investigation/redirects.md`, `investigation/cookie-config.md`, `investigation/frontend-routing.md`, `investigation/conventions.md`

## Goal

Set a first-party cookie on signed-in hire users that is readable by JavaScript on both `app.polymer.co` and `www.polymer.co`, so the marketing site can identify existing customers and exclude them from retargeting.

Scope is setting the cookie only. No marketing-site code — Jessica writes the reader.

## Scope of the change

**One file: `app/controllers/api/v1/base_controller.rb`.**

No new files. No migration. No config. No frontend change. No RSpec (repo rule 0a).

## The change

### 1. Register the callback

`app/controllers/api/v1/base_controller.rb`, after line 7:

```ruby
class Api::V1::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :track_ahoy_visit
  before_action :authenticate_api_v1_user!
  before_action :set_sentry_context
  before_action :set_hire_app_user_id_cookie
```

### 2. Add the private method

Same file, in the existing `private` section (line 31), after `set_sentry_context`:

```ruby
  def set_hire_app_user_id_cookie
    return unless current_user

    cookies[:hire_app_user_id] = {
      value: current_user.id.to_s,
      domain: request.domain,
      expires: 2.years.from_now,
      httponly: false
    }
  end
```

### Emitted header

| Environment | Host | `Set-Cookie` |
|---|---|---|
| development | `app.lvh.me:5007` | `hire_app_user_id=123; domain=lvh.me; path=/; expires=<+2y>` |
| production | `app.polymer.co` | `hire_app_user_id=123; domain=polymer.co; path=/; expires=<+2y>; secure` |

## Decisions, with the reason each was made

| Decision | Value | Why |
|---|---|---|
| Backend, not frontend | Rails `Set-Cookie` | Domain derivation has an established Ruby idiom (`request.domain`, used in six subdomain-constraint files); JavaScript has no equivalent and would need new last-two-labels logic. A `Set-Cookie` header and a `document.cookie` write produce an identical cookie, so this was a coverage-and-idiom choice, not a cookie-mechanics one. |
| Hook point | `before_action` on `Api::V1::BaseController` | Every authenticated interaction is an XHR through this base. Its structural analog `set_sentry_context` sits two lines above: private method, per-request external side effect keyed on `current_user.id`, guarded by `return unless current_user`. |
| Not `Hire::PagesController#root` | — | Password sign-in produces no Rails HTML response at all: `useSession.ts:171` seeds the React Query cache via `queryClient.setQueryData("me", data)` and `Login.tsx:29` is `props.history.push("/jobs")`. A page-controller write would leave that user with no cookie for their whole session. |
| Callback type | `before_action` | Matches `set_sentry_context`. No app-authored `after_action` exists anywhere in `app/controllers/` — the only one is commented out at `application_controller.rb:5`. |
| Guard | `return unless current_user` | **Required** — eight subclasses of `Api::V1::BaseController` skip `authenticate_api_v1_user!`, so `current_user` is nil on those. Bare `return`, no truthy/falsy value, per `core_critical_rules.md:152-154`. Matches `set_sentry_context:37`. |
| Cookie name | `hire_app_user_id` | Follows the `<area>_<thing>` shape of the only two existing cookies (`account_referrer`, `connect_referrer`). Bare `hire` reads as a verb; `<thing>_app` is already a codebase form (`IndividualApp::BaseController`, `namespace :individual_app` at `routes.rb:433`). |
| Value | `current_user.id.to_s` | Matches PostHog's `distinct_id` in this app, so the marketing site can call `identify` with it rather than only testing presence. |
| `domain:` | `request.domain` | `url.rb:329-331` → `extract_domain_from` at `:95-97` is `host.split(".").last(1 + tld_length).join(".")` with `tld_length` defaulting to 1 — literally the last two labels. Yields `polymer.co` in production, `lvh.me` on `app.lvh.me`, `polymer.co` on staging and develop. No environment branching. |
| Not `domain: :all` | — | `cookies.rb:457` uses the heuristic `/\.[^.]{2,3}\.[^.]{2}\z/` to detect two-label TLDs. `app.lvh.me` matches it (`lvh` is 3 chars, `me` is 2), so `:all` emits `Domain=.app.lvh.me` in development — silently, with no error. `app.polymer.co` escapes only because `polymer` is 7 characters. |
| `expires:` | `2.years.from_now` | Without it the cookie is a session cookie, gone on browser close (`rack-2.2.9/lib/rack/utils.rb:242`). Mirrors Devise `remember_for = 2.years` (`devise.rb:171`). Because the cookie is rewritten on every authenticated request, the practical lifetime is two years from last activity. |
| `httponly: false` | explicit | Already the default for the plain jar (`utils.rb:244` — no attribute emitted when nil), so this changes no behavior. Present so the intent is legible and nobody later "hardens" it, which would make the cookie invisible to the only thing that reads it. |
| No `secure:` option | omitted | `config.force_ssl = true` (`production.rb:56`) makes `ActionDispatch::SSL` append `; secure` to every `Set-Cookie` in production (`ssl.rb:79, 114-126`). Development is plain HTTP, where a `secure` cookie would be dropped by the browser. Omitting gets the correct behavior in both. |
| No `same_site:` option | omitted | `config.load_defaults 6.0` (`application.rb:52`) never sets `cookies_same_site_protection`, so no attribute is emitted. Irrelevant regardless: `app.` and `www.` are the same site, and SameSite governs what is sent on requests, not what `document.cookie` can read. |
| Plain cookie jar | `cookies[...]` | Only the plain jar produces a JS-readable value. `cookies.signed` emits `<base64(JSON)>--<HMAC>`; `cookies.encrypted` is opaque AES-256-GCM. |
| Unconditional write | every request | An identical write replaces the existing entry — cookies key on name + domain + path, so no accumulation. Cost is ~100 bytes of response header. A read-then-write-if-missing guard would never migrate a cookie already scoped narrowly to `app.polymer.co`, because the read would return the right value and skip the rewrite. |
| Not cleared on sign-out | — | Shared machines almost always mean two people at the same company, both of whom should be excluded. A stale ID still produces the correct outcome; clearing creates the worse failure of paying to retarget an existing customer. |

## Accepted trade-offs

**Staging and develop write the same cookie as production.** `app-staging.polymer.co` and `app-develop.polymer.co` (`rack_attack.rb:19`) both have registrable domain `polymer.co`, so a staging visit overwrites the production cookie with a staging-database user ID until the next visit to `app.polymer.co`. Accepted, and it is the property that makes the feature testable on staging at all. Harmless because the exclusion decision is presence-based — anyone holding the cookie is a Polymer user and should be excluded regardless of which ID it carries.

**The cookie is sent to every host under `polymer.co`.** Hosts with evidence in the repo: `www`, `api`, `jobs`, `hire`, `help`, `developer`, `mail`, `individual`, plus the four staging/develop hosts. `help.` and `developer.` are third-party hosted. `jobs.polymer.co` is the public unauthenticated job board — candidates who have never signed in have no cookie at all, so nothing is set on them; a signed-in user visiting there simply carries their own.

**A plain cookie is user-editable.** The value is an unverified hint, correct for retargeting exclusion. It must never be treated as an identity assertion.

**ngrok sessions get no cookie.** `ngrok.io` is on the Public Suffix List, so browsers reject a cookie scoped to it. Silently absent during ngrok work.

**Other registrable domains work automatically.** `wrk.xyz` and `wrkhq.com` are live (`rack_attack.rb:20`); `request.domain` handles them with no special-casing.

## Verification

No RSpec — `.claude/CLAUDE.md:29-37` rule 0a forbids writing spec files. Verification is manual.

1. **Local write.** Sign in at `http://app.lvh.me:5007`. In devtools → Application → Cookies, confirm `hire_app_user_id` exists, value equals the signed-in user's ID, `Domain` reads `lvh.me`, `HttpOnly` is unchecked, `Expires` is ~2 years out.
2. **Local cross-subdomain read.** Serve the marketing site from a `lvh.me` host (e.g. `www.lvh.me`) and confirm `document.cookie` there contains `hire_app_user_id`. A cookie scoped to `lvh.me` is invisible to `localhost`, so the reader must be on a `lvh.me` host.
3. **Signed-out.** In a clean profile, load `app.lvh.me` without signing in and confirm no `hire_app_user_id` cookie is set.
4. **Public API path.** Hit an `Api::V1::Public::` endpoint unauthenticated and confirm no `Set-Cookie` for this name — this exercises the `return unless current_user` guard.
5. **Staging.** Deploy to staging, sign in at `app-staging.polymer.co`, confirm `Domain` reads `polymer.co`.
6. **Production.** After deploy, confirm on `app.polymer.co` that `Domain` reads `polymer.co` and `Secure` is checked, then confirm the cookie is visible from `www.polymer.co`.

Optional: a Cypress file at `cypress/e2e/auth/` asserting the `Set-Cookie` header. New Cypress files are permitted (`.claude/CLAUDE.md:532-533`), and `cypress/e2e/auth/logout.cy.js:58-60` is the existing precedent for asserting on that header.

## What the cookie looks like to a reader (for reference, not specified here)

- **Name:** `hire_app_user_id`
- **Domain:** `polymer.co` — readable from any `*.polymer.co` host
- **Value:** the Polymer user ID as a string; matches PostHog `distinct_id`
- **Presence:** present ⇒ signed-in Polymer user

## Out of scope

Connect app. Individual app. The account app (`/account` is a separate React root and controller; a user reaching it already holds the cookie from their hire-side activity). Marketing-site code.
