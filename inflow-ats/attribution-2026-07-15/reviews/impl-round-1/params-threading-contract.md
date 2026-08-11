# params-threading-contract — Round 1

## Verification performed

Traced both JSON transports end-to-end in committed code:

- **Payloads:** `AuthForm.tsx` `handleAuth` adds `utmSource`/`utmCampaign`/`utmData`/`internalRef` to the `magicLink({...})` variables alongside `referral`/`partner` (lines 81-84 region); `SignupForm.tsx` `handleSignup` adds the same four to `register({...})` alongside `inviteToken`/`referral`. Values are direct property reads off `trackingParams` — absent fields are `undefined` and drop out of the JSON body (axios `JSON.stringify`), so the wire param never arrives.
- **Request functions** (`useSession.ts`): `magicLink` gained the four in (a) destructure, (b) inline TS type (`utmSource?: string | null; utmCampaign?: string | null; utmData?: Record<string, any> | null; internalRef?: string | null;`), (c) `variables`. `register` gained destructure + `variables` (it has no inline type today and none was added — per plan F2.2). Hook wrappers `useMagicLink`/`useRegister` untouched (verified: diff hunks stop before line 116; the pre-existing unused-`queryClient` eslint warnings at 143/156 are in unchanged code). The `window.logger` object inside `magicLink` was NOT extended (do-not-touch respected).
- **Wire transform:** `apiPost` → `apiMutate` (`api.ts:40-53`, untouched) applies `allKeysToSnake` (`structure.js:94-105`): `utmSource`→`utm_source`, `utmData`→`utm_data`; recursion into the nested object leaves canonical `utm_*` inner keys unchanged (`snakeCase("utm_medium") === "utm_medium"`). Non-canonical inner-key normalization (`utm_content2`→`utm_content_2`) is the accepted spec Risk 3 fact.
- **Permit** (`registrations_controller.rb:307-310`): three scalars added + `utm_data: {}` as the TRAILING argument of `permit` — the exact `questions_controller.rb:50` `options: {}` analog form. Still the controller's one params method (rule 5); the commented-out line preserved.
- **`magic_create` merge** (lines 88-115): the four keys present in BOTH branches of the two-branch conditional, appended after the existing keys, sourced from `sign_up_params[...]` — raw, no `&.downcase`, no mapping (D3; deliberate contrast with the adjacent `partner_source: params[:partner]&.downcase`, which is unchanged). The two existing-user branches read only `user_params[:email]` (lines 117, 126) — the added keys are inert there; row creation only via `build_resource(user_params)` in the new-user branch (line 166). Zero change to any `magic_create` JSON response shape (no diff in those regions).
- **`create` path (D10):** no change beyond the permit — `expanded_params = sign_up_params.merge(created_via:, partner_source:)` (lines 13-16, untouched) forwards the newly permitted params to `build_resource`.
- **Nil-for-absent, proven by execution:** ran the 5 new spec files (`RAILS_ENV=test bundle exec rspec ...`) — 17 examples, 0 failures. Includes: no-params POST → all four columns nil with `utm_data` `be_nil` (nil, not `{}`), on both `magic_create` and `create`.
- **`ActionController::Parameters` → jsonb** (plan risk 4): the passing round-trip assertion (`utm_data == { 'utm_medium' => 'email', 'utm_term' => 'hiring' }`) is the falsifier — the spec-run output showed `utm_data` entering `user_params` as `ActionController::Parameters {…} permitted: true` and persisting as a plain string-keyed hash. Confirmed working.
- **Migration** (`20260715233505_add_attribution_columns_to_users.rb`): plain `add_column` ×4, no defaults/null constraints/indexes — matches D6.

## Findings

No issues found.
