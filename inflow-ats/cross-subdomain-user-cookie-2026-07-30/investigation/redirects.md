# Request / redirect topology of an authenticated hire page load

**Repo read:** `/Users/jessica/wrk/wrk-corp/inflow-ats.cross-subdomain-user-cookie`
**Branch:** `cross-subdomain-user-cookie` — `git log --oneline develop..HEAD` is empty and `git status --short` is empty, so the branch is byte-identical to `develop`. Everything below describes existing code, not feature code.
**Gems read from:** `/Users/jessica/.rvm/gems/ruby-3.1.6/gems/` (versions pinned in `Gemfile.lock`: rails/actionpack/actiontext `6.1.7.7`, `devise 4.8.1`, `ahoy_matey 4.0.1`, `sentry-rails 4.8.0`, `tophat 2.3.1`, `rack 2.2.9`, `rack-attack 6.7.0`, `rack-cors 1.0.2`, `rack-rewrite 1.5.1`).

## File chain traced

```
config/routes.rb
  → app/services/subdomain_app_constraints.rb → config/initializers/01_variables.rb (Variables::APP_DOMAIN_LIST)
  → app/services/subdomain_api_constraints.rb
  → app/controllers/hire/pages_controller.rb
      → app/controllers/hire/base_controller.rb
          → app/controllers/application_controller.rb
              → gems/actionpack-6.1.7.7/lib/action_controller/base.rb
              → gems/ahoy_matey-4.0.1/lib/ahoy.rb:117 → gems/ahoy_matey-4.0.1/lib/ahoy/controller.rb
                  → gems/ahoy_matey-4.0.1/lib/ahoy/tracker.rb:137 (reset) → config/initializers/ahoy.rb
              → gems/tophat-2.3.1/lib/tophat/reset.rb
              → gems/sentry-rails-4.8.0/lib/sentry/rails/controller_transaction.rb
              → gems/actiontext-6.1.7.7/lib/action_text/engine.rb:58
              → gems/devise-4.8.1/lib/devise/controllers/helpers.rb:112 (api_v1_user_signed_in?, current_api_v1_user, authenticate_api_v1_user!)
      → app/views/hire/pages/root.html.erb → app/views/layouts/application.html.erb
      → app/javascript/packs/ats_application.js → app/javascript/ats/src/index.js
          → app/javascript/ats/src/views/layouts/App.tsx → AppAuthRouter.tsx
              → app/javascript/shared/queryHooks/useMe.ts → app/javascript/shared/queryHooks/api.ts
                  → app/controllers/api/v1/me_controller.rb → app/controllers/api/v1/base_controller.rb
              → app/javascript/shared/PostHogContext.tsx → app/javascript/shared/lib/posthog.ts
              → app/javascript/ats/src/websockets/WebsocketContext.tsx → app/channels/application_cable/connection.rb
  → app/controllers/hire/redirector_controller.rb
  → app/controllers/hire/confirmations_controller.rb
  → app/controllers/hire/errors_controller.rb
  → app/controllers/hire/integrations/oauth_authentications_controller.rb
  → app/controllers/account/{base,pages}_controller.rb
  → app/controllers/connect/{base,pages}_controller.rb
  → app/controllers/auth/invites_controller.rb → gems/devise-4.8.1/app/controllers/devise/registrations_controller.rb
  → app/controllers/magic_links_controller.rb
  → app/controllers/api/v1/sessions_controller.rb → gems/devise-4.8.1/app/controllers/devise/sessions_controller.rb
  → app/controllers/api/v1/users/omniauth_callbacks_controller.rb
  → app/controllers/api/v1/billing_controller.rb
  → app/controllers/api/v1/public/direct_uploads_controller.rb → gems/activestorage-6.1.7.7/app/controllers/active_storage/{direct_uploads,base}_controller.rb
  → app/controllers/api_public/v1/hire/base_controller.rb → app/controllers/concerns/api_public/v1/hire/html_sanitizable.rb
  → app/controllers/admin/base_controller.rb
  → app/controllers/api/v1/admin/base_controller.rb
  → app/controllers/api/v1/individual_app/base_controller.rb
  → app/controllers/individual_app/base_controller.rb
  → app/controllers/job_board/base_controller.rb
  → app/controllers/concerns/role_fit_filterable.rb
  → app/utils/sanitizer.rb
  → app/controllers/api/v1/integrations/zapier_integrations_controller.rb
  → app/channels/application_cable/channel.rb
  → gems/devise-4.8.1/lib/devise/failure_app.rb
  → gems/devise-4.8.1/lib/devise/controllers/rememberable.rb
config/application.rb → config/environments/{development,production,test}.rb → config/initializers/*
  → gems/railties-6.1.7.7/lib/rails/application/default_middleware_stack.rb
  → gems/railties-6.1.7.7/lib/rails/application/finisher.rb:99-105 (default session store)
  → gems/actionpack-6.1.7.7/lib/action_dispatch/middleware/ssl.rb:73-126
  → gems/rack-2.2.9/lib/rack/etag.rb
```

Live introspection used to confirm callback order, config, and the route→controller→base-class mapping (`bundle exec rails runner` / `bundle exec rails middleware` in the worktree, development env). Every ordering claim in §3 comes from `_process_action_callbacks` on the actual class, not from reading source order. Every claim in §10.3 comes from enumerating all **538** entries in `Rails.application.routes.routes` and constantizing each `defaults[:controller]`, not from reading routes.rb by eye.

---

## 1. Route topology

`config/routes.rb` is 734 lines. Separation between areas is **subdomain constraint at the top level, then path prefix inside** — never subdomain alone.

### Top-level constraint blocks

| Block | routes.rb | Constraint class | Matches when |
|---|---|---|---|
| `constraints SubdomainApiConstraints` | 474 | `app/services/subdomain_api_constraints.rb:3-9` | `request.subdomain.present? && subdomain.start_with?('api') && Variables::APP_DOMAIN_LIST.include?(request.domain)` |
| `constraints SubdomainAppConstraints` | 541 | `app/services/subdomain_app_constraints.rb:3-9` | `request.subdomain.present? && subdomain.start_with?('app') && Variables::APP_DOMAIN_LIST.include?(request.domain)` |
| `constraints SubdomainIndividualConstraints` | 671 | `app/services/subdomain_individual_constraints.rb` | subdomain starts with `individual` |
| `constraints SubdomainJobsConstraints` | 698 | `app/services/subdomain_jobs_constraints.rb` | subdomain starts with `jobs` |
| `constraints CustomDomainConstraints` | 719 | `app/services/custom_domain_constraints.rb` | careers-page custom domains |

`Variables::APP_DOMAIN_LIST = ['wrkhq.com', 'wrk.xyz', 'polymer.co', 'lvh.me', 'ngrok.io', 'localhost']` (`config/initializers/01_variables.rb:95`).

So `app.polymer.co` (and `app-staging`, `app-develop`, `app.lvh.me`) is the hire/account/connect host.

### Inside `SubdomainAppConstraints` (routes.rb:541-666) — the three app areas

| Area | routes.rb | Mechanism | URL prefix | Controller module |
|---|---|---|---|---|
| `account` | 544-560 | `namespace :account` | `/account` | `Account::` |
| `connect` | 562-565 | `namespace :connect` | `/connect` | `Connect::` |
| `hire` | 567-665 | `scope module: :hire` — **module only, no path prefix** | root of the host | `Hire::` |

Hire therefore owns the *entire root namespace* of `app.polymer.co`: `/`, `/jobs`, `/candidates`, `/auth`, `/hire/settings/*`, etc.

`Api::V1::` (routes.rb:69-469) sits **outside every subdomain constraint**, so `/api/v1/*` resolves on any host, including `app.polymer.co` — which is exactly how the SPA's XHR reaches Rails (`app/javascript/shared/queryHooks/api.ts:6`, `:41` build relative `/api/v1${path}` URLs).

`ApiPublic::V1::Hire::` (routes.rb:474-534) is `api.polymer.co` only, API-key authenticated.

### Root route and route helpers referenced in redirects

There is **no unconstrained `root` route**, so `root_path` does not exist as a helper (verified: `Rails.application.routes.url_helpers.root_path` raises `NoMethodError`). Each constrained block declares its own root:

| Declaration | routes.rb | Helper | Path |
|---|---|---|---|
| `root to: 'pages#root', as: :app_root` (inside `scope module: :hire`) | 568 | `app_root_path` | `/` |
| `root to: 'pages#root', as: :account_root` (inside `namespace :account`) | 546 | `account_account_root_path` | `/account` |
| `root to: 'pages#root', as: nil` (inside `namespace :connect`) | 563 | (named `connect`) | `/connect` |
| `root 'home#index'` (inside `namespace :api/:v1`) | 71 | `api_v1_root_path` | `/api/v1` |

Helpers named in redirect code, with resolved paths (all verified by evaluating the helper):

| Helper / literal | Declared | Resolves to | Used by |
|---|---|---|---|
| `app_root_path` | routes.rb:568 | `/` | `Hire::PagesController#redirect_if_authed` (pages_controller.rb:27) |
| `app_root_url` | routes.rb:568 | `https://app.<domain>/` | `Connect::PagesController#root` (connect/pages_controller.rb:5) |
| `auth_path` | routes.rb:591 | `/auth` | destination of literal `'/auth?...'` redirects |
| `login_path` | routes.rb:590 | `/login` | — |
| `register_path` | routes.rb:593 | `/register` | — |
| `admin_path` | routes.rb:606 | `/admin` (router-level 301 to `/admin/dashboard`) | `ApplicationController#after_sign_in_path_for` for `AdminUser` (application_controller.rb:144) |
| `new_admin_user_session_path` | routes.rb:536 (`devise_for :admin_users`) | `/admin_users/sign_in` | `ApplicationController#after_sign_out_path_for` (application_controller.rb:136) |
| `root_path` | **does not exist** | raises `NoMethodError` | `ApplicationController#after_sign_in_path_for`:146 and `#after_sign_out_path_for`:138 — see §4 note |
| `hire_email_confirmation_path` | routes.rb:577 | `/email_confirmation` | Devise confirmation emails |
| `jobs_path` | routes.rb:608 | `/jobs` | literal `'/jobs'` redirects in `Hire::RedirectorController`, `Auth::InvitesController` |
| `onboarding_profile_path` | routes.rb:599 | `/onboarding/profile` | React `<Redirect>` only |
| `organization_new_path` | routes.rb:602 | `/organization/new` | React `<Redirect>` only |
| `needs_email_confirmation_path` | routes.rb:605 | `/needs-email-confirmation` | React `<Redirect>` only |
| `deactivated_path` | routes.rb:604 | `/deactivated` | React `<Redirect>` only |
| `plans_path` | routes.rb:664 | `/plans` | — |
| `api_v1_me_path` | routes.rb:93 | `/api/v1/me` | SPA bootstrap XHR |
| `rails_direct_uploads_path` | Rails default | `/rails/active_storage/direct_uploads` | not used by the hire SPA (see §6) |
| `invites_accept_path` | routes.rb:58 | `/invites/accept` | invite emails |
| `Variables::AtsRootUrl` | `config/initializers/01_variables.rb:19` | full origin of the app host | absolute redirects in billing/oauth/omniauth controllers |

**Dead route found:** `post '/billing/create_customer_portal_session', to: 'stripe_customer_portal#create'` (routes.rb:575) points at `Hire::StripeCustomerPortalController`, which does not exist anywhere in the repo (`grep -rn "StripeCustomerPortal\|stripe_customer_portal" app/ config/ spec/` returns only that routes.rb line). Not load-bearing for this feature; noted so nobody treats it as a hire code path.

---

## 2. Controller inheritance tree

> Superseded in detail by **§10 Base controller inheritance map**, which enumerates every base class, every concern, and all 538 routes. This section keeps the hire-path summary.

Every app controller descends from `ApplicationController < ActionController::Base` (`app/controllers/application_controller.rb:3`) — with four exceptions found in §10.1: `Api::V1::Integrations::ZapierIntegrationsController`, `Cypress::CleanupController`, and the two ActiveStorage direct-upload subclasses. There is **no shared concern/module included by several controllers** — `app/controllers/concerns/` contains only `role_fit_filterable.rb` (used by API job-application filtering) and an `api_public/` subdirectory. `ApplicationController` includes exactly one module: `Pundit` (application_controller.rb:6).

Per-area base controllers exist and each is a thin subclass:

```
ActionController::Base
└── ApplicationController                        app/controllers/application_controller.rb:3
    ├── Hire::BaseController                     app/controllers/hire/base_controller.rb:3
    │   ├── Hire::PagesController                app/controllers/hire/pages_controller.rb:3
    │   ├── Hire::RedirectorController           app/controllers/hire/redirector_controller.rb:3
    │   ├── Hire::ConfirmationsController        app/controllers/hire/confirmations_controller.rb:3
    │   └── Hire::ErrorsController               app/controllers/hire/errors_controller.rb:3
    ├── Hire::Integrations::OauthAuthenticationsController   app/controllers/hire/integrations/oauth_authentications_controller.rb:3
    │       (NOTE: inherits ApplicationController directly, NOT Hire::BaseController)
    ├── Account::BaseController                  app/controllers/account/base_controller.rb:3   (layout 'account_application')
    │   └── Account::PagesController             app/controllers/account/pages_controller.rb:3
    ├── Connect::BaseController                  app/controllers/connect/base_controller.rb:3   (layout 'connect_application')
    │   └── Connect::PagesController             app/controllers/connect/pages_controller.rb:3
    ├── Api::V1::BaseController                  app/controllers/api/v1/base_controller.rb:3
    │   ├── (all ~50 Api::V1::* controllers)
    │   ├── Api::V1::Public::*                   (each does skip_before_action :authenticate_api_v1_user!)
    │   └── Api::V1::IndividualApp::BaseController
    ├── ApiPublic::V1::Hire::BaseController      app/controllers/api_public/v1/hire/base_controller.rb:3
    ├── Admin::BaseController                    app/controllers/admin/base_controller.rb:3
    ├── MagicLinksController                     app/controllers/magic_links_controller.rb:3
    ├── JobBoard::BaseController                 app/controllers/job_board/base_controller.rb
    ├── IndividualApp::*                         app/controllers/individual_app/
    ├── Cypress::*                               app/controllers/cypress/    (test env only, routes.rb:8-11 via lib/test_routes.rb)
    └── DeviseController                         gems/devise-4.8.1 (config.parent_controller default = 'ApplicationController')
        ├── Devise::RegistrationsController → Auth::InvitesController      app/controllers/auth/invites_controller.rb:3
        ├── Devise::SessionsController      → Api::V1::SessionsController  app/controllers/api/v1/sessions_controller.rb:3
        └── Devise::OmniauthCallbacksController → Api::V1::Users::OmniauthCallbacksController
```

Outside the `ApplicationController` tree entirely:

```
ActionController::Base
└── ActiveStorage::BaseController               gems/activestorage-6.1.7.7/app/controllers/active_storage/base_controller.rb
    └── ActiveStorage::DirectUploadsController
        └── Api::V1::Public::DirectUploadsController   app/controllers/api/v1/public/direct_uploads_controller.rb:3
        └── ApiPublic::V1::Hire::DirectUploadsController

ActionCable::Connection::Base
└── ApplicationCable::Connection                app/channels/application_cable/connection.rb:4
```

**The authenticated hire page load chain is:** `Hire::PagesController < Hire::BaseController < ApplicationController < ActionController::Base`.

`Hire::BaseController` (hire/base_controller.rb:3-5) declares **no layout**, so it uses `app/views/layouts/application.html.erb`. Its entire body is `skip_before_action :track_ahoy_visit`.

---

## 3. Callback chain, in execution order

Order below is the actual `Hire::PagesController._process_action_callbacks` sequence.

| # | Kind | Filter | Declared at | What it does / halts? |
|---|---|---|---|---|
| 0 | before | (block) | `gems/sentry-rails-4.8.0/lib/sentry/rails/controller_transaction.rb:5` | Names the Sentry transaction `#{controller}#{action}`. Never halts. |
| 1 | before | `set_ahoy_cookies` | `gems/ahoy_matey-4.0.1/lib/ahoy/controller.rb:8` (registered onto `ActionController::Base` by `ahoy.rb:117`), `unless: -> { Ahoy.api_only }` | `Ahoy.cookies == false` (`config/initializers/ahoy.rb:10`), so it takes the `else` branch → `ahoy.reset` → deletes cookies `ahoy_visitor`, `ahoy_visit`, `ahoy_events`, `ahoy_track` (`gems/ahoy_matey-4.0.1/lib/ahoy/tracker.rb:137-146`). **This is a response-header-modifying before_action that runs on every request in the app.** Never halts. |
| 2 | around | `set_ahoy_request_store` | `gems/ahoy_matey-4.0.1/lib/ahoy/controller.rb:10` | Sets/restores `Thread.current[:ahoy]`. Never halts. |
| 3 | before | `reset_tophat` | `gems/tophat-2.3.1/lib/tophat/reset.rb:5` (`append_before_action`) | `TopHat.reset` — clears meta-tag thread state. Never halts. |
| 4 | around | (block) | `gems/actiontext-6.1.7.7/lib/action_text/engine.rb:58` | `ActionText::Content.with_renderer(self) { yield }`. Never halts. |
| 5 | before | `verify_authenticity_token` | `ApplicationController` line 8 `protect_from_forgery with: :null_session` | With `:null_session` a bad token nulls the session rather than raising. GET requests are exempt. |
| 6 | after | `verify_same_origin_request` | same `protect_from_forgery` call | Rails' XHR-origin check on JS responses. The **only** `after_action` in the whole chain. |
| 7 | before | `redirect_if_authed` | `app/controllers/hire/pages_controller.rb:4`, `except: %i[root]` | **The only app-authored callback in a hire page load, and the only one that redirects.** See §4. |

`track_ahoy_visit` (`gems/ahoy_matey-4.0.1/lib/ahoy/controller.rb:9`) is registered on `ActionController::Base` for every controller but is **skipped** by `Hire::BaseController:4`, `Account::BaseController:5`, `Connect::BaseController:5`, `Api::V1::BaseController:5`, `Admin::BaseController:4`. It still runs for `MagicLinksController`, `Auth::InvitesController`, `Hire::Integrations::OauthAuthenticationsController`, `ApiPublic::V1::Hire::*`, `ActiveStorage::*` and the Devise controllers. With `Ahoy.cookies=false` and `Ahoy.server_side_visits=true` it performs a DB visit lookup/insert.

### Where `authenticate_user!` lives

There is **no `authenticate_user!`** in this app — the Devise mapping is `:api_v1_user` (see §8), so the generated filter is `authenticate_api_v1_user!` (`gems/devise-4.8.1/lib/devise/controllers/helpers.rb:112-132`).

Declared in exactly two places:
- `app/controllers/api/v1/base_controller.rb:6` — `before_action :authenticate_api_v1_user!` (no options). Individual controllers opt out: `api/v1/users_controller.rb:5` (`only: [:ping]`), `api/v1/invites_controller.rb:5` (`only: [:show]`), and every `api/v1/public/*` controller.
- `app/controllers/hire/integrations/oauth_authentications_controller.rb:4` — `before_action :authenticate_api_v1_user!` (no options).

`Hire::PagesController` has **no** `authenticate_api_v1_user!`. `pages#root` renders the SPA shell for signed-out visitors too; the auth gate is entirely client-side (§5).

### Api::V1::BaseController order (relevant for a hook there)

```
0 before  sentry ControllerTransaction block
1 before  set_ahoy_cookies
2 around  set_ahoy_request_store
3 before  reset_tophat
4 around  actiontext block
5 after   verify_same_origin_request
6 before  authenticate_api_v1_user!      app/controllers/api/v1/base_controller.rb:6
7 before  set_sentry_context             app/controllers/api/v1/base_controller.rb:7
```

`verify_authenticity_token` is absent (skipped at `api/v1/base_controller.rb:4`). A `before_action` appended in `Api::V1::BaseController` lands after `set_sentry_context`, i.e. after authentication has already succeeded.

---

## 4. Every redirect that can hit a signed-in hire user

### 4a. Router-level redirects — these never reach a controller

`ActionDispatch::Routing::Redirect` responses are generated by the router itself. **No `before_action`/`after_action` anywhere can attach a cookie to these responses.** All 13 that exist in a normal boot are **301** (verified by enumerating `Rails.application.routes.routes` and reading `app.app.status` on each `ActionDispatch::Routing::Redirect`; `redirect()` defaults to 301).

| routes.rb | Condition | From | To | Different host? |
|---|---|---|---|---|
| 14-22 | `ENV['REDIRECT_TO_XYZ'] == 'enabled'` and `domain == 'wrkhq.com'` | any path on `*.wrkhq.com` | `https://<subdomain>polymer.co/<path>` (explicit 301) | **Yes** |
| 32-48 | `ENV['REDIRECT_TO_POLYMER'] == 'enabled'` and `domain == 'wrk.xyz'` and path not `/api/v1/public` | any path on `*.wrk.xyz` | `https://<app-ified subdomain>.polymer.co/<path>` (explicit 301); `hire*` → `app*` | **Yes** |
| 547 | always | `/account/organization` | `/hire/settings/organization` | No |
| 548 | always | `/account/team` | `/hire/settings/team` | No |
| 549 | always | `/account/message_templates` | `/hire/settings/message_templates` | No |
| 550 | always | `/account/review_templates` | `/hire/settings/review_templates` | No |
| 551-552 | always | `/account/jobboard`, `/account/jobboard/:jobboard_section` | `/hire/settings/jobboard[/…]` | No |
| 553 | always | `/account/categories` | `/hire/settings/categories` | No |
| 554-555 | always | `/account/integrations[/:integration]` | `/hire/settings/integrations[/…]` | No |
| 556 | always | `/account/billing` | `/hire/settings/billing` | No |
| 606 | always | `/admin` | `/admin/dashboard` | No |
| 631 | always | `/jobs/:job_id/stages/:stage_id/candidates` | `/jobs/%{job_id}/stages/%{stage_id}/applicants` | No |
| 704 | always | `/` on `jobs.*` | `https://polymer.co` | **Yes** |

Also router-level and controller-free: `config/application.rb:56-59` inserts `Rack::Rewrite` before `Rack::Runtime` with one rule, `r302 %r{^/sitemap.xml.gz}` → S3.

### 4b. Controller-issued redirects reachable by a signed-in hire user

| # | Where | Condition | From | To | Host change |
|---|---|---|---|---|---|
| R1 | `app/controllers/hire/pages_controller.rb:24-31` | `api_v1_user_signed_in? && !params.key?(:invite_token)` | `/auth`, `/auth-register`, `/login`, `/register`, `/password-reset`, `/request-password-reset`, `/verify-email` (every `Hire::PagesController` action **except** `root`, per line 4 `except: %i[root]`) | `app_root_path` = `/` (302). **All query params are dropped** — `email_confirmed=true`, `error=…`, `magic=…` are lost | No |
| R1b | `app/controllers/hire/pages_controller.rb:29` | signed **out**, on the same actions | — | Renders `hire/pages/root` inline (no redirect). So `/login`, `/register` etc. all serve the same SPA shell | — |
| R2 | `app/controllers/hire/redirector_controller.rb:13` | `/jobs/:job_id/stages/:stage_id/candidates/:candidate_id[/:application_view]` (routes.rb:629-630) with both IDs present | that path | `/jobs/<job_id>/stages/<hiring_stage_id>/applicants/<job_application_id>[/view]` **301 moved_permanently** | No |
| R3 | `app/controllers/hire/redirector_controller.rb:15,18,33` | missing/invalid IDs | same | `/jobs` (302) | No |
| R4 | `app/controllers/hire/redirector_controller.rb:27` | `/applicants/:job_application_hash_id(/:nested_link)` (routes.rb:643) resolves | that path | `@job_application.application_url` + optional nested link | No |
| R5 | `app/controllers/hire/redirector_controller.rb:30` | hash_id not found (also fires `Sentry.capture_message`) | same | `/jobs` | No |
| R6 | `app/controllers/hire/confirmations_controller.rb:18` | `GET /email_confirmation?confirmation_token=…` (routes.rb:577) succeeds | `/email_confirmation` | `/auth?email_confirmed=true` | No |
| R7 | `app/controllers/hire/confirmations_controller.rb:21` | confirm fails | `/email_confirmation` | `/auth?email_confirmed=false` | No |
| R8 | `app/controllers/hire/integrations/oauth_authentications_controller.rb:66` | signed-in (line 4 `authenticate_api_v1_user!`), org present, OAuth callback OK (routes.rb:582) | `/auth/:provider/callback` | `#{Variables::AtsRootUrl}/account/integrations/:provider?oauth_success=true` — absolute URL, same host in practice | No (absolute URL) |
| R9 | `.../oauth_authentications_controller.rb:71` | org missing | same | `…?oauth_success=false` | No |
| R10 | `.../oauth_authentications_controller.rb:84` | `/auth/failure` (routes.rb:583) | `/auth/failure` | `…?oauth_success=false&message=…` | No |
| R11 | `app/controllers/connect/pages_controller.rb:5` | signed-in user whose `current_organization_user.is_admin` is false, hitting `/connect` | `/connect` | `app_root_url` (absolute `https://app.<domain>/`) | No |
| R12 | `app/controllers/magic_links_controller.rb:28` | valid magic-link token at `/magic_links/validate` (routes.rb:55) — **signs the user in first** (line 22) | `/magic_links/validate` | `@magic_link.redirect_to` or `/jobs?magic=not_found` | Depends on stored value |
| R13 | `app/controllers/magic_links_controller.rb:31` | expired/invalid token | same | `session[:connect_user_referrer]` or `/auth?error=expired_link` | Depends |
| R14 | `app/controllers/auth/invites_controller.rb:32` | `/invites/accept` (routes.rb:58) with an already-accepted invite + `job_application` param | `/invites/accept` | `/applicants/:hash_id/reviews/new` | No |
| R15 | `.../invites_controller.rb:34,37` | accepted or invalid token | same | `/auth?invite_token=…&error=could_not_login` / `…&error=invalid_invite` | No |
| R16 | `.../invites_controller.rb:117,119` | user inactive for authentication, or save failed | same | `invite.interviewer_invite_path(...)` / `invite.invite_path` | Per `Invite` model |
| R17 | `.../invites_controller.rb:125,127` | invite accepted, user signed in (line 48 / 76) | same | `/applicants/:hash_id/reviews/new` or `/jobs?invite=accepted` | No |
| R18 | `app/controllers/api/v1/users/omniauth_callbacks_controller.rb:49` | Google SSO callback (routes.rb:128) persists a user; `sign_in(user)` at line 42 | `/api/v1/users/auth/google_oauth2/callback` | `#{Variables::AtsRootUrl}/` | No (absolute) |
| R19 | `.../omniauth_callbacks_controller.rb:57` | SSO failure | same | `#{Variables::AtsRootUrl}/auth?error=authentication_failed` | No (absolute) |
| R20 | `app/controllers/api/v1/billing_controller.rb:457` | signed-in org owner calling `GET /api/v1/billing/continue_change_subscription_portal_session` (routes.rb:178) | that API path | `session.url` — a **Stripe billing-portal URL** | **Yes — billing.stripe.com** |
| R21 | `app/controllers/api/v1/billing_controller.rb:392,397,411,427,463,469` | missing Stripe IDs / validation failure / Stripe error | same | `#{return_url}?error=…`, `return_url` defaults to `#{Variables::AtsRootUrl}/hire/settings/billing` (line 404) | No |
| R22 | `app/controllers/api/v1/registrations_controller.rb:318` | Devise `update` succeeds | `PUT /api/v1/users` | `after_update_path_for(@user)` | Devise default |
| R23 | `app/controllers/admin/base_controller.rb:11` | `verify_current_user_is_admin` fails | `/api/v1/admin/*` | `root_path` — **helper does not exist**, raises `NoMethodError` | n/a |

### 4c. Redirects that do **not** exist for signed-in hire users

- **Onboarding-incomplete, no-organization, unconfirmed-email, deactivated, god-admin gates are all client-side React Router `<Redirect>`s**, not HTTP redirects: `app/javascript/ats/src/views/layouts/AppAuthRouter.tsx:285` (`/needs-email-confirmation`), `:323` (`/onboarding/profile`), `:342` (`/organization/new`), `:357` (`/jobs` for non-god-admin under `/admin/`), `:373` (`/jobs` from an unauthed route), `needsHandleDeactivatedRoute` at `:502`. The Rails request for the original deep link already rendered `hire/pages/root` (200) before any of these fire.
- **Subscription / billing-required / trial-expired / plan-gate:** no Rails redirect exists. `stripeSubscriptionInGoodStanding` is read in `AppAuthRouter.tsx:138-140` and used only for Heap/Intercom properties; gating is per-view in React.
- **Impersonation:** `POST /api/v1/admin/sessions/become` (routes.rb:421-425). It is a JSON API action; no redirect.
- **`after_sign_in_path_for` / `after_sign_out_path_for`** (`app/controllers/application_controller.rb:142-148`, `:134-140`) are effectively dead for the hire user: both fall through to `root_path`, which is not a defined helper (verified — `Rails.application.routes.url_helpers.root_path` raises `NoMethodError`). They are never reached in practice because `Api::V1::SessionsController#create` returns `render json:` from inside the `super` block before `respond_with` (`api/v1/sessions_controller.rb:10-14`), and `#destroy` → Devise `respond_to_on_destroy` picks `format.all { head :no_content }` for `Accept: application/json` (`gems/devise-4.8.1/app/controllers/devise/sessions_controller.rb:77-82`).
- **`store_location` / Devise `failure_app`:** `Devise::FailureApp#respond` (`gems/devise-4.8.1/lib/devise/failure_app.rb:37-43`) chooses `http_auth` when `http_auth?` is true, which for a non-XHR request means `!(request_format && is_navigational_format?)` (`:180-186`). The SPA sends `Accept: application/json` (`app/javascript/shared/queryHooks/api.ts:10,48`), so `request_format` is `:json`, not in `navigational_formats` (`['*/*', :html]`, Devise default — not overridden in `config/initializers/devise.rb:270` which is commented out). Result: **401 JSON, no redirect, no `store_location!`**. The SPA turns that into a client-side `window.location.href = "#{window.APP_ATS_ROOT_URL}/logout?path=…"` (`app/javascript/shared/queryHooks/useMe.ts:89`) — a full browser navigation to `/logout`, which is routed to `pages#root` (routes.rb:600).
- **404s:** `config.exceptions_app = routes` (`config/application.rb:78`). An unrouted path on `app.polymer.co` re-enters the router at `/404` → `Hire::ErrorsController#not_found_404` (routes.rb:570, `hire/errors_controller.rb:8-10`), `layout false`.

---

## 5. Where the authenticated hire SPA shell is rendered

**One action: `Hire::PagesController#root`** (`app/controllers/hire/pages_controller.rb:6`, empty body).

- View: `app/views/hire/pages/root.html.erb` — 11 lines, a `<div id="root">` plus a loader.
- Layout: `app/views/layouts/application.html.erb` (default; `Hire::BaseController` sets no `layout`). It emits `javascript_packs_with_chunks_tag 'ats_application'` and `stylesheet_pack_tag 'ats_application'` at lines 95-96, plus the `window.*` config block at lines 73-92, GTM (32-38), Heap (43-49), Stripe.js (65), reCAPTCHA (68), Intercom (109-113).
- Pack: `app/javascript/packs/ats_application.js` → `app/javascript/ats/src/index.js` → `views/layouts/App.tsx` → `AppAuthRouter.tsx`.

**Every authenticated hire deep link routes to that same action.** `routes.rb:598-664` is an explicit enumeration — `get 'jobs/:job_id', to: 'pages#root'` (611), `get 'candidates', to: 'pages#root'` (645), `get 'jobs/:job_id/stages/:stage_id/applicants/:job_application_id', to: 'pages#root'` (640), and ~45 more. Exceptions inside that block that render something else: the six `Hire::PagesController` unauthed actions (590-596), the two `Hire::RedirectorController` actions (629-630, 643), `Hire::ConfirmationsController#show` (577), the three `Hire::ErrorsController` actions (570-572), and the two router-level redirects (606, 631).

**There is no catch-all/wildcard route for hire.** The commented-out `get '*any_other_path', to: "pages#root"` sits at routes.rb:585-587. The only wildcards under `SubdomainAppConstraints` are `get 'hire/settings/*path', to: 'pages#root'` (663), `namespace :account` `get ':path', to: 'pages#root'` (558, single segment only), and `namespace :connect` `get '*path', to: 'pages#root'` (564). A hire URL not on the list 404s through `Hire::ErrorsController`.

`Account::PagesController#root` (`account/pages_controller.rb:4-6`) and `Connect::PagesController#root` (`connect/pages_controller.rb:4-8`) render their own shells with their own layouts (`account_application`, `connect_application`) and their own packs.

---

## 6. Non-HTML authenticated requests

| Family | Entry | Base class | Fires an `ApplicationController` callback? |
|---|---|---|---|
| SPA XHR/JSON — `/api/v1/*` | `app/javascript/shared/queryHooks/api.ts:6` (`apiGet`) and `:41` (`apiMutate`), relative same-origin axios calls | `Api::V1::BaseController < ApplicationController` (`api/v1/base_controller.rb:3`) | **Yes** |
| Public API — `api.polymer.co/v1/hire/*` | routes.rb:474-534, API-key auth | `ApiPublic::V1::Hire::BaseController < ApplicationController` (`api_public/v1/hire/base_controller.rb:3`) | **Yes** |
| Unauthenticated public JSON — `/api/v1/public/*` | routes.rb:345-380 | `Api::V1::Public::* < Api::V1::BaseController < ApplicationController`, each with `skip_before_action :authenticate_api_v1_user!` | **Yes** |
| Admin JSON — `/api/v1/admin/*` | routes.rb:385-426 | `Admin::BaseController < ApplicationController` (`admin/base_controller.rb:3`) | **Yes** |
| **ActionCable / websocket** — `/cable` | `app/javascript/ats/src/websockets/WebsocketContext.tsx:11` → `ActionCable.createConsumer("${window.APP_ATS_ROOT_URL}/cable")`; mount path confirmed `"/cable"` (`Rails.application.config.action_cable.mount_path`), mounted by `ActionCable::Engine`, not by routes.rb | `ApplicationCable::Connection < ActionCable::Connection::Base` (`app/channels/application_cable/connection.rb:4`). Authenticates via `env['warden'].user('api_v1_user')` (`:14`) | **No** — different superclass, no `_process_action_callbacks`. Also: the WebSocket handshake response cannot usefully carry a `Set-Cookie` for the SPA's purposes. |
| **ActiveStorage direct upload** — `/api/v1/public/rails/active_storage/direct_uploads` | `app/javascript/ats/src/components/DragAndDropResumeUploader.tsx:68` and `components/forms/FormUploader.tsx` | `Api::V1::Public::DirectUploadsController < ActiveStorage::DirectUploadsController < ActiveStorage::BaseController < ActionController::Base` (`api/v1/public/direct_uploads_controller.rb:3`) | **No** |
| ActiveStorage blob/disk serving — `/rails/active_storage/*` | Rails default routes | `ActiveStorage::{DiskController, Blobs::RedirectController,…} < ActiveStorage::BaseController < ActionController::Base` | **No** |
| Health check | none exists in routes.rb. Closest is `GET /api/v1/users/ping` (routes.rb:216) which does `skip_before_action :authenticate_api_v1_user!, only: [:ping]` (`api/v1/users_controller.rb:5`) | `Api::V1::UsersController < Api::V1::BaseController` | Yes, but unauthenticated |
| Static assets / webpack bundles | `ActionDispatch::Static` (production `config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?`, production.rb:27) and `Webpacker::DevServerProxy` in development | none — served from middleware | **No** |
| Sidekiq Web — `/sidekiq` | routes.rb:62-64, `authenticate :user, ->(u) { u&.email && AdminUser.exists?(email: u.email) }` | Sinatra app mounted in the router | **No**. Note the warden scope requested is `:user`, and `Devise.mappings.keys == [:api_v1_user, :admin_user, :individual]` — there is no `:user` mapping. Whether this route can ever match, I could not determine from code alone. |

One more `/api/v1/*` outlier, found in the §10 sweep: **`Api::V1::Integrations::ZapierIntegrationsController` inherits `ActionController::Base` directly** (`app/controllers/api/v1/integrations/zapier_integrations_controller.rb:3`), so its three routes (routes.rb:459-465) bypass `ApplicationController` despite the `/api/v1/` path. Same for `Cypress::CleanupController` (`cypress/cleanup_controller.rb:3`, test env only) and `Griddler::EmailsController` (gem, `POST /email_processor`).

**Summary for the hook decision:** a `before_action`/`after_action` on `ApplicationController` fires for the hire SPA shell **and** all `/api/v1/*` XHR. It does **not** fire for `/cable`, for ActiveStorage upload/serve (including the SPA's own resume uploader), for the Zapier integration endpoints, for static assets, or for router-level redirects. See §10.4 for the full per-base-class coverage table.

---

## 7. Response-modifying middleware / caching

Middleware stack, from `bundle exec rails middleware` in this worktree (development):

```
Webpacker::DevServerProxy            (development only)
Rack::Cors                           config/application.rb:88-97
ActionDispatch::HostAuthorization
Rack::Sendfile
ActionDispatch::Static
ActionDispatch::Executor
Rack::Rewrite                        config/application.rb:56-59
ActiveSupport::Cache::Strategy::LocalCache::Middleware
Rack::Runtime
Rack::MethodOverride
ActionDispatch::RequestId
ActionDispatch::RemoteIp
Sprockets::Rails::QuietAssets
Rails::Rack::Logger
ActionDispatch::ShowExceptions
Sentry::Rails::CaptureExceptions
WebConsole::Middleware               (development only)
ActionDispatch::DebugExceptions
Sentry::Rails::RescuedExceptionInterceptor
ActionDispatch::ActionableExceptions
ActionDispatch::Reloader             (development only; skipped when cache_classes)
ActionDispatch::Callbacks
ActiveRecord::Migration::CheckPending (development only)
ActionDispatch::Cookies
ActionDispatch::Session::CookieStore
ActionDispatch::Flash
ActionDispatch::ContentSecurityPolicy::Middleware
ActionDispatch::PermissionsPolicy::Middleware
Rack::Head
Rack::ConditionalGet
Rack::ETag
Rack::TempfileReaper
Warden::Manager
Bullet::Rack                         (development only)
OmniAuth::Builder
Flipper::Middleware::Memoizer
Rack::Attack                         config/initializers/rack_attack.rb
ScoutApm::Middleware
ScoutApm::Instant::Middleware
run InflowATS::Application.routes
```

### Things that touch responses / headers / cookies / sessions

- **`config.middleware.insert_before(Rack::Runtime, Rack::Rewrite)`** — `config/application.rb:56-59`. One rule: 302 `^/sitemap.xml.gz` to S3. Irrelevant to authenticated hire responses.
- **`config.middleware.insert_before 0, Rack::Cors`** — `config/application.rb:88-97`. `origins '*'` but scoped to three resources: `/v1/hire/*` (GET), `/api/v1/public/*` (GET/PUT/POST), `/rails/active_storage/disk/*`. **`/api/v1/*` (non-public) and the hire HTML routes are not CORS-exposed**, so cross-origin JS on `www.polymer.co` cannot read them.
- **Session store** — no `config/initializers/session_store.rb` exists and no `config.session_store` call anywhere in `config/` (`grep -rn "session_store" config/` returns nothing). Rails' fallback applies: `gems/railties-6.1.7.7/lib/rails/application/finisher.rb:99-105` → `config.session_store :cookie_store, key: "_#{app_name}_session"`. Verified live: `Rails.application.config.session_options == {key: "_inflow_ats_session", cookie_only: true}` and `config.session_store == ActionDispatch::Session::CookieStore`. **No `:domain` and no `:secure` in session options** — the session cookie is host-only on `app.polymer.co`.
- **`config.action_dispatch.cookies_serializer = :json`** — `config/initializers/cookies_serializer.rb:7`. `use_cookies_with_metadata` is left commented out (`config/initializers/new_framework_defaults_6_0.rb:19`), so signed/encrypted cookies carry no purpose metadata.
- **`config.force_ssl = true`** — `config/environments/production.rb:56`, with `config.ssl_options == {hsts: {subdomains: true}}` (Rails default; verified live). This inserts `ActionDispatch::SSL` at the top of the production stack (`gems/railties-6.1.7.7/lib/rails/application/default_middleware_stack.rb:18-21`). Because `secure_cookies:` defaults to `true` (`gems/actionpack-6.1.7.7/lib/action_dispatch/middleware/ssl.rb:61`), **every `Set-Cookie` header on every production response gets `; secure` appended** (`ssl.rb:79`, `:114-126`). Any cookie this feature sets will be secure-only in production whether or not the code asks for it, and HSTS is emitted with `includeSubDomains`.
- **`ActionDispatch::Cookies` → `Session::CookieStore` → `Warden::Manager` ordering** — Warden sits *after* the cookie jar in the stack, so `cookies[…] = …` from a controller is written into the same jar Devise uses. No ordering hazard.
- **Ahoy** issues cookie *deletions* on every request via `set_ahoy_cookies` (§3 row 1). `Ahoy.cookie_domain` is a real gem setting (`gems/ahoy_matey-4.0.1/lib/ahoy.rb:34`) but is left `nil` here — `config/initializers/ahoy.rb` sets only `mask_ips` and `cookies`.
- **`Rack::Attack`** — `config/initializers/rack_attack.rb`. Blocklisted responses are `[404, {}, ['']]` (lines 108-111 and again 118-121), produced *before* the router. `Rack::Attack.enabled = Variables::RACK_ATTACK_ENABLED` (last line). `APP_HOSTNAME_LIST` (lines 15-24) exempts the app/api hostnames from the job-board allow2ban rule.
- **`ActionDispatch::ContentSecurityPolicy::Middleware`** is present but the whole policy in `config/initializers/content_security_policy.rb` is commented out (lines 9-32), so no CSP header is emitted.
- **`Rack::ETag` + `Rack::ConditionalGet`** — `gems/rack-2.2.9/lib/rack/etag.rb`. For a 200 HTML response with no `Cache-Control`, it computes a weak ETag and sets `Cache-Control: max-age=0, private, must-revalidate` (`etag.rb:18`, `:40-46`). `private` is the key word.

### Is any authenticated hire HTML response HTTP-cached? — **No.** Evidence:

1. **No `Rack::Cache`.** Rails inserts it only when `config.action_dispatch.rack_cache` is truthy (`default_middleware_stack.rb:31-34`, `:84-94`). `grep -rn "rack_cache\|Rack::Cache" config/ app/ Gemfile` returns nothing, and `Rack::Cache` is absent from the printed middleware stack. `rack-cache` is not in the `Gemfile`.
2. **No action/page caching and no explicit HTTP freshness anywhere.** `grep -rn "expires_in\|fresh_when\|stale?\|http_cache_forever\|Cache-Control\|cache_control\|caches_action\|caches_page\|etag" app/controllers/ config/` returns exactly three hits, all `config.public_file_server.headers` for static files: `config/environments/development.rb:29` (`public, max-age=172800`) and `config/environments/test.rb:22` (`public, max-age=3600`). **Production sets no `public_file_server.headers` at all** (production.rb:27 only toggles `enabled`), and in any case that middleware serves files from `public/`, never a controller response.
3. **`Rack::ETag` marks uncached responses `private`** (`gems/rack-2.2.9/lib/rack/etag.rb:18`), which forbids shared/proxy caching of the SPA shell.
4. **Rails-level caching is fragment caching only.** `config.action_controller.perform_caching = true` (production.rb:19) enables `cache` view helpers; `app/views/hire/pages/root.html.erb` and `app/views/layouts/application.html.erb` contain no `cache` blocks. `Set-Cookie` headers are not part of a fragment cache entry regardless.
5. **No CDN or asset host in code.** `config.action_controller.asset_host` is commented out (production.rb:40). The only Cloudflare code in the repo is careers-page **custom hostname** provisioning: `app/services/cloudflare_client.rb`, `app/models/careers_page.rb:130-141`, `app/interactors/create_custom_domain.rb`, `app/interactors/delete_custom_domain.rb`, and `Variables::CUSTOM_DOMAIN_CNAME_TARGET` / `CLOUDFLARE_AUTH_TOKEN` (`config/initializers/01_variables.rb:113-114`). None of it touches `app.polymer.co`.

**Caveat, stated explicitly:** this rules out caching *configured in this repository*. Whether a proxy/CDN sits in front of `app.polymer.co` at the DNS/Heroku/Cloudflare-dashboard level is **not determinable from code** — I looked at `config/environments/production.rb`, all of `config/initializers/`, `config/application.rb`, `Procfile`, `app.json`, and `release-tasks.sh` and found no CDN configuration. Given `Rack::ETag`'s `private` directive on every uncached 200, a conformant shared cache would not store the response anyway.

---

## 8. Devise configuration

`config/initializers/devise.rb`:

| Setting | Line | Value |
|---|---|---|
| `config.remember_for` | 171 | **`2.years`** |
| `config.expire_all_remember_me_on_sign_out` | 174 | `true` |
| `config.extend_remember_period` | 177 | commented out → `false` |
| `config.rememberable_options` | 181 | **commented out → `{}`** (verified live: `Devise.rememberable_options == {}`) |
| `config.skip_session_storage` | 110 | `[:http_auth]` |
| `config.reconfirmable` | 164 | `true` |
| `config.sign_out_via` | 273 | `:delete` |
| `config.navigational_formats` | 270 | commented out → Devise default `['*/*', :html]` |
| `config.warden do …` | 284-287 | commented out → **no custom failure app, no custom strategies** |
| `config.parent_controller` | 33 | commented out → `'ApplicationController'` |

**Is `rememberable` enabled?** Yes. `app/models/user.rb:24-25`: `devise :database_authenticatable, :registerable, :confirmable, :recoverable, :rememberable, :trackable, :validatable`. Verified live: `User.devise_modules == [:database_authenticatable, :rememberable, :recoverable, :registerable, :validatable, :confirmable, :trackable]`.

**Remember-me cookie:** name is `remember_#{scope}_token` (`gems/devise-4.8.1/lib/devise/controllers/rememberable.rb:52`) → **`remember_api_v1_user_token`**. Its options come from `Devise::Controllers::Rememberable.cookie_values` = `Rails.configuration.session_options.slice(:path, :domain, :secure)` (`rememberable.rb:11`), which for this app is **`{}`** — no domain, no path, no secure — merged with `{httponly: true}` and `expires: resource.remember_expires_at` (`rememberable.rb:42-49`). So: host-only on `app.polymer.co`, HttpOnly, 2-year expiry, `; secure` appended in production by `ActionDispatch::SSL`. It is set from the warden `after_set_user` hook when `remember_me` is truthy; the app assigns `remember_me: true` explicitly at `app/controllers/magic_links_controller.rb:20` and `app/controllers/auth/invites_controller.rb:46`.

**Session cookie:** `_inflow_ats_session`, `cookie_only: true`, no domain, no explicit expiry (browser-session), `; secure` in production. See §7.

**`User#active_for_authentication?`** — `app/models/user.rb:134-138`:

```ruby
def active_for_authentication?
  super || organization.nil? #  && (self.current_membership_is_active || !self.belongs_to_organization?)
end
```

`super` is Devise's `:confirmable` check (`confirmed? || confirmation_period_valid?`). The `|| organization.nil?` override means **a freshly-signed-up, unconfirmed user with no organization is fully authenticated**. Consequence for this feature: a signed-in-but-unconfirmed user hitting `/auth?email_confirmed=true` is bounced by `redirect_if_authed` (R1) before `Auth.tsx` renders — the query param never reaches React.

**Devise scopes/mappings** — three, verified live (`Devise.mappings.keys`):

| Mapping | Class | Declared |
|---|---|---|
| `:api_v1_user` | `User` | `devise_for :users` inside `namespace :api { namespace :v1 { … } }`, routes.rb:123-126 |
| `:admin_user` | `AdminUser` | `devise_for :admin_users`, routes.rb:536 |
| `:individual` | `Individual` | `devise_for :individuals` inside `SubdomainIndividualConstraints`, routes.rb:681 |

**There is no `:user` mapping.** Two places reference one anyway: `routes.rb:62` (`authenticate :user, …` guarding `/sidekiq`) and `app/controllers/api/v1/users/omniauth_callbacks_controller.rb:5` (`request.env["devise.mapping"] = Devise.mappings[:user]`, which assigns `nil`). Both are pre-existing and outside this feature's scope; flagged only so nobody copies `:user` into new code. The generated helpers you must use are `current_api_v1_user`, `api_v1_user_signed_in?`, `authenticate_api_v1_user!` (`gems/devise-4.8.1/lib/devise/controllers/helpers.rb:112-132`). `Api::V1::BaseController:9` and `Connect::BaseController:7` both do `alias current_user current_api_v1_user`; **`Hire::BaseController` does not**, so inside a hire page controller `current_user` is undefined and only `current_api_v1_user` / `api_v1_user_signed_in?` work.

---

## 9. Existing analogs for per-request work on authenticated loads

There are **five** in-repo analogs (plus three gem-installed ones for reference). Fewer than three are on the hire HTML path specifically — stated explicitly below.

**In-repo, app-authored:**

1. **`Api::V1::BaseController#set_sentry_context`** — declared `before_action :set_sentry_context` at `app/controllers/api/v1/base_controller.rb:7`, defined at `:33-46`. Guarded `return unless current_user`, then `Sentry.set_user(id:, email:)`. This is the closest structural match to "do one small thing per authenticated request, after authentication, on every API call."
2. **`Admin::BaseController#set_sentry_context`** — `before_action :set_sentry_context` at `app/controllers/admin/base_controller.rb:6`; same shape, plus `before_action :verify_current_user_is_admin` at `:5` (which redirects at `:11`).
3. **`Account::PagesController#root`** — `app/controllers/account/pages_controller.rb:5`: `cookies[:account_referrer] = request.referrer`. **The only precedent in the codebase for writing a plain cookie from a page-shell action.** Note it is in the action body, not a callback, and it has no `domain`/`expires`/`httponly` options — a bare host-only session cookie.
4. **`Connect::PagesController#root`** — `app/controllers/connect/pages_controller.rb:7`: `cookies[:connect_referrer] = request.referrer`, after a `redirect_to app_root_url and return unless current_organization_user.is_admin` guard at `:5`. Same shape as #3.
5. **Frontend per-load identify block** — `app/javascript/ats/src/views/layouts/AppAuthRouter.tsx`: Heap `window.heap.identify(currentUser?.hashId)` + `addUserProperties` in a `useEffect` keyed on `[currentUser, organizationId]` (`:146-161`); PostHog `identifyUser({id, email, organizationId, organizationName, plan, organizationUserRole})` in a `useEffect` (`:166-177`, implementation at `app/javascript/shared/lib/posthog.ts:17-38`); Google Analytics pageview on location change (`:180-184`); Intercom `boot` with user attributes (`:187-197`). This is the existing "identify the signed-in user to a third party once per authenticated load" pattern — it runs client-side, after `useGetMe` resolves.

**Gem-installed, for reference (they establish that per-request callbacks on `ActionController::Base` are normal here):** the sentry-rails transaction-naming `before_action` (`gems/sentry-rails-4.8.0/lib/sentry/rails/controller_transaction.rb:5`), ahoy's `set_ahoy_cookies` / `track_ahoy_visit` / `set_ahoy_request_store` (`gems/ahoy_matey-4.0.1/lib/ahoy/controller.rb:8-10`), and tophat's `reset_tophat` (`gems/tophat-2.3.1/lib/tophat/reset.rb:5`).

**Explicitly absent:** there is **no app-authored `after_action` anywhere in `app/controllers/`** (`grep -rn "^\s*after_action" app/controllers/` returns nothing). The only `after_action` in any chain is Rails' own `verify_same_origin_request`. There is no last-seen-timestamp update, no `current_user.touch`, no feature-flag-per-request hook (Flipper is memoized by middleware, `Flipper::Middleware::Memoizer`), and no server-side PostHog call on page load — `PosthogIdentifyJob` / `PosthogTrackJob` are enqueued only at sign-in/sign-up moments (`app/controllers/api/v1/sessions_controller.rb:10-11`, `app/controllers/magic_links_controller.rb:23-24`, `app/controllers/auth/invites_controller.rb:49-50` and `:79-84`, `app/controllers/api/v1/users/omniauth_callbacks_controller.rb:43-47`). Devise `:trackable` (`app/models/user.rb:25`) updates `sign_in_count` / `last_sign_in_at` on the warden sign-in hook, not per request.

---

## Base controller inheritance map

Scope addition from the repo owner: `config/routes.rb` holds **both** the JSON routes the React SPA calls for data **and** the HTML page routes, and both families hit base controller classes. This section maps that completely.

Method: the class inventory comes from `grep -rn "^class " app/controllers/` (every declaration, no sampling). The route classification comes from enumerating all `Rails.application.routes.routes` in a booted app — **538 routes** — resolving each route's `defaults[:controller]` to a constant and printing its full superclass chain plus its resolved `_process_action_callbacks`. Nothing below is inferred from a filename.

### 10.1 Every base/parent controller class

There are **eleven** in-repo base classes plus five framework/gem base classes that app routes land on.

#### In-repo

| # | Class | File | Inherits | Includes | Callbacks it declares |
|---|---|---|---|---|---|
| 1 | `ApplicationController` | `app/controllers/application_controller.rb:3` | `ActionController::Base` | `Pundit` (`:6`) — the only module | `protect_from_forgery with: :null_session` (`:8`) → registers `before_action :verify_authenticity_token` + `after_action :verify_same_origin_request`. Also `rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized` (`:10`) and `serialization_scope :current_user` (`:11`). **No `before_action` of its own.** Defines render helpers (`render_paginated`, `render_one`, `render_each`, …) and private `after_sign_in_path_for` / `after_sign_out_path_for` (`:134-148`). The commented-out `set_sentry_context` at `:158-171` and `redirect_app_to_hire` at `:13` are dead. |
| 2 | `Hire::BaseController` | `app/controllers/hire/base_controller.rb:3` | `ApplicationController` | none | `skip_before_action :track_ahoy_visit` (`:4`). Nothing else — 5 lines total. No `layout`, so the default `application` layout applies. |
| 3 | `Account::BaseController` | `app/controllers/account/base_controller.rb:3` | `ApplicationController` | none | `layout 'account_application'` (`:4`), `skip_before_action :track_ahoy_visit` (`:5`). |
| 4 | `Connect::BaseController` | `app/controllers/connect/base_controller.rb:3` | `ApplicationController` | none | `layout 'connect_application'` (`:4`), `skip_before_action :track_ahoy_visit` (`:5`). Also `alias current_user current_api_v1_user` (`:7`) and `#current_organization_user` (`:9-11`). |
| 5 | `Api::V1::BaseController` | `app/controllers/api/v1/base_controller.rb:3` | `ApplicationController` | none | `skip_before_action :verify_authenticity_token` (`:4`), `skip_before_action :track_ahoy_visit` (`:5`), **`before_action :authenticate_api_v1_user!` (`:6`)**, `before_action :set_sentry_context` (`:7`), `respond_to :json` (`:11`). `alias current_user current_api_v1_user` (`:9`); `#current_organization` (`:23-25`), `#current_organization_user` (`:27-29`), private `#set_sentry_context` (`:33-46`). |
| 6 | `Api::V1::Admin::BaseController` | `app/controllers/api/v1/admin/base_controller.rb:3` | `Api::V1::BaseController` | none | `before_action :verify_god_admin` (`:4`), which calls `user_not_authorized(nil)` (403 JSON) unless `AdminUser.exists?(email: current_user.email)` (`:12-19`). |
| 7 | `Api::V1::IndividualApp::BaseController` | `app/controllers/api/v1/individual_app/base_controller.rb:3` | `ApplicationController` | none | `skip_before_action :verify_authenticity_token` (`:4`), `before_action :authenticate_api_v1_user!` (`:5`), `respond_to :json` (`:7`). **Note: authenticates the same `:api_v1_user` scope as the hire API — not an `:individual` scope.** |
| 8 | `ApiPublic::V1::Hire::BaseController` | `app/controllers/api_public/v1/hire/base_controller.rb:3` | `ApplicationController` | **`ApiPublic::V1::Hire::HtmlSanitizable`** (`:21`) | `skip_before_action :verify_authenticity_token` (`:4`), `before_action :authenticate_api_key!` (`:5`), `before_action :check_api_access!` (`:6`), `before_action :validate_param_lengths` (`:7`), `respond_to :json` (`:9`). `authenticate_api_key!` (`:57-69`) reads `Authorization: Bearer …`, SHA-256 digests it, looks up `ApiKey`, sets `@current_api_organization` / `@current_api_key_owner`, `touch_last_used`. **No Devise, no `current_user`.** |
| 9 | `Admin::BaseController` | `app/controllers/admin/base_controller.rb:3` | `ApplicationController` | none | `skip_before_action :track_ahoy_visit` (`:4`), `before_action :verify_current_user_is_admin` (`:5`) — `redirect_to root_path unless current_user_is_admin?` (`:11`, and `root_path` is not a defined helper, §4c) — `before_action :set_sentry_context` (`:6`, defined `:20-24`). **No route in `config/routes.rb` targets any subclass of this class** (see 10.3). |
| 10 | `IndividualApp::BaseController` | `app/controllers/individual_app/base_controller.rb:3` | `ApplicationController` | none | `layout "individual_application"` (`:4`). Nothing else — 6 lines. |
| 11 | `JobBoard::BaseController` | `app/controllers/job_board/base_controller.rb:3` | `ApplicationController` | none | `layout 'job_board_application'` (`:4`), **`around_action :switch_locale` (`:5`)** — the only `around_action` declared by app code; it queries `CareersPage` on every request (`:42`) and wraps the action in `I18n.with_locale` (`:48`). Also `#set_organization` (`:7-34`), used as a `before_action` by subclasses. |

#### Framework / gem base classes that app routes land on

| Class | Source | Inherits | Reachable via |
|---|---|---|---|
| `DeviseController` | `gems/devise-4.8.1/app/controllers/devise_controller.rb` | **`ApplicationController`** — `config.parent_controller` is left at its default (`config/initializers/devise.rb:33`, commented out) | `Api::V1::SessionsController`, `Api::V1::RegistrationsController`, `Api::V1::Users::OmniauthCallbacksController`, `Auth::InvitesController`, `Api::V1::Public::UnregisteredJobController`, `ApiPublic::V1::Hire::UnregisteredJobController`, `IndividualApp::ConfirmationsController`, `Admin::SessionsController`, and the bare `Devise::SessionsController` / `Devise::RegistrationsController` mounted by `devise_for :admin_users` |
| `ActiveStorage::BaseController` | `gems/activestorage-6.1.7.7/app/controllers/active_storage/base_controller.rb` | **`ActionController::Base`** — *not* `ApplicationController` | `Api::V1::Public::DirectUploadsController`, `ApiPublic::V1::Hire::DirectUploadsController`, and Rails' own `/rails/active_storage/*` routes |
| `ActionMailbox::BaseController` | `gems/actionmailbox-6.1.7.7` | `ActionController::Base` | the five `/rails/action_mailbox/*/inbound_emails` ingress routes |
| `Rails::ApplicationController` / `Rails::Conductor::BaseController` | railties | `ActionController::Base` | `/rails/info`, `/rails/mailers`, `/rails/conductor/*` (development only) |
| `ActionCable::Connection::Base` | `gems/actioncable-6.1.7.7` | — (not a controller at all) | `ApplicationCable::Connection` |

#### Two more classes that skip every base

- **`Api::V1::Integrations::ZapierIntegrationsController < ActionController::Base`** (`app/controllers/api/v1/integrations/zapier_integrations_controller.rb:3`) — inherits `ActionController::Base` **directly**, bypassing `ApplicationController` entirely, despite living under `/api/v1/`. Serves the three Zapier routes (routes.rb:459-465) with `before_action :authenticate` (`:4`).
- **`Cypress::CleanupController < ActionController::Base`** (`app/controllers/cypress/cleanup_controller.rb:3`) — also direct. The other seven `Cypress::*` controllers do inherit `ApplicationController`. All Cypress routes exist only when `Rails.env.test?` (routes.rb:8-11 → `lib/test_routes.rb`).
- **`Griddler::EmailsController < ActionController::Base`** (gem) — serves `POST /email_processor` (routes.rb:53).

#### ActionCable

```
ActionCable::Connection::Base
└── ApplicationCable::Connection      app/channels/application_cable/connection.rb:4
        identified_by :current_user                          (:5)
        def connect → self.current_user = find_verified_user (:7-9)
        find_verified_user → env['warden'].user('api_v1_user') else reject_unauthorized_connection (:13-19)

ActionCable::Channel::Base
└── ApplicationCable::Channel         app/channels/application_cable/channel.rb:4   (empty, 6 lines)
    ├── BillingChannel                app/channels/billing_channel.rb:3
    ├── GlobalChannel                 app/channels/global_channel.rb:3
    └── JobChannel                    app/channels/job_channel.rb:3
```

Mounted at `/cable` — confirmed via `Rails.application.config.action_cable.mount_path == "/cable"` and present in the enumerated route set as `MOUNTED(ActionCable::Server::Base)`. It is mounted by `ActionCable::Engine`, not by any line in `config/routes.rb`. **It has no `_process_action_callbacks` at all** — `before_action` is not a concept on `ActionCable::Connection::Base`.

### 10.2 Full inheritance tree

```
ActionController::Base
│
├── ApplicationController                                    application_controller.rb:3   [include Pundit]
│   │
│   ├── Hire::BaseController                                 hire/base_controller.rb:3          ← HTML
│   │   ├── Hire::PagesController                            hire/pages_controller.rb:3         (60 routes)
│   │   ├── Hire::RedirectorController                       hire/redirector_controller.rb:3    (3)
│   │   ├── Hire::ConfirmationsController                    hire/confirmations_controller.rb:3 (1)
│   │   └── Hire::ErrorsController                           hire/errors_controller.rb:3        (3)
│   │
│   ├── Hire::Integrations::OauthAuthenticationsController    hire/integrations/oauth_authentications_controller.rb:3   (2)  ← NOT under Hire::BaseController
│   │
│   ├── Account::BaseController                              account/base_controller.rb:3       ← HTML
│   │   └── Account::PagesController                         account/pages_controller.rb:3      (2)
│   │
│   ├── Connect::BaseController                              connect/base_controller.rb:3       ← HTML
│   │   └── Connect::PagesController                         connect/pages_controller.rb:3      (2)
│   │
│   ├── IndividualApp::BaseController                        individual_app/base_controller.rb:3 ← HTML
│   │   └── IndividualApp::PagesController                   individual_app/pages_controller.rb:3 (3)
│   │
│   ├── JobBoard::BaseController                             job_board/base_controller.rb:3     ← HTML
│   │   ├── JobBoard::JobsController                         (8)
│   │   ├── JobBoard::PrivacyController                      (4)
│   │   └── JobBoard::ErrorsController                       (6)
│   │
│   ├── Api::V1::BaseController                              api/v1/base_controller.rb:3        ← JSON, Devise session
│   │   ├── ~50 Api::V1::* controllers  (me, jobs, candidates, job_applications, billing,
│   │   │     organizations, comments, channels, hiring_stages, invites, users, analytics,
│   │   │     organization_ai_credit_*, bulk_*, integrations/*, …)
│   │   ├── Api::V1::Admin::BaseController                   api/v1/admin/base_controller.rb:3
│   │   │   └── Api::V1::Admin::{Dashboard,Jobs,Organizations,Sessions,*Search}Controller
│   │   └── Api::V1::Public::{Candidates,Jobs,Organizations,Webhooks,JobFeeds}Controller
│   │           (each does skip_before_action :authenticate_api_v1_user!)
│   │       └── ApiPublic::V1::Hire::JobsController          api_public/v1/hire/jobs_controller.rb:3
│   │               ← OUTLIER: sits in the ApiPublic namespace but inherits Api::V1::BaseController
│   │
│   ├── Api::V1::IndividualApp::BaseController               api/v1/individual_app/base_controller.rb:3  ← JSON, Devise session
│   │   ├── Api::V1::IndividualApp::CareersPageSubscriptionsController      (1)
│   │   └── IndividualApp::CareersPageSubscriptionsController               (1)
│   │
│   ├── ApiPublic::V1::Hire::BaseController                  api_public/v1/hire/base_controller.rb:3     ← JSON, API key
│   │   └── ApiPublic::V1::Hire::{Candidates,Comments,CustomerJobs,HiringStageEvents,
│   │         HiringStages,JobApplications,JobResumeExports,Messages,OrganizationUsers,
│   │         Organizations,Reviews}Controller
│   │
│   ├── Admin::BaseController                                admin/base_controller.rb:3   ← NO ROUTES POINT HERE
│   │
│   ├── MagicLinksController                                 magic_links_controller.rb:3        (2)
│   │
│   ├── Cypress::{AdminUsers,Candidates,Invites,Jobs,Organizations,Users}Controller
│   │   Cypress::IndividualApp::CareersPageSubscriptionsController          (test env only)
│   │
│   └── DeviseController                                     gems/devise-4.8.1 (parent = ApplicationController)
│       ├── Devise::SessionsController        → Api::V1::SessionsController        api/v1/sessions_controller.rb:3   (5)
│       │                                     → Admin::SessionsController          admin/sessions_controller.rb:3
│       ├── Devise::RegistrationsController   → Api::V1::RegistrationsController   api/v1/registrations_controller.rb:3 (3)
│       │                                     → Auth::InvitesController            auth/invites_controller.rb:3      (1)
│       │                                     → Api::V1::Public::UnregisteredJobController
│       │                                     → ApiPublic::V1::Hire::UnregisteredJobController
│       ├── Devise::OmniauthCallbacksController → Api::V1::Users::OmniauthCallbacksController                        (1)
│       └── Devise::ConfirmationsController   → IndividualApp::ConfirmationsController                               (4)
│
├── ActiveStorage::BaseController                            gem   ← BYPASSES ApplicationController
│   ├── ActiveStorage::DiskController / Blobs::{Redirect,Proxy} / Representations::*
│   └── ActiveStorage::DirectUploadsController
│       ├── Api::V1::Public::DirectUploadsController         api/v1/public/direct_uploads_controller.rb:3   ← the hire SPA's uploader
│       └── ApiPublic::V1::Hire::DirectUploadsController     api_public/v1/hire/direct_uploads_controller.rb:3
│
├── Api::V1::Integrations::ZapierIntegrationsController      api/v1/integrations/zapier_integrations_controller.rb:3   ← BYPASSES ApplicationController
├── Cypress::CleanupController                               cypress/cleanup_controller.rb:3                          ← BYPASSES ApplicationController
├── Griddler::EmailsController                               gem                                                      ← BYPASSES ApplicationController
├── ActionMailbox::BaseController                            gem                                                      ← BYPASSES ApplicationController
└── Rails::ApplicationController / Rails::Conductor::BaseController   railties                                        ← BYPASSES ApplicationController

ActionCable::Connection::Base
└── ApplicationCable::Connection                             app/channels/application_cable/connection.rb:4   ← not a controller

ActionCable::Channel::Base
└── ApplicationCable::Channel  → BillingChannel, GlobalChannel, JobChannel
```

### 10.3 Route family → base class (complete, all 538 routes)

Grouped by controller; the route counts sum to 538 across every group below plus the router-redirect and mounted rows. "Auth" is what the resolved callback chain actually enforces, not what a filename suggests.

#### Family A — hire HTML, `app.polymer.co` (`constraints SubdomainAppConstraints` → `scope module: :hire`, routes.rb:567-665)

| Routes | Controller | Base chain | Renders | Auth |
|---|---|---|---|---|
| 60 | `hire/pages` | `Hire::PagesController < Hire::BaseController < ApplicationController` | HTML (SPA shell) | **none** at Rails level; `redirect_if_authed` on the 6 non-`root` actions |
| 3 | `hire/redirector` | `Hire::RedirectorController < Hire::BaseController < ApplicationController` | 301/302 redirect | none |
| 3 | `hire/errors` | `Hire::ErrorsController < Hire::BaseController < ApplicationController` | HTML, `layout false` | none |
| 1 | `hire/confirmations` | `Hire::ConfirmationsController < Hire::BaseController < ApplicationController` | 302 redirect | none (token in params) |
| 2 | `hire/integrations/oauth_authentications` | `Hire::Integrations::OauthAuthenticationsController < ApplicationController` | 302 redirect | **`authenticate_api_v1_user!` (Devise session)** |
| 1 | `hire/stripe_customer_portal` | **class does not exist** (routes.rb:575) | — | — |
| 12 | router redirects (routes.rb:547-556, 606, 631) | none — `ActionDispatch::Routing::Redirect` | 301 | none |

#### Family B — account / connect HTML, same host

| Routes | Controller | Base chain | Renders | Auth |
|---|---|---|---|---|
| 2 | `account/pages` | `Account::PagesController < Account::BaseController < ApplicationController` | HTML (`account_application` layout) | none; writes `cookies[:account_referrer]` |
| 2 | `connect/pages` | `Connect::PagesController < Connect::BaseController < ApplicationController` | HTML (`connect_application` layout) | none declared; action body calls `current_organization_user.is_admin` and would `NoMethodError` on nil for a signed-out visitor |

#### Family C — the SPA's own data API, `/api/v1/*` (routes.rb:69-469, **no subdomain constraint**)

All of these are `< Api::V1::BaseController < ApplicationController < ActionController::Base` and all render JSON. **All authenticate through the same Devise `:api_v1_user` session cookie** (§10.6).

`me` (13), `jobs` (13), `billing` (14), `organization_ai_credit_purchases` (13), `job_application_notifications` (8), `hiring_stages` (8), `process_templates` (7), `organizations` (7), `job_applications` (7), `invites` (7), `comments` (7), `candidates` (7), `board_what_jobs_listings` (7), `users` (6), `registered_webhooks` (6), `job_categories` (6), `hiring_stage_message_automations` (6), `comment_templates` (6), `channel_message_templates` (6), `integrations/webflow_integrations` (5), `integrations/slack_channel_integrations` (5), `careers_pages` (5), `questions` (4), `integrations/discord_channel_integrations` (4), `hiring_stage_templates` (4), `board_wwr_listings` (4), `organization_users` (3), `job_application_files` (3), `hiring_team_invites` (3), `candidate_private_notes` (3), `api_keys` (3), `organization_data_exports` (2), `hiring_team_memberships` (2), `connect_members` (2), `channels` (2), `bulk_ai_job_application_summaries` (2), `ai_job_application_summaries` (2), `organization_ai_credit_balance` (1), `job_csv_export` (1), `job_csv_import` (1), `job_resume_export` (1), `job_application_activities` (1), `job_application_interviewer_invites` (1), `job_application_interviewer_requests` (1), `channel_messages` (1), `channel_message_templates_mail_merge` (1), `bulk_channel_messages` (1), `bulk_move_job_applications_to_stage` (1), `analytics` (1), `universal_search` (1), `connect_members_search` (1), `support_messages` (1), `timestamp` (1), `integrations/oauth_authentications` (1).

Exceptions inside `/api/v1/*`:

| Routes | Controller | Base chain | Auth |
|---|---|---|---|
| 1 | `api/v1/users#ping` (routes.rb:216) | same | `skip_before_action :authenticate_api_v1_user!, only: [:ping]` (`api/v1/users_controller.rb:5`) — **unauthenticated** |
| 1 | `api/v1/invites#show` (routes.rb:132) | same | `skip_before_action …, only: [:show]` (`api/v1/invites_controller.rb:5`) — unauthenticated |
| 5 | `api/v1/sessions` (routes.rb:84-87, 90) | `Api::V1::SessionsController < Devise::SessionsController < DeviseController < ApplicationController` | Devise controller (`require_no_authentication` on create) |
| 3 | `api/v1/registrations` (routes.rb:81-83) | `Api::V1::RegistrationsController < Devise::RegistrationsController < DeviseController < ApplicationController` | Devise controller |
| 1 | `api/v1/users/omniauth_callbacks` (routes.rb:128) | `< Devise::OmniauthCallbacksController < DeviseController < ApplicationController` | none (OmniAuth env) |
| 3 | `api/v1/integrations/zapier_integrations` (routes.rb:459-465) | **`ActionController::Base` directly** | `before_action :authenticate` (Zapier API key) |
| 12+8+8+9+4+1+1+1+1 = 45 | `api/v1/admin/*` (routes.rb:385-426) | `< Api::V1::Admin::BaseController < Api::V1::BaseController < ApplicationController` | Devise session **+ `verify_god_admin`** |
| 5 | `api/v1/public/webhooks` (routes.rb:361-369) | `< Api::V1::BaseController < ApplicationController` | **none** (Stripe/Mailgun/Slack/Discord/Webflow POSTs) |
| 3+3+2+2 | `api/v1/public/{jobs,candidates,organizations,job_feeds}` (routes.rb:345-372) | `< Api::V1::BaseController < ApplicationController` | none / `authenticate` (job feeds) |
| 1 | `api/v1/public/unregistered_job` (routes.rb:376) | `< Devise::RegistrationsController < DeviseController < ApplicationController` | Devise controller |
| 1 | `api/v1/public/direct_uploads` (routes.rb:346) | **`< ActiveStorage::DirectUploadsController < ActiveStorage::BaseController < ActionController::Base`** | none |
| 1 | `api/v1/individual_app/careers_page_subscriptions` (routes.rb:434) | `< Api::V1::IndividualApp::BaseController < ApplicationController` | Devise session (`:api_v1_user`) |
| 1 | `api/v1/home#index` (routes.rb:71) | **class does not exist** | — |
| 5+3+7 | `api/v1/passwords`, `api/v1/confirmations`, `registrations` (generated by `devise_for :users`, routes.rb:123-126) | **classes do not exist** — `controllers: { registrations: 'registrations' }` resolves to a top-level `RegistrationsController` that was never created; the working signup path is the `devise_scope` route at routes.rb:81 | — |
| 1 | `MOUNTED(Rack::Builder)` — `Flipper::Api.app` at `/api/v1/flipper` (routes.rb:76) | no controller | none |

#### Family D — customer public API, `api.polymer.co` (routes.rb:474-534)

| Routes | Controller | Base chain | Renders | Auth |
|---|---|---|---|---|
| 6+5+5+5+3+2+2+2+1+1 | `api_public/v1/hire/{job_applications,reviews,comments,candidates,organization_users,organizations,job_resume_exports,customer_jobs,messages,hiring_stages,hiring_stage_events}` | `< ApiPublic::V1::Hire::BaseController < ApplicationController` | JSON | **API key** (`Authorization: Bearer`) — no Devise, no `current_user` |
| 3 | `api_public/v1/hire/jobs` | **`< Api::V1::BaseController < ApplicationController`** (outlier) | JSON | none (`skip_before_action :authenticate_api_v1_user!`, `api_public/v1/hire/jobs_controller.rb:4`) |
| 1 | `api_public/v1/hire/unregistered_job` | `< Devise::RegistrationsController < DeviseController < ApplicationController` | JSON | Devise controller |
| 1 | `api_public/v1/hire/direct_uploads` | **`< ActiveStorage::DirectUploadsController < ActiveStorage::BaseController < ActionController::Base`** | JSON | none |

#### Family E — other hosts and top-level routes

| Routes | Route / block | Controller | Base chain | Renders | Auth |
|---|---|---|---|---|---|
| 1 | `POST /email_processor` (routes.rb:53) | `griddler/emails` | **`ActionController::Base`** (gem) | JSON | none |
| 2 | `POST /magic_links`, `GET /magic_links/validate` (routes.rb:54-55) | `magic_links` | `MagicLinksController < ApplicationController` | JSON / 302 | none (token) |
| 1 | `GET /invites/accept` (routes.rb:58) | `auth/invites` | `< Devise::RegistrationsController < DeviseController < ApplicationController` | 302 | none (token); signs the user in |
| 1 | `/sidekiq` (routes.rb:62-64) | `MOUNTED(Class)` — Sidekiq::Web | no controller | HTML | `authenticate :user` — no `:user` mapping exists (§8) |
| 1 | `/caffeinate` (routes.rb:6) | `MOUNTED(Class)` — Caffeinate::Engine | engine | HTML | engine's own |
| 7+3 | `devise_for :admin_users` (routes.rb:536) | `devise/registrations`, `devise/sessions` | `< DeviseController < ApplicationController` | HTML | Devise, `:admin_user` scope |
| 8+4+6 | `jobs.polymer.co` (routes.rb:698-714) | `job_board/{jobs,privacy,errors}` | `< JobBoard::BaseController < ApplicationController` | HTML | none (public careers pages) |
| — | custom domains (routes.rb:719-733) | same `JobBoard::*` classes | same | HTML | none |
| 3+4+1 | `individual.polymer.co` (routes.rb:671-693) | `individual_app/{pages,confirmations,careers_page_subscriptions}` | `IndividualApp::BaseController` / `Devise::ConfirmationsController` / `Api::V1::IndividualApp::BaseController` — all under `ApplicationController` | HTML | none / Devise |
| 5+7+3+4 | `devise_for :individuals` (routes.rb:681) | `individual_app/{sessions,registrations,passwords,confirmations}` | only `confirmations` has a class; **the other three do not exist** | — | — |
| 8+2+1+1+1+1+1+1 | Rails/ActionMailbox/Conductor built-ins | `rails/*`, `action_mailbox/*` | `Rails::ApplicationController` / `ActionMailbox::BaseController`, both `< ActionController::Base` | — | — |
| 1+2+2+1+1 | `/rails/active_storage/*` | `active_storage/{disk,blobs/redirect,blobs/proxy,representations/*,direct_uploads}` | `< ActiveStorage::BaseController < ActionController::Base` | binary/JSON | signed-ID only |
| 1 | `/cable` | `MOUNTED(ActionCable::Server::Base)` | not a controller | WebSocket | warden `api_v1_user` (`connection.rb:14`) |
| 1 | `/assets` | `MOUNTED(Sprockets::Environment)` | — | — | — |
| 1 | `/_flipper` | `MOUNTED(Rack::Builder)` | — | — | — |
| (test env only) | `lib/test_routes.rb` via routes.rb:8-11 | `cypress/*` | 7 under `ApplicationController`, `Cypress::CleanupController` under `ActionController::Base` | JSON | none |

### 10.4 Coverage per candidate base class — the decisive question

**Direct answer to "do the SPA's data-fetching XHRs share a base class with the HTML page requests?" — Yes.** `Hire::PagesController` and `Api::V1::MeController` share exactly one common ancestor below `ActionController::Base`: **`ApplicationController`**. They share no other base class and no concern. So an `ApplicationController` callback is the only single hook that reaches both families; anything narrower reaches one or the other.

| Candidate base class | Fires on | Does NOT fire on |
|---|---|---|
| **`ApplicationController`** (`application_controller.rb:3`) | Hire HTML (60 `pages` + 3 redirector + 3 errors + 1 confirmations + 2 oauth-integration); Account (2) and Connect (2) HTML; **all ~200 `/api/v1/*` JSON routes including every SPA data fetch**; all `/api/v1/admin/*` (45); all `api_public/v1/hire/*` API-key JSON (32); all `job_board` HTML (18); all `individual_app` HTML; every `DeviseController` descendant (sessions, registrations, invites, omniauth, confirmations); `MagicLinksController`; the Cypress controllers except cleanup | `/cable` (`ApplicationCable::Connection`); **all ActiveStorage controllers, including `Api::V1::Public::DirectUploadsController` — the hire SPA's own file uploader**; `Api::V1::Integrations::ZapierIntegrationsController`; `Cypress::CleanupController`; `Griddler::EmailsController`; ActionMailbox ingresses; `rails/*` built-ins; the 13 router-level 301s; `/sidekiq`, `/caffeinate`, `/assets`, `/_flipper`, `/api/v1/flipper`; static assets |
| **`Hire::BaseController`** (`hire/base_controller.rb:3`) | `Hire::PagesController` (60), `Hire::RedirectorController` (3), `Hire::ErrorsController` (3), `Hire::ConfirmationsController` (1) — **67 HTML routes** | Every `/api/v1/*` request (so: every SPA data fetch, on every page after the first paint); `Hire::Integrations::OauthAuthenticationsController` (it inherits `ApplicationController` directly); Account and Connect shells; everything in the ApplicationController "does not fire" column |
| **`Api::V1::BaseController`** (`api/v1/base_controller.rb:3`) | Every `/api/v1/*` JSON route that is not a Devise controller — the SPA's entire data layer (~200 routes), plus `/api/v1/admin/*` (45), plus the five `api/v1/public/*` families (14), plus `ApiPublic::V1::Hire::JobsController` (3, the outlier) | All HTML: hire shell, account, connect, job board, individual app; `api/v1/sessions` / `api/v1/registrations` / omniauth (Devise controllers); `api_public/v1/hire/*` proper (they use `ApiPublic::V1::Hire::BaseController`); Zapier; ActiveStorage; `/cable` |
| **`Hire::PagesController`** (`hire/pages_controller.rb:3`) | 60 routes — the SPA shell for every enumerated hire path, plus the 6 unauthed page actions | The 3 redirector routes, the 3 error pages, the confirmations redirect, and every XHR |
| **`Account::BaseController`** / **`Connect::BaseController`** | 2 routes each | everything else |
| **`ApiPublic::V1::Hire::BaseController`** | 32 API-key routes on `api.polymer.co` | everything else; and it has no `current_user` to read (§10.6) |
| **`Admin::BaseController`** | **nothing** — no route in `config/routes.rb` resolves to a subclass of it | everything |

Two facts that follow directly and matter for a `Set-Cookie` decision:

1. `ApplicationController` is the **only** hook point that covers both the HTML shell and the SPA's XHR. Every other candidate covers one family only.
2. `ApplicationController` still misses the SPA's **file uploads** (`Api::V1::Public::DirectUploadsController`, used by `DragAndDropResumeUploader.tsx:68` and `forms/FormUploader.tsx`), because ActiveStorage's base class descends from `ActionController::Base`, not from `ApplicationController`. That is a gap in coverage but not a gap in *reachability* — any user uploading a file is already making dozens of other `/api/v1/*` calls.

### 10.5 Concerns shared across HTML and API families

**None.** Exhaustive list of every `include` in `app/controllers/` (`grep -rn "^\s*include \|^\s*extend " app/controllers/`):

| Module | Definition | Included by | Family |
|---|---|---|---|
| `Pundit` | gem | `ApplicationController:6` | **both** — but it is a third-party authorization module, not an app concern, and it declares no callbacks |
| `RoleFitFilterable` | `app/controllers/concerns/role_fit_filterable.rb:11` (32 lines) | `api/v1/job_applications_controller.rb:4`, `api/v1/bulk_channel_messages_controller.rb:5`, `api/v1/bulk_ai_job_application_summaries_controller.rb:4`, `api/v1/bulk_move_job_applications_to_stage_controller.rb:4` | JSON only. Declares no callbacks — one method, `apply_role_fit_filter` |
| `ApiPublic::V1::Hire::HtmlSanitizable` | `app/controllers/concerns/api_public/v1/hire/html_sanitizable.rb:4` (105 lines) | `api_public/v1/hire/base_controller.rb:21` | JSON only. No callbacks |
| `Sanitizer` | `app/utils/sanitizer.rb:3` (not in `concerns/`) | 11 API controllers: `api/v1/{jobs,organizations,bulk_channel_messages,careers_pages,comments,support_messages,candidate_private_notes,channel_messages}`, `api/v1/admin/{jobs,organizations}`, `api/v1/public/unregistered_job`, `api_public/v1/hire/unregistered_job` | JSON only. No callbacks |

So: **no app-authored concern is included by both an HTML base and an API base**, and no concern in the codebase declares a callback at all. There is no existing shared-concern hook point; the shared surface is the `ApplicationController` class itself.

### 10.6 Authentication mechanism per family — is `current_user` available on API requests?

**Yes. The JSON API authenticates with the same Devise session cookie as the HTML pages. There is no token or header scheme on the SPA's data API.** Evidence, in order:

1. `Api::V1::BaseController:6` declares `before_action :authenticate_api_v1_user!`. That method is generated by `Devise::Controllers::Helpers.define_helpers` (`gems/devise-4.8.1/lib/devise/controllers/helpers.rb:112-119`) and its body is `warden.authenticate!(scope: :api_v1_user)` — pure Warden/Devise session authentication.
2. `current_api_v1_user` is `warden.authenticate(scope: :api_v1_user)` memoized (`helpers.rb:125-127`), and `Api::V1::BaseController:9` does `alias current_user current_api_v1_user`. So inside any API controller, `current_user` is a real `User`.
3. **No custom Warden strategy is registered.** `config/initializers/devise.rb:284-287` (`config.warden do |manager| … end`) is entirely commented out, as are the two JWT blocks at `:8-10` and `:15-22`. `Devise.mappings` has three entries, none token-based (§8).
4. **The frontend sends no `Authorization` header.** `app/javascript/shared/queryHooks/api.ts:8-13` — `apiGet` sets only `Accept: application/json` and `Content-Type: application/json`. `:43-53` — `apiMutate` adds only `X-CSRF-Token: Rails.csrfToken()`. Both build **relative** URLs (`/api/v1${path}`, `:6` and `:41`), so they are same-origin requests to `app.polymer.co` and the browser attaches `_inflow_ats_session` (and `remember_api_v1_user_token`) automatically.
5. Corroborating dead code: `app/controllers/api/v1/base_controller.rb:13-21` is a commented-out `handle_old_proof_token` that decoded a JWT from `request.headers['Authorization']` — a token scheme that was considered and is not in use.
6. The same session backs the websocket: `app/channels/application_cable/connection.rb:14` reads `env['warden'].user('api_v1_user')`.
7. `Api::V1::IndividualApp::BaseController:5` also uses `authenticate_api_v1_user!` — same scope, same cookie.

**The one family that does not have `current_user`:** `ApiPublic::V1::Hire::BaseController` authenticates via `Authorization: Bearer <key>` → SHA-256 digest → `ApiKey` lookup (`api_public/v1/hire/base_controller.rb:57-69`, `:78-83`). It sets `@current_api_organization`, `@current_api_key`, `@current_api_key_owner` (an `OrganizationUser`, `:67`) and never touches Warden. A callback on `ApplicationController` firing there would find `current_api_v1_user` nil — correct behavior, since those requests come from customer servers, not browsers.

**Consequence for the cookie decision (fact, not recommendation):** because the JSON family shares `ApplicationController` with the HTML family *and* authenticates from the same session cookie, a callback on `ApplicationController` guarded by `current_api_v1_user.present?` would find a real user on both the SPA shell request and every one of the SPA's ~200 data endpoints, and a `Set-Cookie` on any of those JSON responses is stored by the browser exactly as it would be on the HTML response.

---

## Recommended hook points

Four viable places. Presented with coverage and gaps; **not ranked**.

Universal constraints that apply to all four:
- The cookie must be readable by `www.polymer.co`, so it needs `domain:` set to the registrable domain (`.polymer.co`), derived from `request.domain` — hardcoding `polymer.co` breaks `app.lvh.me` in development and `app-staging.wrk.xyz` / `app-develop.polymer.co` in staging (`Variables::APP_DOMAIN_LIST`, `config/initializers/01_variables.rb:95`; staging hostnames enumerated in `config/initializers/rack_attack.rb:19-21`).
- In production `ActionDispatch::SSL` appends `; secure` to the `Set-Cookie` unconditionally (`config/environments/production.rb:56` → `gems/actionpack-6.1.7.7/lib/action_dispatch/middleware/ssl.rb:79`). Plan for a secure cookie; don't fight it.
- If `www.polymer.co` reads the value with JavaScript, `httponly` must be left off. The existing `cookies[:account_referrer]` precedent (`account/pages_controller.rb:5`) is non-HttpOnly.
- No hook can cover **router-level redirects** (§4a) — 13 of them, including all nine `/account/*` → `/hire/settings/*` rewrites and `/admin` → `/admin/dashboard`. Those responses are generated before any controller.

### Option A — `after_action` on `ApplicationController`

Guarded on `current_api_v1_user.present?`.

- **Covers:** the hire SPA shell (`pages#root`) and all six other `Hire::PagesController` actions; the redirector, confirmations, errors and OAuth-integration controllers; **every `/api/v1/*` XHR** the SPA makes; `Account::` and `Connect::` shells; Admin API; `ApiPublic::V1::Hire::*`; every Devise controller. **This is the only hook point that reaches both the HTML family and the SPA's data API** — they share no other ancestor and no concern (§10.4, §10.5). Because it is an `after_action` it also runs on the R1 `/auth` → `/` 302 and on every other controller-issued redirect in §4b — `redirect_to` sets the response but does not skip `after_action`s.
- **Misses:** `/cable` (`ApplicationCable::Connection`, §6), ActiveStorage direct-upload and blob controllers (`ActiveStorage::BaseController < ActionController::Base`) — which includes the SPA's own resume uploader at `/api/v1/public/rails/active_storage/direct_uploads`, `Api::V1::Integrations::ZapierIntegrationsController`, static assets, and all router-level redirects (§4a).
- **Over-covers:** fires on `jobs.polymer.co` job-board requests, `individual.polymer.co`, custom-domain careers pages, the public API, and Mailgun/Stripe webhook POSTs. On those, `current_api_v1_user` invokes `warden.authenticate(scope: :api_v1_user)` (`gems/devise-4.8.1/lib/devise/controllers/helpers.rb:125-127`) — non-throwing, but it runs Devise strategies and can add a `User` lookup to requests that currently do none. That is a real, measurable cost on the job-board hosts, which are the highest-traffic surface (see the `Rack::Attack` allow2ban rule that exists specifically to protect them, `config/initializers/rack_attack.rb:83-101`).

### Option B — `before_action` (or `after_action`) on `Hire::BaseController`

- **Covers:** every hire HTML response — `pages#root` for all ~45 enumerated deep links (routes.rb:598-664), the six unauthed page actions, `Hire::RedirectorController` (both redirect actions), `Hire::ConfirmationsController#show`, `Hire::ErrorsController` (the 404/422/500 pages, which is where unrouted hire URLs land via `config.exceptions_app = routes`).
- **Misses:** every XHR. A user who leaves the tab open for days and never reloads the shell never refreshes the cookie. Also misses `Hire::Integrations::OauthAuthenticationsController`, which inherits `ApplicationController` directly (`hire/integrations/oauth_authentications_controller.rb:3`) — the one hire controller outside `Hire::BaseController`. Misses `Account::` and `Connect::` shells.
- **Over-covers:** fires for signed-out visitors on `/`, `/auth`, `/login`, `/register` — `Hire::PagesController#root` has no authentication whatsoever, so a `current_api_v1_user.present?` guard is mandatory, not optional.
- **Ordering note if you choose `before_action`:** it appends after `redirect_if_authed` in subclass order only if declared in the subclass; declared on `Hire::BaseController` it runs *before* `Hire::PagesController`'s `redirect_if_authed` (parent callbacks run first), so the cookie is set and the redirect still carries it. Either kind works.

### Option C — `Api::V1::BaseController`, appended after `set_sentry_context`

- **Covers:** every SPA XHR — ~200 routes (§10.3 Family C), dozens per session for an active user — so the cookie stays fresh without a full page reload. `authenticate_api_v1_user!` (index 6) has already run, so `current_user` is guaranteed non-nil in the non-skipping controllers; no extra warden work, no extra query. The API family authenticates from the **same Devise session cookie** as the HTML family (§10.6), so the user ID is genuinely available here. Structurally identical to the existing `set_sentry_context` analog (`api/v1/base_controller.rb:7`, `:33-46`).
- **Misses:** the initial HTML shell response. On a cold first load the cookie is not present until `GET /api/v1/me` returns — a race for anything on `www.polymer.co` reading it in the same instant, though irrelevant for cross-site retargeting exclusion which reads on a later visit.
- **Over-covers:** the `api/v1/public/*` controllers that `skip_before_action :authenticate_api_v1_user!` (webhooks, job feeds, public job apply) still inherit the hook, so it needs a `current_api_v1_user` presence guard even here. Also covers `Api::V1::IndividualApp::*`.

### Option D — narrowest: `Hire::PagesController` only (or its `root` action)

- **Covers:** exactly the authenticated SPA shell. Matches the shape of the existing precedent (`Account::PagesController#root` writing `cookies[:account_referrer]`, `account/pages_controller.rb:5`).
- **Misses:** everything Option B covers beyond `pages#*` — the redirector's 301/302s, the confirmation redirect, the 404 page — plus all XHR.
- **Note:** if placed as a `before_action` on the controller rather than inside `#root`, it also fires on the six unauthed actions, including the R1 `/auth` → `/` redirect path, which is arguably desirable (a signed-in user arriving at `/auth` gets the cookie before being bounced). Placed inside `#root` alone, it does not.

**Composite worth considering:** B + C (shell sets it on first paint, API refreshes it thereafter) gives full coverage of the hire population with no cost imposed on the job-board hosts. Named here only because the two options compose cleanly; the choice is yours.

---

## Open questions / could not determine from code

1. **Is there a CDN or reverse proxy in front of `app.polymer.co`?** Nothing in the repository configures one (§7, point 5). Deployment-level configuration (Heroku router, a Cloudflare zone managed in their dashboard) is outside the code and I did not attempt to verify it. The in-code answer to "could a cached HTML response leak one user's `Set-Cookie` to another" is **no**, on the strength of no `Rack::Cache`, no `expires_in`/`fresh_when`/`caches_action` anywhere, and `Rack::ETag` stamping `Cache-Control: private` on every uncached 200.
2. **Can `/sidekiq` (routes.rb:62-64) ever match?** It requests warden scope `:user`, and `Devise.mappings.keys == [:api_v1_user, :admin_user, :individual]`. Resolving what Warden does with an unmapped scope requires tracing Warden's default-strategy resolution, which is past the gem boundary. Not relevant to the cookie feature; flagged because it looks like latent breakage.
3. **`Variables::AtsRootUrl`** resolves through `Rails.application.credentials` (`config/initializers/01_variables.rb:19`). I did not decrypt credentials, so I cannot state the literal production value; the redirects at `oauth_authentications_controller.rb:66,71,84`, `omniauth_callbacks_controller.rb:49,57` and `billing_controller.rb:404` are absolute URLs built from it.
4. **`window.APP_ATS_ROOT_URL`** (`app/views/layouts/application.html.erb:74`) is the same value and is what `useMe.ts:89` uses for the forced `/logout` navigation and what `WebsocketContext.tsx:11` uses for the `/cable` consumer. Same credential dependency.
5. **Routes whose controller class does not exist** (found by constantizing every route target in the enumerated route set; each raises `NameError` on dispatch). None affect the cookie decision; listed so they are not mistaken for live code paths:
   - `hire/stripe_customer_portal#create` — routes.rb:575.
   - `api/v1/home#index` — routes.rb:71.
   - `api/v1/admin/users#*` (8 routes) and `api/v1/admin/candidates#*` (8) — routes.rb:403-412. Only the `*_search` siblings exist in `app/controllers/api/v1/admin/`.
   - `api/v1/passwords#*` (5) and `api/v1/confirmations#*` (3) — Devise defaults generated by `devise_for :users` under the `api/v1` module scope (routes.rb:123-126).
   - `registrations#*` (7, at `/api/v1/users*`) — `devise_for :users, controllers: { registrations: 'registrations' }` takes the value literally as a top-level `RegistrationsController`, ignoring the module scope. The working signup path is the `devise_scope` route `post '/sign_up', to: 'registrations#create'` at routes.rb:81, which does resolve to `Api::V1::RegistrationsController`.
   - `individual_app/{sessions,registrations,passwords}#*` (15) — Devise defaults from `devise_for :individuals` (routes.rb:681); only `IndividualApp::ConfirmationsController` was written.
6. **`Admin::BaseController` (`app/controllers/admin/base_controller.rb:3`) has no routes.** Every `/api/v1/admin/*` route resolves to `Api::V1::Admin::BaseController` instead. Whether `Admin::BaseController` is reachable some other way, I could not determine from code — nothing in the enumerated route set targets a subclass of it, and `grep -rn "Admin::BaseController" app/` finds only the definition.
7. **`ApiPublic::V1::Hire::JobsController` inherits `Api::V1::BaseController`** (`api_public/v1/hire/jobs_controller.rb:3`) rather than `ApiPublic::V1::Hire::BaseController` like its ten siblings. It then does `skip_before_action :authenticate_api_v1_user!` (`:4`), so its three routes on `api.polymer.co` are unauthenticated rather than API-key-gated. Pre-existing; flagged because it changes which base-class hook would cover it.
8. **`ApplicationController#after_sign_in_path_for` / `#after_sign_out_path_for` reference `root_path`, which is not a defined route helper** (application_controller.rb:146 and :138; verified `NoMethodError`). I traced every caller I could find and concluded they are unreachable for the `api_v1_user` scope (§4c), but I did not exhaustively prove that no Devise code path reaches them — `Admin::BaseController:11` calls `root_path` directly and would raise.
