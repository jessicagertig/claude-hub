# PostHog Frontend Integration — Full Trace

Repo: `/Users/jessica/wrk/wrk-corp/inflow-ats`, branch `ai-credit-posthog-events`. Read-only; nothing modified.

---

## 1. File chain traced

**Bootstrap / init chain**
```
app/views/layouts/application.html.erb  (window.POSTHOG_API_KEY / POSTHOG_HOST)
  → config/initializers/01_variables.rb  (Variables::POSTHOG_API_KEY / POSTHOG_HOST)
app/javascript/packs/ats_application.js
  → app/javascript/shared/logger.ts          (window.logger)
  → app/javascript/ats/src/index.tsx
    → app/javascript/ats/src/views/layouts/App.tsx
      → app/javascript/shared/PostHogContext.tsx
        → posthog-js (npm, 1.297.4)  [boundary]
        → @posthog/react (npm, 1.0.0) PostHogProvider  [boundary]
        → react-router-dom withRouter  [boundary]
        → app/javascript/shared/lib/posthog.ts
      → app/javascript/ats/src/views/layouts/AppAuthRouter.tsx
```

**Identify chain**
```
AppAuthRouter.tsx
  → @shared/PostHogContext (re-export) → @shared/lib/posthog.ts → posthog.identify()
  → @shared/queryHooks/useMe.ts (useGetMe)
      → @shared/queryHooks/api.ts (apiGet)
          → @ats/src/lib/utils/structure.js (allKeysToCamel)
          → GET /api/v1/me
              → app/controllers/api/v1/me_controller.rb#show
              → app/serializers/api/v1/session_serializer.rb
  → @shared/queryHooks/useOrganization.ts (useOrganization)
      → GET /api/v1/organizations/:id
          → app/controllers/api/v1/organizations_controller.rb#show
          → app/serializers/api/v1/organization_serializer.rb
          → db/schema.rb (organizations table, line 1033)
  → @ats/src/context/CurrentSessionContext.tsx
  → @ats/src/lib/store/zustand/organizationStore.ts
  → @shared/types/currentUser.ts, @shared/types/organization.ts
```

**Reset chain**
```
AppAuthRouter.tsx → app/javascript/ats/src/views/sessions/Logout.tsx
  → @shared/PostHogContext → @shared/lib/posthog.ts → posthog.reset()
  → @shared/queryHooks/useSession (useLogout)
```

**Capture chain (39 component files)**
```
<component>.tsx → @shared/lib/posthog.ts (trackEvent) → posthog.capture(event, properties)
e.g. views/sessions/OnboardingProfile.tsx, views/sessions/components/ProfileForm.tsx,
     views/sessions/components/OrganizationForm.tsx, views/jobApplications/JobStageMenu.tsx,
     views/jobApplications/useRunPlatoCtaModals.tsx
```

**Org-switch chain**
```
components/shared/OrgSwitcherLogo.tsx / views/layouts/AppHeader.tsx / components/shared/UserNav.tsx
  → views/accountAdmin/OrganizationSwitcher.tsx
    → @shared/queryHooks/useMe.ts (useChooseOrganizationUser)
      → PUT /api/v1/me/choose_organization_user → me_controller.rb#choose_organization_user
```

**Backend (for completeness on `group()`)**
```
config/initializers/posthog.rb → POSTHOG_CLIENT
app/services/posthog/identify.rb, app/services/posthog/track.rb
app/jobs/posthog_identify_job.rb, app/jobs/posthog_track_job.rb
```

---

## 2. posthog-js initialisation

`app/javascript/shared/PostHogContext.tsx:26-43` — the only `posthog.init` in the repo:

```tsx
function PostHogProvider({ children }: { children: React.ReactNode }) {
  const apiKey = (window as any).POSTHOG_API_KEY;
  const host = (window as any).POSTHOG_HOST;

  React.useEffect(() => {
    if (!apiKey || (window as any).IS_TEST_ENV) return;

    posthog.init(apiKey, {
      api_host: host || "https://us.i.posthog.com",
      capture_pageview: false, // We handle pageviews manually via React Router
      capture_pageleave: true,
      loaded: (ph) => {
        if ((window as any).IS_DEVELOPMENT) {
          ph.debug();
        }
      },
    });
  }, []);
```

That is the complete options object: `api_host`, `capture_pageview: false`, `capture_pageleave: true`, `loaded`. No `person_profiles`, no `bootstrap`, no `autocapture` override, no `session_recording` config.

**Key/host source** — globals written into the HTML `<head>` (not meta tags), `app/views/layouts/application.html.erb:78-79`:

```erb
window.POSTHOG_API_KEY = "<%= Variables::POSTHOG_API_KEY %>";
window.POSTHOG_HOST = "<%= Variables::POSTHOG_HOST %>";
```

`config/initializers/01_variables.rb:35-36`:

```ruby
POSTHOG_API_KEY = ENV['POSTHOG_API_KEY'] || Rails.application.credentials.dig(Rails.configuration.x.RailsCredentialsEnv, :posthog, :api_key)
POSTHOG_HOST = ENV['POSTHOG_HOST'] || 'https://us.i.posthog.com'
```

Same two constants feed the server-side client (`config/initializers/posthog.rb:5-11`). The declared window typings live at `app/javascript/shared/lib/posthog.ts:3-8`.

Guards: init is skipped when `apiKey` is falsy or `window.IS_TEST_ENV` is true (`application.html.erb:83` sets `window.IS_TEST_ENV = <%= Rails.env.test? %>`). In development with a key present it inits and calls `ph.debug()` (`application.html.erb:82` sets `window.IS_DEVELOPMENT`).

---

## 3. Provider: `@posthog/react`'s `PostHogProvider` — wrapped in a local component

Both. `@posthog/react@1.0.0`'s `PostHogProvider` is used, aliased `PHProvider`, wrapped by a locally-defined component of the same name that owns `init` plus a router-driven pageview tracker. There is no React context of the app's own.

`app/javascript/shared/PostHogContext.tsx:1-23, 45-54`:

```tsx
import posthog from "posthog-js";
import { PostHogProvider as PHProvider } from "@posthog/react";
import { withRouter } from "react-router-dom";
import { identifyUser, resetUser } from "@shared/lib/posthog";

// Pageview tracker - uses withRouter to listen to React Router v4 location changes
function PageviewTrackerInner({ location, children }: { location: any; children: React.ReactNode }) {
  const previousPathnameRef = React.useRef<string>("");

  React.useEffect(() => {
    if (location?.pathname && location.pathname !== previousPathnameRef.current) {
      previousPathnameRef.current = location.pathname;
      if (posthog.__loaded) {
        posthog.capture("$pageview");
      }
    }
  }, [location.pathname]);

  return <>{children}</>;
}

const PageviewTracker = withRouter(PageviewTrackerInner as any) as any;
```

```tsx
  return (
    <PHProvider client={posthog}>
      <PageviewTracker>
        {children}
      </PageviewTracker>
    </PHProvider>
  );
}

export { PostHogProvider, identifyUser, resetUser };
```

Mounted once, inside `BrowserRouter`, `app/javascript/ats/src/views/layouts/App.tsx:34-55`:

```tsx
    <QueryClientProvider client={queryClient}>
      <ColorSchemeProvider>
        <BrowserRouter>
          <PostHogProvider>
```

`@posthog/react`'s hooks (`usePostHog`, `useFeatureFlagEnabled`, `PostHogErrorBoundary`, `PostHogFeature`, …) are exported by the package but **not used anywhere** in `app/javascript` — the only import from `@posthog/react` in the repo is `PostHogProvider` at `PostHogContext.tsx:3`. Every capture in the app goes through the module-singleton helpers instead.

Two notes from the traced code, both mechanical consequences of the structure above:

- `posthog.__loaded` (`node_modules/posthog-js/dist/module.d.ts:3330`) is set by `init`. `PageviewTrackerInner` is a **child** of `PHProvider`, which is rendered by `PostHogProvider`; React commits child effects before parent effects, so on a hard page load the pageview effect runs while `__loaded` is still `false` and the first `$pageview` is dropped. With `capture_pageview: false` there is no library-side fallback for that first view. Subsequent route changes capture normally.
- `PageviewTrackerInner` keys off `location.pathname` only — `previousPathnameRef` comparison at line 12 — so a query-string-only or hash-only navigation captures no pageview.

---

## 4. `posthog.identify()` — one call site

The wrapper, `app/javascript/shared/lib/posthog.ts:17-39`:

```ts
function identifyUser(user: {
  id: number;
  email: string;
  organizationId?: number;
  organizationName?: string;
  plan?: string;
  organizationUserRole?: string;
}): void {
  const ph = getPosthog();
  if (!ph) {
    window.logger("%c[PostHog] identifyUser skipped - not loaded", "background-color: #FF76D2", { user });
    return;
  }

  window.logger("%c[PostHog] identifyUser", "background-color: #FF76D2", { user });
  ph.identify(String(user.id), {
    email: user.email,
    organization_id: user.organizationId,
    organization_name: user.organizationName,
    plan: user.plan,
    organization_user_role: user.organizationUserRole,
  });
}
```

- **distinct_id**: `String(user.id)` — the Rails `users.id` integer as a string. Not `hashId` (that one is used for Heap at `AppAuthRouter.tsx:147`).
- **person properties** (second arg → `$set`): `email`, `organization_id`, `organization_name`, `plan`, `organization_user_role`.

The single caller, `app/javascript/ats/src/views/layouts/AppAuthRouter.tsx:163-177`:

```tsx
  /* POSTHOG IDENTIFY
  --===================================================-- */
  const currentPlan = currentOrganization?.plan;
  React.useEffect(() => {
    if (currentUser?.id) {
      identifyUser({
        id: currentUser.id,
        email: currentUser.email,
        organizationId: organizationId,
        organizationName: organizationName,
        plan: currentPlan,
        organizationUserRole: currentUser.currentOrganizationUser?.role,
      });
    }
  }, [currentUser, organizationId, currentPlan, organizationName]);
```

with the inputs defined at `AppAuthRouter.tsx:76-91` and `:138-141`:

```tsx
  const { data: currentUser, isLoading: isLoadingUser } = useGetMe({...});
  const organizationId = currentUser?.organizationId;
  ...
  const { data: currentOrganization, isLoading: isLoadingOrganization } = useOrganization(
    organizationId,
  );
  ...
  const organizationName = currentOrganization ? currentOrganization.name : null;
```

Consequences visible in this code: `organizationId` comes from the `/me` payload, while `organizationName` and `plan` come from the *separate* `/organizations/:id` query that is only issued once `organizationId` is known. The effect's dependency array includes all three, so on a cold load `identify` fires at least twice — first with `organization_name: null` and `plan: undefined`, then again once the organization query resolves. `currentUser` is an object identity in the dep array, so any `me` refetch that returns a new object re-fires `identify` as well.

Server side also identifies with the same distinct_id shape — `app/services/posthog/identify.rb:11-21` uses `distinct_id: @user.id.to_s` with properties `email, created_at, organization_id, organization_name, plan, organization_user_role`.

---

## 5. `posthog.reset()` — logout

Wrapper, `app/javascript/shared/lib/posthog.ts:52-57`:

```ts
function resetUser(): void {
  const ph = getPosthog();
  if (!ph) return;

  ph.reset();
}
```

Called once, `app/javascript/ats/src/views/sessions/Logout.tsx:12-28`:

```tsx
  React.useEffect(() => {
    window.logger("%c[Logout] useEffect", "color: #1976D2");
    logout(null, {
      onSuccess: () => {
        resetUser();
        queryCache.clear();
        const search = new URLSearchParams(window.location.search);
        const path = search?.has("path") ? search.get("path") : null;
        // window.location.href = `${window.APP_ATS_ROOT_URL}/auth`; // This is a hard refresh of the page to clear console and make sure App component refreshes
        if (path) {
          props.history.push(`/auth?path=${encodeURIComponent(path)}`);
        } else {
          props.history.push("/auth");
        }
      },
    });
  }, []);
```

Reset runs only in the mutation's `onSuccess`. `Logout` is reached two ways: the `/logout` route at `AppAuthRouter.tsx:481-485`, and the short-circuit at `AppAuthRouter.tsx:533-542` (`AuthedLogoutDecision`) which bypasses `AppAuthed` entirely when the path contains `/logout`. Note `useGetMe`'s `onError` (`useMe.ts:89`) sends the browser to `/logout` via `window.location.href` on a session failure — that path reaches `Logout` after a full reload, so reset still depends on the logout mutation succeeding.

---

## 6. `posthog.group()` — not called anywhere

Definitively: **no**. There is no `posthog.group(`, no `group_identify`, no `$groups`, and no `groups:` key anywhere in `app/` (frontend or backend). A repo-wide search for group-shaped calls returns exactly one hit, unrelated: `app/services/engagement_report/organization_analyzer.rb:68` (`apps_in_period.group("DATE_TRUNC('month', ...)")`, an ActiveRecord grouping).

Organization association today is carried only as **person properties** on the user (`organization_id` / `organization_name` in `identifyUser`, `PostHogContext`/`lib/posthog.ts`, and the same pair in `Posthog::Identify` and `Posthog::Track#default_properties`). No PostHog group analytics entity exists. There is also no group config in `posthog.init` (see §2) and none in `config/initializers/posthog.rb`.

---

## 7. Shared capture helper

**`trackEvent(event: string, properties?: Record<string, any>): void`** — `app/javascript/shared/lib/posthog.ts:41-50`:

```ts
function trackEvent(event: string, properties?: Record<string, any>): void {
  const ph = getPosthog();
  if (!ph) {
    window.logger("%c[PostHog] trackEvent skipped - not loaded", "background-color: #FF76D2", { event, properties });
    return;
  }

  window.logger("%c[PostHog] trackEvent", "background-color: #FF76D2", { event, properties });
  ph.capture(event, properties);
}
```

Its load guard, `app/javascript/shared/lib/posthog.ts:10-15`:

```ts
// posthog-js is a singleton. Once initialized by PostHogProvider in App.tsx,
// these helpers can be used anywhere (including non-component code like query hook callbacks).

function getPosthog() {
  return posthog.__loaded ? posthog : null;
}
```

Exports at line 59-60: `export { identifyUser, trackEvent, resetUser }; export default posthog;`.

`window.logger` is `console.log` only in dev / when `CONSOLE_LOG_ENABLED`, else a no-op — `app/javascript/shared/logger.ts:1-5`.

**Reach: 69 `trackEvent(` call sites across 39 files**, every one importing `{ trackEvent } from "@shared/lib/posthog"` (no file imports `trackEvent` from `@shared/PostHogContext` — that module re-exports only `identifyUser` and `resetUser`).

Three representative call sites (all three files read in full):

1. `app/javascript/ats/src/views/jobApplications/JobStageMenu.tsx:98-100`
```tsx
  const handleOnClickMessageAll = (event) => {
    event.preventDefault();
    trackEvent("bulk_message_clicked", { job_id: job.id, hiring_stage_id: currentStage.id, candidates_count: candidatesCount });
```

2. `app/javascript/ats/src/views/jobApplications/useRunPlatoCtaModals.tsx:40-42`
```tsx
  const handleReviewAll = (event?: React.SyntheticEvent) => {
    event?.preventDefault();
    trackEvent("run_plato_review_all_clicked", { job_id: jobId, candidates_count: jobApplicationsCount });
```

3. `app/javascript/ats/src/views/sessions/components/OrganizationForm.tsx:55-62`
```tsx
      createOrganization(
        { name, heardAboutUsFrom },
        {
          onSuccess: (data) => {
            window.logger("[OrganizationForm] createOrganization onSuccess", { data });
            trackEvent("organization_created");
            onComplete(data);
          },
```

Property keys at call sites are snake_case throughout (`job_id`, `hiring_stage_id`, `candidates_count`, `current_plan`, `job_application_id`, …). No call site passes an organization identifier — org attribution rides entirely on the person properties set by `identifyUser`.

The onboarding events fire before their mutations on purpose — `ProfileForm.tsx:57-62`:
```tsx
      // Fire name-submitted events BEFORE mutation (cache update causes redirect race — see above)
      if (props.isNewOwner) {
        trackEvent("organization_owner_user_name_submitted");
      } else {
        trackEvent("invited_user_name_submitted");
      }
```
and `OnboardingProfile.tsx:28-35` fires `organization_owner_email_verified` / `invited_user_email_verified` from a mount effect.

---

## 8. Where the frontend learns the current organization

**Two hooks, in this order.**

**a) `useGetMe` — `app/javascript/shared/queryHooks/useMe.ts:57-93`** (react-query key `"me"`, `GET /api/v1/me`). Supplies the organization **id only**:

```ts
export function useGetMe({ enabled = true, refetchOnWindowFocus = false }: {...}): {
  status: any; data: CurrentUser; error: any; isFetching: boolean; isLoading: boolean;
} {
  return useQuery("me", getMe, { ... });
}
```

Consumed at `AppAuthRouter.tsx:76-80`: `const organizationId = currentUser?.organizationId;`

**b) `useOrganization(organizationId)` — `app/javascript/shared/queryHooks/useOrganization.ts:104-118`** (react-query key `["currentOrganization", organizationId]`, `GET /api/v1/organizations/:id`). Supplies **name, plan and everything else**:

```ts
function useOrganization(organizationId): {...} {
  return useQuery(["currentOrganization", organizationId], () => getOrganization(organizationId), {
    refetchOnWindowFocus: false,
  });
}
```

**Exact field names on the response objects.** Rails serializes snake_case; `apiGet` runs the payload through `allKeysToCamel` (`app/javascript/shared/queryHooks/api.ts:22`, implementation `app/javascript/ats/src/lib/utils/structure.js:39-70`, lodash `camelCase` per key, recursive). So the frontend objects are camelCase:

| Frontend field | Source | Type |
|---|---|---|
| `currentUser.organizationId` | `session_serializer.rb:25` + `:54-56` — `object&.current_organization_user&.organization_id` | `number` (`currentUser.ts:48`) |
| `currentUser.currentOrganizationUser.role` | `session_serializer.rb:40` → `Api::V1::OrganizationUserSerializer` | `string` (`currentUser.ts:61`) |
| `currentUser.id`, `currentUser.email` | `session_serializer.rb:5, :11` | `number`, `string` |
| `currentOrganization.id` | `organization_serializer.rb:4` | `number` (`organization.ts:12`) |
| `currentOrganization.organizationId` | `organization_serializer.rb:4` + `:68-70` — `object.id`, duplicate of `id` | `number` |
| `currentOrganization.name` | `organization_serializer.rb:4` | `string` (`organization.ts:13`) |
| `currentOrganization.plan` | `organization_serializer.rb:12` (integer enum column, serialized as its enum string, e.g. `"plan_ats_tier_growth"` — see `Plans` enum, `organization.ts:109-121`) | `string` (`organization.ts:36`) |
| `currentOrganization.flipperId` | `organization_serializer.rb:36` → `app/models/organization.rb:443-445`, `"Organization-#{id}"` | `string` |

**There is no `uuid` on organizations.** `db/schema.rb:1033-1101` shows the primary key is the default bigint `id`; the only `uuid` column on the table is `t.uuid "zapier_api_key"` (line 1073), an API key, not an org identifier, and it is not in `OrganizationSerializer`'s attribute list. The stable string identifier that already exists is `flipperId` (`"Organization-<id>"`).

**Contexts/stores that also carry it** (all downstream of the same two queries, no independent fetch):
- `CurrentSessionProvider` — `AppAuthRouter.tsx:419-422` passes `currentUser` and `currentOrganization`; `useCurrentSession()` at `app/javascript/ats/src/context/CurrentSessionContext.tsx:95-117` returns `{ currentUser, currentOrganizationUser, currentOrganization }` typed `CurrentOrganization`.
- zustand `useOrganizationStore` — written during render at `AppAuthRouter.tsx:110-120` (`state.currentOrganization = currentOrganization; state.users = ...`). Note the store's own type (`organizationStore.ts:4-11`) declares `organization: {}` and has no `currentOrganization` key, and the only other consumer is `JobSetupTeam.tsx:21`, which reads users — nothing reads `state.currentOrganization`.

---

## 9. Switching organizations without a full page reload — yes

`app/javascript/ats/src/views/accountAdmin/OrganizationSwitcher.tsx:60-73` is a pure SPA transition:

```tsx
  const handleOrganizationUserChoice = (organizationUser) => {
    chooseOrganizationUser(
      { organization_user_id: organizationUser.id },
      {
        onSuccess: (organizationUser) => {
          window.logger("%c[OrganizationSwitcher] handleOrganizationUserChoice", "color: #19d228", {
            organizationUser,
          });
          queryClient.clear();
          history.push("/jobs");
        },
      },
    );
  };
```

`chooseOrganizationUser` → `useChooseOrganizationUser` (`useMe.ts:184-193`):

```ts
export function useChooseOrganizationUser() {
  const queryClient = useQueryClient();
  return useMutation(chooseOrganizationUser, {
    onSuccess: (data) => {
      queryClient.invalidateQueries("currentOrganization");
      queryClient.invalidateQueries("me");
    },
  });
}
```

→ `PUT /api/v1/me/choose_organization_user` (`useMe.ts:37-42`) → `me_controller.rb:13-25`, which does `current_user.update(current_organization_user: organization_user)` and re-renders `SessionSerializer`.

Routes into that screen — all client-side, no reload:
- `components/shared/OrgSwitcherLogo.tsx:19-22` — `history.push("/organization/manage")`
- `views/layouts/AppHeader.tsx:86` and `components/shared/UserNav.tsx:100` — `<Link to="/organization/manage">`
- `AppAuthRouter.tsx:212-217` — `<Redirect to="/organization/manage" />` for a deactivated `currentOrganizationUser`

The route itself is `AppAuthRouter.tsx:496-500`. Exception: `app/javascript/shared/components/PolymerBar.tsx:183` uses `<a href="/organization/manage">`, which *is* a document load.

**What this means for PostHog:** `queryClient.clear()` + `history.push` keeps the same JS context, so the posthog singleton and its `distinct_id` persist. `AppAuthed` refetches `me` and `currentOrganization`, and the effect at `AppAuthRouter.tsx:166-177` re-fires `identifyUser` with the new `organization_id` / `organization_name` / `plan` / `organization_user_role`, overwriting those person properties on the same person. No `reset()`, no `group()`. Between the mutation resolving and the org query resolving, `identify` can fire with `organization_name: null` / `plan: undefined` (same double-fire as §4), transiently blanking those person properties.

A second no-reload org change exists: accepting an invite. `AppAuthRouter.tsx:388-407` (`needsHandleAcceptInvite`) calls `acceptInvite` then `<Redirect to="/jobs" />`; `useAcceptInvite` (`useMe.ts:132-141`) invalidates `"me"` and `"meInvites"`. And org *creation* — `NewOrganization.tsx:27-45` — does `queryClient.clear(); props.history.push("/jobs");` with no reload, after `OrganizationForm` fires `trackEvent("organization_created")`.

---

## 10. Jest tests covering the PostHog helpers — none

There are **zero** tests touching PostHog anywhere in the repo.

- Jest config: `jest.config.js` (jsdom, `testPathIgnorePatterns` excludes `node_modules`, `config/webpack/test.js`, `cypress/`). Scripts `test` / `test:watch` in `package.json:9-10`.
- The only Jest test file in `app/javascript` is `app/javascript/ats/src/components/shared/Button/Button.test.tsx`. (`app/javascript/ats/src/lib/utils/__tests__/` contains only `devUtils.js`, which is not a test.)
- A repo-wide case-insensitive search for `posthog` returns no hits under `spec/` or `cypress/`, and none in any `*.test.*` / `*.spec.*` file. The full list of files mentioning posthog is: `app/javascript/shared/lib/posthog.ts`, `app/javascript/shared/PostHogContext.tsx`, the 42 importing components/layouts, `app/views/layouts/application.html.erb`, `config/initializers/posthog.rb`, `config/initializers/01_variables.rb`, `package.json`, `app/services/posthog/{identify,track}.rb`, `app/jobs/posthog_{identify,track}_job.rb`, `app/jobs/track_new_sso_owner_signup_job.rb`, `app/models/{user,organization_ai_credit_purchase,subscription_event}.rb`, `app/services/email_processor.rb`, and the controllers `api/v1/{billing,organization_ai_credit_purchases,registrations,sessions,users/omniauth_callbacks}`, `auth/invites_controller.rb`, `magic_links_controller.rb`.