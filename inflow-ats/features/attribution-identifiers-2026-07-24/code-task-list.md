# Code-level task list — attribution identifiers

Derived from `SPEC.md` in this directory. Each task is one code change on `attribution-work-qa` (repo: `/Users/jessica/wrk/wrk-corp/inflow-ats`). Spec section references in parentheses.

## Migrations

- [x] **T1** — New migration `add_attribution_identifier_columns_to_users`: `add_column :users, <col>, :string` for `ga_client_id`, `ga_session_id`, `fbclid`, `fbp`, `fbc`, `li_fat_id`, `google_click_id`, `adroll_first_party_cookie`. Shape of `20260723222212_add_adroll_click_id_to_users.rb`. (§3)
- [x] **T2** — New migration `add_attribution_identifier_columns_to_organizations`: same for `organizations`, six columns only — `ga_client_id`, `ga_session_id`, `fbclid`, `fbp`, `fbc`, `li_fat_id` (`google_click_id` and `adroll_first_party_cookie` already exist there). (§3)
- [x] **T3** — Run `bundle exec rails db:migrate`. When committing, stage `db/schema.rb` hunk-by-hunk (`git add -p`) — only the new columns and version bump; the dev schema carries unrelated corruption that must never be committed. (§3 hard rule)

## Frontend — capture

- [x] **T4** — `app/javascript/shared/lib/utils.js`: extend `sanitizeTrackingParams` with cookie reading and eight new output fields. Sub-tasks:
  - [x] T4a — Cookie extraction that splits each `document.cookie` entry on the FIRST `=` only (do not inherit `useCookieValue`'s `split("=")[1]` truncation; `useCookieValue` itself untouched). Cookie-NAME matching is exact-equality for `_ga`, `_fbp`, `_fbc`, `li_fat_id`, `_gcl_aw`, `__adroll_fpc` (no `startsWith` — `_ga_<CONTAINER>` must not shadow `_ga`); only `gaSessionId` matches by `_ga_` prefix. Empty-value cookie = absent. (§5.1)
  - [x] T4b — `gaClientId`: `_ga` cookie, drop first two dot-segments, join the rest; fewer than 4 segments → store raw. (§4)
  - [x] T4c — `gaSessionId`: all `_ga_*` cookies serialized as `<cookie_name>=<raw_value>`, `"; "`-joined — single raw string, NOT jsonb. (§5.2)
  - [x] T4d — `fbclid`: URL param — first occurrence when repeated, then the 1024 cap; no other transformation. (§4)
  - [x] T4e — `fbp`: `_fbp` cookie, verbatim. (§4)
  - [x] T4f — `fbc`: `_fbc` cookie verbatim; if absent AND URL `fbclid` present, construct `fb.1.<Date.now()>.<fbclid>`; never construct otherwise. "Present" = first-occurrence value is a non-empty string (`typeof x === "string" && x.length > 0`) — `?fbclid` (null) and `?fbclid=` ("") never construct. (§4)
  - [x] T4g — `liFatId`: `li_fat_id` URL param first, `li_fat_id` cookie fallback. URL value must be a non-empty string, else fall through to the cookie. (§4)
  - [x] T4h — `googleClickId`: `gclid` URL param first (non-empty string, else cookie fallback); `_gcl_aw` cookie fallback parsed per the `OrganizationForm.tsx:25-29` rule (split `.`, last element when >1 segment; a single-segment/dotless value contributes nothing — no raw fallback). Approved — decision 1 RESOLVED. (§4, §13.1)
  - [x] T4i — `adrollFirstPartyCookie`: `__adroll_fpc` cookie, verbatim. Capture location moves here from the org form. (§4)
  - [x] T4j — New 1024-code-unit surrogate-safe cap applied to the eight new values (to the FINAL field value — after the `_ga` strip, `fbc` construction, `ga_session_id` join); existing fields keep 255. Approved — decision 2 RESOLVED. (§5.1, §13.2)
  - [x] T4k — All new fields absent (not null/empty) when their source is absent. (§5.1)

## Frontend — threading

- [x] **T5** — `AuthForm.tsx`: add `gaClientId`, `gaSessionId`, `fbclid`, `fbp`, `fbc`, `liFatId`, `googleClickId`, `adrollFirstPartyCookie` from `trackingParams` to (a) the `magicLink` payload in `handleAuth`, (b) the `GoogleSSOButton` props. (§5.3)
- [x] **T6** — `SignupForm.tsx`: add the same eight to the `register` payload. (§5.4)
- [x] **T7** — `GoogleSSOButton.tsx`: extend `Props` with the eight optional strings; render eight hidden inputs (`ga_client_id`, `ga_session_id`, `fbclid`, `fbp`, `fbc`, `li_fat_id`, `google_click_id`, `adroll_first_party_cookie`) behind the existing `typeof x === "string" && x.length > 0` guard. (§5.5)
- [x] **T8** — `useSession.ts`: add the eight to `magicLink` and `register` — destructured params, the `magicLink` inline TS type, both `variables` objects. Verify the lodash `snakeCase` wire transform of each name. (§5.6, §14.5)

## Frontend — collection-point removal (move capture location of Google Click ID + AdRoll first-party cookie)

- [x] **T9** — `OrganizationForm.tsx`: remove lines 24-36 (per §5.7 — the `_gcl_aw` read/parse `gclAwCookieValue`/`parsedArray`/`googleClickId` with its comment lines, both `window.logger` calls, the AdRoll comment at line 33, and the `__adroll_fpc` read `adrollFirstPartyCookie`), and remove `googleClickId`/`adrollFirstPartyCookie` from the `createOrganization` payload (line 72 → `{ name, heardAboutUsFrom }`); drop the `useCookieValue` import if unused. Do NOT touch `heardAboutUsFrom`, `window.__adroll.record_user`, or `trackEvent("organization_created")`. (§5.7)

## Backend

- [x] **T10** — `app/controllers/api/v1/registrations_controller.rb` `sign_up_params`: permit the eight new snake_case params as plain values, keeping `utm_data: {}` as the trailing argument. (§6.1)
- [x] **T11** — `registrations_controller.rb` `magic_create`: merge the eight `sign_up_params` keys into `user_params` in BOTH branches of the conditional (lines 88-117). (§6.2; password-path `create` needs nothing beyond T10 — §6.3)
- [x] **T12** — `app/controllers/api/v1/organizations_controller.rb` `#create`: copy the eight columns from `current_user` onto `@organization`, extending the existing block at lines 31-36. (§6.4)
- [x] **T13** — `organizations_controller.rb` `organization_params`: remove `:google_click_id` and `:adroll_first_party_cookie` from the permit. (§6.4)
- [x] **T14** — `config/initializers/omniauth.rb`: add the eight keys to `allowed_keys` in the `setup` lambda. (§6.5)
- [x] **T15** — `app/models/user.rb` `from_omniauth`: add eight nil-defaulted keywords to the signature and eight assignments inside the `first_or_create` block. Per-keyword form — Jessica's ruling 2026-07-24 (§13.4 RESOLVED). (§6.6)
- [x] **T16** — `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` `#google_oauth2`: pass the eight `merged_tracking['<key>']` values to `User.from_omniauth`. Re-run `git grep -ln "from_omniauth"` and extend every call site and keyword expectation found (four files as of the spec — see §6.6). (§6.7)

## Tests (all extensions of existing files, mirroring the `adroll_click_id` additions in `ec9f87232`)

- [x] **T17** — `spec/controllers/api/v1/registrations_controller_spec.rb`: eight params persisted raw on `magic_create` new-user POST (include a `ga_session_id` value with `=`/`.`/`;`; include a >255-char fbclid-style value); absent → nil; existing-user branches untouched; password-path `create` both ways; keep `login_intent: 'hire'` on every `magic_create` POST. (§10.1)
- [x] **T18** — `spec/models/user_from_omniauth_spec.rb`: new keywords persisted on creation, omitted → nil, existing SSO user untouched, values raw. (§10.2)
- [x] **T19** — `spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb`: `session[:oauth_tracking]` seeded with all keys → `from_omniauth` receives the eight values. Both exhaustive `have_received(:from_omniauth).with(...)` expectations extended — the no-tracking example (lines 69-83) gains the eight nil keywords. (§10.3)
- [x] **T20** — `spec/controllers/api/v1/organizations_controller_spec.rb`: `create` copies the eight from `current_user` (values and nils); NEW assertion that `organization[google_click_id]`/`organization[adroll_first_party_cookie]` request params are ignored after the permit removal. Also UPDATE the existing example `'stores adroll_first_party_cookie from the request body'` (lines 59-69, now inverted — request-body value ignored) and rewrite the header comment's request-body-exception paragraph (lines 10-12). (§10.4)
- [x] **T21** — Full RSpec run green; `cypress/e2e/auth/registration.cy.js` passes via the pre-commit hook. No Jest (house ruling). (§10)

## Decisions (SPEC §13) — all five RESOLVED by Jessica, 2026-07-24

- Decision 1 — gclid: URL param first, `_gcl_aw` cookie fallback → T4h
- Decision 2 — 1024 cap for the eight new values; UTM stays 255 → T4j
- Decision 3 — jsonb rejected; `ga_session_id` is a plain string → T1, T2, T4c, T7, T10
- Decision 4 — per-keyword `from_omniauth` → T15
- Decision 5 — transition-window nils accepted; no org-form fallback → T9, T13
