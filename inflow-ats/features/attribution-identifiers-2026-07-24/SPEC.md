# SPEC — Attribution identifiers for Meta, LinkedIn, Google Analytics (capture only)

**Working branch:** `attribution-work-qa` (main checkout `/Users/jessica/wrk/wrk-corp/inflow-ats` — see `REPO-PATH`)
**Origin:** Jessica's draft capture spec (2026-07-24), written by Claude and Webb, reworked against the live branch state. Corrections to the draft's factual claims are listed in §12. All five §13 decisions were ruled on by Jessica on 2026-07-24 and are marked RESOLVED; remaining **SPEC-PROPOSED** markers denote mechanical details (file names, helper structure, edge rules) left to spec review and planning, not open decisions.
**Prior art (binding analog):** the UTM/AdRoll capture already merged into this branch — `attribution-2026-07-15/SPEC.md` and commit `ec9f87232` ("Capture AdRoll click ID and first-party cookie at signup"). This feature adds new identifiers through the exact same pipeline; it introduces no new mechanism except cookie reading in the capture helper.

---

## 1. Summary

Capture eight additional attribution identifiers so they are on file for future server-side conversion APIs (GA4 Measurement Protocol, Meta CAPI, LinkedIn CAPI). Capture-only: nothing is sent to any ad platform in this PR.

1. **Six new identifiers on BOTH `users` and `organizations`:** `ga_client_id`, `ga_session_id`, `fbclid`, `fbp`, `fbc`, `li_fat_id`. All captured at user signup (the existing capture moments), copied onto the organization at creation (the existing copy mechanism in `Api::V1::OrganizationsController#create`).
2. **Two existing organization columns added to `users`:** `google_click_id` and `adroll_first_party_cookie`. Their collection point MOVES from the organization form to user signup; the organization now receives them as copies from `current_user` like every other attribution column.
3. **Collection-point removal:** `OrganizationForm.tsx` stops reading the `_gcl_aw` and `__adroll_fpc` cookies; `organization_params` stops permitting `:google_click_id` and `:adroll_first_party_cookie`. Attribution collection happens exactly once, at first touch on the auth/signup pages.

Funnel semantics (unchanged principle): a `users` row with identifiers but no organization = signed up, never created an org — that is the fall-off signal.

All columns nullable, no defaults, no backfill, absent = nil. Values are never hashed at capture (these are matching identifiers sent as plain strings to conversion APIs later).

## 2. Stack scope

- **Backend (Rails):** 2 schema migrations; `Api::V1::RegistrationsController#sign_up_params` (+ the `magic_create` `user_params` merge); `Api::V1::OrganizationsController` (`#create` copy lines, `organization_params` permit removal); `Api::V1::Users::OmniauthCallbacksController#google_oauth2`; `User.from_omniauth`; `config/initializers/omniauth.rb` setup lambda.
- **Frontend (React/TS):** `sanitizeTrackingParams` in `app/javascript/shared/lib/utils.js` (extended to read cookies); `AuthForm.tsx`; `SignupForm.tsx`; `GoogleSSOButton.tsx`; `OrganizationForm.tsx` (removal); `useSession.ts` (`magicLink` + `register`).
- **Not touched:** serializers, policies, models other than `user.rb`, Sidekiq jobs, `api.ts`, contexts, PostHog events, `heard_about_us_from` (user-entered field, not an attribution identifier — stays on the organization form), the `window.__adroll.record_user` call in `OrganizationForm.tsx` `handleSubmit` (outbound pixel event, not identifier collection — stays).

## 3. Data model changes

Two migrations, following the shape of `db/migrate/20260723222212_add_adroll_click_id_to_users.rb` / `20260723222213_add_adroll_columns_to_organizations.rb` (bare `add_column` calls, `ActiveRecord::Migration[6.1]`, `# frozen_string_literal: true`). Spec-proposed file names; class names to match:

- `db/migrate/<timestamp>_add_attribution_identifier_columns_to_users.rb`
- `db/migrate/<timestamp>_add_attribution_identifier_columns_to_organizations.rb`

| column | type | users | organizations |
|---|---|---|---|
| `ga_client_id` | string | NEW | NEW |
| `ga_session_id` | string (see §5.2 — raw cookie string; jsonb rejected by Jessica 2026-07-24) | NEW | NEW |
| `fbclid` | string | NEW | NEW |
| `fbp` | string | NEW | NEW |
| `fbc` | string | NEW | NEW |
| `li_fat_id` | string | NEW | NEW |
| `google_click_id` | string | NEW | already exists (schema line 1078) |
| `adroll_first_party_cookie` | string | NEW | already exists |

All nullable, no defaults, no indexes, no null constraints. No model changes: no validations, no enums — plain attributes assigned by mass assignment or direct setters, identical to the existing `utm_source`/`adroll_click_id` columns. `app/models/organization.rb` needs no edit.

**No backfill.** Existing rows keep nil. Organization rows that already carry `google_click_id`/`adroll_first_party_cookie` from the old org-form collection keep their values untouched.

### Schema commit rule (HARD — from Jessica, 2026-07-24)

The development environment's `db/schema.rb` is corrupted with unrelated local diffs. **Never stage `db/schema.rb` wholesale.** When committing, stage ONLY the hunks these two migrations introduce (`git add -p db/schema.rb`, or equivalent hunk-level staging), verify the staged diff contains exactly the new columns and the version bump, and nothing else. Jessica normally commits schema changes herself in part for this reason; any agent that commits must follow this rule exactly.

## 4. Capture rules per identifier

Sources are read at first touch on the auth/signup pages (URL params from `location.search`, cookies from `document.cookie`), at the existing capture moment — the `React.useState(sanitizeTrackingParams(...))` initializer in `AuthForm.tsx:41` and `SignupForm.tsx:26`. URL params must be read there because later pages no longer carry them.

| identifier | source | rule |
|---|---|---|
| `ga_client_id` | `_ga` cookie | Format `GA1.1.1234567890.1699999999`. Strip the first two dot-segments (`GA1.1.`/`GA1.2.`); store the remaining segments joined by `.` (`1234567890.1699999999`). **SPEC-PROPOSED edge rule:** if the value has fewer than 4 dot-segments (unexpected format), store the raw cookie value rather than guessing. |
| `ga_session_id` | all `_ga_*` cookies | See §5.2. Store raw — the draft itself calls raw storage "acceptable and safer". |
| `fbclid` | `fbclid` URL query param | From the URL — first occurrence when repeated, then the §5.1 cap, otherwise unmodified (the same handling `adct` gets from `sanitizeTrackingValue`, at the 1024 cap instead of 255). |
| `fbp` | `_fbp` cookie | Set by the Meta pixel for every visitor. Format `fb.1.<timestamp>.<random>`. Store verbatim; do not parse; do not hash. |
| `fbc` | `_fbc` cookie, URL fallback | Set by the Meta pixel only when the visitor arrived with an fbclid. Format `fb.1.<timestamp>.<fbclid_value>`. Store verbatim if present. FALLBACK: if the `_fbc` cookie is absent but the URL carries `fbclid`, construct `fb.1.<Date.now()>.<fbclid>` (Meta's documented construction; `Date.now()` = current unix ms at capture). Only construct when fbclid is genuinely present — never invent fbc otherwise. |
| `li_fat_id` | `li_fat_id` URL param, else `li_fat_id` cookie | URL param first; first-party cookie (written by LinkedIn's Insight Tag) as fallback. The Insight Tag is not installed yet (scheduled) — URL-param capture works regardless; the cookie fallback is written now and simply reads nothing until the tag ships. |
| `google_click_id` | `gclid` URL param first, else `_gcl_aw` cookie (**RESOLVED** — Jessica, 2026-07-24) | The draft says "add to users, captured at the same signup write moments" but names no source (§12 correction 1). Ruling: read the `gclid` URL param verbatim at first touch; if absent, fall back to the `_gcl_aw` cookie parsed exactly as `OrganizationForm.tsx:25-29` does today — split on `.`, take the last element when the split yields more than one segment (comment there: format `GCL.1719852261.actualGoogleClickIdHere`; the prefix is GTM-editable, so last-element is the safe read). When the split yields a single segment (dotless value), the cookie contributes nothing — the analog's `parsedArray && parsedArray.length > 1 ? parsedArray[parsedArray.length - 1] : null`; `google_click_id` is then absent unless the `gclid` URL param was present. The `_ga` raw-fallback rule does NOT apply here. |
| `adroll_first_party_cookie` | `__adroll_fpc` cookie | Verbatim — the same cookie `OrganizationForm.tsx:34` reads today, read at signup instead. |

Notes:
- **Repeated URL params:** `fbclid`, `li_fat_id`, and `gclid` reads keep the FIRST occurrence when the param repeats (`queryString.parse` returns an array for `?fbclid=a&fbclid=b` — same first-of-array rule `sanitizeTrackingValue` applies to `adct`), then the §5.1 cap. The `fbc` construction uses that first-occurrence `fbclid`. "Verbatim" means no further parsing, not exemption from these two steps.
- **"Present" for the conditional rules** — the `fbc` construction and the `li_fat_id`/`google_click_id` URL-first fallbacks — means the URL param value (after first-occurrence selection) is a non-empty string (`typeof x === "string" && x.length > 0`, the existing GoogleSSOButton guard form). query-string v6.1.0 parses a valueless `?fbclid` to `null` and `?fbclid=` to `""`; neither may trigger `fbc` construction, and either falls through to the cookie fallback for `li_fat_id`/`gclid`.
- The `_fbp`/`_fbc` cookies exist only where a Meta pixel runs; `_ga*` cookies only where a GA tag runs. The app layout loads GTM container `GTM-N6H844WJ` on all app pages including the auth pages (`app/views/layouts/application.html.erb:32-36`; auth routes render through `Hire::PagesController` → `hire/pages/root`). Which tags that container fires (GA4, Meta, AdRoll, LinkedIn) is GTM-side configuration, not in the repo. Additionally, pixels on the marketing site set cookies scoped to the eTLD+1 (`.polymer.co`), which are readable at `app.polymer.co`. Either way: **capture whatever exists, nil the rest** — the helper never fabricates.
- `adroll_click_id` (the `adct` URL param) is already fully captured on the branch — no change to it in this PR.

## 5. Frontend changes

### 5.1 `sanitizeTrackingParams` in `app/javascript/shared/lib/utils.js` — extended

The helper keeps its current signature and contract (raw `location.search` string in; camelCase fields out; occurrence-order derivation and `sanitizeTrackingValue` unchanged for the existing fields) and additionally reads `document.cookie` for the cookie-sourced identifiers. Reading `document.cookie` directly inside the helper is acceptable — there is no Jest in this codebase (Jessica's ruling 2026-07-16, recorded in the prior SPEC §9), so no injection seam is needed. (**SPEC-PROPOSED** mechanism; the contract below is what's binding, the internal structure is plan-level.)

New output fields, all absent when their source is absent (never `null`/`""` fabrication — repo rule 10):

- `gaClientId` — from `_ga` per §4
- `gaSessionId` — per §5.2
- `fbclid` — from URL param
- `fbp` — from `_fbp` cookie
- `fbc` — from `_fbc` cookie, else constructed from fbclid per §4
- `liFatId` — from URL param, else `li_fat_id` cookie
- `googleClickId` — from `gclid` URL param, else `_gcl_aw` cookie per §4
- `adrollFirstPartyCookie` — from `__adroll_fpc` cookie

Cookie-parsing rule: when extracting a cookie's value from `document.cookie`, split each cookie entry on the FIRST `=` only (value = everything after the first `=`). The existing `useCookieValue` hook's `cookie.split("=")[1]` would truncate a value containing `=`; the helper must not inherit that defect. (`useCookieValue` itself is not modified in this PR.) Cookie-NAME matching is exact: the name is the substring before the first `=`, compared by strict equality for `_ga`, `_fbp`, `_fbc`, `li_fat_id`, `_gcl_aw`, and `__adroll_fpc` — a `startsWith`-style lookup would let a `_ga_<CONTAINER>` cookie shadow `_ga` and corrupt `gaClientId`. Only `gaSessionId` matches by prefix (`_ga_`, which excludes the bare `_ga`). A cookie present with an empty value is treated as absent.

**Value cap (§13 decision 2 — RESOLVED, Jessica 2026-07-24):** the eight new values are truncated to **1024 code units** (surrogate-safe, same trailing-lone-high-surrogate rule as `sanitizeTrackingValue`) instead of the existing 255. Rationale: fbclid values longer than 255 characters occur in real Meta traffic, and `fbc` embeds the full fbclid — a 255 cap would corrupt exactly the identifier the capture exists for. The existing fields (`utm_*`, `internal_ref`, `adct`) keep their 255 cap unchanged. The draft's "store verbatim" and the sanitizer's truncation conflict; 1024 is the approved reconciliation. The cap applies to the FINAL field value — after the `_ga` strip, the `fbc` construction, and the `ga_session_id` join.

### 5.2 `ga_session_id` — raw string, not jsonb (§13 decision 3 — RESOLVED, Jessica 2026-07-24: no jsonb)

The draft suggests capturing every `_ga_<CONTAINER_ID>` cookie, jsonb "acceptable". Jessica rejected jsonb outright. A jsonb object keyed by cookie name does NOT survive this codebase's transport: `apiPost` runs `allKeysToSnake`, which recurses into nested objects and applies lodash `snakeCase` to every key (documented fact in prior SPEC §5, verified against `app/javascript/ats/src/lib/utils/structure.js`) — a key like `_ga_ABC123XYZ` would be mangled in transit, destroying the measurement ID it encodes. Instead:

- `gaSessionId` is a **single string**: every cookie whose name starts with `_ga_`, serialized as `<cookie_name>=<raw_value>`, joined with `"; "` when more than one exists (i.e., the relevant slice of `document.cookie`, verbatim). Example: `_ga_ABC123XYZ=GS1.1.1699999999.5.1.1699999999.0.0.0`.
- Field absent when no `_ga_*` cookie exists.
- This preserves the property/container identity AND the raw value (the draft notes the session_id is the 3rd value-segment but calls raw storage safer), survives `allKeysToSnake` untouched (values are never transformed, only keys), rides the SSO form as one plain hidden input, and needs only a plain `:ga_session_id` string permit. The future Measurement Protocol consumer parses it server-side, where GA cookie parsing is required anyway.
- The draft's claim that "two properties are installed" is not verifiable from the repo (GTM container config is external — §12 correction 4); capture-all makes the question moot.

### 5.3 `AuthForm.tsx`

- `trackingParams` (line 41) automatically carries the new fields once the helper is extended — no capture change.
- `magicLink` payload (inside `handleAuth`, alongside the existing `utmSource`…`adrollClickId` lines): add `gaClientId`, `gaSessionId`, `fbclid`, `fbp`, `fbc`, `liFatId`, `googleClickId`, `adrollFirstPartyCookie` from `trackingParams`.
- `GoogleSSOButton` props (line 129-138): pass the same eight.

### 5.4 `SignupForm.tsx`

- Same: add the eight fields to the `register` mutation payload from `trackingParams` (line 26).

### 5.5 `GoogleSSOButton.tsx`

- Extend `Props` with `gaClientId?`, `gaSessionId?`, `fbclid?`, `fbp?`, `fbc?`, `liFatId?`, `googleClickId?`, `adrollFirstPartyCookie?` (all `string`).
- Eight new hidden inputs following the exact existing guard pattern (`typeof x === "string" && x.length > 0`), with snake_case wire names: `ga_client_id`, `ga_session_id`, `fbclid`, `fbp`, `fbc`, `li_fat_id`, `google_click_id`, `adroll_first_party_cookie`. All plain single-value inputs — with §5.2, nothing new needs the Rails-nested `utm_data[<key>]` form.

### 5.6 `useSession.ts`

- `magicLink` and `register` request functions: add the eight fields to the destructured parameters, the `magicLink` inline TS type (`?: string | null` like the existing tracking fields), and both `variables` objects. `allKeysToSnake` produces the wire params `ga_client_id`, `ga_session_id`, `fbclid`, `fbp`, `fbc`, `li_fat_id`, `google_click_id`, `adroll_first_party_cookie` (lodash `snakeCase` leaves the single-word `fbclid`/`fbp`/`fbc` unchanged — reviewer should verify all eight transforms).

### 5.7 `OrganizationForm.tsx` — collection removal

- Remove lines 24-36: the `_gcl_aw` read/parse (`gclAwCookieValue`, `parsedArray`, `googleClickId`), the `__adroll_fpc` read (`adrollFirstPartyCookie`), and their two `window.logger` calls.
- Remove `googleClickId` and `adrollFirstPartyCookie` from the `createOrganization` payload (line 72) — payload becomes `{ name, heardAboutUsFrom }`.
- Remove the `useCookieValue` import if no other use remains in the file.
- Explicitly NOT removed: `heardAboutUsFrom` capture/payload, the `window.__adroll.record_user` block, the `trackEvent("organization_created")` call. A fix agent touching anything beyond the enumerated lines violates pipeline rule 23.

## 6. Backend changes

### 6.1 `Api::V1::RegistrationsController#sign_up_params`

Add `:ga_client_id, :ga_session_id, :fbclid, :fbp, :fbc, :li_fat_id, :google_click_id, :adroll_first_party_cookie` as plain single-value permits (before the trailing `utm_data: {}` hash permit, which must remain the last argument).

### 6.2 `#magic_create`

Add the eight keys to the `user_params` merge in **BOTH** branches of the two-branch conditional (lines 88-117), exactly as `utm_source`…`adroll_click_id` appear today:

```ruby
ga_client_id: sign_up_params[:ga_client_id],
ga_session_id: sign_up_params[:ga_session_id],
fbclid: sign_up_params[:fbclid],
fbp: sign_up_params[:fbp],
fbc: sign_up_params[:fbc],
li_fat_id: sign_up_params[:li_fat_id],
google_click_id: sign_up_params[:google_click_id],
adroll_first_party_cookie: sign_up_params[:adroll_first_party_cookie]
```

Values stored raw as sent; absent param → nil column. The existing-user branches remain inert (they read only `user_params[:email]`). No response-shape change.

### 6.3 `#create` (password path)

No change beyond 6.1 — `expanded_params = sign_up_params.merge(...)` flows the new permits into `build_resource` automatically.

### 6.4 `Api::V1::OrganizationsController`

**`#create`** — extend the copy block (lines 31-36) with the eight columns, same form:

```ruby
@organization.ga_client_id = current_user.ga_client_id
@organization.ga_session_id = current_user.ga_session_id
@organization.fbclid = current_user.fbclid
@organization.fbp = current_user.fbp
@organization.fbc = current_user.fbc
@organization.li_fat_id = current_user.li_fat_id
@organization.google_click_id = current_user.google_click_id
@organization.adroll_first_party_cookie = current_user.adroll_first_party_cookie
```

No re-capture at organization creation; the values never come from the request.

**`organization_params`** — remove `:google_click_id` and `:adroll_first_party_cookie` from the permit (line 120). Consequence: `#update` also stops accepting them (shared params method, per core rule 5 one-params-method). Nothing else sends them on update today; noted as fact, not a behavior change to work around.

### 6.5 `config/initializers/omniauth.rb` setup lambda

`allowed_keys` (line 14) gains the eight snake_case keys:

```ruby
allowed_keys = %w[partner referral utm_source utm_campaign utm_data internal_ref adroll_click_id
                  ga_client_id ga_session_id fbclid fbp fbc li_fat_id google_click_id adroll_first_party_cookie]
```

All eight arrive as plain strings from the hidden inputs; the existing loop (`value if value && !value.empty?`) handles them unchanged. They ride `session[:oauth_tracking]` to the callback exactly as today's keys do.

### 6.6 `User.from_omniauth` (`app/models/user.rb:379`)

Extend the keyword signature with eight nil-defaulted keywords, and assign each inside the `first_or_create` block alongside the existing assignments (creation-time only; existing users logging in via SSO untouched):

```ruby
def self.from_omniauth(auth:, created_via:, partner_source: nil, utm_source: nil, utm_campaign: nil,
                       utm_data: nil, internal_ref: nil, adroll_click_id: nil,
                       ga_client_id: nil, ga_session_id: nil, fbclid: nil, fbp: nil, fbc: nil,
                       li_fat_id: nil, google_click_id: nil, adroll_first_party_cookie: nil)
```

This continues the analog's per-keyword form exactly (16 keywords total). Jessica ruled (2026-07-24) to continue the per-keyword form — §13 decision 4, RESOLVED.

Post-block behavior (`new_user_created_via_google_sso`, `assign_attributes(remember_me: true)`, the names `update`, `enqueue_complete_user_setup`) unchanged.

**Call-site check (mandatory implementation step):** re-run `git grep -ln "from_omniauth"` at implementation time; extend every call site and keyword expectation found. As of this spec the grep returns FOUR files: the definition (`app/models/user.rb`), the sole APP call site (`app/controllers/api/v1/users/omniauth_callbacks_controller.rb:22`), and two spec files added in `ec9f87232` — `spec/models/user_from_omniauth_spec.rb` (direct keyword calls; the new nil-defaulted keywords are inert there until the §10 item 2 extensions) and `spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb` (exhaustive `have_received(:from_omniauth).with(...)` keyword expectations that FAIL once the call site gains eight keywords unless extended per §10 item 3).

### 6.7 `Api::V1::Users::OmniauthCallbacksController#google_oauth2`

Extend the `User.from_omniauth` call with the eight values from `merged_tracking` (string keys, same as today's five):

```ruby
ga_client_id: merged_tracking['ga_client_id'],
ga_session_id: merged_tracking['ga_session_id'],
fbclid: merged_tracking['fbclid'],
fbp: merged_tracking['fbp'],
fbc: merged_tracking['fbc'],
li_fat_id: merged_tracking['li_fat_id'],
google_click_id: merged_tracking['google_click_id'],
adroll_first_party_cookie: merged_tracking['adroll_first_party_cookie']
```

Nothing else in the action changes.

## 7. Authorization requirements

**None.** No new endpoints, no policy changes. Signup paths remain unauthenticated by design; `organizations#create` keeps its existing Pundit `authorize @organization`; the copied values come from `current_user`, never from request params (the permit removal in 6.4 narrows, not widens, what the request can set).

## 8. Constraints

1. **Nil for absent, everywhere.** No `|| ""`, no `|| {}`, no defaults (repo rule 10). A visitor with no Meta pixel cookies gets nil `fbp`/`fbc`; no Google click gets nil `google_click_id`; and so on.
2. **Raw storage, no hashing, no mapping, no downcasing.** These are matching identifiers for server-side conversion APIs; they must survive byte-exact (subject only to the §5.1 cap).
3. **Creation-time only.** Users get values only at row creation (`magic_create` new-user branch, `create`, `from_omniauth` `first_or_create` block). Existing users logging in are never updated. Organizations get values only at `organizations#create`, copied from `current_user`.
4. **Single collection point.** After this PR, no attribution identifier is collected anywhere except the signup capture. The org form collects none.
5. **No serializer exposure.** None of the new columns appear in any Api::V1 serializer.
6. **`fbc` is never fabricated for non-Meta traffic** — constructed only when a genuine fbclid is present and the `_fbc` cookie is absent.
7. **Existing capture behavior unchanged** — `utm_*`, `internal_ref`, `adct` keep their current sanitization (255 cap) and flow; `adroll_click_id` untouched.

## 9. Existing patterns to follow (analogs, verified in live code on `attribution-work-qa`)

| Pattern | Analog location | Used for |
|---|---|---|
| URL-param capture + sanitize into component state | `AuthForm.tsx:41`, `SignupForm.tsx:26` (`sanitizeTrackingParams` into `useState`) | all URL-sourced fields |
| Cookie read + parse (last-segment) | `OrganizationForm.tsx:24-34` (`_gcl_aw` split-dot-last, `__adroll_fpc` verbatim) | §4 gclid cookie fallback + adroll fpc — logic MOVES, parse rule preserved |
| Sanitizer value handling | `sanitizeTrackingValue` in `utils.js:31-40` (first-of-array, surrogate-safe truncation) | §5.1 cap (new 1024 constant for new fields) |
| Payload threading | `adrollClickId` through `AuthForm.tsx:85` → `useSession.ts` `magicLink`/`register` → `sign_up_params` | all eight fields |
| Hidden SSO inputs, render-only-when-present | `GoogleSSOButton.tsx:61-78` | §5.5 |
| Omniauth whitelist + session ride | `omniauth.rb:12-27` `allowed_keys` | §6.5 |
| Callback merged-tracking read | `omniauth_callbacks_controller.rb:9-31` | §6.7 |
| Creation-time keyword assignment | `from_omniauth` `first_or_create` block (`user.rb:385-398`) | §6.6 |
| Parent→child copy at org creation | `organizations_controller.rb:31-36` | §6.4 |
| Add-columns migration shape | `db/migrate/20260723222212` / `20260723222213` | §3 |

Per the analog-manifest rule (global CLAUDE.md): the plan phase must produce the structural manifest diff (files touched / not touched, columns read+written per step, logic locations, lifecycle) between the `adroll_click_id` chain and each new identifier's chain before implementation, with every DIFFERENT row justified by §4's source differences (cookie vs URL) and nothing else.

## 10. Test requirements

All four spec files below already exist and were extended for `adroll_click_id` in commit `ec9f87232` — extend each the same way for the eight new fields (this is an UPDATE to existing specs, not new files). Stale counts in header comments and example names ("five attribution values", "all five columns") are updated as part of the extension:

1. **`spec/controllers/api/v1/registrations_controller_spec.rb`** — `magic_create` new-user POST carrying all eight params → persisted raw on the created User (include a `ga_session_id` value containing `=`, `.`, and `;` to pin verbatim storage; include an `fbclid`-style value longer than 255 to pin that the server stores what it receives); POST with none → all eight nil; existing-user branches → columns untouched; `create` password path both ways. Keep the existing `login_intent: 'hire'` requirement on every `magic_create` POST.
2. **`spec/models/user_from_omniauth_spec.rb`** — new keywords persist on creation; omitted keywords → nil; existing user via SSO → untouched; keywords assigned raw.
3. **`spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb`** — seed `session[:oauth_tracking]` with all tracking keys → `from_omniauth` receives the eight values (pins the string-key session read and the extended call site). Both existing `have_received(:from_omniauth).with(...)` expectations are exhaustive keyword matches — the no-tracking example (`'passes nil for all five attribution values when no tracking rode the session'`, lines 69-83) must gain the eight new nil keywords too.
4. **`spec/controllers/api/v1/organizations_controller_spec.rb`** — `create` with a `current_user` carrying all eight → identical values on the new Organization; nils → nils. NEW assertion for the collection-point removal: a `create` request whose `organization` params include `google_click_id`/`adroll_first_party_cookie` values does NOT write them from params — the resulting organization carries `current_user`'s values (or nil), proving the permit removal. This INVERTS the existing example `'stores adroll_first_party_cookie from the request body'` (lines 59-69), which POSTs the value in the body and asserts it lands — update that example to the new behavior (request-body value ignored; organization carries `current_user`'s value or nil), and rewrite the file's header comment (lines 10-12), whose "adroll_first_party_cookie is the exception … it IS permitted through organization_params" paragraph becomes false after the permit removal.

**Jest: none** (house ruling 2026-07-16 — this codebase does not use Jest; the helper changes get no JS unit tests).

**Cypress:** read-only per repo rules. `cypress/e2e/auth/registration.cy.js` exercises both signup paths and runs in the pre-commit hook; the payload additions must not break it. No new Cypress tests.

## 11. Out of scope (explicit)

- Sending anything to GA4 Measurement Protocol, Meta CAPI, LinkedIn CAPI, or AdRoll — capture only.
- LinkedIn Insight Tag installation (scheduled separately; the cookie fallback simply reads nothing until then).
- Marketing-site capture/forwarding (`*.polymer.co` pages) — the app captures what reaches its own auth pages.
- Backfill or analysis of historical rows; migration of org-form-era `google_click_id` values onto users.
- Any PostHog event or identify change.
- Serializer exposure of any attribution column.

## 12. Corrections to the draft (facts verified on the branch)

1. **"written to the user at the same write moments GCLID is written" is wrong.** GCLID (`google_click_id`) is currently never written to users — it is collected via the `_gcl_aw` cookie on `OrganizationForm.tsx` and written to the organization at creation through `organization_params`. The pattern the new work actually follows is the UTM/AdRoll **signup** capture. The draft also names no signup-time source for gclid; §4 proposes one (decision 1).
2. **`adroll_click_id` needs no work.** The draft's framing predates commit `ec9f87232`: `adroll_click_id` is already on users AND organizations with the full signup capture (URL param `adct`), and `adroll_first_party_cookie` already exists on organizations on this branch — not just staging.
3. **"organization populated at creation via the same inheritance mechanism" — confirmed accurate** (`organizations_controller.rb:31-36`), and this PR extends that exact block.
4. **"two properties are installed" is unverifiable from the repo.** The app loads one GTM container (`GTM-N6H844WJ`); GA property configuration lives inside GTM. §5.2's capture-all string sidesteps needing to know.
5. **The draft's jsonb suggestion for `ga_session_id` would be corrupted in transit** — `allKeysToSnake` mangles cookie-name keys (§5.2). Raw-string storage proposed instead.
6. **"Standard pattern: stash in the Rails session via a before_action on the auth pages" —** the mechanism already on the branch is equivalent but different in detail: hidden form inputs on `GoogleSSOButton` → omniauth `setup` lambda → `session[:oauth_tracking]` → callback. No `before_action` involved. This PR extends the existing mechanism; it does not build the draft's variant.

## 13. Open decisions for Jessica (rule before Phase 2 spec review)

1. **`google_click_id` signup source — RESOLVED (Jessica, 2026-07-24):** `gclid` URL param first, `_gcl_aw` cookie fallback with the OrganizationForm parse (§4). The cookie remains the load-bearing source for the common marketing-site funnel; the URL param covers direct landings.
2. **Value cap for the new identifiers — RESOLVED (Jessica, 2026-07-24):** 1024 code units for the eight new values (§5.1); `utm_*`/`internal_ref`/`adct` stay at 255.
3. **`ga_session_id` storage — RESOLVED (Jessica, 2026-07-24):** the draft's jsonb is rejected ("don't do that at all"). Single raw string `<cookie_name>=<value>` ("; "-joined) per §5.2.
4. **`from_omniauth` signature growth — RESOLVED (Jessica, 2026-07-24):** continue the analog's per-keyword form to 16 keywords (§6.6). Collapsing tracking into a hash keyword is rejected; if the attribution columns are ever restructured it would be as a join table, and that is out of scope here — the per-column path is already started and gets finished as-is.
5. **Transition-window consequence of the collection-point removal — RESOLVED (Jessica, 2026-07-24): accepted.** Users who signed up BEFORE this ships (nil identifier columns) and create their organization AFTER it ships produce organizations with nil `google_click_id`/`adroll_first_party_cookie`. Jessica's rationale: tracking is not consistent today anyway; no org-form fallback is kept.

## 14. Risks / factual notes for review

1. **SSO session-cookie size.** `session[:oauth_tracking]` (default cookie store, ~4KB ceiling) now carries up to 8 more values. With the 1024 cap, a hostile/degenerate browser state can overflow the cookie (`ActionDispatch::Cookies::CookieOverflow`) for that request — an extension of the risk already accepted in the prior SPEC §11 note 2. Realistic values (~1.2KB total new) fit.
2. **Direct API callers bypass the frontend caps entirely** (no server-side sanitization, consistent with the approved prior design) — Postgres `character varying` is unlimited.
3. **Capture timing:** cookies are read at component render on the auth page. A pixel that sets `_fbp`/`_fbc` asynchronously AFTER render could be missed for a user who signs up within seconds of first landing; the fbc URL fallback covers the Meta-click case. Accepted property of capture-at-first-touch.
4. **`fbc` constructed timestamp** uses page-render time, not true click time — Meta's documented construction for exactly this situation.
5. **lodash `snakeCase` wire transforms** must be verified for all eight camelCase names during implementation (§5.6); single-word names (`fbclid`, `fbp`, `fbc`) pass through unchanged.
