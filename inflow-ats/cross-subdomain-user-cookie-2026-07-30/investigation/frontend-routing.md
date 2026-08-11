# Frontend routing + the Rails↔React seam — cross-subdomain user cookie

Source read: `/Users/jessica/wrk/wrk-corp/inflow-ats.cross-subdomain-user-cookie` (branch `cross-subdomain-user-cookie`). Read-only; nothing modified.

## STACK CORRECTION (read this first)

The task brief said "React 18, React Router v5". **Both are wrong for this repo.**

| Package | `package.json` | Installed in `node_modules` |
|---|---|---|
| `react` | `16.14.0` (`package.json:86`) | `16.14.0` |
| `react-router` | `4.2.0` (`package.json:105`) | `4.2.0` |
| `react-router-dom` | `4.2.2` (`package.json:106`) | `4.2.2` |
| `react-query` | `3.13.10` (`package.json:102`) | `3.13.10` |
| `query-string` | `6.1.0` (`package.json:85`) | — |
| `posthog-js` | `1.297.4` (`package.json:70`) | — |

React Router **4.2.0**, not v5. Consequences verified in installed source:
- `<Redirect>` calls `history.replace(to)` unless `push` is passed (`node_modules/react-router/Redirect.js:70-82`, `Redirect.defaultProps = { push: false }` at `:96-98`). Every `<Redirect>` in this codebase is therefore a **client-side** location change — React stays mounted.
- `<Switch>` matches on the first child having a `path` **or** `from` prop; a child with neither (a bare `<Redirect to=...>`) matches unconditionally via `route.match` (`node_modules/react-router/Switch.js:63-81`). This is why `AppAuthRouter`'s `{needsX()}` helpers work as gates inside `<Switch>`.
- v4 `<Redirect>` performs in `componentDidMount` (`Redirect.js:54-56`), i.e. after the first render commits.

React 16 also means no concurrent rendering / no `<StrictMode>` double-invoke concerns.

## File chain traced

Hire (ATS) mount chain:

```
config/routes.rb:541 (SubdomainAppConstraints)
  → config/routes.rb:567-665 (scope module: :hire)
  → app/controllers/hire/pages_controller.rb#root
  → app/controllers/hire/base_controller.rb
  → app/controllers/application_controller.rb
  → app/views/hire/pages/root.html.erb   (<div id="root">)
  → app/views/layouts/application.html.erb:95 (javascript_packs_with_chunks_tag 'ats_application')
  → app/javascript/packs/ats_application.js:18 (import "../ats/src")
  → app/javascript/ats/src/index.js:27 (ReactDOM.render(<App/>, #root))
  → app/javascript/ats/src/views/layouts/App.tsx:49 (<AppAuthRouter/>)
  → app/javascript/ats/src/views/layouts/AppAuthRouter.tsx:544 (withRouter(AuthedLogoutDecision))
  → AppAuthRouter.tsx:533 (AuthedLogoutDecision)
  → AppAuthRouter.tsx:65 (AppAuthed)
  → AppAuthRouter.tsx:419 (<CurrentSessionProvider>)
  → AppAuthRouter.tsx:511 (<AppContainer>)
  → app/javascript/ats/src/views/layouts/AppContainer.tsx
```

Account mount chain (separate React root, separate page load):

```
config/routes.rb:544-560 (namespace :account)
  → app/controllers/account/pages_controller.rb:4-6 (sets cookies[:account_referrer])
  → app/controllers/account/base_controller.rb:4 (layout 'account_application')
  → app/views/account/pages/root.html.erb:1 (<div id="root">)
  → app/views/layouts/account_application.html.erb:58 (pack 'account_application')
  → app/javascript/packs/account_application.js:18 (import "../account/src")
  → app/javascript/account/src/index.js:10 (ReactDOM.render(<App/>, #root))
  → app/javascript/account/src/App.tsx:9-13 (AppDefaultWrapper > AppAuthedWrapper > Routes)
  → app/javascript/shared/layouts/AppAuthedWrapper.tsx:35 (<CurrentSessionProvider>)
  → app/javascript/account/src/routes.tsx (its own BrowserRouter basename="/account")
```

Session/data chain:

```
AppAuthRouter.tsx:76 useGetMe
  → app/javascript/shared/queryHooks/useMe.ts:57-93 (useQuery "me")
  → app/javascript/shared/queryHooks/api.ts:5-23 (apiGet → axios GET /api/v1/me)
  → config/routes.rb:93 (resource :me, controller: :me)
  → app/controllers/api/v1/me_controller.rb:5-9 (#show)
  → app/controllers/api/v1/base_controller.rb:6 (before_action :authenticate_api_v1_user!)
  → app/serializers/api/v1/session_serializer.rb:5 (attributes :id, ...)
```

Supporting files read in full: `app/javascript/shared/layouts/AppDefaultWrapper.tsx`, `app/javascript/ats/src/context/CurrentSessionContext.tsx`, `app/javascript/ats/src/context/GlobalChannelContext.tsx`, `app/javascript/ats/src/websockets/WebsocketContext.tsx`, `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx`, `app/javascript/shared/websockets/WebsocketContext.tsx`, `app/javascript/shared/context/ColorSchemeContext.tsx`, `app/javascript/shared/PostHogContext.tsx`, `app/javascript/shared/lib/posthog.ts`, `app/javascript/shared/hooks/{useSentry,useHeapAnalytics,useIntercom,useCookieValue,useReferrerCookie,useCSRFToken,useFeatureGate,usePlanLimitsGate,useAddActiveUserGate}.ts`, `app/javascript/shared/lib/utils.js`, `app/javascript/shared/components/PolymerBar.tsx`, `app/javascript/shared/components/NavBar.tsx`, `app/javascript/shared/routing/{DesktopRedirector,WithGoogleAnalytics}.tsx`, `app/javascript/shared/queryHooks/{useMe,useSession,useOrganization,useFeatureFlippers,api}.ts`, `app/javascript/ats/src/views/sessions/{Auth,Logout,VerifyEmail}.tsx`, `app/javascript/ats/src/views/jobApplications/JobStripeCheckoutRedirectHandler.tsx`, `app/javascript/ats/src/components/shared/FeatureFlipper.tsx`, `app/javascript/ats/src/lib/store/zustand/featureFlipperStore.ts`, `app/javascript/ats/src/lib/api/index.js`, `app/javascript/ats/src/views/sessions/components/GoogleSSOButton.tsx`, `app/javascript/shared/components/OauthConnectButton.tsx`, `app/controllers/{magic_links_controller,hire/redirector_controller,hire/confirmations_controller,hire/errors_controller}.rb`, `app/controllers/api/v1/users/omniauth_callbacks_controller.rb`, `app/services/subdomain_app_constraints.rb`, `app/helpers/application_helper.rb`, `config/initializers/01_variables.rb`, `node_modules/react-router/{Switch,Redirect}.js`, `node_modules/react-query/lib/core/{query,queryObserver}.js`.

---

## 1. The React entry points

`app/javascript/packs/` contains six pack files. Full mapping:

| Pack | Imports app code | Rails layout that mounts it | Rails controller/action(s) | App |
|---|---|---|---|---|
| `ats_application.js` (`:18` `import "../ats/src"`) | `ats/src` | `app/views/layouts/application.html.erb:95` | `Hire::PagesController#root` (+ `#login`, `#auth`, `#auth_register`, `#register`, `#password_reset`, `#request_password_reset`, `#verify_email`, all of which `render template: 'hire/pages/root'` at `hire/pages_controller.rb:29`) | **ats / hire** |
| `account_application.js` (`:18` `import "../account/src"`) | `account/src` | `app/views/layouts/account_application.html.erb:58` | `Account::PagesController#root` (`routes.rb:546`, `:558`) | account |
| `connect_application.js` (`:18` `import "../connect/src"`) | `connect/src` | `app/views/layouts/connect_application.html.erb:57` | `Connect::PagesController#root` (`routes.rb:563-564`) | connect (out of scope) |
| `job_board_application.js` (`:23-29`, Stimulus + Turbolinks, **no React**) | `job_board/stimulus/controllers` | `app/views/layouts/job_board_application.html.erb:81`; also directly in `app/views/hire/errors/not_found_404.html.erb:6`, `internal_error_500.html.erb:6`, `app/views/job_board/errors/*.erb:6` | `JobBoard::*`, and **`Hire::ErrorsController`** | job_board |
| `job_board_form_application.js` (`:12` `import "../job_board/src"`) | `job_board/src` | `app/views/application/_react_apply_form.html.erb:2` (partial, `defer`) | job board apply form | job_board |
| `individual_application.js` (Turbolinks only; the React import at `:33` is **commented out**) | — | `app/views/layouts/individual_application.html.erb:21` | `IndividualApp::*` (`routes.rb:671-693`) | individual |

Notes worth carrying into the spec:

- **`hire/pages/root.html.erb` has no `javascript_pack_tag` of its own** — lines 8 and 10 are both ERB comments (`<%#=`). The pack comes entirely from the layout, `app/views/layouts/application.html.erb:95-96`. Any Rails-side change to what the hire HTML response contains lands in `application.html.erb`, which is the **default** layout — `Hire::BaseController` declares no `layout`, unlike `Account::BaseController:4` and `Connect::BaseController:4`.
- `application.html.erb:73-92` is the server→client injection block: `window.APP_ATS_ROOT_URL`, `window.POSTHOG_API_KEY`, `window.SERVER_ENV`, `window.IS_TEST_ENV`, `window.AI_CREDIT_ALLOCATIONS`, etc. **No user identity is injected here** (see §3).
- The hire 404/500 pages load the **job_board** pack, not the ats pack (`app/views/hire/errors/not_found_404.html.erb:6`), and `Hire::ErrorsController` sets `layout false` (`hire/errors_controller.rb:6`). React never mounts on a hire 404. `config/application.rb:78` sets `config.exceptions_app = routes`, so an unrouted hire path reaches these.

## 2. The authenticated mount points

There are **two** `CurrentSessionProvider` render sites and they serve **different apps**. They are neither nested nor siblings — they live in separate React roots reached by separate full page loads.

### 2a. `app/javascript/ats/src/views/layouts/AppAuthRouter.tsx:419` — the **hire** provider

Render path upward: `AppAuthRouter.tsx:419` ← `AppAuthed` (`:65`) ← `AuthedLogoutDecision` (`:533-542`) ← `withRouter(...)` default export (`:544`) ← `App.tsx:49` ← `ats/src/index.js:27` ← `hire/pages/root.html.erb:1` (`<div id="root">`).

Wrappers between: `ThemeProvider` (`:410`) → `Styled.AppWrapper` (`:417`) → `WindowSizeProvider` (`:418`) → **`CurrentSessionProvider` (`:419`)** → `Sentry.ErrorBoundary` (`:423`) → `GlobalChannelContextProvider` (`:424`) → `ToastProvider` (`:425`) → `ModalProvider` (`:426`) → loading branch (`:427`) → `<Switch>` (`:430`).

Conditions:
- It renders on **every** location the hire pack serves, authed or not — it sits **above** the `isLoadingUser || isLoadingOrganization` branch at `:427`, so it also renders during the initial `/api/v1/me` round trip, with `currentUser === undefined`.
- **The one exception:** `AuthedLogoutDecision` (`:537`) — `if (props.location.pathname.includes("/logout")) return <Logout {...props} />`. On `/logout`, `AppAuthed` is never rendered, so `CurrentSessionProvider` never mounts. That is a substring test, so any path *containing* `/logout` bypasses it.
- When conditions aren't met (loading): children are `<LoadingIndicator label="Loading..." />` (`:428`) — but still inside the provider.

### 2b. `app/javascript/shared/layouts/AppAuthedWrapper.tsx:35` — the **account** (and connect) provider

Render path upward: `AppAuthedWrapper.tsx:35` ← `account/src/App.tsx:10` ← `account/src/index.js:10` ← `account/pages/root.html.erb:1`. Identical shape for connect at `connect/src/App.tsx:10`.

Grep confirms `AppAuthedWrapper` has exactly two importers — `account/src/App.tsx:3` and `connect/src/App.tsx:3`. **The hire app never imports it.**

Conditions:
- `AppAuthedWrapper.tsx:30-32`: `if (isLoadingUser || isLoadingOrganization) { return <LoadingIndicator label="Loading..." />; }` — this returns **before** the provider. So unlike the hire provider, the account provider does **not** render during the `/me` round trip.
- After loading, `:35` renders the provider unconditionally (even if `currentUser` came back undefined).

### The decisive question

**Yes — for the hire app there is a single component every authenticated hire view passes through: `AppAuthed`, `app/javascript/ats/src/views/layouts/AppAuthRouter.tsx:65`, and the `CurrentSessionProvider` it renders at `AppAuthRouter.tsx:419`.** Every hire route in `routes.rb:567-665` that goes `to: 'pages#root'` renders the same HTML shell and the same React root, and `AppAuthed` is the only component below `<BrowserRouter>` that all of them traverse.

Caveats that make it "single mount point, with holes":

1. **`/logout` skips it** (`AppAuthRouter.tsx:537`). `/logout` is a Rails route (`routes.rb:600`) reached by full page load from `PolymerBar.tsx:205` (`<a href="/logout">`) and from the 401 handler (`useMe.ts:89`). A signed-in user is authenticated on that request.
2. **The account app has its own provider** (`AppAuthedWrapper.tsx:35`). `/account`, reached from `PolymerBar.tsx:186` (`<a href="/account">`) and as the Stripe billing-portal default `return_url` (`app/controllers/api/v1/billing_controller.rb:21`, `:292`, `:340`), is a full page load out of the hire SPA into a different pack. A hire-only mount point would not fire there.
3. **Hire 404/500 pages mount no React at all** (`app/views/hire/errors/not_found_404.html.erb:6` loads `job_board_application`, which contains no React).

Which hire views reach which: all of `routes.rb:598-664` (`/jobs`, `/jobs/:job_id/...`, `/candidates`, `/notifications`, `/interviewer`, `/admin/:admin_view`, `/hire/settings/*path`, `/organization/new`, `/organization/manage`, `/deactivated`, `/needs-email-confirmation`, `/onboarding/profile`, `/plans`, `/preview/jobs/:job_id`, `/applicants/...`, `/boards/...`) reach `AppAuthed` → hire provider. Only `/account` (`routes.rb:546`, `:558`) reaches the account provider. Only `/connect` (`routes.rb:563-564`) reaches the connect provider.

## 3. How the frontend obtains `currentUser`

**Fetched over the API after mount. Not server-injected. There is no `gon`, no `window.__INITIAL_STATE__`, no `data-` attribute, no `current_user` reference anywhere in `app/views/`** (grep for `gon.`, `__INITIAL_STATE__`, `window.currentUser`, `data-current-user`, `current_user` across `app/views/` returns nothing; `gon` is not in the Gemfile).

The chain:

- Hook: `useGetMe` — `app/javascript/shared/queryHooks/useMe.ts:57-93`. `useQuery("me", getMe, {...})` at `:71`.
- Fetcher: `getMe` — `useMe.ts:8-10` → `apiGet({ path: "/me" })`.
- Transport: `apiGet` — `app/javascript/shared/queryHooks/api.ts:5-23`, `axios.get("/api/v1/me")`, response run through `allKeysToCamel` (`:22`).
- Endpoint: `config/routes.rb:93` → `Api::V1::MeController#show` (`app/controllers/api/v1/me_controller.rb:5-9`) → `render_one(current_user, Api::V1::SessionSerializer)`.
- `id` is the **first** serialized attribute: `app/serializers/api/v1/session_serializer.rb:5`. So `currentUser.id` is the `User#id`.
- Auth: `app/controllers/api/v1/base_controller.rb:6` `before_action :authenticate_api_v1_user!`.

Call sites of `useGetMe`:
- Hire: `AppAuthRouter.tsx:76` — `useGetMe({ enabled: !isUnauthedRoute, refetchOnWindowFocus: !isUnauthedRoute })`, where `isUnauthedRoute = UNAUTHED_ROUTES.includes(location.pathname)` (`:74`, list at `:55-63`).
- Account/connect: `AppAuthedWrapper.tsx:22` — `useGetMe({ refetchOnWindowFocus: true })`.
- `PolymerBar.tsx:129` — `useGetMe({})`; same `"me"` query key, so it is deduped against whichever provider already fetched.

**Timing — the authenticated tree renders BEFORE the network round trip completes, and `currentUser.id` is NOT available synchronously at mount.**

- Verified against installed react-query 3.13.10: for an enabled query with no cached data, `shouldLoadOnMount` is true (`node_modules/react-query/lib/core/queryObserver.js:500`), so the optimistic result sets `status = 'loading'` (`:286-295`) and `isLoading: status === 'loading'` (`:350`). First render of `AppAuthed` therefore has `currentUser === undefined` and `isLoadingUser === true`.
- What renders during loading: **hire** — `CurrentSessionProvider` mounts with `currentUser={undefined}` and its children are `<LoadingIndicator label="Loading..." />` (`AppAuthRouter.tsx:427-428`). **account/connect** — `<LoadingIndicator/>` returned *before* the provider (`AppAuthedWrapper.tsx:30-32`), so the provider is not mounted yet.
- On an **unauthed** hire route (`/auth`, `/login`, `/register`, `/verify-email`, `/password-reset`, `/request-password-reset`, `/auth-register` — `AppAuthRouter.tsx:55-63`), `enabled: false` ⇒ `shouldLoadOnMount` returns false at `queryObserver.js:500` (`options.enabled !== false` fails) ⇒ status stays `'idle'` (`node_modules/react-query/lib/core/query.js:392`) ⇒ `isLoading` false ⇒ the `<Switch>` renders immediately with `currentUser === undefined`. **No `/me` request is made on those paths at all.**

Redux is vestigial here: `ats/src/index.js:27` passes `store={store}` into `<App>`, but `App.tsx` never wraps anything in a react-redux `<Provider>` — `props` is only used for a `window.logger` call (`App.tsx:28-31`). There is no redux-sourced `currentUser`.

Organization data: `useOrganization(organizationId)` — `app/javascript/shared/queryHooks/useOrganization.ts:104-118`, `useQuery(["currentOrganization", organizationId], ...)`. `getOrganization` no-ops when the id is undefined (`:30-35`). Feature flags: `useFeatureFlippers()` — `useFeatureFlippers.ts:43-52`, `GET /api/v1/flipper/features` (Flipper API mounted at `routes.rb:76`).

## 4. Every frontend redirect for a signed-in user

**All of them are client-side.** `<Redirect>` → `history.replace` (`node_modules/react-router/Redirect.js:70-82`); `history.push` → HTML5 pushState via `BrowserRouter` (`App.tsx:36`). Grep found **zero** `history.replace(` call sites and **zero** `<Navigate` (v6 API) in `app/javascript/`. React stays mounted through every one of these.

### 4a. Session/gate redirects in `AppAuthRouter.tsx` (all client-side, all `history.replace`)

| file:line | Condition | Source route | Destination |
|---|---|---|---|
| `AppAuthRouter.tsx:216` | `currentUser.currentOrganizationUser.isActive === false` and path ≠ `/organization/manage` (`:212-215`) | any | `/organization/manage` |
| `AppAuthRouter.tsx:273` | `currentUser.hasConfirmedEmail` and path === `/needs-email-confirmation` (`:271-272`) | `/needs-email-confirmation` | `/jobs` |
| `AppAuthRouter.tsx:285` | `!currentUser.hasConfirmedEmail` and path ≠ `/needs-email-confirmation` (`:279`) | any | `/needs-email-confirmation` |
| `AppAuthRouter.tsx:309` | `currentUser.hasCompletedProfile` and path === `/onboarding/profile` (`:307-308`) | `/onboarding/profile` | `redirectPath` = `?path` param, else `/interviewer` for `org_interviewer`, else `/jobs` (`:203-205`) |
| `AppAuthRouter.tsx:323` | `!currentUser.hasCompletedProfile` and path ≠ `/onboarding/profile` (`:315`) | any | `/onboarding/profile` (+ `?path=<current>` unless current is `/`, `/jobs`, `/interviewer` — `:319-322`) |
| `AppAuthRouter.tsx:342` | `currentUser.hasConfirmedEmail && organizationId == undefined` and path ≠ `/organization/new` (`:340-341`) | any | `/organization/new` |
| `AppAuthRouter.tsx:359` | path starts with `/admin/` and role ≠ `god_admin` (`:355-358`, `startsWith` from `ats/src/lib/utils/helpers.js:12`) | `/admin/*` | `/jobs` |
| `AppAuthRouter.tsx:371` | `currentUser.email` present and path ∈ `UNAUTHED_ROUTES` (`:370`) | `/auth`, `/login`, `/register`, … | `/jobs` |
| `AppAuthRouter.tsx:406` | `needsHandleAcceptInvite` — reached from `/register` when `currentUser != undefined` (`:381-386`); fires `acceptInvite` mutation first if `?invite_token` present (`:394-404`) | `/register` | `/jobs` |
| `AppAuthRouter.tsx:479` | `location.pathname === "/" && hasUser` (`:478`; `hasUser` at `:81`) | `/` | `defaultPath` (`/interviewer` or `/jobs`, `:203-204`) |

Every one of these helpers returns `null` when `currentUser == undefined` (`:208-210`, `:267-269`, `:303-305`, `:336-338`, `:351-353`, `:366-368`) — so none of them fire during the `/me` round trip.

### 4b. Role/layout redirects in `AppContainer.tsx` (client-side)

| file:line | Condition | Destination |
|---|---|---|
| `AppContainer.tsx:59` | `location.pathname === "/hire/settings"` and `currentOrganizationUser.isAdmin` (`:56-57`) | `/hire/settings/organization` |
| `AppContainer.tsx:63` | `location.pathname === "/hire/settings"` and not admin | `/hire/settings/preferences` |
| `AppContainer.tsx:73` | role `org_interviewer` and path is not `reviews/new` or `interviewer` (`:70-72`) | `/interviewer?message=error` |

Note `AppContainer.tsx:77-79`: `if (currentUser == undefined) return null;` — a hard `null` render, below `CurrentSessionProvider`.

### 4c. Nested-view default redirects (client-side, all `${match.url}`-relative)

`AccountIntegrationsContainer.tsx:154` → `${match.url}/googleanalytics`; `AccountJobBoardContainer.tsx:224` → `${match.url}/branding`; `AccountPlatoAiContainer.tsx:83` → `${match.url}/billing`; `JobApplicationContainer.tsx:181`, `:188`, `:190`, `:291`, `:293`; `JobApplicationListContainer.tsx:367` → first job application; `JobSetupContainer.tsx:496` → `${match.url}/details`; `JobStagesContainer.tsx:192` → first hiring stage's applicants; `JobDistributionContainer.tsx:78` → `${match.path}/weworkremotely`; `JobStripeCheckoutRedirectHandler.tsx:108` → `redirectUrl` from the `redirect_url` query param (`:28`, `:54`).

`shared/routing/DesktopRedirector.tsx:20` and `:24` — viewport-width-driven redirects (`useMedia({ query: "(max-width: 640px)" })` at `:16`); used by `account/src/routes.tsx:17` and `connect/src/views/Connect.tsx:34`. Client-side.

### 4d. `history.push` inventory (all client-side)

71 grep hits for `history.push|history.replace|useHistory`; no `history.replace` among them. Session-relevant ones: `Auth.tsx:39` → `/needs-email-confirmation`, `Auth.tsx:49` → `/verify-email?e=<base64 email>`; `AuthRegister.tsx:75`, `:85` (same pair); `Login.tsx:29` → `/jobs`; `Signup.tsx:13` → `/jobs`; `OnboardingProfile.tsx:38` → `/jobs`; `NewOrganization.tsx:44` → `/jobs`; `OrganizationSwitcher.tsx:69` → `/jobs`; `PasswordReset.tsx:74` → `/login`; **`Logout.tsx:22` / `:24` → `/auth`** (after the logout mutation resolves). The rest are in-app navigation (job/candidate/settings/admin views, `NavBar.tsx:62/76/83`, `UnsavedChangesGuard.tsx:36`, `UniversalSearch.tsx:261`, `NotificationListItem.tsx:97`, modal CTAs).

### 4e. Full-page-load "redirects" from the frontend — see §7 and §9

`useMe.ts:89`, `AccountRemoval.tsx:75`, `AdminDashboardCustomers.tsx:89`, `AdminDashboardFreeJobs.tsx:89`, `AdminUsersSearch.tsx:43`, and the Stripe/OAuth `window.location.href = data.redirectUrl` set.

## 5. Route guards in React

There is **no** `PrivateRoute` / `RequireAuth` / `ProtectedRoute` component anywhere in `app/javascript/`. Guarding is done by the seven `needs*Route()` helper functions inside `AppAuthed` and by two bare `null` returns. Each, and whether it is a coverage gap for a **frontend-set** cookie placed at `CurrentSessionProvider`:

| Guard | file:line | Renders on failure | Covered / gap |
|---|---|---|---|
| `AuthedLogoutDecision` | `AppAuthRouter.tsx:533-542` | `<Logout/>` **instead of** `AppAuthed` | **GAP** — `CurrentSessionProvider` never mounts on `/logout`. The user is still authenticated for that Rails request and for the `DELETE /api/v1/logout` that follows. |
| loading branch | `AppAuthRouter.tsx:427-428` | `<LoadingIndicator/>` inside the provider | **Covered** for provider mount, **but `currentUser` is `undefined`** at that moment. A cookie write must key on `currentUser?.id` becoming defined, not on mount. |
| `needsHandleDeactivatedRoute` | `AppAuthRouter.tsx:207-218` | `<Redirect to="/organization/manage"/>` (client-side) | Covered — provider is above the `<Switch>` |
| `needsGodAdminRoute` | `:350-363` | `<Redirect to="/jobs"/>` | Covered |
| `needsEmailConfirmationRoute` | `:260-297` | `<Redirect to="/needs-email-confirmation"/>` or the `/needs-email-confirmation` `<Route>` | Covered |
| `needsOnboardingProfileRoute` | `:299-333` | `<Redirect to="/onboarding/profile…"/>` or the `/onboarding/profile` `<Route>` | Covered |
| `needsNewOrganizationRoute` | `:335-348` | `<Redirect to="/organization/new"/>` | Covered |
| `needsRedirectToJobsRoute` | `:365-374` | `<Redirect to="/jobs"/>` | Covered |
| `AppContainer` no-user bail | `AppContainer.tsx:77-79` | `null` | Covered — this is **below** the provider |
| `AppAuthedWrapper` loading bail | `AppAuthedWrapper.tsx:30-32` | `<LoadingIndicator/>` **before** the provider | **GAP** for the account/connect apps: on the loading render the provider is not mounted. It mounts on the next render, so this is a delay, not a permanent hole. |
| `FeatureFlipper` | `ats/src/components/shared/FeatureFlipper.tsx:64-91` | `null` | Not a route guard — wraps UI fragments. Ruled out. |
| `useFeatureGate` / `usePlanLimitsGate` / `useAddActiveUserGate` | `shared/hooks/useFeatureGate.ts:46-154`, `usePlanLimitsGate.ts:23-`, `useAddActiveUserGate.ts:22-` | Return `{isLocked, modalType, …}` objects consumed by buttons/modals | Not route guards — they gate **actions**, not routes. Ruled out. |
| `DesktopRedirector` | `shared/routing/DesktopRedirector.tsx:19-25` | `<Redirect>` | Account/connect only; client-side. Covered. |

There is **no subscription/plan route guard** — `stripeSubscriptionInGoodStanding` is read at `AppAuthRouter.tsx:138-140` but only fed to Heap (`:153`) and Intercom (`:196`), never to a redirect.

## 6. The seam, Rails → React

**There is no catch-all/wildcard route feeding the hire SPA.** Every hire deep link has its own explicit Rails route. `config/routes.rb:585-587` shows the wildcard was attempted and is **commented out**:

```ruby
# get '*any_other_path', to: "pages#root", constraints: lambda { |req|
#   req.path.exclude? 'rails/active_storage'
# }
```

Instead `routes.rb:598-664` enumerates ~55 explicit `get … to: 'pages#root'` lines. Contrast: connect **does** have a wildcard (`routes.rb:564` `get '*path', to: 'pages#root'`); account has a single-segment catch (`routes.rb:558` `get ':path', to: 'pages#root'`, with the comment at `:557` explaining why a greedy `*path` is impossible there — Active Storage attachments).

Rails routes that render a React-mounting view, for hire:
- `routes.rb:568` `root to: 'pages#root', as: :app_root`
- `routes.rb:599-664` — all the `pages#root` lines
- `routes.rb:590-596` — `pages#login/#auth/#auth_register/#register/#password_reset/#request_password_reset/#verify_email`, each of which renders the *same* template via `redirect_if_authed`'s else-branch (`hire/pages_controller.rb:29`)

**Hard refresh of `/jobs/123`:** matched by `routes.rb:611` `get 'jobs/:job_id', to: 'pages#root'` → `Hire::PagesController#root` (`hire/pages_controller.rb:6`, an empty action) → default layout `application.html.erb` → `ats_application` pack → React mounts → `BrowserRouter` reads `window.location.pathname` → `AppAuthed` → `<Route path="/jobs/:jobId">` in `AppContainer.tsx:146`.

**Does the Rails route require authentication? No.** `Hire::PagesController` has exactly one `before_action`: `redirect_if_authed, except: %i[root]` (`hire/pages_controller.rb:4`). `#root` is **excepted**, and `Hire::BaseController` (`hire/base_controller.rb:3-5`) adds only `skip_before_action :track_ahoy_visit`. `ApplicationController` has no `authenticate_*!` before_action. **A signed-out user hitting `/jobs/123` gets a 200 HTML page with the SPA on it**; the bounce happens client-side when `GET /api/v1/me` 401s (§7).

`redirect_if_authed` (`hire/pages_controller.rb:24-31`) is the inverse guard, and it applies **only** to the seven unauthed page actions: a signed-in user requesting `/auth`, `/login`, `/register`, `/auth-register`, `/password-reset`, `/request-password-reset`, or `/verify-email` is 302'd to `app_root_path` (`/`) — **query params are dropped**, and the only exemption is `params.key?(:invite_token)` (`:26`).

**Deep links with no matching route** (e.g. `/jobs/123/unknown`) raise `ActionController::RoutingError`; `config/application.rb:78` `config.exceptions_app = routes` routes it to `routes.rb:570` `get '404', to: 'errors#not_found_404'` → `Hire::ErrorsController#not_found_404` with `layout false` (`hire/errors_controller.rb:6`) rendering `app/views/hire/errors/not_found_404.html.erb`, which loads the **job_board** pack (`:6`). React (ATS) does not mount.

**History mode:** `App.tsx:36` uses `<BrowserRouter>` (HTML5 history, no basename) for hire; `account/src/routes.tsx:14` uses `<BrowserRouter basename="/account">`. Yes, this depends on Rails serving the shell at each deep path — and no, that Rails route does not require authentication.

## 7. The seam, React → Rails (401 / 403 handling)

**There is no axios interceptor.** `grep -rn "interceptors" app/javascript/` returns nothing. `app/javascript/shared/queryHooks/api.ts` is the only api layer (`api.ts:1-68`); it configures no global response handler. `apiMutate`'s `.catch` (`api.ts:54-63`) only reshapes the error and re-rejects — it does not branch on status.

401 handling lives in a **single per-query callback**, in `useGetMe`:

```ts
// app/javascript/shared/queryHooks/useMe.ts:71-92
return useQuery("me", getMe, {
  enabled,
  refetchOnWindowFocus,
  retry: (failureCount, error) => !error.message.includes(401),      // :74
  onSettled: () => {},
  onError: (error) => {
    const search = new URLSearchParams(window.location.search);      // :77
    const isAcceptingAnInvite = search?.has("invite_token");         // :78
    if (!isAcceptingAnInvite) {                                      // :80
      const noredirectPaths = ["/", "/jobs", "/interviewer"];        // :85
      const queryParams = !noredirectPaths.includes(window.location.pathname)
        ? `?path=${window.location.pathname}` : "";                  // :86-88
      window.location.href = `${window.APP_ATS_ROOT_URL}/logout${queryParams}`;  // :89
    }
  },
});
```

- **`useMe.ts:89` is a FULL PAGE LOAD.** `window.location.href = …` on the absolute `window.APP_ATS_ROOT_URL` (injected at `application.html.erb:74` from `Variables::AtsRootUrl`, `config/initializers/01_variables.rb:19`). The browser leaves React and re-enters Rails at `routes.rb:600` `get 'logout', to: 'pages#root'`.
- The retry guard at `:74` matches axios's error message string ("Request failed with status code 401"), so a 401 does not retry — `onError` fires on the first failure.
- `useMyInvites` has the same handler **commented out** (`useMe.ts:106`).
- **403 is not handled anywhere on the frontend.** `ApplicationController#user_not_authorized` (`app/controllers/application_controller.rb:15-17`) renders `{errors: [...]}, status: 403` for `Pundit::NotAuthorizedError`; nothing in `app/javascript/` branches on 403.
- The legacy redux fetch layer `app/javascript/ats/src/lib/api/index.js:28-32` detects `response.status === 401` but the redirect is **commented out** (`:31`) and there is a `// TODO handle 401` (`:30`).

**Session expiring mid-SPA-session ⇒ full reload.** `useGetMe` is configured `refetchOnWindowFocus: !isUnauthedRoute` in hire (`AppAuthRouter.tsx:78`) and `true` in account (`AppAuthedWrapper.tsx:22`). Re-focusing the tab after the Devise session expires refetches `/me`, gets a 401, and `useMe.ts:89` navigates the whole browser to `/logout`.

`/logout` then: Rails serves `pages#root` (no auth check) → React mounts → `AuthedLogoutDecision` (`AppAuthRouter.tsx:537`) short-circuits to `<Logout/>` → `Logout.tsx:12-28` fires `DELETE /api/v1/logout` (`useSession.ts:12-14`, `routes.rb:85`) → on success `resetUser()` (PostHog, `shared/lib/posthog.ts:52-57`), `queryCache.clear()`, then `history.push("/auth")` (`Logout.tsx:22`/`:24`, client-side). Note `Logout.tsx:20` records that the previous implementation was a hard `window.location.href` and it was deliberately replaced with a push.

## 8. Couplings — backend state determining frontend routing, and vice versa

### 8a. Backend state → frontend routing (CONFIRMED)

Every one of these is a field on the `/api/v1/me` or `/api/v1/organizations/:id` payload that the hire router branches on. Backend source → frontend consumer → routing outcome:

| # | Backend source | Frontend consumer | Routing outcome |
|---|---|---|---|
| 1 | `Api::V1::SessionSerializer:15` `:has_confirmed_email` | `AppAuthRouter.tsx:271`, `:340` | forces `/needs-email-confirmation`; and gates whether the no-org redirect can fire at all |
| 2 | `Api::V1::SessionSerializer:16` `:has_completed_profile?` | `AppAuthRouter.tsx:307`, `:315` | forces `/onboarding/profile`, stashing the intended path in `?path=` |
| 3 | `Api::V1::SessionSerializer:25` `:organization_id` (from the organization_user) | `AppAuthRouter.tsx:80` → `:341` | `organizationId == undefined` forces `/organization/new`; also keys `useOrganization` (`:89-91`) |
| 4 | `Api::V1::SessionSerializer:40` `belongs_to :current_organization_user` → its `role` | `AppAuthRouter.tsx:204` (`defaultPath`), `:357` (god_admin gate), `AppContainer.tsx:72` (interviewer gate) | picks `/interviewer` vs `/jobs` as the post-auth landing; blocks `/admin/*`; pins interviewers to `/interviewer` |
| 5 | same serializer → `is_active` on the organization_user | `AppAuthRouter.tsx:213` | forces `/organization/manage` |
| 6 | same → `is_admin` | `AppContainer.tsx:57` | `/hire/settings` → `…/organization` vs `…/preferences` |
| 7 | `Api::V1::SessionSerializer:11` `:email` | `AppAuthRouter.tsx:303` (`!currentUser?.email` ⇒ helper returns `null`), `:370` | a user with no email suppresses the onboarding gate entirely; a user *with* an email on an unauthed route is bounced to `/jobs` |
| 8 | `current_organization` payload `plan` / `stripeSubscriptionInGoodStanding` | `AppAuthRouter.tsx:138-141`, `:165` | **NOT routing** — fed only to Heap (`:153`), PostHog (`:172`), Intercom (`:196`). Explicitly ruled out as a route gate. |
| 9 | Flipper API `GET /api/v1/flipper/features` (`routes.rb:76`) → `useFeatureFlippers.ts:51` | `AppAuthRouter.tsx:128-134` → `featureFlipperStore.ts:11-13` → `FeatureFlipper.tsx:66-90` | **NOT routing** — `FeatureFlipper` returns `null` around UI fragments only; grep shows its only consumers are component-level. Ruled out. |
| 10 | `Variables::AtsRootUrl` (`config/initializers/01_variables.rb:19`) → `application.html.erb:74` `window.APP_ATS_ROOT_URL` | `useMe.ts:89` (401 bounce), `ats/src/websockets/WebsocketContext.tsx:11` (ActionCable consumer URL) | a misconfigured `ats_root_url` sends the 401 bounce cross-origin |
| 11 | `rescued_csrf_meta_tags` (`application.html.erb:5` → `app/helpers/application_helper.rb:4-9`, which calls `request.reset_session` on `ArgumentError`) | `api.ts:50` `Rails.csrfToken()`; `shared/hooks/useCSRFToken.ts:3-9`, `:21-30` (re-fetches `/auth` HTML and re-scrapes the meta tag) | a stale token makes every mutation fail; `useCSRFToken` deliberately fetches a Rails HTML page mid-SPA to refresh it (`GoogleSSOButton.tsx:48`, `:54`) |
| 12 | `?invite_token` in the URL | `AppAuthRouter.tsx:68` `isAcceptingAnInvite`, `:394-404` (fires the `acceptInvite` mutation) → `:406` `<Redirect to="/jobs"/>`; and `useMe.ts:78-80` (suppresses the 401 bounce) | invite acceptance is the one case where a 401 does **not** cause a full page load |
| 13 | `?path=` query param | `AppAuthRouter.tsx:205` `redirectPath`; written by `AppAuthRouter.tsx:320-322`, `useMe.ts:86-88`, `Logout.tsx:19-22`; read by `AuthForm.tsx:35` | the deep link a user was trying to reach survives the logout/onboarding round trip |
| 14 | `?checkout=success&session_id=…` written by Rails Stripe callbacks (`app/controllers/api/v1/billing_controller.rb:75-76`, `organization_ai_credit_purchases_controller.rb:40-41`, `:192-193`, `board_what_jobs_listings_controller.rb:257-258`) | `JobStripeCheckoutRedirectHandler.tsx:28` → `:108` `<Redirect to={redirectUrl}/>`; `AccountBilling.tsx:69`; `OrganizationAiBilling.tsx:18` | the return leg of Stripe Checkout is a full page load into a Rails route whose query params then drive a client-side redirect |
| 15 | `?email_confirmed=true` set by `Hire::ConfirmationsController#show` (`app/controllers/hire/confirmations_controller.rb:18`, `:21`) | `Auth.tsx:23-28`; `AuthRegister.tsx:59`; `Login.tsx:20` | shows a banner — **but see the next row** |
| 16 | `Hire::PagesController#redirect_if_authed` (`hire/pages_controller.rb:4`, `:24-31`) | — | **A signed-in user requesting `/auth?email_confirmed=true` is 302'd to `/` server-side and the query param is discarded. `Auth.tsx` never renders.** This is the coupling the repo owner is warning about, and it is already recorded as pipeline rule 29. Only the `invite_token` param exempts. |
| 17 | `cookies[:account_referrer]` set by `Account::PagesController#root` (`app/controllers/account/pages_controller.rb:5`); `cookies[:connect_referrer]` by `Connect::PagesController#root` (`connect/pages_controller.rb:7`) | `shared/hooks/useReferrerCookie.ts:3-17` via `shared/hooks/useCookieValue.ts:3-13`; consumed at `account/src/views/Account.tsx:12` and `connect/src/views/Connect.tsx:15`, rendered as `NavBar.tsx:131` `<StyledButton href={externalUrl} as="a">` | **A server-set cookie already drives a frontend navigation target in this codebase, and the navigation it produces is a full page load** (`as="a"` + `href`, not a `<Link>`). This is the closest existing precedent for "Rails writes a cookie, React reads it". |
| 18 | `after_sign_in_path_for` (`app/controllers/application_controller.rb:142-148`) returns `root_path` for non-`AdminUser` | — | Under `SubdomainAppConstraints` `root_path`/`app_root_path` is `hire#pages#root` (`routes.rb:568`), which React then re-redirects: `AppAuthRouter.tsx:478-480` `location.pathname === "/" && hasUser` ⇒ `<Redirect to={defaultPath}/>`. **Confirmed: a Rails redirect lands on a path the React router immediately re-redirects.** Same pattern for `Api::V1::Users::OmniauthCallbacksController#google_oauth2` → `redirect_to "#{Variables::AtsRootUrl}/"` (`:49`). |
| 19 | `MagicLinksController#validate` (`app/controllers/magic_links_controller.rb:28`) `redirect_to @magic_link.redirect_to \|\| '/jobs?magic=not_found'` (`redirect_to` column set from `params[:redirect_to]` at `app/controllers/api/v1/registrations_controller.rb:151`, which comes from `useSession.ts:132` `redirectTo`) | the landing route's React tree | **Frontend-supplied value round-trips through the database and comes back as a Rails 302.** |
| 20 | `Hire::RedirectorController` (`app/controllers/hire/redirector_controller.rb:13`, `:15`, `:18`, `:27`, `:30`, `:33`) | — | Rails 301/302s legacy candidate URLs onto React paths (`/jobs/:id/stages/:id/applicants/:id/...`), always as a full page load |
| 21 | `window.SERVER_ENV` (`application.html.erb:85`), `window.IS_TEST_ENV` (`:83`) | `ats/src/index.js:14`, `shared/hooks/useSentry.ts:7`, `shared/PostHogContext.tsx:31` | backend env value suppresses Sentry init and PostHog init |

Explicitly **ruled out** as backend→routing couplings, with evidence: subscription/plan status (row 8), Flipper flags (row 9), `ColorSchemeContext` (localStorage via `use-persisted-state`, `shared/context/ColorSchemeContext.tsx:9`, no cookie, no server input), redux (`ats/src/index.js:27` passes a store that `App.tsx` never provides).

### 8b. Frontend routing → forced backend request

- `<a href="/account">` (`PolymerBar.tsx:186`, and dead `UserNav.tsx:99`) — a nav item in the *hire* SPA that is a **full document request** to `Account::PagesController#root`.
- `<a href="/organization/manage">` (`PolymerBar.tsx:183`, currently inside a commented-out block) vs `<Link to="/organization/manage">` (`AppHeader.tsx:86`, client-side) — the same destination reached two different ways.
- `<a href="/admin/dashboard">` (`PolymerBar.tsx:191`) — full page load, and `routes.rb:606` `get 'admin', to: redirect('/admin/dashboard')` adds a Rails redirect in front of it.
- `<a href="/logout">` (`PolymerBar.tsx:205`) — full page load into `pages#root`.
- `useCSRFToken.refreshCsrfToken` (`shared/hooks/useCSRFToken.ts:21-30`) — a `fetch("/auth?_=<ts>")` for the **HTML** document mid-SPA-session, purely to re-scrape the CSRF meta tag. For a signed-in user that request is 302'd by `redirect_if_authed` to `/` and the scrape reads `/`'s meta tag instead. Called from `GoogleSSOButton.tsx:54`.
- `<a href="javascript:window.location.reload()">` in the update banner (`AppContainer.tsx:90`, `AppAuthedWrapper.tsx:47`) — triggered by the `UPDATE_AVAILABLE` websocket message (`WebsocketGlobalChannelHandler.tsx:204-206`).

## 9. Full-page-load inventory

Every path where the browser leaves React and Rails handles a request without the ATS React tree mounting (or with it re-mounting from scratch):

| # | Trigger | file:line | Rails endpoint reached | Does ats React re-mount after? |
|---|---|---|---|---|
| 1 | 401 on `/me` → logout bounce | `shared/queryHooks/useMe.ts:89` | `routes.rb:600` `pages#root` | Yes, but `AuthedLogoutDecision` renders `<Logout/>`, **not** `AppAuthed` |
| 2 | "Log out" menu item | `shared/components/PolymerBar.tsx:205` | `routes.rb:600` `pages#root` | same as above |
| 3 | "Account settings" menu item | `shared/components/PolymerBar.tsx:186` | `routes.rb:558` `Account::PagesController#root` | No — the **account** pack mounts instead |
| 4 | "Admin - Dashboard" menu item | `shared/components/PolymerBar.tsx:191` | `routes.rb:606` redirect → `:607` `pages#root` | Yes |
| 5 | "Your organizations" (commented-out variant) | `shared/components/PolymerBar.tsx:183` | `routes.rb:603` `pages#root` | Yes |
| 6 | Account deletion | `account/src/views/AccountRemoval.tsx:75` | `${APP_ATS_ROOT_URL}/auth?account_deleted=success` → `routes.rb:591` `pages#auth`; **`redirect_if_authed` 302s to `/` if the session survives** | Yes |
| 7 | Google SSO form POST | `ats/src/views/sessions/components/GoogleSSOButton.tsx:58` (`formElement.submit()`), form at `:62` | `POST /api/v1/users/auth/google_oauth2` (omniauth request phase) | No — leaves the origin |
| 8 | Google SSO callback return | `app/controllers/api/v1/users/omniauth_callbacks_controller.rb:49` `redirect_to "#{Variables::AtsRootUrl}/"` (failure branch `:57` → `/auth?error=authentication_failed`) | `routes.rb:568` `root to: 'pages#root'` | Yes; then `AppAuthRouter.tsx:479` re-redirects `/` → `defaultPath` |
| 9 | Integration OAuth connect (Webflow, Slack, Discord, LinkedIn, …) form POST | `shared/components/OauthConnectButton.tsx:10`; duplicate at `ats/src/views/accountAdmin/accountIntegrations/OuathConnectButton.tsx:10` | provider-specific POST, then `routes.rb:582` `get '/auth/:provider/callback'` → `Integrations::OauthAuthenticationsController#create` | Yes |
| 10 | Stripe Checkout / Customer Portal launch | `AccountBillingPlans.tsx:225`, `:264`, `:304`; `ManageBillingActions.tsx:47`; `AccountBillingPlansFreeTrial.tsx:98`; `AccountBillingPlansUnsubscribed.tsx:208`; `AiCreditSubscription.tsx:93`, `:177` | external (stripe.com) | No |
| 11 | Stripe Checkout return | Rails-generated: `billing_controller.rb:75-76`, `organization_ai_credit_purchases_controller.rb:40-41`, `:192-193`, `board_what_jobs_listings_controller.rb:257-258` | `routes.rb:612` `jobs/:job_id/stripe_checkout_redirect_handler`, or `:663` `hire/settings/*path` | Yes |
| 12 | Stripe Billing Portal return | `billing_controller.rb:21`, `:292`, `:340` — **default `return_url` is `/account`** | `routes.rb:558` `Account::PagesController#root` | No — **account** pack |
| 13 | Magic-link email click | `routes.rb:55` `get '/magic_links/validate'` → `magic_links_controller.rb:22` `sign_in`, `:28` `redirect_to @magic_link.redirect_to \|\| '/jobs?magic=not_found'` | whatever `redirect_to` holds; default `/jobs` (`routes.rb:608`) | Yes |
| 14 | Email confirmation link | `routes.rb:577` → `hire/confirmations_controller.rb:18` `redirect_to '/auth?email_confirmed=true'` | `routes.rb:591` `pages#auth`; **`redirect_if_authed` 302s a signed-in user to `/`, dropping the param** | Yes (at `/`, not `/auth`) |
| 15 | Invite accept link | `routes.rb:58` `get '/invites/accept' => 'auth/invites#accept'` | Rails | Depends on that controller's redirect |
| 16 | Legacy candidate permalinks | `routes.rb:629-630`, `:643` → `hire/redirector_controller.rb:13`, `:27` | `routes.rb:633-640` `pages#root` | Yes |
| 17 | Legacy `/account/*` settings paths | `routes.rb:547-556` — nine `redirect('/hire/settings/…')` entries | `routes.rb:663` `hire/settings/*path` → `pages#root` | Yes |
| 18 | Update-available banner "Refresh" | `AppContainer.tsx:90`, `AppAuthedWrapper.tsx:47` (`href="javascript:window.location.reload()"`); also `MaintenanceCompleteModal.tsx:17` | same URL | Yes |
| 19 | Admin org-switch actions | `AdminDashboardCustomers.tsx:89`, `AdminDashboardFreeJobs.tsx:89`, `AdminUsersSearch.tsx:43` — `window.location.href = ${APP_ATS_ROOT_URL}/jobs` | `routes.rb:608` `pages#root` | Yes |
| 20 | WWR / WhatJobs distribution OAuth | `JobDistributionWeWorkRemotely.tsx:339`, `WhatJobsSidebarActions.tsx:144` (`window.location.href = data.url`) | external, returns to `routes.rb:618` | Yes |
| 21 | Error/404 pages | `hire/errors_controller.rb:8-18`, views at `app/views/hire/errors/*.erb:6` | `routes.rb:570-572` | **No — job_board pack, no React** |
| 22 | CSV / resume / data-export downloads | toast `externalLink.href` values from `WebsocketGlobalChannelHandler.tsx:87`, `:96`, `:113`, `:122`, `:131`, `:140` | Active Storage / S3 URLs | N/A (download, not navigation) |
| 23 | `ErrorBoundaryFallback` / `FriendlyErrors` links | `ats/src/components/shared/ErrorBoundaryFallback.tsx:13`, `FriendlyErrors.tsx:57` (`<a href="/">`) | `routes.rb:568` | Yes |

## 10. Existing frontend per-mount side effects (structural analogs)

Six qualify; none are AI-related. Listed closest-analog-first for "write a cookie once per authenticated load".

### A. `useHeapAanalytics` — `app/javascript/shared/hooks/useHeapAnalytics.ts:5-17`

```ts
export default function useHeapAanalytics(currentUser: CurrentUser) {
  useEffect(() => {
    if (!currentUser) return;
    window.heap.identify(currentUser?.hashId);
    window.heap.addUserProperties({ OrganizationId: currentUser?.organizationId, … });
  }, [currentUser]);
}
```

Traits: **lives in a hook file** under `shared/hooks/`; takes `currentUser` as its only argument; `useEffect` with dependency array `[currentUser]`; guard is a bare `if (!currentUser) return;` as the first statement of the effect body; no cleanup. Called from `AppAuthedWrapper.tsx:27` — i.e. **above** the provider, in the account/connect tree.

### B. `useIntercom` — `app/javascript/shared/hooks/useIntercom.ts:5-21`

Identical shape to A: hook file, `currentUser` argument, `useEffect(…, [currentUser])`, `if (!currentUser) return;` first, then a nested `if ((window as any).Intercom)` capability check, no cleanup. Called from `AppAuthedWrapper.tsx:28`, adjacent to A.

**A and B together are the house pattern**: a one-argument `shared/hooks/use<Thing>.ts` taking `currentUser`, `useEffect` keyed on `[currentUser]`, early-return guard, invoked from the authed layout component immediately before the provider.

### C. PostHog identify — inline in `app/javascript/ats/src/views/layouts/AppAuthRouter.tsx:163-177`

```tsx
const currentPlan = currentOrganization?.plan;                 // :165
React.useEffect(() => {
  if (currentUser?.id) {                                       // :167
    identifyUser({ id: currentUser.id, email: currentUser.email,
      organizationId, organizationName, plan: currentPlan,
      organizationUserRole: currentUser.currentOrganizationUser?.role });
  }
}, [currentUser, organizationId, currentPlan, organizationName]);  // :177
```

Traits: **inline in the component, not extracted to a hook**; dependency array has four entries including two derived scalars; guard is `if (currentUser?.id)` — **it keys on `id` specifically**, which is exactly the guard shape a cookie write needs; delegates to `identifyUser` in `shared/lib/posthog.ts:17-39`, which does its own `getPosthog()` availability check (`:13-15`, `:25-29`) and returns early with a `window.logger` line when the SDK is not loaded. This is the **hire-side** equivalent of A/B and the single best structural analog: it is the only existing per-load side effect in the hire tree that gates on `currentUser.id`.

### D. Heap identify — inline in `AppAuthRouter.tsx:144-161`

Same file as C, ~20 lines above it. `React.useEffect(… , [currentUser, organizationId])` at `:146`/`:161`. **No guard at all** — it calls `window.heap.identify(currentUser?.hashId)` with `undefined` on the pre-fetch render. Duplicates hook A's job for the hire tree. Worth naming in the spec as the thing *not* to copy.

### E. `useSentry` — `app/javascript/shared/hooks/useSentry.ts:5-17`

Hook file, **no arguments**, `useEffect` with **no dependency array at all** (`:17` closes with `});`) — so it re-runs `Sentry.init` on every render of `AppDefaultWrapper`. Guard is `if (window.SERVER_ENV !== "test")`. Called from `AppDefaultWrapper.tsx:46` — account/connect only; the hire app instead calls `Sentry.init` at module scope in `ats/src/index.js:14-23`.

### F. `WebsocketGlobalChannelHandler` — `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx:16-22`

```tsx
React.useEffect(() => {
  const subscription = setupWebsocketConnections();
  return () => { subscription.unsubscribe(); };
}, []);
```

Traits: component-level (not a hook file); **empty dependency array** — strictly once per mount; **returns a cleanup function**. The only per-mount effect in the hire tree with a teardown. Mounted via `WebsocketProvider` at `AppContainer.tsx:82` — i.e. **below** `CurrentSessionProvider` and below the `currentUser == undefined ⇒ null` bail at `AppContainer.tsx:77-79`.

Also present, lower relevance: `AppContainer.tsx:39-53` (WWR discount modal, deps `[currentUser, currentOrganization, currentOrganizationUser, openModal]`, guard is a compound boolean on org settings); `shared/hooks/useCookieValue.ts:6-11` (a cookie **read** effect with **no dependency array** and `setCookieValue` inside it — it re-runs every render; its `cookie.split("=")[1]` at `:10` truncates values at the second `=`, the defect already recorded as pipeline rule 33); `shared/PostHogContext.tsx:30-43` (`posthog.init` in `useEffect(…, [])`) and `:11-18` (pageview tracker keyed on `[location.pathname]`).

---

## Coverage table

Rows = every way a signed-in hire user can arrive at an authenticated view. Columns: does the Rails HTML response render / does React mount / does `CurrentSessionProvider` render / is `currentUser.id` available.

| # | Arrival path | Rails HTML response? | ats React mounts? | `CurrentSessionProvider` renders? | `currentUser.id` available? |
|---|---|---|---|---|---|
| 1 | Fresh load of `/` | YES — `routes.rb:568` → `hire/pages_controller.rb:6`, no auth gate | YES — `application.html.erb:95` → `ats/src/index.js:27` | YES — `AppAuthRouter.tsx:419` | **NO at first render**, YES after `/me` resolves (`useMe.ts:71`; `queryObserver.js:286-295` forces `status='loading'` on mount) |
| 2 | Hard refresh of an enumerated deep link (`/jobs/123`, `/jobs/1/stages/2/applicants/3/overview`, `/hire/settings/billing`, `/notifications`, `/interviewer`, …) | YES — `routes.rb:611`, `:638`, `:663`, `:652`, `:654` etc, all `pages#root` | YES | YES — `AppAuthRouter.tsx:419` | NO at first render; YES after `/me` resolves |
| 3 | Hard refresh of a **non-enumerated** hire path (`/jobs/123/unknown`) | YES but **404** — `config/application.rb:78` → `routes.rb:570` → `hire/errors_controller.rb:8`, `layout false` | **NO** — `not_found_404.html.erb:6` loads `job_board_application`, which has no React | NO | NO |
| 4 | Client-side navigation inside hire (`<Link>`, `history.push`, `<Redirect>`) | **NO** — no request; `Redirect.js:70-82` `history.replace`, `BrowserRouter` pushState | already mounted, no remount | already rendered, **stays mounted** (`AppAuthRouter.tsx:419` is above the `<Switch>` at `:430`) | YES (post-fetch) |
| 5 | Post-sign-in via magic link | YES — `routes.rb:55` → `magic_links_controller.rb:22` `sign_in`, `:28` redirect → `pages#root` | YES | YES | NO at first render; YES after `/me` |
| 6 | Post-sign-in via Google SSO return | YES — `omniauth_callbacks_controller.rb:42` `sign_in`, `:49` `redirect_to "#{AtsRootUrl}/"` → `routes.rb:568` | YES | YES | NO at first render; YES after `/me`. Then `AppAuthRouter.tsx:479` client-side-redirects `/` → `defaultPath` |
| 7 | Post-sign-in via password form (`useLogin`) | **NO** — `useSession.ts:164-175` `POST /api/v1/login`, then `Login.tsx:29` `history.push("/jobs")` | already mounted | already rendered — **but on `/login` the `/me` query was `enabled: false`** (`AppAuthRouter.tsx:77`, `:55-63`) | YES immediately — `useLogin.onSuccess` does `queryClient.setQueryData("me", data)` (`useSession.ts:171`), seeding the cache without a round trip |
| 8 | Email-confirmation link click **while signed in** | YES but a **302** — `hire/confirmations_controller.rb:18` → `/auth?email_confirmed=true` → `hire/pages_controller.rb:26-27` `redirect_if_authed` → `app_root_path`, **query param dropped** | YES, at `/` not `/auth` | YES | NO at first render; YES after `/me` |
| 9 | Session-expiry bounce (401 on a focus refetch) | YES — `useMe.ts:89` full page load to `${APP_ATS_ROOT_URL}/logout` → `routes.rb:600` `pages#root` | YES | **NO** — `AppAuthRouter.tsx:537` renders `<Logout/>` instead of `AppAuthed` | NO |
| 10 | Explicit "Log out" click | YES — `PolymerBar.tsx:205` `<a href="/logout">` → `routes.rb:600` | YES | **NO** — same short-circuit | NO |
| 11 | "Account settings" click | YES — `PolymerBar.tsx:186` `<a href="/account">` → `routes.rb:558` → `account/pages_controller.rb:4` | **NO ats React** — `account_application` pack instead (`account_application.html.erb:58`) | YES, but the **account** one at `AppAuthedWrapper.tsx:35`, and only **after** the loading bail at `:30-32` | NO during loading (provider not mounted); YES after |
| 12 | Stripe Checkout return | YES — `billing_controller.rb:75` → `routes.rb:612` or `:663` `pages#root` | YES | YES | NO at first render; YES after `/me` |
| 13 | Stripe Billing Portal return (default) | YES — `billing_controller.rb:21`/`:292`/`:340` `return_url` defaults to `/account` → `routes.rb:558` | **NO ats React** — account pack | account provider only (`AppAuthedWrapper.tsx:35`) | NO during loading; YES after |
| 14 | Integration OAuth callback | YES — `routes.rb:582` → `Integrations::OauthAuthenticationsController#create`, then its redirect to a `pages#root` path | YES | YES | NO at first render; YES after `/me` |
| 15 | Legacy candidate permalink | YES — `routes.rb:643` → `redirector_controller.rb:27` 302 → `routes.rb:633-640` `pages#root` | YES | YES | NO at first render; YES after `/me` |
| 16 | Update-banner "Refresh" | YES — same URL reloaded (`AppContainer.tsx:90`) | YES | YES | NO at first render; YES after `/me` |
| 17 | Signed-in user requesting `/auth` / `/login` / `/register` directly | YES but a **302** — `hire/pages_controller.rb:26-27` → `app_root_path` (unless `?invite_token`, `:26`) | YES, at `/` | YES | NO at first render; YES after `/me` |
| 18 | `/register?invite_token=…` while signed in | YES, **no 302** (`hire/pages_controller.rb:26` exempts `invite_token`) — renders `pages#root` via `:29` | YES | YES | **NO** — `/register` ∈ `UNAUTHED_ROUTES` (`AppAuthRouter.tsx:60`) ⇒ `enabled: false` ⇒ the `/me` query stays `'idle'` and **never fetches** (`queryObserver.js:500`). `currentUser` stays `undefined` until `acceptInvite` (`AppAuthRouter.tsx:396`) invalidates `"me"` (`useMe.ts:136`) |

## Coverage gaps — side by side

### Frontend-set cookie (written from `document.cookie` inside the authenticated React tree, at `CurrentSessionProvider` / `AppAuthed`)

| Gap | Evidence |
|---|---|
| **`/logout` never renders `AppAuthed`.** `AuthedLogoutDecision` returns `<Logout/>` when `pathname.includes("/logout")`. The user is still authenticated for that Rails request and for the `DELETE /api/v1/logout` that follows. | `AppAuthRouter.tsx:537` |
| **The account app (`/account`) is a different React root with a different provider.** A hire-tree mount point does not fire there. This matters because `/account` is a first-class destination: the PolymerBar menu item and the default Stripe Billing Portal `return_url`. | `PolymerBar.tsx:186`; `billing_controller.rb:21`, `:292`, `:340`; `AppAuthedWrapper.tsx:35` vs `AppAuthRouter.tsx:419` |
| **Hire 404/500 pages mount no React.** They load the `job_board_application` pack with `layout false`. | `app/views/hire/errors/not_found_404.html.erb:6`; `hire/errors_controller.rb:6` |
| **`currentUser.id` is not available at mount** — it arrives one network round trip later. A write placed in the provider's render body would run with `undefined` first. The write must be a `useEffect` guarded on `currentUser?.id`, like `AppAuthRouter.tsx:167`. | `useMe.ts:71`; `queryObserver.js:286-295`, `:350` |
| **On `UNAUTHED_ROUTES` the `/me` query is disabled and never fetches**, so a signed-in user sitting on `/register?invite_token=…` (the one path `redirect_if_authed` lets through) has no `currentUser` in the tree at all. | `AppAuthRouter.tsx:55-63`, `:74`, `:77`; `hire/pages_controller.rb:26`; `queryObserver.js:500` |
| **Account/connect provider is skipped during loading**, so any write hung off `AppAuthedWrapper` mount misses the first render there. (Delay, not a permanent hole.) | `AppAuthedWrapper.tsx:30-32` |
| **The connect app is a third React root** with its own copy of the provider path. Declared out of scope, but it is a third place the same code would have to live. | `connect/src/App.tsx:10` |

### Backend-set cookie (`Set-Cookie` on the HTML response)

| Gap | Evidence |
|---|---|
| **Nothing in the hire HTML pipeline currently knows who the user is.** `Hire::PagesController#root` is an empty method and `Hire::BaseController` adds no authentication or user lookup. Devise's `current_api_v1_user` is reachable, but it is not referenced anywhere in the hire page pipeline today — this would be new behavior on the HTML path, not an extension of it. | `hire/pages_controller.rb:6`; `hire/base_controller.rb:3-5`; `application_controller.rb` (no `authenticate_*!`) |
| **Pure client-side navigation issues no Rails request at all.** A user who signs in and then works for an hour inside the SPA generates one HTML response and zero more. `<Redirect>` is `history.replace`; `history.push` is pushState. | `node_modules/react-router/Redirect.js:70-82`; `App.tsx:36` |
| **Sign-in itself can complete with no HTML response.** `useLogin` posts to `/api/v1/login` and seeds the React Query cache directly; the only navigation is `history.push("/jobs")`. No Rails HTML render, so no `Set-Cookie` on an HTML response. | `useSession.ts:164-175`; `Login.tsx:29` |
| **`/account` and `/connect` are served by different controllers**, so a hire-only `after_action` would miss them. `Account::PagesController#root` already writes a cookie (`account_referrer`) and would need the second write added. | `account/pages_controller.rb:4-6`; `connect/pages_controller.rb:4-8` |
| **404/500 responses come from `Hire::ErrorsController`**, a separate controller with `layout false`. | `hire/errors_controller.rb:3-18` |
| **`redirect_if_authed` returns a 302 with no body** for a signed-in user on the seven unauthed page actions. A cookie set on the 302 does reach the browser, but only if the writer is on that code path — the redirect happens in a `before_action`, before any `after_action` on `#root` would run. | `hire/pages_controller.rb:4`, `:24-31` |
| **Devise `sign_in` points that redirect** (`magic_links_controller.rb:22`, `omniauth_callbacks_controller.rb:42`) issue 302s whose target is a `pages#root` render — so those are covered *by the subsequent render*, not by the sign-in response itself. | `magic_links_controller.rb:22`, `:28`; `omniauth_callbacks_controller.rb:42`, `:49` |
| **Assets, API JSON, ActionCable, and Active Storage requests never render the layout.** Any cookie write hung off `application.html.erb` or a hire-HTML `after_action` is absent from those. | `application.html.erb:95`; `api/v1/base_controller.rb` |

### Where the two approaches differ most sharply

Rows 4 and 7 of the coverage table are the crux: **client-side navigation and password sign-in produce no Rails HTML response**, so a backend-only cookie would be written once per hard load and never refreshed inside a long SPA session. Rows 9, 10, 11, 13 are the mirror image: **`/logout` and `/account` never render the hire `CurrentSessionProvider`**, so a frontend-only cookie mounted there misses them. Neither side covers row 3 (hire 404).

## Open questions / could not determine from code

1. **Whether `/connect` is reachable at all in production.** `Connect::PagesController#root:5` calls `current_organization_user.is_admin`, and `Connect::BaseController:9-11` derives that from `current_user.current_organization_user` with no nil guard, so a signed-out request would raise. The brief says no connect users exist; I did not verify against data (and would not — DB reads are out of scope here).
2. **Whether `useOrganization(undefined)` ever settles.** `getOrganization` returns `undefined` when the id is undefined (`useOrganization.ts:30-35`), and react-query v3 treats a query function resolving `undefined` as an error. For a user with no `organizationId`, `isLoadingOrganization` at `AppAuthRouter.tsx:89` may not settle cleanly. I did not trace react-query's `undefined`-result handling to a conclusion; the `/organization/new` gate at `:342` sits behind that same loading branch, so it is worth checking if the spec depends on it.
3. **The `Integrations::OauthAuthenticationsController#create` redirect target** (`routes.rb:582`). I read the route but not the controller — it is in the Rails agent's territory. Row 14 of the coverage table assumes it lands on a `pages#root` path; confirm against `redirects.md`.
4. **Whether `MagicLink#redirect_to` is ever populated in the hire flow.** `registrations_controller.rb:151` passes `params[:redirect_to]`, which comes from `useSession.ts:132` `redirectTo`, but I did not find a hire-side caller that supplies a non-nil `redirectTo`. If it is always nil, magic-link sign-in always lands on `/jobs?magic=not_found` (`magic_links_controller.rb:28`).
5. **Cookie domain / `Set-Cookie` attributes.** Nothing in this repo currently sets a cookie with an explicit `domain` — `account_referrer` (`account/pages_controller.rb:5`) and `connect_referrer` (`connect/pages_controller.rb:7`) both use bare `cookies[:key] = value`, which scopes to the exact host. Whatever writes the new cookie will be the first `.polymer.co`-scoped cookie in the codebase; there is no in-repo precedent to match.
