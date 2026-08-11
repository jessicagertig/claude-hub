# Review Angles — Attribution identifiers for Meta, LinkedIn, Google Analytics (capture only)

Generated from: SPEC.md (this directory)
Date: 2026-07-24

Repo: `/Users/jessica/wrk/wrk-corp/inflow-ats`, branch `attribution-work-qa` (per REPO-PATH). All line numbers below verified live on the branch.

**Severity calibration (harness-profile.md):** MED means "should be fixed." An observation that doesn't warrant a fix is a note/LOW — never MED. Missing RSpec coverage is never HIGH or MED on its own; broken/wrong specs are real findings; ghost tests are BLOCKER.

## Subsystems touched

**Migrations**
- `db/migrate/<timestamp>_add_attribution_identifier_columns_to_users.rb` (NEW — 8 string columns)
- `db/migrate/<timestamp>_add_attribution_identifier_columns_to_organizations.rb` (NEW — 6 string columns; `google_click_id` at schema.rb:1078 and `adroll_first_party_cookie` at schema.rb:1094 already exist on organizations)
- `db/schema.rb` — hunk-level staging ONLY (SPEC §3 HARD rule: dev schema carries unrelated corruption)

**Frontend**
- `app/javascript/shared/lib/utils.js` — `sanitizeTrackingParams` (42-91) extended with cookie reading + 8 output fields; new 1024-code-unit cap constant alongside `TRACKING_VALUE_MAX_LENGTH = 255` (28)
- `app/javascript/ats/src/views/sessions/components/AuthForm.tsx` — magicLink payload (~85), GoogleSSOButton props (129-138)
- `app/javascript/ats/src/views/sessions/components/SignupForm.tsx` — register payload (~71)
- `app/javascript/ats/src/views/sessions/components/GoogleSSOButton.tsx` — Props (9-19), 8 hidden inputs (after 76-78)
- `app/javascript/ats/src/views/sessions/components/OrganizationForm.tsx` — REMOVAL: lines 24-36 (`_gcl_aw` read/parse, `__adroll_fpc` read, both `window.logger` calls), payload at 72 → `{ name, heardAboutUsFrom }`, `useCookieValue` import at 14 if unused
- `app/javascript/shared/queryHooks/useSession.ts` — `register` (27-56) and `magicLink` (58-114): destructured params, inline TS type, both `variables` objects

**Backend**
- `app/controllers/api/v1/registrations_controller.rb` — `sign_up_params` (310-313), `magic_create` user_params merge BOTH branches (97-101 and 111-115); password `#create` needs nothing beyond the permit (`expanded_params = sign_up_params.merge` at 13 → `build_resource` at 20)
- `app/controllers/api/v1/organizations_controller.rb` — `#create` copy block (31-36) extended; `organization_params` (120) drops `:google_click_id, :adroll_first_party_cookie`
- `config/initializers/omniauth.rb` — `allowed_keys` (14) gains 8 keys
- `app/models/user.rb` — `from_omniauth` signature (379) → 16 keywords; assignments in `first_or_create` block (385-398)
- `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` — `google_oauth2` call site (22-31) gains 8 `merged_tracking['<key>']` arguments

**Specs (all extensions of existing files, per SPEC §10)**
- `spec/controllers/api/v1/registrations_controller_spec.rb`
- `spec/models/user_from_omniauth_spec.rb`
- `spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb`
- `spec/controllers/api/v1/organizations_controller_spec.rb`

**Not touched:** serializers, policies, models other than `user.rb`, jobs, `api.ts`, contexts, PostHog events, `heard_about_us_from`, `window.__adroll.record_user`, `useCookieValue.ts` itself, Cypress files (read-only).

## Full-stack analog

The `adroll_click_id` capture chain, commit `ec9f87232` ("Capture AdRoll click ID and first-party cookie at signup"), traced whole in live code:

1. **Capture:** `utils.js:68-70` — `parsedParams.adct !== undefined` → `trackingParams.adrollClickId = sanitizeTrackingValue(parsedParams.adct)`. `sanitizeTrackingValue` (31-40): first-of-array for repeated params, `.slice(0, 255)`, trailing-lone-high-surrogate drop.
2. **Component state:** `AuthForm.tsx:41` and `SignupForm.tsx:26` — `React.useState(sanitizeTrackingParams(location.search))`, capture at first render only.
3. **JSON payloads:** `AuthForm.tsx:85` (`adrollClickId: trackingParams.adrollClickId` in magicLink), `SignupForm.tsx:71` (register).
4. **SSO props:** `AuthForm.tsx:136` → `GoogleSSOButton.tsx:17` (Props), `:29` (destructure), `:76-78` (hidden input `name="adroll_click_id"` behind `typeof adrollClickId === "string" && adrollClickId.length > 0`).
5. **Mutation hooks:** `useSession.ts` — `register` param 38 + variables 53; `magicLink` param 71 + inline type 85 (`adrollClickId?: string | null`) + variables 111.
6. **Wire transform:** `app/javascript/shared/queryHooks/api.ts:52` `allKeysToSnake(variables)` → `app/javascript/ats/src/lib/utils/structure.js:94-108` (lodash `snakeCase` on every key, recursing into nested objects — the fact that killed jsonb for `ga_session_id`).
7. **Permit:** `registrations_controller.rb:312` — `:adroll_click_id` before the trailing `utm_data: {}`.
8. **magic_create merge:** lines 101 and 115 — BOTH branches of the `user_params` conditional (88-117).
9. **Password path:** nothing beyond the permit — `expanded_params = sign_up_params.merge(...)` at line 13.
10. **Omniauth ride:** `omniauth.rb:14` `allowed_keys`; loop 17-24 (`value if value && !value.empty?`) → `session[:oauth_tracking]`.
11. **Callback:** `omniauth_callbacks_controller.rb:9-31` — `session.delete(:oauth_tracking)`, `merged_tracking`, string-key read at 30.
12. **Model:** `user.rb:379` keyword signature; assignment at 393 inside `first_or_create` (385-398); creation-time only.
13. **Org copy:** `organizations_controller.rb:36` — `@organization.adroll_click_id = current_user.adroll_click_id`.
14. **Migrations:** `db/migrate/20260723222212_add_adroll_click_id_to_users.rb`, `20260723222213_add_adroll_columns_to_organizations.rb` — `# frozen_string_literal: true`, `ActiveRecord::Migration[6.1]`, bare `add_column`.
15. **Specs:** all four files above extended in the same commit — four→five column assertions, raw-value + nil + existing-user-untouched + copy cases, `have_received(:from_omniauth).with(...)` keyword expectations.
16. **The analog's second identifier (`adroll_first_party_cookie`)** took the OTHER path — `OrganizationForm.tsx:34` `useCookieValue("__adroll_fpc")` → payload 72 → `organization_params` permit 120 → request-body write at org creation. THIS path is what the new feature dismantles (collection-point move).

**Priority rule:** Where the full-stack analog deviates from convention, the analog wins. Sanctioned deviations FROM the analog in this feature (do NOT flag):
- **1024 cap for the eight new values** vs the analog's 255 (§13 decision 2, RESOLVED). Existing fields keep 255.
- **Cookie reading inside `sanitizeTrackingParams` via `document.cookie` directly** — not via `useCookieValue` (no-Jest ruling 2026-07-16; and `useCookieValue`'s `cookie.split("=")[1]` truncation defect must NOT be inherited — split on FIRST `=` only, value = everything after).
- **`adroll_first_party_cookie`/`google_click_id` leaving `organization_params`** — deliberate reversal of the analog's own request-body path (§13 decision 5, RESOLVED; transition-window nils accepted).
- **Per-keyword `from_omniauth` to 16 keywords** — continues the analog form; hash-collapse rejected (§13 decision 4, RESOLVED).

## Angles

### per-identifier-capture-contract
**What this covers:** Each of the eight identifiers is read from exactly its §4 source with exactly its §4 parse rule — `_ga` first-two-dot-segment strip with <4-segment raw fallback; `ga_session_id` as the raw `"; "`-joined `_ga_*` slice (single string, NOT jsonb); `fbp`/`fbc` verbatim; the `fbc` construction guard (`fb.1.<Date.now()>.<fbclid>` ONLY when `_fbc` absent AND fbclid genuinely present — never fabricated otherwise); `li_fat_id` URL-first cookie-fallback; `gclid` URL-first `_gcl_aw`-fallback with the split-dot-last-element parse preserved from `OrganizationForm.tsx:25-29`; `__adroll_fpc` verbatim; cookie-entry split on FIRST `=` only; 1024-cap applied to the eight (surrogate-safe, same trailing-lone-high-surrogate rule) while existing fields keep 255; repeated-URL-param first-occurrence handling for the URL-sourced fields.
**Files across all layers:** `app/javascript/shared/lib/utils.js` (`sanitizeTrackingParams`, `sanitizeTrackingValue`, the new cap constant); `OrganizationForm.tsx:24-31` (the parse rule being MOVED, must survive byte-identical); `app/javascript/shared/hooks/useCookieValue.ts` (the defect NOT to inherit — file itself untouched)
**Analog files for comparison:** `utils.js:59-70` (existing per-field guards `!== undefined` + sanitize), `utils.js:31-40` (`sanitizeTrackingValue`), `OrganizationForm.tsx:24-36`
**Convention context:** `cursor_rules/core_critical_rules.md` rules 10 (never fabricate fallbacks) and 13 (strict comparisons; loose only vs `undefined`); repo CLAUDE.md failure pattern 28 (query-string v6.1.0 sorted parse — occurrence order only matters for existing `utm_data` logic, which must be untouched)

### collection-point-move
**What this covers:** The one destructive part of the feature. `OrganizationForm.tsx` stops reading `_gcl_aw`/`__adroll_fpc` (lines 24-36 removed including the comment lines and both `window.logger` calls), payload narrows to `{ name, heardAboutUsFrom }`; `organization_params` (line 120) drops the two permits — with the shared-params-method consequence that `#update` also stops accepting them (stated fact, not to be worked around); `#create` now copies both from `current_user` instead. Scope discipline is first-class here: `heardAboutUsFrom`, `window.__adroll.record_user`, `trackEvent("organization_created")`, and `useReferrerCookie.ts` stay untouched (pipeline rules 10/23). The §13.5 transition consequence (pre-ship users creating post-ship orgs → nil `google_click_id`/`adroll_first_party_cookie`) is ACCEPTED — do not flag it; flag any org-form fallback someone adds to "fix" it.
**Files across all layers:** `OrganizationForm.tsx`; `organizations_controller.rb` (`#create` 31-36, `organization_params` 120); `spec/controllers/api/v1/organizations_controller_spec.rb` — NOTE: its existing example `'stores adroll_first_party_cookie from the request body'` (lines ~58-68) and its header comment documenting the request-body exception (lines ~10-12) assert the OLD behavior and must be updated/inverted, not just appended to
**Analog files for comparison:** the analog's own `ec9f87232` OrganizationForm/organization_params additions — this feature reverses them; the `@organization.adroll_click_id = current_user.adroll_click_id` copy line (organizations_controller.rb:36) is the pattern the two moved columns now join
**Convention context:** `cursor_rules/core_critical_rules.md` rule 5 (one params method per controller — why `#update` is affected); repo CLAUDE.md rules 10/23 (fix/impl agents must not touch beyond enumerated lines)

### sso-session-ride
**What this covers:** The eight values riding the Google SSO path end-to-end: hidden inputs (snake_case names, existing `typeof x === "string" && x.length > 0` guard, all plain single-value — nothing uses the Rails-nested `utm_data[<key>]` form) → `allowed_keys` in the omniauth setup lambda → `session[:oauth_tracking]` (json cookie serializer, string keys) → `merged_tracking` string-key reads in the callback → `from_omniauth` 16-keyword signature → assignments inside `first_or_create` only (existing SSO users untouched; post-block behavior unchanged). Includes the mandatory call-site re-grep (`git grep -ln "from_omniauth"` now returns 4 files — the two spec files' direct calls and `have_received(...).with(...)` keyword expectations must be extended or every example fails at dispatch). Also: the setup-lambda guard `value && !value.empty?` vs the `ga_session_id` value (contains `=`, `;`, spaces — must ride intact), and the §14.1 session-cookie ~4KB ceiling with up to 8 more ≤1024-unit values (accepted risk — note-only unless the implementation worsens it).
**Files across all layers:** `GoogleSSOButton.tsx`; `config/initializers/omniauth.rb:12-27`; `omniauth_callbacks_controller.rb:9-31`; `user.rb:379-413`; `spec/models/user_from_omniauth_spec.rb`; `spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb`
**Analog files for comparison:** the `adroll_click_id` additions at each of those exact locations (`omniauth.rb:14`, callback :30, `user.rb:379`/`:393`, `GoogleSSOButton.tsx:76-78`)
**Convention context:** repo CLAUDE.md failure pattern 30 (Devise controller specs need BOTH `Devise::Test::ControllerHelpers` AND `devise.mapping` — already correct in the existing spec files, must stay); pattern 31 (inline queue adapter — existing `around` blocks must stay)

### wire-format-integrity
**What this covers:** Name integrity across the three transports. JSON paths: camelCase payload fields → `allKeysToSnake` (lodash `snakeCase` per key) → wire params — all eight transforms verified individually (`gaClientId`→`ga_client_id`, `gaSessionId`→`ga_session_id`, `liFatId`→`li_fat_id`, `googleClickId`→`google_click_id`, `adrollFirstPartyCookie`→`adroll_first_party_cookie`; single-word `fbclid`/`fbp`/`fbc` pass through unchanged). SSO path: hidden-input names are written snake_case directly (bypasses `allKeysToSnake`) and must equal the `allowed_keys` entries, which must equal the permit names, which must equal the column names. The `ga_session_id` raw-string decision exists BECAUSE `allKeysToSnake` recurses into nested objects and would mangle `_ga_<CONTAINER>` cookie-name keys (structure.js:104) — any reviewer or implementer reintroducing an object/jsonb shape for it is a BLOCKER against a RESOLVED decision. Values are never transformed by `allKeysToSnake` (only keys) — the `=`/`;`-laden `ga_session_id` value must arrive byte-exact on both JSON and form paths.
**Files across all layers:** `useSession.ts`; `app/javascript/shared/queryHooks/api.ts:52`; `app/javascript/ats/src/lib/utils/structure.js:94-108`; `GoogleSSOButton.tsx`; `registrations_controller.rb:312`; `omniauth.rb:14`; both migrations (column names)
**Analog files for comparison:** `adrollClickId`/`adroll_click_id` at every hop (useSession.ts:38/53/71/85/111; GoogleSSOButton.tsx:77; sign_up_params; allowed_keys)
**Convention context:** `cursor_rules/core_critical_rules.md` rule 7 (backend snake_case / frontend camelCase, API layer transforms)

### nil-absence-semantics
**What this covers:** Absent source → absent everywhere, at every layer, for all eight: helper omits the key entirely (no `null`/`""` fabrication); absent fields serialize out of the JSON body; `sign_up_params[<key>]` → nil column; SSO hidden input not rendered (guard) → key absent from `oauth_tracking` → `merged_tracking['<key>']` nil → nil-defaulted keyword → nil column; org copy of a nil user column → nil org column. The `fbc` never-fabricate guard is the sharpest instance (constraint §8.6). No `|| 0`, `|| ""`, `|| {}`, `|| []` anywhere in the new code.
**Files across all layers:** `utils.js`; `GoogleSSOButton.tsx`; `useSession.ts`; `registrations_controller.rb`; `omniauth.rb`; `omniauth_callbacks_controller.rb`; `user.rb`; `organizations_controller.rb`
**Analog files for comparison:** the existing `!== undefined` per-field guards in `sanitizeTrackingParams` (utils.js:59-70); the analog's nil assertions in all four spec files
**Convention context:** `cursor_rules/core_critical_rules.md` rules 9 (never deliberately set undefined) and 10 (never fabricate fallbacks); repo CLAUDE.md failure pattern 13

### creation-time-only-and-existing-behavior-unchanged
**What this covers:** The eight values land ONLY at row creation (magic_create new-user branch — the merge must appear in BOTH branches of the 88-117 conditional; password `#create` via the permit; `from_omniauth` `first_or_create` block) — existing users logging in are never updated, existing-user magic_create branches remain inert (read only `user_params[:email]`), no response-shape change. Organizations get values only via the `#create` copy, never from the request. Existing capture behavior byte-identical: `utm_*`/`internal_ref`/`adct` keep the 255 cap, occurrence-order `utm_data` logic, and flow; `adroll_click_id` untouched; no serializer exposes any attribution column; no policy/route/job changes; `heard_about_us_from` stays a user-entered org-form field.
**Files across all layers:** `registrations_controller.rb:88-117`; `user.rb:385-398`; `organizations_controller.rb:26-54`; `utils.js` (existing field paths); every Api::V1 serializer (verify absence)
**Analog files for comparison:** the analog's placement of `adroll_click_id` at exactly these points and nowhere else — any new write moment for the eight (e.g., an update path, a login-time backfill) is EXTRA vs the analog manifest and an automatic mismatch
**Convention context:** global CLAUDE.md analog-manifest rule (structure, not process — the plan phase owes the row-by-row manifest diff); repo CLAUDE.md failure pattern 14 (structural matching, not layer completeness)

### migrations-and-schema-hygiene
**What this covers:** Two migrations matching the analog shape exactly (`# frozen_string_literal: true`, `ActiveRecord::Migration[6.1]`, bare `add_column`, `:string`, no defaults/indexes/constraints); users migration has EIGHT columns, organizations migration has SIX (`google_click_id`/`adroll_first_party_cookie` already exist there — adding them again breaks the migration); no model edits (`organization.rb` untouched — also a hard repo rule); and the §3 HARD schema-commit rule: `db/schema.rb` staged hunk-by-hunk, staged diff contains exactly the new columns and version bump and none of the dev checkout's unrelated corruption. The impl review must inspect the COMMITTED schema diff, not the working tree.
**Files across all layers:** the two new `db/migrate/` files; `db/schema.rb` (users table ~1291ff, organizations table ~1078ff)
**Analog files for comparison:** `db/migrate/20260723222212_add_adroll_click_id_to_users.rb`, `db/migrate/20260723222213_add_adroll_columns_to_organizations.rb`, and `ec9f87232`'s schema.rb hunks (clean: columns + version only)
**Convention context:** repo CLAUDE.md failure pattern 15 (review committed code, not working tree); global CLAUDE.md database-safety rules (only `db:migrate`-family commands)

## Always-on checks

### Source accuracy
The review agent verifies every file path, class, method, column, route, and component the spec references against the current source. All line references in SPEC §§4-6 and §9 were verified live for this document (2026-07-24); re-verify at review time — the branch moves.

### Test coverage
Calibrated per harness-profile.md: Cypress is top priority — `cypress/e2e/auth/registration.cy.js` is read-only, runs pre-commit, and must pass; the payload additions must not break it. Customer/public API specs: not touched by this feature. All other RSpec strongly deprioritized — "missing RSpec coverage" is never HIGH or MED on its own; the SPEC §10 extensions are the required scope (including the pinning values: a `ga_session_id` containing `=`/`.`/`;`, a >255-char fbclid-style value, `login_intent: 'hire'` on every magic_create POST). WRONG or BROKEN specs remain real findings — in particular the existing `organizations_controller_spec.rb` example asserting `adroll_first_party_cookie` is stored from the request body, which the permit removal inverts. Ghost tests (assertions that pass with the feature deleted) are BLOCKER.

### Backward compatibility
The review agent identifies all consumers of modified code and verifies they are addressed. Verified consumer sets as of scoping: `sanitizeTrackingParams` — only `AuthForm.tsx` and `SignupForm.tsx`; `GoogleSSOButton` — only `AuthForm.tsx`; `AuthForm` — `Auth.tsx` + `AuthRegister.tsx` (no change needed); `SignupForm` — `Signup.tsx`; `from_omniauth` — one app call site + two spec files; `useCookieValue` — `OrganizationForm.tsx` (import removed) + `useReferrerCookie.ts` (untouched); `organization_params` — `#create` and `#update` (permit narrowing affects both; accepted). Re-grep at review time.

### Full-stack analog completeness
The review agent verifies the new feature has a corresponding piece for every layer of the analog pipeline (the 15-layer trace above) for EACH of the eight identifiers — capture rule → state → JSON payloads (both) → SSO props → hidden input → mutation hooks (both) → permit → both magic_create branches → password path → allowed_keys → callback → from_omniauth keyword + assignment → org copy → migration column → spec extensions. A missing layer is a BLOCKER.

### Analog structural matching
The review agent greps for analog files, reads their parameter interfaces and patterns, and diffs them against the new code. Layer completeness without structural matching is insufficient. A structural mismatch is BLOCKER — except the four sanctioned deviations listed under the Priority rule (1024 cap, in-helper `document.cookie` reads, the organization_params removal, nothing else). Any EXTRA file, method, write moment, or column beyond the manifest is an automatic mismatch and must be named.
