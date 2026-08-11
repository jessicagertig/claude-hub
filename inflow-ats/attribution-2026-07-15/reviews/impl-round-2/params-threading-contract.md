# params-threading-contract — Round 2

Re-derived fresh across every hop of both JSON paths.

## Verified

- **Payloads:** `AuthForm.tsx` `handleAuth` passes `utmSource`/`utmCampaign`/`utmData`/`internalRef` into `magicLink` alongside `referral`/`partner`; `SignupForm.tsx` passes the same four into `register`. camelCase per repo rule 7.
- **Request functions:** `useSession.ts` `magicLink` gains the four in destructure + inline TS type (optional `?: string | null`, `utmData?: Record<string, any> | null`) + `variables`; `register` (which has no inline type — matches spec §5.4 which only requires destructure + variables there) gains the four. Hook wrappers `useMagicLink`/`useRegister` untouched.
- **Wire transform:** `allKeysToSnake` (`structure.js`) — `snakeCase` on each key produces `utm_source`/`utm_campaign`/`utm_data`/`internal_ref`; recursion into `utmData` leaves canonical `utm_*` inner keys unchanged (lodash `snakeCase('utm_medium')` === `'utm_medium'`); string/null values pass through `isPlainObject` unchanged; undefined values drop out of `JSON.stringify` — nil-for-absent survives the hop.
- **Permit:** `sign_up_params` (registrations_controller.rb:310) adds `:utm_source, :utm_campaign, :internal_ref` and trailing `utm_data: {}` — the exact `questions_controller.rb` `options: {}` analog form, trailing argument of `permit`.
- **`magic_create` merge:** the four keys present in BOTH branches of the `user_params` conditional (connect-intent branch and default branch), values `sign_up_params[<key>]` raw — no downcase, no mapping. Existing-user branches read only `user_params[:email]` — additions inert there. JSON responses untouched (no render change in the diff).
- **`create`:** no change beyond the permit; `expanded_params = sign_up_params.merge(created_via:, partner_source:)` → `build_resource` picks up the four automatically (verified lines 10–22).
- **Persistence proof:** registrations controller spec passes — raw `'SomeRawValue'` stored verbatim, `utm_data` round-trips `{ 'utm_medium' => 'email', 'utm_term' => 'hiring' }` (proves the permitted `ActionController::Parameters` value serializes to jsonb correctly), absent params → all four nil including `utm_data` nil-not-`{}`, both existing-user branches leave columns untouched. 17/17 examples pass.
- **Migration:** `20260715233505_add_attribution_columns_to_users.rb` — string/string/jsonb/string, no defaults, nullable, no index.

## Findings

No issues found.
