# Implementation Plan — Attribution identifiers for Meta, LinkedIn, Google Analytics (capture only)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`, branch `attribution-work-qa` (per `REPO-PATH`)
**Spec:** `SPEC.md` in this directory (READY FOR PLANNING; all five §13 decisions RESOLVED and immutable)
**Task mapping:** 1:1 onto `code-task-list.md` T1–T21 — the T-numbers below are the shared progress tracker.
**Verified against:** branch HEAD `b4cb4463a`, clean working tree, 2026-07-24. All file:line references below re-verified live.

---

## 1. Summary

Capture eight additional attribution identifiers (`ga_client_id`, `ga_session_id`, `fbclid`, `fbp`, `fbc`, `li_fat_id`, `google_click_id`, `adroll_first_party_cookie`) at user signup on all three signup paths (magic link, password, Google SSO), store them on `users`, and copy them onto `organizations` at organization creation — through the exact pipeline the `adroll_click_id` analog (commit `ec9f87232`) already uses. Capture-only: nothing is sent to any ad platform.

The one destructive part: `OrganizationForm.tsx` stops reading the `_gcl_aw` and `__adroll_fpc` cookies, and `organization_params` stops permitting `:google_click_id` / `:adroll_first_party_cookie` — collection moves entirely to signup (SPEC §13 decision 5, RESOLVED).

New mechanism introduced: cookie reading inside `sanitizeTrackingParams` (sanctioned — no-Jest ruling 2026-07-16). Everything else is field-by-field extension of existing code.

## 2. Repo state and conflict check

- `git log --oneline -15` on `attribution-work-qa`: HEAD is `b4cb4463a` ("Tag internal links to Polymer marketing properties with UTM params"). That commit touched `app/javascript/shared/lib/utils.js` (added `INTERNAL_UTM_PARAMS` at line 145) — same file as T4 but a disjoint region; no conflict. `ec9f87232` (the analog) and `fa51c91a5` (surrogate-safe truncation) are both already merged and are the state this plan builds on.
- `git status`: clean working tree — nothing uncommitted overlaps the files in scope.
- No open-PR table for this run; nothing in recent history touches the other in-scope files.
- The SPEC §3 "schema.rb corruption" is NOT visible in the committed tree (clean at `b4cb4463a`); it is expected to appear when `db:migrate` regenerates `db/schema.rb` from the drifted dev database. The hunk-level staging rule (§13 below) applies regardless.

## 3. Pattern precedents (verified file:line on `b4cb4463a`)

| Pattern | Precedents (2–3 each) |
|---|---|
| Add-column migration shape | `db/migrate/20260723222212_add_adroll_click_id_to_users.rb` (whole file: `# frozen_string_literal: true`, `ActiveRecord::Migration[6.1]`, bare `add_column :users, :adroll_click_id, :string`); `db/migrate/20260723222213_add_adroll_columns_to_organizations.rb` (two bare `add_column :organizations, ...` calls) |
| Helper field capture, `!== undefined` guard + sanitize | `app/javascript/shared/lib/utils.js:59-61` (`utm_source`), `:65-67` (`internal_ref`), `:68-70` (`adct` → `adrollClickId`) |
| Value sanitization (first-of-array, cap, surrogate-safe) | `utils.js:31-40` `sanitizeTrackingValue`; cap constant `TRACKING_VALUE_MAX_LENGTH = 255` at `utils.js:28` |
| Cookie read + parse | `OrganizationForm.tsx:24-29` (`_gcl_aw` split-on-`.`, last element when >1 segment, with format comment); `OrganizationForm.tsx:34` (`__adroll_fpc` verbatim); `app/javascript/shared/hooks/useCookieValue.ts` (`document.cookie.split("; ")` + `` startsWith(`${cookieKey}=`) `` — its `cookie.split("=")[1]` value read is the DEFECT not to inherit; its name match includes the `=` so it does NOT shadow `_ga` with `_ga_<CONTAINER>`, but the new helper uses exact-equality name matching per SPEC §5.1, which warns against bare `startsWith`-style name lookups) |
| Payload threading into mutations | `AuthForm.tsx:81-85` (`utmSource`…`adrollClickId` in `magicLink` payload); `SignupForm.tsx:67-71` (same five in `register` payload) |
| SSO props pass-through | `AuthForm.tsx:132-136` (`utmSource`…`adrollClickId` props on `GoogleSSOButton`) |
| Hidden SSO input, render-only-when-present | `GoogleSSOButton.tsx:67-69` (`utm_source`), `:73-75` (`internal_ref`), `:76-78` (`adroll_click_id`) — guard form `typeof x === "string" && x.length > 0` |
| Mutation hook threading | `useSession.ts:27-56` (`register`: destructure 34-38, variables 49-53); `useSession.ts:58-114` (`magicLink`: destructure 67-71, inline type 81-85, variables 107-111) |
| Controller permit, plain values before trailing hash | `registrations_controller.rb:312` (`:utm_source, :utm_campaign, :internal_ref, :adroll_click_id, utm_data: {}`) |
| magic_create user_params merge, BOTH branches | `registrations_controller.rb:97-101` (connect branch) and `:111-115` (else branch) |
| Omniauth allowed_keys + session ride | `config/initializers/omniauth.rb:14` (`allowed_keys`), `:17-24` (loop → `session[:oauth_tracking]`) |
| Callback string-key tracking read | `omniauth_callbacks_controller.rb:26-30` (`merged_tracking['utm_source']` … `merged_tracking['adroll_click_id']`) |
| Creation-time keyword assignment | `user.rb:379` (keyword signature), `:389-393` (`omniauth_user.utm_source = utm_source` … `omniauth_user.adroll_click_id = adroll_click_id` inside `first_or_create`) |
| Parent→child copy at org creation | `organizations_controller.rb:32-36` (`@organization.utm_source = current_user.utm_source` … `@organization.adroll_click_id = current_user.adroll_click_id`) |
| Spec extension shape | `spec/controllers/api/v1/registrations_controller_spec.rb:30-50` (raw storage), `:52-67` (all-nil); `spec/models/user_from_omniauth_spec.rb:25-44` / `:46-55` / `:57-84`; `spec/controllers/api/v1/organizations_controller_spec.rb:45-57` (copy) / `:95-108` (nils); `spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb:43-67` / `:69-83` (exhaustive keyword expectations) |

## 4. Files to create / modify

**Create (2):**
- `db/migrate/<timestamp>_add_attribution_identifier_columns_to_users.rb` — class `AddAttributionIdentifierColumnsToUsers`, 8 `add_column` lines
- `db/migrate/<timestamp>_add_attribution_identifier_columns_to_organizations.rb` — class `AddAttributionIdentifierColumnsToOrganizations`, 6 `add_column` lines

**Modify (12):**
- `db/schema.rb` — regenerated by `db:migrate`; commit ONLY the new-column + version hunks (§13)
- `app/javascript/shared/lib/utils.js` — new cap constant, cookie-entry helpers, defaulted `maxLength` param on `sanitizeTrackingValue`, eight new output fields (~60 lines)
- `app/javascript/ats/src/views/sessions/components/AuthForm.tsx` — +8 payload lines, +8 prop lines
- `app/javascript/ats/src/views/sessions/components/SignupForm.tsx` — +8 payload lines
- `app/javascript/ats/src/views/sessions/components/GoogleSSOButton.tsx` — +8 Props fields, +8 destructures, +8 hidden inputs
- `app/javascript/ats/src/views/sessions/components/OrganizationForm.tsx` — REMOVE lines 24-36, shrink payload line 72, remove `useCookieValue` import line 14
- `app/javascript/shared/queryHooks/useSession.ts` — +8 in `register` (destructure + variables), +8×3 in `magicLink` (destructure + inline type + variables)
- `app/controllers/api/v1/registrations_controller.rb` — +8 permits (line 312), +8 merge keys × 2 branches (97-101, 111-115)
- `app/controllers/api/v1/organizations_controller.rb` — +8 copy lines (after line 36), −2 permits (line 120)
- `config/initializers/omniauth.rb` — +8 `allowed_keys` entries (line 14)
- `app/models/user.rb` — +8 keywords (line 379), +8 assignments (after line 393)
- `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` — +8 keyword arguments (after line 30)

**Spec extensions (4, all existing files):**
- `spec/controllers/api/v1/registrations_controller_spec.rb`
- `spec/models/user_from_omniauth_spec.rb`
- `spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb`
- `spec/controllers/api/v1/organizations_controller_spec.rb`

**Deliberately NOT touched:** any Api::V1 serializer, any policy, `app/models/organization.rb` (also a hard repo rule), any Sidekiq job, `app/javascript/shared/queryHooks/api.ts`, `app/javascript/ats/src/lib/utils/structure.js`, any context file, `app/javascript/shared/hooks/useCookieValue.ts`, `app/javascript/shared/hooks/useReferrerCookie.ts`, any Cypress file (read-only), `routes.rb`, PostHog event code, `heard_about_us_from` handling, the `window.__adroll.record_user` block.

## 5. Structural manifest — `adroll_click_id` analog chain vs the eight new identifier chains (MANDATORY, SPEC §9)

Analog = the `adroll_click_id` chain from commit `ec9f87232`, traced live. Verdicts: SAME / DIFFERENT / EXTRA / MISSING. Every DIFFERENT is justified ONLY by the §4 source differences (cookie vs URL vs constructed) or a §13-RESOLVED sanctioned deviation.

### 5.1 File-set and logic-location rows

| # | Manifest row | Analog (`adroll_click_id`) | New (eight identifiers) | Verdict | Justification |
|---|---|---|---|---|---|
| 1 | users migration | 1 file, bare `add_column :users, :adroll_click_id, :string`, `[6.1]`, frozen_string_literal | 1 file, 8 bare `add_column :users, <col>, :string`, same shape | SAME | — |
| 2 | organizations migration | 1 file, 2 bare `add_column :organizations, ...` | 1 file, 6 bare `add_column :organizations, ...` | DIFFERENT (count only) | `google_click_id` (schema.rb:1078) and `adroll_first_party_cookie` (schema.rb:1094) already exist on organizations — from the analog's own commit; re-adding would break the migration |
| 3 | schema.rb | new columns + version bump only | same | SAME | — |
| 4 | Capture logic location | inside `sanitizeTrackingParams` (`utils.js:68-70`) | inside `sanitizeTrackingParams`, same function | SAME | — |
| 5 | Capture source read | `parsedParams.adct` (URL param only) | 4 cookie-only (`_ga`, `_ga_*`, `_fbp`, `__adroll_fpc`); 1 cookie-with-constructed-fallback (`_fbc` else built from fbclid); 2 URL-first-cookie-fallback (`li_fat_id`, `gclid`/`_gcl_aw`); 1 URL-only (`fbclid`) | DIFFERENT | §4 source table — cookie vs URL vs constructed is the entire reason these rules differ |
| 6 | Value transform | `sanitizeTrackingValue`: first-of-array, 255 cap, surrogate-safe | same function, defaulted `maxLength` param; new fields pass 1024; `_ga` two-segment strip, `_gcl_aw` split-dot-last, `ga_session_id` `"; "`-join before the cap | DIFFERENT | 1024 cap = §13 decision 2 RESOLVED; parse transforms dictated by §4 cookie formats; existing callers byte-identical via default param |
| 7 | Component state | `React.useState(sanitizeTrackingParams(location.search))` — `AuthForm.tsx:41`, `SignupForm.tsx:26` | unchanged; new fields ride the same state automatically | SAME | — |
| 8 | magicLink JSON payload | `AuthForm.tsx:85` | +8 fields, same `trackingParams.<field>` form | SAME | — |
| 9 | register JSON payload | `SignupForm.tsx:71` | +8 fields | SAME | — |
| 10 | SSO props | `AuthForm.tsx:136` → `GoogleSSOButton.tsx:17/:29/:76-78` | +8 props, +8 hidden inputs, identical guard, plain single-value snake_case names | SAME | — |
| 11 | Mutation hooks | `useSession.ts:38/53` (register), `:71/:85/:111` (magicLink) | +8 at each of the same five positions | SAME | — |
| 12 | Wire transform | `api.ts:52` `allKeysToSnake` → `structure.js:94-108` — untouched infrastructure | same, untouched | SAME | — |
| 13 | Permit | `registrations_controller.rb:312`, plain symbol before trailing `utm_data: {}` | +8 plain symbols, `utm_data: {}` stays last | SAME | — |
| 14 | magic_create merge | BOTH branches, `:97-101` and `:111-115` | +8 keys in BOTH branches | SAME | — |
| 15 | Password #create | nothing beyond permit (`expanded_params = sign_up_params.merge` at :13 → `build_resource` :20) | nothing beyond permit | SAME | — |
| 16 | Omniauth ride | `omniauth.rb:14` allowed_keys; loop :17-24 → `session[:oauth_tracking]` | +8 keys; loop untouched | SAME | — |
| 17 | Callback | `omniauth_callbacks_controller.rb:30` string-key `merged_tracking` read → keyword arg | +8 string-key reads → +8 keyword args | SAME | — |
| 18 | Model | `user.rb:379` nil-defaulted keyword; `:393` assignment inside `first_or_create` block only | +8 keywords, +8 assignments, per-keyword form (16 keywords total) | SAME | §13 decision 4 RESOLVED — continue per-keyword form |
| 19 | Org copy | `organizations_controller.rb:36` `@organization.adroll_click_id = current_user.adroll_click_id` | +8 identical copy lines | SAME | — |
| 20 | Org request-body path | analog's SECOND identifier (`adroll_first_party_cookie`) took the request-body path: `OrganizationForm.tsx:34` cookie read → payload :72 → `organization_params` permit :120 | REMOVED — `OrganizationForm.tsx:24-36` deleted, payload → `{ name, heardAboutUsFrom }`, both permits dropped | DIFFERENT | §13 decision 5 RESOLVED — deliberate reversal of the analog's own path; single collection point at signup |
| 21 | Spec files | 4 files extended in `ec9f87232` | same 4 files extended; ONE existing example inverted (`'stores adroll_first_party_cookie from the request body'`) + header comment rewrite | DIFFERENT (inversion only) | consequence of row 20 / decision 5 |
| 22 | Files NOT touched | serializers, policies, `organization.rb`, jobs, `api.ts`, `structure.js`, contexts, `useCookieValue.ts`, `useReferrerCookie.ts`, Cypress, routes | identical not-touched set | SAME | — |
| 23 | EXTRA files/methods/write moments beyond the analog | none | none — no new files except the 2 migrations, no new methods except the in-file cookie helpers inside `utils.js` (part of the capture step, sanctioned in-helper `document.cookie` mechanism) | — | in-helper cookie reading is the sanctioned deviation (no-Jest ruling 2026-07-16); it lives inside the analog's own capture location, not a new module |
| 24 | MISSING layers vs analog | — | none — all 15 analog layers present for each of the eight identifiers (see 5.2) | — | — |

### 5.2 Column read/write per step, per identifier (record lifecycle)

Lifecycle (identical to analog, row-verified): value exists ONLY at (a) `users` row creation — `magic_create` new-user branch via `build_resource(user_params)`, password `#create` via `build_resource(expanded_params)`, SSO via `from_omniauth` `first_or_create` block — and (b) `organizations` row creation — `#create` copy from `current_user` before `@organization.save`. No update path, no backfill, no destroy handling (columns die with the row). Existing users logging in: untouched on every path.

| Identifier | Browser source read (§4) | Wire name (JSON + SSO input + permit) | users column written | organizations column written (copy from `current_user`) |
|---|---|---|---|---|
| analog: `adroll_click_id` | `adct` URL param | `adroll_click_id` | `users.adroll_click_id` | `organizations.adroll_click_id` |
| `ga_client_id` | `_ga` cookie, strip first two dot-segments; <4 segments → raw | `ga_client_id` | `users.ga_client_id` (NEW) | `organizations.ga_client_id` (NEW) |
| `ga_session_id` | all `_ga_*` cookies, `<name>=<value>` joined `"; "` | `ga_session_id` | `users.ga_session_id` (NEW) | `organizations.ga_session_id` (NEW) |
| `fbclid` | `fbclid` URL param | `fbclid` | `users.fbclid` (NEW) | `organizations.fbclid` (NEW) |
| `fbp` | `_fbp` cookie verbatim | `fbp` | `users.fbp` (NEW) | `organizations.fbp` (NEW) |
| `fbc` | `_fbc` cookie verbatim, else `fb.1.<Date.now()>.<fbclid>` when fbclid genuinely present | `fbc` | `users.fbc` (NEW) | `organizations.fbc` (NEW) |
| `li_fat_id` | `li_fat_id` URL param, else `li_fat_id` cookie | `li_fat_id` | `users.li_fat_id` (NEW) | `organizations.li_fat_id` (NEW) |
| `google_click_id` | `gclid` URL param, else `_gcl_aw` cookie split-dot-last (>1 segment only) | `google_click_id` | `users.google_click_id` (NEW) | `organizations.google_click_id` (exists, schema.rb:1078 — write source changes from request body to copy) |
| `adroll_first_party_cookie` | `__adroll_fpc` cookie verbatim | `adroll_first_party_cookie` | `users.adroll_first_party_cookie` (NEW) | `organizations.adroll_first_party_cookie` (exists, schema.rb:1094 — write source changes from request body to copy) |

Every row: SAME shape as the analog's read→wire→users→organizations chain; the only DIFFERENT cells are the source column (justified by §4) and the two pre-existing organizations columns' write-source change (justified by decision 5).

## 6. Implementation tasks

### Migrations (T1–T3)

Read before implementing: `cursor_rules/core_critical_rules.md`, `cursor_rules/backend/_base.md`, `cursor_rules/backend/migrations.md`

- [ ] **T1** — Create `db/migrate/<timestamp>_add_attribution_identifier_columns_to_users.rb` (timestamp from `date +%Y%m%d%H%M%S` at creation time; class `AddAttributionIdentifierColumnsToUsers`):
  ```ruby
  # frozen_string_literal: true

  class AddAttributionIdentifierColumnsToUsers < ActiveRecord::Migration[6.1]
    def change
      add_column :users, :ga_client_id, :string
      add_column :users, :ga_session_id, :string
      add_column :users, :fbclid, :string
      add_column :users, :fbp, :string
      add_column :users, :fbc, :string
      add_column :users, :li_fat_id, :string
      add_column :users, :google_click_id, :string
      add_column :users, :adroll_first_party_cookie, :string
    end
  end
  ```
  No defaults, no indexes, no null constraints (SPEC §3). Shape of `20260723222212_add_adroll_click_id_to_users.rb`
- [ ] **T2** — Create `db/migrate/<timestamp>_add_attribution_identifier_columns_to_organizations.rb` (later timestamp than T1; class `AddAttributionIdentifierColumnsToOrganizations`): SIX columns only — `ga_client_id`, `ga_session_id`, `fbclid`, `fbp`, `fbc`, `li_fat_id`. Do NOT add `google_click_id` or `adroll_first_party_cookie` (already exist, schema.rb:1078/:1094 — re-adding raises on migrate). Same shape as T1
- [ ] **T3** — Run `bundle exec rails db:migrate` (allowed db command). Then verify `db/schema.rb` diff: the ONLY acceptable hunks to ever stage are the 8 users columns, 6 organizations columns, and the version bump. See §13 commit guidance — never stage `db/schema.rb` wholesale; expect unrelated dev-database drift to appear in the regenerated file and leave it unstaged

### Frontend — capture (T4)

Read before implementing: `cursor_rules/core_critical_rules.md` (rules 9, 10, 13), `cursor_rules/frontend/_base.md`, `cursor_rules/frontend/core_critical_rules.md`

- [ ] **T4** — `app/javascript/shared/lib/utils.js`: extend `sanitizeTrackingParams`. Full target shape below; sub-checkboxes map to code-task-list T4a–T4k.

  Constant, next to `TRACKING_VALUE_MAX_LENGTH` (line 28):
  ```js
  const ATTRIBUTION_IDENTIFIER_MAX_LENGTH = 1024;
  ```

  `sanitizeTrackingValue` gains a defaulted second parameter — existing call sites unchanged, existing fields byte-identical (255 default):
  ```js
  function sanitizeTrackingValue(value, maxLength = TRACKING_VALUE_MAX_LENGTH) {
    const firstValue = isArray(value) ? value[0] : value; // repeated param: keep first occurrence
    if (!isString(firstValue)) return firstValue;
    const truncatedValue = firstValue.slice(0, maxLength);
    const lastCodeUnit = truncatedValue.charCodeAt(truncatedValue.length - 1);
    // drop a trailing lone high surrogate left by the slice (would serialize as an unparsable \udXXX escape)
    return lastCodeUnit >= 0xd800 && lastCodeUnit <= 0xdbff
      ? truncatedValue.slice(0, -1)
      : truncatedValue;
  }
  ```

  Cookie-entry helpers (module-private, in `utils.js` above `sanitizeTrackingParams`). Split each entry on the FIRST `=` only; empty-value cookie = absent; exact-equality name match:
  ```js
  function getCookieEntries() {
    const cookieEntries = [];
    document.cookie.split("; ").forEach((cookieEntry) => {
      const separatorIndex = cookieEntry.indexOf("=");
      if (separatorIndex === -1) return;
      const cookieName = cookieEntry.substring(0, separatorIndex);
      const cookieValue = cookieEntry.substring(separatorIndex + 1); // everything after the FIRST "="
      if (cookieValue.length === 0) return; // cookie present with empty value = absent
      cookieEntries.push({ name: cookieName, value: cookieValue });
    });
    return cookieEntries;
  }

  function getCookieValue(cookieEntries, cookieName) {
    const matchingCookieEntry = cookieEntries.find((cookieEntry) => cookieEntry.name === cookieName);
    return matchingCookieEntry ? matchingCookieEntry.value : undefined;
  }
  ```

  New field logic appended inside `sanitizeTrackingParams` after the existing `adct` block (line 70), before the `utmDataKeys` derivation — existing fields untouched:
  ```js
  const cookieEntries = getCookieEntries();

  // gaClientId — _ga cookie, format GA1.1.1234567890.1699999999: drop the first two
  // dot-segments; store the raw value when the format is unexpected (<4 segments)
  const gaCookieValue = getCookieValue(cookieEntries, "_ga");
  if (gaCookieValue !== undefined) {
    const gaSegments = gaCookieValue.split(".");
    trackingParams.gaClientId = sanitizeTrackingValue(
      gaSegments.length >= 4 ? gaSegments.slice(2).join(".") : gaCookieValue,
      ATTRIBUTION_IDENTIFIER_MAX_LENGTH,
    );
  }

  // gaSessionId — every _ga_* cookie (prefix match excludes the bare _ga), serialized raw
  const gaSessionCookieEntries = cookieEntries.filter(
    (cookieEntry) => cookieEntry.name.indexOf("_ga_") === 0,
  );
  if (gaSessionCookieEntries.length > 0) {
    trackingParams.gaSessionId = sanitizeTrackingValue(
      gaSessionCookieEntries
        .map((cookieEntry) => cookieEntry.name + "=" + cookieEntry.value)
        .join("; "),
      ATTRIBUTION_IDENTIFIER_MAX_LENGTH,
    );
  }

  // fbclid — URL param, same handling adct gets (first occurrence, cap)
  if (parsedParams.fbclid !== undefined) {
    trackingParams.fbclid = sanitizeTrackingValue(
      parsedParams.fbclid,
      ATTRIBUTION_IDENTIFIER_MAX_LENGTH,
    );
  }

  // fbp — Meta pixel cookie, verbatim
  const fbpCookieValue = getCookieValue(cookieEntries, "_fbp");
  if (fbpCookieValue !== undefined) {
    trackingParams.fbp = sanitizeTrackingValue(fbpCookieValue, ATTRIBUTION_IDENTIFIER_MAX_LENGTH);
  }

  // fbc — _fbc cookie verbatim; else Meta's documented construction from a genuinely
  // present fbclid (?fbclid parses to null and ?fbclid= to "" — neither constructs)
  const fbclidParamValue = isArray(parsedParams.fbclid) ? parsedParams.fbclid[0] : parsedParams.fbclid;
  const fbcCookieValue = getCookieValue(cookieEntries, "_fbc");
  if (fbcCookieValue !== undefined) {
    trackingParams.fbc = sanitizeTrackingValue(fbcCookieValue, ATTRIBUTION_IDENTIFIER_MAX_LENGTH);
  } else if (typeof fbclidParamValue === "string" && fbclidParamValue.length > 0) {
    trackingParams.fbc = sanitizeTrackingValue(
      "fb.1." + Date.now() + "." + fbclidParamValue,
      ATTRIBUTION_IDENTIFIER_MAX_LENGTH,
    );
  }

  // liFatId — li_fat_id URL param first, li_fat_id cookie (LinkedIn Insight Tag) fallback
  const liFatIdParamValue = isArray(parsedParams.li_fat_id)
    ? parsedParams.li_fat_id[0]
    : parsedParams.li_fat_id;
  if (typeof liFatIdParamValue === "string" && liFatIdParamValue.length > 0) {
    trackingParams.liFatId = sanitizeTrackingValue(
      liFatIdParamValue,
      ATTRIBUTION_IDENTIFIER_MAX_LENGTH,
    );
  } else {
    const liFatIdCookieValue = getCookieValue(cookieEntries, "li_fat_id");
    if (liFatIdCookieValue !== undefined) {
      trackingParams.liFatId = sanitizeTrackingValue(
        liFatIdCookieValue,
        ATTRIBUTION_IDENTIFIER_MAX_LENGTH,
      );
    }
  }

  // googleClickId — gclid URL param first; else the _gcl_aw cookie.
  // Expected format for cookie value:  GCL.1719852261.actualGoogleClickIdHere
  // Since the beginning can be edited in GTM, get last element of array
  const gclidParamValue = isArray(parsedParams.gclid) ? parsedParams.gclid[0] : parsedParams.gclid;
  if (typeof gclidParamValue === "string" && gclidParamValue.length > 0) {
    trackingParams.googleClickId = sanitizeTrackingValue(
      gclidParamValue,
      ATTRIBUTION_IDENTIFIER_MAX_LENGTH,
    );
  } else {
    const gclAwCookieValue = getCookieValue(cookieEntries, "_gcl_aw");
    const gclAwSegments = gclAwCookieValue !== undefined ? gclAwCookieValue.split(".") : null;
    if (gclAwSegments && gclAwSegments.length > 1) {
      trackingParams.googleClickId = sanitizeTrackingValue(
        gclAwSegments[gclAwSegments.length - 1],
        ATTRIBUTION_IDENTIFIER_MAX_LENGTH,
      );
    }
  }

  // adrollFirstPartyCookie — __adroll_fpc verbatim (capture moves here from the org form)
  const adrollFpcCookieValue = getCookieValue(cookieEntries, "__adroll_fpc");
  if (adrollFpcCookieValue !== undefined) {
    trackingParams.adrollFirstPartyCookie = sanitizeTrackingValue(
      adrollFpcCookieValue,
      ATTRIBUTION_IDENTIFIER_MAX_LENGTH,
    );
  }
  ```

  Sub-task checklist (verify each against the code above before checking off):
  - [ ] T4a — cookie extraction: first-`=` split, exact-equality name match for `_ga`/`_fbp`/`_fbc`/`li_fat_id`/`_gcl_aw`/`__adroll_fpc` (no `startsWith` — a `_ga_<CONTAINER>` cookie must not shadow `_ga`), only `gaSessionId` matches by `_ga_` prefix (which excludes bare `_ga`), empty-value cookie absent; `useCookieValue.ts` itself untouched
  - [ ] T4b — `gaClientId` strip rule + <4-segment raw fallback
  - [ ] T4c — `gaSessionId` single raw `"; "`-joined string, NOT jsonb (§13 decision 3)
  - [ ] T4d — `fbclid` URL param, adct-identical handling at 1024
  - [ ] T4e — `fbp` verbatim
  - [ ] T4f — `fbc` verbatim-else-construct; `?fbclid` (null) and `?fbclid=` ("") never construct
  - [ ] T4g — `liFatId` URL-first (non-empty string), cookie fallback
  - [ ] T4h — `googleClickId` URL-first, `_gcl_aw` split-dot-last (>1 segment only, no raw fallback), parse rule + comment preserved from `OrganizationForm.tsx:25-29`
  - [ ] T4i — `adrollFirstPartyCookie` verbatim
  - [ ] T4j — 1024 cap on the FINAL value of all eight (after strip/construction/join); existing fields keep 255 via the default param
  - [ ] T4k — every new field absent (key not set) when its source is absent; no `|| ""`/`|| null` fabrication anywhere

### Frontend — threading (T5–T8)

Read before implementing: `cursor_rules/frontend/_base.md` (rules 1–3), `cursor_rules/core_critical_rules.md` (rules 7, 9, 13)

- [ ] **T5** — `AuthForm.tsx`:
  - [ ] T5a — `magicLink` payload in `handleAuth` (after `adrollClickId: trackingParams.adrollClickId,` at line 85): add `gaClientId: trackingParams.gaClientId,` `gaSessionId: trackingParams.gaSessionId,` `fbclid: trackingParams.fbclid,` `fbp: trackingParams.fbp,` `fbc: trackingParams.fbc,` `liFatId: trackingParams.liFatId,` `googleClickId: trackingParams.googleClickId,` `adrollFirstPartyCookie: trackingParams.adrollFirstPartyCookie,`
  - [ ] T5b — `GoogleSSOButton` props (after `adrollClickId={trackingParams.adrollClickId}` at line 136): the same eight as `<name>={trackingParams.<name>}`
- [ ] **T6** — `SignupForm.tsx`: same eight `trackingParams` fields added to the `register` payload after `adrollClickId` (line 71)
- [ ] **T7** — `GoogleSSOButton.tsx`:
  - [ ] T7a — `Props` (after `adrollClickId?: string;` at line 17): `gaClientId?: string;` `gaSessionId?: string;` `fbclid?: string;` `fbp?: string;` `fbc?: string;` `liFatId?: string;` `googleClickId?: string;` `adrollFirstPartyCookie?: string;`
  - [ ] T7b — destructure the eight in the function signature (after `adrollClickId,` line 29)
  - [ ] T7c — eight hidden inputs after the `adroll_click_id` input (line 78), exact existing guard form, snake_case wire names — e.g. `{typeof gaClientId === "string" && gaClientId.length > 0 ? (<input type="hidden" name="ga_client_id" value={gaClientId} />) : null}` — for `ga_client_id`, `ga_session_id`, `fbclid`, `fbp`, `fbc`, `li_fat_id`, `google_click_id`, `adroll_first_party_cookie`. All plain single-value inputs; nothing uses the `utm_data[<key>]` nested form
- [ ] **T8** — `useSession.ts`:
  - [ ] T8a — `register`: add the eight camelCase names to the destructured params (after `adrollClickId,` line 38) and the `variables` object (after line 53)
  - [ ] T8b — `magicLink`: add the eight to the destructured params (after line 71), the inline TS type as `?: string | null` (after `adrollClickId?: string | null;` line 85), and the `variables` object (after line 111)
  - [ ] T8c — verify all eight wire transforms through `allKeysToSnake` (`api.ts:52` → `structure.js:94-108`, lodash `snakeCase` on keys only): `gaClientId`→`ga_client_id`, `gaSessionId`→`ga_session_id`, `fbclid`→`fbclid`, `fbp`→`fbp`, `fbc`→`fbc`, `liFatId`→`li_fat_id`, `googleClickId`→`google_click_id`, `adrollFirstPartyCookie`→`adroll_first_party_cookie` (already verified empirically against the installed lodash during spec review; re-verify with a one-liner if in doubt)

### Frontend — collection-point removal (T9)

Read before implementing: `cursor_rules/frontend/_base.md`; pipeline rules 10/23 (minimum scope — touch ONLY the enumerated lines)

- [ ] **T9** — `OrganizationForm.tsx`:
  - [ ] T9a — remove lines 24-36: `gclAwCookieValue`/`parsedArray`/`googleClickId` with their two comment lines, both `window.logger` calls, the AdRoll comment (line 33), and `adrollFirstPartyCookie`
  - [ ] T9b — payload (line 72): `{ name, googleClickId, heardAboutUsFrom, adrollFirstPartyCookie }` → `{ name, heardAboutUsFrom }`
  - [ ] T9c — remove the `useCookieValue` import (line 14) — no other use remains in this file (verified: grep hits only OrganizationForm.tsx, useCookieValue.ts itself, useReferrerCookie.ts)
  - [ ] T9d — do NOT touch: `heardAboutUsFrom` capture/state/input, the `window.__adroll.record_user` block, `trackEvent("organization_created")`, anything else in the file

### Backend (T10–T16)

Read before implementing: `cursor_rules/core_critical_rules.md` (rules 1, 5, 8, 11), `cursor_rules/backend/_base.md`, `cursor_rules/backend/controllers/controller_patterns_and_crud.md`, `cursor_rules/backend/controllers/controller_error_handling.md`

- [ ] **T10** — `registrations_controller.rb` `sign_up_params` (line 312): add `:ga_client_id, :ga_session_id, :fbclid, :fbp, :fbc, :li_fat_id, :google_click_id, :adroll_first_party_cookie` after `:adroll_click_id`, keeping `utm_data: {}` as the trailing argument. One params method stays one params method
- [ ] **T11** — `registrations_controller.rb` `magic_create`: in BOTH branches of the `user_params` conditional (after `adroll_click_id: sign_up_params[:adroll_click_id]` at lines 101 and 115), add:
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
  Password `#create` needs nothing beyond T10 (SPEC §6.3). The existing-user branches remain inert (read only `user_params[:email]`); no response-shape change
- [ ] **T12** — `organizations_controller.rb` `#create`: after `@organization.adroll_click_id = current_user.adroll_click_id` (line 36), add:
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
  Before `@organization.is_claimed = true` / `authorize @organization`. Values never come from the request
- [ ] **T13** — `organizations_controller.rb` `organization_params` (line 120): remove `:google_click_id` and `:adroll_first_party_cookie` from the permit. Known consequence (accepted, not to be worked around): `#update` also stops accepting them — shared params method per core rule 5
- [ ] **T14** — `config/initializers/omniauth.rb` (line 14): extend `allowed_keys` exactly as SPEC §6.5:
  ```ruby
  allowed_keys = %w[partner referral utm_source utm_campaign utm_data internal_ref adroll_click_id
                    ga_client_id ga_session_id fbclid fbp fbc li_fat_id google_click_id adroll_first_party_cookie]
  ```
  The loop (`value if value && !value.empty?`) and session write are untouched
- [ ] **T15** — `app/models/user.rb` `from_omniauth` (line 379): extend the signature to the SPEC §6.6 16-keyword form:
  ```ruby
  def self.from_omniauth(auth:, created_via:, partner_source: nil, utm_source: nil, utm_campaign: nil,
                         utm_data: nil, internal_ref: nil, adroll_click_id: nil,
                         ga_client_id: nil, ga_session_id: nil, fbclid: nil, fbp: nil, fbc: nil,
                         li_fat_id: nil, google_click_id: nil, adroll_first_party_cookie: nil)
  ```
  and add eight assignments inside the `first_or_create` block after `omniauth_user.adroll_click_id = adroll_click_id` (line 393), before `omniauth_user.sign_on_provider = 'google'`:
  ```ruby
  omniauth_user.ga_client_id = ga_client_id
  omniauth_user.ga_session_id = ga_session_id
  omniauth_user.fbclid = fbclid
  omniauth_user.fbp = fbp
  omniauth_user.fbc = fbc
  omniauth_user.li_fat_id = li_fat_id
  omniauth_user.google_click_id = google_click_id
  omniauth_user.adroll_first_party_cookie = adroll_first_party_cookie
  ```
  Post-block behavior (`new_user_created_via_google_sso`, `assign_attributes(remember_me: true)`, the names `update`, `enqueue_complete_user_setup`) unchanged
- [ ] **T16** — `omniauth_callbacks_controller.rb` `#google_oauth2`: extend the `User.from_omniauth` call after `adroll_click_id: merged_tracking['adroll_click_id']` (line 30):
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
  - [ ] T16a — MANDATORY call-site re-grep at implementation time: `git grep -ln "from_omniauth"`. As of this plan it returns exactly four files — `app/models/user.rb` (definition), `app/controllers/api/v1/users/omniauth_callbacks_controller.rb:22` (sole app call site), `spec/models/user_from_omniauth_spec.rb` (direct keyword calls — nil-defaulted keywords inert until T18), `spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb` (exhaustive `have_received(:from_omniauth).with(...)` expectations that FAIL once the call site gains eight keywords unless T19 extends them). Extend every site the grep finds

### Tests (T17–T21)

Priorities per harness-profile.md: Cypress top (read-only, must pass); other RSpec extended minimally, mirroring `ec9f87232`. Bang methods allowed in specs. Update stale "five attribution values" counts in header comments and example names as part of each extension.

- [ ] **T17** — `spec/controllers/api/v1/registrations_controller_spec.rb`:
  - [ ] T17a — extend the `magic_create` new-user raw-storage example (lines 30-50) with all eight params → assert persisted raw. Include a `ga_session_id` value containing `=`, `.`, and `;` (e.g. `'_ga_ABC123XYZ=GS1.1.1699999999.5.1.1699999999.0.0.0; _ga_DEF456=GS1.1.2.3'`) to pin verbatim storage, and an fbclid-style value longer than 255 chars (e.g. `'fb' + 'x' * 300`) to pin that the server stores what it receives
  - [ ] T17b — extend the all-nil example (lines 52-67): all eight nil when not sent
  - [ ] T17c — extend both existing-user contexts (lines 70-128): the eight new params sent, columns remain nil/untouched
  - [ ] T17d — extend both password `#create` examples (lines 131-169): eight raw + eight nil
  - [ ] T17e — keep `login_intent: 'hire'` on every `magic_create` POST (the header comment at lines 10-13 explains why); update the "five attribution values" header comment (lines 5-8) and example names to the new count
- [ ] **T18** — `spec/models/user_from_omniauth_spec.rb`: extend the raw-storage example (lines 25-44) with the eight keywords → persisted raw; the omitted-keywords example (lines 46-55) → eight nils; the existing-user example (lines 57-84) → eight `'ShouldNotStick'` values not assigned. Update the header comment (lines 5-9) and "five" example names
- [ ] **T19** — `spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb`: seed `session[:oauth_tracking]` (lines 44-52) with the eight string keys → extend the exhaustive `have_received(:from_omniauth).with(...)` expectation (lines 56-65) with the eight values; the no-tracking example `'passes nil for all five attribution values when no tracking rode the session'` (lines 69-83) gains the eight nil keywords AND a renamed example string. Both expectations are exhaustive keyword matches — they fail at dispatch if T16 lands without this. Keep `Devise::Test::ControllerHelpers` + the `devise.mapping` line + the queue-adapter `around` block exactly as they are
- [ ] **T20** — `spec/controllers/api/v1/organizations_controller_spec.rb`:
  - [ ] T20a — extend the attributed-user `let` (lines 30-43) and the copy example (lines 45-57) with the eight values → identical on the new Organization; extend the nil context (lines 84-108) → eight nils
  - [ ] T20b — INVERT the example `'stores adroll_first_party_cookie from the request body'` (lines 59-69): POST `organization: { name: ..., google_click_id: 'from-body', adroll_first_party_cookie: 'fpc-abc123' }` and assert the organization does NOT carry the request-body values — it carries `current_user`'s values (or nil), proving the permit removal
  - [ ] T20c — rewrite the header comment (lines 10-12): the "adroll_first_party_cookie is the exception … it IS permitted through organization_params" paragraph is false after T13
- [ ] **T21** — Full RSpec run green (`bundle exec rspec` — RAILS_ENV=test); `cypress/e2e/auth/registration.cy.js` passes via the pre-commit hook (read-only; spec review verified it asserts navigation/text only and GTM does not load in test env, so the payload additions cannot break it). No Jest (house ruling 2026-07-16)

## 7. Validation and constraints

- **Nil for absent, everywhere** (SPEC §8.1, core rule 10): the helper omits absent fields; absent JSON fields → `sign_up_params[<key>]` nil → nil column; unrendered hidden input → key absent from `oauth_tracking` → `merged_tracking['<key>']` nil → nil-defaulted keyword → nil column; nil user column copies as nil org column. No `|| ""`, `|| 0`, `|| {}` anywhere in new code.
- **Raw storage** (§8.2): no hashing, mapping, or downcasing; byte-exact subject only to the 1024 cap.
- **Creation-time only** (§8.3): no update path, no login-time backfill — any new write moment is an automatic manifest mismatch (manifest §5.1 row 23/24).
- **Single collection point** (§8.4): after T9/T13, no attribution identifier is collected outside signup.
- **No serializer exposure** (§8.5): zero serializer edits; reviewers verify absence.
- **`fbc` never fabricated** (§8.6): construction only when `_fbc` absent AND fbclid is a genuinely non-empty string.
- **Existing behavior byte-identical** (§8.7): `utm_*`/`internal_ref`/`adct` keep the 255 cap (via the defaulted param) and their flow; `adroll_click_id` untouched; `utm_data` occurrence-order logic untouched.
- **JS conventions**: strict comparisons except loose `!= undefined`/`== undefined` (core rule 13); no `??` (frontend _base rule 1); never set `undefined` deliberately (rule 9); double quotes in TS/JS, single quotes in Ruby.
- **No model changes beyond `user.rb`**; `app/models/organization.rb` is untouched (hard repo rule).
- **Authorization: none** (SPEC §7) — no new endpoints, no policy changes; the permit removal narrows, not widens.

## 8. Test plan

Covered as first-class tasks T17–T21 above. Summary of the contract:
- Four existing RSpec files extended (never new files), mirroring their `ec9f87232` additions; pinning values: `ga_session_id` containing `=`/`.`/`;`, a >255-char fbclid-style value, `login_intent: 'hire'` on every `magic_create` POST.
- One existing example INVERTED (T20b) and one header comment rewritten (T20c) — these assert the old request-body behavior the feature removes; leaving them is a wrong-spec finding.
- Cypress: `cypress/e2e/auth/registration.cy.js` is the source of truth for both signup paths; read-only; runs pre-commit; no new Cypress tests (SPEC §10).
- Jest: none — this codebase has no Jest (house ruling 2026-07-16); the `utils.js` changes get no JS unit tests.
- Ghost-test check: every new assertion must fail if its feature line is deleted (e.g., the T20b inversion fails if T13's permit removal is reverted; T19's keyword expectations fail if T16 is missing).

## 9. Documentation impact

None. No README, no cursor_rules change, no API docs — the feature adds no endpoints and exposes nothing in serializers. (Header comments inside the four spec files are updated as part of T17–T20; that is test code, not documentation.)

## 10. Risks

1. **SSO session-cookie ~4KB ceiling** (SPEC §14.1): up to 8 more ≤1024-unit values in `session[:oauth_tracking]`; degenerate browser state can overflow (`ActionDispatch::Cookies::CookieOverflow`) for that request. Accepted extension of the previously accepted risk; realistic values (~1.2KB) fit. Do not add mitigation.
2. **Direct API callers bypass the frontend caps** (§14.2): no server-side sanitization, consistent with the approved prior design. Postgres `character varying` is unlimited. Accepted.
3. **Async pixel timing** (§14.3): cookies read at first render; a pixel setting `_fbp`/`_fbc` after render is missed for near-instant signups; the fbc URL fallback covers the Meta-click case. Accepted property of capture-at-first-touch.
4. **`fbc` constructed timestamp** is page-render time, not click time — Meta's documented construction for exactly this case (§14.4).
5. **schema.rb drift**: `db:migrate` will regenerate `db/schema.rb` from the drifted dev database, mixing unrelated diffs into the working tree. Mitigated by the §13 hunk-staging rule; the impl review must inspect the COMMITTED schema diff, not the working tree (pipeline failure pattern 15).
6. **Omniauth spec expectations are exhaustive**: T16 without T19 fails the suite loudly at dispatch — by design; do not loosen the expectations to `hash_including`.
7. **Transition window** (§13 decision 5, RESOLVED — accepted): pre-ship users creating post-ship orgs produce nil `google_click_id`/`adroll_first_party_cookie`. Do NOT add an org-form fallback to "fix" this; any such fallback is a defect against a resolved decision.

## 11. Estimated scope

- 2 new migration files (14 add_column lines total) + schema hunks
- ~60 net new lines in `utils.js` (helpers + eight field blocks + constant + one defaulted param)
- ~50 net new lines across the four threading files (AuthForm, SignupForm, GoogleSSOButton, useSession)
- ~13 lines removed + 1 shrunk in `OrganizationForm.tsx`
- ~35 net new backend lines across 5 files (permits, merges ×2, copies, allowed_keys, keywords + assignments, callback args)
- ~120 lines of spec extensions across 4 existing files
- No new components, hooks, services, jobs, routes, policies, or serializers. Single PR-sized change; the risk concentration is T4 (the only new logic) and T20b (the only inversion).

## 12. Deviation ledger (all sanctioned; flag anything beyond these)

1. 1024-unit cap for the eight new values vs the analog's 255 (§13 decision 2).
2. Cookie reading inside `sanitizeTrackingParams` via `document.cookie` directly, first-`=` split (not `useCookieValue`, whose `split("=")[1]` truncation is the defect not to inherit; name matching is exact-equality per SPEC §5.1) — no-Jest ruling 2026-07-16.
3. `:google_click_id`/`:adroll_first_party_cookie` leaving `organization_params` — deliberate reversal of the analog's own request-body path (§13 decision 5).
4. Per-keyword `from_omniauth` growth to 16 keywords (§13 decision 4).

Nothing else may deviate from the analog. Any EXTRA file, method, write moment, or column is an automatic manifest mismatch.

## 13. Commit guidance

SPEC §3 schema commit rule, verbatim (HARD — from Jessica, 2026-07-24):

> The development environment's `db/schema.rb` is corrupted with unrelated local diffs. **Never stage `db/schema.rb` wholesale.** When committing, stage ONLY the hunks these two migrations introduce (`git add -p db/schema.rb`, or equivalent hunk-level staging), verify the staged diff contains exactly the new columns and the version bump, and nothing else. Jessica normally commits schema changes herself in part for this reason; any agent that commits must follow this rule exactly.

Additional commit rules in force: never `--no-verify` (the pre-commit hook runs `registration.cy.js`); commits run detached and are never timed out under 20 minutes; work stays on `attribution-work-qa` (Jessica's directive) — no new branches; merges/PRs are Jessica's.
