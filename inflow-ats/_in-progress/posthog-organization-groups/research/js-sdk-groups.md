# posthog-js 1.297.4 + @posthog/react 1.0.0 — Group API Surface

**Primary evidence: the installed package's own TypeScript source**, recovered from the shipped sourcemaps (`sourcesContent`) at `/Users/jessica/wrk/wrk-corp/inflow-ats/node_modules/posthog-js/lib/src/*.js.map`. Extracted copies (line numbers below refer to these):

- `/private/tmp/claude-501/-Users-jessica-claude-hub-inflow-ats/e7d6fcd8-6c0f-4d2b-9216-3c1560b83063/scratchpad/posthog-core.ts` (3540 lines)
- `.../scratchpad/posthog-persistence.ts`, `.../scratchpad/storage.ts`, `.../scratchpad/constants.ts`, `.../scratchpad/posthog-featureflags.ts`, `.../scratchpad/types.ts`

Compiled equivalent on disk: `/Users/jessica/wrk/wrk-corp/inflow-ats/node_modules/posthog-js/lib/src/posthog-core.js` lines 1870–1935. Typings: `/Users/jessica/wrk/wrk-corp/inflow-ats/node_modules/posthog-js/dist/module.d.ts`.

**1.297.4 was published 2025-11-24T10:48:38Z** (`https://registry.npmjs.org/posthog-js`). Two upstream group fixes postdate it and are **absent** from this build — see §7.

---

## 1. Exact signature and emission behavior of `posthog.group()`

Declaration (`dist/module.d.ts:4166`):

```ts
group(groupType: string, groupKey: string, groupPropertiesToSet?: Properties): void;
```

Full body, `posthog-core.ts:2248-2281` (verbatim):

```ts
    group(groupType: string, groupKey: string, groupPropertiesToSet?: Properties): void {
        if (!groupType || !groupKey) {
            logger.error('posthog.group requires a group type and group key')
            return
        }

        if (!this._requirePersonProcessing('posthog.group')) {
            return
        }

        const existingGroups = this.getGroups()

        // if group key changes, remove stored group properties
        if (existingGroups[groupType] !== groupKey) {
            this.resetGroupPropertiesForFlags(groupType)
        }

        this.register({ $groups: { ...existingGroups, [groupType]: groupKey } })

        if (groupPropertiesToSet) {
            this.capture('$groupidentify', {
                $group_type: groupType,
                $group_key: groupKey,
                $group_set: groupPropertiesToSet,
            })
            this.setGroupPropertiesForFlags({ [groupType]: groupPropertiesToSet })
        }

        // If groups change and no properties change, reload feature flags.
        // The property change reload case is handled in setGroupPropertiesForFlags.
        if (existingGroups[groupType] !== groupKey && !groupPropertiesToSet) {
            this.reloadFeatureFlags()
        }
    }
```

JSDoc on the same method (`posthog-core.ts:2216-2247`) documents the three params as:

```
     * @param {String} groupType Group type (example: 'organization')
     * @param {String} groupKey Group key (example: 'org::5')
     * @param {Object} groupPropertiesToSet Optional properties to set for group
```

### What it does beyond local state

| Effect | Condition |
|---|---|
| Registers super property `$groups: { ...existing, [groupType]: groupKey }` | always (after guards) |
| Registers `$epp` (`ENABLE_PERSON_PROCESSING`) = `true` | always, via `_requirePersonProcessing` (`posthog-core.ts:2968-2977`) |
| Clears stored flag-eval properties for that group type | only when `existingGroups[groupType] !== groupKey` |
| **Captures `$groupidentify`** | **only when `groupPropertiesToSet` is truthy** — NOT gated on the group having changed |
| Registers `$stored_group_properties` + `reloadFeatureFlags()` | only when `groupPropertiesToSet` is truthy (via `setGroupPropertiesForFlags`) |
| `reloadFeatureFlags()` (a `/flags` POST) | when group key changed AND no properties passed |
| No-op + `logger.error` | `!groupType \|\| !groupKey`, or `config.person_profiles === 'never'` |

**In 1.297.4, `posthog.group('organization', 'org_5')` with no third argument emits NO event at all.** It mutates localStorage and triggers a `/flags` reload. The group and group type are never created server-side.

This is a known, long-standing gap: [PostHog/posthog-js#3598](https://github.com/PostHog/posthog-js/issues/3598), opened 2021-12-15 — *"Currently, posthog.group(type, id) doesn't create a group unless a property is set because we prevent groupidentify from being emitted if there are no properties set."* PostHog's own answer in the thread ([comment](https://github.com/PostHog/posthog-js/issues/3598#issuecomment-4430822367)):

> `.group` calls in posthog-js without setting any properties does:
> 1. Set groups information on subsequent events
> 2. Does _not_ send us any properties for the group
>
> We don't create the group objects until we receive properties for them.

Note this contradicts PostHog's own docs snippet, which is inaccurate for 1.297.4 (`https://github.com/PostHog/posthog.com/blob/master/contents/docs/_snippets/capture-group-event-code.mdx`):

```js
// Call posthog.group() to create a group before capturing events.
// It sends a `$groupidentify` event to create or update the group.
// It will also create the group type if it doesn't exist. In the
// web SDK, it also associates all subsequent events in the session
// with the group.
posthog.group('company', 'company_id_in_your_db');
```

Also note the **conditional is on the argument, not on change**: passing properties on every call emits a `$groupidentify` every call. There is no dedup in this version.

Server-side validation of `$group_set` (`https://posthog.com/docs/data/ingestion-warnings`, source `contents/docs/data/ingestion-warnings.mdx:114-131`):

> PostHog discards `$groupidentify` events when the `$group_set` property is not a valid JSON object. The `$group_set` property must be a plain object containing the group properties you want to set — strings, numbers, booleans, and arrays are rejected.
>
> `null` or `undefined` values for `$group_set` are accepted and upsert the group with empty properties.

### Full group API surface in 1.297.4

From `dist/module.d.ts`:

```ts
group(groupType: string, groupKey: string, groupPropertiesToSet?: Properties): void;   // :4166
resetGroups(): void;                                                                   // :4180
getGroups(): Record<string, any>;                                                      // :4329
setGroupPropertiesForFlags(properties: { [type: string]: Properties }, reloadFeatureFlags?: boolean): void;
resetGroupPropertiesForFlags(group_type?: string): void;                               // :4258
```

`posthog.resetGroup()` (singular) **does not exist** — `grep -n "resetGroup" dist/module.d.ts` returns only `resetGroups` and `resetGroupPropertiesForFlags`. The PostHog tutorial page at `https://posthog.com/tutorials/frontend-vs-backend-group-analytics` names `posthog.resetGroup()`; that is a docs error, and it produced the community question ["posthog.resetGroup() is not a function?"](https://posthog.com/questions/posthog-reset-group-is-not-a-function).

---

## 2. Client-side persistence of the group association

`$groups` is an ordinary **super property**. It is written through `register()` (`posthog-core.ts:1425-1427`):

```ts
    register(properties: Properties, days?: number): void {
        this.persistence?.register(properties, days)
    }
```

**Storage key.** `posthog-persistence.ts:34-45`:

```ts
const parseName = (config: PostHogConfig): string => {
    let token = ''
    if (config['token']) {
        token = config['token'].replace(/\+/g, 'PL').replace(/\//g, 'SL').replace(/=/g, 'EQ')
    }

    if (config['persistence_name']) {
        return 'ph_' + config['persistence_name']
    } else {
        return 'ph_' + token + '_posthog'
    }
}
```

So the key is `ph_<PROJECT_API_KEY>_posthog` (or `ph_<persistence_name>` when `persistence_name` is configured). `$groups` is one JSON key inside that single entry.

**Which store.** Default is `persistence: 'localStorage+cookie'` (`posthog-core.ts:166`). Under that store, only a hardcoded five properties go to the cookie (`storage.ts:258-267`):

```ts
// Use localstorage for most data but still use cookie for COOKIE_PERSISTED_PROPERTIES
// This solves issues with cookies having too much data in them causing headers too large
// Also makes sure we don't have to send a ton of data to the server
const COOKIE_PERSISTED_PROPERTIES = [
    DISTINCT_ID,
    SESSION_ID,
    SESSION_RECORDING_IS_SAMPLED,
    ENABLE_PERSON_PROCESSING,
    INITIAL_PERSON_INFO,
]
```

`$groups` is not in that list → **under the default persistence, `$groups` lives in `localStorage` only, never in a cookie.** It therefore does not cross subdomains. (The `cookie_persisted_properties` config option documented at `https://posthog.com/docs/libraries/js/persistence` **does not exist in 1.297.4** — no occurrence in `types.ts`, `posthog-core.ts`, or `storage.ts`.) With `persistence: 'cookie'`, `$groups` goes into the cookie with `cookie_expiration` = 365 days (`posthog-core.ts:177`).

**Lifetime.** localStorage has no expiry, so the association persists indefinitely across reloads, tabs, and browser restarts until `reset()`, `resetGroups()`, another `group()` call for that type, or manual localStorage clearing. `register()` is called with no `days`, so `_expire_days` falls back to `cookie_expiration` (365) — which matters only under cookie-backed persistence.

**Automatic `$groups` on every capture.** `$groups` is deliberately absent from `PERSISTENCE_RESERVED_PROPERTIES` (`constants.ts:77-101`), the list of props excluded from events. `PostHogPersistence.properties()` (`posthog-persistence.ts:124-138`) therefore returns it, and `calculateEventProperties` merges it into every event (`posthog-core.ts:1313-1320`):

```ts
        // update properties with pageview info and super-properties
        properties = extend(
            {},
            infoProperties,
            this.persistence.properties(),
            this.sessionPersistence.properties(),
            properties
        )
```

One exception: `$snapshot` (session replay) events return before that merge (`posthog-core.ts:1240-1251`) and carry no `$groups`.

**Flag evaluation.** The `/flags` request body includes groups (`posthog-featureflags.ts:397-408`):

```ts
        const data: Record<string, any> = {
            token: token,
            distinct_id: this._instance.get_distinct_id(),
            groups: this._instance.getGroups(),
            $anon_distinct_id: this.$anon_distinct_id,
            person_properties: { ... },
            group_properties: this._instance.get_property(STORED_GROUP_PROPERTIES_KEY),
        }
```

---

## 3. Clearing the association on logout / org switch

### `posthog.resetGroups()` — the targeted call (`posthog-core.ts:2296-2302`)

```ts
    resetGroups(): void {
        this.register({ $groups: {} })
        this.resetGroupPropertiesForFlags()

        // If groups changed, reload feature flags.
        this.reloadFeatureFlags()
    }
```

JSDoc: *"Resets only the group properties of the user currently logged in."* Added in **1.36.1 (2022-12-01)**, changelog entry: `feat(groups): allow resetting only user's groups (#476)` (`packages/browser/CHANGELOG.md`).

Two things it does NOT do, both verifiable in the source above: it does not `unregister('$groups')` (it leaves `$groups: {}`, an empty object, which is then attached to every subsequent event), and it does not clear `$epp` / `ENABLE_PERSON_PROCESSING` that `group()` set via `_requirePersonProcessing`. Person processing stays on for that browser until a full `reset()`.

### `posthog.reset()` — yes, it clears groups (`posthog-core.ts:2423-2462`)

```ts
    reset(reset_device_id?: boolean): void {
        logger.info('reset')
        if (!this.__loaded) {
            return logger.uninitializedWarning('posthog.reset')
        }
        const device_id = this.get_property('$device_id')
        this.consent.reset()
        this.persistence?.clear()
        ...
```

`this.persistence?.clear()` → `posthog-persistence.ts:180-183`:

```ts
    clear(): void {
        this.remove()
        this.props = {}
    }
```

That deletes the whole `ph_<TOKEN>_posthog` entry, `$groups` included. Officially confirmed in `https://posthog.com/docs/libraries/js/usage` (source `contents/docs/libraries/js/usage.mdx:105`):

> This also resets group analytics.

Note `reset()` early-returns if `!this.__loaded`.

### Un-setting a single group type

**There is no API for it in 1.297.4.** `resetGroups()` wipes all types at once; `resetGroupPropertiesForFlags(group_type)` takes a type argument but touches only the flag-evaluation property cache, not `$groups` (`posthog-featureflags.ts:931-938`):

```ts
    resetGroupPropertiesForFlags(group_type?: string): void {
        if (group_type) {
            const existingProperties = this._instance.get_property(STORED_GROUP_PROPERTIES_KEY) || {}
            this._instance.register({
                [STORED_GROUP_PROPERTIES_KEY]: { ...existingProperties, [group_type]: {} },
            })
        } else {
            this._instance.unregister(STORED_GROUP_PROPERTIES_KEY)
        }
    }
```

The only route is to rewrite the super property yourself — `posthog.register({ $groups: rest })` after removing the key from `posthog.getGroups()`. That is not a documented API; it works because `$groups` is an ordinary super property. Upstream tracking issue for splitting the concerns: [PostHog/posthog-js#600 "Split group & groupIdentify"](https://github.com/PostHog/posthog-js/issues/600) (open since 2023-04-01).

### Failure mode when you do not clear

Confirmed by the source: the association is persisted in localStorage and merged into every event, so it survives logout, browser close, and user switch on a shared device. User B's autocaptured clicks, pageviews, and custom events all carry User A's `$groups` until something clears it, and the flag-evaluation payload sends the stale `groups` to `/flags`, so B may receive A's org's flag variants.

The org-switch variant is [PostHog/posthog-js#1545](https://github.com/PostHog/posthog-js/issues/1545) (open, filed 2024-11-21), which describes the stickiness as the core defect:

> 1. Calling `posthog.group()` has a side-effect where subsequent events that captured are associated to the group.
> …
> 4. User switches tab to dashboard. All events from the dashboard are now assocaited with the project 🤦🏻‍♂️

That issue also documents the per-event escape hatch not working as a merge — **event-level `$groups` replaces the super property rather than merging**:

> **Expected result:** Your event is captured with both the project and the company
> **Actual result:** Event is only captured with the project. The company is dropped

The source confirms the mechanism: in the `extend({}, infoProperties, this.persistence.properties(), this.sessionPersistence.properties(), properties)` call at `posthog-core.ts:1314-1320`, the caller's `properties` object is spread **last**, so its `$groups` key overwrites the persisted one wholesale.

Secondary billing consequence: a lingering group forces identified-event processing. `_hasPersonProcessing()` (`posthog-core.ts:2918-2927`) treats a non-empty `$groups` as a reason to process person profiles even under `identified_only`:

```ts
    _hasPersonProcessing(): boolean {
        return !(
            this.config.person_profiles === 'never' ||
            (this.config.person_profiles === 'identified_only' &&
                !this._isIdentified() &&
                isEmptyObject(this.getGroups()) &&
                !this.persistence?.props?.[ALIAS_ID_KEY] &&
                !this.persistence?.props?.[ENABLE_PERSON_PROCESSING])
        )
    }
```

---

## 4. Ordering relative to `identify()`

**For the group state itself, order does not matter.** `identify()` (`posthog-core.ts:2040-2155`) never reads or writes `$groups`; `group()` never reads or writes `distinct_id`. Both are independent super-property writes.

**For event contents, order matters exactly as you'd expect:** `$groups` is attached at capture time from persistence, so any event captured *before* the `group()` call lacks it. `identify()` captures a `$identify` event at `posthog-core.ts:2123-2130`; calling `group()` first means that `$identify` carries `$groups`, calling it second means it does not.

**In 1.297.4 there is a real ordering bug, and it favors `identify()` first.** `capture()` calls `_calculate_set_once_properties()` unconditionally for every event including `$groupidentify` (`posthog-core.ts:1137`), and that method sets a one-shot latch (`posthog-core.ts:1363-1387`):

```ts
        if (this._personProcessingSetOncePropertiesSent) {
            // We only need to send these properties once. Sending them with later events would be redundant and would
            // just require extra work on the server to process them.
            return dataSetOnce
        }
        const initialProps = this.persistence.get_initial_props()
        const sessionProps = this.sessionPropsManager?.getSetOnceProps()
        let setOnceProperties = extend({}, initialProps, sessionProps || {}, dataSetOnce || {})
        ...
        this._personProcessingSetOncePropertiesSent = true
```

The server strips `$set_once` from `$groupidentify` events, so those initial properties are discarded and never re-sent. This is [PostHog/posthog-js#2725](https://github.com/PostHog/posthog-js/pull/2725), *"fix: include initial person props in $identify when group() called first"*, merged 2025-12-12 and released in **1.306.0** — i.e. **after** 1.297.4, so the bug is live in this build. From the PR body:

> Calling `group()` with properties before `identify()` causes initial person properties (UTM params, referrer, etc.) to be lost from the person profile.
> ```javascript
> posthog.group('organization', 'org_123', { name: 'Acme' })
> posthog.identify('user_123')
> // Result: Person missing $initial_utm_source, $initial_referrer, etc.
> ```
> **Root cause:** `group()` triggers `_calculate_set_once_properties()` which marks initial person props as "sent" via `_personProcessingSetOncePropertiesSent = true`. When `identify()` is called later, it skips sending these props because the flag is already set. However, the server ignores `$set_once` on `$groupidentify` events, so the initial props are never actually saved.
> …
> **Impact:** Affects customers using `person_profiles: 'identified_only'` who call `group()` before `identify()` a common B2B SaaS pattern where org context is set before user identification.

The PR cites the server-side strip at `plugin-server/src/utils/event.ts:180-189` in PostHog/posthog:

```typescript
if (!processPerson || event.event === '$groupidentify') {
    delete event.$set
    delete event.$set_once
}
```

**Practical rule for 1.297.4: call `identify()` before `group()`** when passing group properties, or the person profile permanently loses `$initial_utm_source`, `$initial_referrer`, and the rest of the initial-attribution set. Calling `group()` *without* properties does not trip the latch (no capture happens at all), so the ordering hazard is specific to the three-argument form.

---

## 5. @posthog/react 1.0.0

**No group-specific hook or provider prop exists.** Complete export list, `node_modules/@posthog/react/dist/types/index.d.ts:68`:

```ts
export { type PostHog, PostHogContext, PostHogErrorBoundary, type PostHogErrorBoundaryFallbackProps, type PostHogErrorBoundaryProps, PostHogFeature, type PostHogFeatureProps, PostHogProvider, useActiveFeatureFlags, useFeatureFlagEnabled, useFeatureFlagPayload, useFeatureFlagVariantKey, usePostHog };
```

Provider props (`index.d.ts:13-22`) — `client` XOR (`apiKey` + `options`), nothing group-related:

```ts
type PostHogProviderProps = {
    client: PostHog;
    apiKey?: never;
    options?: never;
} | {
    apiKey: string;
    options?: Partial<PostHogConfig>;
    client?: never;
};
```

`usePostHog` is a thin context read (`dist/esm/index.js:85-88`):

```js
var usePostHog = function () {
    var client = useContext(PostHogContext).client;
    return client;
};
```

Init happens inside a `useEffect` in the provider (`dist/esm/index.js:54-81`), so `posthog.init()` runs after the first render commit — a `group()` call in a child's `useEffect` on the same commit may run before init depending on tree order.

**The recommended pattern is exactly `useEffect` → `posthog.group()`,** per PostHog's React docs (`https://posthog.com/docs/libraries/react`, source `contents/docs/libraries/react/index.mdx:115-138`):

```react
import { usePostHog } from '@posthog/react'
import { useEffect } from 'react'
import { useUser, useLogin } from '../lib/user'

function App() {
    // `usePostHog`, like other React contexts, must be called at the top level of your component
    const posthog = usePostHog()
    const login = useLogin()
    const user = useUser()

    useEffect(() => {
        if (user) {
            // Identify sends an event, so you may want to limit how often you call it
            posthog?.identify(user.id, {
                email: user.email,
            })
            posthog?.group('company', user.company_id)
        }
    }, [posthog, user.id, user.email, user.company_id])
```

Two things worth reading off that snippet: the dependency array uses **scalar fields**, not the `user` object (an object identity would re-fire on every fetch); and the docs' own ordering is `identify()` then `group()`, which happens to be the order that avoids the §4 bug. The docs also warn against importing `posthog` directly (`react/index.mdx:106`):

> Always use the `usePostHog` hook to access the PostHog library. Directly importing `posthog` will likely cause errors as the library might not be initialized yet.

---

## 6. Autocapture and pageviews

**Yes — every autocaptured and pageview event picks up `$groups` automatically once `group()` has run**, with one exception.

Mechanism: autocapture calls the ordinary `capture()` (`node_modules/posthog-js/lib/src/autocapture.js:334`, `this.instance.capture(eventName, props)`), which routes through `calculateEventProperties`, which merges `this.persistence.properties()` — including `$groups` — into the event (`posthog-core.ts:1313-1320`). Nothing about `$autocapture`, `$pageview`, `$pageleave`, `$rageclick`, `$web_vitals`, `$feature_flag_called`, or `$identify` is special-cased for groups.

**Exception: `$snapshot` (session replay) events.** They return from `calculateEventProperties` before the super-property merge (`posthog-core.ts:1240-1251`):

```ts
        if (eventName === '$snapshot') {
            const persistenceProps = { ...this.persistence.properties(), ...this.sessionPersistence.properties() }
            properties['distinct_id'] = persistenceProps.distinct_id
            ...
            return properties
        }
```

**Timing of the very first pageview.** The initial `$pageview` fires one tick after the `loaded` callback (`posthog-core.ts:827-845`):

```ts
    _loaded(): void {
        try {
            this.config.loaded(this)
        } catch (err) {
            logger.critical('`loaded` function failed', err)
        }

        this._start_queue_if_opted_in()

        // this happens after "loaded" so a user can call identify or any other things before the pageview fires
        if (this.config.capture_pageview) {
            // NOTE: We want to fire this on the next tick as the previous implementation had this side effect
            // and some clients may rely on it
            setTimeout(() => {
                if (this.consent.isOptedIn() || this.config.cookieless_mode === 'always') {
                    this._captureInitialPageview()
                }
            }, 1)
        }
```

A synchronous `group()` inside `config.loaded` therefore lands on the initial pageview. A React `useEffect` that waits on an org API response does not — that first pageview goes out without `$groups`. On *subsequent* page loads the previously persisted `$groups` is already in localStorage at init, so the initial pageview does carry it; only the very first load of a fresh browser (or the first load after `reset()`) is uncovered.

One caveat on the docs' claim that `posthog.group()` links "all session events": the linkage is forward-only. `https://posthog.com/docs/product-analytics/group-analytics` (source `contents/docs/product-analytics/group-analytics.mdx:141,145`):

> - **JavaScript Web SDK:** Call `posthog.group()` once and all session events link to that individual group automatically.
>
> Events must be [identified](/docs/data/anonymous-vs-identified-events) to link to individual groups. If `$process_person_profile` is set to `false`, the event won't link to the group.

---

## 7. Known bugs and caveats in 1.297.4

**a. Two upstream group fixes are missing from this build.** Both are in `packages/browser/CHANGELOG.md`, both released after 1.297.4's 2025-11-24 publish date:

| Version | Date | PR | Change |
|---|---|---|---|
| 1.306.0 | 2025-12-12 | [#2725](https://github.com/PostHog/posthog-js/pull/2725) | `fix: include initial person props in $identify when group() called first` |
| 1.364.7 | 2026-04-03 | [#3319](https://github.com/PostHog/posthog-js/pull/3319) | `fix: send $groupidentify for new groups even when no properties are provided` |

Verified absent by reading the installed source, not by version comparison alone: `_calculate_set_once_properties` has no `$groupidentify` exclusion (`posthog-core.ts:1363-1387`), and `group()` still gates the capture on `if (groupPropertiesToSet)` (`posthog-core.ts:2267`). Latest published posthog-js is 1.414.0.

**b. Duplicate `$groupidentify` spam is real and unguarded in this version.** `group()` emits `$groupidentify` on *every* call that passes a third argument — same group, same properties, no change. A `useEffect` whose dependency array contains an inline properties object (`{ name: org.name }` reconstructed each render) fires a `$groupidentify` capture **and** a `/flags` POST (via `setGroupPropertiesForFlags` → `reloadFeatureFlags()`) on every render. PR #3319 later added dedup, but only for the no-properties path — from its description:

> - `group()` now sends `$groupidentify` when the group key is **new or changed**, even without properties.
> - When the group already exists with the same key and no properties are provided, the event is skipped (no redundant network traffic).
> - `$group_set` is only included in the event payload when properties are actually provided, matching the behavior of all other SDKs.

Even after that fix, repeated calls **with** properties still emit every time. The mitigation in 1.297.4 is caller-side: guard on `posthog.getGroups()[type] !== key` before calling, and keep the properties object out of the dependency array.

**c. Group not applied to the first pageview.** Covered in §6 — inherent to the `useEffect`-after-org-fetch pattern, not a library bug. The workaround is either `config.loaded` (synchronous, requires the org id at init) or `capture_pageview: false` + a manual `posthog.capture('$pageview')` after `group()`.

**d. There is no way to bootstrap groups.** `BootstrapConfig` in 1.297.4 (`types.ts:163-177`) has exactly five fields and none is group-related:

```ts
export interface BootstrapConfig {
    distinctID?: string
    isIdentifiedID?: boolean
    featureFlags?: Record<string, boolean | string>
    featureFlagPayloads?: Record<string, JsonType>
    sessionID?: string
}
```

Server-rendering the group into the page and calling `group()` synchronously in `config.loaded` is the only pre-first-event route.

**e. Event-level `$groups` overrides rather than merges** — see §3, [issue #1545](https://github.com/PostHog/posthog-js/issues/1545), mechanism at `posthog-core.ts:1314-1320`.

**f. Group state is stickier than user state.** `resetGroups()` leaves `$groups: {}` attached to every event and leaves `$epp` set; only `reset()` removes both. And `$groups` lives in localStorage, so it is not cleared by cookie-clearing, does not cross subdomains, and survives everything short of an explicit call.

**g. `group()` silently no-ops before `init()`.** `register()` is `this.persistence?.register(...)` (`posthog-core.ts:1426`) and `this.persistence` does not exist until `init()` runs. With the npm module (as opposed to the HTML snippet's queuing stub), a `group()` call that races `PostHogProvider`'s init `useEffect` is simply lost — no error, no queue.

**h. `person_profiles: 'never'` makes `group()` a no-op** with only a console error: *"posthog.group was called, but process_person is set to \"never\". This call will be ignored."* (`posthog-core.ts:2968-2977`).

**i. Group analytics is a paid feature.** `contents/docs/libraries/js/usage.mdx:123`: *"This is a paid feature and is not available on the open-source or free cloud plan."* And per `contents/docs/product-analytics/group-analytics.mdx:57`, billing then applies to all identified events, not only grouped ones.

**j. Hard product limits** (`group-analytics.mdx`, "Limitations"): max 5 group types per project; group types can be deleted but individual groups cannot; one event cannot carry two groups of the same type; group types are unsupported for lifecycle insights and user paths; only groups with known properties appear in the people tab.

---

## Sources

- [PostHog group analytics docs](https://posthog.com/docs/product-analytics/group-analytics) · raw: `https://raw.githubusercontent.com/PostHog/posthog.com/master/contents/docs/product-analytics/group-analytics.mdx`
- [PostHog JavaScript web usage docs](https://posthog.com/docs/libraries/js/usage) · raw: `.../contents/docs/libraries/js/usage.mdx`
- [PostHog JavaScript persistence docs](https://posthog.com/docs/libraries/js/persistence) · raw: `.../contents/docs/libraries/js/persistence.mdx`
- [PostHog React docs](https://posthog.com/docs/libraries/react) · raw: `.../contents/docs/libraries/react/index.mdx`
- [PostHog ingestion warnings docs](https://posthog.com/docs/data/ingestion-warnings) · raw: `.../contents/docs/data/ingestion-warnings.mdx`
- [PostHog group capture snippet](https://github.com/PostHog/posthog.com/blob/master/contents/docs/_snippets/capture-group-event-code.mdx)
- [posthog-js#3598 — Groups list does not show group when group has no properties](https://github.com/PostHog/posthog-js/issues/3598)
- [posthog-js#1545 — It's not possible to opt out subsequent group event capture](https://github.com/PostHog/posthog-js/issues/1545)
- [posthog-js#600 — Split group & groupIdentify](https://github.com/PostHog/posthog-js/issues/600)
- [posthog-js#2725 — include initial person props in $identify when group() called first](https://github.com/PostHog/posthog-js/pull/2725)
- [posthog-js#3319 — send $groupidentify for new groups even without properties](https://github.com/PostHog/posthog-js/pull/3319)
- [posthog-js packages/browser/CHANGELOG.md](https://github.com/PostHog/posthog-js/blob/main/packages/browser/CHANGELOG.md)
- [posthog-js posthog-core.ts (main)](https://github.com/PostHog/posthog-js/blob/main/packages/browser/src/posthog-core.ts)
- [posthog-js registry metadata](https://registry.npmjs.org/posthog-js)
- [PostHog tutorial: frontend vs backend group analytics](https://posthog.com/tutorials/frontend-vs-backend-group-analytics) (contains the `posthog.resetGroup()` docs error)
- [PostHog community question: posthog.resetGroup() is not a function?](https://posthog.com/questions/posthog-reset-group-is-not-a-function)