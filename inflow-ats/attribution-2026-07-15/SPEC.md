# SPEC — UTM capture + identify/funnel events (attribution)

**Working branch:** `attribution-work` (off `develop`, main checkout `/Users/jessica/wrk/wrk-corp/inflow-ats`)
**Binding design source:** `/Users/jessica/claude-hub/inflow-ats/attribution-2026-07-15/approved-decisions.md` — 19 approved decisions (D1–D19; there is no D11 in the approved set, and D12 is void — superseded by D18 and reverted by D19). Every mechanism, event name, and column name below comes from those decisions. This spec assembles them into implementable form; it introduces no new design decisions. Where the spec names something the decisions left mechanical (helper function name, migration file names), that is called out inline as "spec-proposed".
**Supporting context:** `funnel-audit.md`, `identify-findings.md`, `NOTES.md` in the same directory.

---

## 1. Summary

Two changes, one PR:

1. **UTM capture.** Four new columns on `users` and on `organizations`: `utm_source` (string), `utm_campaign` (string), `utm_data` (jsonb), `internal_ref` (string). Values are captured from `location.search` on the auth pages (`AuthForm.tsx` for `/auth` and `/auth-register`; `SignupForm.tsx` for the `/register` password path), sanitized client-side by a new helper in `app/javascript/shared/lib/utils.js`, threaded through the `magicLink`/`register` payloads and the Google SSO path (hidden form inputs → omniauth `setup` lambda → `session[:oauth_tracking]` → `User.from_omniauth`, which converts to all-keyword arguments), written raw onto the `User` at row creation, and copied from `current_user` onto the new `Organization` at `Api::V1::OrganizationsController#create`. No defaults, no backfill, absent params stay nil.

2. **Funnel events (browser-first).** New browser PostHog events via the existing `trackEvent` helper in `app/javascript/shared/lib/posthog.ts`:
   - `organization_owner_email_verified` / `invited_user_email_verified` on `OnboardingProfile.tsx` (the Tell-us-about-you page) mount, keyed on the `isNewOwner` value it already computes (D18 — supersedes the void D12). `Auth.tsx` and the confirmation redirect in `app/controllers/hire/confirmations_controller.rb` are NOT modified (D19); no browser identify call is added anywhere in this PR.
   - `user_signed_up_client_side` at `magicLink` onSuccess in `AuthForm.tsx` and at `register` onSuccess in `SignupForm.tsx` (D14).
   - `organization_created` at `createOrganization` onSuccess in `OrganizationForm.tsx` (D13).
   - `organization_owner_user_name_submitted` / `invited_user_name_submitted` at `updateMe` onSuccess in `ProfileForm.tsx`, keyed on the existing `isNewOwner` prop (D16).
   - The funnel's logged-in step stays server-side `user_logged_in` (D15 — browser login event deferred). The signup-page event is deferred entirely (D17).

   All existing server-side `PosthogTrackJob`/`PosthogIdentifyJob` calls stay untouched as backup — none are removed or modified.

**Already applied on the branch (uncommitted, part of this feature):** `window.logger` added to `identifyUser` in `app/javascript/shared/lib/posthog.ts` — both the fire path and the not-loaded skip path. Commit as part of this PR; no further change to that file.

## 2. Stack scope

- **Backend (Rails):** 2 schema migrations; `Api::V1::RegistrationsController`; `Api::V1::OrganizationsController#create`; `Api::V1::Users::OmniauthCallbacksController#google_oauth2`; `User.from_omniauth`; `config/initializers/omniauth.rb`. (`Hire::ConfirmationsController` is not modified — D19; it gains spec coverage only, §9 item 5.)
- **Frontend (React/TS):** new helper in `app/javascript/shared/lib/utils.js`; `AuthForm.tsx`; `SignupForm.tsx`; `GoogleSSOButton.tsx`; `useSession.ts` (`magicLink` + `register` request functions); `OnboardingProfile.tsx`; `OrganizationForm.tsx`; `ProfileForm.tsx`. (`posthog.ts` already changed on the branch. `Auth.tsx` is not modified — D19.)
- **Not touched:** serializers, policies, models other than `user.rb`, Sidekiq jobs, `api.ts`, contexts, existing Cypress tests.

## 3. Data model changes (D6)

Two migrations, one per table, identical column sets (spec-proposed file names; class names to match):

- `db/migrate/<timestamp>_add_attribution_columns_to_users.rb`
- `db/migrate/<timestamp>_add_attribution_columns_to_organizations.rb`

Each:

| column | type | default | null constraint | index |
|---|---|---|---|---|
| `utm_source` | `string` | none | none (nullable) | none |
| `utm_campaign` | `string` | none | none (nullable) | none |
| `utm_data` | `jsonb` | **none** | none (nullable) | none |
| `internal_ref` | `string` | none | none (nullable) | none |

- **No defaults** — deliberately unlike the existing `settings` jsonb columns (`default: {}, null: false` on both tables). Absent data must stay `nil`, not `{}` (D6, D3).
- **No backfill** of existing rows; no data migration (D6).
- No model changes: no validations, no enums, no `attr_accessor` — the columns are plain attributes assigned by mass assignment (`build_resource`) or direct setters. Contrast with `users.created_via`/`users.partner_source`, which are integer enum columns; the new columns store **raw strings/json, no mapping** (D3: "no `get_created_via`-style mapping", no `&.downcase`).
- Note for the implementer: `app/models/organization.rb` needs **no edit** (repo rule restricts edits to that file; none are required here).

## 4. API / backend changes

### 4.1 `Api::V1::RegistrationsController#sign_up_params` (D3)

Current (line 300–303):

```ruby
params.permit(:name, :first_name, :last_name, :email, :password, :beta_token, :registration_stripe_plan, :referral, :partner, :organization_slug, :login_intent)
```

Add `:utm_source`, `:utm_campaign`, `:internal_ref` as plain single-value params, and `utm_data: {}` as an arbitrary-key hash — the exact `options: {}` permit form used in `app/controllers/api/v1/questions_controller.rb` line 50 (`permit(..., options: {})`, assigned to the `questions.options` jsonb column). The hash-permit must be the trailing argument of `permit`.

### 4.2 `#magic_create` (D3)

Merge the four values into `user_params` so they are assigned when the User row is created. `user_params` is built in a two-branch conditional (connect-intent branch and default branch, lines 88–107); the four keys must be present in the resulting hash in **both** branches:

```ruby
utm_source: sign_up_params[:utm_source],
utm_campaign: sign_up_params[:utm_campaign],
utm_data: sign_up_params[:utm_data],
internal_ref: sign_up_params[:internal_ref]
```

- Values stored **raw as sent** — no downcasing, no mapping (D3).
- A param absent from the request leaves its column `nil` (D3): `sign_up_params[:utm_source]` is `nil` when the param wasn't sent, and jsonb `utm_data` is `nil` when no `utm_data` param arrived.
- Only the new-user branch (`build_resource(user_params)` / `resource.save`) creates a row, so the values only land on newly created Users. The two existing-user branches read only `user_params[:email]` — adding the keys is inert there. **No identify/track/redirect/response-shape change in `magic_create`** — its JSON responses stay exactly as they are.

### 4.3 `#create` (password path — D10)

No change beyond 4.1. `create` already builds `expanded_params = sign_up_params.merge(created_via: ..., partner_source: ...)` and passes it to `build_resource`, so once `sign_up_params` permits the four params they are assigned automatically as User attributes.

### 4.4 `Api::V1::OrganizationsController#create` (D5)

Copy the four values from `current_user` onto the new Organization, the same way the action already copies `created_via` (line 31):

```ruby
@organization.created_via = current_user.created_via   # existing
@organization.utm_source = current_user.utm_source
@organization.utm_campaign = current_user.utm_campaign
@organization.utm_data = current_user.utm_data
@organization.internal_ref = current_user.internal_ref
```

No re-capture of query params at organization creation. `organization_params` is NOT modified — the values never come from the request. A user with nil columns produces an organization with nil columns.

### 4.5 `config/initializers/omniauth.rb` setup lambda (D8)

Line 14: `allowed_keys = %w[partner referral]` becomes:

```ruby
allowed_keys = %w[partner referral utm_source utm_campaign utm_data internal_ref]
```

No other change to the lambda. The existing loop (`value = rack_request.params[key]; tracking_params[key] = value if value && !value.empty?`) already handles the new keys: `utm_source`/`utm_campaign`/`internal_ref` arrive as strings; `utm_data` arrives as a `Hash` from the Rails-nested `utm_data[<key>]` inputs (Hash responds to `empty?`). The values ride `env['rack.session'][:oauth_tracking]` to the callback exactly as `partner`/`referral` do today. (Session cookies use the `:json` serializer — `config/initializers/cookies_serializer.rb` — so the `utm_data` hash round-trips with string keys.)

### 4.6 `User.from_omniauth` keyword conversion (D9)

Current signature (`app/models/user.rb` line 379):

```ruby
def self.from_omniauth(auth, created_via, partner_source = nil)
```

Convert to keyword arguments throughout, declared in this exact order:

```ruby
def self.from_omniauth(auth:, created_via:, partner_source: nil, utm_source: nil, utm_campaign: nil, utm_data: nil, internal_ref: nil)
```

- `auth:` and `created_via:` are required keywords; the rest default to nil.
- Assignment of the four new values happens **inside the `first_or_create` block**, alongside the existing `omniauth_user.created_via = created_via` and `omniauth_user.partner_source = partner_source&.downcase` lines — set only when the User row is created. An existing user logging in via SSO is untouched (the block does not run, and no assignment happens outside it). The new values are assigned raw (no `&.downcase`).
- The post-block behavior (`assign_attributes(remember_me: true)`, `update(first_name:, last_name:)`, `enqueue_complete_user_setup`) is unchanged.

**Call-site conversion (D9, mandatory implementation step):** search every tracked file in the repository for `from_omniauth` references and convert every call site to keyword form. As of this spec, `git grep -ln "from_omniauth"` returns exactly two files: `app/models/user.rb` (the definition) and `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` (line 22, the sole call site). The implementer must re-run the search at implementation time and must not rely on this list.

### 4.7 `Api::V1::Users::OmniauthCallbacksController#google_oauth2` (D9)

Update line 22 to keyword form and supply the four new values from the merged tracking hash (`merged_tracking = request_phase_params.merge(tracking_from_session)`, string keys):

```ruby
user = User.from_omniauth(
  auth: oauth_data,
  created_via: created_via_value,
  partner_source: partner_param,
  utm_source: merged_tracking['utm_source'],
  utm_campaign: merged_tracking['utm_campaign'],
  utm_data: merged_tracking['utm_data'],
  internal_ref: merged_tracking['internal_ref']
)
```

Nothing else in the action changes — the existing `PosthogIdentifyJob`/`PosthogTrackJob` calls and redirect stay as they are.

### 4.8 `Hire::ConfirmationsController#show` (D19 — no change)

Not modified. D12 had the success redirect (line 18, sole producer of the `email_confirmed=true` landing) additionally carry the confirmed user's id and email as query params; D19 voids that — the redirect stays exactly:

```ruby
redirect_to '/auth?email_confirmed=true'
```

The failure redirect (line 21, `/auth?email_confirmed=false`) is likewise unchanged. The controller gains new spec coverage pinning both bare redirects (§9 item 5).

## 5. Frontend changes

Case convention (repo rule 7): frontend payload fields are camelCase — `utmSource`, `utmCampaign`, `utmData`, `internalRef`. `apiPost` runs `allKeysToSnake` (`app/javascript/ats/src/lib/utils/structure.js`), producing the wire params `utm_source`, `utm_campaign`, `utm_data`, `internal_ref` that `sign_up_params` permits. The keys **inside** `utmData` are the raw URL param names (`utm_medium`, `utm_term`, …) per D2 ("keyed by its param name") — this is external data, an accepted deviation from the frontend JSONB-camelCase rule (like the Ruby-enum exception). `allKeysToSnake` recurses into nested objects and applies lodash `snakeCase` to each key: canonical `utm_*` names pass through unchanged; a non-canonical key such as `utm_content2` would be normalized to `utm_content_2` in transit (existing API-layer mechanism, noted as fact). The SSO path posts a plain HTML form, bypassing `allKeysToSnake`, so its input names are written snake_case directly.

### 5.1 New sanitization helper in `app/javascript/shared/lib/utils.js` (D4)

Spec-proposed name: `sanitizeTrackingParams` (the decisions fix the location and behavior, not the name). It joins the existing query-param helpers (`standardizeQueryParamsObject` is at the top of the file — place it alongside).

**Input:** the raw `location.search` string. NOT the object returned by `queryString.parse` — the installed `query-string` v6.1.0 `parse` returns its keys **alphabetically sorted with no opt-out** (`node_modules/query-string/index.js`, `parse()` ends in `Object.keys(ret).sort().reduce(...)`), which destroys the occurrence order that D4's 10-key cap requires. The helper calls `queryString.parse(search)` internally for values and derives **key occurrence order from the raw string itself** (e.g. `queryString.extract(search).split("&")` key scan — mechanism is plan-level, the contract is: order comes from the raw string, values from the parse). Two order facts, verified in the library source: object keys are sorted (order lost); array values for a repeated param are built in occurrence order and pass through the final sort untouched — so rule 1's "first occurrence = element [0]" does hold from the parse output.

**Output:** an object with camelCase fields for component state:
- `utmSource` — sanitized value of the `utm_source` param
- `utmCampaign` — sanitized value of the `utm_campaign` param
- `internalRef` — sanitized value of the `internal_ref` param
- `utmData` — an object holding **every other** param whose name starts with `utm_` (i.e. excluding `utm_source` and `utm_campaign`), keyed by its param name, each value sanitized

**Sanitization rules per value (D4):**
1. When `queryString.parse` yields an array (repeated param), keep the first occurrence.
2. Truncate string values to 255 code units via `.slice(0, 255)`, then drop a trailing lone high surrogate (code unit 0xD800–0xDBFF) left when the slice splits a surrogate pair — the truncated value is 254 code units in that case. A value must never end in an unpaired surrogate: `JSON.stringify` would emit a lone `\udXXX` escape that Rails json 2.6.1 rejects, 400ing the entire signup POST. (Surrogate-safe semantics sanctioned by qa-run-2 Layer-2 finding l2-B1, fix commit fa51c91a5.)
3. `utmData` keeps at most 10 `utm_*` keys beyond `utm_source`/`utm_campaign` — the first 10 by occurrence order in the query string; the rest are dropped.

**Absence semantics (D3/D6, repo rule 10 "never fabricate fallback values"):** a param absent from the URL yields an absent/undefined field — no `|| ""` and no empty-object fabrication. `utmData` is present in the output only when at least one additional `utm_*` param was captured; otherwise it is absent. Absent fields serialize out of the JSON request body (undefined keys are dropped), the wire param never arrives, `sign_up_params[<key>]` is nil, and the column stays nil. A param present with no value (`?utm_source`) parses to `null` and passes through as-is.

### 5.2 `AuthForm.tsx` (D1, D2, D7)

- **Capture (D1):** at component render, pass `location.search` through `sanitizeTrackingParams` (which parses it with `queryString.parse` internally — see 5.1) and hold the sanitized values in React component state — the same state mechanism as the existing `referral` state (line 37: `React.useState(queryString.parse(location.search).referral)`). Sanitization happens **before** the values are set into state (D4). No setter is needed (the values are never re-captured); state shape (single object vs. per-field) is a plan-level choice.
- **Magic-link payload (D2):** include in the `magicLink` mutation call (inside `handleAuth`) the four fields alongside the existing `referral` and `partner`: `utmSource`, `utmCampaign` (top-level strings), `utmData` (single object field), `internalRef` (top-level string).
- **SSO props (D7):** pass the captured `utmSource`, `utmCampaign`, `utmData`, `internalRef` to `GoogleSSOButton` as props (line 120 currently passes `referral={referral} partner={partner}`).
- **Step-2 event (D14):** in the existing `magicLink` `onSuccess` callback (which currently logs and calls `onComplete({ email: cleanedEmail, ...data })`), fire `trackEvent("user_signed_up_client_side")` — plain call, no properties — before `onComplete`. Import `trackEvent` from `@shared/lib/posthog`.
  - Stated fact (accepted semantics, per the funnel audit's step 2 "Email submitted (shared form)"): this fires on **every** successful `magic_login` response, including an existing confirmed user requesting a login link — the form is shared between signup and login and the server does not distinguish in the success path the client consumes.

`AuthForm` is rendered by both `Auth.tsx` (`/auth`) and `AuthRegister.tsx` (`/auth-register`), both passing `location={props.location}` — capture therefore covers both pages with no change to either parent.

### 5.3 `GoogleSSOButton.tsx` (D7)

Extend `Props` with `utmSource?`, `utmCampaign?`, `utmData?`, `internalRef?`. Render them as hidden inputs in the existing form (action `/api/v1/users/auth/google_oauth2`, method post), alongside the existing `referral`/`partner` hidden inputs and following their render-only-when-present pattern (`typeof referral === "string" && referral.length > 0`):

- `<input type="hidden" name="utm_source" value={utmSource} />` — when present
- `<input type="hidden" name="utm_campaign" value={utmCampaign} />` — when present
- `<input type="hidden" name="internal_ref" value={internalRef} />` — when present
- `utm_data`: **one hidden input per key** using Rails-nested naming — `name={"utm_data[" + key + "]"}` — rendered only for keys whose value passes the same analog guard applied per-key: `typeof value === "string" && value.length > 0`. (A valueless `?utm_medium` parses to `null` and an empty `utm_medium=` to `""`; neither renders an input — a plain form POST cannot carry null, and the analog's guard already drops empty strings for `referral`/`partner`. Stated consequence: such degenerate values ride the JSON paths as `null`/`""` but are omitted from the SSO path. They carry no attribution signal; the divergence is accepted as the analog's own behavior.)

### 5.4 `useSession.ts` request functions (D2, D10)

- `magicLink` (posts to `/magic_login`): add `utmSource`, `utmCampaign`, `utmData`, `internalRef` to the destructured parameters, the inline TS type, and the `variables` object.
- `register` (posts to `/sign_up`): add the same four to the destructured parameters and `variables`.

No change to the `useMagicLink`/`useRegister` hook wrappers themselves (their onSuccess handlers stay as they are; component-level `onSuccess` callbacks carry the new events).

### 5.5 `SignupForm.tsx` (D10, D14)

- Capture `utmSource`, `utmCampaign`, `utmData` (other `utm_*` params), `internalRef` by passing the raw `props.location.search` string through the same `sanitizeTrackingParams` helper (see 5.1), held in component state the same way as its existing `referral` state (line 23).
- Include the four in the `register` mutation payload (alongside `firstName`, `lastName`, `email`, `password`, `inviteToken`, `referral`).
- In the existing `register` `onSuccess` callback (currently logs and calls `props.onComplete()`), fire `trackEvent("user_signed_up_client_side")` — plain call, no properties — before `onComplete`.

`SignupForm` is rendered by `Signup.tsx` at `/register`.

### 5.6 `OnboardingProfile.tsx` (D18) — replaces the voided `Auth.tsx` mechanism (D19)

**D19 — `Auth.tsx` is NOT modified.** The D12 mechanism that briefly lived there (an `[emailConfirmed]` effect reading `id`/`email` from `location.search`, calling `identifyUser` + `trackEvent("email_verified")`) is removed; `showEmailConfirmationBannerIfApplicable` and the `emailConfirmed` banner behave exactly as before this feature. D12's approval never validly covered the `/auth` placement: the server route for `/auth` bounces signed-in requests to the app root, so confirmers typically never land there (the full verified chain is retained in this spec's git history and in §11 note 7). No browser identify call is added anywhere in this PR — `AppAuthRouter.tsx`'s existing identify effect remains the only browser identify surface.

**D18 — the email-verification events fire on the Tell-us-about-you page.** `OnboardingProfile.tsx` (rendered inside `AppAuthRouter`, line 328) already computes `wasInvited`/`isNewOwner` (lines 16–17). A mount effect — `React.useEffect` with an empty dependency array and the `// eslint-disable-next-line react-hooks/exhaustive-deps` comment, per the house pattern at `AuthRegister.tsx:53-56` — fires exactly one of two events, plain `trackEvent` calls with no properties, `trackEvent` imported from `@shared/lib/posthog`:

- `trackEvent("organization_owner_email_verified")` when `isNewOwner` is true;
- `trackEvent("invited_user_email_verified")` otherwise.

Fires for everyone who reaches the page — email, Google SSO, and invited signups alike; reaching it requires a confirmed email, which is the fact being recorded (D18).

### 5.7 `OrganizationForm.tsx` (D13)

In the `createOrganization` `onSuccess` callback (where `onComplete(data)` already runs), fire `trackEvent("organization_created")` — no properties — before `onComplete(data)`. Fires on every successful creation.

**No identify call added here:** the existing `AppAuthRouter.tsx` line 168 identify `useEffect` re-fires with the new organization's properties because `useCreateOrganization` (in `useOrganization.ts`) invalidates the `currentOrganization` and `me` queries on success, changing the effect's deps (`currentUser`, `organizationId`, `currentPlan`, `organizationName`). Jessica verifies the effect re-fire in dev via the `identifyUser` `window.logger` (already on the branch).

### 5.8 `ProfileForm.tsx` (D16)

In the `updateMe` `onSuccess` callback (currently logs and calls `props.onComplete()`), fire exactly one of two events — plain `trackEvent` calls, no properties — before `onComplete`:

- `trackEvent("organization_owner_user_name_submitted")` when the form's existing `isNewOwner` prop is true;
- `trackEvent("invited_user_name_submitted")` otherwise (the `wasInvited` case and the rare neither-true edge both land here).

`isNewOwner`/`wasInvited` are computed and passed by `OnboardingProfile.tsx` (lines 16–17, 47–48); `OnboardingProfile.tsx` itself also gains the D18 mount-effect events (§5.6).

### 5.9 `posthog.ts` — already applied

`window.logger` in `identifyUser` (fire + skip paths) is already in the working tree on `attribution-work` (uncommitted). It is part of this feature; no further edit.

## 6. Authorization requirements

**None.** No new endpoints, no policy changes, no changes to who can call what:
- `/magic_login`, `/sign_up`, and the omniauth request/callback paths are unauthenticated by design (Devise scope `api_v1_user`).
- `Api::V1::OrganizationsController#create` keeps its existing Pundit `authorize @organization` call unchanged; the copied attribution values come from `current_user`, never from request params.
- `Hire::ConfirmationsController#show` remains token-authenticated via `User.confirm_by_token` exactly as today.

## 7. Constraints and requirements

1. **Sanitization is capture-side only (D4):** surrogate-safe truncation to 255 code units per value (254 when the slice would split a surrogate pair — 5.1 rule 2); first occurrence of a repeated param; at most 10 `utm_*` keys in `utm_data` (first 10 by occurrence order). There is intentionally **no server-side sanitization** — the server stores values raw as sent (D3). See Risks for the consequence.
2. **Nil for absent (D3/D6):** an absent param must produce a nil column at every layer — no `|| ""`, no `|| {}`, no jsonb default. Repo rule "Never fabricate fallback values" applies verbatim.
3. **No backfill (D6):** existing users/organizations keep nil in all four columns.
4. **Raw storage (D3):** no `get_created_via`-style mapping, no downcasing — deliberate contrast with the adjacent `created_via`/`partner_source` handling.
5. **Creation-time only:** Users get values only at row creation (`magic_create` new-user branch, `create`, `from_omniauth` `first_or_create` block). Existing users logging in — magic link or SSO — are never updated. Organizations get values only at `organizations#create`, copied from `current_user`.
6. **No serializer changes:** the four columns are not exposed through any Api::V1 serializer (the decisions specify none; they are attribution data for PostHog/DB analysis, not frontend inputs). `Api::V1::SessionSerializer` and `Api::V1::OrganizationSerializer` are untouched.
7. **Browser-first events; server events untouched:** no `PosthogTrackJob`/`PosthogIdentifyJob` call is added, removed, or modified anywhere. The server's `user_signed_up`, `user_logged_in`, and all identify jobs remain the backup layer.
8. **Event names are fixed:** `user_signed_up_client_side`, `organization_owner_email_verified`, `invited_user_email_verified`, `organization_created`, `organization_owner_user_name_submitted`, `invited_user_name_submitted`. All are plain `trackEvent` calls with no properties. (`email_verified` is gone with the void D12.)
9. **`utm_data` inner keys** are the URL param names as captured (D2) — not camelCased.
10. **Files-never-edit list respected:** no changes to `api.ts`, context files, or core infrastructure. No new files in the source repo other than the two migrations (all other changes are edits to existing files).

## 8. Existing patterns to follow (analogs, verified in live code)

| Pattern | Analog location | Used for |
|---|---|---|
| Query-param capture into component state | `AuthForm.tsx:37` (`referral`), `SignupForm.tsx:23` | D1/D10 capture |
| Tracking threading through signup payloads | `referral`/`partner` in `AuthForm.tsx` `handleAuth` → `useSession.ts` `magicLink` → `sign_up_params` | D2/D3 |
| Hidden tracking inputs on the SSO form | `GoogleSSOButton.tsx:46-51` (`referral`, `partner`, render-only-when-present) | D7 |
| Omniauth tracking whitelist + session ride | `config/initializers/omniauth.rb:12-27` `setup` lambda, `allowed_keys` | D8 |
| Tracking recovery in the callback | `omniauth_callbacks_controller.rb:9-18` (`session.delete(:oauth_tracking)`, `merged_tracking`) | D9 |
| Creation-time-only attribute assignment | `from_omniauth` `first_or_create` block (`created_via`, `partner_source`) | D9 |
| Parent→child attribute copy at org creation | `organizations_controller.rb:31` (`@organization.created_via = current_user.created_via`) | D5 |
| Arbitrary-key jsonb permit | `questions_controller.rb:50` (`options: {}` → `questions.options` jsonb) | D3 `utm_data: {}` |
| Query-param helper placement | `utils.js` `standardizeQueryParamsObject` (top of file) | D4 helper |
| Browser event in a mutation onSuccess | `NewJobCenterModal.tsx:46` (`trackEvent("job_created", ...)` in create onSuccess), `CommentTemplateModal.tsx:100` (plain no-property call) | D13/D14/D16 |
| Mount effect with empty deps + eslint-disable | `AuthRegister.tsx:53-56` (`React.useEffect(..., [])`) | D18 |
| Add-columns migration shape | `db/migrate/20260622182504_add_ai_summary_and_criteria_columns_to_jobs.rb` | D6 migrations |

## 9. Test requirements

Verified current state: no existing RSpec file covers `Api::V1::RegistrationsController`, `Api::V1::Users::OmniauthCallbacksController`, `Api::V1::OrganizationsController#create`, or `User.from_omniauth` (`git grep from_omniauth` matches only `app/models/user.rb` and the callbacks controller; `spec/` contains no registrations/omniauth/organizations-create specs). So there are **no existing specs to update** — the requirement is new coverage. The suite's conventions: `type: :controller` specs with stubbed authentication/Pundit (see `spec/controllers/api/v1/organization_ai_credit_purchases_purchase_top_up_spec.rb` — "no Devise controller helpers wired into rails_helper"; Devise-controller specs opt in per-file, see items 1 and 3 below), manual record-creation helpers in `spec/support/api_factories.rb` (no FactoryBot), bang methods permitted in specs. `Recaptcha::Verifier#verify` returns success automatically in the test env — no stubbing needed for `magic_create`.

**New RSpec coverage required:**

1. **`spec/controllers/api/v1/registrations_controller_spec.rb`** (new; `type: :controller`; set `@request.env['devise.mapping'] = Devise.mappings[:api_v1_user]` AND `include Devise::Test::ControllerHelpers` in the describe block — the actions call `sign_up`/`sign_in`, which need warden in the request env; rails_helper does not wire the helpers globally, the per-file precedent is `spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb` line 7):
   - **Every `magic_create` POST in this spec must include `login_intent: 'hire'`** (the value `AuthForm.tsx` always sends). Without it, `login_intent` defaults to `'connect'` and — with no `organization_slug` — the connect branch of the `user_params` conditional evaluates `organization.id` on nil (`registrations_controller.rb` lines 88–97) and raises `NoMethodError`. Pre-existing behavior outside this feature's scope; the tests must simply route around it, not fix it.
   - `magic_create` new-user branch: POST with `utm_source`, `utm_campaign`, `internal_ref`, and a multi-key `utm_data` hash → created User has all four persisted **raw** (assert an unmapped value like `utm_source: 'SomeRawValue'` is stored verbatim — no downcase, no created_via-style mapping; assert `utm_data` round-trips as a hash).
   - `magic_create` with none of the four params → created User has nil in all four columns (including `utm_data` nil, not `{}`).
   - `magic_create` existing-confirmed-user branch with the four params present → the existing User's columns are not modified.
   - `magic_create` existing-UNCONFIRMED-user branch (resend-confirmation path) with the four params present → the existing User's columns are not modified. (This branch calls `sign_in`, hence the warden requirement above.)
   - `create` (password path): POST with the four params → assigned via `sign_up_params`; without them → nil.
2. **`User.from_omniauth` spec** (new; e.g. `spec/models/user_from_omniauth_spec.rb`):
   - Keyword interface: new user created with `utm_source:`/`utm_campaign:`/`utm_data:`/`internal_ref:` supplied → values persisted; omitted keywords → nil columns.
   - Existing user (matching email): SSO login leaves all four columns untouched (assignment only inside `first_or_create`).
   - `auth:`/`created_via:` required; `partner_source:` still downcased; new values raw.
3. **`spec/controllers/api/v1/users/omniauth_callbacks_controller_spec.rb`** (new; `type: :controller`; `include Devise::Test::ControllerHelpers` — `google_oauth2` calls `sign_in(user)`, which needs warden in the request env): stub `request.env['omniauth.auth']` and seed `session[:oauth_tracking]` with the six tracking keys → assert `from_omniauth` receives the four values from the merged tracking hash (this pins the keyword call-site conversion and the string-key session read).
4. **`spec/controllers/api/v1/organizations_controller_spec.rb`** (new; `type: :controller`, stub `authenticate_api_v1_user!`/`current_user`/Pundit per the ai-credit spec pattern): `create` with a `current_user` carrying the four values → new Organization has identical values; `current_user` with nils → Organization nils.
5. **`Hire::ConfirmationsController` spec** (new): success path redirects to the bare `/auth?email_confirmed=true` — no `id`/`email` params (D19); failure path redirect unchanged (`/auth?email_confirmed=false`).

**Jest coverage: none (Jessica's ruling, 2026-07-16).** This codebase does not use Jest; the `sanitizeTrackingParams` helper has no Jest coverage by design. The `app/javascript/shared/lib/utils.test.js` file created during implementation is removed as part of the D18/D19 revision.

**Cypress:** existing tests are read-only per repo rules and none are to be altered. `cypress/e2e/auth/registration.cy.js` exercises both signup paths end-to-end and must keep passing (it runs in the pre-commit hook); the payload additions must not break it. No new Cypress tests are required for this PR: the browser events are PostHog side effects (verified manually by Jessica in dev via the `identifyUser`/`trackEvent` `window.logger` output), and UTM persistence is covered by the RSpec layer above.

**Event-name grep check (for the reviewer):** after implementation, `git grep user_signed_up_client_side app/` should match only the two frontend callsites; the server's `user_signed_up` string must be unmodified.

## 10. Out of scope / deferred (explicit)

- **Marketing-site work (D17):** utm forwarding from `*.polymer.co` marketing pages, CTA click events, and signup-page instrumentation (arrival + in-page interactions) are queued for the marketing-site round. No event fires on `/auth-register` page view in this PR; until the marketing round, the funnel's first captured step is `user_signed_up_client_side`.
- **Browser-side login event (D15):** deferred, not declined. A magic-link login lands directly in the app with no distinct browser moment; the funnel's logged-in step keeps the server `user_logged_in`.
- **SSO signups get no `user_signed_up_client_side`:** there is no browser moment (the browser leaves for Google and returns via server redirect); the server `user_signed_up` (fired in `omniauth_callbacks#google_oauth2`) covers them. Status quo, flagged as accepted.
- **Serializer exposure of the four columns:** not in the approved decisions; not done.
- **Identify at `Hire::ConfirmationsController#show` server-side** (the gap named in identify-findings.md): not an approved decision; no server identify added. With D12 void (D19), this PR adds no identify at the confirmation moment at all — the D18 events fire on `OnboardingProfile.tsx`, rendered inside `AppAuthRouter`, whose existing identify effect is the browser identify surface.
- ~~SSO signups never fire `email_verified`~~ / ~~`email_verified` coverage for signed-in confirmations (Risk 7)~~ — both former gaps are superseded by D18: the email-verified events fire on the Tell-us-about-you page for every population (email, Google SSO, invited; signed-in or not), so neither exclusion exists anymore. See §11 note 7.
- **Backfill/analysis of historical rows:** none.

## 11. Risks / factual notes for review

1. **Shared-form semantics:** `user_signed_up_client_side` fires for existing users requesting a magic login link (5.2). This is the approved step-2 "email submitted" semantics, not a defect.
2. **Cookie session size (SSO path):** the app uses the default cookie session store with the `:json` cookie serializer. `session[:oauth_tracking]` can now carry up to ~12 values of ≤255 chars from a sanitized browser (~3KB worst case) against the ~4KB cookie ceiling; a direct POST to the omniauth request path bypasses the frontend sanitizer entirely and is uncapped server-side (the approved design has no server-side sanitization), which can overflow the session cookie and drop tracking or raise `ActionDispatch::Cookies::CookieOverflow` for that request. Noted as an accepted property of the approved design.
3. **API-layer key normalization:** lodash `snakeCase` inside `allKeysToSnake` normalizes `utm_data` inner keys in transit on the magic-link/register paths (`utm_content2` → `utm_content_2`); the SSO form path posts keys verbatim. Canonical `utm_*` names are unaffected on both paths.
4. **Postgres string columns are unlimited** (`character varying` without limit), so the 255-code-unit surrogate-safe cap (5.1 rule 2) exists only in the frontend helper — direct API callers can store longer values. Consistent with "stored raw as sent".
5. **`from_omniauth` signature change is a breaking interface change** — mitigated by D9's mandatory repo-wide call-site search (one call site today) and the new specs pinning the keyword interface.
6. **(Void — D19.)** D12 had the confirmation redirect carry the user's id and email in the URL (browser history / request-log exposure). D19 reverts the redirect to bare `email_confirmed=true`; the exposure no longer exists.
7. **(Resolved by D18/D19 — Jessica's ruling on the former Risk 7.)** Under D12, `email_verified` fired only for confirmations clicked while signed out: signups are signed in while unconfirmed (`registrations#create`/`magic_create` call `sign_up`; `User#active_for_authentication?` is overridden to `super || organization.nil?` — user.rb lines 136–138), and the server route for `/auth` (`config/routes.rb:591` → `Hire::PagesController#auth`) runs `before_action :redirect_if_authed`, which 302s any signed-in request to `app_root_path`, dropping all query params (pages_controller.rb lines 24–31) — so the typical same-browser confirmation click never rendered `Auth.tsx`. That is why D19 voids D12 ("the decision text asserted the landing as fact"). D18 moves the events to `OnboardingProfile.tsx` mount, which every population reaches (email, SSO, invited; signed-in or not), so the undercount no longer applies. Semantics shift accordingly: the events record "reached the Tell-us-about-you page with a confirmed email," not "landed on `/auth` from the confirmation link."
